import SwiftUI
import UIKit

/// Keep the passage beside a question aligned with the latest visited scene.
/// Story lessons introduce new paragraphs mid-lesson, so falling back to the
/// entry stimulus would send the learner to the wrong paragraph.
func currentContextStimulus(pack: CoursePack, lesson: Lesson,
                            visitedStepIds: [String], activeStepId: String) -> Stimulus? {
    guard let activeIndex = visitedStepIds.lastIndex(of: activeStepId) else { return nil }
    for stepId in visitedStepIds[...activeIndex].reversed() {
        guard let step = lesson.steps.first(where: { $0.id == stepId }),
              let stimulusId = pack.activity(id: step.activityId)?.stimulusId
        else { continue }
        if let stimulus = pack.stimulus(id: stimulusId) { return stimulus }
    }
    return nil
}

// MARK: - Lesson player
//
// Faithful port of the web `LessonPlayer`: deterministic session reducers
// drive the UI; every submit persists its events before the session moves on;
// checkpoints save on session/draft change so leaving mid-lesson resumes
// exactly where the learner stopped.

struct LessonPlayerView: View {
    let pack: CoursePack
    let store: LearningStore
    let onExit: () -> Void

    /// The lesson currently open in the player. Starts as the launched
    /// lesson; the recap's "Next" button moves it without dismissing.
    @State private var activeLessonId: String
    @State private var session: LessonSession?
    @State private var draft: AttemptResponse?
    @State private var assistanceUsed: [AssistanceKind] = []
    @State private var thinkGate = ThinkGateState()
    @State private var pendingEvents: [LearningEvent] = []
    @State private var pendingSession: LessonSession?
    @State private var pendingAutoAdvance = false
    @State private var saveError = false
    @State private var engineError: String?
    @State private var checkpointError: String?
    @State private var resumedComplete = false
    @State private var restartNotice: String?
    @State private var bootstrapped = false
    @StateObject private var audioPlayer = LessonAudioPlayer()
    /// Brand-new lessons open with the briefing; resumes go straight in.
    @State private var showBriefing = false
    /// Steps whose evaluation came back incorrect or blocked this run —
    /// the recap offers them for one more try.
    @State private var troubleStepIds: [String] = []
    @State private var retryQueue: [String] = []
    @State private var retrying = false
    /// One-time guide to the lesson controls, shown on the first step
    /// the learner ever opens.
    @AppStorage("condisco.hasSeenLessonGuide") private var hasSeenLessonGuide = false
    @State private var showLessonGuide = false

    init(pack: CoursePack, lessonId: String, store: LearningStore, onExit: @escaping () -> Void) {
        self.pack = pack
        self.store = store
        self.onExit = onExit
        _activeLessonId = State(initialValue: lessonId)
    }

    // MARK: Derived

    private var lesson: Lesson? { pack.lesson(id: activeLessonId) }

    private var step: LessonStep? {
        guard let lesson, let session else { return nil }
        return lesson.steps.first { $0.id == session.activeStepId }
    }

    private var mainActivity: Activity? {
        guard let step else { return nil }
        return pack.activity(id: step.activityId)
    }

    private var supportOpen: Bool { session?.activeSupportActivityId != nil }

    private var activity: Activity? {
        guard let session else { return nil }
        if let supportId = session.activeSupportActivityId {
            return pack.activity(id: supportId)
        }
        return mainActivity
    }

    private var stepCompleted: Bool {
        guard let session, let step else { return false }
        return session.completedStepIds.contains(step.id)
    }

    private var evaluation: AttemptEvaluation? { session?.currentEvaluation }

    private var contextStimulus: Stimulus? {
        guard let lesson, let session else { return nil }
        return currentContextStimulus(
            pack: pack, lesson: lesson, visitedStepIds: session.visitedStepIds,
            activeStepId: session.activeStepId)
    }

    private var thinkGateActive: Bool {
        guard let step, let activity = mainActivity else { return false }
        if case .text = activity, step.purpose == .predict {
            return !thinkGate.isCleared(stepId: step.id)
        }
        return false
    }

    private var trailProgress: (done: Int, total: Int) {
        guard let lesson, let session else { return (0, 0) }
        let trail = walkTrail(lesson: lesson, selectedBranches: session.selectedBranches)
        let stepsById = Dictionary(uniqueKeysWithValues: lesson.steps.map { ($0.id, $0) })
        let required = trail.filter { stepsById[$0]?.required == true }
        let done = required.filter { session.completedStepIds.contains($0) }.count
        return (done, required.count)
    }

