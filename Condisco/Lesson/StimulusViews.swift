import AVFoundation
import SwiftUI
import UIKit

// MARK: - Media resolution
//
// The packs reference media by web-style URLs such as
// `/audio/french-ordering/fr-ordering-politely-answer.wav`. The app bundle
// carries the same tree under `Content/`, so resolution is a bundle lookup.

enum MediaResolver {
    static func bundleURL(for mediaURL: String) -> URL? {
        let trimmed = mediaURL.hasPrefix("/") ? String(mediaURL.dropFirst()) : mediaURL
        let candidate = Bundle.main.bundleURL.appendingPathComponent("Content/" + trimmed)
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }
}

// MARK: - Lesson audio player

/// Minimal AVPlayer wrapper for lesson audio: play/pause, no autoplay.
/// Also offers a slowed-down pass for beginners — same audio, gentler pace.
final class LessonAudioPlayer: ObservableObject {
    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?
    @Published var isPlaying = false
    @Published var failed = false
    /// The URL currently loaded in the player, so per-phrase buttons can
    /// reflect playback state individually.
    @Published var currentURL: URL?
    /// The URL currently playing at slow speed, if any.
    @Published var slowURL: URL?

    /// Reduced playback rate for the slow pass.
    private static let slowRate: Float = 0.7

    func toggle(url: URL) {
        toggle(url: url, slow: false)
    }

    func toggleSlow(url: URL) {
        toggle(url: url, slow: true)
    }

    private func toggle(url: URL, slow: Bool) {
        if isPlaying {
            player?.pause()
            isPlaying = false
            return
        }
        if let current = player?.currentItem?.asset as? AVURLAsset,
           current.url == url {
            player?.play()
            if slow { player?.rate = Self.slowRate }
            isPlaying = true
            slowURL = slow ? url : nil
            return
        }
        failed = false
        currentURL = url
        slowURL = slow ? url : nil
        let item = AVPlayerItem(url: url)
        if slow {
            // Keep the voice natural at reduced speed (speech-tuned).
            item.audioTimePitchAlgorithm = .timeDomain
        }
        let player = AVPlayer(playerItem: item)
        self.player = player
        if let old = endObserver {
            NotificationCenter.default.removeObserver(old)
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            self?.isPlaying = false
            self?.currentURL = nil
            self?.slowURL = nil
        }
        // Surface load failures so the player can retry instead of
        // silently sitting on a dead item.
        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await item.asset.load(.isPlayable)
                player.play()
                if slow { player.rate = Self.slowRate }
                self.isPlaying = true
            } catch {
                self.failed = true
            }
        }
    }

    func stop() {
        player?.pause()
        player = nil
        isPlaying = false
        failed = false
        currentURL = nil
        slowURL = nil
    }

    deinit {
        if let old = endObserver {
            NotificationCenter.default.removeObserver(old)
        }
    }
}

// MARK: - Stimulus context

/// Renders the lesson's context stimulus above the activity, mirroring the
/// web player's context area: text with tappable glosses, dialogue threads,
/// audio with transcript, scenes, and example pairs.
struct StimulusContextView: View {
    let stimulus: Stimulus
    let pack: CoursePack
    /// The enclosing lesson, when known — used to label saved phrases
    /// with the lesson they came from.
    let lesson: Lesson? = nil
    let onAssist: (AssistanceKind) -> Void
    @ObservedObject var audioPlayer: LessonAudioPlayer

    private var vocabularyByWord: [String: VocabularyItem] {
        makeVocabularyMap(pack.vocabulary)
    }

    var body: some View {
        switch stimulus {
        case .text(_, let text, let translation):
            TextStimulusView(text: text, translation: translation,
                             vocabularyByWord: vocabularyByWord, onAssist: onAssist)
        case .examples(_, let pairs):
            ExamplesStimulusView(
                pairs: pairs,
                vocabularyByWord: vocabularyByWord,
                languageName: pack.language.displayName,
                languageSlug: pack.language.slug,
                pack: pack,
                lesson: lesson,
                audioPlayer: audioPlayer,
                onAssist: onAssist)
        case .audio(_, let mediaId):
            AudioStimulusView(pack: pack, mediaId: mediaId,
                              onAssist: onAssist, audioPlayer: audioPlayer)
        case .dialogue(_, let turns):
            DialogueStimulusView(turns: turns, vocabularyByWord: vocabularyByWord,
                                 onAssist: onAssist)
        case .scene(_, let mediaId, let alt, _, let textAlternative):
            SceneStimulusView(pack: pack, mediaId: mediaId, alt: alt,
                              textAlternative: textAlternative)
        }
    }
}

// MARK: Text (glossed reading)

struct TextStimulusView: View {
    let text: String
    let translation: String?
    let vocabularyByWord: [String: VocabularyItem]
    let onAssist: (AssistanceKind) -> Void

    @State private var translationShown = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GlossableText(text: text, vocabularyByWord: vocabularyByWord,
                          fontSize: 17, onGloss: { onAssist(.translation) })

            if let translation {
                if translationShown {
                    Text(translation)
                        .font(DesignTokens.text(15))
                        .foregroundStyle(DesignTokens.muted)
                } else {
                    StudioSecondaryButton("Show translation") {
                        translationShown = true
                        onAssist(.translation)
                    }
                }
            }
        }
    }
}

// MARK: Dialogue

struct DialogueStimulusView: View {
    let turns: [DialogueTurn]
    var vocabularyByWord: [String: VocabularyItem] = [:]
    let onAssist: (AssistanceKind) -> Void

    @State private var meaningsShown = false

    private var turnIndices: [Int] {
        Array(0..<turns.count)
    }

    private func turnRow(_ turn: DialogueTurn) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(turn.speaker)
                .font(DesignTokens.text(13, weight: .semibold))
                .foregroundStyle(DesignTokens.primaryStrong)
            GlossableText(text: turn.text, vocabularyByWord: vocabularyByWord,
                          fontSize: 16, onGloss: { onAssist(.translation) })
            if meaningsShown, let meaning = turn.meaning, !meaning.isEmpty {
                Text(meaning)
                    .font(DesignTokens.text(14))
                    .foregroundStyle(DesignTokens.muted)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.stock2)
        .cornerRadius(8)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(turnIndices, id: \.self) { index in
                    turnRow(turns[index])
                }
            }
            if turns.contains(where: { !($0.meaning ?? "").isEmpty }) && !meaningsShown {
                StudioSecondaryButton("Show meanings") {
                    meaningsShown = true
                    onAssist(.translation)
                }
            }
        }
    }
}

