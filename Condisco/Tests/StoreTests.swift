import XCTest
@testable import Condisco

// MARK: - LearningStore

/// Event-log persistence against a throwaway SQLite file per test.
/// `LearningStore` is @MainActor, so the whole class is too.
@MainActor
final class LearningStoreTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("condisco-store-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
    }

    private func makeStore() throws -> LearningStore {
        try LearningStore(path: tempDir.appendingPathComponent("store.sqlite").path)
    }

    private func frenchPack() throws -> CoursePack {
        try XCTUnwrap(
            PackLoader.loadPacks().first { $0.language == .french })
    }

    /// A valid independent-correct attempt on the first practice step of
    /// fr-home-foundation (a selection activity).
    private func makeAttempt(
        id: String, pack: CoursePack, at: Date
    ) throws -> ActivityAttempt {
        let lesson = try XCTUnwrap(pack.lesson(id: "fr-home-foundation"))
        let step = try XCTUnwrap(
            lesson.steps.first { $0.id == "fr-home-foundation-step-rb2" })
        let activity = try XCTUnwrap(pack.activity(id: step.activityId))
        guard case .selection(let spec) = activity else {
            throw XCTSkip("expected a selection activity")
        }
        return ActivityAttempt(
            id: id,
            packId: pack.id,
            packVersion: pack.version,
            lessonId: lesson.id,
            lessonRevision: lesson.revision,
            stepId: step.id,
            activityId: activity.id,
            activityRevision: activity.revision,
            evidenceKey: activity.evidenceKey,
            response: .selection(ids: spec.acceptedIds),
            assistance: [],
            evaluation: AttemptEvaluation(
                outcome: .correct, independent: true, feedback: "correct"),
            at: at)
    }

    /// An independent-correct cloze attempt on fr-home-foundation-step-rb7
    /// (the cloze activity). The response carries at least three `values`
    /// keys so the dictionary-typed field — the one JSONEncoder does not
    /// serialize with a stable key order — has room to differ between the
    /// seeded row and a fresh encode.
    private func makeClozeAttempt(
        id: String, pack: CoursePack, at: Date
    ) throws -> ActivityAttempt {
        let lesson = try XCTUnwrap(pack.lesson(id: "fr-home-foundation"))
        let step = try XCTUnwrap(
            lesson.steps.first { $0.id == "fr-home-foundation-step-rb7" })
        let activity = try XCTUnwrap(pack.activity(id: step.activityId))
        guard case .cloze = activity else {
            throw XCTSkip("expected a cloze activity")
        }
        return ActivityAttempt(
            id: id,
            packId: pack.id,
            packVersion: pack.version,
            lessonId: lesson.id,
            lessonRevision: lesson.revision,
            stepId: step.id,
            activityId: activity.id,
            activityRevision: activity.revision,
            evidenceKey: activity.evidenceKey,
            response: .cloze(values: ["b1": "Le", "b2": "chat", "b3": "sur"]),
            assistance: [],
            evaluation: AttemptEvaluation(
                outcome: .correct, independent: true, feedback: "correct"),
            at: at)
    }

    // MARK: Record → projection round trip

    func testAttemptProjectRoundTrip() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        let attempt = try makeAttempt(id: "roundtrip-1", pack: pack, at: at)
        try store.record(.attempt(attempt))

        let progress = try store.project(pack: pack)
        XCTAssertTrue(progress.quarantined.isEmpty)

        // Evidence record: one independent success, FSRS state created.
        let key = try XCTUnwrap(attempt.evidenceKey)
        let record = try XCTUnwrap(progress.evidence[key])
        XCTAssertEqual(record.successes, 1)
        XCTAssertEqual(record.failures, 0)
        XCTAssertEqual(record.mode, .recognition)
        XCTAssertEqual(record.fsrs.reps, 1)
        XCTAssertEqual(record.fsrs.lastGrade, FsrsGrade.good.rawValue)
        XCTAssertEqual(record.fsrs.dueAt.timeIntervalSince1970,
                       at.timeIntervalSince1970 + Double(record.fsrs.intervalDays) * 86_400)

        // Skill counts from the attempt's skills (reading, vocabulary).
        XCTAssertEqual(progress.skillCounts[.reading]?.independent, 1)
        XCTAssertEqual(progress.skillCounts[.vocabulary]?.independent, 1)
        XCTAssertEqual(progress.skillCounts[.listening]?.independent, 0)

        // No step completion was recorded, so no participation credit.
        XCTAssertTrue(progress.participationCompleted.isEmpty)

        // The raw log round-trips the event.
        let events = try store.learningEvents(packId: pack.id)
        XCTAssertEqual(events.count, 1)
        guard case .attempt(let stored) = events[0] else {
            return XCTFail("expected an attempt event")
        }
        XCTAssertEqual(stored, attempt)
    }

    func testFailureAttemptIncrementsFailures() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        var attempt = try makeAttempt(id: "fail-1", pack: pack, at: at)
        attempt.response = .selection(ids: ["o2"])
        attempt.evaluation = AttemptEvaluation(
            outcome: .incorrect, independent: false, feedback: "wrong")
        try store.record(.attempt(attempt))

        let progress = try store.project(pack: pack)
        let key = try XCTUnwrap(attempt.evidenceKey)
        let record = try XCTUnwrap(progress.evidence[key])
        XCTAssertEqual(record.successes, 0)
        XCTAssertEqual(record.failures, 1)
        XCTAssertEqual(record.fsrs.lastGrade, FsrsGrade.again.rawValue)

        // A miss earns no skill credit.
        XCTAssertEqual(progress.skillCounts[.reading]?.independent, 0)
    }

    func testDueEvidenceIncludesScheduledKey() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        // An old review date keeps the due date in the past.
        let attempt = try makeAttempt(
            id: "due-1", pack: pack, at: Date(timeIntervalSince1970: 1_700_000_000))
        try store.record(.attempt(attempt))

        let due = try store.dueEvidence(pack: pack)
        XCTAssertTrue(due.contains { $0.key == attempt.evidenceKey })
    }

    // MARK: Idempotency and conflicts

    func testDuplicateIdenticalRecordDoesNotDuplicateRows() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let attempt = try makeAttempt(
            id: "dup-1", pack: pack,
            at: Date(timeIntervalSince1970: 1_700_000_000))
        try store.record(.attempt(attempt))
        // Re-recording the same event is a no-op by design: no second row
        // and no .conflict, even though JSONEncoder key order can differ
        // between encodes. The store canonicalizes payloads before
        // comparing, so a duplicate never throws.
        // Guards the deterministic in-process case: this fixture carries no
        // dictionary-typed fields, so two plain encodes of it are
        // byte-identical even without canonicalization.
        try store.record(.attempt(attempt))
        let events = try store.learningEvents(packId: pack.id)
        XCTAssertEqual(events.count, 1)
        guard case .attempt(let stored) = events[0] else {
            return XCTFail("expected an attempt event")
        }
        XCTAssertEqual(stored, attempt)
    }

    func testDuplicateWithReorderedKeyPayloadIsNoOp() throws {
        // Regression: the duplicate check must compare event *content*, not
        // raw JSON bytes. Two representations with the same id and the same
        // semantic content but different JSON key order are duplicates.
        let store = try makeStore()
        let pack = try frenchPack()
        let attempt = try makeAttempt(
            id: "det-1", pack: pack,
            at: Date(timeIntervalSince1970: 1_700_000_000))

        // Seed the stored row with a reordered-key encoding of the same
        // event. Sorted keys differ byte-for-byte from the store's plain
        // encode order, which used to make the raw-string check throw a
        // spurious .conflict.
        let sortedEncoder = JSONEncoder()
        sortedEncoder.outputFormatting = [.sortedKeys]
        let reorderedPayload = try XCTUnwrap(
            String(data: sortedEncoder.encode(LearningEvent.attempt(attempt)),
                   encoding: .utf8))
        try seedEventRow(.attempt(attempt), payload: reorderedPayload)

        // Recording the canonical event must be a no-op: no conflict and
        // exactly one row.
        XCTAssertNoThrow(try store.record(.attempt(attempt)))

        let events = try store.learningEvents(packId: pack.id)
        XCTAssertEqual(events.count, 1)
        guard case .attempt(let stored) = events[0] else {
            return XCTFail("expected an attempt event")
        }
        XCTAssertEqual(stored, attempt)
    }

    func testRecordClozeValuesReorderedKeysIsNoOp() throws {
        // Regression for the *real* non-determinism behind the spurious
        // .conflict: Swift Dictionary key order in cloze responses.
        // JSONEncoder serializes `[String: String]` in the dictionary's
        // iteration order, which differs across processes/devices, so two
        // devices can persist the same semantic cloze answer with
        // different bytes. The duplicate check must canonicalize content,
        // not compare raw bytes.
        let store = try makeStore()
        let pack = try frenchPack()
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        let cloze = try makeClozeAttempt(
            id: "cloze-dict-1", pack: pack, at: at)

        // Seed the row with an explicitly reordered-key encoding of the
        // same event: the local plain encode with the `values` entries
        // reversed. The reversal is guaranteed to differ byte-for-byte
        // from the plain encode — three distinct keys can never be their
        // own reverse — so this exercises the cross-device case without
        // depending on encoder randomness.
        let seededPayload = try payloadWithReversedClozeValues(
            LearningEvent.attempt(cloze))
        XCTAssertNotEqual(seededPayload,
                          String(data: try JSONEncoder().encode(LearningEvent.attempt(cloze)),
                                 encoding: .utf8))
        try seedEventRow(.attempt(cloze), payload: seededPayload)

        // Recording the plain-encoded event must be a no-op: no conflict
        // and exactly one row.
        XCTAssertNoThrow(try store.record(.attempt(cloze)))

        let events = try store.learningEvents(packId: pack.id)
        XCTAssertEqual(events.count, 1)
        guard case .attempt(let stored) = events[0] else {
            return XCTFail("expected an attempt event")
        }
        XCTAssertEqual(stored, cloze)
    }

    /// Renders `event` with a plain encoder, then returns that payload
    /// with the cloze `values` object's entries in reverse order — the
    /// same semantic event with provably different bytes. Values are
    /// single words without braces/commas, so the scan for the object's
    /// extent is safe: only the controlled values dictionary is touched.
    private func payloadWithReversedClozeValues(
        _ event: LearningEvent
    ) throws -> String {
        let plain = try XCTUnwrap(
            String(data: JSONEncoder().encode(event), encoding: .utf8))
        let marker = #""values":"#
        guard let markerRange = plain.range(of: marker),
              let open = plain[markerRange.upperBound...].firstIndex(of: "{"),
              let close = plain[open...].firstIndex(of: "}")
        else {
            throw XCTSkip("could not locate cloze values in encoded payload")
        }
        let contentStart = plain.index(after: open)
        let entries = plain[contentStart..<close]
            .split(separator: ",", omittingEmptySubsequences: false)
        let reversed = entries.reversed().joined(separator: ",")
        return plain.replacingCharacters(
            in: contentStart..<close, with: reversed)
    }

    /// Inserts an event row directly into the store's SQLite file,
    /// bypassing `record`, so a test can seed a payload whose JSON key
    /// order differs from what the store itself would produce.
    private func seedEventRow(_ event: LearningEvent, payload: String) throws {
        let db = try Database(
            path: tempDir.appendingPathComponent("store.sqlite").path)
        let atMs = Int64((event.at.timeIntervalSince1970 * 1_000).rounded())
        let version: Int
        let type: String
        let lessonId: String?
        let activityId: String?
        let evidenceKey: String?
        switch event {
        case .practiceV1:
            version = 1; type = "practice"
            lessonId = nil; activityId = nil; evidenceKey = nil
        case .attempt(let e):
            version = 2; type = "attempt"
            lessonId = e.lessonId; activityId = e.activityId; evidenceKey = e.evidenceKey
        case .stepCompleted(let e):
            version = 2; type = "step-completed"
            lessonId = e.lessonId; activityId = nil; evidenceKey = nil
        case .lessonKnown(let e):
            version = 2; type = "lesson-known"
            lessonId = e.lessonId; activityId = nil; evidenceKey = nil
        }
        try db.execute(
            """
            INSERT INTO events(id, pack_id, event_version, type, lesson_id,
                               activity_id, evidence_key, at_ms, payload)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
            """,
            bind: {
                try $0.bindText(1, event.id)
                try $0.bindText(2, event.packId)
                try $0.bindInt64(3, Int64(version))
                try $0.bindText(4, type)
                try $0.bindText(5, lessonId)
                try $0.bindText(6, activityId)
                try $0.bindText(7, evidenceKey)
                try $0.bindInt64(8, atMs)
                try $0.bindText(9, payload)
            })
    }

    /// Rewrites an existing event row's payload, mimicking a row written
    /// by another device whose JSONEncoder emitted a different key order.
    private func updateEventRowPayload(id: String, payload: String) throws {
        let db = try Database(
            path: tempDir.appendingPathComponent("store.sqlite").path)
        try db.execute(
            "UPDATE events SET payload = ? WHERE id = ?;",
            bind: {
                try $0.bindText(1, payload)
                try $0.bindText(2, id)
            })
    }

    func testDuplicateConflictingRecordThrowsConflict() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let attempt = try makeAttempt(id: "conflict-1", pack: pack, at: Date())
        try store.record(.attempt(attempt))

        var conflicting = attempt
        conflicting.evaluation = AttemptEvaluation(
            outcome: .incorrect, independent: false, feedback: "different")
        XCTAssertThrowsError(try store.record(.attempt(conflicting))) { error in
            guard case LearningStore.StoreError.conflict(let id) = error else {
                return XCTFail("expected store conflict, got \(error)")
            }
            XCTAssertEqual(id, "conflict-1")
        }

        // The conflicting event never landed.
        XCTAssertEqual(try store.learningEvents(packId: pack.id).count, 1)
    }

    // MARK: Checkpoints

    func testCheckpointSaveLoadRoundTrip() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let lesson = try XCTUnwrap(pack.lesson(id: "fr-home-foundation"))
        let checkpoint = LessonCheckpoint(
            packId: pack.id, lessonId: lesson.id, revision: lesson.revision,
            stepId: "fr-home-foundation-step-rb4",
            selectedBranches: ["fr-home-foundation-step-rb1": "a"],
            assistance: [.translation],
            draft: .text("Le chat"),
            at: Date(timeIntervalSince1970: 1_700_000_000))

        try store.saveCheckpoint(checkpoint)
        let loaded = try store.loadCheckpoint(
            packId: pack.id, lessonId: lesson.id)
        XCTAssertEqual(loaded, checkpoint)

        // Saving again with a newer timestamp upserts, not duplicates.
        var newer = checkpoint
        newer.at = Date(timeIntervalSince1970: 1_700_000_100)
        newer.draft = .text("Le chat est")
        try store.saveCheckpoint(newer)
        XCTAssertEqual(
            try store.loadCheckpoint(packId: pack.id, lessonId: lesson.id), newer)
        XCTAssertEqual(try store.allCheckpoints().count, 1)
    }

    func testClearCheckpointRecordsTombstone() throws {
        let store = try makeStore()
        let checkpoint = LessonCheckpoint(
            packId: "fr-foundations", lessonId: "fr-home-foundation",
            revision: 2, stepId: "s1", selectedBranches: [:],
            assistance: [], draft: nil, at: Date())
        try store.saveCheckpoint(checkpoint)

        try store.clearCheckpoint(
            packId: checkpoint.packId, lessonId: checkpoint.lessonId)
        XCTAssertNil(try store.loadCheckpoint(
            packId: checkpoint.packId, lessonId: checkpoint.lessonId))
        XCTAssertEqual(try store.allCheckpointTombstones().count, 1)
    }

    // MARK: Saved phrases

    func testSavedPhraseSaveUnsaveRoundTrip() throws {
        let store = try makeStore()
        let id = LearningStore.savedPhraseId(
            languageSlug: "french", target: "Le chat", meaning: "The cat")
        let phrase = SavedPhrase(
            id: id,
            languageSlug: "french",
            languageName: "French",
            target: "Le chat",
            meaning: "The cat",
            source: "fr-home-foundation-act-rb6",
            sourcePackId: "fr-foundations",
            sourceLessonId: "fr-home-foundation",
            savedAt: Date(timeIntervalSince1970: 1_700_000_000))

        try store.savePhrase(phrase)
        XCTAssertTrue(try store.isPhraseSaved(id: id))
        XCTAssertEqual(try store.savedPhrases().count, 1)

        // Re-saving the same id is a no-op, not a second row.
        try store.savePhrase(phrase)
        XCTAssertEqual(try store.savedPhrases().count, 1)

        try store.unsavePhrase(id: id)
        XCTAssertFalse(try store.isPhraseSaved(id: id))
        XCTAssertEqual(try store.allSavedPhraseTombstones().count, 1)
    }

    // MARK: Sync bookkeeping

    func testIngestSyncedMarksEventsUploaded() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let attempt = try makeAttempt(id: "sync-1", pack: pack, at: Date())
        try store.record(.attempt(attempt))
        XCTAssertEqual(try store.unsyncedEvents().count, 1)

        try store.ingestSynced(downloaded: [], uploadedIds: [attempt.id])
        XCTAssertTrue(try store.unsyncedEvents().isEmpty)
    }

    func testIngestSyncedReplayWithReorderedKeysIsIdempotent() throws {
        // CloudKit replay: another device's copy of an event this device
        // already has, serialized with a different JSON key order, must be
        // a no-op — no duplicate row and no error out of ingest. Because
        // the replay is semantically identical it must ALSO not surface as
        // a conflict: the returned skipped set stays empty. (Before payload
        // canonicalization the raw-string compare threw .conflict here and
        // the id landed in that set.)
        let store = try makeStore()
        let pack = try frenchPack()
        let attempt = try makeAttempt(
            id: "sync-replay-1", pack: pack,
            at: Date(timeIntervalSince1970: 1_700_000_000))
        try store.record(.attempt(attempt))
        XCTAssertEqual(try store.learningEvents(packId: pack.id).count, 1)

        // Rewrite the stored row with a reordered-key encoding of the same
        // content so the local row and the incoming encode differ
        // byte-for-byte while staying semantically identical.
        let sortedEncoder = JSONEncoder()
        sortedEncoder.outputFormatting = [.sortedKeys]
        let reorderedPayload = try XCTUnwrap(
            String(data: sortedEncoder.encode(LearningEvent.attempt(attempt)),
                   encoding: .utf8))
        try updateEventRowPayload(id: attempt.id, payload: reorderedPayload)

        var skipped: Set<String> = []
        XCTAssertNoThrow(
            skipped = try store.ingestSynced(
                downloaded: [.attempt(attempt)], uploadedIds: []))
        XCTAssertTrue(skipped.isEmpty,
                      "a reordered-key replay must not surface as a conflict")

        let events = try store.learningEvents(packId: pack.id)
        XCTAssertEqual(events.count, 1)
        guard case .attempt(let stored) = events[0] else {
            return XCTFail("expected an attempt event")
        }
        XCTAssertEqual(stored, attempt)
        // The replayed id is marked uploaded, so it never uploads again.
        XCTAssertTrue(try store.unsyncedEvents().isEmpty)
    }

    func testIngestSyncedConflictingSameIdDoesNotDuplicateRows() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let attempt = try makeAttempt(
            id: "sync-conflict-1", pack: pack,
            at: Date(timeIntervalSince1970: 1_700_000_000))
        try store.record(.attempt(attempt))

        // A genuinely different event with the same id arrives via sync.
        // ingestSynced skips it rather than failing the whole sync, and it
        // must neither create a second row nor overwrite the original. The
        // returned set names the skipped id, so conflicts are surfaced
        // instead of silently swallowed.
        var conflicting = attempt
        conflicting.evaluation = AttemptEvaluation(
            outcome: .incorrect, independent: false, feedback: "different")
        let skipped = try store.ingestSynced(
            downloaded: [.attempt(conflicting)], uploadedIds: [])

        XCTAssertTrue(
            skipped.contains(attempt.id),
            "the conflicting id must be reported as skipped, got \(skipped)")

        let events = try store.learningEvents(packId: pack.id)
        XCTAssertEqual(events.count, 1)
        guard case .attempt(let stored) = events[0] else {
            return XCTFail("expected an attempt event")
        }
        XCTAssertEqual(stored, attempt)
    }

    // MARK: Misc

    func testKvAndDeviceId() throws {
        let store = try makeStore()
        XCTAssertNil(try store.kvGet("missing"))
        try store.kvSet("k", "v")
        XCTAssertEqual(try store.kvGet("k"), "v")

        let id1 = try store.deviceId()
        let id2 = try store.deviceId()
        XCTAssertEqual(id1, id2)
        XCTAssertFalse(id1.isEmpty)
    }
}

