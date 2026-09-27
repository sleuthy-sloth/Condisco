import Foundation

// MARK: - Lesson session engine
//
// Faithful port of the web app's `lesson-session.ts`: deterministic lesson
// session reducers. Pure functions — no storage, clocks, or random ID
// generation. The caller persists events between `submitResponse` and
// `advanceLesson`; advancing never writes.
//
// The resume logic is ported from `attempts.ts` (`resumeSession`).

// MARK: Pack lookups

extension CoursePack {
    func lesson(id: String) -> Lesson? {
        lessons.first { $0.id == id }
    }

    func activity(id: String) -> Activity? {
        activities.first { $0.id == id }
    }

    func stimulus(id: String) -> Stimulus? {
        stimuli.first { $0.id == id }
    }

    func media(id: String) -> MediaItem? {
        media.first { $0.id == id }
    }
}

// MARK: Session state

enum LessonSessionStatus: String, Equatable {
    case active, complete
}

struct LessonSession: Equatable {
    var lessonId: String
    var revision: Int
    var activeStepId: String
    var visitedStepIds: [String]
    var selectedBranches: [String: String]
    /// Support overlay: help activity shown over the current step.
    var activeSupportActivityId: String?
    var draftResponse: AttemptResponse?
    var accumulatedAssistance: [AssistanceKind]
    var currentEvaluation: AttemptEvaluation?
    var completedStepIds: [String]
    var status: LessonSessionStatus
}

enum LessonSessionError: Error, CustomStringConvertible {
    case unknownLesson(String)
    case lessonChanged(lessonId: String, from: Int, to: Int)
    case lessonComplete(String)
    case unknownStep(String)
    case unknownActivity(String)
    case noSupportActivity(String)
    case supportOpen
    case noEvaluation(String)
    case stepIncomplete(String)
    case branchNotChosen(String)

    var description: String {
        switch self {
        case .unknownLesson(let id): return "Unknown lesson \(id)"
        case .lessonChanged(let id, let from, let to):
            return "Lesson \(id) changed (r\(from) → r\(to)); restart the session"
        case .lessonComplete(let id): return "Lesson \(id) is complete"
        case .unknownStep(let id): return "Unknown step \(id)"
        case .unknownActivity(let id): return "Unknown activity \(id)"
        case .noSupportActivity(let id): return "Step \(id) has no support activity"
        case .supportOpen: return "Resolve the support activity before advancing"
        case .noEvaluation(let id): return "Step \(id) has no evaluation yet"
        case .stepIncomplete(let id): return "Step \(id) is not complete"
        case .branchNotChosen(let id): return "Step \(id) needs a chosen branch"
        }
    }
}

private func checkedLesson(pack: CoursePack, session: LessonSession) throws -> Lesson {
    guard let lesson = pack.lesson(id: session.lessonId) else {
        throw LessonSessionError.unknownLesson(session.lessonId)
    }
    guard lesson.revision == session.revision else {
        throw LessonSessionError.lessonChanged(lessonId: session.lessonId,
                                               from: session.revision,
                                               to: lesson.revision)
    }
    guard session.status == .active else {
        throw LessonSessionError.lessonComplete(session.lessonId)
    }
    return lesson
}

func startLesson(pack: CoursePack, lessonId: String) throws -> LessonSession {
    guard let lesson = pack.lesson(id: lessonId) else {
        throw LessonSessionError.unknownLesson(lessonId)
    }
    return LessonSession(
        lessonId: lessonId,
        revision: lesson.revision,
        activeStepId: lesson.entryStepId,
        visitedStepIds: [lesson.entryStepId],
        selectedBranches: [:],
        activeSupportActivityId: nil,
        draftResponse: nil,
        accumulatedAssistance: [],
        currentEvaluation: nil,
        completedStepIds: [],
        status: .active)
}

func orderedUnion(_ base: [AssistanceKind], _ additions: [AssistanceKind]) -> [AssistanceKind] {
    var seen = Set<AssistanceKind>()
    return (base + additions).filter { seen.insert($0).inserted }
}

/// Show the active step's support activity; submission returns to the step.
func openSupport(pack: CoursePack, session: LessonSession) throws -> LessonSession {
    let lesson = try checkedLesson(pack: pack, session: session)
    guard let step = lesson.steps.first(where: { $0.id == session.activeStepId }),
          let supportId = step.supportActivityId else {
        throw LessonSessionError.noSupportActivity(session.activeStepId)
    }
    var next = session
    next.activeSupportActivityId = supportId
    next.accumulatedAssistance = orderedUnion(session.accumulatedAssistance, [.hint])
    return next
}