// MARK: Audio

struct AudioStimulusView: View {
    let pack: CoursePack
    let mediaId: String
    let onAssist: (AssistanceKind) -> Void
    @ObservedObject var audioPlayer: LessonAudioPlayer

    @State private var transcriptShown = false
    /// On-device course voice for steps whose recording is not part of the
    /// shipped content (or fails to play) — never a dead play control.
    @StateObject private var ttsSpeaker = ShadowSpeaker()
    @State private var ttsTarget: String? = nil

    private var media: MediaItem? {
        pack.media(id: mediaId)
    }

    private var transcript: String? {
        guard let media,
              case .audio(_, _, _, _, let transcript) = media,
              !transcript.isEmpty else { return nil }
        return transcript
    }

    private var audioURL: URL? {
        guard let media, case .audio(_, let url, _, _, _) = media else { return nil }
        return MediaResolver.bundleURL(for: url)
    }

    private var languageCode: String? {
        ShadowVoice.languageCode(for: pack.language.slug)
    }

    private var speakingTranscript: Bool {
        ttsSpeaker.isSpeaking && ttsTarget == transcript
    }

    /// Working alternative when the recorded audio is unavailable: reads the
    /// step's transcript with the synthesized course voice, clearly labeled.
    private var synthesizedAlternative: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let transcript {
                StudioSecondaryButton(speakingTranscript ? "Stop" : "Hear audio") {
                    if speakingTranscript {
                        ttsSpeaker.stop()
                        ttsTarget = nil
                    } else {
                        ttsTarget = transcript
                        ttsSpeaker.speak(transcript, languageCode: languageCode)
                    }
                }
                .accessibilityHint("Synthesized course voice")
                Text("Course voice (synthesized)")
                    .font(DesignTokens.text(12))
                    .foregroundStyle(DesignTokens.muted)
            } else {
                Text("A recording for this step isn't available yet.")
                    .font(DesignTokens.text(14))
                    .foregroundStyle(DesignTokens.attentionInk)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let url = audioURL {
                StudioSecondaryButton(audioPlayer.isPlaying ? "Pause audio" : "Play audio") {
                    audioPlayer.toggle(url: url)
                }
                if audioPlayer.failed {
                    Text("Audio could not play on this device. Try again.")
                        .font(DesignTokens.text(14))
                        .foregroundStyle(DesignTokens.attentionInk)
                    synthesizedAlternative
                }
            } else {
                synthesizedAlternative
            }

            if let transcript {
                if transcriptShown {
                    GlossableText(text: transcript,
                                  vocabularyByWord: makeVocabularyMap(pack.vocabulary),
                                  fontSize: 15,
                                  onGloss: { onAssist(.translation) })
                } else {
                    StudioSecondaryButton("Show transcript") {
                        transcriptShown = true
                        onAssist(.transcript)
                    }
                }
            }
        }
        .onDisappear {
            ttsSpeaker.stop()
            ttsTarget = nil
        }
    }
}

// MARK: Scene

struct SceneStimulusView: View {
    let pack: CoursePack
    let mediaId: String
    let alt: String
    let textAlternative: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let media = pack.media(id: mediaId),
               case .image(_, let url, _, _) = media,
               let bundleURL = MediaResolver.bundleURL(for: url),
               let uiImage = UIImage(contentsOfFile: bundleURL.path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(8)
                    .accessibilityLabel(alt)
            } else {
                Text(textAlternative.isEmpty ? alt : textAlternative)
                    .font(DesignTokens.text(15))
                    .foregroundStyle(DesignTokens.muted)
            }
        }
    }
}

// MARK: Examples

struct ExamplesStimulusView: View {
    let pairs: [ConceptExample]
    var vocabularyByWord: [String: VocabularyItem] = [:]
    var languageName: String = ""
    var languageSlug: String = ""
    var pack: CoursePack? = nil
    /// The enclosing lesson, when known — labels saved phrases with
    /// the lesson they came from.
    var lesson: Lesson? = nil
    var audioPlayer: LessonAudioPlayer? = nil
    var onAssist: (AssistanceKind) -> Void = { _ in }

    /// On-device voice for examples with no bundled audio.
    @StateObject private var ttsSpeaker = ShadowSpeaker()
    @State private var ttsTarget: String? = nil
    @State private var ttsSlowTarget: String? = nil
    @State private var playingAll = false
    @State private var playAllTask: Task<Void, Never>?

    private var languageCode: String? {
        ShadowVoice.languageCode(for: languageSlug)
    }

    private var pairIndices: [Int] {
        Array(0..<pairs.count)
    }

    /// True when at least one example has no bundled recording, so the
    /// "Hear them all" sequence will read part of the list with the
    /// on-device synthesized course voice.
    private var includesSynthesizedVoice: Bool {
        pairs.contains { audioURL(for: $0) == nil }
    }

    private func audioURL(for pair: ConceptExample) -> URL? {
        guard let mediaId = pair.mediaId,
              let media = pack?.media(id: mediaId),
              case .audio(_, let url, _, _, _) = media else { return nil }
        return MediaResolver.bundleURL(for: url)
    }

    private func isPlaying(url: URL) -> Bool {
        audioPlayer?.currentURL == url && (audioPlayer?.isPlaying ?? false)
    }

    private func isPlayingSlow(url: URL) -> Bool {
        audioPlayer?.slowURL == url && (audioPlayer?.isPlaying ?? false)
    }

    /// Plays every example in order — bundled audio when present,
    /// otherwise on-device TTS — until the list ends or the learner
    /// taps Stop.
    private func playAll() {
        stopPlayAll()
        playingAll = true
        playAllTask = Task {
            for pair in pairs {
                if Task.isCancelled { break }
                if let url = audioURL(for: pair) {
                    await playBundled(url: url)
                } else {
                    ttsSpeaker.speak(pair.target, languageCode: languageCode)
                    // Wait for speech to finish (approximate)
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                }
            }
            playingAll = false
        }
    }

    private func stopPlayAll() {
        playAllTask?.cancel()
        playAllTask = nil
        audioPlayer?.stop()
        ttsSpeaker.stop()
        if playingAll { playingAll = false }
    }

