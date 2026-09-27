import SwiftUI

// MARK: - Checkpoint flow (5.3B)
//
// The presentation side of the pack-level checkpoint task bank that 5.3A
// shipped: the entry card on the course page (one per stage its pack has a
// task for), the task flow itself (unseen reading, open writing, and
// self-assessed speaking), a result report that names the source of every
// result, targeted revisit suggestions, and an attempts history. The 5.3A
// store API is the contract — this layer only ever records through
// `LearningStore.recordCheckpointAttempt`, and `itemsRevealed` is set only
// after the task's items and rubric have actually been presented.
//
// Boundaries, kept honest:
//   · The checkpoint is optional. It never locks a lesson, never touches
//     completion or SRS, and a low self-rating changes nothing.
//   · The unseen passage and questions are presented exactly as authored —
//     no recomputation, no fabricated answers. Reading answers are graded
//     with the engine's set-equality rule (`checkpointReadingCorrect`), but
//     completion never depends on the score: a mistake only earns a
//     suggestion to revisit, never a penalty.
//   · Writing is never auto-graded. Speaking is self-assessment against the
//     authored rubric. Both are worded as practice evidence.
//   · Assistance (the passage translation / glosses) flows into the attempt
//     honestly; the store derives `independent` from it.
//   · Every shown result names its evidence ("identified from the passage",
//     "practised in writing", "you compared your spoken response"). No
//     level, CEFR, or proficiency claim is ever derived from completion.

// MARK: Stage mapping

/// Which checkpoint stage (path) a lesson belongs to, from its authored
/// level tag — the same mapping CoursesView's path cards use for its
/// content paths. A lesson with no tag belongs to Foundation, exactly like
/// the course browser treats it.
func checkpointStage(of lesson: Lesson) -> CheckpointStage {
    switch lesson.cefr {
    case "A2": return .developing
    case "A1", nil: return .foundation
    default: return .independent
    }
}

func checkpointStageDisplayName(_ stage: CheckpointStage) -> String {
    switch stage {
    case .foundation: return "Foundation"
    case .developing: return "Developing"
    case .independent: return "Independent"
    }
}

func checkpointModalityDisplayName(_ modality: CheckpointModality) -> String {
    modality.rawValue.capitalized
}

// MARK: - In-flight attempt state

/// The in-flight state of one checkpoint attempt, before it is recorded.
/// A plain value type the views mutate; `recordCheckpointRun` persists the
/// finished shape through the store API. `itemsRevealed` starts false and
/// flips to true only once the task's items and self-assessment rubric have
/// been presented (reveal-before-answer, the 5.3A contract) — an attempt
/// saved before the reveal is never independent.
struct CheckpointRun {
    let checkpoint: CheckpointTask

    /// Reading answers keyed by checkpoint question id → chosen option id.
    var readingSelections: [String: String] = [:]
    /// Submitted written response per writing item id. Never graded.
    var writingTexts: [String: String] = [:]
    /// Speaking rubric criterion ids the learner ticked (any speaking
    /// item's rubric — ids are unique per item bank).
    var criteriaMet: Set<String> = []
    /// Optional overall rating on the review scale, for the attempt.
    var rating: AttemptResponse.SelfRating? = nil
    /// Assistance used during the attempt (passage translation/glosses).
    var assistance: [AssistanceKind] = []
    /// Reveal marker: true only after the items and rubric were shown.
    var itemsRevealed = false

