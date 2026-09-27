import AVFoundation
import MediaPlayer
import SwiftUI
import UIKit

// MARK: - Listen track source pack
//
// Audio tracks are authored against the same lesson ids as the packs
// (`fr-identity-foundation` is both a bare-track lesson and a pack lesson),
// so the pack a track belongs to can be located by lesson id — the same
// lookup the phrasebook uses to open a saved phrase's origin lesson.
// PackLoader caches its result, so this costs nothing after first load.

extension ListenTrack {
    /// The id of the pack that ships this track's lesson, when one exists.
    /// Empty when the track's lesson id matches no bundled pack lesson.
    var sourcePackId: String {
        (try? PackLoader.loadPacks())?
            .first { $0.lessons.contains { $0.id == lessonId } }?
            .id ?? ""
    }
}

// MARK: - Listen player model
//
// Audio-only lesson playback: play/pause, ±15s, scrubber, speed, and a
// one-tap "Slow" replay that hears the current section again at 0.75×.
// Playback continues with the screen off (UIBackgroundModes audio + .playback
// session) with lock-screen controls via MPRemoteCommandCenter.
//
// Position honesty mirrors the web's position.ts: resume points under five
// seconds are stray taps, stopping within ten seconds of the end counts as
// finished, and a finished track is marked listened — heard, not mastered.

@MainActor
final class ListenPlayerModel: ObservableObject {
    static let skipSeconds = 15.0
    static let rates: [Float] = [1, 0.75, 1.25, 1.5]
    /// Speed used by the explicit "Slow" replay; also reachable by cycling rates.
    static let slowRate: Float = 0.75
    /// Provenance caption shared by the player card and the lock screen: the
    /// track's voice is synthesized TTS (never a claimed human recording). This
    /// keeps the "(synthesized)" wording used by every other voice surface in
    /// the app (Shadow, Practice, lesson pairs) on the main listening surface.
    static let voiceDescriptor = "Course voice (synthesized)"

    let track: ListenTrack
    let courseTitle: String

    @Published var isPlaying = false
    @Published var current: Double = 0
    @Published var duration: Double
    @Published var rate: Float = 1
    @Published var isSlowReplay = false
    @Published var sleepMinutesLeft: Int?
    @Published var resumeFrom: Double?
    @Published var resumeApplied = false
    @Published var heard: Date?
    @Published var failed = false

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var backgroundObserver: NSObjectProtocol?
    private var remoteTargets: [Any] = []
    private var lastPersistedAt = -10.0
    private var tornDown = false
    private var sleepDeadline: Date?
    private let history: ListenHistory?

    init(track: ListenTrack, courseTitle: String) {
        self.track = track
        self.courseTitle = courseTitle
        self.duration = track.durationS
        let history = ListenHistory.open()
        self.history = history
        self.heard = history?.listenedAt(lessonId: track.lessonId)
        self.resumeFrom = history?.readPosition(lessonId: track.lessonId)
        setup()
    }

