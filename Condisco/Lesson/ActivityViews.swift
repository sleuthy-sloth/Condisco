import SwiftUI

// MARK: - Activity views
//
// SwiftUI renderers for every schema-v2 activity kind, in the warm Studio
// idiom: cream stock, terracotta accent, hard offset shadows, no blur.
// Each view edits a shared `AttemptResponse` draft and reports assistance
// through `onAssist`; the player owns submit/advance.

// MARK: Shared bits

/// Warm Studio primary button: terracotta fill, cream text, hard shadow.
struct StudioPrimaryButton: View {
    let label: String
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(DesignTokens.text(17, weight: .semibold))
                .foregroundStyle(DesignTokens.stock)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(disabled ? DesignTokens.muted : DesignTokens.primary)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(DesignTokens.edge, lineWidth: 1.5)
                )
                .shadow(color: DesignTokens.ink, radius: 0, x: 3, y: 3)
        }
        .disabled(disabled)
    }
}

/// Warm Studio secondary button: stock fill, ink edge, hard shadow.
struct StudioSecondaryButton: View {
    let label: String
    let disabled: Bool
    let action: () -> Void

    init(_ label: String, disabled: Bool = false, action: @escaping () -> Void) {
        self.label = label
        self.disabled = disabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(DesignTokens.text(15, weight: .medium))
                .foregroundStyle(DesignTokens.ink)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(DesignTokens.stock)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(DesignTokens.edge, lineWidth: 1.5)
                )
                .shadow(color: DesignTokens.ink, radius: 0, x: 2, y: 2)
        }
        .disabled(disabled)
    }
}

/// Selectable option row: checkbox/radio styling in warm Studio.
struct OptionRow: View {
    let text: String
    let selected: Bool
    let multi: Bool
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    if multi {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(DesignTokens.edge, lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                            .background(selected ? DesignTokens.primary : Color.clear)
                            .cornerRadius(4)
                        if selected {
                            Text("✓")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(DesignTokens.stock)
                        }
                    } else {
                        Circle()
                            .stroke(DesignTokens.edge, lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                        if selected {
                            Circle()
                                .fill(DesignTokens.primary)
                                .frame(width: 12, height: 12)
                        }
                    }
                }
                Text(text)
                    .font(DesignTokens.text(16))
                    .foregroundStyle(DesignTokens.ink)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(12)
            .background(selected ? DesignTokens.primarySoft : DesignTokens.stock)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selected ? DesignTokens.primary : DesignTokens.edgeSoft, lineWidth: 1.5)
            )
        }
        .disabled(disabled)
        .buttonStyle(.plain)
    }
}

// MARK: - Think gate

/// The think-first gate. Clearing it is a commitment, not assistance: the
/// player deliberately does not report it through `onAssist`.
struct ThinkGateView: View {
    let onClear: () -> Void

    var body: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Think first — don't write yet.")
                    .font(DesignTokens.display(19))
                    .foregroundStyle(DesignTokens.inkDeep)
                Text("Say it in your head, out loud, or to whoever is nearby. There is nothing to memorize; build it from what this lesson already gave you.")
                    .font(DesignTokens.text(15))
                    .foregroundStyle(DesignTokens.ink)
                StudioPrimaryButton(label: "I've thought about it — let me answer", disabled: false, action: onClear)
            }
        }
    }
}

// MARK: - Dispatcher

/// Renders the right activity view for the step, including the hint area.
/// Excludes information, self-compare, legacy, and scene-selection from the
/// hint button, mirroring the web player.
struct ActivityView: View {
    let activity: Activity
    let stimulus: Stimulus?
    let pack: CoursePack
    let audioPlayer: LessonAudioPlayer
    @Binding var draft: AttemptResponse?
    let disabled: Bool
    let onAssist: (AssistanceKind) -> Void
    /// The open-task submit path, supplied by the lesson player (6.2).
    /// Only open-task steps call it; other kinds ignore it.
    var onOpenTaskSubmit: ((OpenTaskSubmission) -> Void)? = nil

    @State private var hintRevealed = false

    private var hintable: Bool {
        switch activity {
        case .information, .selfCompare, .legacy, .sceneSelection, .openTask:
            return false
        default:
            return !(activity.base?.hints.isEmpty ?? true)
        }
    }