    /// Whether the learner engaged with at least one part — the honest
    /// gate for submitting. An untouched task records nothing.
    var hasEngagement: Bool {
        !readingSelections.isEmpty
            || writingTexts.values.contains {
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            || !criteriaMet.isEmpty
    }
}

// MARK: - Reading grading (engine-consistent, selection-style)

/// Whether a reading answer matches the accepted option(s) — the same
/// set-equality rule the engine's selection grading uses. The Spanish
/// questions are single-answer, radio-style; the rule still honours a
/// multiple-accepted question honestly.
func checkpointReadingCorrect(_ question: CheckpointReadingQuestion,
                              selectedIds: [String]) -> Bool {
    !selectedIds.isEmpty && Set(selectedIds) == Set(question.acceptedIds)
}

/// One reading question's result: the question, what was chosen, and
/// whether it matches the passage's accepted answer. The result screen
/// names exactly this comparison as the source of what it shows.
struct CheckpointReadingResult {
    let question: CheckpointReadingQuestion
    let selectedOptionText: String?
    let correct: Bool
}

/// Every reading question's result for the attempt, in checkpoint item
/// order. Questions the learner left unanswered read as not correct (the
/// result names the missing evidence instead of inventing a score).
func checkpointReadingResults(run: CheckpointRun) -> [CheckpointReadingResult] {
    var results: [CheckpointReadingResult] = []
    for item in run.checkpoint.items {
        guard case .reading(let reading) = item else { continue }
        for question in reading.questions {
            let chosen = run.readingSelections[question.id]
            let text = question.options.first(where: { $0.id == chosen })?.text
            results.append(CheckpointReadingResult(
                question: question,
                selectedOptionText: text,
                correct: chosen.map { checkpointReadingCorrect(question, selectedIds: [$0]) }
                    ?? false))
        }
    }
    return results
}

// MARK: - Recording

/// Persists the attempt exactly as the run ended, through the 5.3A store
/// API: task id, modality slots, assistance, self-rating, and the reveal
/// marker all ride along, and the store derives `independent` from
/// `itemsRevealed && assistance.isEmpty`. A retake is a fresh row; earlier
/// attempts stay. Returns the stored event, or nil when the checkpoint is
/// not in the bundled pack.
@MainActor
@discardableResult
func recordCheckpointRun(pack: CoursePack, store: LearningStore,
                         run: CheckpointRun,
                         at: Date = Date()) throws -> CheckpointAttemptEvent? {
    try store.recordCheckpointAttempt(
        pack: pack,
        checkpointId: run.checkpoint.id,
        assistance: run.assistance,
        itemsRevealed: run.itemsRevealed,
        selfRating: checkpointSelfRating(for: run),
        at: at)
}

/// Builds the optional self-rating: present whenever the attempt involved
/// speaking work or collected any ticks/rating; nil for a purely
/// receptive attempt with nothing self-assessed.
private func checkpointSelfRating(for run: CheckpointRun) -> CheckpointSelfRating? {
    let hasSpeakingWork = run.checkpoint.items.contains { $0.modality == .speaking }
    guard hasSpeakingWork || !run.criteriaMet.isEmpty || run.rating != nil else {
        return nil
    }
    return CheckpointSelfRating(
        criteriaMet: run.criteriaMet.sorted(),
        rating: run.rating)
}

// MARK: - Targeted revisit suggestions

/// A targeted, honest suggestion to revisit existing content after an
/// attempt. Never a queue and never forced: it names a concrete lesson
/// that already exists in the pack plus the evidence that lesson
/// practises. When an honest derivation is too thin, the suggestion is
/// omitted rather than guessed.
struct CheckpointRevisitSuggestion: Equatable, Identifiable {
    var id: String { "\(itemId)|\(lessonId)" }
    /// The checkpoint item that prompted the suggestion.
    let itemId: String
    /// A real lesson id in the pack.
    let lessonId: String
    /// Grounded reason copy, e.g. "Practises the words in this passage."
    let reason: String
}

/// Lessons that belong to the same stage as the checkpoint, in pack order
/// — the pool a revisit suggestion draws from, so a Foundation checkpoint
/// never points into Developing content the learner hasn't reached.
func checkpointStageLessons(pack: CoursePack, stage: CheckpointStage) -> [Lesson] {
    pack.lessons.filter { checkpointStage(of: $0) == stage }
}

/// The stage's lessons that practise speaking out loud (self-compare
/// activities) — the honest "lesson(s) that practised this skill" for a
/// speaking rubric criterion. Empty when the stage has none (then the
/// criterion gets no suggestion).
func checkpointSpeakingLessons(pack: CoursePack, stage: CheckpointStage) -> [Lesson] {
    let stageIds = Set(checkpointStageLessons(pack: pack, stage: stage).map(\.id))
    return pack.lessons.filter { lesson in
        guard stageIds.contains(lesson.id) else { return false }
        return lesson.steps.contains { step in
            guard let activity = pack.activity(id: step.activityId) else { return false }
            if case .selfCompare = activity { return true }
            return false
        }
    }
}

/// Stop words filtered out of passage/concept matching, so a match means a
/// real content word ("manzanas", "cuánto"), not "el" or "the".
private let checkpointStopWords: Set<String> = [
    "el", "la", "los", "las", "un", "una", "unos", "unas", "y", "o", "ni",
    "de", "del", "a", "al", "en", "con", "por", "para", "que", "quien",
    "es", "son", "no", "se", "su", "sus", "mi", "mis", "tu", "tus", "me",
    "te", "le", "lo", "hay", "fue", "era", "ido", "ir",
    "the", "and", "to", "of", "in", "on", "at", "for", "with", "an", "as",
    "or", "is", "are", "was", "were", "it", "its", "this", "that", "there",
    "your", "my", "his", "her", "their", "they", "them", "you", "we", "he",
    "she", "i", "me", "up", "out", "from", "by", "about", "than", "into",
]

/// Normalised lowercase tokens of a piece of Spanish/English text: accent-
/// and case-folded so "¿Cuánto cuesta?" matches "cuanto cuesta" in a
/// concept's example. Stop words and one-letter tokens are dropped.
func checkpointTokens(_ text: String) -> Set<String> {
    let folded = text.folding(
        options: [.caseInsensitive, .diacriticInsensitive],
        locale: Locale(identifier: "es"))
    let words = folded.lowercased()
        .unicodeScalars
        .split(whereSeparator: { !CharacterSet.letters.contains($0) })
        .map(String.init)
    return Set(words.filter { !checkpointStopWords.contains($0) && $0.count > 1 })
}

/// Scores every pack concept by how many of its content words (title,
/// explanation, examples, common error) appear in the passage and its
/// translation — the passage-theme lookup behind reading suggestions.
/// Concepts with at least one content-word overlap, best match first.
func checkpointConcepts(for passage: String, translation: String,
                        pack: CoursePack) -> [(concept: CourseConcept, matchedWords: Int)] {
    let passageWords = checkpointTokens(passage).union(checkpointTokens(translation))
    var scored: [(concept: CourseConcept, matchedWords: Int)] = []
    for concept in pack.concepts {
        var conceptWords = checkpointTokens(concept.title)
            .union(checkpointTokens(concept.explanation))
            .union(checkpointTokens(concept.commonError))
        for example in concept.examples {
            conceptWords.formUnion(checkpointTokens(example.target))
            conceptWords.formUnion(checkpointTokens(example.meaning))
        }
        let matched = conceptWords.intersection(passageWords).count
        if matched > 0 { scored.append((concept: concept, matchedWords: matched)) }
    }
    return scored.sorted { $0.matchedWords > $1.matchedWords }
}

/// Reading suggestions: a wrong reading answer names the lessons that
/// practised the passage's themes (concepts whose words appear in the
/// passage → lessons carrying those concepts, restricted to the
/// checkpoint's stage). A correctly answered passage earns no suggestion —
/// there is nothing honest to revisit.
func checkpointReadingSuggestions(pack: CoursePack, checkpoint: CheckpointTask,
                                  run: CheckpointRun) -> [CheckpointRevisitSuggestion] {
    var suggestions: [CheckpointRevisitSuggestion] = []
    var usedLessons = Set<String>()
    let stageIds = Set(checkpointStageLessons(pack: pack, stage: checkpoint.stage).map(\.id))
    for item in run.checkpoint.items {
        guard case .reading(let reading) = item else { continue }
        let hasWrongQuestion = reading.questions.contains { question in
            guard let chosen = run.readingSelections[question.id] else { return true }
            return !checkpointReadingCorrect(question, selectedIds: [chosen])
        }
        guard hasWrongQuestion else { continue }
        let conceptHits = checkpointConcepts(
            for: reading.passage, translation: reading.translation, pack: pack)
        for (concept, _) in conceptHits {
            for lesson in pack.lessons where lesson.conceptIds.contains(concept.id) {
                guard stageIds.contains(lesson.id), !usedLessons.contains(lesson.id)
                else { continue }
                usedLessons.insert(lesson.id)
                suggestions.append(CheckpointRevisitSuggestion(
                    itemId: item.id,
                    lessonId: lesson.id,
                    reason: CheckpointCopy.readingReason))
                if suggestions.count >= 3 { return suggestions }
            }
        }
    }
    return suggestions
}

/// Speaking suggestions: an unmet rubric criterion names the stage's
/// speaking-practice lessons. When the stage has none (an honest empty),
/// no suggestion is made rather than guessing at content.
func checkpointSpeakingSuggestions(pack: CoursePack, checkpoint: CheckpointTask,
                                   run: CheckpointRun) -> [CheckpointRevisitSuggestion] {
    var suggestions: [CheckpointRevisitSuggestion] = []
    var usedLessons = Set<String>()
    for item in run.checkpoint.items {
        guard case .speaking(let speaking) = item else { continue }
        let unmet = speaking.rubric.filter { !run.criteriaMet.contains($0.id) }
        guard !unmet.isEmpty else { continue }
        for lesson in checkpointSpeakingLessons(pack: pack, stage: checkpoint.stage) {
            guard !usedLessons.contains(lesson.id) else { continue }
            usedLessons.insert(lesson.id)
            suggestions.append(CheckpointRevisitSuggestion(
                itemId: item.id,
                lessonId: lesson.id,
                reason: CheckpointCopy.speakingReason))
        }
    }
    return suggestions
}

/// All targeted revisit suggestions for an attempt: wrong reading answers
/// and unmet speaking criteria only. Deduplicated per item so a wrong
/// reading answer on a shared passage names each lesson once.
func checkpointRevisitSuggestions(pack: CoursePack, checkpoint: CheckpointTask,
                                  run: CheckpointRun) -> [CheckpointRevisitSuggestion] {
    var suggestions = checkpointReadingSuggestions(pack: pack, checkpoint: checkpoint, run: run)
    let speaking = checkpointSpeakingSuggestions(pack: pack, checkpoint: checkpoint, run: run)
    for suggestion in speaking where !suggestions.contains(where: { $0.id == suggestion.id }) {
        suggestions.append(suggestion)
    }
    return suggestions
}

// MARK: - Small display helpers

func checkpointRatingLabel(_ rating: AttemptResponse.SelfRating) -> String {
    switch rating {
    case .again: return "Again"
    case .comfortable: return "Comfortable"
    case .hard: return "Hard"
    case .good: return "Good"
    case .easy: return "Easy"
    }
}

func checkpointAssistanceName(_ kind: AssistanceKind) -> String {
    switch kind {
    case .hint: return "hint"
    case .translation: return "translation"
    case .transcript: return "transcript"
    case .model: return "model answer"
    }
}

/// The modality slots of a task, joined for the intro line
/// ("In this task: reading · writing · speaking.").
func checkpointModalityLine(_ checkpoint: CheckpointTask) -> String {
    checkpoint.modalities.map(checkpointModalityDisplayName).joined(separator: " · ")
}

// MARK: - Learner-facing copy (5.3B)
//
// Every new string the flow shows lives here so the developer can approve
// the wording in one place and the tests can pin them (forbidden
// level/proficiency phrasings absent, source phrases present). Plain,
// British spelling throughout.

enum CheckpointCopy {
    // Entry card (course page, at the stage boundary).
    static let optionalEyebrow = "OPTIONAL TASK"
    static func cardStageLine(_ stage: CheckpointStage) -> String {
        "Rounds off the \(checkpointStageDisplayName(stage)) path."
    }
    static let cardOptionalLine =
        "Optional — nothing here is graded, and the lessons are never locked."
    static let startTask = "Start the task"
    static let practiseAgain = "Practise again"
    static func attemptsSaved(_ count: Int) -> String {
        count == 1 ? "1 attempt saved" : "\(count) attempts saved"
    }
    static let pastAttempts = "Past attempts"

