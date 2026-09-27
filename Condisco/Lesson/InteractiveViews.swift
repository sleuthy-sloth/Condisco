import AVFoundation
import SwiftUI

// MARK: - Branching exchange practice (Phase 6.3)
//
// A hosted `Dialogue` from the pack, rendered as a live two-sided
// exchange: the partner's authored lines, the learner's own replies
// (picked choices or composed drafts), deterministic choice turns and
// open turns with the 6.2 self-check rubric. Nothing here grades: choice
// turns route the authored graph, open turns are self-assessed, and the
// end-of-exchange recap shows ONLY what the learner themselves supplied.
// Every answered turn records one `DialogueTurnEvent` (the player holds
// the pending event + session until the save lands).

/// Learner-facing copy for the exchange lane. Plain, British spelling;
/// no CEFR/ability/correctness-claim language (pinned in tests like the
/// 6.2 open-task copy).
enum DialoguePracticeCopy {
    static let hero = "Conversation practice"
    static let freshCta = "Start conversation"
    static let continueCta = "Continue conversation"
    static let replayCta = "Practise again"
    static let done = "Done"
    static let chooseYourReply = "Choose your reply"
    static let writeYourReply = "Write your reply in Spanish"
    static let answerFirst = "Write your reply first."
    static let sendReply = "Send reply"
    static let yourLine = "What you said"
    static let recapTitle = "Your conversation"
    static let recapNote =
        "Here is the exchange as it happened. Your replies are your own — written or picked — nothing is invented here."
    static let endedNote = "That's the end of this conversation."
    static let partnerFallback = "Partner"
    static let saveFailed =
        "Not saved — check your connection and try again. Your reply is intact."
    static let retry = "Retry save"
    static let couldNotStart = "This conversation could not be opened."

    /// Every new learner-facing string, gathered for the copy pin test.
    static let allStrings: [String] = [
        hero, freshCta, continueCta, replayCta, done, chooseYourReply,
        writeYourReply, answerFirst, sendReply, yourLine, recapTitle,
        recapNote, endedNote, partnerFallback, saveFailed, retry, couldNotStart,
    ]
}

/// Transient editor fields for the presented turn. A draft edit also updates
/// the bound DialogueSession for checkpointing; that change must not clear
/// the learner's rubric choices. Only a different presented turn resets it.
struct DialogueOpenTurnForm {
    var draftText = ""
    var criteriaMet: Set<String> = []
    var rating: AttemptResponse.SelfRating?

    mutating func reset(for session: DialogueSession?) {
        draftText = session?.openDraft ?? ""
        criteriaMet = []
        rating = nil
    }

    mutating func sessionChanged(from previous: DialogueSession?,
                                 to current: DialogueSession?) {
        guard previous?.dialogueId != current?.dialogueId
                || previous?.hostLessonId != current?.hostLessonId
                || previous?.currentNodeId != current?.currentNodeId
                || previous?.visitedNodeIds != current?.visitedNodeIds
                || previous?.turns != current?.turns
                || previous?.status != current?.status else { return }
        reset(for: current)
    }
}

struct DialogueExchangeView: View {
    let pack: CoursePack
    let store: LearningStore
    let lesson: Lesson
    let dialogue: Dialogue
    @Binding var session: DialogueSession?
    let onClose: () -> Void

    @State private var openForm = DialogueOpenTurnForm()
    @State private var saveError = false
    @State private var pendingEvent: DialogueTurnEvent?
    @State private var pendingSession: DialogueSession?

    private var current: DialogueNode? {
        session.flatMap { dialogue.node(id: $0.currentNodeId) }
    }

    private var partnerName: String {
        dialogue.partner ?? DialoguePracticeCopy.partnerFallback
    }

    /// The learner's own reply to an answered turn: the picked choice
    /// text (authored) or their composed draft — never an invented line.
    private func learnerReply(_ turn: DialogueTurnRecord) -> String? {
        if let choiceId = turn.choiceId,
           let node = dialogue.node(id: turn.nodeId),
           let choice = node.choices.first(where: { $0.id == choiceId }) {
            return choice.text
        }
        return turn.draft
    }

