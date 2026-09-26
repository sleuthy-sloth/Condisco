import AVFoundation
import SwiftUI

// MARK: - Ordering

struct OrderingActivityView: View {
    let activity: OrderingActivity
    @Binding var draft: AttemptResponse?
    let disabled: Bool

    private var placedIds: [String] {
        if case .ordering(let ids) = draft { return ids }
        return []
    }

    private func token(id: String) -> OptionItem? {
        activity.tokens.first { $0.id == id }
    }

    /// Stable 1-based position among tokens sharing visible text, derived
    /// from activity token order regardless of placement.
    private func duplicateSuffix(for id: String) -> String {
        guard let current = token(id: id) else { return "" }
        let sameText = activity.tokens.filter { $0.text == current.text }
        guard sameText.count > 1,
              let position = sameText.firstIndex(where: { $0.id == id }) else { return "" }
        return " (\(position + 1))"
    }

    private func setIds(_ ids: [String]) {
        draft = .ordering(ids: ids)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 8) {
                ForEach(Array(placedIds.enumerated()), id: \.element) { index, id in
                    if let item = token(id: id) {
                        HStack {
                            Text("\(item.text)\(duplicateSuffix(for: id))")
                                .font(DesignTokens.text(16))
                                .foregroundStyle(DesignTokens.ink)
                            Spacer()
                            Button("↑") {
                                var next = placedIds
                                next.swapAt(index, index - 1)
                                setIds(next)
                            }
                            .disabled(disabled || index == 0)
                            .frame(minWidth: 40, minHeight: 44)
                            .accessibilityLabel("Move up")
                            Button("↓") {
                                var next = placedIds
                                next.swapAt(index, index + 1)
                                setIds(next)
                            }
                            .disabled(disabled || index == placedIds.count - 1)
                            .frame(minWidth: 40, minHeight: 44)
                            .accessibilityLabel("Move down")
                            Button("✕") {
                                var next = placedIds
                                next.remove(at: index)
                                setIds(next)
                            }
                            .disabled(disabled)
                            .frame(minWidth: 40, minHeight: 44)
                            .accessibilityLabel("Remove")
                        }
                        .font(DesignTokens.text(16))
                        .foregroundStyle(DesignTokens.ink)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(DesignTokens.primarySoft)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(DesignTokens.primary, lineWidth: 1.5)
                        )
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("Placed: \(item.text)\(duplicateSuffix(for: id))")
                    }
                }
                if placedIds.isEmpty {
                    Text("Tap the words below to build your sentence.")
                        .font(DesignTokens.text(14))
                        .foregroundStyle(DesignTokens.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            FlowLayout(spacing: 8) {
                ForEach(activity.tokens.filter { !placedIds.contains($0.id) }, id: \.id) { item in
                    Button("\(item.text)\(duplicateSuffix(for: item.id))") {
                        setIds(placedIds + [item.id])
                    }
                    .font(DesignTokens.text(16))
                    .foregroundStyle(DesignTokens.ink)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .background(DesignTokens.stock)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(DesignTokens.edge, lineWidth: 1.5)
                    )
                    .shadow(color: DesignTokens.ink, radius: 0, x: 2, y: 2)
                    .disabled(disabled)
                    .accessibilityLabel("Add \(item.text)\(duplicateSuffix(for: item.id))")
                }
            }
        }
    }
}

// MARK: - Matching

struct MatchingActivityView: View {
    let activity: MatchingActivity
    @Binding var draft: AttemptResponse?
    let disabled: Bool

    @State private var selectedLeftId: String?

    private var pairs: [ResponsePair] {
        if case .matching(let pairs) = draft { return pairs }
        return []
    }

    private var pairedLeft: Set<String> { Set(pairs.map { $0.leftId }) }
    private var pairedRight: Set<String> { Set(pairs.map { $0.rightId }) }

    private func text(forLeft id: String) -> String {
        activity.left.first { $0.id == id }?.text ?? id
    }

    private func text(forRight id: String) -> String {
        activity.right.first { $0.id == id }?.text ?? id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 8) {
                    ForEach(activity.left, id: \.id) { item in
                        Button(item.text) {
                            selectedLeftId = item.id
                        }
                        .font(DesignTokens.text(15))
                        .foregroundStyle(selectedLeftId == item.id ? DesignTokens.stock : DesignTokens.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.vertical, 10)
                        .background(selectedLeftId == item.id ? DesignTokens.primary : DesignTokens.stock)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(DesignTokens.edge, lineWidth: 1.5)
                        )
                        .disabled(disabled || pairedLeft.contains(item.id))
                        .opacity(pairedLeft.contains(item.id) ? 0.4 : 1)
                    }
                }
                VStack(spacing: 8) {
                    ForEach(activity.right, id: \.id) { item in
                        Button(item.text) {
                            if let leftId = selectedLeftId {
                                draft = .matching(pairs: pairs + [ResponsePair(leftId: leftId, rightId: item.id)])
                                selectedLeftId = nil
                            }
                        }
                        .font(DesignTokens.text(15))
                        .foregroundStyle(DesignTokens.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.vertical, 10)
                        .background(DesignTokens.stock)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(DesignTokens.edge, lineWidth: 1.5)
                        )
                        .disabled(disabled || pairedRight.contains(item.id) || selectedLeftId == nil)
                        .opacity(pairedRight.contains(item.id) ? 0.4 : 1)
                    }
                }
            }

            if !pairs.isEmpty {
                VStack(spacing: 6) {
                    ForEach(pairs, id: \.leftId) { pair in
                        HStack {
                            Text("\(text(forLeft: pair.leftId)) — \(text(forRight: pair.rightId))")
                                .font(DesignTokens.text(15))
                                .foregroundStyle(DesignTokens.ink)
                            Spacer()
                            Button("Remove") {
                                draft = .matching(pairs: pairs.filter {
                                    !($0.leftId == pair.leftId && $0.rightId == pair.rightId)
                                })
                            }
                            .font(DesignTokens.text(14, weight: .medium))
                            .foregroundStyle(DesignTokens.attentionInk)
                            .disabled(disabled)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(DesignTokens.stock2)
                        .cornerRadius(6)
                    }
                }
            }
        }
    }
}

