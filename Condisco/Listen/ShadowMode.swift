import AVFoundation
import SwiftUI

// MARK: - Shadow mode
//
// Shadowing over a track's target phrases: the phrase appears big, TTS
// speaks it in the track's language on demand, and the learner repeats it
// aloud before moving on. Manual advance only — no timers, no scoring.
// The track itself pauses while shadowing.

/// BCP-47 codes for the five courses, for TTS voice selection.
enum ShadowVoice {
    static func languageCode(for courseSlug: String) -> String {
        switch courseSlug {
        case "french": return "fr-FR"
        case "italian": return "it-IT"
        case "german": return "de-DE"
        case "portuguese": return "pt-PT"
        case "spanish": return "es-ES"
        default: return "en-US"
        }
    }
}

private final class ShadowSpeakerDelegate: NSObject, AVSpeechSynthesizerDelegate {
    var onFinish: (() -> Void)?

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        onFinish?()
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        onFinish?()
    }
}

/// Speaks target phrases with the device's TTS voice for the language.
@MainActor
final class ShadowSpeaker: ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    private let delegate = ShadowSpeakerDelegate()
    @Published var isSpeaking = false

    init() {
        synthesizer.delegate = delegate
        delegate.onFinish = { [weak self] in
            Task { @MainActor in self?.isSpeaking = false }
        }
    }

    func speak(_ text: String, languageCode: String, slow: Bool = false) {
        stop()
        let utterance = AVSpeechUtterance(string: text)
        if let identifier = VoiceStore.voiceIdentifier(for: languageCode),
           let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            // The learner's chosen voice for this language.
            utterance.voice = voice
        } else {
            let prefix = String(languageCode.prefix(2))
            if let voice = AVSpeechSynthesisVoice.speechVoices().first(where: {
                $0.language.hasPrefix(prefix)
            }) {
                utterance.voice = voice
            } else {
                utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
            }
        }
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * (slow ? 0.55 : 0.92)
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }
}

struct ShadowModeView: View {
    let track: ListenTrack

    @Environment(\.dismiss) private var dismiss
    @StateObject private var speaker = ShadowSpeaker()
    @State private var index = 0

    private var phrases: [ListenTarget] {
        track.sections.compactMap(\.target)
    }

    private var languageCode: String {
        ShadowVoice.languageCode(for: track.courseSlug)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.canvas.ignoresSafeArea()
                VStack(spacing: 20) {
                    Text("Shadow \(index + 1) of \(phrases.count)")
                        .font(DesignTokens.text(13, weight: .semibold))
                        .foregroundStyle(DesignTokens.primary)
                        .textCase(.uppercase)
                    Spacer()
                    Text(phrases[index].text)
                        .font(DesignTokens.display(34))
                        .foregroundStyle(DesignTokens.inkDeep)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                    Text(phrases[index].meaning)
                        .font(DesignTokens.text(17))
                        .foregroundStyle(DesignTokens.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                    Text("Say it out loud, matching the rhythm.")
                        .font(DesignTokens.text(14))
                        .foregroundStyle(DesignTokens.muted)
                        .padding(.top, 8)
                    Spacer()
                    VStack(spacing: 6) {
                        Button {
                            speaker.speak(
                                phrases[index].text, languageCode: languageCode)
                        } label: {
                            Label(
                                speaker.isSpeaking ? "Speaking…" : "Hear it",
                                systemImage: "speaker.wave.2.fill")
                                .font(DesignTokens.text(16, weight: .semibold))
                                .foregroundStyle(DesignTokens.stock)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(DesignTokens.primary)
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .disabled(speaker.isSpeaking)
                        .accessibilityHint("Synthesized course voice")
                        Text("Course voice (synthesized)")
                            .font(DesignTokens.text(12))
                            .foregroundStyle(DesignTokens.muted)
                    }
                    HStack {
                        Button("Previous") {
                            speaker.stop()
                            index = max(0, index - 1)
                        }
                        .font(DesignTokens.text(16, weight: .semibold))
                        .foregroundStyle(index == 0 ? DesignTokens.muted : DesignTokens.primary)
                        .disabled(index == 0)
                        Spacer()
                        Button(index == phrases.count - 1 ? "Done" : "Next") {
                            speaker.stop()
                            if index == phrases.count - 1 {
                                dismiss()
                            } else {
                                index += 1
                            }
                        }
                        .font(DesignTokens.text(16, weight: .semibold))
                        .foregroundStyle(DesignTokens.primary)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .navigationTitle("Shadow mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onDisappear { speaker.stop() }
        }
    }
}