// MARK: - FsrsState

/// FSRS decode tolerance (legacy SM-2 payloads) and the scheduler's pure
/// mechanics. No actor isolation needed.
final class FsrsStateTests: XCTestCase {

    func testLegacySM2PayloadDecodesTolerantly() throws {
        // SM-2-shaped keys: easeFactor, repetitions, lastQuality + the
        // shared intervalDays/dueAt. Dates use the default JSONDecoder
        // strategy (seconds since 2001-01-01), matching the store.
        let json = """
        {
          "easeFactor": 2.5,
          "intervalDays": 6,
          "dueAt": 650000000,
          "repetitions": 3,
          "lastQuality": 4
        }
        """
        let state = try JSONDecoder().decode(
            FsrsState.self, from: Data(json.utf8))
        XCTAssertEqual(state.stability, 6)
        XCTAssertEqual(state.intervalDays, 6)
        XCTAssertEqual(state.reps, 3)
        // SM-2 quality 4 maps to the top FSRS grade band.
        XCTAssertEqual(state.lastGrade, 3)
        XCTAssertEqual(
            state.lastReviewedAt.timeIntervalSinceReferenceDate,
            650000000 - 6 * 86_400)
        XCTAssertGreaterThanOrEqual(state.difficulty, 1)
        XCTAssertLessThanOrEqual(state.difficulty, 10)
    }