// MARK: - Self compare (speaking)

/// The lesson flow's only speaking step. The learner says the line, hears
/// themselves back, then reveals the model and rates how it went.
///
/// Recording comes BEFORE the reveal on purpose: producing the line from
/// memory and then comparing is the whole point. When recording is
/// unavailable the step degrades to plain self-assessment — nothing is
/// uploaded or kept.
final class LessonStepRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    enum RecorderState {
        case idle, requesting, recording
    }

    @Published var state: RecorderState = .idle
    @Published var recordingURL: URL?
    @Published var denied = false

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?

    var canRecord: Bool { !denied }

    func toggle() {
        switch state {
        case .recording: stop()
        case .idle: start()
        case .requesting: break
        }
    }

    func start() {
        state = .requesting
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                guard granted else {
                    self.denied = true
                    self.state = .idle
                    return
                }
                self.beginRecording()
            }
        }
    }

    private func beginRecording() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("verbalibera-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
        ]
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.delegate = self
            recorder.record()
            self.recorder = recorder
            self.recordingURL = url
            self.state = .recording
        } catch {
            self.state = .idle
            self.denied = true
        }
    }

    func stop() {
        recorder?.stop()
        recorder = nil
        state = .idle
    }

    deinit {
        recorder?.stop()
    }

    func discard() {
        stop()
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordingURL = nil
        player?.stop()
        player = nil
    }

    func playRecording() {
        guard let url = recordingURL else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.play()
            self.player = player
        } catch {
            // Playback failure leaves the recording in place; the learner
            // can record again or move on to the model.
        }
    }
}

struct SelfCompareActivityView: View {
    let activity: SelfCompareActivity
    @Binding var draft: AttemptResponse?
    let disabled: Bool
    let modelAudioURL: URL?
    @ObservedObject var audioPlayer: LessonAudioPlayer
    let onAssist: (AssistanceKind) -> Void

    @StateObject private var recorder = LessonStepRecorder()
    @State private var revealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Say your answer, then compare it with the model. This is self-assessed practice.")
                .font(DesignTokens.text(15))
                .foregroundStyle(DesignTokens.ink)

            if recorder.canRecord {
                if let _ = recorder.recordingURL, recorder.state != .recording {
                    HStack(spacing: 10) {
                        StudioSecondaryButton("Play my recording") {
                            recorder.playRecording()
                        }
                        StudioSecondaryButton("Record again", disabled: disabled) {
                            recorder.discard()
                        }
                    }
                    Text("Hear yourself, then the model. Nothing is uploaded or kept.")
                        .font(DesignTokens.text(13))
                        .foregroundStyle(DesignTokens.muted)
                } else {
                    StudioSecondaryButton(
                        recorder.state == .recording ? "Stop recording"
                            : recorder.state == .requesting ? "Starting…"
                            : "Record yourself saying it",
                        disabled: disabled || recorder.state == .requesting
                    ) {
                        recorder.toggle()
                    }
                }
            }

            if recorder.denied {
                Text("Microphone is blocked, so nothing is recorded. Say it out loud anyway and compare with the model.")
                    .font(DesignTokens.text(13))
                    .foregroundStyle(DesignTokens.muted)
            }

            if revealed {
                Text(activity.modelText)
                    .font(DesignTokens.display(19))
                    .foregroundStyle(DesignTokens.inkDeep)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DesignTokens.primarySoft)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(DesignTokens.primary, lineWidth: 1.5)
                    )
                if let modelAudioURL {
                    StudioSecondaryButton(audioPlayer.isPlaying ? "Pause model" : "Play model") {
                        audioPlayer.toggle(url: modelAudioURL)
                    }
                }
                HStack(spacing: 10) {
                    StudioSecondaryButton("Practise again", disabled: disabled) {
                        draft = .selfRating(.again)
                    }
                    StudioSecondaryButton("Comfortable", disabled: disabled) {
                        draft = .selfRating(.comfortable)
                    }
                }
            } else {
                StudioSecondaryButton("Reveal comparison model", disabled: disabled) {
                    revealed = true
                    onAssist(.model)
                }
            }
        }
        .onDisappear {
            // The recording exists only for this step's comparison; remove
            // the temp file when the step goes away.
            recorder.discard()
        }
    }
}
