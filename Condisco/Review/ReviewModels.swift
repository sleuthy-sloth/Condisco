import Foundation

// MARK: - Review item
//
// A due SRS evidence key resolved back to its activity: the prompt the
// learner first saw, the correct answer to recall, and the identifiers
// needed to record a review attempt through the same event pipeline as
// lessons (so the SRS reschedules identically).

struct ReviewItem: Identifiable {
    var id: String { evidenceKey }
    let evidenceKey: String
    let packId: String
    let packVersion: String
    let courseTitle: String
    let lessonId: String
    let lessonTitle: String
    let lessonRevision: Int
    let stepId: String
    let activityId: String
    let activityRevision: Int
    let prompt: String
    let answerText: String
    let feedback: String
    let dueAt: Date
}

// MARK: - Review verdict
//
// Self-assessed after the answer is revealed, mirroring the web drill
// verdicts. Maps onto FSRS v6's four native grades: only clean,
// independent recall earns full credit.

enum ReviewVerdict: String {
    case exact
    case close
    case tryAgain
    case easy

    var outcome: AttemptEvaluation.Outcome {
        self == .tryAgain ? .incorrect : .correct
    }

    /// "Close" counts as assisted: seen, but shaky.
    var independent: Bool {
        self == .exact || self == .easy
    }

    var grade: FsrsGrade {
        switch self {
        case .tryAgain: return .again
        case .close: return .hard
        case .exact: return .good
        case .easy: return .easy
        }
    }

    var response: AttemptResponse {
        switch self {
        case .tryAgain: return .selfRating(.again)
        case .close: return .selfRating(.hard)
        case .exact: return .selfRating(.good)
        case .easy: return .selfRating(.easy)
        }
    }

    var label: String {
        switch self {
        case .exact: return "I knew it"
        case .close: return "Almost"
        case .tryAgain: return "Not yet"
        case .easy: return "Easy"
        }
    }
}

// MARK: - Attempt construction
//
// Review verdicts and the lesson warm-up record through the same event
// pipeline, so the SRS reschedules an evidence key identically whether it
// was rated in the Review tab or in a lesson's warm-up phase.

extension ReviewItem {
    /// Builds the activity attempt a review verdict records: the exact
    /// shape `ReviewModel.recordVerdict` writes (same evidenceKey, stepId,
    /// response, independence, and grade mapping via `Fsrs.grade(for:)`).
    /// `at` defaults to now, matching the Review tab's behavior.
    func makeAttempt(verdict: ReviewVerdict, at: Date = Date()) -> ActivityAttempt {
        ActivityAttempt(
            id: UUID().uuidString,
            packId: packId,
            packVersion: packVersion,
            lessonId: lessonId,
            lessonRevision: lessonRevision,
            stepId: stepId,
            activityId: activityId,
            activityRevision: activityRevision,
            evidenceKey: evidenceKey,
            response: verdict.response,
            assistance: [],
            evaluation: AttemptEvaluation(
                outcome: verdict.outcome,
                independent: verdict.independent,
                feedback: ""),
            at: at)
    }
}

// MARK: - Review catalog

enum ReviewCatalog {
    /// Due items across every pack, oldest first. Also returns the
    /// soonest upcoming due date (for the empty state) when nothing is due.
    /// Main-actor isolated because it reads from LearningStore.
    @MainActor
    static func loadDue(
        packs: [CoursePack], store: LearningStore, now: Date = Date()
    ) throws -> (due: [ReviewItem], nextDueAt: Date?) {
        var due: [ReviewItem] = []
        var nextDueAt: Date?
        for pack in packs {
            let progress = try store.project(pack: pack)
            for (key, record) in progress.evidence {
                if record.fsrs.dueAt <= now {
                    if let item = makeItem(
                        pack: pack, evidenceKey: key,
                        dueAt: record.fsrs.dueAt) {
                        due.append(item)
                    }
                } else if nextDueAt == nil || record.fsrs.dueAt < nextDueAt! {
                    nextDueAt = record.fsrs.dueAt
                }
            }
        }
        due.sort { $0.dueAt < $1.dueAt }
        return (due, nextDueAt)
    }