    func testLegacyPayloadWithoutRepetitionsDefaultsToZero() throws {
        let json = """
        {"easeFactor": 2.0, "intervalDays": 2, "dueAt": 650000000}
        """
        let state = try JSONDecoder().decode(
            FsrsState.self, from: Data(json.utf8))
        XCTAssertEqual(state.reps, 0)
        XCTAssertEqual(state.lastGrade, 1)
        XCTAssertEqual(state.stability, 2)
    }

    func testRoundTripEncodeDecode() throws {
        let state = FsrsState(
            stability: 4.25,
            difficulty: 6.1,
            intervalDays: 5,
            dueAt: Date(timeIntervalSince1970: 700_000_000),
            lastReviewedAt: Date(timeIntervalSince1970: 600_000_000),
            lastGrade: 3,
            reps: 2)
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(FsrsState.self, from: data)
        XCTAssertEqual(decoded, state)
    }

    func testFirstGoodReviewInitializesState() throws {
        let reviewedAt = Date(timeIntervalSince1970: 700_000_000)
        let initial = Fsrs.initial(at: reviewedAt)
        XCTAssertEqual(initial.reps, 0)

        let next = Fsrs.scheduleReview(
            previous: initial, grade: .good, reviewedAt: reviewedAt)
        XCTAssertEqual(next.reps, 1)
        XCTAssertEqual(next.lastGrade, FsrsGrade.good.rawValue)
        XCTAssertEqual(next.stability, Fsrs.initStability(.good))
        XCTAssertEqual(next.difficulty, Fsrs.initDifficulty(.good))
        XCTAssertGreaterThanOrEqual(next.intervalDays, 1)
        XCTAssertEqual(
            next.dueAt.timeIntervalSince1970,
            reviewedAt.timeIntervalSince1970 + Double(next.intervalDays) * 86_400)
        XCTAssertEqual(next.lastReviewedAt, reviewedAt)
    }

    func testGradeForAttemptMapsOutcomes() {
        func attempt(outcome: AttemptEvaluation.Outcome,
                     independent: Bool,
                     response: AttemptResponse = .text("x")) -> ActivityAttempt {
            ActivityAttempt(
                id: "g", packId: "p", packVersion: "1", lessonId: "l",
                lessonRevision: 1, stepId: "s", activityId: "a",
                activityRevision: 1, evidenceKey: nil, response: response,
                assistance: [],
                evaluation: AttemptEvaluation(
                    outcome: outcome, independent: independent, feedback: "f"),
                at: Date())
        }
        XCTAssertEqual(
            Fsrs.grade(for: attempt(outcome: .correct, independent: true)), .good)
        XCTAssertEqual(
            Fsrs.grade(for: attempt(outcome: .correct, independent: false)), .hard)
        XCTAssertEqual(
            Fsrs.grade(for: attempt(outcome: .incorrect, independent: false)), .again)
        let rated = attempt(
            outcome: .selfAssessed, independent: false,
            response: .selfRating(.easy))
        XCTAssertEqual(Fsrs.grade(for: rated), .easy)
        let legacyComfortable = attempt(
            outcome: .selfAssessed, independent: false,
            response: .selfRating(.comfortable))
        XCTAssertEqual(Fsrs.grade(for: legacyComfortable), .good)
    }
}

// MARK: - Pack content regression

/// Guards against packaged-content regressions: the five languages must
/// load, validate, and ship real lessons and activities.
final class PackContentTests: XCTestCase {

    func testPacksLoadValidateAndCoverFiveLanguages() throws {
        let packs = try PackLoader.loadPacks()
        XCTAssertEqual(packs.count, 5)

        let languages = Set(packs.map(\.language.rawValue))
        XCTAssertEqual(languages.count, 5)

        for pack in packs {
            XCTAssertEqual(pack.schemaVersion, 2, pack.id)
            XCTAssertFalse(pack.lessons.isEmpty, pack.id)
            XCTAssertFalse(pack.activities.isEmpty, pack.id)
            XCTAssertNoThrow(try PackValidator.validate(pack), pack.id)
        }
    }
}

// MARK: - Multi-device sync drills (P4.2)

extension LearningStoreTests {

    /// A second, fully independent store over its own SQLite file, so a test
    /// can simulate a second device sharing nothing but the schema.
    private func makeStore(named name: String) throws -> LearningStore {
        try LearningStore(path: tempDir.appendingPathComponent(name).path)
    }

