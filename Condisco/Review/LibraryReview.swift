import Foundation

// MARK: - Phrase-review projection (8.2 §4)
//
// The Review tab's only queue source is `ReviewCatalog.loadDue`: it
// projects each bundle pack with `LearningStore.project(pack:)` and
// resolves every due evidence key back to an authored activity via
// `ReviewCatalog.makeItem`. Saved phrases have no authored activity, and a
// synthetic in-memory `CoursePack` is not viable (the models are
// decode-only), so the library stream is a small, pure projection that
// reuses the scheduler's exact FSRS fold and the existing `ReviewItem`
// pipeline — no fake pack, no parallel scheduler.
//
// Identity: one phrase row ⇔ one evidence key ⇔ one FSRS chain. The
// evidence key is a pure function of the deterministic `savedPhraseId`
// (language + target + meaning), so a re-save — same document, another
// document, or after unsave+resave — always produces the same key: one
// queue item, one FSRS chain, by construction.

enum LibraryReview {
    @MainActor
    static func refreshSurfaces() {
        if let packs = try? PackLoader.loadPacks() {
            WidgetSnapshotWriter.refresh(packs: packs,
                focusSlug: UserDefaults.standard.string(forKey: "condisco.focusLanguage") ?? "french")
        }
        ReviewReminders.refreshShared()
        NotificationCenter.default.post(name: .condiscoProgressChanged, object: nil)
    }

    struct Snapshot {
        let due: [ReviewItem]
        let nextDueAt: Date?
        let tricky: [ReviewItem]
        let dueTomorrowCount: Int
        let languageSlugs: [String: String]
    }

    /// Read active library candidates and their existing FSRS history once.
    @MainActor
    static func load(store: LearningStore, now: Date = Date()) throws -> Snapshot {
        let phrases = candidatePhrases(
            phrases: try store.savedPhrases(), links: try store.phraseLinks())
        guard !phrases.isEmpty else {
            return Snapshot(due: [], nextDueAt: nil, tricky: [],
                            dueTomorrowCount: 0, languageSlugs: [:])
        }
        let (events, skipped) = try store.allEventsWithQuarantine()
        if !skipped.isEmpty { LearningStore.logCorruptRows(skipped) }
        let attempts = events.compactMap { event -> ActivityAttempt? in
            guard case .attempt(let attempt) = event,
                  attempt.packId == packId else { return nil }
            return attempt
        }
        let queue = loadDuePhrases(phrases: phrases, attempts: attempts, now: now)
        return Snapshot(
            due: queue.due, nextDueAt: queue.nextDueAt,
            tricky: loadTrickyPhrases(phrases: phrases, attempts: attempts),
            dueTomorrowCount: countPhrasesDueWithin(
                phrases: phrases, attempts: attempts, days: 1, now: now),
            languageSlugs: Dictionary(uniqueKeysWithValues: phrases.map {
                (evidenceKey(phraseId: $0.id), $0.languageSlug)
            }))
    }

    /// `pack_id` carried by phrase-review attempt events. The library is
    /// not a course, so this id exists only in event payloads — no pack
    /// JSON and no kv key collide with it.
    static let packId = "practice-library"

    /// Stable version tag carried on phrase-review attempts, like a pack
    /// version.
    static let packVersion = "1"

    /// One evidence key per saved phrase: `"phrase-review|<savedPhraseId>"`.
    static func evidenceKey(phraseId: String) -> String {
        "phrase-review|\(phraseId)"
    }

    /// The same fold `project(pack:)` runs for lesson evidence: correct/
    /// incorrect outcomes only (blocked/ungraded/self-assessed are
    /// ignored), `Fsrs.initial` / `Fsrs.scheduleReview` / `Fsrs.grade`,
    /// keyed by evidence key, in (at, id) order, with successes/failures
    /// tallied per key.
    ///
    /// The one difference: phrase-review attempts carry no resolvable
    /// activity, so the fold's activity-derived `mode` is fixed at
    /// `.production` (recalling target-language text). Attempts from other
    /// packs are ignored.
    static func project(attempts: [ActivityAttempt]) -> [String: EvidenceRecord] {
        let ordered = attempts.filter { attempt in
            guard attempt.packId == packId, attempt.evidenceKey != nil else {
                return false
            }
            switch attempt.evaluation.outcome {
            case .correct, .incorrect: return true
            case .blocked, .ungraded, .selfAssessed: return false
            }
        }.sorted {
            if $0.at != $1.at { return $0.at < $1.at }
            return $0.id < $1.id
        }

        var evidence: [String: EvidenceRecord] = [:]
        for attempt in ordered {
            guard let key = attempt.evidenceKey else { continue }
            let at = attempt.at
            let previous = evidence[key] ?? EvidenceRecord(
                fsrs: Fsrs.initial(at: at),
                successes: 0,
                failures: 0,
                mode: .production)
            let success = attempt.evaluation.outcome == .correct
                && attempt.evaluation.independent
            let next = Fsrs.scheduleReview(
                previous: previous.fsrs,
                grade: Fsrs.grade(for: attempt),
                reviewedAt: at)
            evidence[key] = EvidenceRecord(
                fsrs: next,
                successes: previous.successes + (success ? 1 : 0),
                failures: previous.failures + (success ? 0 : 1),
                mode: previous.mode)
        }
        return evidence
    }