    /// The lesson after this one in the course, for the recap's way onward.
    private var nextLessonInPack: Lesson? {
        guard let lesson else { return nil }
        guard let idx = pack.lessons.firstIndex(where: { $0.id == lesson.id }) else { return nil }
        let next = idx + 1
        guard next < pack.lessons.count else { return nil }
        return pack.lessons[next]
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            Group {
                if session == nil {
                    if let checkpointError {
                        PlayerErrorView(message: checkpointError, onExit: onExit)
                    } else {
                        ProgressView("Loading lesson…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else if showBriefing, let lesson {
                    LessonBriefingView(
                        lesson: lesson, pack: pack,
                        stepCount: trailProgress.total,
                        keyPhrases: keyPhrases(for: lesson, pack: pack, limit: 3),
                        onStart: { showBriefing = false },
                        onExit: onExit)
                } else if resumedComplete && !retrying, let lesson {
                    LessonRecapView(
                        lesson: lesson, pack: pack,
                        stepsDone: trailProgress.done, stepsTotal: trailProgress.total,
                        troubleCount: troubleStepIds.count,
                        keyPhrases: keyPhrases(for: lesson, pack: pack, limit: 4),
                        nextLesson: nextLessonInPack,
                        onRevisitTroubleSpots: startRetry,
                        onNextLesson: { switchLesson(to: $0) },
                        onExit: onExit)
                } else if let step, let activity {
                    playerContent(step: step, activity: activity)
                        .overlay {
                            if showLessonGuide {
                                LessonGuideOverlay {
                                    showLessonGuide = false
                                    hasSeenLessonGuide = true
                                }
                            }
                        }
                        .onAppear {
                            if !hasSeenLessonGuide { showLessonGuide = true }
                        }
                } else {
                    PlayerErrorView(message: "That step is not in this lesson anymore.", onExit: onExit)
                }
            }
            .navigationBarBackButtonHidden(true)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(lesson?.title ?? "Lesson")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Lessons") { handleBack() }
                }
            }
        }
        .onAppear { if !bootstrapped { bootstrapped = true; boot() } }
        .onChange(of: session) { _, _ in saveCheckpointNow() }
        .onChange(of: draft) { _, _ in saveCheckpointNow() }
    }

    // MARK: Content

    @ViewBuilder
    private func playerContent(step: LessonStep, activity: Activity) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PlayerProgressHeader(done: trailProgress.done, total: trailProgress.total)

                    if let checkpointError {
                        PlayerNoticeView(text: checkpointError)
                    }

                    if let engineError {
                        PlayerNoticeView(text: engineError)
                    }

                    if let notice = restartNotice {
                        PlayerNoticeView(text: notice)
                    }

                    stepSlide(step: step, activity: activity)

                    if saveError {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Not saved — check your connection and try again.")
                                .font(DesignTokens.text(14))
                                .foregroundStyle(DesignTokens.attentionInk)
                            StudioSecondaryButton("Retry save") { retrySave() }
                        }
                    }

                    if let supportId = session?.activeSupportActivityId,
                       pack.activity(id: supportId) != nil {
                        Text("This help step does not affect your score.")
                            .font(DesignTokens.text(13))
                            .foregroundStyle(DesignTokens.muted)
                    }

                    if !supportOpen && !stepCompleted && !saveError {
                        HStack {
                            Spacer()
                            if step.supportActivityId != nil {
                                StudioSecondaryButton("I need help") { handleHelp() }
                            }
                        }
                    }
                }
                .padding(16)
                .id("playerTop")
                // Calm slide between steps; the root transaction already
                // disables animations when reduce motion is on.
                .animation(.easeInOut(duration: 0.25), value: step.id)
            }
            .onChange(of: step.id) { _, _ in
                proxy.scrollTo("playerTop", anchor: .top)
            }
            .onChange(of: evaluation) { _, result in
                guard result != nil else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("answerFeedback", anchor: .bottom)
                }
            }
        }
    }

    /// The step-varying slice of the player: feedback, body, and primary
    /// action slide as one when the step changes.
    @ViewBuilder
    private func stepSlide(step: LessonStep, activity: Activity) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            stepBody(step: step, activity: activity)

            if let evaluation, evaluation.outcome != .ungraded {
                PlayerFeedbackView(evaluation: evaluation)
                    .id("answerFeedback")
            } else if !stepCompleted && assistanceTainted {
                PlayerNoticeView(text: "Help was used on this step, so it will not count as independent practice.")
            }

            primaryButton(step: step, activity: activity)
        }
        .id("step-\(step.id)")
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)))
    }

    // MARK: Family body

    /// Step body arranged per lesson family: conversation lessons frame the
    /// objective as a goal and open the dialogue; story and listening lessons
    /// open their passage or audio in a labeled card; discovery keeps the
    /// compact disclosure. Mirrors the web family layouts.
    @ViewBuilder
    private func stepBody(step: LessonStep, activity: Activity) -> some View {
        let family = lesson?.family ?? .discovery
        let isEntry = step.id == lesson?.entryStepId
        let compactContext = (family == .mission && !isEntry)
            || (family == .story && !isInformation(activity))
        // A full scene belongs to the reading step; question screens keep
        // the prompt and answer visible without another tall illustration.
        if !compactContext,
           let id = lesson?.id, let artURL = sceneArtURL(forLessonId: id) {
            SceneArtCard(url: artURL)
        }
        if (family == .mission || family == .story) && !isEntry {
            // The first reading carries the goal; repeating it before every
            // answer pushes the actual question off the phone.
        } else if family == .conversation {
            if let objective = lesson?.objective, !objective.isEmpty {
                ConversationGoalBanner(objective: objective)
            }
        } else {
            objectiveView()
        }
        if compactContext {
            if let stimulus = contextStimulus {
                DisclosureGroup(family == .story
                                ? "Read the passage again" : "Review the mission notes") {
                    StimulusContextView(stimulus: stimulus, pack: pack,
                                        onAssist: recordAssistance, audioPlayer: audioPlayer)
                        .id(stimulus.id)
                        .padding(.top, 4)
                }
                .font(DesignTokens.text(15, weight: .medium))
                .foregroundStyle(DesignTokens.ink)
            }
        } else {
            familyContextSection(family: family)
        }
        promptView()
        activitySection(step: step, activity: activity)
    }

    private func isInformation(_ activity: Activity) -> Bool {
        if case .information = activity { return true }
        return false
    }

    @ViewBuilder
    private func objectiveView() -> some View {
        if let objective = lesson?.objective, !objective.isEmpty {
            Text(objective)
                .font(DesignTokens.text(15))
                .foregroundStyle(DesignTokens.muted)
        }
    }

    @ViewBuilder
    private func familyContextSection(family: LessonFamily) -> some View {
        if let stimulus = contextStimulus {
            if family == .discovery {
                DisclosureGroup("Context") {
                    StimulusContextView(stimulus: stimulus, pack: pack,
                                        onAssist: recordAssistance, audioPlayer: audioPlayer)
                        .id(stimulus.id)
                        .padding(.top, 4)
                }
                .font(DesignTokens.text(15, weight: .medium))
                .foregroundStyle(DesignTokens.ink)
            } else {
                FamilyContextCard(label: familyContextLabel(family)) {
                    StimulusContextView(stimulus: stimulus, pack: pack,
                                        onAssist: recordAssistance, audioPlayer: audioPlayer)
                        .id(stimulus.id)
                }
            }
        }
    }

    @ViewBuilder
    private func promptView() -> some View {
        if let main = mainActivity, let prompt = activityPrompt(for: main) {
            Text(prompt)
                .font(DesignTokens.text(17, weight: .semibold))
                .foregroundStyle(DesignTokens.inkDeep)
        }
    }

    @ViewBuilder
    private func activitySection(step: LessonStep, activity: Activity) -> some View {
        if thinkGateActive {
            ThinkGateView { thinkGate.clear(stepId: step.id) }
        } else if supportOpen {
            // The support overlay is scaffolding, not a graded step:
            // it renders presentationally and its Continue button
            // closes it without recording events.
            ActivityView(activity: activity, stimulus: contextStimulus,
                         pack: pack, audioPlayer: audioPlayer,
                         draft: .constant(nil), disabled: false,
                         onAssist: recordAssistance)
            .id(activity.id)
        } else {
            ActivityView(activity: activity, stimulus: contextStimulus,
                         pack: pack, audioPlayer: audioPlayer,
                         draft: $draft, disabled: stepCompleted || saveError,
                         onAssist: recordAssistance)
            .id(activity.id)
        }
    }

    private var assistanceTainted: Bool {
        guard let session else { return false }
        // A reveal taints the attempt the moment an evidence-bearing kind is
        // used, not only once it is saved — the same rule evaluateActivity
        // applies, so the learner hears it while they can still choose to
        // answer from memory.
        let affects = activity?.base?.assistanceAffectsEvidence ?? []
        return (session.accumulatedAssistance + assistanceUsed).contains { kind in
            kind == .model || affects.contains(kind)
        }
    }

    /// The web blocks checking while an audio stimulus failed to load, so a
    /// learner never submits against a silent step.
    private var audioBlocked: Bool {
        guard let stimulus = contextStimulus else { return false }
        if case .audio = stimulus { return audioPlayer.failed }
        return false
    }

    private func activityPrompt(for activity: Activity) -> String? {
        switch activity {
        case .information: return "Read"
        case .selfCompare(let spec): return spec.prompt
        default: return activity.base?.prompt
        }
    }

    // MARK: Primary button

    @ViewBuilder
    private func primaryButton(step: LessonStep, activity: Activity) -> some View {
        if supportOpen {
            StudioPrimaryButton(label: "Continue", disabled: saveError || audioBlocked) { handleSubmit() }
        } else if !stepCompleted {
            if case .information = activity {
                StudioPrimaryButton(label: "Continue", disabled: false) { handleSubmit() }
            } else {
                StudioPrimaryButton(label: "Check",
                                    disabled: !validDraft(draft) || saveError || audioBlocked) {
                    handleSubmit()
                }
                if evaluation?.outcome == .incorrect,
                   modelResponse(for: activity) != nil {
                    StudioSecondaryButton("Continue with model answer") {
                        handleUseModelAnswer(activity: activity)
                    }
                }
            }
        } else {
            let terminal = step.nextStepId == nil && step.branches.isEmpty
            StudioPrimaryButton(label: terminal ? "Finish lesson" : "Next step",
                                disabled: saveError) { handleAdvance() }
        }
    }

    // MARK: Assistance

    private func recordAssistance(_ kind: AssistanceKind) {
        if !assistanceUsed.contains(kind) {
            assistanceUsed.append(kind)
        }
    }

    // MARK: Engine actions

    @MainActor
    private func boot() {
        guard let lesson else {
            checkpointError = "That lesson is not in this course."
            return
        }
        do {
            let storedCheckpoint = try store.loadCheckpoint(packId: pack.id, lessonId: lesson.id)
            let events = try store.learningEvents(packId: pack.id)
            let quarantined = Set(try store.project(pack: pack).quarantined)
            var checkpoint = storedCheckpoint
            // Opening the briefing creates an entry-step checkpoint before
            // the learner taps Start lesson. Keep showing that briefing if
            // they leave and come back without attempting a step.
            let hasLessonAttempt = events.contains { event in
                switch event {
                case .attempt(let attempt):
                    return attempt.lessonId == lesson.id
                case .stepCompleted(let completion):
                    return completion.lessonId == lesson.id
                default:
                    return false
                }
            }
            let unstartedEntry = storedCheckpoint?.stepId == lesson.entryStepId
                && storedCheckpoint?.draft == nil && !hasLessonAttempt
            // A brand-new lesson (no checkpoint, no history) opens with the
            // briefing; anything resumed or restarted from history goes
            // straight to the step.
            var openedFresh = storedCheckpoint == nil
            if checkpoint == nil {
                // No checkpoint but completions exist (for example, the
                // checkpoint was lost): synthesize one at the first
                // incomplete step along the recorded branch path.
                let completed = events.compactMap { event -> StepCompletion? in
                    guard case .stepCompleted(let completion) = event,
                          completion.packId == pack.id,
                          completion.lessonId == lesson.id,
                          completion.lessonRevision == lesson.revision,
                          !quarantined.contains(completion.id) else { return nil }
                    return completion
                }
                if !completed.isEmpty {
                    var selectedBranches: [String: String] = [:]
                    for completion in completed {
                        if let branch = completion.selectedBranchId {
                            selectedBranches[completion.stepId] = branch
                        }
                    }
                    let trail = walkTrail(lesson: lesson, selectedBranches: selectedBranches)
                    let done = Set(completed.map { $0.stepId })
                    let stepId = trail.first(where: { !done.contains($0) })
                        ?? trail.last ?? lesson.entryStepId
                    var assists: [AssistanceKind] = []
                    for event in events {
                        guard case .attempt(let attempt) = event,
                              attempt.packId == pack.id,
                              attempt.lessonId == lesson.id,
                              attempt.lessonRevision == lesson.revision,
                              !quarantined.contains(attempt.id) else { continue }
                        if attempt.stepId == stepId {
                            assists += attempt.assistance
                        } else {
                            assists += attempt.assistance.filter {
                                $0 == .translation || $0 == .transcript
                            }
                        }
                    }
                    var seenAssists = Set<AssistanceKind>()
                    checkpoint = LessonCheckpoint(
                        packId: pack.id, lessonId: lesson.id, revision: lesson.revision,
                        stepId: stepId, selectedBranches: selectedBranches,
                        assistance: assists.filter { seenAssists.insert($0).inserted },
                        draft: nil, at: Date())
                    openedFresh = false
                }
            }
            let resume: ResumeResult
            if let checkpoint {
                resume = resumeSession(pack: pack, checkpoint: checkpoint,
                                       events: events, quarantined: quarantined)
            } else {
                resume = .restart(explanation: "")
            }
            switch resume {
            case .resume(let resumed):
                var next = resumed
                draft = resumed.draftResponse
                assistanceUsed = []
                if resumed.completedStepIds.contains(resumed.activeStepId) {
                    restorePostSubmitState(into: &next, lesson: lesson, events: events)
                }
                session = next
                let trail = walkTrail(lesson: lesson, selectedBranches: next.selectedBranches)
                resumedComplete = trail.allSatisfy { next.completedStepIds.contains($0) }
                showBriefing = unstartedEntry
            case .restart(let explanation):
                let fresh = try startLesson(pack: pack, lessonId: lesson.id)
                session = fresh
                draft = nil
                assistanceUsed = []
                if !explanation.isEmpty {
                    restartNotice = explanation
                }
                resumedComplete = false
                showBriefing = openedFresh || unstartedEntry
            }
        } catch {
            checkpointError = "Could not load your saved progress: \(String(describing: error))"
        }
    }

    /// After a resume lands on an already-completed step, rebuild the
    /// post-submit screen (evaluation + draft) from the latest attempt.
    private func restorePostSubmitState(into session: inout LessonSession,
                                        lesson: Lesson,
                                        events: [LearningEvent]) {
        let attempts = events.compactMap { event -> ActivityAttempt? in
            guard case .attempt(let attempt) = event,
                  attempt.lessonId == lesson.id,
                  attempt.lessonRevision == lesson.revision,
                  attempt.stepId == session.activeStepId else { return nil }
            return attempt
        }
        guard let latest = attempts.last else { return }
        session.currentEvaluation = latest.evaluation
        session.accumulatedAssistance = latest.assistance
        draft = latest.response
    }

    private func handleSubmit(responseOverride: AttemptResponse? = nil,
                              extraAssistance: [AssistanceKind] = [],
                              advanceAfter: Bool = false) {
        guard let session, let lesson, let step else { return }
        guard pendingEvents.isEmpty else { return }
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
        engineError = nil
        let supportWasOpen = supportOpen
        let assistance = supportWasOpen
            ? orderedUnion([.hint], assistanceUsed)
            : orderedUnion(assistanceUsed, extraAssistance)
        let response = supportWasOpen ? .continue : (responseOverride ?? draft ?? .continue)
        var next: LessonSession
        do {
            next = try submitResponse(pack: pack, session: session,
                                      response: response, assistance: assistance)
        } catch {
            engineError = "Could not check that answer: \(String(describing: error))"
            return
        }

        if supportWasOpen {
            self.session = next
            assistanceUsed = []
            return
        }

        guard let activity = pack.activity(id: step.activityId),
              let evaluation = next.currentEvaluation else {
            engineError = "That step could not be checked."
            return
        }
        // Trouble spots feed the recap's revisit pass; a soft tap marks a
        // correct answer. Nothing ever fires on a mistake.
        if evaluation.outcome == .incorrect || evaluation.outcome == .blocked {
            if !troubleStepIds.contains(step.id) {
                troubleStepIds.append(step.id)
            }
            if evaluation.outcome == .incorrect {
                if next.currentEvaluation?.correction == nil {
                    next.currentEvaluation?.correction = modelDisplay(for: activity)
                }
                // Once the answer is shown, another attempt is practice with
                // help, even if the learner types it in unaided afterward.
                recordAssistance(.model)
            }
        } else if evaluation.outcome == .correct {
            Haptics.correct()
        }
        let now = Date()
        let attemptId = UUID().uuidString
        let attempt = ActivityAttempt(
            id: attemptId, packId: pack.id, packVersion: pack.version,
            lessonId: lesson.id, lessonRevision: lesson.revision,
            stepId: step.id, activityId: activity.id,
            activityRevision: activity.revision,
            evidenceKey: activity.evidenceKey,
            response: response, assistance: next.accumulatedAssistance,
            evaluation: evaluation, at: now)
        var events: [LearningEvent] = [.attempt(attempt)]
        let freshCompletion = next.completedStepIds.contains(step.id)
            && !session.completedStepIds.contains(step.id)
        if freshCompletion {
            let selectedBranchId: String? = step.branches.isEmpty ? nil :
                next.selectedBranches[step.id]
            events.append(.stepCompleted(StepCompletion(
                id: UUID().uuidString, packId: pack.id, packVersion: pack.version,
                lessonId: lesson.id, lessonRevision: lesson.revision,
                stepId: step.id, selectedBranchId: selectedBranchId,
                attemptId: attemptId, at: now)))
        }
        pendingEvents = events
        do {
            for event in events { try store.record(event) }
            pendingEvents = []
        } catch {
            // Hold the evaluated session until the save succeeds: the learner
            // can retry without losing the result, the pending-events guard
            // above prevents double submissions, and editing stays disabled
            // until the retry lands.
            pendingSession = next
            if case .information = activity { pendingAutoAdvance = true }
            if advanceAfter { pendingAutoAdvance = true }
            saveError = true
            return
        }

        // Information steps move on by themselves once their events are
        // saved, the way the web player auto-advances them.
        let informationStep: Bool
        if case .information = activity { informationStep = true }
        else { informationStep = false }
        if informationStep || advanceAfter {
            if retrying {
                advanceRetry()
                return
            }
            do {
                let advanced = try advanceLesson(pack: pack, session: next)
                self.session = advanced
                draft = nil
                assistanceUsed = []
                audioPlayer.stop()
                if advanced.status == .complete {
                    resumedComplete = true
                    // New evidence may have refilled the review queue.
                    ReviewReminders.refreshShared()
                }
            } catch {
                engineError = "Could not continue: \(String(describing: error))"
            }
            return
        }
        self.session = next
    }

    private func handleUseModelAnswer(activity: Activity) {
        guard let model = modelResponse(for: activity) else { return }
        handleSubmit(responseOverride: model, extraAssistance: [.model], advanceAfter: true)
    }

    private func modelResponse(for activity: Activity) -> AttemptResponse? {
        switch activity {
        case .text(let spec):
            return spec.answer.answers.first.map(AttemptResponse.text)
        case .legacy(let spec):
            return lesson?.legacyExercises.first(where: { $0.id == spec.exerciseId })?
                .base.answers.first.map(AttemptResponse.text)
        case .cloze(let spec):
            let values = spec.blanks.compactMapValues { $0.answers.first }
            return values.count == spec.blanks.count ? .cloze(values: values) : nil
        case .selection(let spec): return .selection(ids: spec.acceptedIds)
        case .dialogueChoice(let spec):
            return spec.acceptedIds.first.map { .selection(ids: [$0]) }
        case .sceneSelection(let spec): return .selection(ids: spec.acceptedRegionIds)
        case .ordering(let spec):
            return spec.acceptedOrders.first.map { .ordering(ids: $0) }
        case .matching(let spec):
            return .matching(pairs: spec.acceptedPairs.map {
                ResponsePair(leftId: $0.leftId, rightId: $0.rightId)
            })
        case .information, .selfCompare: return nil
        }
    }

    private func modelDisplay(for activity: Activity) -> String? {
        switch activity {
        case .text(let spec): return spec.answer.answers.first
        case .legacy(let spec):
            return lesson?.legacyExercises.first(where: { $0.id == spec.exerciseId })?
                .base.answers.first
        case .cloze(let spec):
            return spec.blanks.keys.sorted().compactMap { spec.blanks[$0]?.answers.first }
                .joined(separator: " · ")
        case .selection(let spec):
            return spec.options.filter { spec.acceptedIds.contains($0.id) }
                .map(\.text).joined(separator: " · ")
        case .dialogueChoice(let spec):
            return spec.options.filter { spec.acceptedIds.contains($0.id) }
                .map(\.text).joined(separator: " · ")
        case .ordering(let spec):
            guard let order = spec.acceptedOrders.first else { return nil }
            let byId = Dictionary(uniqueKeysWithValues: spec.tokens.map { ($0.id, $0.text) })
            return order.compactMap { byId[$0] }.joined(separator: " ")
        case .matching(let spec):
            let left = Dictionary(uniqueKeysWithValues: spec.left.map { ($0.id, $0.text) })
            let right = Dictionary(uniqueKeysWithValues: spec.right.map { ($0.id, $0.text) })
            return spec.acceptedPairs.compactMap { pair in
                guard let source = left[pair.leftId], let meaning = right[pair.rightId]
                else { return nil }
                return "\(source) → \(meaning)"
            }.joined(separator: " · ")
        case .sceneSelection(let spec):
            guard let stimulus = pack.stimulus(id: spec.stimulusId),
                  case .scene(_, _, _, let regions, _) = stimulus
            else { return nil }
            return regions.filter { spec.acceptedRegionIds.contains($0.id) }
                .map(\.label).joined(separator: " · ")
        case .information, .selfCompare: return nil
        }
    }

    private func retrySave() {
        do {
            for event in pendingEvents { try store.record(event) }
            pendingEvents = []
            saveError = false
        } catch {
            saveError = true
            return
        }
        // The save finally landed: apply the post-submit transition that was
        // held back, including the information auto-advance.
        guard let pending = pendingSession else { return }
        pendingSession = nil
        let autoAdvance = pendingAutoAdvance
        pendingAutoAdvance = false
        if autoAdvance {
            if retrying {
                advanceRetry()
                return
            }
            do {
                let advanced = try advanceLesson(pack: pack, session: pending)
                session = advanced
                draft = nil
                assistanceUsed = []
                audioPlayer.stop()
                if advanced.status == .complete {
                    resumedComplete = true
                    // New evidence may have refilled the review queue.
                    ReviewReminders.refreshShared()
                }
            } catch {
                session = pending
                engineError = "Could not continue: \(String(describing: error))"
            }
        } else {
            session = pending
        }
    }

    private func handleAdvance() {
        guard let session else { return }
        engineError = nil
        if retrying {
            advanceRetry()
            return
        }
        do {
            let next = try advanceLesson(pack: pack, session: session)
            self.session = next
            draft = nil
            assistanceUsed = []
            audioPlayer.stop()
            if next.status == .complete {
                resumedComplete = true
                // New evidence may have refilled the review queue.
                ReviewReminders.refreshShared()
                Haptics.lessonComplete()
            } else {
                Haptics.stepComplete()
            }
        } catch {
            engineError = "Could not continue: \(String(describing: error))"
        }
    }

    private func handleHelp() {
        guard let session else { return }
        engineError = nil
        do {
            self.session = try openSupport(pack: pack, session: session)
        } catch {
            engineError = "That step has no extra help."
        }
    }

    private func handleBack() {
        saveCheckpointNow()
        onExit()
    }

    // MARK: - Trouble-spot retry

    /// Re-walk exactly the steps that came back incorrect or blocked,
    /// bypassing the trail: the session struct is value-typed, so the
    /// retry jumps the active step directly and the engine still checks
    /// each answer (attempts keep flowing to the review scheduler).
    private func startRetry() {
        guard !troubleStepIds.isEmpty else { return }
        retrying = true
        retryQueue = troubleStepIds
        jumpToRetryStep()
    }

    private func advanceRetry() {
        guard !retryQueue.isEmpty else {
            endRetry()
            return
        }
        let doneId = retryQueue.removeFirst()
        troubleStepIds.removeAll { $0 == doneId }
        Haptics.stepComplete()
        if retryQueue.isEmpty {
            endRetry()
        } else {
            jumpToRetryStep()
        }
    }

    private func jumpToRetryStep() {
        guard var jumped = session, let id = retryQueue.first else {
            endRetry()
            return
        }
        jumped.activeStepId = id
        jumped.draftResponse = nil
        jumped.currentEvaluation = nil
        jumped.activeSupportActivityId = nil
        jumped.accumulatedAssistance = []
        if !jumped.visitedStepIds.contains(id) {
            jumped.visitedStepIds.append(id)
        }
        session = jumped
        draft = nil
        assistanceUsed = []
        audioPlayer.stop()
    }

    private func endRetry() {
        retrying = false
        retryQueue = []
        audioPlayer.stop()
    }

    // MARK: - Lesson switching

    /// Move to the next lesson without dismissing the player: all
    /// per-lesson state resets and the new lesson boots (briefing included
    /// when it is brand new).
    private func switchLesson(to id: String) {
        audioPlayer.stop()
        activeLessonId = id
        session = nil
        draft = nil
        assistanceUsed = []
        thinkGate = ThinkGateState()
        pendingEvents = []
        pendingSession = nil
        pendingAutoAdvance = false
        saveError = false
        engineError = nil
        checkpointError = nil
        resumedComplete = false
        restartNotice = nil
        troubleStepIds = []
        retryQueue = []
        retrying = false
        showBriefing = false
        boot()
    }

    // MARK: Checkpoints

    private func saveCheckpointNow() {
        // Retry passes never move the checkpoint: the lesson is complete
        // and the checkpoint must keep pointing at real progress.
        guard !retrying else { return }
        guard let session, let lesson else { return }
        let checkpoint = LessonCheckpoint(
            packId: pack.id, lessonId: lesson.id, revision: lesson.revision,
            stepId: session.activeStepId,
            selectedBranches: session.selectedBranches,
            assistance: orderedUnion(session.accumulatedAssistance, assistanceUsed),
            draft: draft, at: Date())
        do {
            try store.saveCheckpoint(checkpoint)
        } catch {
            checkpointError = "Could not save your place: \(String(describing: error))"
        }
    }
}