    private func setup() {
        guard let url = MediaResolver.bundleURL(for: track.audioUrl) else {
            failed = true
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        } catch {
            // Playback still works in the foreground without the category.
        }
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        self.player = player

        // AVAsset.duration is deprecated (iOS 16+): load the real duration
        // asynchronously and correct the JSON-declared value when it arrives.
        Task {
            do {
                let loaded = try await item.asset.load(.duration)
                if let actual = loaded.secondsIfFinite, actual > 0 {
                    duration = actual
                    updateNowPlaying()
                }
            } catch {
                // Keep the JSON-declared duration.
            }
        }

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            Task { @MainActor in
                self.current = time.secondsIfFinite ?? self.current
                if self.isPlaying, self.current - self.lastPersistedAt >= 5 {
                    self.persist()
                }
                self.updateNowPlaying()
                self.checkSleepTimer()
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleEnded() }
        }

        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.persist() }
        }

        setupRemoteCommands()
        updateNowPlaying()
    }

    /// Stops playback, saves position, removes observers. Called when the
    /// player view disappears.
    func teardown() {
        guard !tornDown else { return }
        tornDown = true
        sleepDeadline = nil
        sleepMinutesLeft = nil
        persist()
        player?.pause()
        isPlaying = false
        if let timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        if let backgroundObserver {
            NotificationCenter.default.removeObserver(backgroundObserver)
        }
        let center = MPRemoteCommandCenter.shared()
        for target in remoteTargets {
            center.playCommand.removeTarget(target)
            center.pauseCommand.removeTarget(target)
            center.togglePlayPauseCommand.removeTarget(target)
            center.skipBackwardCommand.removeTarget(target)
            center.skipForwardCommand.removeTarget(target)
            center.changePlaybackPositionCommand.removeTarget(target)
        }
        remoteTargets.removeAll()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: transport

    func togglePlay() {
        isPlaying ? pause() : play()
    }

    func play() {
        guard let player, !failed else { return }
        if let resume = resumeFrom, !resumeApplied {
            seek(to: resume)
            resumeApplied = true
        }
        do {
            let session = AVAudioSession.sharedInstance()
            // A prior record-and-compare cycle leaves the session in
            // playAndRecord mode; re-assert plain playback so track audio
            // keeps routing correctly (and with the screen off) after
            // recording stops.
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            // Best effort: the player may still produce sound.
        }
        player.play()
        player.rate = rate
        isPlaying = true
        updateNowPlaying()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        persist()
        updateNowPlaying()
    }

    func seek(to seconds: Double) {
        guard let player else { return }
        let target = min(max(0, seconds), duration)
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
        current = target
        updateNowPlaying()
    }

    func nudge(by delta: Double) {
        seek(to: current + delta)
    }

    func cycleRate() {
        guard let index = Self.rates.firstIndex(of: rate) else {
            rate = Self.rates[0]
            isSlowReplay = false
            return
        }
        rate = Self.rates[(index + 1) % Self.rates.count]
        if isPlaying { player?.rate = rate }
        if rate != Self.slowRate { isSlowReplay = false }
        updateNowPlaying()
    }

    // MARK: slow replay

    /// One tap replays the current section at a gentle pace: the playhead
    /// jumps to the nearest section start and playback continues at
    /// `slowRate`. A second tap returns to normal speed in place. The
    /// rate-cycle button stays independent — it clears slow mode whenever
    /// it moves the speed off 0.75×. Reuses the transport rate machinery,
    /// so lock-screen rate reporting and background playback keep working.
    func toggleSlowReplay() {
        if isSlowReplay {
            isSlowReplay = false
            rate = 1
            if isPlaying { player?.rate = rate }
            updateNowPlaying()
        } else {
            isSlowReplay = true
            rate = Self.slowRate
            // An explicit replay supersedes any offered resume point.
            resumeApplied = true
            seek(to: nearestSectionStart())
            if isPlaying {
                player?.rate = rate
            } else {
                play()
            }
            updateNowPlaying()
        }
    }

    /// Start of the section under the playhead: the last heading at or
    /// before the current position. Transcripts without section timings
    /// keep the playhead where it is.
    private func nearestSectionStart() -> Double {
        let candidates = track.sections
            .compactMap(\.startS)
            .filter { $0 <= current + 0.25 }
        return candidates.max() ?? current
    }

    // MARK: sleep timer

    /// Wall-clock timer that pauses playback when it fires. Checked in
    /// the periodic time observer, so it keeps working with the
    /// screen off.
    func setSleepTimer(minutes: Int?) {
        if let minutes {
            sleepDeadline = Date().addingTimeInterval(Double(minutes) * 60)
            sleepMinutesLeft = minutes
        } else {
            sleepDeadline = nil
            sleepMinutesLeft = nil
        }
    }

    private func checkSleepTimer() {
        guard let deadline = sleepDeadline else { return }
        let remaining = Int(ceil(deadline.timeIntervalSinceNow / 60))
        if remaining <= 0 {
            sleepDeadline = nil
            sleepMinutesLeft = nil
            if isPlaying { pause() }
        } else if remaining != sleepMinutesLeft {
            sleepMinutesLeft = remaining
        }
    }

    /// Discards the saved position and restarts from the beginning.
    func startOver() {
        history?.clearPosition(lessonId: track.lessonId)
        resumeFrom = nil
        resumeApplied = true
        seek(to: 0)
    }

    // MARK: persistence

    private func persist() {
        lastPersistedAt = current
        let kept = history?.savePosition(
            lessonId: track.lessonId,
            seconds: current,
            duration: duration
        )
        if kept == nil { resumeFrom = nil }
    }

    private func handleEnded() {
        isPlaying = false
        current = duration
        heard = history?.markListened(lessonId: track.lessonId)
        history?.clearPosition(lessonId: track.lessonId)
        resumeFrom = nil
        updateNowPlaying()
    }

    // MARK: lock screen / control center

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.skipBackwardCommand.preferredIntervals = [NSNumber(value: Self.skipSeconds)]
        center.skipForwardCommand.preferredIntervals = [NSNumber(value: Self.skipSeconds)]

        remoteTargets = [
            center.playCommand.addTarget { [weak self] _ in
                Task { @MainActor in self?.play() }
                return .success
            },
            center.pauseCommand.addTarget { [weak self] _ in
                Task { @MainActor in self?.pause() }
                return .success
            },
            center.togglePlayPauseCommand.addTarget { [weak self] _ in
                Task { @MainActor in self?.togglePlay() }
                return .success
            },
            center.skipBackwardCommand.addTarget { [weak self] _ in
                Task { @MainActor in self?.nudge(by: -Self.skipSeconds) }
                return .success
            },
            center.skipForwardCommand.addTarget { [weak self] _ in
                Task { @MainActor in self?.nudge(by: Self.skipSeconds) }
                return .success
            },
            center.changePlaybackPositionCommand.addTarget { [weak self] event in
                guard let position = (event as? MPChangePlaybackPositionCommandEvent)?.positionTime else {
                    return .commandFailed
                }
                Task { @MainActor in self?.seek(to: position) }
                return .success
            },
        ]
    }

    private func updateNowPlaying() {
        guard !failed else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: "\(track.lessonTitle) · \(Self.voiceDescriptor)",
            MPMediaItemPropertyArtist: "Condisco",
            MPMediaItemPropertyAlbumTitle: courseTitle,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: current,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? rate : 0,
        ]
    }
}