    // Intro screen.
    static func insideLine(_ checkpoint: CheckpointTask) -> String {
        "In this task: \(checkpointModalityLine(checkpoint))."
    }
    static let practiceNotTest =
        "Everything you write, record or tick is saved as practice evidence. "
        + "This is practice, not a test — no score, no pass or fail, and the "
        + "lessons are never locked."
    static let notNow = "Not now"

    // Items screen.
    static let sectionReading = "READING"
    static let showTranslation = "Show translation"
    static let translationHelpNote =
        "Help was used, so this attempt won't count as independent practice."
    static let sectionWriting = "WRITING"
    static let writingCaption = "Nothing here is marked right or wrong."
    static let sectionSpeaking = "SPEAKING"
    static let speakingCaption =
        "Say it, play it back, then tick what you hear yourself doing. "
        + "This is your own self-assessment — nothing is marked right or wrong."
    static let recordMyself = "Record yourself"
    static let stopRecording = "Stop recording"
    static let starting = "Starting…"
    static let playMyRecording = "Play my recording"
    static let recordAgain = "Record again"
    static let recordingNote = "Hear yourself back. Nothing is uploaded or kept."
    static let micBlocked =
        "Microphone is blocked, so nothing could be recorded. Say it out loud "
        + "anyway and tick what you hear yourself doing."
    static let tickWhatYouHear = "Tick what you hear yourself doing:"
    static let rateYourself = "Overall, how did that feel?"
    static let ratingOptional = "Optional — your own judgement, saved with the attempt."
    static let submit = "Submit practice"
    static let answerSomeFirst = "Answer at least one part to submit."
    static let saveFailed =
        "Not saved — check your connection and try again. Your answers are intact."