    @MainActor
    private func playBundled(url: URL) async {
        await withCheckedContinuation { continuation in
            let token = UUID()
            NotificationCenter.default.addObserver(
                forName: .condiscoAudioDidFinish,
                object: nil,
                queue: .main
            ) { _ in
                continuation.resume()
            }
            audioPlayer?.toggle(url: url)
            _ = token
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if pairs.count > 1 {
                VStack(alignment: .leading, spacing: 4) {
                    StudioSecondaryButton(playingAll ? "Stop" : "Hear them all") {
                        playingAll ? stopPlayAll() : playAll()
                    }
                    .accessibilityHint(includesSynthesizedVoice
                                       ? "Synthesized course voice" : "")
                    if includesSynthesizedVoice {
                        Text("Includes course voice (synthesized)")
                            .font(DesignTokens.text(12))
                            .foregroundStyle(DesignTokens.muted)
                    }
                }
                .padding(.bottom, 4)
            }
            ForEach(pairs, id: \.self) { pair in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 8) {
                        GlossableText(text: pair.target, vocabularyByWord: vocabularyByWord,
                                      fontSize: 16, fontWeight: .medium,
                                      onGloss: { onAssist(.translation) })
                        Spacer()
                        HStack(spacing: 14) {
                            if let audioURL = audioURL(for: pair) {
                                let playing = isPlaying(url: audioURL)
                                Button {
                                    stopPlayAll()
                                    audioPlayer?.toggle(url: audioURL)
                                } label: {
                                    Image(systemName: playing
                                          ? "speaker.wave.2.fill" : "speaker.wave.2")
                                        .font(.system(size: 15))
                                        .foregroundStyle(DesignTokens.primaryStrong)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(
                                    (playing ? "Pause" : "Hear")
                                    + " pronunciation of \"\(pair.target)\"")
                                let playingSlow = isPlayingSlow(url: audioURL)
                                Button {
                                    stopPlayAll()
                                    audioPlayer?.toggleSlow(url: audioURL)
                                } label: {
                                    Image(systemName: playingSlow
                                          ? "tortoise.fill" : "tortoise")
                                        .font(.system(size: 15))
                                        .foregroundStyle(playingSlow
                                                         ? DesignTokens.primary
                                                         : DesignTokens.muted)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(
                                    (playingSlow ? "Pause" : "Hear")
                                    + " \"\(pair.target)\" slowly")
                            } else {
                                // No bundled audio: speak it on-device with
                                // the course voice. Never a dead row.
                                let speaking = ttsSpeaker.isSpeaking && ttsTarget == pair.target
                                Button {
                                    stopPlayAll()
                                    if speaking {
                                        ttsSpeaker.stop()
                                        ttsTarget = nil
                                    } else {
                                        ttsTarget = pair.target
                                        ttsSlowTarget = nil
                                        ttsSpeaker.speak(pair.target, languageCode: languageCode)
                                    }
                                } label: {
                                    Image(systemName: speaking
                                          ? "speaker.wave.2.fill" : "speaker.wave.2")
                                        .font(.system(size: 15))
                                        .foregroundStyle(DesignTokens.primaryStrong)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(
                                    (speaking ? "Stop" : "Hear")
                                    + " pronunciation of \"\(pair.target)\"")
                                .accessibilityHint("Synthesized course voice")
                                let speakingSlow = ttsSpeaker.isSpeaking
                                    && ttsSlowTarget == pair.target
                                Button {
                                    stopPlayAll()
                                    if speakingSlow {
                                        ttsSpeaker.stop()
                                        ttsSlowTarget = nil
                                    } else {
                                        ttsSlowTarget = pair.target
                                        ttsTarget = nil
                                        ttsSpeaker.speak(
                                            pair.target, languageCode: languageCode,
                                            slow: true)
                                    }
                                } label: {
                                    Image(systemName: speakingSlow
                                          ? "tortoise.fill" : "tortoise")
                                        .font(.system(size: 15))
                                        .foregroundStyle(speakingSlow
                                                         ? DesignTokens.primary
                                                         : DesignTokens.muted)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(
                                    (speakingSlow ? "Stop" : "Hear")
                                    + " \"\(pair.target)\" slowly")
                                .accessibilityHint("Synthesized course voice")
                            }
                            PhraseSaveButton(
                                phrase: ShareablePhrase(
                                    target: pair.target,
                                    meaning: pair.meaning,
                                    languageName: languageName),
                                languageSlug: languageSlug,
                                source: lesson?.title ?? "",
                                sourcePackId: pack?.id ?? "",
                                sourceLessonId: lesson?.id ?? "")
                            PhraseShareButton(phrase: ShareablePhrase(
                                target: pair.target,
                                meaning: pair.meaning,
                                languageName: languageName))
                            RecordCompareButton(
                                target: pair.target,
                                languageCode: languageCode)
                        }
                    }
                    if audioURL(for: pair) == nil {
                        Text("Course voice (synthesized)")
                            .font(DesignTokens.text(12))
                            .foregroundStyle(DesignTokens.muted)
                    }
                    Text(pair.meaning)
                        .font(DesignTokens.text(15))
                        .foregroundStyle(DesignTokens.muted)
                }
            }
        }
        .onDisappear { stopPlayAll(); ttsSpeaker.stop() }
    }
}

// MARK: - Sustained reading & listening (Phase 6.1B)
//
// The presentation lane for a lesson step that binds a sustained passage.
// A host step carries `sustainedTextId` or `sustainedListeningId` alongside
// its (launch, information) activity; the lesson player renders this lane in
// place of the standard step slide, and the step's Continue button remains
// the only way onward — the lesson graph, completion discipline, checkpoint
// resume, and the store are all untouched.
//
// Honesty rules held throughout:
//   · Every listening section is synthesised on the device — always labelled
//     as such, never presented as a human recording.
//   · A declared voice is a preference, never a requirement: when it is not
//     installed, any installed voice of the same language reads the section,
//     and a device with no matching voice falls back to the language's system
//     voice. A missing voice can never fail a section.
//   · Comprehension answers reveal only after submission, using the same
//     deterministic set-equality grading the engine and the checkpoint
//     reading items use. Nothing here is open auto-graded, and no score,
//     level, or proficiency claim is ever derived.
//   · The phrasebook save button writes through the real save API
//     (`LearningStore.savePhrase`), never a novel store path.

// MARK: Pure decision helpers (pinned by tests)

/// Whether a sustained-material answer matches the accepted option(s) — the
/// same deterministic set-equality rule the engine's selection grading and
/// the checkpoint reading items use. The pilot questions are single-answer;
/// the rule still honours a multiple-accepted question honestly.
func sustainedQuestionCorrect(_ question: SustainedQuestion,
                              selectedIds: [String]) -> Bool {
    !selectedIds.isEmpty && Set(selectedIds) == Set(question.acceptedIds)
}

/// One sustained question's result, for the post-submission reveal.
struct SustainedQuestionResult {
    let question: SustainedQuestion
    let selectedOptionId: String?
    let selectedOptionText: String?
    let correct: Bool
}

/// Every question's result, in authored order — produced only from a stated
/// selection map after submission, so nothing pre-answer every renders.
func sustainedQuestionResults(questions: [SustainedQuestion],
                              selections: [String: String]) -> [SustainedQuestionResult] {
    questions.map { question in
        let chosen = selections[question.id]
        return SustainedQuestionResult(
            question: question,
            selectedOptionId: chosen,
            selectedOptionText: question.options.first { $0.id == chosen }?.text,
            correct: chosen.map { sustainedQuestionCorrect(question, selectedIds: [$0]) }
                ?? false)
    }
}

/// In-flight answer state for the three embedded questions. `answersSubmitted`
/// gates every reveal: selections lock and results first become available
/// only once it flips. Pure value type, pinned by the unit tests.
struct SustainedAnswersState: Equatable {
    private(set) var selections: [String: String] = [:]
    private(set) var answersSubmitted = false

    mutating func select(_ optionId: String, for questionId: String) {
        guard !answersSubmitted else { return }
        selections[questionId] = optionId
    }

    mutating func submit() {
        answersSubmitted = true
    }

    /// Whether every question has an answer — the Check button's gate.
    func isComplete(_ questions: [SustainedQuestion]) -> Bool {
        questions.allSatisfy { selections[$0.id] != nil }
    }
}

/// Transcript-visibility state machine for a sustained listening passage:
/// the transcript is hidden through the first full pass (every section heard
/// once) and may be deliberately revealed at any time — the explicit reveal
/// is the learner's call, never an automatic one during the first pass.
/// Pure value type, pinned by the unit tests.
struct SustainedTranscriptState: Equatable {
    let sectionCount: Int
    private(set) var playedSections: Set<Int> = []
    private(set) var explicitlyRevealed = false

    init(sectionCount: Int) {
        self.sectionCount = sectionCount
    }

    /// The whole passage has played through (every section reached its end).
    var firstPassComplete: Bool {
        sectionCount > 0 && playedSections.count >= sectionCount
    }

    /// The transcript may be inspected after the first full pass, or from a
    /// deliberate reveal.
    var isRevealed: Bool {
        explicitlyRevealed || firstPassComplete
    }

    mutating func markPlayed(_ index: Int) {
        guard index >= 0, index < sectionCount else { return }
        playedSections.insert(index)
    }

    mutating func reveal() {
        explicitlyRevealed = true
    }
}

/// One installed speech voice as the resolver sees it: identifier + language
/// tag. Kept as a plain value so the resolution rules are unit-testable
/// without touching the live TTS catalogue.
struct InstalledVoice: Equatable {
    let identifier: String
    let language: String
}

/// Offline voice resolution for a sustained listening section. The declared
/// voice id is a *preference* (the schema documents this): when exactly that
/// identifier is installed it is used; otherwise ANY installed voice whose
/// language matches the section's language root ("es-ES" and "es-MX" both
/// match "es") reads the section — the same language-root rule ShadowSpeaker
/// uses app-wide. Nil means no installed voice of the language exists; the
/// renderer then falls back to `AVSpeechSynthesisVoice(language:)` and
/// finally the system default, so a missing voice never fails a section.
enum SustainedVoiceResolver {
    static func resolve(declaredVoiceId: String,
                        languageCode: String,
                        installed: [InstalledVoice]) -> String? {
        if let exact = installed.first(where: { $0.identifier == declaredVoiceId }) {
            return exact.identifier
        }
        let root = String(languageCode.prefix(2)).lowercased()
        return installed.first { $0.language.lowercased().hasPrefix(root) }?.identifier
    }

    /// The declared voices that are absent from this device, recorded once in
    /// declared order — an in-memory diagnostic surfaced in the view state
    /// (never a store event).
    static func missingVoices(declaredVoiceIds: [String],
                              installed: [InstalledVoice]) -> [String] {
        let installedIdentifiers = Set(installed.map(\.identifier))
        var seen = Set<String>()
        return declaredVoiceIds.filter {
            !installedIdentifiers.contains($0) && seen.insert($0).inserted
        }
    }
}

// MARK: Sustained TTS speaker

/// The per-section speech engine for one sustained listening passage. Each
/// section speaks as its own utterance with its resolved voice at the app's
/// TTS pace (ShadowSpeaker's normal 0.92× default) or the gentle slow pace
/// (0.55×). Mirrors the existing audio surfaces: the AVAudioSession is
/// re-asserted as plain `.playback` before each utterance (ListenPlayerModel's
/// pattern, so a prior record-and-compare cycle can't leave it misrouted),
/// and every natural completion or cancellation fires `onFinish` with its
/// cause, keyed to the utterance — a superseded cancel can never advance or
/// deadlock a caller that already moved on.
@MainActor
final class SustainedListener: ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    private let delegate = SustainedListenerDelegate()
    /// Normal pace for the app's on-device TTS (ShadowSpeaker's 0.92).
    static let normalRate: Float = AVSpeechUtteranceDefaultSpeechRate * 0.92
    /// Gentler pace for slow replays (ShadowSpeaker's 0.55).
    static let slowRate: Float = AVSpeechUtteranceDefaultSpeechRate * 0.55

    @Published private(set) var isSpeaking = false
    /// Fired once per utterance with whether it reached its natural end.
    /// Set right before `speak`, cleared by the caller once the callback ran.
    var onFinish: ((Bool) -> Void)?

    private var activeUtterance: AVSpeechUtterance?

    init() {
        synthesizer.delegate = delegate
        delegate.onFinish = { [weak self] utterance, completed in
            Task { @MainActor in
                guard let self, utterance === self.activeUtterance else { return }
                self.isSpeaking = false
                self.activeUtterance = nil
                self.onFinish?(completed)
            }
        }
    }

    func speak(_ text: String, voice: AVSpeechSynthesisVoice?,
               languageCode: String, slow: Bool) {
        stopSpeaking()
        do {
            // Re-assert plain playback (ListenPlayerModel's pattern) so a
            // prior record-and-compare cycle can't leave the session in
            // playAndRecord mode.
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            // Best effort: TTS still produces sound in the foreground.
        }
        let utterance = AVSpeechUtterance(string: text)
        if let voice {
            utterance.voice = voice
        } else if let languageVoice = AVSpeechSynthesisVoice(language: languageCode) {
            utterance.voice = languageVoice
        }
        // else: system default voice — never a dead section.
        utterance.rate = slow ? Self.slowRate : Self.normalRate
        activeUtterance = utterance
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        stopSpeaking()
        // Cancellation also fires the delegate (keyed to the utterance), so
        // nothing awaiting a finish can hang.
    }

    private func stopSpeaking() {
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }
}

private final class SustainedListenerDelegate: NSObject, AVSpeechSynthesizerDelegate {
    var onFinish: ((AVSpeechUtterance, Bool) -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didFinish utterance: AVSpeechUtterance) {
        onFinish?(utterance, true)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didCancel utterance: AVSpeechUtterance) {
        onFinish?(utterance, false)
    }
}

// MARK: Glossary lookup + save-to-review

/// A glossary entry selected for inspection. Wraps the value so the popover
/// can key on the term (the pack guarantees unique terms per passage).
private struct SelectedGlossaryEntry: Identifiable {
    let entry: SustainedGlossaryEntry
    var id: String { entry.term }
}

/// The lookup + save surface for a passage's glossary: every term is a
/// button; tapping opens a non-modal popover with the term, its definition,
/// the usage note when authored, and a save-to-review toggle that writes
/// through the phrasebook's real save API — never a store event, never a
/// navigation, and nothing is paused or covered by a modal.
struct SustainedGlossaryPanel: View {
    let glossary: [SustainedGlossaryEntry]
    var title: String = "Words in this passage"
    let languageSlug: String
    let languageName: String
    let source: String
    let sourcePackId: String
    let sourceLessonId: String

