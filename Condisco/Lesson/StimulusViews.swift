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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let url = audioURL {
                StudioSecondaryButton(audioPlayer.isPlaying ? "Pause audio" : "Play audio") {
                    audioPlayer.toggle(url: url)
                }
                if audioPlayer.failed {
                    Text("Audio could not play. Check the download and try again.")
                        .font(DesignTokens.text(14))
                        .foregroundStyle(DesignTokens.attentionInk)
                }
            } else {
                Text("Audio for this step is not available.")
                    .font(DesignTokens.text(14))
                    .foregroundStyle(DesignTokens.attentionInk)
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

    private var languageCode: String {
        ShadowVoice.languageCode(for: languageSlug)
    }

    private var pairIndices: [Int] {
        Array(0..<pairs.count)
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
                StudioSecondaryButton(playingAll ? "Stop" : "Hear them all") {
                    playingAll ? stopPlayAll() : playAll()
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
                            }
                            PhraseSaveButton(
                                phrase: ShareablePhrase(
                                    target: pair.target,
                                    meaning: pair.meaning,
                                    languageName: languageName),
                                languageSlug: languageSlug,
                                source: lesson?.title ?? "")
                            PhraseShareButton(phrase: ShareablePhrase(
                                target: pair.target,
                                meaning: pair.meaning,
                                languageName: languageName))
                            RecordCompareButton(
                                target: pair.target,
                                languageCode: languageCode)
                        }
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