    /// Model audio for the self-compare step, when the pack provides one.
    private var modelAudioURL: URL? {
        guard case .selfCompare(let spec) = activity,
              let mediaId = spec.modelAudioId,
              let media = pack.media(id: mediaId),
              case .audio(_, let url, _, _, _) = media else { return nil }
        return MediaResolver.bundleURL(for: url)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if hintable {
                if hintRevealed {
                    Text(activity.base?.hints.first ?? "")
                        .font(DesignTokens.text(15))
                        .foregroundStyle(DesignTokens.muted)
                        .padding(10)
                        .background(DesignTokens.stock2)
                        .cornerRadius(8)
                } else {
                    StudioSecondaryButton("Hint") {
                        hintRevealed = true
                        onAssist(.hint)
                    }
                }
            }

            switch activity {
            case .information(let spec):
                InformationActivityView(activity: spec)
            case .selection(let spec):
                SelectionActivityView(activity: spec, draft: $draft, disabled: disabled)
            case .ordering(let spec):
                OrderingActivityView(activity: spec, draft: $draft, disabled: disabled)
            case .matching(let spec):
                MatchingActivityView(activity: spec, draft: $draft, disabled: disabled)
            case .cloze(let spec):
                InlineClozeActivityView(activity: spec, draft: $draft, disabled: disabled)
            case .dialogueChoice(let spec):
                DialogueChoiceActivityView(activity: spec, draft: $draft, disabled: disabled)
            case .text(let spec):
                TextResponseActivityView(activity: spec, draft: $draft, disabled: disabled, onAssist: onAssist)
            case .selfCompare(let spec):
                SelfCompareActivityView(activity: spec, draft: $draft, disabled: disabled,
                                        modelAudioURL: modelAudioURL, audioPlayer: audioPlayer,
                                        onAssist: onAssist)
            case .openTask(let spec):
                OpenTaskActivityView(activity: spec, draft: $draft, disabled: disabled,
                                     onAssist: onAssist,
                                     onSubmit: onOpenTaskSubmit ?? { _ in })
            case .sceneSelection(let spec):
                SceneSelectionActivityView(activity: spec, stimulus: stimulus, draft: $draft, disabled: disabled)
            case .legacy:
                Text("This player does not support legacy activities yet.")
                    .font(DesignTokens.text(15))
                    .foregroundStyle(DesignTokens.attentionInk)
            }
        }
    }
}

// MARK: - Information

struct InformationActivityView: View {
    let activity: InformationActivity

    var body: some View {
        Text(activity.body)
            .font(DesignTokens.text(16))
            .foregroundStyle(DesignTokens.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Selection

struct SelectionActivityView: View {
    let activity: SelectionActivity
    @Binding var draft: AttemptResponse?
    let disabled: Bool

    private var ids: [String] {
        if case .selection(let ids) = draft { return ids }
        return []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(activity.multiple ? "Choose all that apply" : "Choose one answer")
                .font(DesignTokens.text(14, weight: .medium))
                .foregroundStyle(DesignTokens.muted)
            ForEach(activity.options, id: \.id) { option in
                OptionRow(
                    text: option.text,
                    selected: ids.contains(option.id),
                    multi: activity.multiple,
                    disabled: disabled
                ) {
                    var next = ids
                    if activity.multiple {
                        if next.contains(option.id) {
                            next.removeAll { $0 == option.id }
                        } else {
                            next.append(option.id)
                        }
                    } else {
                        next = [option.id]
                    }
                    draft = .selection(ids: next)
                }
            }
        }
    }
}

// MARK: - Dialogue choice

struct DialogueChoiceActivityView: View {
    let activity: DialogueChoiceActivity
    @Binding var draft: AttemptResponse?
    let disabled: Bool

    private var chosenId: String? {
        if case .selection(let ids) = draft { return ids.first }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Choose your reply")
                .font(DesignTokens.text(14, weight: .medium))
                .foregroundStyle(DesignTokens.muted)
            ForEach(activity.options, id: \.id) { option in
                OptionRow(
                    text: option.text,
                    selected: chosenId == option.id,
                    multi: false,
                    disabled: disabled
                ) {
                    draft = .selection(ids: [option.id])
                }
            }
        }
    }
}

// MARK: - Scene selection

/// Region checkboxes. The scene image itself renders in the stimulus
/// context; when the image is unavailable the text alternative stands in.
struct SceneSelectionActivityView: View {
    let activity: SceneSelectionActivity
    let stimulus: Stimulus?
    @Binding var draft: AttemptResponse?
    let disabled: Bool