    private func millis(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1_000).rounded())
    }

    /// The `StoredCheckpoint` row another device's copy of `checkpoint`
    /// would produce on upload, with the same payload/timestamp the store
    /// itself writes.
    private func storedCheckpoint(
        _ checkpoint: LessonCheckpoint
    ) throws -> StoredCheckpoint {
        StoredCheckpoint(
            packId: checkpoint.packId,
            lessonId: checkpoint.lessonId,
            payload: try XCTUnwrap(
                String(data: JSONEncoder().encode(checkpoint), encoding: .utf8)),
            updatedAtMs: millis(checkpoint.at))
    }

    // MARK: Two-device merge drill: immutable event log (union)

    /// Guards the heart of multi-device sync: the append-only event log
    /// merges as the *union* of both devices' logs. Would catch a regression
    /// that loses events during replay, duplicates rows, marks the wrong ids
    /// uploaded, or surfaces a same-content replay as a conflict.
    func testTwoDeviceEventMergeConvergesWithoutLossOrDuplicates() throws {
        let deviceA = try makeStore(named: "device-a.sqlite")
        let deviceB = try makeStore(named: "device-b.sqlite")
        let pack = try frenchPack()
        let lesson = try XCTUnwrap(pack.lesson(id: "fr-home-foundation"))

        // One event both devices independently recorded (same id, same
        // content) plus disjoint events per device, across three kinds.
        let shared = try makeAttempt(
            id: "merge-shared-1", pack: pack,
            at: Date(timeIntervalSince1970: 1_700_000_050))
        try deviceA.record(.attempt(shared))
        try deviceB.record(.attempt(shared))

        let attemptA = try makeAttempt(
            id: "merge-devA-1", pack: pack,
            at: Date(timeIntervalSince1970: 1_700_000_000))
        try deviceA.record(.attempt(attemptA))
        try deviceA.record(.stepCompleted(StepCompletion(
            id: "merge-devA-2", packId: pack.id, packVersion: pack.version,
            lessonId: lesson.id, lessonRevision: lesson.revision,
            stepId: "fr-home-foundation-step-rb2", selectedBranchId: nil,
            attemptId: attemptA.id,
            at: Date(timeIntervalSince1970: 1_700_000_001))))

        let attemptB = try makeAttempt(
            id: "merge-devB-1", pack: pack,
            at: Date(timeIntervalSince1970: 1_700_000_100))
        try deviceB.record(.attempt(attemptB))
        try deviceB.record(.lessonKnown(LessonKnownEvent(
            id: "merge-devB-2", packId: pack.id, packVersion: pack.version,
            lessonId: lesson.id, lessonRevision: lesson.revision, known: true,
            at: Date(timeIntervalSince1970: 1_700_000_101))))

        XCTAssertEqual(try deviceA.unsyncedEvents().count, 3)
        XCTAssertEqual(try deviceB.unsyncedEvents().count, 3)

        // Drive convergence the way CloudKitSync does: each device pushes its
        // unsynced events (the server acknowledges them → uploadedIds), then
        // pulls what the other device pushed (ingestSynced marks downloaded
        // ids uploaded too, because the server already holds them).
        let aPushed = try deviceA.unsyncedEvents()
        let aUploadSkipped = try deviceA.ingestSynced(
            downloaded: [], uploadedIds: aPushed.map(\.id))
        XCTAssertTrue(aUploadSkipped.isEmpty)
        let bPullSkipped = try deviceB.ingestSynced(
            downloaded: aPushed, uploadedIds: [])
        XCTAssertTrue(bPullSkipped.isEmpty,
                      "replaying the shared event must be a no-op, not a conflict")

        let bPushed = try deviceB.unsyncedEvents()
        XCTAssertEqual(bPushed.count, 2)
        let bUploadSkipped = try deviceB.ingestSynced(
            downloaded: [], uploadedIds: bPushed.map(\.id))
        XCTAssertTrue(bUploadSkipped.isEmpty)
        let aPullSkipped = try deviceA.ingestSynced(
            downloaded: bPushed, uploadedIds: [])
        XCTAssertTrue(aPullSkipped.isEmpty)

        // The union is present on both devices: no loss, no duplicates.
        let expectedIds: Set<String> = [
            "merge-shared-1", "merge-devA-1", "merge-devA-2",
            "merge-devB-1", "merge-devB-2",
        ]
        let eventsA = try deviceA.learningEvents(packId: pack.id)
        let eventsB = try deviceB.learningEvents(packId: pack.id)
        XCTAssertEqual(Set(eventsA.map(\.id)), expectedIds)
        XCTAssertEqual(Set(eventsB.map(\.id)), expectedIds)
        XCTAssertEqual(eventsA.count, expectedIds.count)
        XCTAssertEqual(eventsB.count, expectedIds.count)

        // Upload bookkeeping settles: nothing is still waiting to upload.
        XCTAssertTrue(try deviceA.unsyncedEvents().isEmpty)
        XCTAssertTrue(try deviceB.unsyncedEvents().isEmpty)

        // A repeat full replay is a safe no-op: no new rows, no conflicts.
        let allB = try deviceB.allEvents()
        let allA = try deviceA.allEvents()
        let skippedA = try deviceA.ingestSynced(
            downloaded: allB, uploadedIds: [])
        let skippedB = try deviceB.ingestSynced(
            downloaded: allA, uploadedIds: [])
        XCTAssertTrue(skippedA.isEmpty)
        XCTAssertTrue(skippedB.isEmpty)
        XCTAssertEqual(try deviceA.learningEvents(packId: pack.id).count,
                       expectedIds.count)
        XCTAssertEqual(try deviceB.learningEvents(packId: pack.id).count,
                       expectedIds.count)
    }

    // MARK: Two-device merge drill: checkpoints (last-write-wins + tombstones)

    /// Guards the checkpoint merge contract: the newer write wins, an older
    /// remote write never clobbers local progress, a clear spreads as a
    /// tombstone that deletes on the other device, and a newer re-save
    /// retires the tombstone. Would catch a regression where a merge
    /// resurrects a cleared lesson or lets a stale row overwrite newer work.
    func testTwoDeviceCheckpointLastWriteWinsAndTombstoneConvergence() throws {
        let deviceA = try makeStore(named: "device-a.sqlite")
        let deviceB = try makeStore(named: "device-b.sqlite")
        let pack = try frenchPack()
        let lesson = try XCTUnwrap(pack.lesson(id: "fr-home-foundation"))

        let first = LessonCheckpoint(
            packId: pack.id, lessonId: lesson.id, revision: lesson.revision,
            stepId: "fr-home-foundation-step-rb1", selectedBranches: [:],
            assistance: [], draft: .text("Le"),
            at: Date(timeIntervalSince1970: 1_700_000_000))
        let second = LessonCheckpoint(
            packId: pack.id, lessonId: lesson.id, revision: lesson.revision,
            stepId: "fr-home-foundation-step-rb1", selectedBranches: [:],
            assistance: [], draft: .text("Le chat"),
            at: Date(timeIntervalSince1970: 1_700_000_100))
        try deviceA.saveCheckpoint(first)
        try deviceB.saveCheckpoint(second)

        // A newer remote write wins on the other device.
        let remoteSecond = try XCTUnwrap(deviceB.allCheckpoints().first)
        try deviceA.mergeCheckpoint(remoteSecond)
        XCTAssertEqual(
            try deviceA.loadCheckpoint(packId: pack.id, lessonId: lesson.id),
            second)
        XCTAssertEqual(try deviceA.allCheckpoints().count, 1)

        // An older remote write never rolls the newer local row back.
        let staleFirst = try storedCheckpoint(first)
        try deviceB.mergeCheckpoint(staleFirst)
        XCTAssertEqual(
            try deviceB.loadCheckpoint(packId: pack.id, lessonId: lesson.id),
            second)

        // Device A clears the lesson: the tombstone must spread to B and
        // delete B's row, never resurrecting it.
        try deviceA.clearCheckpoint(packId: pack.id, lessonId: lesson.id)
        let tombstone = try XCTUnwrap(deviceA.allCheckpointTombstones().first)
        try deviceB.mergeCheckpointTombstone(tombstone)
        XCTAssertNil(try deviceB.loadCheckpoint(
            packId: pack.id, lessonId: lesson.id))
        XCTAssertEqual(try deviceB.allCheckpointTombstones().count, 1)

        // Device B re-saves: the newer row retires the tombstone everywhere.
        // The revive timestamp is deliberately after the in-test clear time
        // (real "now"), not a fixed epoch, so the ordering never decays.
        let revivedAt = Date().addingTimeInterval(3_000)
        let revived = LessonCheckpoint(
            packId: pack.id, lessonId: lesson.id, revision: lesson.revision,
            stepId: "fr-home-foundation-step-rb1", selectedBranches: [:],
            assistance: [], draft: .text("Le chat est noir"),
            at: revivedAt)
        try deviceB.saveCheckpoint(revived)
        XCTAssertEqual(try deviceB.allCheckpointTombstones().count, 0)
        // Compare against what the store actually persisted: `at` is stored at
        // millisecond precision, so an in-memory `Date()` (sub-millisecond) is
        // not equal after the round-trip.
        let persistedRevived = try XCTUnwrap(
            deviceB.loadCheckpoint(packId: pack.id, lessonId: lesson.id))
        let remoteRevived = try storedCheckpoint(persistedRevived)
        try deviceA.mergeCheckpoint(remoteRevived)
        XCTAssertEqual(
            try deviceA.loadCheckpoint(packId: pack.id, lessonId: lesson.id),
            persistedRevived)
        XCTAssertTrue(try deviceA.allCheckpointTombstones().isEmpty)
        XCTAssertTrue(try deviceB.allCheckpointTombstones().isEmpty)

        // A stale remote tombstone (older than the local row) is dropped, so
        // an old delete can never kill a newer save.
        let staleTombstone = CheckpointTombstone(
            packId: pack.id, lessonId: lesson.id,
            deletedAtMs: millis(first.at) - 1_000)
        try deviceB.mergeCheckpointTombstone(staleTombstone)
        XCTAssertEqual(
            try deviceB.loadCheckpoint(packId: pack.id, lessonId: lesson.id),
            persistedRevived)
        XCTAssertTrue(try deviceB.allCheckpointTombstones().isEmpty)
    }

    // MARK: Two-device merge drill: saved phrases (LWW + tombstones + union)

    /// Guards the phrasebook merge contract: rows from both devices union,
    /// the same phrase is last-write-wins by saved_at, an unsave spreads as a
    /// tombstone, and a newer re-save retires it. Would catch a regression
    /// where one device's unsave resurrects on the other, or a stale save
    /// rolls a newer timestamp back.
    func testTwoDeviceSavedPhraseMergeTombstoneAndUnion() throws {
        let deviceA = try makeStore(named: "device-a.sqlite")
        let deviceB = try makeStore(named: "device-b.sqlite")

        let phrase = SavedPhrase(
            id: LearningStore.savedPhraseId(
                languageSlug: "french", target: "Le chat", meaning: "The cat"),
            languageSlug: "french", languageName: "French",
            target: "Le chat", meaning: "The cat",
            source: "fr-home-foundation-act-rb6",
            savedAt: Date(timeIntervalSince1970: 1_700_000_000))
        var savedLater = phrase
        savedLater.savedAt = Date(timeIntervalSince1970: 1_700_000_100)
        let otherPhrase = SavedPhrase(
            id: LearningStore.savedPhraseId(
                languageSlug: "french", target: "Un chien", meaning: "A dog"),
            languageSlug: "french", languageName: "French",
            target: "Un chien", meaning: "A dog",
            source: "fr-home-foundation-act-rb9",
            savedAt: Date(timeIntervalSince1970: 1_700_000_050))

        try deviceA.savePhrase(phrase)
        // Device B re-saved the same phrase later, and saved one A never saw.
        try deviceB.savePhrase(savedLater)
        try deviceB.savePhrase(otherPhrase)

        // LWW: B's later save wins when A pulls it down.
        try deviceA.mergeSavedPhrase(savedLater)
        XCTAssertEqual(
            try deviceA.savedPhrases()
                .first { $0.id == phrase.id }?.savedAt,
            savedLater.savedAt)
        XCTAssertEqual(try deviceA.savedPhrases().count, 1)

        // Union: B-only phrase arrives on A unchanged.
        try deviceA.mergeSavedPhrase(otherPhrase)
        XCTAssertEqual(try deviceA.savedPhrases().count, 2)

        // A stale save never rolls a newer timestamp back on B.
        try deviceB.mergeSavedPhrase(phrase)
        XCTAssertEqual(
            try deviceB.savedPhrases()
                .first { $0.id == phrase.id }?.savedAt,
            savedLater.savedAt)

        // A unsaves: the tombstone spreads to B; unrelated phrases survive.
        try deviceA.unsavePhrase(id: phrase.id)
        let tombstone = try XCTUnwrap(deviceA.allSavedPhraseTombstones().first)
        try deviceB.mergeSavedPhraseTombstone(tombstone)
        XCTAssertFalse(try deviceB.isPhraseSaved(id: phrase.id))
        XCTAssertTrue(try deviceB.isPhraseSaved(id: otherPhrase.id))
        XCTAssertEqual(try deviceB.allSavedPhraseTombstones().count, 1)

        // B re-saves after the clear: the newer row retires the tombstone
        // everywhere (timestamp after the in-test unsave, so ordering holds).
        var resaved = phrase
        resaved.savedAt = Date().addingTimeInterval(3_000)
        try deviceB.savePhrase(resaved)
        XCTAssertTrue(try deviceB.isPhraseSaved(id: phrase.id))
        let remoteResaved = try XCTUnwrap(
            deviceB.savedPhrases().first { $0.id == phrase.id })
        try deviceA.mergeSavedPhrase(remoteResaved)
        XCTAssertTrue(try deviceA.isPhraseSaved(id: phrase.id))
        XCTAssertTrue(try deviceA.allSavedPhraseTombstones().isEmpty)
        XCTAssertTrue(try deviceB.allSavedPhraseTombstones().isEmpty)

        let expectedIds = Set([phrase.id, otherPhrase.id])
        XCTAssertEqual(Set(try deviceA.savedPhrases().map(\.id)), expectedIds)
        XCTAssertEqual(Set(try deviceB.savedPhrases().map(\.id)), expectedIds)

        // A stale tombstone is dropped in favor of the live row.
        let staleTombstone = SavedPhraseTombstone(
            id: phrase.id, deletedAtMs: millis(phrase.savedAt) - 1_000)
        try deviceB.mergeSavedPhraseTombstone(staleTombstone)
        XCTAssertTrue(try deviceB.isPhraseSaved(id: phrase.id))
        XCTAssertTrue(try deviceB.allSavedPhraseTombstones().isEmpty)
    }

    // MARK: Two-device merge drill: listen state (last-write-wins)

    /// Guards the listen-state merge contract: one row per track,
    /// last-write-wins by updated_at_ms, unrelated tracks union across
    /// devices, and an older row never rolls a newer one back. Would catch a
    /// regression that drops a track's resume position or listens mark during
    /// sync.
    func testTwoDeviceListenStateLastWriteWins() throws {
        let deviceA = try makeStore(named: "device-a.sqlite")
        let deviceB = try makeStore(named: "device-b.sqlite")
        let t1 = Date(timeIntervalSince1970: 1_700_000_000)
        let t2 = Date(timeIntervalSince1970: 1_700_000_100)

        // Same track, different resume position on each device; plus a track
        // only device B knows.
        try deviceA.saveListenPosition(trackId: "trackT", seconds: 30, at: t1)
        try deviceB.saveListenPosition(trackId: "trackT", seconds: 90, at: t2)
        try deviceB.saveListenPosition(trackId: "trackU", seconds: 12, at: t2)

        // B's newer row wins when pulled onto A.
        let remoteB = try XCTUnwrap(
            deviceB.allListenState().first { $0.trackId == "trackT" })
        try deviceA.mergeListenState(remoteB)
        XCTAssertEqual(try deviceA.listenPosition(trackId: "trackT"), 90)

        // The older A row cannot roll B back. Rebuilt explicitly with the old
        // timestamp because the merge above already replaced A's row.
        let staleA = ListenStateRow(
            trackId: "trackT", positionSeconds: 30, listenedAtMs: nil,
            updatedAtMs: millis(t1))
        try deviceB.mergeListenState(staleA)
        XCTAssertEqual(try deviceB.listenPosition(trackId: "trackT"), 90)

        // Unrelated tracks simply arrive on the other device.
        let remoteU = try XCTUnwrap(
            deviceB.allListenState().first { $0.trackId == "trackU" })
        try deviceA.mergeListenState(remoteU)
        XCTAssertEqual(try deviceA.listenPosition(trackId: "trackU"), 12)

        // A later whole-row write (listened mark, later updated_at_ms) wins
        // the row wholesale; position and mark travel together.
        let t3 = Date(timeIntervalSince1970: 1_700_000_200)
        try deviceA.markListened(trackId: "trackT", at: t3)
        let remoteA = try XCTUnwrap(
            deviceA.allListenState().first { $0.trackId == "trackT" })
        try deviceB.mergeListenState(remoteA)
        XCTAssertEqual(try deviceB.listenedAt(trackId: "trackT"), t3)
        XCTAssertEqual(try deviceB.allListenState().count, 2)  // no duplicates
        XCTAssertEqual(try deviceA.allListenState().count, 2)
    }

    // MARK: Offline-first behavior

    /// Guards the offline-first contract: with sync unavailable (no downloads
    /// at all), every local path — record, project, review due set, checkpoint,
    /// phrasebook, listen state, KV/device id — keeps working, and an empty
    /// ingest is a strict no-op that must NOT touch the pending-upload queue.
    /// Would catch a regression where offline use breaks local writes or where
    /// a no-op sync accidentally marks events uploaded (they would never
    /// upload once connectivity returns) or throws.
    func testOfflineFirstLocalPathsWorkWithoutSync() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let lesson = try XCTUnwrap(pack.lesson(id: "fr-home-foundation"))
        let at = Date(timeIntervalSince1970: 1_700_000_000)

        // Record → project + review.
        let attempt = try makeAttempt(id: "offline-1", pack: pack, at: at)
        try store.record(.attempt(attempt))
        let progress = try store.project(pack: pack)
        XCTAssertTrue(progress.quarantined.isEmpty)
        XCTAssertEqual(progress.evidence.count, 1)
        XCTAssertEqual(try store.dueEvidence(pack: pack).count, 1)
        XCTAssertEqual(try store.practiceDays(), 1)

        // Checkpoint.
        let checkpoint = LessonCheckpoint(
            packId: pack.id, lessonId: lesson.id, revision: lesson.revision,
            stepId: "fr-home-foundation-step-rb4",
            selectedBranches: ["fr-home-foundation-step-rb1": "a"],
            assistance: [.translation], draft: .text("Le chat"), at: at)
        try store.saveCheckpoint(checkpoint)
        XCTAssertEqual(
            try store.loadCheckpoint(packId: pack.id, lessonId: lesson.id),
            checkpoint)

        // Phrasebook.
        let phrase = SavedPhrase(
            id: LearningStore.savedPhraseId(
                languageSlug: "french", target: "Le chat", meaning: "The cat"),
            languageSlug: "french", languageName: "French",
            target: "Le chat", meaning: "The cat",
            source: "offline", savedAt: at)
        try store.savePhrase(phrase)
        XCTAssertTrue(try store.isPhraseSaved(id: phrase.id))

        // Listen state.
        try store.saveListenPosition(trackId: "offline-track", seconds: 42, at: at)
        XCTAssertEqual(try store.listenPosition(trackId: "offline-track"), 42)
        try store.markListened(trackId: "offline-track", at: at.addingTimeInterval(100))
        XCTAssertEqual(
            try store.listenedAt(trackId: "offline-track"),
            at.addingTimeInterval(100))

        // KV + device id.
        try store.kvSet("offline-k", "offline-v")
        XCTAssertEqual(try store.kvGet("offline-k"), "offline-v")
        XCTAssertEqual(try store.deviceId(), try store.deviceId())

        // Sync unavailable: an empty ingest is a safe no-op.
        let skipped = try store.ingestSynced(downloaded: [], uploadedIds: [])
        XCTAssertTrue(skipped.isEmpty)

        // The no-op must NOT mark local events uploaded: they still need to
        // ride up when connectivity returns.
        XCTAssertEqual(try store.unsyncedEvents().count, 1)
        XCTAssertEqual(try store.learningEvents(packId: pack.id).count, 1)

        // Everything still answers after the empty ingest.
        XCTAssertEqual(try store.project(pack: pack).evidence.count, 1)
        XCTAssertEqual(try store.dueEvidence(pack: pack).count, 1)
        XCTAssertEqual(try store.allCheckpoints().count, 1)
        XCTAssertEqual(try store.savedPhrases().count, 1)
        XCTAssertEqual(try store.listenPosition(trackId: "offline-track"), 42)
    }

    // MARK: Malformed content — store side

    /// Guards the store's handling of a corrupt stored event row. The raw-log
    /// reads (`learningEvents`, `allEvents`) still fail loudly with a typed
    /// `StoreError.corruptPayload` naming the offending id — never a crash,
    /// and never silently dropping history — while write paths stay usable.
    /// The tolerant reads (`project`, `unsyncedEvents`) are covered by
    /// `testCorruptStoredEventPayloadStillProjectsAndSyncs`.
    func testCorruptStoredEventPayloadRawLogsThrowTypedErrorNotCrash() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let good = try makeAttempt(
            id: "good-1", pack: pack,
            at: Date(timeIntervalSince1970: 1_700_000_000))
        try store.record(.attempt(good))

        // A second row whose payload is not JSON at all — the shape a
        // half-written or bit-rotted event row could take on disk. Seeded
        // directly so no store API hides the corruption.
        let seed = try makeAttempt(
            id: "corrupt-seed-1", pack: pack,
            at: Date(timeIntervalSince1970: 1_705_000_000))
        try seedEventRow(.attempt(seed), payload: "{ this is not json")

        // The raw-log reads stay fail-loud: complete-history consumers
        // (data export, review feeds, lesson resume) must not silently lose
        // a row. They throw a typed error naming the first bad id — never
        // a crash.
        XCTAssertThrowsError(try store.learningEvents(packId: pack.id)) { error in
            guard case LearningStore.StoreError.corruptPayload(let id) = error else {
                return XCTFail("expected corruptPayload, got \(error)")
            }
            XCTAssertEqual(id, "corrupt-seed-1")
        }
        XCTAssertThrowsError(try store.allEvents()) { error in
            guard case LearningStore.StoreError.corruptPayload = error else {
                return XCTFail("expected corruptPayload from allEvents, got \(error)")
            }
        }

        // The corruption stays observable without a throw.
        XCTAssertEqual(try store.corruptEventIds(), ["corrupt-seed-1"])

        // Write paths stay usable around the corrupt row: a fresh valid event
        // still records (practiceDays counts rows without decoding payloads).
        let good2 = try makeAttempt(
            id: "good-2", pack: pack,
            at: Date(timeIntervalSince1970: 1_710_000_000))
        try store.record(.attempt(good2))
        XCTAssertEqual(try store.practiceDays(), 3)
    }

    /// A corrupt stored event row must not dead-end the learner or block
    /// sync: `project(pack:)` still projects the valid rows and reports the
    /// corrupt id in `quarantined`, and `unsyncedEvents()` still returns the
    /// decodable events so the next CloudKit upload proceeds. Since the
    /// corrupt row is skipped by both, its id stays observable through
    /// `PackProgress.quarantined` and `corruptEventIds()`.
    func testCorruptStoredEventPayloadStillProjectsAndSyncs() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let good = try makeAttempt(
            id: "good-1", pack: pack,
            at: Date(timeIntervalSince1970: 1_700_000_000))
        try store.record(.attempt(good))

        let seed = try makeAttempt(
            id: "corrupt-seed-1", pack: pack,
            at: Date(timeIntervalSince1970: 1_705_000_000))
        try seedEventRow(.attempt(seed), payload: "not json at all")

        // Projection survives: the valid attempt still contributes evidence
        // and skill counts exactly as it would with no corrupt row present.
        let progress = try store.project(pack: pack)
        let key = try XCTUnwrap(good.evidenceKey)
        let record = try XCTUnwrap(progress.evidence[key])
        XCTAssertEqual(record.successes, 1)
        XCTAssertEqual(record.failures, 0)
        XCTAssertEqual(progress.skillCounts[.reading]?.independent, 1)
        // The corrupt id is surfaced, not hidden.
        XCTAssertEqual(progress.quarantined, ["corrupt-seed-1"])

        // Sync survives: the pending-upload read returns the decodable event
        // instead of throwing, so CloudKit upload proceeds.
        let unsynced = try store.unsyncedEvents()
        XCTAssertEqual(unsynced.count, 1)
        guard case .attempt(let uploaded) = unsynced[0] else {
            return XCTFail("expected the good attempt to be pending upload")
        }
        XCTAssertEqual(uploaded, good)

        XCTAssertEqual(try store.corruptEventIds(), ["corrupt-seed-1"])
    }

    /// Guards the pack-scoped tolerant read that backs lesson boot: it must
    /// return the decodable events while reporting undecodable ids, the
    /// strict `learningEvents(packId:)` must still throw, a corrupt row in
    /// one pack must never leak into another pack's read, and
    /// `project(pack:)` reports the skipped id in `quarantined` exactly
    /// once. A corrupt row must not block opening or resuming any lesson in
    /// the pack (Major 1).
    func testPackScopedTolerantReadReturnsGoodEventsAndReportsSkipped() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let good = try makeAttempt(
            id: "tolerant-good-1", pack: pack,
            at: Date(timeIntervalSince1970: 1_700_000_000))
        try store.record(.attempt(good))

        // A corrupt row inside this pack…
        let seed = try makeAttempt(
            id: "tolerant-corrupt-1", pack: pack,
            at: Date(timeIntervalSince1970: 1_705_000_000))
        try seedEventRow(.attempt(seed), payload: "not json")
        // …and an unrelated corrupt row in a pack that was never opened.
        let otherPack = ActivityAttempt(
            id: "tolerant-corrupt-other", packId: "some-other-pack",
            packVersion: "1", lessonId: "l", lessonRevision: 1,
            stepId: "s", activityId: "a", activityRevision: 1,
            evidenceKey: nil, response: .text("x"), assistance: [],
            evaluation: AttemptEvaluation(
                outcome: .correct, independent: true, feedback: "f"),
            at: Date(timeIntervalSince1970: 1_706_000_000))
        try seedEventRow(.attempt(otherPack), payload: "also not json")

        // Tolerant pack-scoped read: good events come back, the corrupt id
        // is reported alongside, and the other pack's corruption never leaks
        // into this pack's read.
        let (events, skipped) = try store.learningEventsWithQuarantine(packId: pack.id)
        XCTAssertEqual(events.map(\.id), ["tolerant-good-1"])
        XCTAssertEqual(skipped, ["tolerant-corrupt-1"])

        // The unrelated pack's read reports only its own corrupt row.
        let (otherEvents, otherSkipped) = try store.learningEventsWithQuarantine(
            packId: "some-other-pack")
        XCTAssertTrue(otherEvents.isEmpty)
        XCTAssertEqual(otherSkipped, ["tolerant-corrupt-other"])

        // The strict raw-log read stays fail-loud, naming this pack's row.
        XCTAssertThrowsError(try store.learningEvents(packId: pack.id)) { error in
            guard case LearningStore.StoreError.corruptPayload(let id) = error else {
                return XCTFail("expected corruptPayload, got \(error)")
            }
            XCTAssertEqual(id, "tolerant-corrupt-1")
        }

        // project() reports the skipped id in quarantined exactly once and
        // still projects the valid event's evidence.
        let progress = try store.project(pack: pack)
        XCTAssertEqual(progress.quarantined, ["tolerant-corrupt-1"])
        XCTAssertEqual(progress.evidence.count, 1)
    }

    /// `ingestSynced` must continue past a corrupt local row: a sync pull
    /// that downloads remote events while an undecodable row exists on this
    /// device neither throws nor wedges — the remote rows land and get
    /// marked uploaded, and the corrupt id stays observable. Also guards the
    /// Review tab's tolerant global read (`allEventsWithQuarantine`), which
    /// returns the decodable log while reporting the skipped id.
    func testIngestSyncedContinuesPastCorruptLocalRow() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        let local = try makeAttempt(id: "ingest-corrupt-local", pack: pack, at: at)
        try store.record(.attempt(local))

        // A corrupt local row in the same pack.
        let seed = try makeAttempt(
            id: "ingest-corrupt-bad", pack: pack,
            at: at.addingTimeInterval(100))
        try seedEventRow(.attempt(seed), payload: "boom")

        // Another device's event pulls down while the corrupt row exists.
        let remote = try makeAttempt(
            id: "ingest-corrupt-remote", pack: pack,
            at: at.addingTimeInterval(200))
        let skippedConflicts = try store.ingestSynced(
            downloaded: [.attempt(remote)], uploadedIds: [])
        XCTAssertTrue(skippedConflicts.isEmpty,
                      "a corrupt local row must not surface as a sync conflict")

        // The remote event recorded and the local one survived (tolerant
        // read — the strict raw-log read would throw on the corrupt row).
        let (events, _) = try store.learningEventsWithQuarantine(packId: pack.id)
        XCTAssertEqual(Set(events.map(\.id)),
                       ["ingest-corrupt-local", "ingest-corrupt-remote"])

        // The corrupt row is still observable and never appeared in the
        // pending-upload queue.
        XCTAssertEqual(try store.corruptEventIds(), ["ingest-corrupt-bad"])
        XCTAssertEqual(try store.unsyncedEvents().map(\.id),
                       ["ingest-corrupt-local"])

        // The Review tab's tolerant global read behaves the same way: good
        // history in, skipped id reported, no throw.
        let (all, allSkipped) = try store.allEventsWithQuarantine()
        XCTAssertEqual(Set(all.map(\.id)),
                       ["ingest-corrupt-local", "ingest-corrupt-remote"])
        XCTAssertEqual(allSkipped, ["ingest-corrupt-bad"])
    }

    /// A corrupt row must never upload: it never appears in
    /// `unsyncedEvents()` (the read that feeds CloudKit), `ingestSynced`'s
    /// upload marking never touches it, and it stays observable via
    /// `corruptEventIds()` even after every decodable event is acknowledged.
    func testCorruptRowIsNeverUploaded() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        let good = try makeAttempt(id: "never-upload-good", pack: pack, at: at)
        try store.record(.attempt(good))
        let seed = try makeAttempt(
            id: "never-upload-bad", pack: pack,
            at: at.addingTimeInterval(100))
        try seedEventRow(.attempt(seed), payload: "not json")

        // Before any upload: the pending queue carries only the decodable
        // event; the corrupt id is excluded, never sent to CloudKit.
        XCTAssertEqual(try store.unsyncedEvents().map(\.id), ["never-upload-good"])
        XCTAssertEqual(try store.corruptEventIds(), ["never-upload-bad"])

        // The server acknowledges the good event; ingest marks it uploaded.
        let skipped = try store.ingestSynced(
            downloaded: [], uploadedIds: ["never-upload-good"])
        XCTAssertTrue(skipped.isEmpty)
        XCTAssertTrue(try store.unsyncedEvents().isEmpty)

        // The corrupt id was untouched by upload marking: still observable,
        // never in the pending queue — and a later fresh event syncs alone.
        XCTAssertEqual(try store.corruptEventIds(), ["never-upload-bad"])
        let fresh = try makeAttempt(
            id: "never-upload-fresh", pack: pack,
            at: at.addingTimeInterval(300))
        try store.record(.attempt(fresh))
        XCTAssertEqual(try store.unsyncedEvents().map(\.id), ["never-upload-fresh"])
    }

    /// Corrupt ids are surfaced in stable (at, id) order regardless of the
    /// order the rows were seeded, and the raw-log read names the
    /// chronologically first bad row.
    func testCorruptEventIdsStableOrderAndFirstBadRowNamed() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        // Seed out of chronological order on purpose: later at_ms first.
        let later = try makeAttempt(
            id: "corrupt-later", pack: pack,
            at: Date(timeIntervalSince1970: 1_710_000_000))
        try seedEventRow(.attempt(later), payload: "boom")
        let earlier = try makeAttempt(
            id: "corrupt-earlier", pack: pack,
            at: Date(timeIntervalSince1970: 1_700_000_000))
        try seedEventRow(.attempt(earlier), payload: "also boom")

        // Oldest first, matching the ORDER BY at_ms, id of every read.
        XCTAssertEqual(try store.corruptEventIds(),
                       ["corrupt-earlier", "corrupt-later"])

        // The fail-loud raw read names the same chronologically first row.
        XCTAssertThrowsError(try store.learningEvents(packId: pack.id)) { error in
            guard case LearningStore.StoreError.corruptPayload(let id) = error else {
                return XCTFail("expected corruptPayload, got \(error)")
            }
            XCTAssertEqual(id, "corrupt-earlier")
        }

        // Projection reports the whole pack-scoped set in the same order.
        let progress = try store.project(pack: pack)
        XCTAssertEqual(progress.quarantined,
                       ["corrupt-earlier", "corrupt-later"])
        XCTAssertTrue(progress.evidence.isEmpty)
    }
}

