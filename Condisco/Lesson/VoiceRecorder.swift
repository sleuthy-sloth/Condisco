import AVFoundation
import SwiftUI

// MARK: - Record and compare
//
// On-device pronunciation practice: the learner records their take of a
// phrase, then hears it back followed by the synthesized course voice. No scoring, no
// judgment — just listen and compare. Recordings are ephemeral: a tmp
// .m4a deleted on disappear and after playback completes. Nothing is ever
// uploaded.

/// Owns one record-and-compare cycle: idle → recording → "your take" →
/// "course voice (synthesized)" → idle. Mic denial stays quiet — the button simply notes
/// the mic is unavailable, never an alert.
@MainActor
final class VoiceRecorder: NSObject, ObservableObject, AVAudioPlayerDelegate {
    enum Phase { case idle, recording, yourTake, native }

    let target: String
    let languageCode: String

    @Published private(set) var phase: Phase = .idle
    /// True after the user denies mic access. Surfaced as a quiet
    /// accessibility hint on the button.
    @Published private(set) var micUnavailable = false

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private let nativeSpeaker = ShadowSpeaker()
    private var capTask: Task<Void, Never>?
    private var nativeWatch: Task<Void, Never>?
    private var fileURL: URL?

    init(target: String, languageCode: String) {
        self.target = target
        self.languageCode = languageCode
    }

    /// The mic button's only action: start, stop-and-compare, or stop.
    func toggle() {
        switch phase {
        case .idle:
            requestAndRecord()
        case .recording:
            stopAndCompare()
        case .yourTake, .native:
            stopEverything()
        }
    }

    private func requestAndRecord() {
        let permission = AVAudioApplication.shared.recordPermission
        if permission == .granted {
            beginRecording()
        } else if permission == .denied {
            micUnavailable = true
        } else {
            // .undetermined
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if granted {
                        self.beginRecording()
                    } else {
                        self.micUnavailable = true
                    }
                }
            }
        }
    }

    private func beginRecording() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord, mode: .default, options: .defaultToSpeaker)
            try session.setActive(true)
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.record()
            fileURL = url
            micUnavailable = false
            phase = .recording
            // Safety cap: stop automatically after 30 seconds.
            capTask?.cancel()
            capTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard !Task.isCancelled else { return }
                self?.stopAndCompare()
            }
        } catch {
            // Quiet: the button simply stays idle.
            discard()
            micUnavailable = true
        }
    }

    private func stopAndCompare() {
        capTask?.cancel()
        capTask = nil
        recorder?.stop()
        recorder = nil
        guard let url = fileURL else {
            phase = .idle
            return
        }
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.play()
            phase = .yourTake
        } catch {
            discard()
        }
    }

    private func stopEverything() {
        nativeWatch?.cancel()
        nativeWatch = nil
        player?.stop()
        player = nil
        nativeSpeaker.stop()
        discard()
    }

    /// Stop everything and delete the tmp recording. Safe to call any time.
    func discard() {
        capTask?.cancel()
        capTask = nil
        nativeWatch?.cancel()
        nativeWatch = nil
        if phase == .recording {
            recorder?.stop()
        }
        recorder = nil
        player?.stop()
        player = nil
        nativeSpeaker.stop()
        if let url = fileURL {
            try? FileManager.default.removeItem(at: url)
        }
        fileURL = nil
        phase = .idle
    }

    // MARK: - AVAudioPlayerDelegate

    nonisolated func audioPlayerDidFinishPlaying(
        _ player: AVAudioPlayer, successfully flag: Bool
    ) {
        Task { @MainActor [weak self] in
            guard let self, self.phase == .yourTake else { return }
            // The take has been heard; the tmp file has served its purpose.
            if let url = self.fileURL {
                try? FileManager.default.removeItem(at: url)
            }
            self.fileURL = nil
            self.player = nil
            self.phase = .native
            self.nativeSpeaker.speak(self.target, languageCode: self.languageCode)
            self.watchNativeVoice()
        }
    }

    /// Return to idle once the course voice finishes, so the button
    /// reflects reality without needing a manual tap.
    private func watchNativeVoice() {
        nativeWatch?.cancel()
        nativeWatch = Task { [weak self] in
            // Give the utterance a moment to start.
            try? await Task.sleep(nanoseconds: 400_000_000)
            var speaking = true
            while speaking, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 250_000_000)
                speaking = self?.nativeSpeaker.isSpeaking ?? false
            }
            guard !Task.isCancelled else { return }
            self?.phase = .idle
        }
    }
}

/// Mic button for record-and-compare, placed beside the speaker, tortoise,
/// save, and share buttons. Icon-only when idle or recording; a small
/// caption labels the playback phases.
struct RecordCompareButton: View {
    let target: String
    let languageCode: String

    @StateObject private var recorder: VoiceRecorder

    init(target: String, languageCode: String) {
        self.target = target
        self.languageCode = languageCode
        _recorder = StateObject(
            wrappedValue: VoiceRecorder(
                target: target, languageCode: languageCode))
    }

    var body: some View {
        Button {
            recorder.toggle()
        } label: {
            VStack(spacing: 1) {
                Image(systemName: recorder.phase == .recording
                      ? "stop.circle" : "mic")
                    .font(.system(size: 15))
                    .foregroundStyle(recorder.phase == .recording
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
        .accessibilityHint(recorder.micUnavailable ? "Mic unavailable" : "")
        .onDisappear { recorder.discard() }
    }

    private var buttonLabel: String {
        switch recorder.phase {
        case .idle:
            return "Record your pronunciation of \"\(target)\""
        case .recording:
            return "Stop recording"
        case .yourTake, .native:
            return "Stop playback"
        }
    }
}