    // Results screen — the source of every result.
    static let practiceSaved = "Practice saved"
    static let readingSourceCorrect =
        "Identified from the passage — your choice matches what the text says."
    static let readingSourceIncorrect =
        "Read again — the passage points to a different answer."
    static let readingUnanswered =
        "This question wasn't answered — try it again from the passage."
    static let writingSource =
        "Practised in writing — your response is saved as practice evidence, "
        + "with no right or wrong marked."
    static let speakingSource =
        "You compared your spoken response against the criteria."
    static func criterionTicked(_ text: String) -> String {
        "You ticked: “\(text)”"
    }
    static func ratingPhrase(_ label: String) -> String {
        "Your spoken response, rated by you: \(label)."
    }
    static let independentSource =
        "Answered without help — recorded as independent practice."
    static func helpedSource(_ help: String) -> String {
        "Used help: \(help) — recorded as practice with help."
    }
    static let worthAnotherLook = "Worth another look"
    static let revisitSubline =
        "Optional — open a lesson that practises what came up."
    static let openLesson = "Open lesson"
    static let done = "Done"

    // Revisit suggestion reasons (grounded in pack data).
    static let readingReason = "Practises the words in this passage."
    static let speakingReason = "Practises speaking out loud."

    // Attempts history.
    static let historyTitle = "Past attempts"
    static let historyEmpty = "No attempts yet — this task is optional."
    static let historyIndependent = "Answered without help."
    static func historyHelped(_ help: String) -> String {
        "Used help: \(help)."
    }
    static func historyTicked(_ ticked: Int, of total: Int) -> String {
        "Ticked: \(ticked) of \(total) criteria"
    }
    static func historyRated(_ label: String) -> String {
        "Rated: \(label)"
    }

    /// Every learner-facing string, gathered for the copy pin test — the
    /// developer approves the wording in one place, and the test keeps the
    /// level/proficiency claims out of all of it.
    static let allStrings: [String] = [
        optionalEyebrow,
        cardStageLine(.foundation),
        cardStageLine(.developing),
        cardOptionalLine,
        startTask,
        practiseAgain,
        attemptsSaved(1),
        attemptsSaved(2),
        pastAttempts,
        "In this task: reading · writing · speaking.",
        practiceNotTest,
        notNow,
        sectionReading, showTranslation, translationHelpNote,
        sectionWriting, writingCaption,
        sectionSpeaking, speakingCaption,
        recordMyself, stopRecording, starting, playMyRecording, recordAgain,
        recordingNote, micBlocked, tickWhatYouHear, rateYourself,
        ratingOptional, submit, answerSomeFirst, saveFailed,
        practiceSaved, readingSourceCorrect, readingSourceIncorrect,
        readingUnanswered, writingSource, speakingSource,
        criterionTicked("a criterion"), ratingPhrase("Good"),
        independentSource, helpedSource("translation"),
        worthAnotherLook, revisitSubline, openLesson, done,
        readingReason, speakingReason,
        historyTitle, historyEmpty, historyIndependent,
        historyHelped("translation"),
        historyTicked(2, of: 4), historyRated("Good"),
    ]
}

// MARK: - Entry card (course page, at the stage boundary)

/// The optional stage-end task card shown at the end of a stage's units on
/// the course page. Only rendered when the pack actually ships a task for
/// that stage — packs without one show nothing (the honest empty state).
struct CheckpointEntryCard: View {
    let pack: CoursePack
    let store: LearningStore
    let checkpoint: CheckpointTask
    let attempts: [CheckpointAttemptEvent]
    let onProgressRefresh: () -> Void