// MARK: - Malformed content (P4.2)

/// Decode-layer guards for malformed content. No actor isolation needed:
/// these exercise `CoursePack`/`LearningEvent` decoding and `PackValidator`
/// directly, the exact boundary PackLoader and CloudKitSync decode against.
final class MalformedContentTests: XCTestCase {

    /// A schema-valid, minimal pack shell: every required key with empty
    /// arrays. Decodes, but violates the authored invariants.
    private func minimalPackJSON(schemaVersion: Int = 2) -> String {
        """
        {"schemaVersion":\(schemaVersion),"id":"mini","version":"1.0.0","language":"fr","title":"t","sourceLanguage":"en","description":"d","attribution":"a","units":[],"concepts":[],"vocabulary":[],"media":[],"activities":[],"lessons":[]}
        """
    }

    /// Guards that a pack file cut off mid-document is rejected by the
    /// `CoursePack` decoding path instead of crashing. This is the shape
    /// `Data(contentsOf:)` yields for a truncated bundled pack; PackLoader
    /// catches per-file decode failures and collects them, so a single bad
    /// file degrades to "skipped", and only an all-failed load throws.
    func testTruncatedPackJSONThrowsSafeDecodingError() throws {
        let truncated = """
        {"schemaVersion":2,"id":"mini","version":"1.0.0","language":"fr","title":"t","sourceLanguage":"en","description":"d","attribution":"a","units":[{"
        """
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                CoursePack.self, from: Data(truncated.utf8)))
    }

    /// Guards that a wrong `schemaVersion` is rejected with a typed
    /// `DecodingError`, never trusted and never crashing.
    func testWrongSchemaVersionPackThrowsTypedError() throws {
        let bad = minimalPackJSON(schemaVersion: 1)
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                CoursePack.self, from: Data(bad.utf8))
        ) { error in
            XCTAssertTrue(error is DecodingError,
                          "expected DecodingError, got \(error)")
        }
    }

    /// Guards that a mis-typed field (bad schema) is rejected with a typed
    /// `DecodingError.typeMismatch` rather than crashing or being coerced.
    func testWronglyTypedPackFieldThrowsTypedError() throws {
        let bad = """
        {"schemaVersion":2,"id":"mini","version":"1.0.0","language":"fr","title":"t","sourceLanguage":"en","description":"d","attribution":"a","units":"oops","concepts":[],"vocabulary":[],"media":[],"activities":[],"lessons":[]}
        """
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                CoursePack.self, from: Data(bad.utf8))
        ) { error in
            XCTAssertTrue(error is DecodingError,
                          "expected DecodingError, got \(error)")
        }
    }

    /// Guards the second line of defense: a pack that *decodes* cleanly but
    /// violates authored invariants (here: an active pack with no units,
    /// concepts or lessons) is rejected by PackValidator — the check
    /// PackLoader runs on every bundled pack. Would catch a regression that
    /// lets an invalid-but-decodable pack past validation.
    func testSchemaValidButInvalidPackFailsValidator() throws {
        let pack = try JSONDecoder().decode(
            CoursePack.self, from: Data(minimalPackJSON().utf8))
        XCTAssertThrowsError(try PackValidator.validate(pack)) { error in
            XCTAssertTrue(error is PackValidationError,
                          "expected PackValidationError, got \(error)")
        }
    }

    /// Guards the event-payload decode boundary — the exact payload shape
    /// CloudKitSync.decodeEvent reads from a CKRecord's "payload" field. Its
    /// guard is `try?` + nil, so any of these failures leaves the record
    /// quarantined (silently dropped from the change feed) instead of failing
    /// a sync; `ingestSynced` never sees them. Would catch a regression that
    /// turns undecodable sync content into a crash or a failed sync.
    func testMalformedEventPayloadRejectedAtDecode() throws {
        // Truncated mid-response.
        let truncated = """
        {"eventVersion":2,"type":"attempt","id":"x","packId":"p","packVersion":"1","lessonId":"l","lessonRevision":1,"stepId":"s","activityId":"a","activityRevision":1,"response":
        """
        XCTAssertThrowsError(try JSONDecoder().decode(
            LearningEvent.self, from: Data(truncated.utf8)))

        // Untyped-as-telepathy response kind.
        let bogusKind = """
        {"eventVersion":2,"type":"attempt","id":"x","packId":"p","packVersion":"1","lessonId":"l","lessonRevision":1,"stepId":"s","activityId":"a","activityRevision":1,"response":{"kind":"telepathy"},"assistance":[],"evaluation":{"outcome":"correct","independent":true,"feedback":"f"},"at":"2023-11-14T22:13:20.000Z"}
        """
        XCTAssertThrowsError(try JSONDecoder().decode(
            LearningEvent.self, from: Data(bogusKind.utf8)))

        // Unsupported event version.
        let badVersion = """
        {"eventVersion":9,"type":"attempt","id":"x"}
        """
        XCTAssertThrowsError(try JSONDecoder().decode(
            LearningEvent.self, from: Data(badVersion.utf8)))
    }
}