    private var ids: [String] {
        if case .selection(let ids) = draft { return ids }
        return []
    }

    private var regions: [SceneRegion] {
        guard let stimulus, case .scene(_, _, _, let regions, _) = stimulus else { return [] }
        return regions
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select the matching parts of the scene")
                .font(DesignTokens.text(14, weight: .medium))
                .foregroundStyle(DesignTokens.muted)
            if regions.isEmpty {
                Text("The scene for this activity is unavailable.")
                    .font(DesignTokens.text(15))
                    .foregroundStyle(DesignTokens.attentionInk)
            } else {
                ForEach(regions, id: \.id) { region in
                    OptionRow(
                        text: region.label,
                        selected: ids.contains(region.id),
                        multi: true,
                        disabled: disabled
                    ) {
                        var next = ids
                        if next.contains(region.id) {
                            next.removeAll { $0 == region.id }
                        } else {
                            next.append(region.id)
                        }
                        draft = .selection(ids: next)
                    }
                }
            }
        }
    }
}

// MARK: - Open tasks (Phase 6.2)

/// The learner's in-flight open-task state at submit time. Pure value
/// type so the submission rules are testable headless. Written mode
/// requires non-empty trimmed text; spoken mode requires a finished
/// recording — or, when the microphone is blocked, at least one ticked
/// criterion (the same honest degradation the self-compare and checkpoint
/// lanes use). No length or timing rule can block a submission: the
/// length guidance is a soft target, never a pass/fail.
struct OpenTaskSubmission: Equatable {
    var text: String = ""
    var criteriaMet: [String] = []
    var rating: AttemptResponse.SelfRating? = nil
    var modelRevealed = false
    var hasRecording = false
    var micDenied = false

    static func canSubmit(mode: OpenTaskMode, submission: OpenTaskSubmission) -> Bool {
        switch mode {
        case .written:
            return !submission.text
                .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .spoken:
            return submission.hasRecording
                || (submission.micDenied && !submission.criteriaMet.isEmpty)
        }
    }
}

/// Learner-facing copy for the open-task lane (6.2). Plain, British
/// spelling. Every new string lives here so tests can pin them.
enum OpenTaskCopy {
    // Player bar note (shown instead of a Check button).
    static let barNote =
        "Self-assessed — your judgement, not an automatic mark."
    // Step slide labels.
    static let includePoints = "Include these points:"
    static func lengthGuidance(_ authored: String?) -> String {
        authored?.isEmpty == false ? authored! :
            "A few connected sentences — or, out loud, about a minute. This is a soft target, not a timer."
    }
    static let writtenCaption = "Nothing here is marked right or wrong."
    static let recordMyself = "Record yourself"
    static let stopRecording = "Stop recording"
    static let starting = "Starting…"
    static let playMyRecording = "Play my recording"
    static let recordAgain = "Record again"
    static let recordingNote =
        "Hear it back, then record again to replace it. Nothing is uploaded or kept."
    static let micBlocked =
        "Microphone is blocked, so nothing could be recorded. Say it out loud "
        + "anyway and tick what you hear yourself doing."
    static let hint = "Hint"
    static let selfAssessmentTitle = "Self-assessment"
    static let selfAssessmentSubline =
        "Your own judgement against the criteria — nothing here is marked right or wrong."
    static let tickWhatYouDo = "Tick everything you hear yourself doing:"
    static let rateYourself = "Overall, how did it feel?"
    static let ratingOptional = "Optional — your own judgement, saved with the attempt."
    static let revealModel = "Reveal a model response"
    static let modelRevealedNote =
        "The model is shown, so this attempt won't count as independent practice."
    static let submit = "Submit self-assessment"
    static func answerFirst(mode: OpenTaskMode) -> String {
        mode == .written
            ? "Write your response first."
            : "Record your response first."
    }
    static let saveFailed =
        "Not saved — check your connection and try again. Your response is intact."