func submitResponse(pack: CoursePack,
                    session: LessonSession,
                    response: AttemptResponse,
                    assistance: [AssistanceKind]) throws -> LessonSession {
    let lesson = try checkedLesson(pack: pack, session: session)
    guard let step = lesson.steps.first(where: { $0.id == session.activeStepId }) else {
        throw LessonSessionError.unknownStep(session.activeStepId)
    }
    let activityId = session.activeSupportActivityId ?? step.activityId
    guard let activity = pack.activity(id: activityId) else {
        throw LessonSessionError.unknownActivity(activityId)
    }

    let merged = orderedUnion(session.accumulatedAssistance, assistance)
    let evaluation = ActivityEvaluation.evaluate(
        activity: activity, response: response, assistance: merged,
        legacyExercises: lesson.legacyExercises)

    // Support submissions never complete the step; they return to it with the
    // assistance carried into retries.
    if session.activeSupportActivityId != nil {
        var next = session
        next.activeSupportActivityId = nil
        next.accumulatedAssistance = merged
        next.currentEvaluation = nil
        return next
    }

    let completed: Bool
    switch evaluation.outcome {
    case .correct, .ungraded, .selfAssessed: completed = true
    case .incorrect, .blocked: completed = false
    }
    var completedStepIds: [String]
    if completed {
        var seen = Set<String>()
        completedStepIds = (session.completedStepIds + [step.id]).filter { seen.insert($0).inserted }
    } else {
        completedStepIds = session.completedStepIds.filter { $0 != step.id }
    }

    // Record the chosen branch once a dialogue reply is submitted; the step
    // completes only on an accepted reply, so the recorded branch is valid.
    var selectedBranches = session.selectedBranches
    if completed, case .selection(let ids) = response,
       !step.branches.isEmpty, ids.count == 1, step.branches[ids[0]] != nil {
        selectedBranches[step.id] = ids[0]
    }

    var next = session
    next.selectedBranches = selectedBranches
    next.draftResponse = response
    next.accumulatedAssistance = merged
    next.currentEvaluation = evaluation
    next.completedStepIds = completedStepIds
    return next
}

func advanceLesson(pack: CoursePack, session: LessonSession) throws -> LessonSession {
    let lesson = try checkedLesson(pack: pack, session: session)
    guard session.activeSupportActivityId == nil else {
        throw LessonSessionError.supportOpen
    }
    guard session.currentEvaluation != nil else {
        throw LessonSessionError.noEvaluation(session.activeStepId)
    }
    guard session.completedStepIds.contains(session.activeStepId) else {
        throw LessonSessionError.stepIncomplete(session.activeStepId)
    }
    guard let step = lesson.steps.first(where: { $0.id == session.activeStepId }) else {
        throw LessonSessionError.unknownStep(session.activeStepId)
    }

    var nextStepId = step.nextStepId
    if !step.branches.isEmpty {
        guard let chosen = session.selectedBranches[step.id],
              step.branches[chosen] != nil else {
            throw LessonSessionError.branchNotChosen(step.id)
        }
        nextStepId = step.branches[chosen]
    }
    guard let following = nextStepId else {
        var done = session
        done.status = .complete
        return done
    }
    var next = session
    next.activeStepId = following
    // Shared reference reveals may remain visible; an earlier activity's
    // hint/model must not taint an unrelated independent transfer forever.
    next.accumulatedAssistance = session.accumulatedAssistance.filter {
        $0 == .translation || $0 == .transcript
    }
    next.visitedStepIds = session.visitedStepIds + [following]
    next.draftResponse = nil
    next.currentEvaluation = nil
    return next
}

// MARK: - Trail

/// Steps along the chosen branch path, entry → terminal.
func walkTrail(lesson: Lesson, selectedBranches: [String: String]) -> [String] {
    let steps = Dictionary(uniqueKeysWithValues: lesson.steps.map { ($0.id, $0) })
    var trail: [String] = []
    var seen = Set<String>()
    var current: String? = lesson.entryStepId
    while let stepId = current, !seen.contains(stepId) {
        seen.insert(stepId)
        trail.append(stepId)
        guard let step = steps[stepId] else { break }
        if step.branches.isEmpty {
            current = step.nextStepId
        } else {
            current = step.branches[selectedBranches[stepId] ?? ""]
        }
    }
    return trail
}

// MARK: - Think gate