    @State private var selected: SelectedGlossaryEntry?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(DesignTokens.text(14, weight: .semibold))
                .foregroundStyle(DesignTokens.inkDeep)
            Text("Tap a word for its meaning and a save-to-review shortcut. "
                 + "Nothing here navigates away or interrupts the passage.")
                .font(DesignTokens.text(13))
                .foregroundStyle(DesignTokens.muted)
            ForEach(glossary, id: \.term) { entry in
                Button {
                    selected = SelectedGlossaryEntry(entry: entry)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Text(entry.term)
                            .font(DesignTokens.text(15, weight: .medium))
                            .foregroundStyle(DesignTokens.primaryStrong)
                            .underline()
                        Spacer()
                        Text(entry.definition)
                            .font(DesignTokens.text(14))
                            .foregroundStyle(DesignTokens.muted)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DesignTokens.stock2)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Explain \(entry.term)")
                .accessibilityHint("Opens \(entry.term): meaning, usage, save to review")
            }
        }
        .popover(item: $selected,
                 attachmentAnchor: .rect(.bounds),
                 arrowEdge: .top) { selection in
            SustainedGlossaryPopover(
                entry: selection.entry,
                languageSlug: languageSlug,
                languageName: languageName,
                source: source,
                sourcePackId: sourcePackId,
                sourceLessonId: sourceLessonId)
                .presentationCompactAdaptation(.popover)
        }
    }
}