    private enum CardSheet: Identifiable {
        case task, history
        var id: String {
            switch self {
            case .task: return "task"
            case .history: return "history"
            }
        }
    }

    @State private var sheet: CardSheet?

    private var attemptCount: Int { attempts.count }

    var body: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(CheckpointCopy.optionalEyebrow)
                    .font(DesignTokens.text(11, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(DesignTokens.primary)
                Text(checkpoint.title)
                    .font(DesignTokens.display(20))
                    .foregroundStyle(DesignTokens.inkDeep)
                Text(checkpoint.introduction)
                    .font(DesignTokens.text(14))
                    .foregroundStyle(DesignTokens.ink)
                    .lineLimit(3)
                Text(CheckpointCopy.cardStageLine(checkpoint.stage))
                    .font(DesignTokens.text(13))
                    .foregroundStyle(DesignTokens.muted)
                Text(CheckpointCopy.cardOptionalLine)
                    .font(DesignTokens.text(13))
                    .foregroundStyle(DesignTokens.muted)

                StudioPrimaryButton(
                    label: attemptCount == 0
                        ? CheckpointCopy.startTask : CheckpointCopy.practiseAgain,
                    disabled: false
                ) {
                    sheet = .task
                }

                if attemptCount > 0 {
                    HStack {
                        Text(CheckpointCopy.attemptsSaved(attemptCount))
                            .font(DesignTokens.text(13))
                            .foregroundStyle(DesignTokens.muted)
                        Spacer()
                        Button(CheckpointCopy.pastAttempts) { sheet = .history }
                            .font(DesignTokens.text(13, weight: .medium))
                            .foregroundStyle(DesignTokens.primary)
                            .buttonStyle(.plain)
                    }
                }
            }
        }
        .sheet(item: $sheet) { presented in
            switch presented {
            case .task:
                CheckpointTaskView(
                    pack: pack, store: store, checkpoint: checkpoint,
                    onAttemptRecorded: onProgressRefresh)
            case .history:
                CheckpointHistoryView(checkpoint: checkpoint, attempts: attempts)
            }
        }
    }
}

// MARK: - Task flow

/// The stage-end task flow: intro → items (reveal) → results (sources +
/// suggestions). Everything lives in one sheet; nothing here ever blocks
/// lesson progression.
struct CheckpointTaskView: View {
    let pack: CoursePack
    let store: LearningStore
    let checkpoint: CheckpointTask
    let onAttemptRecorded: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var run: CheckpointRun?
    @State private var results: [CheckpointReadingResult] = []
    @State private var savedEvent: CheckpointAttemptEvent?
    @State private var saveError = false
    @State private var openLesson: OpenLesson?

    private struct OpenLesson: Identifiable {
        let id: String
    }

    var body: some View {
        NavigationStack {
            Group {
                if let run = run {
                    if let savedEvent = savedEvent {
                        resultsScreen(run: run, event: savedEvent)
                    } else {
                        itemsScreen(run: run)
                    }
                } else {
                    introScreen
                }
            }
            .navigationTitle(checkpoint.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .fullScreenCover(item: $openLesson) { selected in
            LessonPlayerView(
                pack: pack,
                lessonId: selected.id,
                store: store,
                onExit: { openLesson = nil }
            )
        }
    }

    // MARK: Intro

    private var introScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("CHECKPOINT")
                        .font(DesignTokens.text(11, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(DesignTokens.primary)
                    Text(checkpoint.title)
                        .font(DesignTokens.display(26))
                        .foregroundStyle(DesignTokens.inkDeep)
                    Text(checkpoint.introduction)
                        .font(DesignTokens.text(16))
                        .foregroundStyle(DesignTokens.ink)
                    Text(CheckpointCopy.insideLine(checkpoint))
                        .font(DesignTokens.text(14, weight: .medium))
                        .foregroundStyle(DesignTokens.primary)
                        .padding(.top, 4)
                    Text(CheckpointCopy.practiceNotTest)
                        .font(DesignTokens.text(14))
                        .foregroundStyle(DesignTokens.muted)
                }

                Spacer(minLength: 8)

                StudioPrimaryButton(label: CheckpointCopy.startTask, disabled: false) {
                    run = CheckpointRun(checkpoint: checkpoint)
                }
                HStack {
                    Spacer()
                    StudioSecondaryButton(CheckpointCopy.notNow) { dismiss() }
                    Spacer()
                }
            }
            .padding(24)
        }
    }

    // MARK: Items (the reveal)

    private func itemsScreen(run: CheckpointRun) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // The moment this screen appears the task's items and
                // rubric are genuinely presented — the reveal marker flips
                // here, and the record call at submit honours it.
                ForEach(checkpoint.items, id: \.id) { item in
                    itemSection(item)
                }