private extension CMTime {
    var secondsIfFinite: Double? {
        let seconds = CMTimeGetSeconds(self)
        return seconds.isFinite ? seconds : nil
    }
}

// MARK: - Listen tab: track library

struct ListenView: View {
    @State private var tracks: [ListenTrack] = []
    @State private var resumePoints: [String: Double] = [:]
    @State private var heardDates: [String: Date] = [:]
    @AppStorage("condisco.focusLanguage") private var focusSlug = "french"

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.canvas.ignoresSafeArea()
                if tracks.isEmpty {
                    emptyState
                } else {
                    trackList
                }
            }
            .navigationTitle("Listen")
        }
        .task { refresh() }
    }

    @MainActor
    private func refresh() {
        tracks = ListenCatalog.loadTracks().sorted { a, b in
            let aKey = (a.courseSlug == focusSlug ? 0 : 1,
                        ListenCourse.courseSlugs.firstIndex(of: a.courseSlug) ?? 99)
            let bKey = (b.courseSlug == focusSlug ? 0 : 1,
                        ListenCourse.courseSlugs.firstIndex(of: b.courseSlug) ?? 99)
            return aKey < bKey
        }
        var resumes: [String: Double] = [:]
        var heard: [String: Date] = [:]
        guard let history = ListenHistory.open() else {
            resumePoints = resumes
            heardDates = heard
            return
        }
        for track in tracks {
            if let position = history.readPosition(lessonId: track.lessonId) {
                resumes[track.lessonId] = position
            }
            if let date = history.listenedAt(lessonId: track.lessonId) {
                heard[track.lessonId] = date
            }
        }
        resumePoints = resumes
        heardDates = heard
    }

    private var trackList: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("One guided audio lesson per language: a calm voice walks you through it by ear. Predict each answer out loud before the reveal — built for walks and screen-off study.")
                    .font(DesignTokens.text(14))
                    .foregroundStyle(DesignTokens.muted)
                    .padding(.horizontal, 4)
                ForEach(tracks) { track in
                    NavigationLink {
                        ListenPlayerView(
                            track: track,
                            courseTitle: ListenCourse.displayName(for: track.courseSlug)
                        )
                    } label: {
                        trackRow(track)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }

    private func trackRow(_ track: ListenTrack) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(ListenCourse.displayName(for: track.courseSlug))
                    .font(DesignTokens.text(13, weight: .semibold))
                    .foregroundStyle(DesignTokens.primary)
                    .textCase(.uppercase)
                Text(track.lessonTitle)
                    .font(DesignTokens.display(19))
                    .foregroundStyle(DesignTokens.inkDeep)
                HStack(spacing: 12) {
                    Label(formatListenDuration(track.durationS), systemImage: "headphones")
                    if heardDates[track.lessonId] != nil {
                        Label("Listened", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(DesignTokens.primary)
                    } else if let resume = resumePoints[track.lessonId] {
                        Label("Resume \(formatListenPosition(resume))", systemImage: "arrow.counterclockwise")
                    }
                    Spacer()
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(DesignTokens.primary)
                }
                .font(DesignTokens.text(13))
                .foregroundStyle(DesignTokens.muted)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("No listen tracks yet")
                .font(DesignTokens.display(20))
                .foregroundStyle(DesignTokens.inkDeep)
            Text("Audio lessons are still being authored. They'll appear here when they're ready.")
                .font(DesignTokens.text(14))
                .foregroundStyle(DesignTokens.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Listen player

struct ListenPlayerView: View {
    let track: ListenTrack
    let courseTitle: String

    @StateObject private var model: ListenPlayerModel
    @State private var scrub: Double = 0
    @State private var isScrubbing = false
    @State private var showingShadow = false
    @State private var showingPractice = false
    @State private var vocabularyByWord: [String: VocabularyItem] = [:]

    private var sectionIndices: [Int] {
        Array(0..<track.sections.count)
    }

    private func sectionRow(_ section: ListenSection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeading(section)
            Text(section.teacher)
                .font(DesignTokens.text(15))
                .foregroundStyle(DesignTokens.ink)
                .lineSpacing(3)
            if let target = section.target {
                let phrase = ShareablePhrase(
                    target: target.text,
                    meaning: target.meaning,
                    languageName: ListenCourse.displayName(for: track.courseSlug))
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        GlossableText(text: target.text, vocabularyByWord: vocabularyByWord,
                                      fontSize: 16, fontWeight: .semibold,
                                      textColor: DesignTokens.primaryStrong)
                        Text(target.meaning)
                            .font(DesignTokens.text(14))
                            .foregroundStyle(DesignTokens.muted)
                    }
                    Spacer()
                    HStack(spacing: 14) {
                        PhraseSaveButton(
                            phrase: phrase,
                            languageSlug: track.courseSlug,
                            source: track.lessonTitle,
                            sourcePackId: track.sourcePackId,
                            sourceLessonId: track.lessonId)
                        PhraseShareButton(phrase: phrase)
                        RecordCompareButton(
                            target: target.text,
                            languageCode: ShadowVoice.languageCode(
                                for: track.courseSlug))
                    }
                }
                .padding(12)
                .background(DesignTokens.stock2)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(DesignTokens.edgeSoft, lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 4)
    }

    init(track: ListenTrack, courseTitle: String) {
        self.track = track
        self.courseTitle = courseTitle
        _model = StateObject(wrappedValue: ListenPlayerModel(track: track, courseTitle: courseTitle))
    }

    var body: some View {
        ZStack {
            DesignTokens.canvas.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    if model.failed {
                        failedCard
                    } else {
                        transportCard
                        if let resume = model.resumeFrom, !model.resumeApplied {
                            resumeCard(resume)
                        }
                    }
                    transcript
                        .sheet(isPresented: $showingPractice) {
                            PracticeLoopView(track: track)
                        }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle(track.lessonTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { scrub = model.current }
        .task { await loadVocabulary() }
        .onChange(of: model.current) { _, newValue in
            if !isScrubbing { scrub = newValue }
        }
        .onDisappear { model.teardown() }
        .sheet(isPresented: $showingShadow) {
            ShadowModeView(track: track)
        }
    }

    private var transportCard: some View {
        PaperCard {
            VStack(spacing: 12) {
                Text("\(track.lessonTitle) · audio lesson")
                    .font(DesignTokens.text(13, weight: .semibold))
                    .foregroundStyle(DesignTokens.primary)
                    .textCase(.uppercase)
                Text(ListenPlayerModel.voiceDescriptor)
                    .font(DesignTokens.text(12))
                    .foregroundStyle(DesignTokens.muted)
                HStack {
                    Text(formatListenPosition(isScrubbing ? scrub : model.current))
                    Spacer()
                    Text(formatListenDuration(model.duration))
                }
                .font(DesignTokens.text(13, weight: .medium))
                .foregroundStyle(DesignTokens.muted)
                .monospacedDigit()

                Slider(
                    value: $scrub,
                    in: 0...max(model.duration, 1),
                    onEditingChanged: { editing in
                        isScrubbing = editing
                        if !editing { model.seek(to: scrub) }
                    }
                )
                .tint(DesignTokens.primary)

                HStack(spacing: 28) {
                    Button { model.nudge(by: -ListenPlayerModel.skipSeconds) } label: {
                        Image(systemName: "gobackward.15")
                            .font(.system(size: 26))
                    }
                    Button { model.togglePlay() } label: {
                        Image(systemName: model.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 56))
                    }
                    Button { model.nudge(by: ListenPlayerModel.skipSeconds) } label: {
                        Image(systemName: "goforward.15")
                            .font(.system(size: 26))
                    }
                }
                .foregroundStyle(DesignTokens.primary)

                HStack(spacing: 12) {
                    Button {
                        model.cycleRate()
                    } label: {
                        Text(rateLabel)
                            .font(DesignTokens.text(14, weight: .semibold))
                            .foregroundStyle(DesignTokens.ink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(DesignTokens.edgeSoft, lineWidth: 1)
                            )
                    }

                    Button {
                        model.toggleSlowReplay()
                    } label: {
                        Text("Slow")
                            .font(DesignTokens.text(14, weight: .semibold))
                            .foregroundStyle(
                                model.isSlowReplay
                                    ? DesignTokens.primaryStrong
                                    : DesignTokens.ink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(
                                        model.isSlowReplay
                                            ? DesignTokens.primary
                                            : DesignTokens.edgeSoft,
                                        lineWidth: 1)
                            )
                    }
                    .accessibilityLabel("Slow replay")
                    .accessibilityHint(
                        model.isSlowReplay
                            ? "On. Tap to return to normal speed."
                            : "Replays the current line at a gentle pace.")
                    .accessibilityAddTraits(model.isSlowReplay ? .isSelected : [])

                    Menu {
                        Button("Off") { model.setSleepTimer(minutes: nil) }
                        ForEach([5, 10, 15, 30, 45, 60], id: \.self) { minutes in
                            Button("\(minutes) minutes") {
                                model.setSleepTimer(minutes: minutes)
                            }
                        }
                    } label: {
                        Label(
                            model.sleepMinutesLeft.map { "Sleep \($0)m" } ?? "Sleep",
                            systemImage: "moon.zzz")
                            .font(DesignTokens.text(14, weight: .semibold))
                            .foregroundStyle(
                                model.sleepMinutesLeft == nil
                                    ? DesignTokens.ink
                                    : DesignTokens.primaryStrong)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(DesignTokens.edgeSoft, lineWidth: 1)
                            )
                    }
                    .accessibilityLabel("Sleep timer")
                }

                if model.heard != nil {
                    Label("Listened — heard, not mastered", systemImage: "checkmark.circle.fill")
                        .font(DesignTokens.text(13))
                        .foregroundStyle(DesignTokens.primary)
                }
            }
        }
    }

    private var rateLabel: String {
        let value = model.rate
        return value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))×"
            : "\(value)×"
    }

    /// Pack id for a Listen course slug, matching the bundled packs
    /// (verified against the Mac content on 2026-09-24). SavedView falls
    /// back to a lesson-id search if this ever drifts.
    private func packId(for courseSlug: String) -> String {
        switch courseSlug {
        case "french": "fr-foundations"
        case "italian": "it-foundations"
        case "german": "de-foundations"
        case "portuguese": "pt-foundations"
        case "spanish": "es-foundations"
        default: ""
        }
    }

    /// Loads the course pack vocabulary off the main thread so transcript
    /// target lines can offer tap-a-word glosses.
    private func loadVocabulary() async {
        let slug = track.courseSlug
        let map = await Task.detached(priority: .utility) {
            guard let pack = (try? PackLoader.loadPacks())?
                .first(where: { $0.language.slug == slug })
            else { return [String: VocabularyItem]() }
            return makeVocabularyMap(pack.vocabulary)
        }.value
        vocabularyByWord = map
    }

    private func resumeCard(_ resume: Double) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("You stopped at \(formatListenPosition(resume)).")
                    .font(DesignTokens.text(14))
                    .foregroundStyle(DesignTokens.ink)
                HStack {
                    Button("Resume") { model.play() }
                        .font(DesignTokens.text(15, weight: .semibold))
                        .foregroundStyle(DesignTokens.stock)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(DesignTokens.primary)
                        .cornerRadius(8)
                    Button("Start over") { model.startOver() }
                        .font(DesignTokens.text(15, weight: .semibold))
                        .foregroundStyle(DesignTokens.primary)
                }
            }
        }
    }

    private var failedCard: some View {
        PaperCard {
            Text("This track's audio file is missing from the app bundle.")
                .font(DesignTokens.text(14))
                .foregroundStyle(DesignTokens.attentionInk)
        }
    }

    /// Section headings jump the player when the transcript carries
    /// timings; older transcripts keep plain headings.
    @ViewBuilder
    private func sectionHeading(_ section: ListenSection) -> some View {
        if let start = section.startS {
            Button { model.seek(to: start) } label: {
                headingLabel(section, start: start)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Jump to \(section.heading)")
        } else {
            headingLabel(section, start: nil)
        }
    }

    private func headingLabel(_ section: ListenSection, start: Double?) -> some View {
        HStack(spacing: 6) {
            Text(section.heading)
                .font(DesignTokens.text(14, weight: .semibold))
                .foregroundStyle(DesignTokens.inkDeep)
            if let start {
                Text(formatListenPosition(start))
                    .font(DesignTokens.text(12, weight: .medium))
                    .foregroundStyle(DesignTokens.muted)
                    .monospacedDigit()
            }
            Spacer()
            if start != nil {
                Image(systemName: "play.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(DesignTokens.primary)
            }
        }
    }

    private var transcript: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Transcript")
                    .font(DesignTokens.display(18))
                    .foregroundStyle(DesignTokens.inkDeep)
                    .padding(.horizontal, 4)
                Spacer()
                if !ListenScenario.scenarioSections(track: track).isEmpty {
                    Button {
                        model.pause()
                        showingPractice = true
                    } label: {
                        Label("Practice", systemImage: "play.circle")
                            .font(DesignTokens.text(14, weight: .semibold))
                            .foregroundStyle(DesignTokens.primary)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 4)
                    .accessibilityLabel("Practice: listen, respond, compare")
                    .accessibilityHint(
                        "Walks through each target phrase: hear it, predict it, record yourself, then compare with a slow replay.")
                }
                if track.sections.contains(where: { $0.target != nil }) {
                    Button {
                        model.pause()
                        showingShadow = true
                    } label: {
                        Label("Shadow", systemImage: "speaker.wave.2.fill")
                            .font(DesignTokens.text(14, weight: .semibold))
                            .foregroundStyle(DesignTokens.primary)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 4)
                    .accessibilityLabel("Practice shadowing the target phrases")
                }
            }
            ForEach(sectionIndices, id: \.self) { index in
                sectionRow(track.sections[index])
            }
        }
        // Selectable so learners can copy phrases. Renders entirely from the
        // bundled transcript + audio — no network access.
        .textSelection(.enabled)
    }
}