// MARK: - Warm-up recall (P2.2)
//
// The delayed-recall warm-up inside LessonPlayerView: due cards from
// earlier lessons, chosen purely by RecallWarmUp.select and recorded
// through the same event pipeline as Review tab verdicts.

extension LearningStoreTests {

    /// A due review item resolved the way ReviewCatalog.makeItem does —
    /// built directly so the selection tests don't need a store.
    private func warmUpItem(
        pack: CoursePack, lessonId: String, evidenceKey: String,
        dueAt: Date, stepId: String = "lesson-step"
    ) -> ReviewItem {
        let lesson = pack.lesson(id: lessonId)
        return ReviewItem(
            evidenceKey: evidenceKey,
            packId: pack.id,
            packVersion: pack.version,
            courseTitle: pack.title,
            lessonId: lessonId,
            lessonTitle: lesson?.title ?? lessonId,
            lessonRevision: lesson?.revision ?? 1,
            stepId: stepId,
            activityId: evidenceKey,
            activityRevision: 1,
            prompt: "Warm-up prompt",
            answerText: "Warm-up answer",
            feedback: "Warm-up feedback",
            dueAt: dueAt)
    }

    /// The lesson ids an event list's attempts belong to, for the
    /// checkpoint-semantics guard (the event union has no lessonId
    /// shorthand).
    private func attemptedLessonIds(_ events: [LearningEvent]) -> Set<String> {
        Set(events.compactMap { event -> String? in
            guard case .attempt(let attempt) = event else { return nil }
            return attempt.lessonId
        })
    }