                if saveError {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(CheckpointCopy.saveFailed)
                            .font(DesignTokens.text(14))
                            .foregroundStyle(DesignTokens.attentionInk)
                        StudioSecondaryButton("Retry save") { submit() }
                    }
                }

                StudioPrimaryButton(
                    label: CheckpointCopy.submit,
                    disabled: !run.hasEngagement
                ) {
                    submit()
                }
                if !run.hasEngagement {
                    Text(CheckpointCopy.answerSomeFirst)
                        .font(DesignTokens.text(13))
                        .foregroundStyle(DesignTokens.muted)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(24)
        }
        .onAppear {
            // Reveal-before-answer: only after the items and rubric are on
            // screen does this attempt become eligible for independent
            // credit (and only if no help was used).
            guard var run = self.run, !run.itemsRevealed else { return }
            run.itemsRevealed = true
            self.run = run
        }
    }

    @ViewBuilder
    private func itemSection(_ item: CheckpointItem) -> some View {
        switch item {
        case .reading(let reading):
            readingSection(reading)
        case .writing(let writing):
            writingSection(writing)
        case .speaking(let speaking):
            speakingSection(speaking)
        }
    }

    // MARK: Reading item

    private func readingSection(_ reading: CheckpointReadingItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(CheckpointCopy.sectionReading)
                .font(DesignTokens.text(11, weight: .semibold))
                .tracking(1)
                .foregroundStyle(DesignTokens.primary)
            Text(reading.passage)
                .font(DesignTokens.text(17))
                .foregroundStyle(DesignTokens.inkDeep)

            if translationShown(reading: reading) {
                Text(reading.translation)
                    .font(DesignTokens.text(15))
                    .foregroundStyle(DesignTokens.muted)
            } else {
                StudioSecondaryButton(CheckpointCopy.showTranslation) {
                    recordAssistance(.translation)
                    shownTranslations.insert(reading.id)
                }
            }
            if run?.assistance.isEmpty == false {
                Text(CheckpointCopy.translationHelpNote)
                    .font(DesignTokens.text(13))
                    .foregroundStyle(DesignTokens.muted)
            }

            ForEach(Array(reading.questions.enumerated()), id: \.element.id) { _, question in
                VStack(alignment: .leading, spacing: 6) {
                    Text(question.question)
                        .font(DesignTokens.text(16, weight: .medium))
                        .foregroundStyle(DesignTokens.inkDeep)
                    ForEach(question.options, id: \.id) { option in
                        OptionRow(
                            text: option.text,
                            selected: run?.readingSelections[question.id] == option.id,
                            multi: false,
                            disabled: false
                        ) {
                            setReadingSelection(question.id, option.id)
                        }
                    }
                }
                .padding(.top, 4)
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

    /// Translation reveal state keyed by reading item id — the authored
    /// translation, treated as assistance exactly like the lesson player's.
    @State private var shownTranslations: Set<String> = []

    private func translationShown(reading: CheckpointReadingItem) -> Bool {
        shownTranslations.contains(reading.id)
    }

    private func setReadingSelection(_ questionId: String, _ optionId: String) {
        guard var run = self.run else { return }
        run.readingSelections[questionId] = optionId
        self.run = run
    }

    private func recordAssistance(_ kind: AssistanceKind) {
        guard var run = self.run, !run.assistance.contains(kind) else { return }
        run.assistance.append(kind)
        self.run = run
    }

    // MARK: Writing item

    private func writingSection(_ writing: CheckpointWritingItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(CheckpointCopy.sectionWriting)
                .font(DesignTokens.text(11, weight: .semibold))
                .tracking(1)
                .foregroundStyle(DesignTokens.primary)
            Text(writing.prompt)
                .font(DesignTokens.text(16))
                .foregroundStyle(DesignTokens.ink)
            TextEditor(text: writingBinding(writing.id))
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
                .accessibilityLabel(writing.prompt)
            Text(CheckpointCopy.writingCaption)
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
    }

    private func writingBinding(_ itemId: String) -> Binding<String> {
        Binding(
            get: { run?.writingTexts[itemId] ?? "" },
            set: { value in
                guard var run = self.run else { return }
                run.writingTexts[itemId] = value
                self.run = run
            })
    }

    // MARK: Speaking item

    private func speakingSection(_ speaking: CheckpointSpeakingItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(CheckpointCopy.sectionSpeaking)
                .font(DesignTokens.text(11, weight: .semibold))
                .tracking(1)
                .foregroundStyle(DesignTokens.primary)
            Text(speaking.prompt)
                .font(DesignTokens.text(16))
                .foregroundStyle(DesignTokens.ink)

            CheckpointSpeakingRecorderView()

            Text(CheckpointCopy.tickWhatYouHear)
                .font(DesignTokens.text(15, weight: .medium))
                .foregroundStyle(DesignTokens.inkDeep)
            ForEach(speaking.rubric, id: \.id) { criterion in
                OptionRow(
                    text: criterion.text,
                    selected: run?.criteriaMet.contains(criterion.id) ?? false,
                    multi: true,
                    disabled: false
                ) {
                    toggleCriterion(criterion.id)
                }
            }

            Text(CheckpointCopy.rateYourself)
                .font(DesignTokens.text(15, weight: .medium))
                .foregroundStyle(DesignTokens.inkDeep)
            ratingPicker
            Text(CheckpointCopy.ratingOptional)
                .font(DesignTokens.text(13))
                .foregroundStyle(DesignTokens.muted)

            Text(CheckpointCopy.speakingCaption)
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
    }

    private var ratingPicker: some View {
        HStack(spacing: 8) {
            ForEach([AttemptResponse.SelfRating.again,
                     .hard, .good, .easy], id: \.self) { rating in
                let selected = run?.rating == rating
                Button {
                    toggleRating(rating)
                } label: {
                    Text(checkpointRatingLabel(rating))
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
            }
        }
    }

    private func toggleCriterion(_ criterionId: String) {
        guard var run = self.run else { return }
        if run.criteriaMet.contains(criterionId) {
            run.criteriaMet.remove(criterionId)
        } else {
            run.criteriaMet.insert(criterionId)
        }
        self.run = run
    }

    private func toggleRating(_ rating: AttemptResponse.SelfRating) {
        guard var run = self.run else { return }
        run.rating = run.rating == rating ? nil : rating
        self.run = run
    }

    // MARK: Submit + results

    private func submit() {
        guard let run = self.run else { return }
        do {
            guard let event = try recordCheckpointRun(
                pack: pack, store: store, run: run) else { return }
            savedEvent = event
            results = checkpointReadingResults(run: run)
            onAttemptRecorded()
        } catch {
            saveError = true
        }
    }

    /// The results screen: every line names the evidence behind what it
    /// shows. Never a level, never a proficiency claim.
    private func resultsScreen(run: CheckpointRun, event: CheckpointAttemptEvent) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(CheckpointCopy.practiceSaved)
                    .font(DesignTokens.display(26))
                    .foregroundStyle(DesignTokens.inkDeep)

                sourceCard(run: run, event: event)

                let suggestions = checkpointRevisitSuggestions(
                    pack: pack, checkpoint: checkpoint, run: run)
                if !suggestions.isEmpty {
                    revisitCard(suggestions)
                }

                StudioPrimaryButton(label: CheckpointCopy.done, disabled: false) {
                    dismiss()
                }
            }
            .padding(24)
        }
    }

    /// "The source of each result": reading results name the passage
    /// comparison, writing names the submitted response, speaking names
    /// the recorded-and-ticked self-assessment, and the independence line
    /// names whether help was used.
    private func sourceCard(run: CheckpointRun, event: CheckpointAttemptEvent) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 14) {
                if !results.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(CheckpointCopy.sectionReading)
                            .font(DesignTokens.text(11, weight: .semibold))
                            .tracking(1)
                            .foregroundStyle(DesignTokens.primary)
                        ForEach(results, id: \.question.id) { result in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.question.question)
                                    .font(DesignTokens.text(15, weight: .medium))
                                    .foregroundStyle(DesignTokens.inkDeep)
                                if let chosen = result.selectedOptionText {
                                    Text("Your answer: \(chosen)")
                                        .font(DesignTokens.text(14))
                                        .foregroundStyle(DesignTokens.muted)
                                }
                                Text(result.correct
                                     ? CheckpointCopy.readingSourceCorrect
                                     : (result.selectedOptionText == nil
                                         ? CheckpointCopy.readingUnanswered
                                         : CheckpointCopy.readingSourceIncorrect))
                                    .font(DesignTokens.text(14))
                                    .foregroundStyle(result.correct
                                                     ? DesignTokens.primaryStrong
                                                     : DesignTokens.attentionInk)
                            }
                        }
                    }
                }

                if run.writingTexts.values.contains(
                    where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(CheckpointCopy.sectionWriting)
                            .font(DesignTokens.text(11, weight: .semibold))
                            .tracking(1)
                            .foregroundStyle(DesignTokens.primary)
                        Text(CheckpointCopy.writingSource)
                            .font(DesignTokens.text(14))
                            .foregroundStyle(DesignTokens.ink)
                    }
                }

                let speakingItems = checkpoint.items.filter { $0.modality == .speaking }
                if !speakingItems.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(CheckpointCopy.sectionSpeaking)
                            .font(DesignTokens.text(11, weight: .semibold))
                            .tracking(1)
                            .foregroundStyle(DesignTokens.primary)
                        Text(CheckpointCopy.speakingSource)
                            .font(DesignTokens.text(14))
                            .foregroundStyle(DesignTokens.ink)
                        ForEach(tickedCriteria(run: run), id: \.id) { criterion in
                            Text(CheckpointCopy.criterionTicked(criterion.text))
                                .font(DesignTokens.text(14))
                                .foregroundStyle(DesignTokens.muted)
                        }
                        if let rating = run.rating {
                            Text(CheckpointCopy.ratingPhrase(checkpointRatingLabel(rating)))
                                .font(DesignTokens.text(14))
                                .foregroundStyle(DesignTokens.muted)
                        }
                    }
                }

                Divider()
                    .overlay(DesignTokens.edgeSoft)

                Text(event.independent
                     ? CheckpointCopy.independentSource
                     : CheckpointCopy.helpedSource(
                         checkpointAssistanceList(run.assistance)))
                    .font(DesignTokens.text(14, weight: .medium))
                    .foregroundStyle(DesignTokens.muted)
            }
        }
    }

    private func tickedCriteria(run: CheckpointRun) -> [CheckpointRubricCriterion] {
        run.checkpoint.items.flatMap { item -> [CheckpointRubricCriterion] in
            guard case .speaking(let speaking) = item else { return [] }
            return speaking.rubric.filter { run.criteriaMet.contains($0.id) }
        }
    }

    private func checkpointAssistanceList(_ kinds: [AssistanceKind]) -> String {
        kinds.map(checkpointAssistanceName).joined(separator: ", ")
    }

    /// The suggestion card: existing lessons only, opened with the same
    /// lesson player every other surface uses. Never forced.
    private func revisitCard(_ suggestions: [CheckpointRevisitSuggestion]) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(CheckpointCopy.worthAnotherLook)
                    .font(DesignTokens.text(16, weight: .semibold))
                    .foregroundStyle(DesignTokens.inkDeep)
                Text(CheckpointCopy.revisitSubline)
                    .font(DesignTokens.text(13))
                    .foregroundStyle(DesignTokens.muted)
                ForEach(suggestions) { suggestion in
                    if let lesson = pack.lesson(id: suggestion.lessonId) {
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(lesson.title)
                                    .font(DesignTokens.text(15, weight: .medium))
                                    .foregroundStyle(DesignTokens.inkDeep)
                                Text(suggestion.reason)
                                    .font(DesignTokens.text(13))
                                    .foregroundStyle(DesignTokens.muted)
                            }
                            Spacer()
                            Button(CheckpointCopy.openLesson) {
                                openLesson = OpenLesson(id: lesson.id)
                            }
                            .font(DesignTokens.text(13, weight: .medium))
                            .foregroundStyle(DesignTokens.primary)
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Speaking recorder (reuses the self-compare recording pattern)

/// Record → play back → tick. The same recorder class the lesson
/// player's self-compare steps use; nothing is uploaded or kept.
struct CheckpointSpeakingRecorderView: View {
    @StateObject private var recorder = LessonStepRecorder()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if recorder.canRecord {
                if let _ = recorder.recordingURL, recorder.state != .recording {
                    HStack(spacing: 10) {
                        StudioSecondaryButton(CheckpointCopy.playMyRecording) {
                            recorder.playRecording()
                        }
                        StudioSecondaryButton(CheckpointCopy.recordAgain) {
                            recorder.discard()
                        }
                    }
                    Text(CheckpointCopy.recordingNote)
                        .font(DesignTokens.text(13))
                        .foregroundStyle(DesignTokens.muted)
                } else {
                    StudioSecondaryButton(
                        recorder.state == .recording ? CheckpointCopy.stopRecording
                            : recorder.state == .requesting ? CheckpointCopy.starting
                            : CheckpointCopy.recordMyself,
                        disabled: recorder.state == .requesting
                    ) {
                        recorder.toggle()
                    }
                }
            }

            if recorder.denied {
                Text(CheckpointCopy.micBlocked)
                    .font(DesignTokens.text(13))
                    .foregroundStyle(DesignTokens.muted)
            }
        }
        .onDisappear { recorder.discard() }
    }
}