// MARK: - Practice loop (P3.2): listen – respond – compare
//
// A guided section loop over the pure ListenScenario core. Per eligible
// section: plays the line once (listen), hides its target behind a reveal
// (choose), optionally records a take with the existing VoiceRecorder
// (respond), then replays the line at 0.75× (compare). The loop carries no
// score, grade, or accuracy state — the app never judges pronunciation.
//
// The sheet owns its own AVPlayer built from the bundled audio with its own
// periodic observer, so the main ListenPlayerModel's position, sleep timer,
// lock-screen controls, and resume point are never touched. The main player
// is paused (only) when the sheet opens, exactly like Shadow mode.

/// The practice sheet's isolated audio: its own AVPlayer plus the periodic
/// observer that stops a play window at its section end. The main
/// ListenPlayerModel is never mutated by this class.
@MainActor
private final class PracticeLoopPlayer: ObservableObject {
    /// Observer tick; fine enough to stop close to a section's end.
    private static let tick: TimeInterval = 0.1

    @Published private(set) var isPlaying = false
    @Published private(set) var failed = false

    /// Called once when a play window reaches its end on its own (or the
    /// track item finishes first). The view advances the loop from here —
    /// skips and teardown call `stop()` and never fire this.
    var onWindowEnded: (() -> Void)?

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var currentWindow: (start: Double, end: Double)?
    private var tornDown = false