    // MARK: Selection rules (pure — no store)

    func testWarmUpSelectsOldestFirstFromEarlierLessonsOnly() throws {
        let pack = try frenchPack()
        let current = try XCTUnwrap(pack.lesson(id: "fr-home-foundation"))
        let t1 = Date(timeIntervalSince1970: 1_700_000_000)

        let earlier = warmUpItem(
            pack: pack, lessonId: "fr-identity-foundation",
            evidenceKey: "fr-identity-foundation-meaning", dueAt: t1)
        let earlierToo = warmUpItem(
            pack: pack, lessonId: "fr-numbers-foundation",
            evidenceKey: "fr-numbers-foundation-cloze",
            dueAt: t1.addingTimeInterval(100))
        let currentLessonItem = warmUpItem(
            pack: pack, lessonId: "fr-home-foundation",
            evidenceKey: "fr-people-foundation-meet",
            dueAt: t1.addingTimeInterval(200))
        let laterLessonItem = warmUpItem(
            pack: pack, lessonId: "fr-descriptions-foundation",
            evidenceKey: "fr-descriptions-foundation-order",
            dueAt: t1.addingTimeInterval(300))

        let selected = RecallWarmUp.select(
            due: [earlier, earlierToo, currentLessonItem, laterLessonItem],
            currentLesson: current, pack: pack, limit: 2)

        // Oldest first, earlier lessons only: the current-lesson item and
        // the later-lesson item are both dropped, and the limit caps at two.
        XCTAssertEqual(
            selected.map(\.evidenceKey),
            ["fr-identity-foundation-meaning", "fr-numbers-foundation-cloze"])
    }

    func testWarmUpExcludesCurrentLessonEvidenceKeys() throws {
        let pack = try frenchPack()
        let current = try XCTUnwrap(pack.lesson(id: "fr-home-foundation"))
        let t1 = Date(timeIntervalSince1970: 1_700_000_000)

        // A due item for an earlier lesson that reuses an evidence key the
        // current lesson itself will produce — the "never ask the exact
        // same question within one mission" guarantee.
        let duplicated = warmUpItem(
            pack: pack, lessonId: "fr-identity-foundation",
            evidenceKey: "fr-home-foundation-meet", dueAt: t1)
        let other = warmUpItem(
            pack: pack, lessonId: "fr-identity-foundation",
            evidenceKey: "fr-identity-foundation-meaning",
            dueAt: t1.addingTimeInterval(100))

        let selected = RecallWarmUp.select(
            due: [duplicated, other], currentLesson: current, pack: pack)

        XCTAssertEqual(selected.map(\.evidenceKey), ["fr-identity-foundation-meaning"])
    }