// MARK: - Attempts history

/// Past attempts for one checkpoint: what was recorded, when, and the
/// source of each row (the event's own fields — task, modality slots,
/// assistance, self-rating, date). No scoring aggregation, no badges.
struct CheckpointHistoryView: View {
    let checkpoint: CheckpointTask
    let attempts: [CheckpointAttemptEvent]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.canvas.ignoresSafeArea()
                if attempts.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "checklist")
                            .font(.system(size: 40))
                            .foregroundStyle(DesignTokens.muted)
                        Text(CheckpointCopy.historyEmpty)
                            .font(DesignTokens.text(15))
                            .foregroundStyle(DesignTokens.muted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Spacer()
                    }
                    .padding(24)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(attempts.reversed(), id: \.id) { attempt in
                                historyRow(attempt)
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle(CheckpointCopy.historyTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func historyRow(_ attempt: CheckpointAttemptEvent) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(attempt.at.formatted(date: .abbreviated, time: .omitted))
                    .font(DesignTokens.text(13, weight: .semibold))
                    .foregroundStyle(DesignTokens.primary)
                Text(attempt.modalitySlots.map(checkpointModalityDisplayName)
                    .joined(separator: " · "))
                    .font(DesignTokens.text(14))
                    .foregroundStyle(DesignTokens.inkDeep)
                Text(attempt.independent
                     ? CheckpointCopy.historyIndependent
                     : CheckpointCopy.historyHelped(
                         attempt.assistance.map(checkpointAssistanceName)
                             .joined(separator: ", ")))
                    .font(DesignTokens.text(13))
                    .foregroundStyle(DesignTokens.muted)
                if let rating = attempt.selfRating {
                    if !rating.criteriaMet.isEmpty {
                        Text(CheckpointCopy.historyTicked(
                            rating.criteriaMet.count, of: checkpointRubricCount))
                            .font(DesignTokens.text(13))
                            .foregroundStyle(DesignTokens.muted)
                    }
                    if let overall = rating.rating {
                        Text(CheckpointCopy.historyRated(checkpointRatingLabel(overall)))
                            .font(DesignTokens.text(13))
                            .foregroundStyle(DesignTokens.muted)
                    }
                }
            }
        }
    }

    private var checkpointRubricCount: Int {
        checkpoint.items.reduce(into: 0) { count, item in
            if case .speaking(let speaking) = item { count += speaking.rubric.count }
        }
    }
}