/// The think-first gate. A `predict` step carrying a text activity is a
/// prediction, not a prompt to copy: the input stays hidden until the learner
/// commits. Clearing the gate is a commitment, not assistance: it must never
/// taint the attempt, or a predicted answer would stop earning full credit the
/// moment the learner asked for the input.
struct ThinkGateState {
    private var cleared: Set<String> = []

    func isCleared(stepId: String) -> Bool {
        cleared.contains(stepId)
    }

    mutating func clear(stepId: String) {
        cleared.insert(stepId)
    }
}

// MARK: - Resume

enum ResumeResult {
    case resume(session: LessonSession)
    case restart(explanation: String)
}

/// Rebuild a session from a saved checkpoint and the event log. Mirrors the
/// web `resumeSession`: the checkpoint wins when it is still valid, otherwise
/// the lesson restarts with attempts and completion credits preserved.
/// `quarantined` holds event ids the store projection held out (rows whose
/// payload could not be decoded, revision drift, retired targets); callers
/// get it from `LearningStore.project`.
func resumeSession(pack: CoursePack,
                   checkpoint: LessonCheckpoint,
                   events: [LearningEvent],
                   quarantined: Set<String> = []) -> ResumeResult {
    guard checkpoint.packId == pack.id else {
        return .restart(explanation: "This checkpoint belongs to another course.")
    }
    guard let lesson = pack.lesson(id: checkpoint.lessonId) else {
        return .restart(explanation:
            "That lesson no longer exists. Your attempts and completion credits are preserved.")
    }
    guard lesson.revision == checkpoint.revision else {
        return .restart(explanation:
            "That lesson changed (revision \(checkpoint.revision) → \(lesson.revision)). " +
            "This lesson restarts; your attempts and completion credits are preserved.")
    }
    let steps = Dictionary(uniqueKeysWithValues: lesson.steps.map { ($0.id, $0) })
    guard steps[checkpoint.stepId] != nil else {
        return .restart(explanation:
            "That step no longer exists. This lesson restarts; your attempts and completion credits are preserved.")
    }
    // Rebuild the visited trail along the recorded branches.
    var trail: [String] = []
    var current: String? = lesson.entryStepId
    var seen = Set<String>()
    while let stepId = current, !seen.contains(stepId) {
        seen.insert(stepId)
        trail.append(stepId)
        if stepId == checkpoint.stepId { break }
        guard let step = steps[stepId] else { break }
        if step.branches.isEmpty {
            current = step.nextStepId
        } else {
            current = step.branches[checkpoint.selectedBranches[stepId] ?? ""]
        }
    }
    guard trail.last == checkpoint.stepId else {
        return .restart(explanation:
            "That path through the lesson changed. This lesson restarts; your attempts and completion credits are preserved.")
    }

    let completedStepIds = stepCompletions(packId: pack.id, lesson: lesson,
                                             events: events, quarantined: quarantined)

    do {
        var session = try startLesson(pack: pack, lessonId: lesson.id)
        session.activeStepId = checkpoint.stepId
        session.visitedStepIds = trail
        session.selectedBranches = checkpoint.selectedBranches
        session.accumulatedAssistance = checkpoint.assistance
        session.draftResponse = checkpoint.draft
        var seenIds = Set<String>()
        session.completedStepIds = completedStepIds.filter { seenIds.insert($0).inserted }
        return .resume(session: session)
    } catch {
        return .restart(explanation: "That lesson could not be restarted cleanly. Your attempts and completion credits are preserved.")
    }
}

/// Step ids with a valid step-completed event for this lesson revision.
/// (Quarantine filtering lives in the store projection; completions that
/// fail structural validation are ignored here the way the web's
/// `resumeSession` ignores quarantined ids.)
private func stepCompletions(packId: String, lesson: Lesson,
                             events: [LearningEvent],
                             quarantined: Set<String>) -> [String] {
    let stepIds = Set(lesson.steps.map { $0.id })
    return events.compactMap { event -> String? in
        guard case .stepCompleted(let completion) = event,
              !quarantined.contains(completion.id),
              completion.packId == packId,
              completion.lessonId == lesson.id,
              completion.lessonRevision == lesson.revision,
              stepIds.contains(completion.stepId) else { return nil }
        return completion.stepId
    }
}

// MARK: - Dialogue sessions (Phase 6.3)
//
// Branching exchange practice, driven by the same discipline as lesson
// sessions: deterministic pure reducers, the caller persists state between
// turns (lesson checkpoint + one `DialogueTurnEvent` per answered turn).
// The learner interprets the partner's latest line, then either picks an
// authored choice or composes against a 6.2-style self-check rubric. Every
// branch is authored and finite; position + answered turns live in
// `LessonCheckpoint.dialogue`, so force-quit resumes exactly and recorded
// events are never reordered or duplicated (a branch change mid-attempt
// only appends later turns in authored order).

