import AVFoundation
import SwiftUI

// MARK: - Voice settings
//
// Per-language TTS voice choice. Every spoken path in the app goes through
// ShadowSpeaker, so honoring the stored choice there covers shadow mode,
// example TTS, slow audio, and "hear them all" at once.

/// Reads and writes the learner's chosen TTS voice per course language.
/// A nil identifier means the system default voice for the language.
enum VoiceStore {
    /// The courses: slug, display name, BCP-47 code. Derived from the
    /// registry so slug/name/code live in one place; the BCP-47 STRINGS
    /// (and therefore the `condisco.voice.<bcp47>` defaults keys) are
    /// unchanged.
    static let courses: [(slug: String, name: String, bcp47: String)] =
        CourseRegistry.order.map { ($0.slug, $0.displayName, $0.bcp47) }

    private static func key(for bcp47: String) -> String {
        "condisco.voice.\(bcp47)"
    }

    /// The stored voice identifier for a BCP-47 code, or nil when the
    /// learner hasn't picked one (system default).
    static func voiceIdentifier(for bcp47: String) -> String? {
        UserDefaults.standard.string(forKey: key(for: bcp47))
    }

    /// Store a voice identifier, or nil to clear back to system default.
    static func setVoice(identifier: String?, for bcp47: String) {
        let defaultsKey = key(for: bcp47)
        if let identifier {
            UserDefaults.standard.set(identifier, forKey: defaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: defaultsKey)
        }
    }
}

/// Per-language voice pickers for the You tab. Embedded by the coordinator;
/// takes no init parameters.
struct VoiceSettingsSection: View {
    var body: some View {
        QuietSurface {
            VStack(alignment: .leading, spacing: 10) {
                Text("Voices")
                    .font(DesignTokens.display(20))
                    .foregroundStyle(DesignTokens.inkDeep)
                Text("Choose which of your device's voices reads phrases aloud in each language. Your choice is used everywhere Condisco speaks.")
                    .font(DesignTokens.text(13))
                    .foregroundStyle(DesignTokens.muted)
                ForEach(VoiceStore.courses, id: \.slug) { course in
                    VoicePickerRow(course: course)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct VoicePickerRow: View {
    let course: (slug: String, name: String, bcp47: String)

    @State private var selectedIdentifier = ""

    private var voices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(course.bcp47) }
            .sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name)
                    == .orderedAscending
            }
    }

    var body: some View {
        Picker(course.name, selection: $selectedIdentifier) {
            Text("System default").tag("")
            ForEach(voices, id: \.identifier) { voice in
                Text(voice.name).tag(voice.identifier)
            }
        }
        .font(DesignTokens.text(15))
        .foregroundStyle(DesignTokens.inkDeep)
        .tint(DesignTokens.primary)
        .onAppear {
            selectedIdentifier =
                VoiceStore.voiceIdentifier(for: course.bcp47) ?? ""
        }
        .onChange(of: selectedIdentifier) { _, newValue in
            VoiceStore.setVoice(
                identifier: newValue.isEmpty ? nil : newValue,
                for: course.bcp47)
        }
    }
}
