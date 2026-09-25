import AVFoundation
import MediaPlayer
import SwiftUI
import UIKit

// MARK: - Listen player model
//
// Audio-only lesson playback: play/pause, ±15s, scrubber, speed. Playback
// continues with the screen off (UIBackgroundModes audio + .playback session)
// with lock-screen controls via MPRemoteCommandCenter.
//
// Position honesty mirrors the web's position.ts: resume points under five
// seconds are stray taps, stopping within ten seconds of the end counts as
// finished, and a finished track is marked listened — heard, not mastered.

@MainActor
final class ListenPlayerModel: ObservableObject {
    static let skipSeconds = 15.0
    static let rates: [Float] = [1, 0.75, 1.25, 1.5]

    let track: ListenTrack
    let courseTitle: String

    @Published var isPlaying = false
    @Published var current: Double = 0
    @Published var duration: Double
    @Published var rate: Float = 1
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
            try AVAudioSession.sharedInstance().setActive(true)
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
            return
        }
        rate = Self.rates[(index + 1) % Self.rates.count]
        if isPlaying { player?.rate = rate }
        updateNowPlaying()
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
            MPMediaItemPropertyTitle: "\(track.lessonTitle) · audio lesson",
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
                            source: track.lessonTitle)
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
    }
}