    /// The review card for a saved phrase: the target phrase as the
    /// prompt, the learner's meaning as the answer. `courseTitle` is the
    /// language name (the library is not a course) and `lessonTitle` is
    /// the phrase's free-text source — the document title for library
    /// saves — so provenance reads on the card. `lessonId`/`activityId`
    /// are stable placeholders no projection resolves; they ride through
    /// `ReviewItem.makeAttempt` onto the recorded event unchanged.
    /// `presentationOrdinal` mirrors `ReviewCatalog.makeItem` for call
    /// parity; a phrase has a single authored cue (the target), so it
    /// never rotates.
    static func makeItem(
        phrase: SavedPhrase, dueAt: Date, presentationOrdinal: Int = 0
    ) -> ReviewItem {
        ReviewItem(
            evidenceKey: evidenceKey(phraseId: phrase.id),
            packId: packId,
            packVersion: packVersion,
            courseTitle: phrase.languageName,
            lessonId: "",
            lessonTitle: phrase.source,
            lessonRevision: 0,
            stepId: "review",
            activityId: "phrase-review",
            activityRevision: 0,
            prompt: phrase.target,
            answerText: phrase.meaning,
            feedback: "",
            dueAt: dueAt)
    }

    /// The review-queue candidates: saved phrases joined to
    /// `imported_phrase_links`. A phrase saved only from a lesson — or
    /// whose documents were deleted — has no link and is not a candidate;
    /// the queue reflects live documents only (§4.2, §8.2).
    static func candidatePhrases(
        phrases: [SavedPhrase], links: [ImportedPhraseLink]
    ) -> [SavedPhrase] {
        let linked = Set(links.map(\.phraseId))
        return phrases.filter { linked.contains($0.id) }
    }

    /// Due phrase-review items, oldest first, plus the soonest upcoming
    /// due date when nothing is due — the same shape and rules as
    /// `ReviewCatalog.loadDue`. `phrases` must already be the joined
    /// candidate set (see `candidatePhrases`).
    ///
    /// A candidate with no phrase-review history is due immediately:
    /// `Fsrs.initial` at its save time, which the scheduler treats as
    /// "never reviewed, due now" — exactly how a fresh lesson key enters
    /// the queue at its first attempt.
    static func loadDuePhrases(
        phrases: [SavedPhrase], attempts: [ActivityAttempt], now: Date = Date()
    ) -> (due: [ReviewItem], nextDueAt: Date?) {
        let evidence = project(attempts: attempts)
        var due: [ReviewItem] = []
        var nextDueAt: Date?
        for phrase in phrases {
            let key = evidenceKey(phraseId: phrase.id)
            let record = evidence[key] ?? EvidenceRecord(
                fsrs: Fsrs.initial(at: phrase.savedAt),
                successes: 0,
                failures: 0,
                mode: .production)
            if record.fsrs.dueAt <= now {
                due.append(makeItem(
                    phrase: phrase, dueAt: record.fsrs.dueAt,
                    presentationOrdinal: record.fsrs.reps))
            } else if nextDueAt == nil || record.fsrs.dueAt < nextDueAt! {
                nextDueAt = record.fsrs.dueAt
            }
        }
        due.sort { $0.dueAt < $1.dueAt }
        return (due, nextDueAt)
    }

    /// The phrase-review items whose latest rating was "not yet", oldest
    /// first — the same rule `ReviewCatalog.loadTricky` applies to lesson
    /// keys. `phrases` must already be the joined candidate set.
    static func loadTrickyPhrases(
        phrases: [SavedPhrase], attempts: [ActivityAttempt]
    ) -> [ReviewItem] {
        var latestByKey: [String: ActivityAttempt] = [:]
        var ratedCount: [String: Int] = [:]
        for attempt in attempts {
            guard attempt.packId == packId,
                  let key = attempt.evidenceKey else { continue }
            switch attempt.evaluation.outcome {
            case .correct, .incorrect:
                ratedCount[key, default: 0] += 1
            case .blocked, .ungraded, .selfAssessed:
                break
            }
            if let current = latestByKey[key], current.at >= attempt.at {
                continue
            }
            latestByKey[key] = attempt
        }
        var tricky: [ReviewItem] = []
        for phrase in phrases {
            let key = evidenceKey(phraseId: phrase.id)
            guard let attempt = latestByKey[key],
                  attempt.response == .selfRating(.again)
            else { continue }
            tricky.append(makeItem(
                phrase: phrase, dueAt: attempt.at,
                presentationOrdinal: ratedCount[key] ?? 0))
        }
        tricky.sort { $0.dueAt < $1.dueAt }
        return tricky
    }

    /// Phrase-review items not yet due but due within the next `days`
    /// device-local days, mirroring `ReviewCatalog.countDueWithin`.
    /// `phrases` must already be the joined candidate set. Items already
    /// due are excluded — they live in the due list above.
    static func countPhrasesDueWithin(
        phrases: [SavedPhrase], attempts: [ActivityAttempt],
        days: Int, now: Date = Date()
    ) -> Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        guard let horizon = calendar.date(
            byAdding: .day, value: days, to: startOfToday)
        else { return 0 }
        let evidence = project(attempts: attempts)
        var count = 0
        for phrase in phrases {
            guard let record = evidence[evidenceKey(phraseId: phrase.id)]
            else { continue }
            if record.fsrs.dueAt > now && record.fsrs.dueAt <= horizon {
                count += 1
            }
        }
        return count
    }
}