    func testWarmUpNeverDuplicatesWithinMission() throws {
        let pack = try frenchPack()
        let current = try XCTUnwrap(pack.lesson(id: "fr-home-foundation"))
        let t1 = Date(timeIntervalSince1970: 1_700_000_000)

        // Two due items resolve to the same evidence key; only the oldest
        // may be asked once this visit.
        let first = warmUpItem(
            pack: pack, lessonId: "fr-numbers-foundation",
            evidenceKey: "fr-numbers-foundation-cloze", dueAt: t1)
        let duplicate = warmUpItem(
            pack: pack, lessonId: "fr-numbers-foundation",
            evidenceKey: "fr-numbers-foundation-cloze",
            dueAt: t1.addingTimeInterval(100))
        let other = warmUpItem(
            pack: pack, lessonId: "fr-numbers-foundation",
            evidenceKey: "fr-numbers-foundation-meet",
            dueAt: t1.addingTimeInterval(50))

        let selected = RecallWarmUp.select(
            due: [first, duplicate, other], currentLesson: current, pack: pack, limit: 3)

        XCTAssertEqual(
            selected.map(\.evidenceKey),
            ["fr-numbers-foundation-cloze", "fr-numbers-foundation-meet"])
    }

    func testWarmUpEmptyWhenNothingDueEarlier() throws {
        let pack = try frenchPack()
        let current = try XCTUnwrap(pack.lesson(id: "fr-home-foundation"))
        let t1 = Date(timeIntervalSince1970: 1_700_000_000)

        let currentLessonItem = warmUpItem(
            pack: pack, lessonId: "fr-home-foundation",
            evidenceKey: "fr-home-foundation-meet", dueAt: t1)
        let later = warmUpItem(
            pack: pack, lessonId: "fr-descriptions-foundation",
            evidenceKey: "fr-descriptions-foundation-order", dueAt: t1)
        let laterToo = warmUpItem(
            pack: pack, lessonId: "fr-plural-foundation",
            evidenceKey: "fr-plural-foundation-cloze",
            dueAt: t1.addingTimeInterval(100))

        XCTAssertTrue(RecallWarmUp.select(
            due: [currentLessonItem, later, laterToo],
            currentLesson: current, pack: pack).isEmpty)
        XCTAssertTrue(RecallWarmUp.select(
            due: [], currentLesson: current, pack: pack).isEmpty)
    }

    func testWarmUpExcludesReviewFallbackItems() throws {
        let pack = try frenchPack()
        let current = try XCTUnwrap(pack.lesson(id: "fr-home-foundation"))
        let t1 = Date(timeIntervalSince1970: 1_700_000_000)

        // An item resolved to the "review" fallback step is quarantined by
        // projection and never reschedules FSRS — asking it in the warm-up
        // would be dead weight.
        let fallback = warmUpItem(
            pack: pack, lessonId: "fr-identity-foundation",
            evidenceKey: "fr-identity-foundation-meaning", dueAt: t1,
            stepId: "review")
        let normal = warmUpItem(
            pack: pack, lessonId: "fr-identity-foundation",
            evidenceKey: "fr-identity-foundation-notice",
            dueAt: t1.addingTimeInterval(100))

        let selected = RecallWarmUp.select(
            due: [fallback, normal], currentLesson: current, pack: pack)

        XCTAssertEqual(selected.map(\.evidenceKey), ["fr-identity-foundation-notice"])
    }

    // MARK: Warm-up attempts vs. the Review tab path

    func testWarmUpAttemptReschedulesFsrsIdenticallyToReview() throws {
        let pack = try frenchPack()
        let lesson = try XCTUnwrap(pack.lesson(id: "fr-identity-foundation"))
        let step = try XCTUnwrap(lesson.steps.first {
            pack.activity(id: $0.activityId)?.evidenceKey == "fr-identity-foundation-meaning"
        })
        let activity = try XCTUnwrap(pack.activity(id: step.activityId))
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        let item = ReviewItem(
            evidenceKey: try XCTUnwrap(activity.evidenceKey),
            packId: pack.id,
            packVersion: pack.version,
            courseTitle: pack.title,
            lessonId: lesson.id,
            lessonTitle: lesson.title,
            lessonRevision: lesson.revision,
            stepId: step.id,
            activityId: activity.id,
            activityRevision: activity.revision,
            prompt: "Recall prompt",
            answerText: "Answer",
            feedback: "Feedback",
            dueAt: at)

        for verdict in [ReviewVerdict.tryAgain, ReviewVerdict.exact] {
            // makeAttempt must be field-for-field what recordVerdict builds
            // inline; only the generated id differs (random in both paths),
            // so mirror it before comparing.
            let warmUpAttempt = item.makeAttempt(verdict: verdict, at: at)
            let reviewPathAttempt = ActivityAttempt(
                id: "review-path-\(verdict.rawValue)",
                packId: item.packId,
                packVersion: item.packVersion,
                lessonId: item.lessonId,
                lessonRevision: item.lessonRevision,
                stepId: item.stepId,
                activityId: item.activityId,
                activityRevision: item.activityRevision,
                evidenceKey: item.evidenceKey,
                response: verdict.response,
                assistance: [],
                evaluation: AttemptEvaluation(
                    outcome: verdict.outcome,
                    independent: verdict.independent,
                    feedback: ""),
                at: at)
            var mirrored = reviewPathAttempt
            mirrored.id = warmUpAttempt.id
            XCTAssertEqual(mirrored, warmUpAttempt)

            // Recording through either path reschedules FSRS identically.
            let warmUpStore = try makeStore(
                named: "warmup-fsrs-\(verdict.rawValue).sqlite")
            let reviewStore = try makeStore(
                named: "review-fsrs-\(verdict.rawValue).sqlite")
            try warmUpStore.record(.attempt(warmUpAttempt))
            try reviewStore.record(.attempt(reviewPathAttempt))

            let warmUpRecord = try XCTUnwrap(
                warmUpStore.project(pack: pack).evidence[item.evidenceKey])
            let reviewRecord = try XCTUnwrap(
                reviewStore.project(pack: pack).evidence[item.evidenceKey])
            XCTAssertEqual(warmUpRecord.fsrs, reviewRecord.fsrs)

            XCTAssertEqual(warmUpRecord.fsrs.reps, 1)
            XCTAssertEqual(
                warmUpRecord.fsrs.lastGrade,
                Fsrs.grade(for: warmUpAttempt).rawValue)
            XCTAssertEqual(
                warmUpRecord.fsrs.dueAt,
                at.addingTimeInterval(
                    Double(warmUpRecord.fsrs.intervalDays) * 86_400))
            XCTAssertEqual(
                warmUpRecord.fsrs.lastGrade,
                verdict == .tryAgain
                    ? FsrsGrade.again.rawValue : FsrsGrade.good.rawValue)
        }
    }

    // MARK: Checkpoint semantics

    func testWarmUpLeavesCheckpointSemanticsIntact() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let lesson = try XCTUnwrap(pack.lesson(id: "fr-home-foundation"))
        let at = Date(timeIntervalSince1970: 1_700_000_000)

        // The current lesson's checkpoint as boot leaves it when the
        // briefing was opened and no step was attempted yet.
        let entryCheckpoint = LessonCheckpoint(
            packId: pack.id, lessonId: lesson.id, revision: lesson.revision,
            stepId: lesson.entryStepId, selectedBranches: [:],
            assistance: [], draft: nil, at: at)
        try store.saveCheckpoint(entryCheckpoint)

        // Warm-up attempts land in other lessons only — the capture of
        // earlier ideas, never the lesson being opened.
        let warmUp: [(lessonId: String, key: String)] = [
            ("fr-identity-foundation", "fr-identity-foundation-meaning"),
            ("fr-numbers-foundation", "fr-numbers-foundation-cloze"),
        ]
        for (i, entry) in warmUp.enumerated() {
            try store.record(.attempt(ActivityAttempt(
                id: "warm-up-\(entry.key)",
                packId: pack.id,
                packVersion: pack.version,
                lessonId: entry.lessonId,
                lessonRevision: 1,
                stepId: "warm-up-step",
                activityId: "warm-up-activity",
                activityRevision: 1,
                evidenceKey: entry.key,
                response: .selfRating(.good),
                assistance: [],
                evaluation: AttemptEvaluation(
                    outcome: .correct, independent: true, feedback: ""),
                at: at.addingTimeInterval(Double(i) * 10))))
        }

        // The checkpoint is byte-for-byte untouched.
        let loaded = try XCTUnwrap(
            store.loadCheckpoint(packId: pack.id, lessonId: lesson.id))
        XCTAssertEqual(loaded, entryCheckpoint)

        // Boot's fresh-start discriminator: no attempt belongs to the
        // current lesson, so `hasLessonAttempt` stays false and the
        // briefing keeps being offered (never a forced mid-lesson resume).
        let events = try store.learningEvents(packId: pack.id)
        XCTAssertFalse(attemptedLessonIds(events).contains(lesson.id))

        // resumeSession still resumes the entry step with nothing
        // completed — warm-up history for other lessons changes nothing.
        let resume = resumeSession(
            pack: pack, checkpoint: entryCheckpoint,
            events: events, quarantined: [])
        guard case .resume(let session) = resume else {
            return XCTFail("warm-up attempts must not disturb the resume path")
        }
        XCTAssertEqual(session.activeStepId, lesson.entryStepId)
        XCTAssertTrue(session.completedStepIds.isEmpty)

        // The warm-up evidence recorded — but nothing for the current
        // lesson's evidence set.
        let progress = try store.project(pack: pack)
        for (_, key) in warmUp {
            XCTAssertNotNil(progress.evidence[key])
        }
        XCTAssertNil(progress.evidence["fr-home-foundation-meet"])
    }
}