    init(track: ListenTrack) {
        guard let url = MediaResolver.bundleURL(for: track.audioUrl) else {
            failed = true
            return
        }
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        // A short track may end before its window; pause, don't loop.
        player.actionAtItemEnd = .pause
        self.player = player

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: Self.tick, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in self?.checkWindow(time: time) }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleItemEnded() }
        }
    }

    /// Seeks to `start` and plays until `end` at the given rate. (Re)claims
    /// the audio session as playback so a prior VoiceRecorder record-compare
    /// cycle can't leave it in playAndRecord mode.
    func playWindow(start: Double, end: Double, rate: Float) {
        guard let player, !failed, end > start else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            // Best effort: the player may still produce sound.
        }
        currentWindow = (start, end)
        player.seek(
            to: CMTime(seconds: start, preferredTimescale: 600),
            toleranceBefore: .zero, toleranceAfter: .zero)
        player.defaultRate = rate
        player.play()
        isPlaying = true
    }

    /// Stops the current window without advancing (Skip, Close, teardown).
    /// Safe to call any time.
    func stop() {
        player?.pause()
        isPlaying = false
        currentWindow = nil
    }

    private func checkWindow(time: CMTime) {
        guard isPlaying, let window = currentWindow else { return }
        let current = time.secondsIfFinite ?? 0
        if current >= window.end {
            stop()
            onWindowEnded?()
        }
    }

    private func handleItemEnded() {
        // The item finished before the window's end (degenerate timing or
        // the very last section). Treat the item end as the window end.
        guard isPlaying else { return }
        stop()
        onWindowEnded?()
    }

    /// Stops playback and removes the observer. Called on sheet disappear so
    /// nothing keeps playing or leaks.
    func teardown() {
        guard !tornDown else { return }
        tornDown = true
        stop()
        if let timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        self.timeObserver = nil
        self.endObserver = nil
        player = nil
    }
}