// MARK: - Small player pieces

struct PlayerProgressHeader: View {
    let done: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(total > 0 ? "\(done) of \(total) steps completed" : "Lesson")
                .font(DesignTokens.text(13, weight: .medium))
                .foregroundStyle(DesignTokens.muted)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(DesignTokens.edgeSoft)
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(DesignTokens.primary)
                        .frame(width: total > 0 ? proxy.size.width * CGFloat(done) / CGFloat(total) : 0,
                               height: 8)
                        .animation(.easeInOut(duration: 0.3), value: done)
                }
            }
            .frame(height: 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(total > 0 ? "\(done) of \(total) steps completed" : "Lesson")
    }
}

struct PlayerNoticeView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(DesignTokens.text(14))
            .foregroundStyle(DesignTokens.muted)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.stock2)
            .cornerRadius(8)
    }
}

struct PlayerFeedbackView: View {
    let evaluation: AttemptEvaluation

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(outcomeWord(evaluation.outcome))
                .font(DesignTokens.text(16, weight: .semibold))
                .foregroundStyle(evaluation.outcome == .correct
                                 ? DesignTokens.correctLine : DesignTokens.inkDeep)
            if !evaluation.feedback.isEmpty {
                Text(evaluation.feedback)
                    .font(DesignTokens.text(15))
                    .foregroundStyle(DesignTokens.ink)
            }
            if let correction = evaluation.correction, !correction.isEmpty {
                Text("Model answer: \(correction)")
                    .font(DesignTokens.text(15, weight: .medium))
                    .foregroundStyle(DesignTokens.inkDeep)
            }
            if evaluation.outcome == .correct || evaluation.outcome == .selfAssessed {
                Text(evaluation.independent
                     ? "Solved on your own — that counts as independent practice."
                     : "Solved with help — good work getting there; it will not count as independent practice.")
                    .font(DesignTokens.text(13))
                    .foregroundStyle(DesignTokens.muted)
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
        .shadow(color: DesignTokens.ink, radius: 0, x: 3, y: 3)
    }
}

struct PlayerErrorView: View {
    let message: String
    let onExit: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text(message)
                .font(DesignTokens.text(16))
                .foregroundStyle(DesignTokens.attentionInk)
                .multilineTextAlignment(.center)
            StudioSecondaryButton("Back to lessons", action: onExit)
            Spacer()
        }
        .padding(24)
    }
}