enum DialogueSessionStatus: String, Equatable {
    case active, complete
}

/// In-memory state of one exchange attempt. Value-typed like
/// `LessonSession`; the caller persists `checkpointState()` between turns
/// and rebuilds with `init(checkpointState:)` on resume.
struct DialogueSession: Equatable {
    var dialogueId: String
    var hostLessonId: String
    var currentNodeId: String
    var visitedNodeIds: [String]
    /// Answered turns in authored order — the learner's own replies, used
    /// verbatim by the recap.
    var turns: [DialogueTurnRecord]
    /// In-progress draft on the current open turn (resume support).
    var openDraft: String?
    var status: DialogueSessionStatus

    func checkpointState() -> DialogueCheckpointState {
        DialogueCheckpointState(
            dialogueId: dialogueId,
            currentNodeId: currentNodeId,
            visitedNodeIds: visitedNodeIds,
            turns: turns,
            openDraft: openDraft,
            complete: status == .complete)
    }

    init(checkpointState: DialogueCheckpointState) {
        dialogueId = checkpointState.dialogueId
        hostLessonId = ""
        currentNodeId = checkpointState.currentNodeId
        visitedNodeIds = checkpointState.visitedNodeIds
        turns = checkpointState.turns
        openDraft = checkpointState.openDraft
        status = checkpointState.complete ? .complete : .active
    }

    init(dialogueId: String, hostLessonId: String, currentNodeId: String,
         visitedNodeIds: [String], turns: [DialogueTurnRecord],
         openDraft: String?, status: DialogueSessionStatus) {
        self.dialogueId = dialogueId
        self.hostLessonId = hostLessonId
        self.currentNodeId = currentNodeId
        self.visitedNodeIds = visitedNodeIds
        self.turns = turns
        self.openDraft = openDraft
        self.status = status
    }
}

enum DialogueSessionError: Error, CustomStringConvertible {
    case unknownDialogue(String)
    case unhosted(dialogue: String, lesson: String)
    case unknownNode(dialogue: String, node: String)
    case dialogueComplete(String)
    case unknownChoice(choice: String, node: String)
    case notAChoiceTurn(String)
    case notAnOpenTurn(String)
    case emptyDraft(String)

    var description: String {
        switch self {
        case .unknownDialogue(let id): return "Unknown dialogue \(id)"
        case .unhosted(let dialogue, let lesson):
            return "Dialogue \(dialogue) is not hosted by lesson \(lesson)"
        case .unknownNode(let dialogue, let node):
            return "Dialogue \(dialogue) has no node \(node)"
        case .dialogueComplete(let id): return "Dialogue \(id) is complete"
        case .unknownChoice(let choice, let node):
            return "Node \(node) has no choice \(choice)"
        case .notAChoiceTurn(let node): return "Node \(node) is not a choice turn"
        case .notAnOpenTurn(let node): return "Node \(node) is not an open turn"
        case .emptyDraft(let node): return "Node \(node) needs a composed reply"
        }
    }
}

/// A session's current node, resolved for the reducers below.
private func currentDialogueNode(pack: CoursePack,
                                 session: DialogueSession) throws -> DialogueNode {
    guard let dialogue = pack.dialogue(id: session.dialogueId) else {
        throw DialogueSessionError.unknownDialogue(session.dialogueId)
    }
    guard let node = dialogue.node(id: session.currentNodeId) else {
        throw DialogueSessionError.unknownNode(dialogue: dialogue.id, node: session.currentNodeId)
    }
    return node
}

/// Open a hosted exchange fresh: branch position at `dialogue.start`,
/// no turns recorded yet. The learner may replay a completed exchange by
/// calling this again — a new attempt with fresh turn events.
func startDialogue(pack: CoursePack, lesson: Lesson,
                   dialogue: Dialogue) throws -> DialogueSession {
    guard dialogue.hostLessonId == lesson.id else {
        throw DialogueSessionError.unhosted(dialogue: dialogue.id, lesson: lesson.id)
    }
    guard dialogue.node(id: dialogue.start) != nil else {
        throw DialogueSessionError.unknownNode(dialogue: dialogue.id, node: dialogue.start)
    }
    return DialogueSession(
        dialogueId: dialogue.id,
        hostLessonId: lesson.id,
        currentNodeId: dialogue.start,
        visitedNodeIds: [dialogue.start],
        turns: [],
        openDraft: nil,
        status: .active)
}