/// The listen–respond–compare sheet. Drives a `ScenarioLoopState`; all step
/// transitions go through `advanceLoop()`, which only ever mutates the pure
/// loop state and never touches `ListenPlayerModel`.
struct PracticeLoopView: View {
    let track: ListenTrack

    @Environment(\.dismiss) private var dismiss
    @StateObject private var player: PracticeLoopPlayer
    @State private var loop: ScenarioLoopState
    @State private var recorder: VoiceRecorder?
    @State private var micSkipped: Bool

    init(track: ListenTrack) {
        self.track = track
        let micDenied = AVAudioApplication.shared.recordPermission == .denied
        let count = ListenScenario.scenarioSections(track: track).count
        _loop = State(initialValue: ScenarioLoopState(
            total: count, micUnavailable: micDenied))
        _player = StateObject(wrappedValue: PracticeLoopPlayer(track: track))
        _micSkipped = State(initialValue: micDenied)
    }

    private var sections: [ListenSection] {
        ListenScenario.scenarioSections(track: track)
    }

    private func currentSection() -> ListenSection? {
        guard sections.indices.contains(loop.currentSectionIndex) else { return nil }
        return sections[loop.currentSectionIndex]
    }

    private var stepName: String {
        switch loop.currentStep {
        case .line:
            return "Listen"
        case .choose:
            return "Choose"
        case .speak:
            return "Respond"
        case .model:
            return "Compare"
        case .done:
            return "Done"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.canvas.ignoresSafeArea()
                VStack(spacing: 18) {
                    header
                    Spacer()
                    stepContent
                    Spacer()
                    if micSkipped {
                        Text("Mic unavailable — recording is skipped.")
                            .font(DesignTokens.text(13))
                            .foregroundStyle(DesignTokens.muted)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .navigationTitle("Practice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                player.onWindowEnded = { self.advanceLoop() }
            }
            // The loop is the sole driver: every step change re-runs this
            // and plays exactly the right window (or stops) for the step.
            .task(id: loop) { handleStep() }
            .onDisappear {
                recorder?.discard()
                player.teardown()
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        if !loop.isDone {
            Text("\(stepName) \(loop.currentSectionIndex + 1) of \(loop.total)")
                .font(DesignTokens.text(13, weight: .semibold))
                .foregroundStyle(DesignTokens.primary)
                .textCase(.uppercase)
                .accessibilityLabel("\(stepName), section \(loop.currentSectionIndex + 1) of \(loop.total)")
        }
    }

    /// Enters the step: plays the listen/compare windows, or manages the
    /// recorder on the respond step. Auto-play steps advance themselves via
    /// the player's `onWindowEnded`.
    @MainActor
    private func handleStep() {
        switch loop.currentStep {
        case .line, .model:
            // Leaving respond must silence the recorder first: a take or the
            // synthesized course voice may still be playing, and would
            // otherwise overlap the line/compare window.
            discardRecorder()
            playCurrentWindow()
        case .speak:
            player.stop()
            makeRecorderIfNeeded()
            if AVAudioApplication.shared.recordPermission == .denied
                || recorder?.micUnavailable == true {
                // Quiet skip — never an alert.
                skipBecauseMicUnavailable()
            }
        case .choose, .done:
            player.stop()
            discardRecorder()
        }
    }

    @MainActor
    private func playCurrentWindow() {
        guard let section = currentSection(), let start = section.startS else { return }
        let end = ListenScenario.sectionEnd(for: loop.currentSectionIndex, in: track)
        // The compare step replays at the slow rate; listen runs at normal
        // speed. Pure helper, pinned by the tests.
        player.playWindow(
            start: start, end: end,
            rate: scenarioStepRate(for: loop.currentStep))
    }

    /// Only the pure loop state changes here; nothing else in the app.
    @MainActor
    private func advanceLoop() {
        loop.advance()
    }

    @MainActor
    private func skipBecauseMicUnavailable() {
        guard loop.currentStep == .speak else { return }
        micSkipped = true
        loop.advance()
    }

    /// One fresh disposable recorder per respond step, so the loop never
    /// offers a phrase with the previous section's target.
    @MainActor
    private func makeRecorderIfNeeded() {
        guard recorder == nil,
              let section = currentSection(),
              let target = section.target else { return }
        recorder = VoiceRecorder(
            target: target.text,
            languageCode: ShadowVoice.languageCode(for: track.courseSlug))
    }

    @MainActor
    private func discardRecorder() {
        recorder?.discard()
        recorder = nil
    }

    @ViewBuilder
    private var stepContent: some View {
        switch loop.currentStep {
        case .line:
            if player.failed {
                failedStepCard(title: "Listen")
            } else {
                VStack(spacing: 14) {
                    lineStepCard
                    PracticeSecondaryButton(title: "Skip") {
                        player.stop()
                        advanceLoop()
                    }
                    .accessibilityHint("Skips the rest of the line and continues.")
                }
            }
        case .choose:
            if let section = currentSection() {
                PracticeChooseStep(section: section) { advanceLoop() }
            }
        case .speak:
            if let section = currentSection(), let recorder {
                PracticeRespondStep(
                    recorder: recorder,
                    section: section,
                    onContinue: { advanceLoop() },
                    onMicUnavailable: { skipBecauseMicUnavailable() })
            }
        case .model:
            if player.failed {
                failedStepCard(title: "Compare")
            } else {
                VStack(spacing: 14) {
                    modelStepCard
                    PracticeSecondaryButton(title: "Skip replay") {
                        player.stop()
                        advanceLoop()
                    }
                    .accessibilityHint("Stops the slow replay and continues.")
                }
            }
        case .done:
            doneCard
        }
    }

    private var lineStepCard: some View {
        PracticeStepCard(title: "Listen") {
            VStack(alignment: .leading, spacing: 10) {
                if let section = currentSection() {
                    Text(section.heading)
                        .font(DesignTokens.text(15, weight: .semibold))
                        .foregroundStyle(DesignTokens.inkDeep)
                }
                Text("The line plays once — predict the target phrase before it's revealed.")
                    .font(DesignTokens.text(14))
                    .foregroundStyle(DesignTokens.ink)
                if player.isPlaying {
                    Label("Playing…", systemImage: "speaker.wave.2.fill")
                        .font(DesignTokens.text(13))
                        .foregroundStyle(DesignTokens.primary)
                }
            }
        }
    }

    private var modelStepCard: some View {
        PracticeStepCard(title: "Compare") {
            VStack(alignment: .leading, spacing: 10) {
                if let target = currentSection()?.target {
                    Text(target.text)
                        .font(DesignTokens.text(17, weight: .semibold))
                        .foregroundStyle(DesignTokens.primaryStrong)
                        .lineSpacing(4)
                    Text(target.meaning)
                        .font(DesignTokens.text(14))
                        .foregroundStyle(DesignTokens.muted)
                }
                Text("Now hear it again at a gentle pace — follow along and compare.")
                    .font(DesignTokens.text(14))
                    .foregroundStyle(DesignTokens.ink)
                if player.isPlaying {
                    Label("Playing at 0.75×…", systemImage: "speaker.wave.2.fill")
                        .font(DesignTokens.text(13))
                        .foregroundStyle(DesignTokens.primary)
                }
            }
        }
    }

    private func failedStepCard(title: String) -> some View {
        VStack(spacing: 14) {
            PracticeStepCard(title: title) {
                Text("This track's audio file is missing from the app bundle.")
                    .font(DesignTokens.text(14))
                    .foregroundStyle(DesignTokens.attentionInk)
            }
            PracticePrimaryButton(title: "Continue") {
                advanceLoop()
            }
        }
    }

    /// Plain completion: no score, no percentage, no accuracy claim.
    private var doneCard: some View {
        VStack(spacing: 16) {
            Text("Done")
                .font(DesignTokens.display(26))
                .foregroundStyle(DesignTokens.inkDeep)
            Text("The app never judges your pronunciation.")
                .font(DesignTokens.text(17, weight: .semibold))
                .foregroundStyle(DesignTokens.ink)
                .multilineTextAlignment(.center)
            Text("You listened to \(loop.total) sections, chose your answer, and compared with the slow replay. No score — just practice.")
                .font(DesignTokens.text(14))
                .foregroundStyle(DesignTokens.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
            PracticePrimaryButton(title: "Close") {
                dismiss()
            }
        }
    }
}

// MARK: - Practice step building blocks

/// PaperCard with the small uppercase caption used across the sheet.
private struct PracticeStepCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(DesignTokens.text(13, weight: .semibold))
                    .foregroundStyle(DesignTokens.muted)
                    .textCase(.uppercase)
                content
            }
        }
    }
}

/// Primary filled button used for Continue/Close.
private struct PracticePrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let systemImage {
                    Label(title, systemImage: systemImage)
                } else {
                    Text(title)
                }
            }
            .font(DesignTokens.text(16, weight: .semibold))
            .foregroundStyle(DesignTokens.stock)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(DesignTokens.primary)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