/// The popover body: term, definition, usage note, and the phrasebook
/// toggle — the exact save path `PhraseSaveButton` uses.
private struct SustainedGlossaryPopover: View {
    let entry: SustainedGlossaryEntry
    let languageSlug: String
    let languageName: String
    let source: String
    let sourcePackId: String
    let sourceLessonId: String

    @State private var saved = false

    private var phraseId: String {
        LearningStore.savedPhraseId(
            languageSlug: languageSlug,
            target: entry.term,
            meaning: entry.definition)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(entry.term)
                .font(DesignTokens.text(17, weight: .semibold))
                .foregroundStyle(DesignTokens.inkDeep)
            Text(entry.definition)
                .font(DesignTokens.text(15))
                .foregroundStyle(DesignTokens.ink)
            if let note = entry.usageNote, !note.isEmpty {
                Text(note)
                    .font(DesignTokens.text(14))
                    .foregroundStyle(DesignTokens.muted)
                    .italic()
            }
            Button {
                toggleSave()
            } label: {
                Label(saved ? "Saved to review" : "Save to review",
                      systemImage: saved ? "bookmark.fill" : "bookmark")
                    .font(DesignTokens.text(15, weight: .semibold))
                    .foregroundStyle(DesignTokens.stock)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(DesignTokens.primary)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(saved ? "Remove from phrasebook" : "Save to review")
        }
        .padding(16)
        .frame(minWidth: 240, maxWidth: 320)
        .task { saved = (try? LearningStore.inDocuments().isPhraseSaved(id: phraseId)) ?? false }
    }

    /// Writes through the phrasebook's real save API (`LearningStore
    /// .savePhrase` / `unsavePhrase`), exactly like every other bookmark in
    /// the app. A deterministic id makes re-saving a no-op.
    private func toggleSave() {
        Task { @MainActor in
            do {
                let store = try LearningStore.inDocuments()
                if saved {
                    try store.unsavePhrase(id: phraseId)
                    saved = false
                } else {
                    try store.savePhrase(SavedPhrase(
                        id: phraseId,
                        languageSlug: languageSlug,
                        languageName: languageName,
                        target: entry.term,
                        meaning: entry.definition,
                        source: source,
                        sourcePackId: sourcePackId,
                        sourceLessonId: sourceLessonId,
                        savedAt: Date()))
                    saved = true
                }
            } catch {
                // Quiet: the toggle simply doesn't change state.
            }
        }
    }
}

// MARK: Passage body (reading)

/// Passage body with glossary terms marked inline. One `Text` per paragraph
/// (never per-word buttons): Dynamic Type recomputes the whole paragraph
/// (no clipping), VoiceOver reads it as flowing text in document order, and
/// the glossary panel below stays the tap surface — lookup never interrupts
/// reading. Marking is cosmetic (best-effort, inflected forms may not match);
/// the glossary panel is the authoritative lookup.
struct SustainedGlossedBody: View {
    let text: String
    let glossary: [SustainedGlossaryEntry]