    internal static func makeItem(
        pack: CoursePack, evidenceKey: String, dueAt: Date
    ) -> ReviewItem? {
        guard let activity = pack.activities.first(where: {
            $0.evidenceKey == evidenceKey
        }), let base = activity.base else {
            return nil
        }
        var lessonId = ""
        var lessonTitle = ""
        var lessonRevision = 0
        var stepId = "review"
        for lesson in pack.lessons {
            if let step = lesson.steps.first(where: {
                $0.activityId == activity.id
            }) {
                lessonId = lesson.id
                lessonTitle = lesson.title
                lessonRevision = lesson.revision
                stepId = step.id
                break
            }
        }
        return ReviewItem(
            evidenceKey: evidenceKey,
            packId: pack.id,
            packVersion: pack.version,
            courseTitle: pack.title,
            lessonId: lessonId,
            lessonTitle: lessonTitle,
            lessonRevision: lessonRevision,
            stepId: stepId,
            activityId: activity.id,
            activityRevision: activity.revision,
            prompt: base.prompt,
            answerText: answerText(for: activity, base: base),
            feedback: base.feedback,
            dueAt: dueAt)
    }

    /// The correct answer in plain text, per activity kind.
    private static func answerText(for activity: Activity, base: GradedBase) -> String {
        switch activity {
        case .text(let a):
            return a.answer.answers.joined(separator: " · ")
        case .selection(let a):
            return acceptedTexts(options: a.options, ids: a.acceptedIds)
        case .ordering(let a):
            let tokensById = Dictionary(
                uniqueKeysWithValues: a.tokens.map { ($0.id, $0.text) })
            guard let order = a.acceptedOrders.first else { return base.feedback }
            return order.compactMap { tokensById[$0] }.joined(separator: " ")
        case .matching(let a):
            let leftById = Dictionary(
                uniqueKeysWithValues: a.left.map { ($0.id, $0.text) })
            let rightById = Dictionary(
                uniqueKeysWithValues: a.right.map { ($0.id, $0.text) })
            return a.acceptedPairs.map { pair in
                let left = leftById[pair.leftId] ?? pair.leftId
                let right = rightById[pair.rightId] ?? pair.rightId
                return "\(left) → \(right)"
            }.joined(separator: "\n")
        case .cloze(let a):
            return a.segments.map { segment in
                switch segment {
                case .text(let text):
                    return text
                case .blank(let name, _):
                    let answer = a.blanks[name]?.answers.first ?? "…"
                    return "«\(answer)»"
                }
            }.joined()
        case .dialogueChoice(let a):
            return a.options
                .filter { a.acceptedIds.contains($0.id) }
                .map(\.text)
                .joined(separator: " · ")
        case .legacy, .sceneSelection:
            // No plain-text answer available; the authored feedback
            // explains what was being tested.
            return base.feedback
        case .information, .selfCompare:
            return base.feedback
        }
    }

    private static func acceptedTexts(options: [OptionItem], ids: [String]) -> String {
        options.filter { ids.contains($0.id) }
            .map(\.text)
            .joined(separator: " · ")
    }

    // MARK: - Tricky list
    //
    // The evidence keys whose latest review rating was "not yet": the
    // cards the learner honestly flagged as shaky. A fresh review that
    // rates the card "almost" or better retires it from the list.
    // Oldest first, so the stalest weak spots get the second pass.