/// Quiet text button for skips.
private struct PracticeSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(DesignTokens.text(15, weight: .semibold))
            .foregroundStyle(DesignTokens.primary)
            .frame(minHeight: 44)
    }
}

/// The choose step mirrors ReviewCardView's recall contract: the target is
/// hidden behind a reveal, and there is no verdict — just an honest read.
private struct PracticeChooseStep: View {
    let section: ListenSection
    let onContinue: () -> Void

    @State private var revealed = false

    var body: some View {
        VStack(spacing: 16) {
            PracticeStepCard(title: "Choose") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(section.heading)
                        .font(DesignTokens.text(15, weight: .semibold))
                        .foregroundStyle(DesignTokens.inkDeep)
                    Text("Say it out loud or think it through, then reveal the answer.")
                        .font(DesignTokens.text(14))
                        .foregroundStyle(DesignTokens.ink)
                    if !revealed {
                        Button("Reveal answer") { revealed = true }
                            .font(DesignTokens.text(15, weight: .semibold))
                            .foregroundStyle(DesignTokens.primary)
                            .padding(.top, 2)
                            .frame(minHeight: 44)
                            .accessibilityHint("Shows the target phrase.")
                    } else if let target = section.target {
                        Text(target.text)
                            .font(DesignTokens.text(17, weight: .semibold))
                            .foregroundStyle(DesignTokens.primaryStrong)
                            .lineSpacing(4)
                        Text(target.meaning)
                            .font(DesignTokens.text(14))
                            .foregroundStyle(DesignTokens.muted)
                        Text("No grading — just your honest read.")
                            .font(DesignTokens.text(13))
                            .foregroundStyle(DesignTokens.muted)
                    }
                }
            }
            if revealed {
                PracticePrimaryButton(title: "Continue", systemImage: "arrow.right") {
                    onContinue()
                }
                .accessibilityHint("Shows your take, or moves on when the mic is unavailable.")
            }
        }
    }
}