    private var marked: AttributedString {
        var attributed = AttributedString(text)
        for entry in glossary {
            var cursor = attributed.startIndex
            while cursor < attributed.endIndex {
                let slice = attributed[cursor...]
                guard let range = slice.range(
                    of: entry.term, options: [.caseInsensitive]) else { break }
                // Underline is drawn in the text's own color, so the
                // primaryStrong foreground above already tints it; there is
                // no SwiftUI-renderable underlineColor attribute, and the
                // UIKit/AppKit-scope one is not honoured by Text.
                attributed[range].foregroundColor = DesignTokens.primaryStrong
                attributed[range].underlineStyle = .single
                cursor = range.upperBound
            }
        }
        return attributed
    }

    var body: some View {
        Text(marked)
            .font(DesignTokens.text(17))
            .foregroundStyle(DesignTokens.ink)
            .lineSpacing(4)
            .textSelection(.enabled)
    }
}

// MARK: Embedded questions

/// The three authored questions with the reveal discipline: options render
/// now; results render only after "Check answers" — never before. Graded
/// with the deterministic set-equality rule, exactly like checkpoint reading.
struct SustainedQuestionsCard: View {
    let questions: [SustainedQuestion]
    let sourceIsListening: Bool
    @Binding var answers: SustainedAnswersState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(SustainedCopy.questionsHeading)
                .font(DesignTokens.text(14, weight: .semibold))
                .foregroundStyle(DesignTokens.inkDeep)
            ForEach(questions, id: \.id) { question in
                VStack(alignment: .leading, spacing: 6) {
                    Text(question.question)
                        .font(DesignTokens.text(16, weight: .medium))
                        .foregroundStyle(DesignTokens.inkDeep)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(question.options, id: \.id) { option in
                        OptionRow(
                            text: option.text,
                            selected: answers.selections[question.id] == option.id,
                            multi: false,
                            disabled: answers.answersSubmitted
                        ) {
                            answers.select(option.id, for: question.id)
                        }
                    }
                }
                .padding(.top, 4)
            }

            if !answers.answersSubmitted {
                StudioPrimaryButton(
                    label: SustainedCopy.checkAnswers,
                    disabled: !answers.isComplete(questions)
                ) {
                    answers.submit()
                }
                if !answers.isComplete(questions) {
                    Text(SustainedCopy.answerAllFirst)
                        .font(DesignTokens.text(13))
                        .foregroundStyle(DesignTokens.muted)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } else {
                SustainedResultsView(
                    results: sustainedQuestionResults(
                        questions: questions, selections: answers.selections),
                    sourceIsListening: sourceIsListening)
            }
        }
    }
}

/// Post-submission results: each question names the chosen answer, whether it
/// matches the accepted option, and the correct answer for a miss. Rendered
/// only from a submitted state, in authored order.
struct SustainedResultsView: View {
    let results: [SustainedQuestionResult]
    /// Copy source: the reading passage vs the listening passage.
    let sourceIsListening: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(results, id: \.question.id) { result in
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.question.question)
                        .font(DesignTokens.text(15, weight: .semibold))
                        .foregroundStyle(DesignTokens.inkDeep)
                    if let chosen = result.selectedOptionText {
                        Text("Your answer: \(chosen)")
                            .font(DesignTokens.text(14))
                            .foregroundStyle(DesignTokens.muted)
                    }
                    Text(result.correct ? correctLine : incorrectLine)
                        .font(DesignTokens.text(14))
                        .foregroundStyle(result.correct
                                         ? DesignTokens.correctLine
                                         : DesignTokens.attentionInk)
                    if !result.correct,
                       let answerText = result.question.options
                        .first(where: { result.question.acceptedIds.contains($0.id) })?.text {
                        Text("The answer is: \(answerText)")
                            .font(DesignTokens.text(14, weight: .medium))
                            .foregroundStyle(DesignTokens.ink)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignTokens.stock2)
                .cornerRadius(8)
            }
        }
    }

    private var correctLine: String {
        sourceIsListening ? SustainedCopy.listeningCorrect
            : SustainedCopy.readingCorrect
    }

    private var incorrectLine: String {
        sourceIsListening ? SustainedCopy.listeningIncorrect
            : SustainedCopy.readingIncorrect
    }
}

// MARK: Sustained reading experience

/// Full-screen readable presentation of a sustained reading passage: the
/// multi-paragraph text with its section markers/headings, the glossary
/// lookup + save-to-review panel (below the passage, never interrupting it),
/// then the three authored questions with results revealed only after
/// submission. VoiceOver reads the passage in document order with section
/// headings as headers and `accessibleSummary` on the container.
struct SustainedReadingExperienceView: View {
    let passage: SustainedText
    let pack: CoursePack
    /// The launch step's authored body — the brief shown above the material.
    var launchInstructions: String = ""
    var lessonTitle: String = ""
    var sourcePackId: String = ""
    var sourceLessonId: String = ""

    @State private var answers = SustainedAnswersState()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !launchInstructions.isEmpty {
                Text(launchInstructions)
                    .font(DesignTokens.text(14))
                    .foregroundStyle(DesignTokens.muted)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DesignTokens.stock2)
                    .cornerRadius(8)
            }

            VStack(alignment: .leading, spacing: 14) {
                Text(passage.title)
                    .font(DesignTokens.display(24))
                    .foregroundStyle(DesignTokens.inkDeep)
                    .accessibilityAddTraits(.isHeader)
                Text(genreLine)
                    .font(DesignTokens.text(12, weight: .semibold))
                    .foregroundStyle(DesignTokens.primary)
                    .textCase(.uppercase)
                Text(provenanceLine)
                    .font(DesignTokens.text(12))
                    .foregroundStyle(DesignTokens.muted)

                ForEach(passage.sections, id: \.marker) { section in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text(section.marker)
                                .font(DesignTokens.text(12, weight: .semibold))
                                .foregroundStyle(DesignTokens.muted)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(DesignTokens.stock3)
                                .cornerRadius(6)
                                .accessibilityHidden(true)
                            Text(section.heading)
                                .font(DesignTokens.text(16, weight: .semibold))
                                .foregroundStyle(DesignTokens.inkDeep)
                                .accessibilityAddTraits(.isHeader)
                        }
                        SustainedGlossedBody(text: section.body, glossary: passage.glossary)
                    }
                    .padding(.top, 2)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(Text(section.accessibilityLabel))
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text(passage.accessibleSummary))

            SustainedGlossaryPanel(
                glossary: passage.glossary,
                languageSlug: pack.language.slug,
                languageName: pack.language.displayName,
                source: lessonTitle,
                sourcePackId: sourcePackId,
                sourceLessonId: sourceLessonId)

            SustainedQuestionsCard(
                questions: passage.questions,
                sourceIsListening: false,
                answers: $answers)
        }
    }

    private var genreLine: String {
        switch passage.genre {
        case .messageThread: return "Message thread"
        case .shortArticle: return "Short article"
        case .personalNarrative: return "Personal narrative"
        }
    }

    private var provenanceLine: String {
        "\(passage.provenance.statement) — written \(passage.provenance.date)."
    }
}

