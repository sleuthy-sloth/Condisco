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

/// Recommended practice starts with an empty transient session. Stored events
/// stay intact; submitting practice appends new evidence through the normal player.
func freshPracticeSession(pack: CoursePack, lessonId: String) throws -> LessonSession {
    try startLesson(pack: pack, lessonId: lessonId)
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
    @State private var startFreshPending: Bool
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
    /// Non-blocking notice when stored event rows could not be decoded at
    /// boot: the lesson still opens, but those rows are skipped.
    @State private var corruptProgressNotice: String?
    @State private var bootstrapped = false
    @StateObject private var audioPlayer = LessonAudioPlayer()
    /// Comfort settings observed so the explicit animation modifiers below
    /// honor the in-app toggle and the system reduce-motion setting live.
    @ObservedObject private var a11y = A11ySettings.shared
    /// Phase 6.3 hosted-exchange practice: the in-flight exchange session
    /// (nil = never started, or reset when the lesson restarts). Survives
    /// force quit through the lesson checkpoint's `dialogue` slice.
    @State private var dialogueSession: DialogueSession?
    @State private var showDialogue = false
    /// Brand-new lessons open with the briefing; resumes go straight in.
    @State private var showBriefing = false
    /// Warm-up recall phase: due cards from earlier lessons, shown before
    /// the briefing only when a brand-new lesson starts this visit. Lives
    /// entirely outside LessonSession — the engine and its checkpoint
    /// logic are untouched, so nothing here can disturb resume semantics.
    @State private var warmUpItems: [ReviewItem] = []
    @State private var warmUpActive = false
    /// Offered once per visit: the recap's "Next lesson" stays in the same
    /// visit, so switching must not re-offer the warm-up.
    @State private var warmUpOffered = false
    @State private var warmUpIndex = 0
    @State private var warmUpSaveError: String?
    /// Steps whose evaluation came back incorrect or blocked this run —
    /// the recap offers them for one more try.
    @State private var troubleStepIds: [String] = []
    /// The specific fix (correction) shown for each trouble spot, keyed by
    /// step id — the recap's "Worth remembering" takeaway draws from here.
    @State private var troubleCorrections: [String: String] = [:]
    @State private var retryQueue: [String] = []
    @State private var retrying = false
    /// One slot per distinct step this run: the recap's honest split between
    /// recall and practice-with-help counts steps, never checks, so revisiting
    /// a trouble spot in the retry pass cannot inflate the numbers.
    @State private var recapSplit = LessonRecapSplit()
    /// One-time guide to the lesson controls, shown on the first step
    /// the learner ever opens.
    @AppStorage("condisco.hasSeenLessonGuide") private var hasSeenLessonGuide = false
    @State private var showLessonGuide = false

    init(pack: CoursePack, lessonId: String, store: LearningStore, startFresh: Bool = false, onExit: @escaping () -> Void) {
        self.pack = pack
        self.store = store
        self.onExit = onExit
        _startFreshPending = State(initialValue: startFresh)
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

    /// The next unfinished lesson after this one, for the recap's way onward.
    private var nextLessonInPack: Lesson? {
        guard let lesson else { return nil }
        let finished = (try? store.project(pack: pack).finishedLessons) ?? []
        return pack.nextUncompletedLesson(after: lesson.id, completed: finished)
    }

    /// The single correction worth remembering from this run: the newest
    /// trouble spot's specific fix. Trouble steps are ordered by when they
    /// went wrong, so walking backwards finds the freshest mistake; blocked
    /// steps carry no correction and are skipped. Nil when nothing was
    /// missed, or when the lesson was resumed already complete.
    private var recapTakeaway: String? {
        for stepId in troubleStepIds.reversed() {
            if let correction = troubleCorrections[stepId], !correction.isEmpty {
                return correction
            }
        }
        return nil
    }

    /// The exchange this lesson hosts for conversation practice (6.3).
    private var hostedDialogue: Dialogue? {
        guard let lesson else { return nil }
        return pack.dialogue(hostedBy: lesson.id)
    }

    /// The conversation practice entry shows only once the lesson trail is
    /// complete — the exchange is the follow-on practice, replayable.
    private var showsDialogueEntry: Bool {
        resumedComplete && !retrying && hostedDialogue != nil && !saveError
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
                } else if warmUpActive, warmUpIndex < warmUpItems.count {
                    warmUpCard
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
                        takeaway: recapTakeaway,
                        independentCount: recapSplit.independentCount,
                        practiceCount: recapSplit.practiceCount,
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
                if showsDialogueEntry {
                    ToolbarItem(placement: .primaryAction) {
                        Button(DialoguePracticeCopy.hero) { openDialogue() }
                    }
                }
            }
        }
        .onAppear { if !bootstrapped { bootstrapped = true; boot() } }
        .onChange(of: session) { _, _ in saveCheckpointNow() }
        .onChange(of: draft) { _, _ in saveCheckpointNow() }
        .onChange(of: dialogueSession) { _, _ in saveCheckpointNow() }
        .sheet(isPresented: $showDialogue, onDismiss: { saveCheckpointNow() }) {
            if let lesson, let dialogue = hostedDialogue, dialogueSession != nil {
                DialogueExchangeView(
                    pack: pack, store: store, lesson: lesson, dialogue: dialogue,
                    session: $dialogueSession,
                    onClose: { showDialogue = false })
            }
        }
    }

    /// Opens the hosted exchange: a fresh attempt the first time, the
    /// checkpointed position (branch + answered turns) on later visits.
    private func openDialogue() {
        guard let lesson, let dialogue = hostedDialogue, dialogueSession == nil else {
            showDialogue = true
            return
        }
        do {
            dialogueSession = try startDialogue(
                pack: pack, lesson: lesson, dialogue: dialogue)
            showDialogue = true
        } catch {
            // The exchange did not start; keep the entry hidden.
        }
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

                    if let notice = corruptProgressNotice {
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
                                    .accessibilityHint("Opens a help step")
                            }
                        }
                    }
                }
                .padding(16)
                .id("playerTop")
                // Calm slide between steps; silenced when reduce motion is on.
                .animation(a11y.effectiveReduceMotion
                           ? nil : .easeInOut(duration: 0.25), value: step.id)
            }
            // The primary action never leaves the thumb's reach: it stays
            // pinned above the bottom safe area (and above the keyboard),
            // and the scroll content is inset so nothing hides behind it.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                primaryActionBar(step: step, activity: activity)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: step.id) { _, _ in
                proxy.scrollTo("playerTop", anchor: .top)
            }
            .onChange(of: evaluation) { _, result in
                guard result != nil else { return }
                if a11y.effectiveReduceMotion {
                    proxy.scrollTo("answerFeedback", anchor: .bottom)
                } else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("answerFeedback", anchor: .bottom)
                    }
                }
            }
        }
    }

    /// The bottom bar holding the step's primary action, pinned above the
    /// keyboard and the home indicator so it is tappable in every state.
    @ViewBuilder
    private func primaryActionBar(step: LessonStep, activity: Activity) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            primaryButton(step: step, activity: activity)
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

    /// The step-varying slice of the player: feedback and body slide as one
    /// when the step changes. The primary action lives in the pinned bar.
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
        // Phase 6.1B: a step that binds a sustained passage renders the
        // material itself — the reading/listening lane replaces the standard
        // step slide. The step's own (launch) activity stays behind the
        // pinned Continue button, so the lesson graph, completion discipline,
        // and checkpoint resume are untouched.
        if let textId = step.sustainedTextId,
           let passage = pack.sustainedText(id: textId) {
            SustainedReadingExperienceView(
                passage: passage,
                pack: pack,
                launchInstructions: sustainedLaunchInstructions(for: step),
                lessonTitle: lesson?.title ?? "",
                sourcePackId: pack.id,
                sourceLessonId: lesson?.id ?? "")
        } else if let listeningId = step.sustainedListeningId,
                  let passage = pack.sustainedListening(id: listeningId) {
            SustainedListeningExperienceView(
                passage: passage,
                pack: pack,
                launchInstructions: sustainedLaunchInstructions(for: step),
                lessonTitle: lesson?.title ?? "",
                sourcePackId: pack.id,
                sourceLessonId: lesson?.id ?? "")
        } else {
            regularStepBody(step: step, activity: activity)
        }
    }

    /// The launch step's information body, surfaced as the brief above the
    /// material when the binding step is a launch (information) step.
    private func sustainedLaunchInstructions(for step: LessonStep) -> String {
        guard let activity = pack.activity(id: step.activityId),
              case .information(let info) = activity else { return "" }
        return info.body
    }

    /// The step body for every non-sustained step — the pre-6.1B layout,
    /// exactly as it always composed.
    @ViewBuilder
    private func regularStepBody(step: LessonStep, activity: Activity) -> some View {
        let family = lesson?.family ?? .discovery
        let isEntry = step.id == lesson?.entryStepId
        // Only the step that introduces the context shows it in the open
        // card; later steps in the same lesson collapse it to a one-line
        // disclosure so the repeated passage never pushes the question off
        // the phone. Story lessons also keep it open on their reading
        // (information) steps.
        let compactContext = shouldCompactContext(
            family: family, isEntry: isEntry, activity: activity)
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
                DisclosureGroup(compactContextLabel(family)) {
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

    /// One-line disclosure title for a collapsed context: names what the
    /// learner can reopen rather than repeating the passage itself.
    private func compactContextLabel(_ family: LessonFamily) -> String {
        switch family {
        case .story: return "Read the passage again"
        case .mission: return "Review the mission notes"
        case .conversation: return "Read the dialogue again"
        case .listening: return "Hear the audio again"
        case .discovery: return "Context"
        default: return "Context"
        }
    }

    private func isInformation(_ activity: Activity) -> Bool {
        if case .information = activity { return true }
        return false
    }

    /// Whether the context collapses to a one-line disclosure for this step.
    /// Kept out of the `@ViewBuilder` body: a `switch` statement of plain
    /// assignments is not valid view content.
    private func shouldCompactContext(
        family: LessonFamily, isEntry: Bool, activity: Activity
    ) -> Bool {
        switch family {
        case .discovery:
            // Discovery keeps its compact disclosure on every step.
            return false
        case .story:
            // Story keeps the passage open on its reading (information) steps.
            return !isInformation(activity)
        case .mission, .conversation, .listening:
            return !isEntry
        default:
            // Construction, scene, and recall rely on their full stimulus.
            return false
        }
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
                         onAssist: recordAssistance,
                         onOpenTaskSubmit: { submission in
                             handleOpenTaskSubmit(submission: submission)
                         })
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
        case .information: return "Read — not graded"
        case .selfCompare(let spec): return spec.prompt
        case .openTask(let spec): return spec.goal
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
            } else if case .openTask = activity {
                // Open tasks host their own submit (self-assessment) inside
                // the step slide; the bar only shows the guidance note.
                Text(OpenTaskCopy.barNote)
                    .font(DesignTokens.text(13))
                    .foregroundStyle(DesignTokens.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
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
            if startFreshPending {
                startFreshPending = false
                session = try freshPracticeSession(pack: pack, lessonId: lesson.id)
                draft = nil
                assistanceUsed = []
                resumedComplete = false
                showBriefing = true
                return
            }
            let storedCheckpoint = try store.loadCheckpoint(packId: pack.id, lessonId: lesson.id)
            let (events, skippedEventRows) = try store.learningEventsWithQuarantine(packId: pack.id)
            let quarantined = Set(try store.project(pack: pack).quarantined)
            // A corrupt row in this pack never blocks the lesson: the tolerant
            // read skips it, and the learner gets a non-blocking notice
            // instead of a PlayerErrorView dead-end.
            if !skippedEventRows.isEmpty {
                corruptProgressNotice =
                    "Some saved progress couldn't be read and was skipped — everything else is intact."
            }
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
                // Phase 6.3: restore the hosted exchange's branch position
                // and answered turns from the checkpoint slice. A stale or
                // un-replayable slice restarts the exchange the next time it
                // is opened (nothing is invented here).
                if let dialogueState = checkpoint?.dialogue {
                    dialogueSession = resumeDialogueSession(pack: pack, state: dialogueState)
                }
                let trail = walkTrail(lesson: lesson, selectedBranches: next.selectedBranches)
                resumedComplete = trail.allSatisfy { next.completedStepIds.contains($0) }
                showBriefing = unstartedEntry
            case .restart(let explanation):
                let fresh = try startLesson(pack: pack, lessonId: lesson.id)
                session = fresh
                draft = nil
                assistanceUsed = []
                dialogueSession = nil
                showDialogue = false
                if !explanation.isEmpty {
                    restartNotice = explanation
                }
                resumedComplete = false
                showBriefing = openedFresh || unstartedEntry
                // Warm-up recall only when the lesson starts from scratch
                // this visit — a resume (valid checkpoint) never sees it.
                if openedFresh {
                    offerWarmUpIfNeeded(lesson: lesson)
                }
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
            // The patched correction (what the learner actually saw) is the
            // specific fix worth remembering; blocked steps carry none, so
            // they never supply the recap takeaway.
            troubleCorrections[step.id] = next.currentEvaluation?.correction ?? ""
        } else if evaluation.outcome == .correct {
            Haptics.correct()
        }
        // Only real checks claim a slot in the recap's honest split between
        // recall and practice-with-help: reading steps (ungraded) and failed
        // saves (blocked) are not practice, and every self-compare is
        // practice against the model. Each distinct step counts once per
        // visit — a retried trouble spot updates nothing, never a second
        // count.
        recapSplit.record(stepId: step.id, evaluation: evaluation)
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

    /// Submits an open task's self-assessment: the authored task's step
    /// completes on the submission exactly like a self-compare, recording
    /// ONLY the completion, the assistance, and the learner's own
    /// self-assessment (rubric ticks + optional rating). The response text
    /// or recording never enters the learning log — the written draft stays
    /// in the lesson checkpoint for resume, and the recording is a
    /// disposable temp file.
    private func handleOpenTaskSubmit(submission: OpenTaskSubmission) {
        guard let session, let lesson, let step else { return }
        guard pendingEvents.isEmpty else { return }
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
        engineError = nil
        guard let activity = pack.activity(id: step.activityId),
              case .openTask(let spec) = activity else {
            engineError = "That step could not be checked."
            return
        }
        // The engine only needs a completion-bearing response; the rating
        // (when present) is the honest one. Nothing about the learner's
        // written text or recording is evaluated or stored here.
        let response: AttemptResponse =
            submission.rating.map { .selfRating($0) } ?? .continue
        var next: LessonSession
        do {
            next = try submitResponse(pack: pack, session: session,
                                      response: response,
                                      assistance: assistanceUsed)
        } catch {
            engineError = "Could not save that step: \(String(describing: error))"
            return
        }
        guard let evaluation = next.currentEvaluation else {
            engineError = "That step could not be checked."
            return
        }
        // Self-assessed open work is practice with help in the recap split,
        // exactly like self-compare steps: never an independent count.
        recapSplit.record(stepId: step.id, evaluation: evaluation)
        let now = Date()
        let attempt = OpenTaskAttemptEvent(
            id: UUID().uuidString,
            packId: pack.id,
            packVersion: pack.version,
            lessonId: lesson.id,
            lessonRevision: lesson.revision,
            stepId: step.id,
            activityId: activity.id,
            activityRevision: spec.revision,
            mode: spec.mode,
            assistance: next.accumulatedAssistance,
            selfRating: OpenTaskSelfRating(
                criteriaMet: submission.criteriaMet.sorted(),
                rating: submission.rating),
            modelRevealed: submission.modelRevealed,
            at: now)
        var events: [LearningEvent] = [.openTaskAttempt(attempt)]
        let freshCompletion = next.completedStepIds.contains(step.id)
            && !session.completedStepIds.contains(step.id)
        if freshCompletion {
            // Open-task steps complete with a bare completion: the attempt
            // row is the open-task-attempt event, not an ActivityAttempt,
            // so no attemptId rides along.
            events.append(.stepCompleted(StepCompletion(
                id: UUID().uuidString, packId: pack.id, packVersion: pack.version,
                lessonId: lesson.id, lessonRevision: lesson.revision,
                stepId: step.id, selectedBranchId: nil,
                attemptId: nil, at: now)))
        }
        pendingEvents = events
        do {
            for event in events { try store.record(event) }
            pendingEvents = []
        } catch {
            pendingSession = next
            saveError = true
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
        case .information, .selfCompare, .openTask: return nil
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
        case .information, .selfCompare, .openTask: return nil
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

    // MARK: - Warm-up recall

    /// Offers the warm-up recall phase for a brand-new lesson. Runs only
    /// from `boot()`'s restart branch when `openedFresh` — no checkpoint,
    /// no history — so a mid-lesson resume never interrupts with cards.
    /// `warmUpOffered` gates the phase to once per visit: the recap's
    /// "Next lesson" stays in the same visit and must not re-offer.
    @MainActor
    private func offerWarmUpIfNeeded(lesson: Lesson) {
        guard !warmUpOffered else { return }
        let picked: [ReviewItem]
        do {
            picked = RecallWarmUp.select(
                due: try ReviewCatalog.loadCourseDue(packs: [pack], store: store).due,
                currentLesson: lesson, pack: pack)
        } catch {
            // No due data (store hiccup) simply means no warm-up; the
            // lesson itself is unaffected.
            return
        }
        guard !picked.isEmpty else { return }
        warmUpItems = picked
        warmUpIndex = 0
        warmUpActive = true
        warmUpSaveError = nil
        warmUpOffered = true
    }

    /// The warm-up card: the existing Review card and session dots, so the
    /// flow is identical to a Review session — recall prompt, reveal, then
    /// a self-rating that reschedules this evidence key like any attempt.
    private var warmUpCard: some View {
        ZStack {
            DesignTokens.canvas.ignoresSafeArea()
            ReviewCardView(
                item: warmUpItems[warmUpIndex],
                position: warmUpIndex + 1,
                total: warmUpItems.count,
                saveError: warmUpSaveError
            ) { verdict in
                handleWarmUpVerdict(verdict)
            }
            .id(warmUpItems[warmUpIndex].id)
        }
    }

    /// Records a warm-up verdict through the lesson event pipeline (the
    /// same path ReviewModel.recordVerdict uses), then advances. After the
    /// last card the reminders refresh like a lesson completion's, and the
    /// phase deactivates so the briefing/lesson flow continues below.
    private func handleWarmUpVerdict(_ verdict: ReviewVerdict) {
        guard warmUpIndex < warmUpItems.count else { return }
        let item = warmUpItems[warmUpIndex]
        do {
            try store.record(.attempt(item.makeAttempt(verdict: verdict)))
            warmUpSaveError = nil
        } catch {
            warmUpSaveError =
                "Couldn't save that review — tap your rating again to retry."
            return
        }
        if warmUpIndex + 1 < warmUpItems.count {
            warmUpIndex += 1
        } else {
            // Warm-up done: the briefing (or the lesson itself) continues.
            // New evidence may have refilled the review queue.
            ReviewReminders.refreshShared()
            warmUpActive = false
            warmUpItems = []
            warmUpIndex = 0
        }
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
        troubleCorrections.removeValue(forKey: doneId)
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
        corruptProgressNotice = nil
        troubleStepIds = []
        troubleCorrections = [:]
        recapSplit = LessonRecapSplit()
        retryQueue = []
        retrying = false
        showBriefing = false
        dialogueSession = nil
        showDialogue = false
        // Transient warm-up state resets per lesson; `warmUpOffered` does
        // NOT — the recap's next lesson is the same visit.
        warmUpItems = []
        warmUpActive = false
        warmUpIndex = 0
        warmUpSaveError = nil
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
            draft: draft, at: Date(),
            dialogue: dialogueSession.map { $0.checkpointState() })
        do {
            try store.saveCheckpoint(checkpoint)
        } catch {
            checkpointError = "Could not save your place: \(String(describing: error))"
        }
    }
}

// MARK: - Recap honest split

/// How one graded check lands in the recap's independence line.
enum RecapClassification: Equatable {
    case independent
    case helped

    init(evaluation: AttemptEvaluation) {
        self = evaluation.independent ? .independent : .helped
    }
}

/// Accumulates the recap's "Solved N on your own · practiced M with help"
/// split for a single visit. Each DISTINCT step claims at most one slot,
/// decided by its first countable check (correct, incorrect, or
/// self-assessed): once a step needed help this run it stays
/// practice-with-help, even when a later retry comes back clean — help was
/// used on it, so upgrading would overstate recall. Reading steps
/// (ungraded) and failed saves (blocked) claim nothing; self-compares are
/// always practice with help. Fresh per lesson (`switchLesson`).
struct LessonRecapSplit: Equatable {
    private(set) var stepClass: [String: RecapClassification] = [:]

    var independentCount: Int {
        stepClass.values.filter { $0 == .independent }.count
    }

    var practiceCount: Int {
        stepClass.values.filter { $0 == .helped }.count
    }

    mutating func record(stepId: String, evaluation: AttemptEvaluation) {
        switch evaluation.outcome {
        case .correct, .incorrect, .selfAssessed:
            guard stepClass[stepId] == nil else { return }
            stepClass[stepId] = RecapClassification(evaluation: evaluation)
        case .ungraded, .blocked:
            return
        }
    }
}

// MARK: - Small player pieces

struct PlayerProgressHeader: View {
    let done: Int
    let total: Int

    @ObservedObject private var a11y = A11ySettings.shared

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
                        .animation(a11y.effectiveReduceMotion
                                   ? nil : .easeInOut(duration: 0.3), value: done)
                }
            }
            .frame(height: 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(total > 0 ? "\(done) of \(total) steps completed" : "Lesson")
        .accessibilityAddTraits(.isHeader)
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
                Text(independenceLine)
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

    /// Plain, truthful note about how this attempt counts. Self-compare
    /// steps are never graded, so "help" language and independent-practice
    /// framing read wrong there; graded steps keep the distinction.
    private var independenceLine: String {
        if evaluation.outcome == .selfAssessed {
            return "Self-assessed — it doesn't count as independent practice."
        }
        return evaluation.independent
            ? "Solved on your own — that counts as independent practice."
            : "Solved with help — it doesn't count as independent practice."
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