/// The respond step: an optional record-and-compare for the current target,
/// always skippable. A mid-flow mic denial quietly skips straight to the
/// compare step through `onMicUnavailable` — never an alert.
private struct PracticeRespondStep: View {
    @ObservedObject var recorder: VoiceRecorder
    let section: ListenSection
    let onContinue: () -> Void
    let onMicUnavailable: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            PracticeStepCard(title: "Respond") {
                VStack(alignment: .leading, spacing: 10) {
                    if let target = section.target {
                        Text(target.text)
                            .font(DesignTokens.text(17, weight: .semibold))
                            .foregroundStyle(DesignTokens.primaryStrong)
                            .lineSpacing(4)
                        Text(target.meaning)
                            .font(DesignTokens.text(14))
                            .foregroundStyle(DesignTokens.muted)
                    }
                    Text("Your turn — say the phrase out loud. Recording is optional.")
                        .font(DesignTokens.text(14))
                        .foregroundStyle(DesignTokens.ink)
                    PracticeRecordButton(recorder: recorder)
                }
            }
            PracticePrimaryButton(title: "Continue", systemImage: "arrow.right") {
                onContinue()
            }
            .accessibilityHint("Stops any recording and replays the line slowly.")
        }
        .onChange(of: recorder.micUnavailable) { _, denied in
            if denied { onMicUnavailable() }
        }
    }
}

/// The respond step's record control — same contract and labels as
/// `RecordCompareButton`, but driven by the sheet's per-section recorder so
/// the loop can observe mic availability.
private struct PracticeRecordButton: View {
    @ObservedObject var recorder: VoiceRecorder

    var body: some View {
        Button {
            recorder.toggle()
        } label: {
            VStack(spacing: 1) {
                Image(systemName: recorder.phase == .recording ? "stop.circle" : "mic")
                    .font(.system(size: 15))
                    .foregroundStyle(
                        recorder.phase == .recording
                            ? DesignTokens.primary
                            : DesignTokens.muted)
                if recorder.phase == .yourTake || recorder.phase == .native {
                    Text(recorder.phase == .yourTake
                         ? "Your take" : "Course voice (synthesized)")
                        .font(DesignTokens.text(10))
                        .foregroundStyle(DesignTokens.muted)
                        .fixedSize()
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(buttonLabel)
        .accessibilityHint(
            recorder.micUnavailable
                ? "Mic unavailable"
                : "Records your take and plays it back with the course voice.")

    }

    private var buttonLabel: String {
        switch recorder.phase {
        case .idle:
            return "Record your pronunciation of \"\(recorder.target)\""
        case .recording:
            return "Stop recording"
        case .yourTake, .native:
            return "Stop playback"
        }
    }
}