// MARK: Sustained listening experience

/// The sustained listening step: every section is synthesised on the device
/// with its declared voice when installed (falling back offline to any
/// installed voice of the same language, or the language's system voice), the
/// transcript stays hidden through the first full pass, per-section replays
/// run at normal or slow speed, and the three questions reveal only after
/// submission. The section currently speaking is highlighted in the
/// transcript, so following along after the reveal is free — no timing data
/// is ever fabricated.
struct SustainedListeningExperienceView: View {
    let passage: SustainedListening
    let pack: CoursePack
    var launchInstructions: String = ""
    var lessonTitle: String = ""
    var sourcePackId: String = ""
    var sourceLessonId: String = ""

    @StateObject private var listener = SustainedListener()
    @State private var transcript = SustainedTranscriptState(sectionCount: 0)
    @State private var answers = SustainedAnswersState()
    @State private var currentSection: Int?
    @State private var slowSection: Int?
    /// In-memory diagnostics: declared voices missing from this device —
    /// surfaced in a subtle line, never a store event.
    @State private var missingDeclaredVoiceIds: [String] = []
    @State private var playAllTask: Task<Void, Never>?
    @State private var playingAll = false

    private var sectionIndices: [Int] {
        Array(0..<passage.sections.count)
    }

    private var installedVoices: [InstalledVoice] {
        AVSpeechSynthesisVoice.speechVoices().map {
            InstalledVoice(identifier: $0.identifier, language: $0.language)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !launchInstructions.isEmpty {
                Text(launchInstructions)
                    .font(DesignTokens.text(14))
                    .foregroundStyle(DesignTokens.muted)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DesignTokens.stock2)
                    .cornerRadius(8)
            }

            VStack(alignment: .leading, spacing: 14) {
                Text(passage.title)
                    .font(DesignTokens.display(24))
                    .foregroundStyle(DesignTokens.inkDeep)
                    .accessibilityAddTraits(.isHeader)
                Text(SustainedCopy.synthesisedNote(pack.language.displayName))
                    .font(DesignTokens.text(12))
                    .foregroundStyle(DesignTokens.muted)
                    .accessibilityLabel(SustainedCopy.synthesisedNote(pack.language.displayName))
                Text(provenanceLine)
                    .font(DesignTokens.text(12))
                    .foregroundStyle(DesignTokens.muted)

                transport

                sectionList
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text(passage.accessibleSummary))

            transcriptCard

            SustainedGlossaryPanel(
                glossary: passage.glossary,
                title: "Words in this call",
                languageSlug: pack.language.slug,
                languageName: pack.language.displayName,
                source: lessonTitle,
                sourcePackId: sourcePackId,
                sourceLessonId: sourceLessonId)

            SustainedQuestionsCard(
                questions: passage.questions,
                sourceIsListening: true,
                answers: $answers)
        }
        .onAppear {
            transcript = SustainedTranscriptState(sectionCount: passage.sections.count)
            recordMissingVoices()
        }
        .onDisappear { stopPlayback() }
    }

    private var provenanceLine: String {
        "\(passage.provenance.statement) — written \(passage.provenance.date)."
    }

    // MARK: Transport

    private var transport: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !missingDeclaredVoiceIds.isEmpty {
                Text(missingVoiceLine)
                    .font(DesignTokens.text(12))
                    .foregroundStyle(DesignTokens.muted)
            }
            HStack(spacing: 10) {
                StudioSecondaryButton(playingAll ? SustainedCopy.stopPlayback
                    : SustainedCopy.playFirstPass) {
                    playingAll ? stopPlayback() : playAll()
                }
                .accessibilityHint(SustainedCopy.synthesisedHint)
            }
            if let current = currentSection {
                Text("Playing section \(current + 1) of \(passage.sections.count) — "
                     + passage.sections[current].heading)
                    .font(DesignTokens.text(13, weight: .medium))
                    .foregroundStyle(DesignTokens.primary)
            }
        }
    }

    /// Subtle, honest recording of which declared voices this device lacks —
    /// always visible so the fallback is never a silent surprise.
    private var missingVoiceLine: String {
        let names = missingDeclaredVoiceIds.joined(separator: ", ")
        return "Declared voice\(missingDeclaredVoiceIds.count == 1 ? "" : "s") not installed "
            + "on this device (\(names)) — a \(pack.language.displayName) voice on this "
            + "device reads those sections instead."
    }

    // MARK: Section list

    private var sectionList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(sectionIndices, id: \.self) { index in
                sectionRow(index)
            }
        }
    }

    private func sectionRow(_ index: Int) -> some View {
        let section = passage.sections[index]
        let playing = currentSection == index
        let slow = slowSection == index
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(section.heading)
                        .font(DesignTokens.text(15, weight: .semibold))
                        .foregroundStyle(DesignTokens.inkDeep)
                        .accessibilityAddTraits(.isHeader)
                    if transcript.playedSections.contains(index) {
                        Label(SustainedCopy.playedLabel, systemImage: "checkmark.circle")
                            .font(DesignTokens.text(12))
                            .foregroundStyle(DesignTokens.muted)
                    }
                }
                Spacer()
                HStack(spacing: 14) {
                    Button {
                        if playing && !slow {
                            stopPlayback()
                        } else {
                            playSingle(index, slow: false)
                        }
                    } label: {
                        Image(systemName: playing && !slow
                              ? "speaker.wave.2.fill" : "speaker.wave.2")
                            .font(.system(size: 15))
                            .foregroundStyle(DesignTokens.primaryStrong)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel((playing && !slow ? "Stop" : "Hear")
                                        + " section \(index + 1) at normal speed")
                    .accessibilityHint(SustainedCopy.synthesisedHint)

                    Button {
                        if playing && slow {
                            stopPlayback()
                        } else {
                            playSingle(index, slow: true)
                        }
                    } label: {
                        Image(systemName: playing && slow ? "tortoise.fill" : "tortoise")
                            .font(.system(size: 15))
                            .foregroundStyle(playing && slow
                                             ? DesignTokens.primary
                                             : DesignTokens.muted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel((playing && slow ? "Stop" : "Hear")
                                        + " section \(index + 1) slowly")
                    .accessibilityHint(SustainedCopy.synthesisedHint)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(playing ? DesignTokens.primarySoft : DesignTokens.stock)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(DesignTokens.edgeSoft, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(section.accessibilityLabel))
    }

    // MARK: Transcript

    @ViewBuilder
    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(SustainedCopy.transcriptHeading)
                .font(DesignTokens.text(14, weight: .semibold))
                .foregroundStyle(DesignTokens.inkDeep)
            if transcript.isRevealed {
                ForEach(sectionIndices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(passage.sections[index].heading)
                            .font(DesignTokens.text(14, weight: .semibold))
                            .foregroundStyle(DesignTokens.inkDeep)
                            .accessibilityAddTraits(.isHeader)
                        Text(passage.sections[index].text)
                            .font(DesignTokens.text(15))
                            .foregroundStyle(DesignTokens.ink)
                            .lineSpacing(3)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        currentSection == index && listener.isSpeaking
                            ? DesignTokens.primarySoft : Color.clear)
                    .cornerRadius(8)
                }
                .textSelection(.enabled)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(SustainedCopy.transcriptHiddenNote)
                        .font(DesignTokens.text(13))
                        .foregroundStyle(DesignTokens.muted)
                    StudioSecondaryButton(SustainedCopy.showTranscript) {
                        transcript.reveal()
                    }
                    .accessibilityHint(SustainedCopy.showTranscriptHint)
                }
            }
        }
    }

    // MARK: Playback orchestration

    @MainActor
    private func playAll() {
        stopPlayback()
        playingAll = true
        playAllTask = Task { @MainActor in
            for index in sectionIndices {
                if Task.isCancelled { break }
                await playSectionThrough(index)
            }
            playingAll = false
        }
    }

    /// Plays one section to its end (natural completion only marks it
    /// played), awaiting the utterance finish. A stop cancels via the
    /// delegate's cancel callback, so this never hangs.
    @MainActor
    private func playSectionThrough(_ index: Int) async {
        let section = passage.sections[index]
        currentSection = index
        slowSection = nil
        let voice = resolvedVoice(for: section)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            listener.onFinish = { [self] completed in
                currentSection = nil
                if completed { transcript.markPlayed(index) }
                continuation.resume()
            }
            listener.speak(section.text,
                           voice: voice,
                           languageCode: section.languageCode,
                           slow: false)
        }
        listener.onFinish = nil
    }

    @MainActor
    private func playSingle(_ index: Int, slow: Bool) {
        stopPlayback()
        playAllTask = nil
        guard sectionIndices.contains(index) else { return }
        let section = passage.sections[index]
        currentSection = index
        slowSection = slow ? index : nil
        let voice = resolvedVoice(for: section)
        listener.onFinish = { [self] completed in
            currentSection = nil
            slowSection = nil
            if completed { transcript.markPlayed(index) }
            listener.onFinish = nil
        }
        listener.speak(section.text,
                       voice: voice,
                       languageCode: section.languageCode,
                       slow: slow)
    }

    @MainActor
    private func stopPlayback() {
        playAllTask?.cancel()
        playAllTask = nil
        listener.stop()
        currentSection = nil
        slowSection = nil
        playingAll = false
    }

    /// Offline voice resolution for one section: declared voice when
    /// installed, else any installed voice of the language root, else the
    /// language's system voice — a missing voice never fails a section.
    private func resolvedVoice(for section: SustainedListeningSection) -> AVSpeechSynthesisVoice? {
        let installed = installedVoices
        if let identifier = SustainedVoiceResolver.resolve(
            declaredVoiceId: section.voiceId,
            languageCode: section.languageCode,
            installed: installed),
           let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            return voice
        }
        return AVSpeechSynthesisVoice(language: section.languageCode)
    }

    private func recordMissingVoices() {
        let installed = installedVoices
        missingDeclaredVoiceIds = SustainedVoiceResolver.missingVoices(
            declaredVoiceIds: passage.sections.map(\.voiceId),
            installed: installed)
    }
}