    /// Every learner-facing string, gathered for the copy pin test.
    static let allStrings: [String] = [
        barNote,
        includePoints,
        lengthGuidance(nil),
        writtenCaption,
        recordMyself, stopRecording, starting, playMyRecording, recordAgain,
        recordingNote, micBlocked, hint,
        selfAssessmentTitle, selfAssessmentSubline, tickWhatYouDo,
        rateYourself, ratingOptional,
        revealModel, modelRevealedNote, submit,
        answerFirst(mode: .written), answerFirst(mode: .spoken),
        saveFailed,
    ]
}

/// A connected-production task: goal + required points up front, a private
/// written draft or recording, optional hints, a model reveal on an
/// explicit action, and a self-check rubric the learner ticks against
/// their own response. Submit records completion, assistance, and the
/// learner's own self-assessment only — never the response itself.
struct OpenTaskActivityView: View {
    let activity: OpenTaskActivity
    @Binding var draft: AttemptResponse?
    let disabled: Bool
    let onAssist: (AssistanceKind) -> Void
    let onSubmit: (OpenTaskSubmission) -> Void

    @StateObject private var recorder = LessonStepRecorder()
    @State private var criteriaMet: Set<String> = []
    @State private var rating: AttemptResponse.SelfRating?
    @State private var modelRevealed = false
    @State private var hintShown = false

    /// The written draft lives in the shared player draft so the lesson
    /// checkpoint persists it for resume (a view re-init restores it).
    private var text: String {
        if case .text(let value) = draft { return value }
        return ""
    }

    private var submission: OpenTaskSubmission {
        OpenTaskSubmission(
            text: text,
            criteriaMet: criteriaMet.sorted(),
            rating: rating,
            modelRevealed: modelRevealed,
            hasRecording: recorder.recordingURL != nil && recorder.state != .recording,
            micDenied: recorder.denied)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(OpenTaskCopy.includePoints)
                .font(DesignTokens.text(14, weight: .medium))
                .foregroundStyle(DesignTokens.muted)
            ForEach(activity.requiredPoints, id: \.self) { point in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundStyle(DesignTokens.primary)
                    Text(point)
                        .font(DesignTokens.text(15))
                        .foregroundStyle(DesignTokens.ink)
                }
            }

            Text(OpenTaskCopy.lengthGuidance(activity.lengthGuidance))
                .font(DesignTokens.text(13))
                .foregroundStyle(DesignTokens.muted)