    @MainActor
    static func loadTricky(
        packs: [CoursePack], store: LearningStore
    ) throws -> [ReviewItem] {
        let packsById = Dictionary(
            uniqueKeysWithValues: packs.map { ($0.id, $0) })
        var latestByKey: [String: ActivityAttempt] = [:]
        // Tolerant global read: an undecodable row anywhere in the log — even
        // in a pack never opened — is skipped and logged instead of failing
        // the whole Review tab. Selection semantics below are unchanged: the
        // decodable events arrive in the same (at, id) order as before.
        let (events, skipped) = try store.allEventsWithQuarantine()
        if !skipped.isEmpty {
            LearningStore.logCorruptRows(skipped)
        }
        for event in events {
            guard case .attempt(let attempt) = event,
                  let key = attempt.evidenceKey else { continue }
            if let current = latestByKey[key], current.at >= attempt.at {
                continue
            }
            latestByKey[key] = attempt
        }
        var tricky: [ReviewItem] = []
        for (key, attempt) in latestByKey {
            guard attempt.response == .selfRating(.again),
                  let pack = packsById[attempt.packId],
                  let item = makeItem(
                    pack: pack, evidenceKey: key, dueAt: attempt.at)
            else { continue }
            tricky.append(item)
        }
        tricky.sort { $0.dueAt < $1.dueAt }
        return tricky
    }

    // MARK: - Forecast
    //
    // Evidence not yet due but coming due within the next N device-local
    // days, for a quiet "more due tomorrow" line. Items already due are
    // excluded — they live in the due list above.

    @MainActor
    static func countDueWithin(
        packs: [CoursePack], store: LearningStore, days: Int,
        now: Date = Date()
    ) throws -> Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        guard let horizon = calendar.date(
            byAdding: .day, value: days, to: startOfToday)
        else { return 0 }
        var count = 0
        for pack in packs {
            let progress = try store.project(pack: pack)
            for (_, record) in progress.evidence {
                if record.fsrs.dueAt > now && record.fsrs.dueAt <= horizon {
                    count += 1
                }
            }
        }
        return count
    }
}

// MARK: - Warm-up recall selection

/// Purely selects the warm-up cards for a brand-new lesson: the oldest
/// due items from *earlier* lessons in the same pack, capped at `limit`.
/// No store access — the lesson player hands in the due list it already
/// loads, so the whole rule set is testable in isolation.
enum RecallWarmUp {
    /// Rules, in order over the (already oldest-first) due list:
    /// 1. drop items whose lesson is the current lesson or appears at or
    ///    after it in `pack.lessons` order ("earlier ideas" only);
    /// 2. drop items whose evidence key is produced by any *required* step
    ///    of the current lesson (never ask the exact same question within
    ///    one mission);
    /// 3. drop items whose `stepId` is the "review" fallback (quarantined
    ///    by projection, never reschedules FSRS);
    /// 4. dedupe by evidence key;
    /// 5. `prefix(limit)`.
    static func select(
        due: [ReviewItem], currentLesson: Lesson, pack: CoursePack, limit: Int = 2
    ) -> [ReviewItem] {
        guard let currentIndex = pack.lessons.firstIndex(where: {
            $0.id == currentLesson.id
        }) else { return [] }
        // Evidence the current lesson's required steps will themselves
        // produce: asking any of these in the warm-up would duplicate a
        // question the mission is about to ask.
        let currentLessonEvidence = Set(
            currentLesson.steps
                .filter { $0.required }
                .compactMap { pack.activity(id: $0.activityId)?.evidenceKey })
        var seen = Set<String>()
        var selected: [ReviewItem] = []
        for item in due {
            guard selected.count < limit else { break }
            // Earlier ideas only: the item's lesson must precede the
            // current lesson in pack order.
            guard let itemIndex = pack.lessons.firstIndex(where: {
                $0.id == item.lessonId
            }), itemIndex < currentIndex else { continue }
            guard !currentLessonEvidence.contains(item.evidenceKey) else { continue }
            // The "review" fallback step is quarantined by projection and
            // never reschedules FSRS, so rating it would be a no-op.
            guard item.stepId != "review" else { continue }
            guard seen.insert(item.evidenceKey).inserted else { continue }
            selected.append(item)
        }
        return selected
    }
}