// MARK: Learner-facing copy (Phase 6.1B)
//
// Every new string the lane shows, gathered like CheckpointCopy so the
// wording is approved in one place and pinned by a test. British spelling;
// synthesised audio is always labelled synthesised; no level or proficiency
// claim anywhere.

enum SustainedCopy {
    static let questionsHeading = "Check your understanding"
    static let checkAnswers = "Check answers"
    static let answerAllFirst = "Choose an answer for each question to check."
    static let readingCorrect =
        "Identified from the passage — your choice matches what the text says."
    static let readingIncorrect =
        "Read again — the passage points to a different answer."
    static let listeningCorrect =
        "Identified from the listening — your choice matches what was said."
    static let listeningIncorrect =
        "Listen again — the passage points to a different answer."
    static let synthesisedCaption =
        "All audio is synthesised on this device — each section uses its "
        + "declared voice when installed."
    static func synthesisedNote(_ languageName: String) -> String {
        "All audio is synthesised on this device — each section uses its "
        + "declared \(languageName) voice when installed."
    }
    static let synthesisedHint = "Synthesised voice"
    static let playFirstPass = "Play the whole call (first pass)"
    static let stopPlayback = "Stop"
    static let playedLabel = "Played"
    static let transcriptHeading = "Transcript"
    static let transcriptHiddenNote =
        "The transcript stays hidden through the first pass — hear the whole "
        + "passage once before following along."
    static let showTranscript = "Show transcript"
    static let showTranscriptHint =
        "Reveals the full text — you can still replay any section."

    /// Every learner-facing string, gathered for the copy pin test.
    static let allStrings: [String] = [
        questionsHeading, checkAnswers, answerAllFirst,
        readingCorrect, readingIncorrect, listeningCorrect, listeningIncorrect,
        synthesisedCaption, synthesisedNote("Spanish"), synthesisedHint,
        playFirstPass, stopPlayback, playedLabel,
        transcriptHeading, transcriptHiddenNote, showTranscript, showTranscriptHint,
    ]
}