/// Answer the current choice turn by picking an authored option. The
/// partner's next line is the picked choice's `next` node; answering the
/// last turn lands on the end state and completes the exchange.
func submitDialogueChoice(pack: CoursePack,
                          session: DialogueSession,
                          choiceId: String) throws -> DialogueSession {
    guard session.status == .active else {
        throw DialogueSessionError.dialogueComplete(session.dialogueId)
    }
    let node = try currentDialogueNode(pack: pack, session: session)
    guard !node.complete else {
        throw DialogueSessionError.dialogueComplete(session.dialogueId)
    }
    guard !node.choices.isEmpty else {
        throw DialogueSessionError.notAChoiceTurn(node.id)
    }
    guard let choice = node.choices.first(where: { $0.id == choiceId }) else {
        throw DialogueSessionError.unknownChoice(choice: choiceId, node: node.id)
    }
    var next = session
    next.turns.append(DialogueTurnRecord(nodeId: node.id, choiceId: choice.id))
    let following = choice.next
    next.currentNodeId = following
    next.visitedNodeIds = session.visitedNodeIds + [following]
    if let followingNode = pack.dialogue(id: session.dialogueId)?.node(id: following),
       followingNode.complete {
        next.status = .complete
    }
    return next
}

/// Answer the current open turn: the learner's own composed reply plus their
/// self-assessment (rubric ticks, optional rating, model-reveal marker).
/// The partner replies with the node's `next`; nothing here grades the
/// draft — the rubric is the learner's own judgement.
func submitDialogueOpenTurn(pack: CoursePack,
                            session: DialogueSession,
                            draft: String,
                            criteriaMet: [String],
                            rating: AttemptResponse.SelfRating?,
                            modelRevealed: Bool) throws -> DialogueSession {
    guard session.status == .active else {
        throw DialogueSessionError.dialogueComplete(session.dialogueId)
    }
    let node = try currentDialogueNode(pack: pack, session: session)
    guard !node.complete else {
        throw DialogueSessionError.dialogueComplete(session.dialogueId)
    }
    guard node.prompt != nil, node.choices.isEmpty else {
        throw DialogueSessionError.notAnOpenTurn(node.id)
    }
    let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, let nextId = node.next else {
        throw DialogueSessionError.emptyDraft(node.id)
    }
    var next = session
    next.turns.append(DialogueTurnRecord(
        nodeId: node.id, draft: trimmed, criteriaMet: criteriaMet,
        rating: rating, modelRevealed: modelRevealed))
    next.currentNodeId = nextId
    next.visitedNodeIds = session.visitedNodeIds + [nextId]
    next.openDraft = nil
    if let dialogue = pack.dialogue(id: session.dialogueId),
       let following = dialogue.node(id: nextId),
       following.complete {
        next.status = .complete
    }
    return next
}

/// Rebuild an exchange from its checkpoint slice. Replays the stored turns
/// against the authored graph to prove the recorded branch position is
/// consistent; returns nil when the exchange (or its position) no longer
/// resolves or the thread does not replay along real edges — the player
/// then presents the exchange fresh. Mirrors how `resumeSession` restarts
/// a lesson whose path changed.
func resumeDialogueSession(pack: CoursePack,
                           state: DialogueCheckpointState) -> DialogueSession? {
    guard let dialogue = pack.dialogue(id: state.dialogueId),
          dialogue.node(id: state.currentNodeId) != nil else {
        return nil
    }
    // Replay the recorded turns: each answered node must route along real
    // edges to the next visited node, in order.
    var current = dialogue.start
    var consistent = state.visitedNodeIds.first == current
    if consistent {
        for (index, turn) in state.turns.enumerated() {
            guard let node = dialogue.node(id: turn.nodeId),
                  node.id == current,
                  !node.complete,
                  index + 1 < state.visitedNodeIds.count else {
                consistent = false
                break
            }
            let following: String?
            if !node.choices.isEmpty {
                following = node.choices.first { $0.id == turn.choiceId }?.next
            } else {
                following = node.next
            }
            guard let following,
                  following == state.visitedNodeIds[index + 1] else {
                consistent = false
                break
            }
            current = following
        }
        if consistent, state.visitedNodeIds.last != state.currentNodeId {
            consistent = false
        }
    }
    guard consistent else { return nil }
    return DialogueSession(
        dialogueId: dialogue.id,
        hostLessonId: dialogue.hostLessonId ?? "",
        currentNodeId: state.currentNodeId,
        visitedNodeIds: state.visitedNodeIds,
        turns: state.turns,
        openDraft: state.openDraft,
        status: state.complete ? .complete : .active)
}