            if activity.mode == .written {
                TextEditor(text: Binding(
                    get: { text },
                    set: { draft = .text($0) }
                ))
                .font(DesignTokens.text(17))
                .foregroundStyle(DesignTokens.ink)
                .frame(minHeight: 130)
                .padding(8)
                .background(DesignTokens.canvas)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(DesignTokens.edge, lineWidth: 1.5)
                )
                .disabled(disabled)
                .accessibilityLabel(activity.goal)
                Text(OpenTaskCopy.writtenCaption)
                    .font(DesignTokens.text(13))
                    .foregroundStyle(DesignTokens.muted)
            } else {
                spokenRecorder
            }

            if !activity.hints.isEmpty && !hintShown {
                StudioSecondaryButton(OpenTaskCopy.hint) {
                    hintShown = true
                    onAssist(.hint)
                }
            }
            if hintShown {
                Text(activity.hints.joined(separator: "\n"))
                    .font(DesignTokens.text(15))
                    .foregroundStyle(DesignTokens.muted)
                    .padding(10)
                    .background(DesignTokens.stock2)
                    .cornerRadius(8)
            }

            // Self-assessment card — the learner's own judgement.
            VStack(alignment: .leading, spacing: 10) {
                Text(OpenTaskCopy.selfAssessmentTitle)
                    .font(DesignTokens.text(14, weight: .semibold))
                    .foregroundStyle(DesignTokens.inkDeep)
                Text(OpenTaskCopy.selfAssessmentSubline)
                    .font(DesignTokens.text(13))
                    .foregroundStyle(DesignTokens.muted)
                Text(OpenTaskCopy.tickWhatYouDo)
                    .font(DesignTokens.text(15, weight: .medium))
                    .foregroundStyle(DesignTokens.inkDeep)
                ForEach(activity.rubric) { criterion in
                    OptionRow(
                        text: criterion.text,
                        selected: criteriaMet.contains(criterion.id),
                        multi: true,
                        disabled: disabled
                    ) {
                        toggleCriterion(criterion.id)
                    }
                }

                Text(OpenTaskCopy.rateYourself)
                    .font(DesignTokens.text(15, weight: .medium))
                    .foregroundStyle(DesignTokens.inkDeep)
                ratingPicker
                Text(OpenTaskCopy.ratingOptional)
                    .font(DesignTokens.text(13))
                    .foregroundStyle(DesignTokens.muted)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.stock)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(DesignTokens.edge, lineWidth: 1.5)
            )

            // Model reveal: an explicit action; after it the attempt is
            // not independent.
            if modelRevealed {
                Text(activity.modelResponse)
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
                Text(OpenTaskCopy.modelRevealedNote)
                    .font(DesignTokens.text(13))
                    .foregroundStyle(DesignTokens.muted)
            } else {
                StudioSecondaryButton(OpenTaskCopy.revealModel, disabled: disabled) {
                    modelRevealed = true
                    onAssist(.model)
                }
            }

            StudioPrimaryButton(
                label: OpenTaskCopy.submit,
                disabled: disabled || !OpenTaskSubmission.canSubmit(
                    mode: activity.mode, submission: submission)
            ) {
                onSubmit(submission)
            }
            if !OpenTaskSubmission.canSubmit(mode: activity.mode, submission: submission) {
                Text(OpenTaskCopy.answerFirst(mode: activity.mode))
                    .font(DesignTokens.text(13))
                    .foregroundStyle(DesignTokens.muted)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .onDisappear {
            // The recording exists only for this step; remove the temp
            // file when the step goes away.
            recorder.discard()
        }
    }

    /// Record → play back → tick. The same recorder class the self-compare
    /// and checkpoint lanes use; nothing is uploaded or kept, and the
    /// take is deletable in-UI ("Record again" discards it).
    private var spokenRecorder: some View {
        VStack(alignment: .leading, spacing: 8) {
            if recorder.canRecord {
                if let _ = recorder.recordingURL, recorder.state != .recording {
                    HStack(spacing: 10) {
                        StudioSecondaryButton(OpenTaskCopy.playMyRecording, disabled: disabled) {
                            recorder.playRecording()
                        }
                        StudioSecondaryButton(OpenTaskCopy.recordAgain, disabled: disabled) {
                            recorder.discard()
                        }
                    }
                    Text(OpenTaskCopy.recordingNote)
                        .font(DesignTokens.text(13))
                        .foregroundStyle(DesignTokens.muted)
                } else {
                    StudioSecondaryButton(
                        recorder.state == .recording ? OpenTaskCopy.stopRecording
                            : recorder.state == .requesting ? OpenTaskCopy.starting
                            : OpenTaskCopy.recordMyself,
                        disabled: disabled || recorder.state == .requesting
                    ) {
                        recorder.toggle()
                    }
                }
            }

            if recorder.denied {
                Text(OpenTaskCopy.micBlocked)
                    .font(DesignTokens.text(13))
                    .foregroundStyle(DesignTokens.muted)
            }
        }
    }

    private var ratingPicker: some View {
        HStack(spacing: 8) {
            ForEach([AttemptResponse.SelfRating.again,
                     .hard, .good, .easy], id: \.self) { option in
                let selected = rating == option
                Button {
                    rating = rating == option ? nil : option
                } label: {
                    Text(checkpointRatingLabel(option))
                        .font(DesignTokens.text(14, weight: .medium))
                        .foregroundStyle(selected ? DesignTokens.stock : DesignTokens.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(selected ? DesignTokens.primary : DesignTokens.canvas)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(DesignTokens.edge, lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
                .disabled(disabled)
            }
        }
    }

    private func toggleCriterion(_ criterionId: String) {
        if criteriaMet.contains(criterionId) {
            criteriaMet.remove(criterionId)
        } else {
            criteriaMet.insert(criterionId)
        }
    }
}