    private func feedback(for turn: DialogueTurnRecord) -> String? {
        guard let choiceId = turn.choiceId,
              let node = dialogue.node(id: turn.nodeId),
              let choice = node.choices.first(where: { $0.id == choiceId }),
              !choice.feedback.isEmpty else { return nil }
        return choice.feedback
    }

    private func resetOpenState() {
        openForm.reset(for: session)
    }

    var body: some View {
        NavigationStack {
            Group {
                if session == nil {
                    PlayerErrorView(message: DialoguePracticeCopy.couldNotStart,
                                    onExit: onClose)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            headerCard
                            transcript
                            turnArea
                            if session?.status == .complete {
                                learnerRecap
                            }
                        }
                        .padding(16)
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        bottomBar
                    }
                }
            }
            .navigationTitle(dialogue.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(DialoguePracticeCopy.done) { onClose() }
                }
            }
        }
        .onAppear { resetOpenState() }
        .onChange(of: session) { previous, current in
            if pendingEvent == nil, pendingSession == nil {
                openForm.sessionChanged(from: previous, to: current)
            }
        }
        .onChange(of: openForm.draftText) { _, newValue in
            guard let current, current.prompt != nil,
                  session?.currentNodeId == current.id else { return }
            if session?.openDraft != newValue {
                session?.openDraft = newValue
            }
        }
    }

    private var headerCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(DialoguePracticeCopy.hero)
                    .font(DesignTokens.text(11, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(DesignTokens.primary)
                Text(dialogue.goal)
                    .font(DesignTokens.text(15))
                    .foregroundStyle(DesignTokens.ink)
            }
        }
    }

    /// The conversation so far: partner lines and the learner's own
    /// replies, one bubble per turn, in the order they happened.
    private var transcript: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let session {
                ForEach(Array(session.turns.enumerated()), id: \.offset) { _, turn in
                    if let node = dialogue.node(id: turn.nodeId) {
                        partnerBubble(node: node)
                        learnerBubble(turn: turn)
                    }
                }
            }
        }
    }

    private func partnerBubble(node: DialogueNode) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(partnerName)
                .font(DesignTokens.text(12, weight: .medium))
                .foregroundStyle(DesignTokens.muted)
            Text(node.line)
                .font(DesignTokens.text(17))
                .foregroundStyle(DesignTokens.inkDeep)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignTokens.stock2)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(DesignTokens.edgeSoft, lineWidth: 1)
                )
            Text(node.meaning)
                .font(DesignTokens.text(13))
                .foregroundStyle(DesignTokens.muted)
        }
    }

    private func learnerBubble(turn: DialogueTurnRecord) -> some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(DialoguePracticeCopy.yourLine)
                .font(DesignTokens.text(12, weight: .medium))
                .foregroundStyle(DesignTokens.muted)
            if let reply = learnerReply(turn) {
                Text(reply)
                    .font(DesignTokens.text(17))
                    .foregroundStyle(DesignTokens.inkDeep)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DesignTokens.primarySoft)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(DesignTokens.primary, lineWidth: 1.5)
                    )
            }
            if let feedback = feedback(for: turn), !feedback.isEmpty {
                Text(feedback)
                    .font(DesignTokens.text(13))
                    .foregroundStyle(DesignTokens.muted)
            }
        }
    }

    /// The live turn: the partner's latest line plus the input the learner
    /// replies with (choices, or the open composer), or the end state.
    @ViewBuilder
    private var turnArea: some View {
        if let current {
            partnerBubble(node: current)
            if current.complete {
                VStack(alignment: .leading, spacing: 10) {
                    Text(DialoguePracticeCopy.endedNote)
                        .font(DesignTokens.text(14))
                        .foregroundStyle(DesignTokens.muted)
                    HStack(spacing: 10) {
                        StudioSecondaryButton(DialoguePracticeCopy.replayCta,
                                              disabled: saveError) { practiseAgain() }
                        StudioPrimaryButton(label: DialoguePracticeCopy.done,
                                            disabled: false) { onClose() }
                    }
                }
            } else if !current.choices.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(DialoguePracticeCopy.chooseYourReply)
                        .font(DesignTokens.text(14, weight: .medium))
                        .foregroundStyle(DesignTokens.muted)
                    ForEach(current.choices, id: \.text) { choice in
                        OptionRow(
                            text: choice.text,
                            selected: false,
                            multi: false,
                            disabled: saveError || pendingEvent != nil
                        ) {
                            choose(choice)
                        }
                    }
                }
            } else {
                openComposer(node: current)
            }
        }
    }

    /// Open turn: compose + self-assess against the authored rubric. The
    /// draft and judgement are the learner's own; the model is revealed
    /// only on an explicit action and marks the turn non-independent.
    @ViewBuilder
    private func openComposer(node: DialogueNode) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let prompt = node.prompt, !prompt.isEmpty {
                Text(prompt)
                    .font(DesignTokens.text(15, weight: .medium))
                    .foregroundStyle(DesignTokens.inkDeep)
            }
            if let guidance = node.lengthGuidance, !guidance.isEmpty {
                Text(guidance)
                    .font(DesignTokens.text(13))
                    .foregroundStyle(DesignTokens.muted)
            }
            Text(DialoguePracticeCopy.writeYourReply)
                .font(DesignTokens.text(14, weight: .medium))
                .foregroundStyle(DesignTokens.muted)
            TextEditor(text: $openForm.draftText)
                .font(DesignTokens.text(17))
                .foregroundStyle(DesignTokens.ink)
                .frame(minHeight: 110)
                .padding(8)
                .background(DesignTokens.canvas)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(DesignTokens.edge, lineWidth: 1.5)
                )
                .disabled(disabled)
                .accessibilityLabel(promptText(node))
            Text(OpenTaskCopy.writtenCaption)
                .font(DesignTokens.text(13))
                .foregroundStyle(DesignTokens.muted)

            rubricCard(node: node)

            if session?.openModelRevealed == true {
                Text(node.modelResponse ?? "")
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
                    session?.openModelRevealed = true
                }
            }

            StudioPrimaryButton(
                label: DialoguePracticeCopy.sendReply,
                disabled: disabled || !canSubmitOpen(node)
            ) {
                submitOpenTurn(node: node)
            }
            if !canSubmitOpen(node) {
                Text(DialoguePracticeCopy.answerFirst)
                    .font(DesignTokens.text(13))
                    .foregroundStyle(DesignTokens.muted)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private var disabled: Bool { saveError || pendingEvent != nil }

    private func promptText(_ node: DialogueNode) -> String {
        node.prompt ?? dialogue.goal
    }

    private func canSubmitOpen(_ node: DialogueNode) -> Bool {
        OpenTaskSubmission.canSubmit(mode: .written, submission: openSubmission)
    }

    private var openSubmission: OpenTaskSubmission {
        OpenTaskSubmission(
            text: openForm.draftText,
            criteriaMet: openForm.criteriaMet.sorted(),
            rating: openForm.rating,
            modelRevealed: session?.openModelRevealed == true)
    }

    private func rubricCard(node: DialogueNode) -> some View {
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
            ForEach(node.rubric ?? [], id: \.id) { criterion in
                OptionRow(
                    text: criterion.text,
                    selected: openForm.criteriaMet.contains(criterion.id),
                    multi: true,
                    disabled: disabled
                ) {
                    if openForm.criteriaMet.contains(criterion.id) {
                        openForm.criteriaMet.remove(criterion.id)
                    } else {
                        openForm.criteriaMet.insert(criterion.id)
                    }
                }
            }
            Text(OpenTaskCopy.rateYourself)
                .font(DesignTokens.text(15, weight: .medium))
                .foregroundStyle(DesignTokens.inkDeep)
            HStack(spacing: 8) {
                ForEach([AttemptResponse.SelfRating.again,
                         .hard, .good, .easy], id: \.self) { option in
                    let selected = openForm.rating == option
                    Button {
                        openForm.rating = openForm.rating == option ? nil : option
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
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.stock)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(DesignTokens.edge, lineWidth: 1.5)
        )
    }

    /// End-of-exchange recap: exactly what the learner supplied (picked
    /// choices and composed drafts), nothing invented, no grading claims.
    @ViewBuilder
    private var learnerRecap: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(DialoguePracticeCopy.recapTitle)
                    .font(DesignTokens.text(14, weight: .semibold))
                    .foregroundStyle(DesignTokens.inkDeep)
                Text(DialoguePracticeCopy.recapNote)
                    .font(DesignTokens.text(13))
                    .foregroundStyle(DesignTokens.muted)
                if let session {
                    ForEach(Array(session.turns.enumerated()), id: \.offset) { _, turn in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(DialoguePracticeCopy.yourLine)
                                .font(DesignTokens.text(12, weight: .medium))
                                .foregroundStyle(DesignTokens.muted)
                            if let reply = learnerReply(turn) {
                                Text(reply)
                                    .font(DesignTokens.text(16, weight: .medium))
                                    .foregroundStyle(DesignTokens.inkDeep)
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(DesignTokens.primarySoft)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(DesignTokens.primary, lineWidth: 1.5)
                                    )
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            if saveError {
                VStack(alignment: .leading, spacing: 8) {
                    Text(DialoguePracticeCopy.saveFailed)
                        .font(DesignTokens.text(14))
                        .foregroundStyle(DesignTokens.attentionInk)
                    StudioSecondaryButton(DialoguePracticeCopy.retry) { retrySave() }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(DesignTokens.canvas)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(DesignTokens.edgeSoft)
                .frame(height: 1)
        }
    }

    // MARK: Actions

    private func choose(_ choice: DialogueChoice) {
        guard let session, let current = current,
              pendingEvent == nil, let choiceId = choice.id else { return }
        let next: DialogueSession
        do {
            next = try submitDialogueChoice(
                pack: pack, session: session, choiceId: choiceId)
        } catch {
            return
        }
        recordTurn(from: session, engineNext: next, node: current,
                   choiceId: choiceId, criteriaMet: [], rating: nil,
                   modelRevealed: false)
    }

    private func submitOpenTurn(node: DialogueNode) {
        guard let session, pendingEvent == nil else { return }
        let submission = openSubmission
        guard OpenTaskSubmission.canSubmit(mode: .written, submission: submission) else {
            return
        }
        let next: DialogueSession
        do {
            next = try submitDialogueOpenTurn(
                pack: pack, session: session, draft: submission.text,
                criteriaMet: submission.criteriaMet, rating: submission.rating,
                modelRevealed: submission.modelRevealed)
        } catch {
            return
        }
        recordTurn(from: session, engineNext: next, node: node,
                   choiceId: nil, criteriaMet: submission.criteriaMet,
                   rating: submission.rating, modelRevealed: submission.modelRevealed)
    }

    /// Record the turn event (idempotent insert) BEFORE advancing the
    /// presented session, so a failed save holds the exchange in place and
    /// retry applies the same pending turn — never a duplicate, never a
    /// reorder.
    private func recordTurn(from previous: DialogueSession,
                            engineNext: DialogueSession,
                            node: DialogueNode,
                            choiceId: String?,
                            criteriaMet: [String],
                            rating: AttemptResponse.SelfRating?,
                            modelRevealed: Bool) {
        let isOpen = choiceId == nil
        let event = DialogueTurnEvent(
            id: UUID().uuidString,
            packId: pack.id,
            packVersion: pack.version,
            dialogueId: dialogue.id,
            hostLessonId: lesson.id,
            hostLessonRevision: lesson.revision,
            nodeId: node.id,
            turnIndex: engineNext.turns.count,
            isOpen: isOpen,
            choiceId: choiceId,
            criteriaMet: criteriaMet,
            rating: rating,
            modelRevealed: modelRevealed,
            at: Date())
        pendingEvent = event
        pendingSession = engineNext
        do {
            try store.record(.dialogueTurn(event))
            pendingEvent = nil
            pendingSession = nil
            self.session = engineNext
            resetOpenState()
        } catch {
            saveError = true
        }
    }

    private func retrySave() {
        guard let event = pendingEvent, let pending = pendingSession else { return }
        do {
            try store.record(.dialogueTurn(event))
            pendingEvent = nil
            pendingSession = nil
            saveError = false
            session = pending
            resetOpenState()
        } catch {
            saveError = true
        }
    }

    private func practiseAgain() {
        guard pendingEvent == nil else { return }
        do {
            session = try startDialogue(pack: pack, lesson: lesson, dialogue: dialogue)
            resetOpenState()
        } catch {
            // The exchange is already presented; nothing to recover here.
        }
    }
}

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
