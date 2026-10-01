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

    func testKnownMarkCanSkipAndRestoreNextLessonWithoutPracticeEvidence() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let first = try XCTUnwrap(pack.lessons.first)
        let second = try XCTUnwrap(pack.lessons.dropFirst().first)

        try store.setLessonKnown(pack: pack, lessonId: first.id, known: true)
        var progress = try store.project(pack: pack)
        XCTAssertTrue(progress.knownLessons.contains(first.id))
        XCTAssertTrue(progress.participationCompleted.isEmpty)
        XCTAssertTrue(progress.evidence.isEmpty)
        XCTAssertEqual(
            pack.firstUncompletedLesson(completed: progress.finishedLessons)?.lesson.id,
            second.id)

        try store.setLessonKnown(pack: pack, lessonId: first.id, known: false)
        progress = try store.project(pack: pack)
        XCTAssertFalse(progress.knownLessons.contains(first.id))
        XCTAssertEqual(
            pack.firstUncompletedLesson(completed: progress.finishedLessons)?.lesson.id,
            first.id)
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
        case .checkpointAttempt:
            version = 2; type = "checkpoint-attempt"
            lessonId = nil; activityId = nil; evidenceKey = nil
        case .openTaskAttempt(let e):
            version = 2; type = "open-task-attempt"
            lessonId = e.lessonId; activityId = e.activityId; evidenceKey = nil
        case .dialogueTurn(let e):
            version = 2; type = "dialogue-turn"
            lessonId = e.hostLessonId; activityId = nil; evidenceKey = nil
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

    // MARK: Mission "I tried it" marker (kv-backed reflection, not evidence)

    /// The marker's key format, shared by the recap card and these tests:
    /// `condisco.mission-tried:<packId>:<lessonId>`.
    private func missionTriedKey(pack: CoursePack, lessonId: String) -> String {
        "condisco.mission-tried:\(pack.id):\(lessonId)"
    }

    func testMissionTriedMarkerRoundTrip() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let lesson = try XCTUnwrap(pack.lesson(id: "fr-home-foundation"))
        let key = missionTriedKey(pack: pack, lessonId: lesson.id)

        try store.kvSet(key, "1")
        XCTAssertEqual(try store.kvGet(key), "1")
    }

    func testMissionTriedMarkerMissingKeyIsUntried() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let lesson = try XCTUnwrap(pack.lesson(id: "fr-home-foundation"))
        let key = missionTriedKey(pack: pack, lessonId: lesson.id)

        // No row at all: untried.
        XCTAssertNil(try store.kvGet(key))
    }

    func testMissionTriedMarkerEmptyValueIsUntried() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let lesson = try XCTUnwrap(pack.lesson(id: "fr-home-foundation"))
        let key = missionTriedKey(pack: pack, lessonId: lesson.id)

        // An empty row is not the literal "1" the marker reads as tried.
        try store.kvSet(key, "")
        XCTAssertEqual(try store.kvGet(key), "")
        XCTAssertNotEqual(try store.kvGet(key), "1")
    }

    func testMissionTriedMarkerUnmarkViaDelete() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let lesson = try XCTUnwrap(pack.lesson(id: "fr-home-foundation"))
        let key = missionTriedKey(pack: pack, lessonId: lesson.id)

        try store.kvSet(key, "1")
        try store.kvDelete(key)
        XCTAssertNil(try store.kvGet(key), "un-marking must return to untried")
    }

    /// Using the marker must not touch the phrasebook: no schema drift, no
    /// phantom saved phrases.
    func testMissionTriedMarkerLeavesSavedPhrasesUntouched() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let lesson = try XCTUnwrap(pack.lesson(id: "fr-home-foundation"))
        let key = missionTriedKey(pack: pack, lessonId: lesson.id)

        XCTAssertTrue(try store.savedPhrases().isEmpty)
        try store.kvSet(key, "1")
        try store.kvDelete(key)
        try store.kvSet(key, "1")

        let phrases = try store.savedPhrases()
        XCTAssertTrue(
            phrases.isEmpty,
            "the marker lives in kv only; savedPhrases() must be unchanged")
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
            // Record exactly as production does: a ReviewItem resolved from
            // the earlier lesson's authored step (like ReviewCatalog.makeItem)
            // written via ReviewItem.makeAttempt. Synthetic step/activity ids
            // would be quarantined by projection — the verdict would then be
            // silently discarded and never reschedule FSRS.
            let at = at.addingTimeInterval(Double(i) * 10)
            let earlierLesson = try XCTUnwrap(pack.lesson(id: entry.lessonId))
            let step = try XCTUnwrap(earlierLesson.steps.first {
                pack.activity(id: $0.activityId)?.evidenceKey == entry.key
            })
            let activity = try XCTUnwrap(pack.activity(id: step.activityId))
            let item = ReviewItem(
                evidenceKey: entry.key,
                packId: pack.id,
                packVersion: pack.version,
                courseTitle: pack.title,
                lessonId: earlierLesson.id,
                lessonTitle: earlierLesson.title,
                lessonRevision: earlierLesson.revision,
                stepId: step.id,
                activityId: activity.id,
                activityRevision: activity.revision,
                prompt: "Warm-up prompt",
                answerText: "Warm-up answer",
                feedback: "Warm-up feedback",
                dueAt: at)
            try store.record(.attempt(item.makeAttempt(verdict: .exact, at: at)))
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

        // The warm-up attempts were accepted by projection — nothing
        // quarantined and silently discarded, so the verdicts genuinely
        // reschedule FSRS — and their evidence landed under the earlier
        // lessons' real evidence keys, while the current lesson's evidence
        // set stays untouched.
        let progress = try store.project(pack: pack)
        XCTAssertTrue(progress.quarantined.isEmpty,
                      "warm-up attempts must survive projection, not be discarded")
        for (_, key) in warmUp {
            XCTAssertNotNil(progress.evidence[key],
                            "warm-up must surface evidence for \(key)")
        }
        let currentLessonKeys = Set(lesson.steps.compactMap {
            pack.activity(id: $0.activityId)?.evidenceKey
        })
        XCTAssertTrue(
            Set(progress.evidence.keys).isDisjoint(with: currentLessonKeys),
            "warm-up must never produce evidence for the lesson being opened")
        XCTAssertNil(progress.evidence["fr-home-foundation-meet"])
    }
}

// MARK: - Pair practice card (P3.4)

/// Local pair role-play card prototype: dialogue turn extraction and the
/// share caption. Purely local — the caption must stay course content and
/// never leak a pack, lesson, or device identifier.
final class PairPracticeCardTests: XCTestCase {

    private func frenchPack() throws -> CoursePack {
        try XCTUnwrap(
            PackLoader.loadPacks().first { $0.language == .french })
    }

    /// The dialogue turns for a real conversation lesson come back in
    /// authored order with both speakers — the shopkeeper opens, the
    /// learner ("Toi") answers, the shopkeeper closes.
    func testDialogueTurnsReturnOrderedTwoSpeakerTurnsForConversationLesson() throws {
        let pack = try frenchPack()
        let lesson = try XCTUnwrap(pack.lesson(id: "fr-requests-foundation"))
        XCTAssertEqual(lesson.family, .conversation)

        let turns = dialogueTurns(for: lesson, pack: pack)
        XCTAssertFalse(turns.isEmpty, "conversation lesson must carry dialogue")

        XCTAssertEqual(turns.count, 3)
        XCTAssertEqual(turns.map(\.speaker), ["Vendeuse", "Toi", "Vendeuse"])
        XCTAssertEqual(Set(turns.map(\.speaker)).count, 2,
                       "expected a two-speaker dialogue")
        XCTAssertEqual(turns[0].text, "Bonjour ! Je peux vous aider ?")
        XCTAssertEqual(turns[0].meaning, "Hello! Can I help you?")
        XCTAssertEqual(turns[1].text, "Je peux prendre un café, s'il vous plaît ?")
        XCTAssertEqual(turns[2].text, "Bien sûr. Autre chose ?")
    }

    /// Non-dialogue lessons return no turns, so the card degrades to its
    /// empty state instead of rendering garbage.
    func testDialogueTurnsEmptyForStoryLesson() throws {
        let pack = try frenchPack()
        let lesson = try XCTUnwrap(pack.lesson(id: "fr-home-foundation"))
        XCTAssertNotEqual(lesson.family, .conversation)
        XCTAssertTrue(dialogueTurns(for: lesson, pack: pack).isEmpty)
    }

    /// The shared card's caption is built by `pairCardCaption`, which is
    /// what `PairPracticeView.makeSharedCard` passes into `SharedCard` as
    /// the SharePreview caption. Assert it carries the course content and
    /// nothing identifiable: no pack id, lesson id, `fr-`-prefixed content
    /// key, or UUID-shaped string. (The card text itself comes from the
    /// same dialogue turns, so this guards the whole share surface.)
    func testPairCardCaptionContainsCourseContentOnly() throws {
        let pack = try frenchPack()
        let lesson = try XCTUnwrap(pack.lesson(id: "fr-requests-foundation"))
        let turns = dialogueTurns(for: lesson, pack: pack)
        let caption = pairCardCaption(
            turns: turns, languageName: pack.language.displayName)

        // Course content is still there.
        XCTAssertTrue(caption.contains("French"))
        XCTAssertTrue(caption.contains("Vendeuse"))
        XCTAssertTrue(caption.contains("Toi"))
        XCTAssertTrue(caption.contains("Bonjour ! Je peux vous aider ?"))
        XCTAssertTrue(caption.contains("Je peux prendre un café, s'il vous plaît ?"))

        // No identifiers of any kind.
        XCTAssertFalse(caption.contains(pack.id))
        XCTAssertFalse(caption.contains(lesson.id))
        XCTAssertFalse(caption.contains("fr-"),
                       "no lesson/activity/stimulus id may leak into the caption")
        XCTAssertNil(
            caption.range(
                of: #"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"#,
                options: .regularExpression),
            "no UUID (device id) may leak into the caption")
    }
}

// MARK: - Upgrade drills (P4.1): old state upgrades cleanly
//
// The roadmap's migration constraint is "preserve verbalibera.sqlite,
// existing event IDs, pack/lesson/step IDs, and legacy UserDefaults keys;
// any migration requires an explicit upgrade test." These drills simulate
// the previous build's on-disk state — a database written before the
// saved-phrase schema columns existed, v1 practice events, v2 events
// carrying an old pack version, and the legacy UserDefaults keys — and
// assert the store/app migrates in place with zero data loss.

extension LearningStoreTests {

    // MARK: Legacy database shape + rows

    /// Inserts one event row into an open `Database` with the modern column
    /// list. Used to seed rows the way the production `record` path writes
    /// them, without going through `record`.
    private func insertEventRow(
        db: Database, id: String, packId: String, version: Int, type: String,
        lessonId: String?, activityId: String?, evidenceKey: String?,
        atMs: Int64, payload: String
    ) throws {
        try db.execute(
            """
            INSERT INTO events(id, pack_id, event_version, type, lesson_id,
                               activity_id, evidence_key, at_ms, payload)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
            """,
            bind: {
                try $0.bindText(1, id)
                try $0.bindText(2, packId)
                try $0.bindInt64(3, Int64(version))
                try $0.bindText(4, type)
                try $0.bindText(5, lessonId)
                try $0.bindText(6, activityId)
                try $0.bindText(7, evidenceKey)
                try $0.bindInt64(8, atMs)
                try $0.bindText(9, payload)
            })
    }

    /// The exercise ids a legacy-success lesson requires, from the live
    /// pack — the same ids the projection's legacy-credit check reads.
    private func legacyExerciseIds(
        _ lessonId: String, in pack: CoursePack
    ) throws -> [String] {
        let lesson = try XCTUnwrap(pack.lesson(id: lessonId))
        guard case .legacySuccess(let ids) = lesson.completionPolicy,
              !ids.isEmpty
        else {
            throw XCTSkip("\(lessonId) must be a legacy-success lesson")
        }
        return ids
    }

    /// Creates a `verbalibera.sqlite`-shaped file exactly as a build from
    /// before the saved-phrase schema drift wrote it: every table the store
    /// knows, but `saved_phrases` WITHOUT `source_pack_id` /
    /// `source_lesson_id` (the only columns `LearningStore.init` migrates
    /// today), seeded with that era's rows — a full set of v1 practice
    /// events granting fr-identity-foundation, a revealed v1 event that must
    /// NOT grant credit, one v2 attempt under an old pack version, a
    /// checkpoint, an old-shape saved phrase, and the kv device id.
    private func seedLegacyBuildDatabase(at url: URL) throws {
        let db = try Database(path: url.path)
        try db.exec(
            """
            CREATE TABLE events(
              id TEXT PRIMARY KEY,
              pack_id TEXT NOT NULL,
              event_version INTEGER NOT NULL,
              type TEXT NOT NULL,
              lesson_id TEXT,
              activity_id TEXT,
              evidence_key TEXT,
              at_ms INTEGER NOT NULL,
              payload TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_events_pack_time ON events(pack_id, at_ms, id);
            CREATE TABLE checkpoints(
              pack_id TEXT NOT NULL,
              lesson_id TEXT NOT NULL,
              payload TEXT NOT NULL,
              updated_at_ms INTEGER NOT NULL,
              PRIMARY KEY (pack_id, lesson_id)
            );
            CREATE TABLE checkpoint_tombstones(
              pack_id TEXT NOT NULL,
              lesson_id TEXT NOT NULL,
              deleted_at_ms INTEGER NOT NULL,
              PRIMARY KEY (pack_id, lesson_id)
            );
            CREATE TABLE listen_state(
              track_id TEXT PRIMARY KEY,
              position_seconds REAL NOT NULL DEFAULT 0,
              listened_at_ms INTEGER,
              updated_at_ms INTEGER NOT NULL
            );
            CREATE TABLE kv(
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            );
            CREATE TABLE sync_uploads(
              event_id TEXT PRIMARY KEY,
              uploaded_at_ms INTEGER NOT NULL
            );
            CREATE TABLE saved_phrases(
              id TEXT PRIMARY KEY,
              language_slug TEXT NOT NULL,
              language_name TEXT NOT NULL,
              target TEXT NOT NULL,
              meaning TEXT NOT NULL,
              source TEXT NOT NULL DEFAULT '',
              saved_at_ms INTEGER NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_saved_phrases_lang
              ON saved_phrases(language_slug, saved_at_ms);
            CREATE TABLE saved_phrase_tombstones(
              id TEXT PRIMARY KEY,
              deleted_at_ms INTEGER NOT NULL
            );
            """)

        let pack = try frenchPack()
        let lesson = try XCTUnwrap(pack.lesson(id: "fr-home-foundation"))
        let at = Date(timeIntervalSince1970: 1_700_000_000)

        // v1 practice events (event_version 1, type "practice") — the exact
        // rows a previous build's writer produced. All correct + unrevealed
        // so they hand the lesson its legacy completion credit.
        let legacyIds = try legacyExerciseIds("fr-identity-foundation", in: pack)
        for (i, exerciseId) in legacyIds.enumerated() {
            let payload = try String(
                data: JSONEncoder().encode(LearningEvent.practiceV1(
                    PracticeEventV1(
                        id: "legacy-v1-\(i)",
                        packId: pack.id,
                        version: "0.9.0",
                        exerciseId: exerciseId,
                        at: at.addingTimeInterval(Double(i)),
                        correct: true,
                        revealed: false))),
                encoding: .utf8)!
            try insertEventRow(
                db: db, id: "legacy-v1-\(i)", packId: pack.id,
                version: 1, type: "practice",
                lessonId: nil, activityId: nil, evidenceKey: nil,
                atMs: millis(at.addingTimeInterval(Double(i))),
                payload: payload)
        }
        // A correct-but-revealed v1 event must never earn credit — pinned so
        // the tolerance of the upgrade path never widens into data forgery.
        let revealedPayload = try String(
            data: JSONEncoder().encode(LearningEvent.practiceV1(
                PracticeEventV1(
                    id: "legacy-v1-revealed",
                    packId: pack.id,
                    version: "0.9.0",
                    exerciseId: "fr-people-foundation-meet",
                    at: at.addingTimeInterval(600),
                    correct: true,
                    revealed: true))),
            encoding: .utf8)!
        try insertEventRow(
            db: db, id: "legacy-v1-revealed", packId: pack.id,
            version: 1, type: "practice",
            lessonId: nil, activityId: nil, evidenceKey: nil,
            atMs: millis(at.addingTimeInterval(600)),
            payload: revealedPayload)

        // A v2 attempt carrying the previous release's pack version.
        let attempt = try makeAttempt(id: "legacy-v2-1", pack: pack, at: at)
        var oldVersionAttempt = attempt
        oldVersionAttempt.packVersion = "0.9.0"
        try insertEventRow(
            db: db, id: oldVersionAttempt.id, packId: pack.id,
            version: 2, type: "attempt",
            lessonId: oldVersionAttempt.lessonId,
            activityId: oldVersionAttempt.activityId,
            evidenceKey: oldVersionAttempt.evidenceKey,
            atMs: millis(at),
            payload: try String(
                data: JSONEncoder().encode(LearningEvent.attempt(oldVersionAttempt)),
                encoding: .utf8)!)

        // Checkpoint, old-shape saved phrase, and the kv device id.
        let checkpoint = LessonCheckpoint(
            packId: pack.id, lessonId: lesson.id, revision: lesson.revision,
            stepId: "fr-home-foundation-step-rb4",
            selectedBranches: ["fr-home-foundation-step-rb1": "a"],
            assistance: [.translation], draft: .text("Le chat"), at: at)
        let checkpointMs = millis(checkpoint.at)
        try db.execute(
            """
            INSERT INTO checkpoints(pack_id, lesson_id, payload, updated_at_ms)
            VALUES (?, ?, ?, ?);
            """,
            bind: {
                try $0.bindText(1, checkpoint.packId)
                try $0.bindText(2, checkpoint.lessonId)
                try $0.bindText(
                    3, String(data: JSONEncoder().encode(checkpoint), encoding: .utf8)!)
                try $0.bindInt64(4, checkpointMs)
            })
        let phrase = SavedPhrase(
            id: LearningStore.savedPhraseId(
                languageSlug: "french", target: "Le chat", meaning: "The cat"),
            languageSlug: "french", languageName: "French",
            target: "Le chat", meaning: "The cat",
            source: "previous build", savedAt: at)
        let phraseMs = millis(phrase.savedAt)
        try db.execute(
            """
            INSERT INTO saved_phrases(
              id, language_slug, language_name, target, meaning, source, saved_at_ms)
            VALUES (?, ?, ?, ?, ?, ?, ?);
            """,
            bind: {
                try $0.bindText(1, phrase.id)
                try $0.bindText(2, phrase.languageSlug)
                try $0.bindText(3, phrase.languageName)
                try $0.bindText(4, phrase.target)
                try $0.bindText(5, phrase.meaning)
                try $0.bindText(6, phrase.source)
                try $0.bindInt64(7, phraseMs)
            })
        try db.execute(
            "INSERT INTO kv(key, value) VALUES (?, ?);",
            bind: {
                try $0.bindText(1, "device_id")
                try $0.bindText(2, "legacy-device-id")
            })
    }

    // MARK: Drills

    /// The previous build's database opens in place with zero data loss:
    /// the schema migration adds the missing saved-phrase columns, every
    /// seeded row (v1 practice events, an old-pack-version attempt, the
    /// checkpoint, the old-shape phrase, the device id) is still readable,
    /// the v1 events still grant their lesson's legacy credit, and
    /// post-upgrade writes round-trip. Would catch a regression where the
    /// migration drops or mangles pre-existing rows.
    func testLegacyBuildDatabaseUpgradesInPlaceWithoutDataLoss() throws {
        let url = tempDir.appendingPathComponent("legacy.sqlite")
        try seedLegacyBuildDatabase(at: url)

        // Reopen runs the store's migration (ALTER TABLE saved_phrases).
        let store = try LearningStore(path: url.path)
        let pack = try frenchPack()

        // Old-shape saved phrase survives; the migrated columns exist and
        // read back empty (never NULL-crashed, never dropped).
        let phrases = try store.savedPhrases()
        XCTAssertEqual(phrases.count, 1)
        XCTAssertEqual(phrases[0].target, "Le chat")
        XCTAssertEqual(phrases[0].source, "previous build")
        XCTAssertEqual(phrases[0].sourcePackId, "")
        XCTAssertEqual(phrases[0].sourceLessonId, "")

        // The checkpoint round-trips unchanged.
        let checkpoint = try XCTUnwrap(
            store.loadCheckpoint(packId: pack.id, lessonId: "fr-home-foundation"))
        XCTAssertEqual(checkpoint.draft, .text("Le chat"))

        // The kv device id survives the upgrade — identity is preserved.
        XCTAssertEqual(try store.deviceId(), "legacy-device-id")

        // v1 practice events still decode and hand out legacy credit; the
        // revealed event does not; the old-pack-version attempt still
        // lands in evidence; nothing is quarantined.
        let progress = try store.project(pack: pack)
        XCTAssertTrue(
            progress.legacyCredits.contains("fr-identity-foundation"),
            "v1 success history must carry its lesson's legacy credit")
        XCTAssertFalse(
            progress.legacyCredits.contains("fr-people-foundation"),
            "a revealed v1 success must not earn credit")
        XCTAssertEqual(progress.evidence.count, 1)
        XCTAssertTrue(progress.quarantined.isEmpty)

        // The event ids from the old build are preserved exactly.
        let events = try store.learningEvents(packId: pack.id)
        let legacyIds = try legacyExerciseIds("fr-identity-foundation", in: pack)
        XCTAssertEqual(events.count, legacyIds.count + 2)

        // Post-upgrade writes work: a fresh phrase with source ids lands.
        let fresh = SavedPhrase(
            id: LearningStore.savedPhraseId(
                languageSlug: "french", target: "Un chien", meaning: "A dog"),
            languageSlug: "french", languageName: "French",
            target: "Un chien", meaning: "A dog",
            source: "fr-home-foundation-act-rb9",
            sourcePackId: pack.id, sourceLessonId: "fr-home-foundation",
            savedAt: Date())
        try store.savePhrase(fresh)
        let all = try store.savedPhrases()
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(
            all.first { $0.target == "Un chien" }?.sourcePackId, pack.id)
        XCTAssertEqual(
            all.first { $0.target == "Un chien" }?.sourceLessonId,
            "fr-home-foundation")
    }

    /// Old pack-version data flowing through the *current* write path too:
    /// v1 practice events recorded via `record` migrate into legacy credit
    /// without quarantine, and v2 attempts carrying a previous release's
    /// pack version still project — the projection decides validity from
    /// lesson/activity revisions, never from `packVersion`, so history made
    /// against an older build keeps working.
    func testOldPackVersionEventsProjectWithoutLossOrQuarantine() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        let legacyIds = try legacyExerciseIds("fr-identity-foundation", in: pack)
        for (i, exerciseId) in legacyIds.enumerated() {
            try store.record(.practiceV1(PracticeEventV1(
                id: "upgrade-v1-\(i)", packId: pack.id, version: "0.9.0",
                exerciseId: exerciseId,
                at: base.addingTimeInterval(Double(i)),
                correct: true, revealed: false)))
        }
        try store.record(.practiceV1(PracticeEventV1(
            id: "upgrade-v1-revealed", packId: pack.id, version: "0.9.0",
            exerciseId: "fr-people-foundation-meet",
            at: base.addingTimeInterval(600), correct: true, revealed: true)))

        var old = try makeAttempt(id: "upgrade-v2-1", pack: pack, at: base)
        old.packVersion = "0.9.0"
        try store.record(.attempt(old))

        let progress = try store.project(pack: pack)
        XCTAssertTrue(progress.legacyCredits.contains("fr-identity-foundation"))
        XCTAssertFalse(progress.legacyCredits.contains("fr-people-foundation"))
        XCTAssertEqual(progress.evidence.count, 1,
                       "the old-pack-version attempt must still project")
        XCTAssertTrue(progress.quarantined.isEmpty,
                      "old pack versions must not quarantine")

        // The v1 rows read back with their original ids and version tag.
        let events = try store.learningEvents(packId: pack.id)
        XCTAssertEqual(events.count, legacyIds.count + 2)
        guard let firstEvent = events.first,
              case .practiceV1(let storedV1) = firstEvent else {
            return XCTFail("expected a practiceV1 first event")
        }
        XCTAssertEqual(storedV1.version, "0.9.0")
    }

    /// Reopening the same database file — the app's own relaunch path —
    /// preserves every event, checkpoint, saved phrase, listen position,
    /// and the device id: nothing is dropped, reordered, or recreated on a
    /// second open.
    func testReopenPreservesAllRowsAndDeviceIdentity() throws {
        let url = tempDir.appendingPathComponent("reopen.sqlite")
        let store = try LearningStore(path: url.path)
        let pack = try frenchPack()
        let at = Date(timeIntervalSince1970: 1_700_000_000)

        let attempt = try makeAttempt(id: "reopen-1", pack: pack, at: at)
        try store.record(.attempt(attempt))
        let deviceId = try store.deviceId()

        let checkpoint = LessonCheckpoint(
            packId: pack.id, lessonId: "fr-home-foundation",
            revision: pack.lesson(id: "fr-home-foundation")?.revision ?? 1,
            stepId: "fr-home-foundation-step-rb4",
            selectedBranches: [:], assistance: [.translation],
            draft: .text("Le chat"), at: at)
        try store.saveCheckpoint(checkpoint)
        let phrase = SavedPhrase(
            id: LearningStore.savedPhraseId(
                languageSlug: "french", target: "Le chat", meaning: "The cat"),
            languageSlug: "french", languageName: "French",
            target: "Le chat", meaning: "The cat",
            source: "reopen", savedAt: at)
        try store.savePhrase(phrase)
        try store.saveListenPosition(trackId: "reopen-track", seconds: 42, at: at)

        // Relaunch: a brand-new store over the same file.
        let reopened = try LearningStore(path: url.path)
        XCTAssertEqual(try reopened.deviceId(), deviceId)
        XCTAssertEqual(try reopened.learningEvents(packId: pack.id).count, 1)
        XCTAssertEqual(try reopened.loadCheckpoint(
            packId: pack.id, lessonId: "fr-home-foundation"), checkpoint)
        XCTAssertEqual(try reopened.savedPhrases().count, 1)
        XCTAssertEqual(try reopened.listenPosition(trackId: "reopen-track"), 42)
        XCTAssertEqual(
            try reopened.project(pack: pack).evidence.count, 1)
    }
}

// MARK: - Upgrade drill: legacy UserDefaults keys (P4.1)
//
// Settings lived in UserDefaults before this build and still do: Home's
// focus language, the per-language TTS voice, the placement badge, review
// reminders, and the sign-in display name all read stable legacy keys. The
// roadmap says to preserve legacy UserDefaults keys; these tests pin the
// exact key strings and the round trip through the production stores, so a
// future migration that renames or drops a key becomes a visible,
// deliberate change instead of a silent data loss.

@MainActor
final class LegacyUserDefaultsMigrationTests: XCTestCase {

    /// Every legacy key the app reads today, in production key format.
    private static let legacyKeys = [
        "condisco.focusLanguage",
        "condisco.voice.fr-FR",
        "condisco.placement.fr-foundations",
        "condisco.reminders.enabled",
        "condisco.reminders.minutes",
        "verbalibera.appleDisplayName",
    ]

    private var hadKey: [String: Bool] = [:]
    private var oldValues: [String: Any] = [:]

    override func setUp() {
        super.setUp()
        for key in Self.legacyKeys {
            if let value = UserDefaults.standard.object(forKey: key) {
                hadKey[key] = true
                oldValues[key] = value
            } else {
                hadKey[key] = false
            }
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    override func tearDown() {
        for key in Self.legacyKeys {
            if hadKey[key] == true, let value = oldValues[key] {
                UserDefaults.standard.set(value, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        hadKey = [:]
        oldValues = [:]
        super.tearDown()
    }

    /// HomeView and ReviewView read the focus language exactly this way:
    /// `UserDefaults.standard.string(forKey: "condisco.focusLanguage")`.
    /// A stored choice from the previous build must read back unchanged.
    func testFocusLanguageKeyReadExactlyAsHomeReadsIt() {
        UserDefaults.standard.set("italian", forKey: "condisco.focusLanguage")
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: "condisco.focusLanguage"),
            "italian")
    }

    /// The per-language TTS voice key (`condisco.voice.<bcp47>`) round-trips
    /// through the production store: a previous build's stored voice id
    /// survives, and write/clear keep the same key.
    func testLegacyVoiceKeyRoundTripsThroughVoiceStore() {
        UserDefaults.standard.set(
            "com.apple.voice.compact.fr-FR.premium",
            forKey: "condisco.voice.fr-FR")
        XCTAssertEqual(
            VoiceStore.voiceIdentifier(for: "fr-FR"),
            "com.apple.voice.compact.fr-FR.premium")

        VoiceStore.setVoice(
            identifier: "com.apple.voice.compact.fr-FR.premium-2",
            for: "fr-FR")
        XCTAssertEqual(
            VoiceStore.voiceIdentifier(for: "fr-FR"),
            "com.apple.voice.compact.fr-FR.premium-2")
        VoiceStore.setVoice(identifier: nil, for: "fr-FR")
        XCTAssertNil(VoiceStore.voiceIdentifier(for: "fr-FR"))
    }

    /// The placement badge key (`condisco.placement.<packId>`) round-trips
    /// through `PlacementStore`: a previous build's recommendation survives
    /// and a new save stays on the same key.
    func testLegacyPlacementKeyRoundTripsThroughPlacementStore() {
        UserDefaults.standard.set(
            "fr-home-foundation", forKey: "condisco.placement.fr-foundations")
        XCTAssertEqual(
            PlacementStore.recommendedLessonId(packId: "fr-foundations"),
            "fr-home-foundation")

        PlacementStore.save(
            packId: "fr-foundations", lessonId: "fr-identity-foundation")
        XCTAssertEqual(
            PlacementStore.recommendedLessonId(packId: "fr-foundations"),
            "fr-identity-foundation")
    }

    /// Review reminders read their enabled flag and time at init from the
    /// legacy keys: a previous build's schedule setting survives untouched.
    func testLegacyReminderKeysReadAtInit() {
        UserDefaults.standard.set(true, forKey: "condisco.reminders.enabled")
        UserDefaults.standard.set(585, forKey: "condisco.reminders.minutes")

        let reminders = ReviewReminders()
        XCTAssertTrue(reminders.isEnabled)
        XCTAssertEqual(reminders.minutes, 585)
    }

    /// `AuthState` reads the sign-in display name from the legacy key at
    /// init; with no keychain user it must not touch the network. The
    /// keychain service itself (`com.sleuthysloth.verbalibera`) is
    /// unchanged by inspection — only the UserDefaults half is drivable
    /// without a real Apple credential.
    func testLegacySignInDisplayNameKeySurvives() {
        UserDefaults.standard.set(
            "Legacy Learner", forKey: "verbalibera.appleDisplayName")

        let auth = AuthState()
        XCTAssertEqual(auth.displayName, "Legacy Learner")
        XCTAssertFalse(auth.isSignedIn)
    }
}

// MARK: - Malformed-pack recovery: PackLoader level (P4.1)
//
// The decode-layer guards in `MalformedContentTests` prove a truncated or
// mis-typed pack is rejected safely. These drive the loader itself against
// a synthetic content tree with corrupted files, pinning the recovery
// contract from the roadmap: "recover from one malformed bundled pack
// without hiding the other four. Return a visible, nonfatal content error
// for that course, keep local progress untouched."

final class PackLoaderRecoveryTests: XCTestCase {

    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("condisco-loader-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }
        tempRoot = nil
    }

    /// Copies the five real bundled packs into a synthetic content root,
    /// replacing the named ones with a mid-document truncated payload —
    /// the exact shape a cut-off bundle file takes on disk.
    private func makeContentRoot(corrupting corrupt: Set<String>) throws -> URL {
        guard let content = PackLoader.contentDirectory() else {
            throw XCTSkip("bundled Content tree unavailable in this test host")
        }
        let sourcePacks = content.appendingPathComponent("packs", isDirectory: true)
        let packsDir = tempRoot.appendingPathComponent("packs", isDirectory: true)
        try FileManager.default.createDirectory(
            at: packsDir, withIntermediateDirectories: true)
        let broken = Data(#"{"schemaVersion":2,"id":"fre"#.utf8)
        for name in PackLoader.packFilenames {
            let dest = packsDir
                .appendingPathComponent(name).appendingPathExtension("json")
            if corrupt.contains(name) {
                try broken.write(to: dest)
            } else {
                let source = sourcePacks
                    .appendingPathComponent(name).appendingPathExtension("json")
                try Data(contentsOf: source).write(to: dest)
            }
        }
        return tempRoot
    }

    /// One malformed bundle file (the first in pack order) is skipped with
    /// no crash, and the other four real packs still load and validate —
    /// the "one malformed bundled pack cannot disable every course" gate.
    func testCorruptedFirstPackSkippedOthersStillLoad() throws {
        let root = try makeContentRoot(corrupting: ["french"])

        let packs = try PackLoader.loadPacks(from: root)
        XCTAssertEqual(packs.count, 4)
        XCTAssertFalse(
            packs.contains { $0.language == .french },
            "the corrupted pack must be skipped, not loaded")
        for pack in packs {
            XCTAssertNoThrow(try PackValidator.validate(pack), pack.id)
        }
    }

    /// Same recovery when the corrupted file sits mid-list: the loader
    /// continues past the bad pack and the packs before and after it both
    /// load.
    func testCorruptedMiddlePackSkippedOthersStillLoad() throws {
        let root = try makeContentRoot(corrupting: ["italian"])

        let packs = try PackLoader.loadPacks(from: root)
        XCTAssertEqual(packs.count, 4)
        XCTAssertFalse(packs.contains { $0.language == .italian })
        XCTAssertTrue(packs.contains { $0.language == .french })
        XCTAssertTrue(packs.contains { $0.language == .spanish })
    }

    /// A bundle where every pack is corrupted throws ONE typed, actionable
    /// error naming the failing files — never a crash and never a silent
    /// empty course list.
    func testFullyCorruptedBundleThrowsActionableErrorNamingFiles() throws {
        let root = try makeContentRoot(corrupting: Set(PackLoader.packFilenames))

        XCTAssertThrowsError(try PackLoader.loadPacks(from: root)) { error in
            guard let loadError = error as? PackLoadError else {
                return XCTFail("expected PackLoadError, got \(error)")
            }
            let message = loadError.errorDescription ?? ""
            XCTAssertTrue(
                message.contains("No course packs could be loaded"),
                "error must be actionable: \(message)")
            for name in ["french", "italian", "spanish"] {
                XCTAssertTrue(
                    message.contains("\(name).json"),
                    "error must name the failed file \(name).json: \(message)")
            }
        }
    }
}

// MARK: - Simulator-only performance probes (P4.3)
//
// Wall-clock probes for the roadmap's measurement points that the pure
// core can drive without views or audio: one lesson step transition and
// one review card flip (the pure-core approximation of a card verdict).
// Each probe uses `XCTClockMetric` with no baseline, so it never fails a
// run — it only records numbers, which go into
// `docs/performance-budget.md` §7 as SIMULATOR-ONLY evidence. These are
// not budgets and not device behavior; see the doc for the boundary.

@MainActor
final class SimulatorPerformanceProbeTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("condisco-perf-probes-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
    }

    private func frenchPack() throws -> CoursePack {
        try XCTUnwrap(
            PackLoader.loadPacks().first { $0.language == .french })
    }

    /// A valid attempt on a real step of fr-home-foundation (selection or
    /// cloze), used to seed the review probe.
    private func seedAttempt(
        id: String, pack: CoursePack, stepId: String, at: Date
    ) throws -> ActivityAttempt {
        let lesson = try XCTUnwrap(pack.lesson(id: "fr-home-foundation"))
        let step = try XCTUnwrap(lesson.steps.first { $0.id == stepId })
        let activity = try XCTUnwrap(pack.activity(id: step.activityId))
        let response: AttemptResponse
        switch activity {
        case .selection(let spec):
            response = .selection(ids: spec.acceptedIds)
        case .cloze(let spec):
            response = .cloze(values: Dictionary(
                uniqueKeysWithValues: spec.blanks.map {
                    ($0.key, $0.value.answers.first ?? "")
                }))
        default:
            throw XCTSkip("expected a selection or cloze step")
        }
        return ActivityAttempt(
            id: id, packId: pack.id, packVersion: pack.version,
            lessonId: lesson.id, lessonRevision: lesson.revision,
            stepId: step.id, activityId: activity.id,
            activityRevision: activity.revision,
            evidenceKey: activity.evidenceKey,
            response: response,
            assistance: [],
            evaluation: AttemptEvaluation(
                outcome: .correct, independent: true, feedback: "correct"),
            at: at)
    }

    /// One lesson step transition = submit + evaluate + advance, the pure
    /// engine work behind every step change. Walks the whole linear
    /// fr-home-foundation lesson per iteration; divide the reported total by
    /// the step count for a per-transition figure.
    func testProbeLessonStepTransitionWallClock() throws {
        let pack = try frenchPack()
        let lesson = try XCTUnwrap(pack.lesson(id: "fr-home-foundation"))

        func correctResponse(for activity: Activity) -> AttemptResponse {
            switch activity {
            case .information:
                return .continue
            case .selection(let spec):
                return .selection(ids: spec.acceptedIds)
            case .cloze(let spec):
                return .cloze(values: Dictionary(
                    uniqueKeysWithValues: spec.blanks.map {
                        ($0.key, $0.value.answers.first ?? "")
                    }))
            case .text(let spec):
                return .text(spec.answer.answers.first ?? "")
            default:
                return .continue
            }
        }

        measure(metrics: [XCTClockMetric()]) {
            var session = try! startLesson(pack: pack, lessonId: lesson.id)
            while session.status == .active {
                let step = lesson.steps.first { $0.id == session.activeStepId }!
                let activity = pack.activity(id: step.activityId)!
                session = try! submitResponse(
                    pack: pack, session: session,
                    response: correctResponse(for: activity), assistance: [])
                session = try! advanceLesson(pack: pack, session: session)
            }
        }
    }

    /// One review card flip = resolve the due set + persist one verdict +
    /// re-project, the pure work behind a Review-tab card (audio and UI
    /// excluded). The store is seeded with two due evidence keys so
    /// `loadDue` always has work each iteration.
    func testProbeReviewCardFlipWallClock() throws {
        let store = try LearningStore(
            path: tempDir.appendingPathComponent("probe.sqlite").path)
        let pack = try frenchPack()
        let past = Date(timeIntervalSince1970: 1_700_000_000)
        for (i, stepId) in
            ["fr-home-foundation-step-rb2", "fr-home-foundation-step-rb7"]
            .enumerated() {
            let attempt = try seedAttempt(
                id: "probe-seed-\(i)", pack: pack, stepId: stepId,
                at: past.addingTimeInterval(Double(i)))
            try store.record(.attempt(attempt))
        }
        XCTAssertEqual(try store.dueEvidence(pack: pack).count, 2)
        let now = Date()

        measure(metrics: [XCTClockMetric()]) {
            let due = try! ReviewCatalog.loadDue(
                packs: [pack], store: store, now: now)
            if let item = due.due.first {
                try! store.record(.attempt(item.makeAttempt(verdict: .exact, at: now)))
            }
            _ = try! store.project(pack: pack)
        }
    }
}

// MARK: - Data export (Slice 1.1: complete and legible)
//
// Pins the export format (currently version 1) from the outside: every
// portable item a learner owns must land in the file with identifiers and
// raw timestamps intact, tombstones included, and nothing device-only or
// sensitive may leak in. Tests build a throwaway store, seed it, and decode
// the produced file exactly the way the store's own decoder would.

@MainActor
final class DataExportTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("condisco-export-tests-\(UUID().uuidString)")
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
        try makeStore(fileName: "store.sqlite")
    }

    /// A throwaway store on a distinct file — `fileName` lets a test pair
    /// two stores (source and target) that must not share a database.
    private func makeStore(fileName: String) throws -> LearningStore {
        try LearningStore(path: tempDir.appendingPathComponent(fileName).path)
    }

    private func frenchPack() throws -> CoursePack {
        try XCTUnwrap(
            PackLoader.loadPacks().first { $0.language == .french })
    }

    /// A valid independent-correct attempt on the first practice step of
    /// fr-home-foundation (a selection activity), same shape as the one in
    /// `LearningStoreTests`.
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

    /// A decoder matching `DataExport`'s encoder (`.iso8601` dates) — the
    /// exact shape a restore/import reader would use.
    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Builds the export for `store` and decodes it as `ExportedLearningData`.
    private func loadExport(store: LearningStore) throws -> ExportedLearningData {
        let url = try DataExport.buildFile(store: store)
        defer { try? FileManager.default.removeItem(at: url) }
        let data = try Data(contentsOf: url)
        return try makeDecoder().decode(ExportedLearningData.self, from: data)
    }

    // MARK: Contents

    /// Every portable category lands in the file: a lesson-known event mark,
    /// a live checkpoint plus a cleared checkpoint's tombstone, a saved
    /// phrase plus a removed phrase's tombstone, and a listened track whose
    /// position carries both a resume offset and the listened mark.
    func testExportContainsEventsCheckpointTombstonesPhrasesAndListenState() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let lesson = try XCTUnwrap(pack.lesson(id: "fr-home-foundation"))

        // A known "I know this" lesson mark (event log).
        try store.setLessonKnown(pack: pack, lessonId: lesson.id, known: true)

        // A live checkpoint, plus a cleared one whose tombstone must export.
        let savedCheckpoint = LessonCheckpoint(
            packId: pack.id, lessonId: lesson.id, revision: lesson.revision,
            stepId: "fr-home-foundation-step-rb4", selectedBranches: [:],
            assistance: [], draft: .text("Le chat"),
            at: Date(timeIntervalSince1970: 1_700_000_000))
        try store.saveCheckpoint(savedCheckpoint)
        let cleared = LessonCheckpoint(
            packId: "fr-foundations", lessonId: "fr-identity-foundation",
            revision: 1, stepId: "s1", selectedBranches: [:],
            assistance: [], draft: nil, at: Date(timeIntervalSince1970: 1_700_000_100))
        try store.saveCheckpoint(cleared)
        try store.clearCheckpoint(
            packId: cleared.packId, lessonId: cleared.lessonId)

        // A kept phrase and a removed phrase whose tombstone must export.
        let keptId = LearningStore.savedPhraseId(
            languageSlug: "french", target: "Le chat", meaning: "The cat")
        try store.savePhrase(SavedPhrase(
            id: keptId, languageSlug: "french", languageName: "French",
            target: "Le chat", meaning: "The cat",
            source: "fr-home-foundation-act-rb6",
            sourcePackId: pack.id, sourceLessonId: lesson.id,
            savedAt: Date(timeIntervalSince1970: 1_700_000_200)))
        let removedId = LearningStore.savedPhraseId(
            languageSlug: "french", target: "Au revoir", meaning: "Goodbye")
        try store.savePhrase(SavedPhrase(
            id: removedId, languageSlug: "french", languageName: "French",
            target: "Au revoir", meaning: "Goodbye",
            source: "", sourcePackId: "", sourceLessonId: "",
            savedAt: Date(timeIntervalSince1970: 1_700_000_300)))
        try store.unsavePhrase(id: removedId)

        // A listened track with a resume position and the listened mark.
        try store.saveListenPosition(
            trackId: "fr-home-foundation", seconds: 42.5,
            at: Date(timeIntervalSince1970: 1_700_000_400))
        try store.markListened(
            trackId: "fr-home-foundation",
            at: Date(timeIntervalSince1970: 1_700_000_500))

        let export = try loadExport(store: store)

        // The lesson-known mark is in the event log, ids preserved.
        let known = try XCTUnwrap(
            export.events.compactMap { event -> LessonKnownEvent? in
                if case .lessonKnown(let e) = event { return e }
                return nil
            }.first)
        XCTAssertEqual(known.lessonId, lesson.id)
        XCTAssertTrue(known.known)

        // The live checkpoint is present; the cleared one is gone but
        // marked, so a restore cannot resurrect it.
        XCTAssertEqual(export.checkpoints.count, 1)
        XCTAssertEqual(export.checkpoints[0].packId, pack.id)
        XCTAssertEqual(export.checkpoints[0].lessonId, lesson.id)
        XCTAssertTrue(export.checkpointTombstones.contains {
            $0.packId == cleared.packId && $0.lessonId == cleared.lessonId
        })

        // The kept phrase is present; the removed one is gone but marked.
        XCTAssertTrue(export.savedPhrases.contains { $0.id == keptId })
        XCTAssertFalse(export.savedPhrases.contains { $0.id == removedId })
        XCTAssertTrue(export.savedPhraseTombstones.contains { $0.id == removedId })

        // Listen state carries both position and the listened mark.
        let listen = try XCTUnwrap(
            export.listenState.first { $0.trackId == "fr-home-foundation" })
        XCTAssertEqual(listen.positionSeconds, 42.5)
        XCTAssertNotNil(listen.listenedAtMs)
    }

    // MARK: Header and round-trip shape

    /// The file names its producer and the export format version, so a
    /// reader can reject a file it does not understand before decoding.
    func testExportHeaderHasFormatVersionAndAppIdentifier() throws {
        let store = try makeStore()
        let export = try loadExport(store: store)
        XCTAssertEqual(export.formatVersion, DataExport.formatVersion)
        XCTAssertEqual(export.formatVersion, 2)
        XCTAssertEqual(export.app, "Condisco")
        XCTAssertGreaterThan(export.exportedAt.timeIntervalSince1970, 0)
    }

    /// The exported JSON decodes and every seeded item round-trips with its
    /// identifiers and timestamps at the store's raw precision — events at
    /// full date equality, row timestamps to the millisecond.
    func testExportRoundTripsIdentifiersAndRawTimestamps() throws {
        let store = try makeStore()
        let pack = try frenchPack()

        let at = Date(timeIntervalSince1970: 1_700_000_000.123)
        let attempt = try makeAttempt(id: "export-prim-1", pack: pack, at: at)
        try store.record(.attempt(attempt))

        try store.saveCheckpoint(LessonCheckpoint(
            packId: "fr-foundations", lessonId: "fr-home-foundation",
            revision: 2, stepId: "s1", selectedBranches: [:],
            assistance: [], draft: nil,
            at: Date(timeIntervalSince1970: 1_700_000_000.456)))

        try store.savePhrase(SavedPhrase(
            id: "export-prim-phrase",
            languageSlug: "french", languageName: "French",
            target: "Bonjour", meaning: "Hello",
            source: "act", sourcePackId: "fr-foundations",
            sourceLessonId: "fr-home-foundation",
            savedAt: Date(timeIntervalSince1970: 1_700_000_000.789)))

        try store.saveListenPosition(
            trackId: "export-prim-track", seconds: 17.25,
            at: Date(timeIntervalSince1970: 1_700_000_000.9))

        let export = try loadExport(store: store)

        // Event identity and timestamp preserved exactly.
        let exportedAttempt = try XCTUnwrap(
            export.events.compactMap { event -> ActivityAttempt? in
                if case .attempt(let e) = event, e.id == "export-prim-1" { return e }
                return nil
            }.first)
        XCTAssertEqual(exportedAttempt, attempt)
        XCTAssertEqual(exportedAttempt.at, at)

        // Checkpoint write timestamp preserved to the millisecond.
        let exportedCheckpoint = try XCTUnwrap(export.checkpoints.first)
        XCTAssertEqual(exportedCheckpoint.packId, "fr-foundations")
        XCTAssertEqual(exportedCheckpoint.lessonId, "fr-home-foundation")
        XCTAssertEqual(exportedCheckpoint.updatedAtMs, 1_700_000_000_456)

        // Phrase fields and save timestamp preserved to the millisecond.
        let exportedPhrase = try XCTUnwrap(export.savedPhrases.first)
        XCTAssertEqual(exportedPhrase.id, "export-prim-phrase")
        XCTAssertEqual(exportedPhrase.target, "Bonjour")
        XCTAssertEqual(exportedPhrase.meaning, "Hello")
        XCTAssertEqual(exportedPhrase.sourcePackId, "fr-foundations")
        XCTAssertEqual(exportedPhrase.sourceLessonId, "fr-home-foundation")
        XCTAssertEqual(exportedPhrase.savedAtMs, 1_700_000_000_789)

        // Listen row keeps position and raw timestamps; a position-only
        // write never fabricates a listened mark.
        let listen = try XCTUnwrap(export.listenState.first)
        XCTAssertEqual(listen.trackId, "export-prim-track")
        XCTAssertEqual(listen.positionSeconds, 17.25)
        XCTAssertEqual(listen.updatedAtMs, 1_700_000_000_900)
        XCTAssertNil(listen.listenedAtMs)
    }

    /// Placement recommendations live in UserDefaults; they are portable
    /// learner-owned data and must ride along in the export.
    func testExportIncludesPlacementRecommendations() throws {
        let store = try makeStore()
        UserDefaults.standard.set(
            "fr-identity-foundation",
            forKey: "condisco.placement.fr-foundations")
        defer {
            UserDefaults.standard.removeObject(
                forKey: "condisco.placement.fr-foundations")
        }

        let export = try loadExport(store: store)
        XCTAssertTrue(export.placement.contains {
            $0.packId == "fr-foundations"
                && $0.recommendedLessonId == "fr-identity-foundation"
        })
    }

    // MARK: Exclusions

    /// The file holds exactly the documented fields and nothing else:
    /// no device-only bookkeeping (device id, sync token, on-device
    /// markers, voice prefs) and no secret or temporary-recording material.
    func testExportContainsNoSecretsRecordingsOrDeviceBookkeeping() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let lesson = try XCTUnwrap(pack.lesson(id: "fr-home-foundation"))

        // Seed device-only state that must never reach the export.
        try store.setLessonKnown(pack: pack, lessonId: lesson.id, known: true)
        let deviceID = try store.deviceId()
        try store.kvSet(
            "condisco.mission-tried:fr-foundations:fr-home-foundation", "1")
        try store.kvSet("condisco.sync.eventChangeToken", "SECRET-TOKEN-VALUE")
        UserDefaults.standard.set(
            "com.apple.voice.compact.fr-FR.premium",
            forKey: "condisco.voice.fr-FR")
        defer {
            UserDefaults.standard.removeObject(
                forKey: "condisco.voice.fr-FR")
        }

        let url = try DataExport.buildFile(store: store)
        defer { try? FileManager.default.removeItem(at: url) }
        let data = try Data(contentsOf: url)
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))

        // Top-level shape: exactly the documented fields, nothing else.
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any])
        let expectedKeys: Set<String> = [
            "app", "formatVersion", "exportedAt", "events", "checkpoints",
            "checkpointTombstones", "listenState", "savedPhrases",
            "savedPhraseTombstones", "placement",
            "importedDocuments", "importedPhraseLinks",
        ]
        XCTAssertEqual(Set(json.keys), expectedKeys)

        // Sensitive material: no secrets, no recordings, no device-only ids
        // or sync tokens, anywhere in the file.
        let forbidden = [
            deviceID,
            "SECRET-TOKEN-VALUE",
            "condisco.sync",
            "condisco.mission-tried",
            "condisco.voice",
            "recording", "audio", "secret", "password", "token",
            "credential", "keychain", "userId", "device_id", "upload",
        ]
        for needle in forbidden {
            XCTAssertFalse(
                text.contains(needle),
                "export must not contain \(needle)")
        }
    }

    // MARK: Library documents (8.2 slice 4)

    private func makeDocument(
        id: String, title: String, content: String, pack: CoursePack,
        at: Date, sourceFileName: String = ""
    ) -> ImportedDocument {
        ImportedDocument(
            id: id, title: title, content: content,
            byteSize: content.data(using: .utf8)!.count,
            languageSlug: pack.language.slug,
            sourceFileName: sourceFileName,
            importedAt: at)
    }

    /// A deterministic saved phrase (id = language|target|meaning).
    private func makePhrase(pack: CoursePack, at: Date) -> SavedPhrase {
        let target = "la gare"
        let meaning = "the station"
        return SavedPhrase(
            id: LearningStore.savedPhraseId(
                languageSlug: pack.language.slug, target: target, meaning: meaning),
            languageSlug: pack.language.slug,
            languageName: pack.language.displayName,
            target: target, meaning: meaning,
            source: "Ma première lecture",
            savedAt: at)
    }

    /// The document-linked save sequence the library's save sheet runs
    /// (§6.5): document row + phrase row (provenance = title) + link.
    private func saveLibraryPhrase(
        store: LearningStore, phrase: SavedPhrase, document: ImportedDocument
    ) throws {
        try store.saveDocument(document)
        var fromDocument = phrase
        fromDocument.source = document.title
        try store.savePhrase(fromDocument)
        try store.linkPhrase(phraseId: phrase.id, documentId: document.id)
    }

    /// A phrase-review attempt of the exact shape
    /// `ReviewItem.makeAttempt(verdict:)` records (pack id
    /// `practice-library`), so the evidence chain is the real review one.
    private func makePhraseReviewAttempt(
        id: String, phraseId: String, at: Date
    ) -> ActivityAttempt {
        let verdict = ReviewVerdict.close
        return ActivityAttempt(
            id: id,
            packId: LibraryReview.packId,
            packVersion: LibraryReview.packVersion,
            lessonId: "",
            lessonRevision: 0,
            stepId: "review",
            activityId: "phrase-review",
            activityRevision: 0,
            evidenceKey: LibraryReview.evidenceKey(phraseId: phraseId),
            response: verdict.response,
            assistance: [],
            evaluation: AttemptEvaluation(
                outcome: verdict.outcome,
                independent: verdict.independent,
                feedback: ""),
            at: at)
    }

    /// Raw millisecond timestamp of a date, matching the store's `millis`.
    private func millis(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1_000).rounded())
    }

    /// Exact row count in `table` as a second connection sees it.
    private func rawCount(_ table: String) throws -> Int {
        let db = try Database(path: tempDir.appendingPathComponent("store.sqlite").path)
        var count = 0
        try db.query(
            "SELECT COUNT(*) FROM \(table);",
            row: { count = Int($0.int64(0)) })
        return count
    }

    /// The exact stored event rows (id + payload), byte-for-byte, one
    /// string per row joined with NUL.
    private func rawEventRows() throws -> [String] {
        let db = try Database(path: tempDir.appendingPathComponent("store.sqlite").path)
        var rows: [String] = []
        try db.query(
            "SELECT id, payload FROM events ORDER BY at_ms, id;",
            row: { rows.append(($0.text(0) ?? "") + "\u{0}" + ($0.text(1) ?? "")) })
        return rows
    }

    /// Decodes a validated preview or fails the test.
    private func requirePreview(
        _ data: Data, file: StaticString = #filePath, line: UInt = #line
    ) throws -> ImportPreview {
        switch ImportValidator.validate(data) {
        case .success(let preview): return preview
        case .failure(let error):
            XCTFail("expected a valid import, got \(error)", file: file, line: line)
            throw error
        }
    }

    /// Encodes a genuine version-1 export: the v1 field set,
    /// `formatVersion` 1, and no document sections.
    private func encodeV1Export(
        events: [LearningEvent] = [],
        savedPhrases: [StoredSavedPhrase] = [],
        exportedAt: Date = Date(timeIntervalSince1970: 1_730_000_000)
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let payload = ExportedLearningData(
            app: "Condisco",
            formatVersion: 1,
            exportedAt: exportedAt,
            events: events,
            checkpoints: [],
            checkpointTombstones: [],
            listenState: [],
            savedPhrases: savedPhrases,
            savedPhraseTombstones: [],
            placement: [])
        return try encoder.encode(payload)
    }

    /// The `flds` field of every note in an exported .apkg, so a test can
    /// assert what text actually reached the deck. The package is a zip of
    /// stored (uncompressed) entries written by `ZipStoreWriter`, so the
    /// SQLite collection is extracted by scanning local file headers
    /// directly, then read with the app's own `Database`.
    private func ankiNoteRows(deckURL: URL) throws -> [String] {
        let bytes = [UInt8](try Data(contentsOf: deckURL))
        var notes: [String] = []
        var i = 0
        while i + 30 <= bytes.count {
            let sig = UInt32(bytes[i])
                | UInt32(bytes[i + 1]) << 8
                | UInt32(bytes[i + 2]) << 16
                | UInt32(bytes[i + 3]) << 24
            guard sig == 0x0403_4B50 else { break }
            let nameLength = Int(bytes[i + 26]) | Int(bytes[i + 27]) << 8
            let extraLength = Int(bytes[i + 28]) | Int(bytes[i + 29]) << 8
            let contentStart = i + 30 + nameLength + extraLength
            if i + 30 + nameLength <= bytes.count,
               String(bytes: bytes[i + 30 ..< i + 30 + nameLength], encoding: .utf8)
                   == "collection.anki2" {
                // Stored entry: advertised size sits at header + 18.
                let size = Int(bytes[i + 18]) | Int(bytes[i + 19]) << 8
                    | Int(bytes[i + 20]) << 16 | Int(bytes[i + 21]) << 24
                guard contentStart + size <= bytes.count else { break }
                let extract = tempDir.appendingPathComponent(
                    "collection-\(UUID().uuidString).anki2")
                try Data(bytes[contentStart ..< contentStart + size]).write(to: extract)
                let db = try Database(path: extract.path)
                try db.query(
                    "SELECT flds FROM notes ORDER BY id;",
                    row: { notes.append($0.text(0) ?? "") })
            }
            i = contentStart
        }
        return notes
    }

    /// The v2 export carries the library: documents with raw-ms import
    /// timestamps and the phrase links, and a fresh store fed the decoded
    /// file restores rows byte-equal on content, byte size, source file
    /// name, and import date (plus the link pairs).
    func testExportRoundTripsDocumentsTitlesDatesContentAndLinks() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let at = Date(timeIntervalSince1970: 1_700_000_000.123)
        let doc = makeDocument(
            id: "doc-rt-1", title: "Ma première lecture",
            content: "Bonjour tout le monde, je m'appelle Marie.\nDeuxième ligne avec des accents : é à ç.",
            pack: pack, at: at, sourceFileName: "ma-lecture.txt")
        let phrase = makePhrase(pack: pack, at: at)
        try saveLibraryPhrase(store: store, phrase: phrase, document: doc)

        let export = try loadExport(store: store)
        XCTAssertEqual(export.formatVersion, DataExport.formatVersion)
        XCTAssertEqual(export.importedDocuments?.count, 1)
        XCTAssertEqual(export.importedPhraseLinks?.count, 1)
        let exportedDoc = try XCTUnwrap(export.importedDocuments?.first)
        XCTAssertEqual(exportedDoc.id, doc.id)
        XCTAssertEqual(exportedDoc.title, doc.title)
        XCTAssertEqual(exportedDoc.content, doc.content)
        XCTAssertEqual(exportedDoc.byteSize, doc.byteSize)
        XCTAssertEqual(exportedDoc.languageSlug, pack.language.slug)
        XCTAssertEqual(exportedDoc.sourceFileName, "ma-lecture.txt")
        XCTAssertEqual(exportedDoc.importedAtMs, millis(at))
        XCTAssertEqual(
            export.importedPhraseLinks?.first,
            StoredImportedPhraseLink(phraseId: phrase.id, documentId: doc.id))

        // A fresh store fed the decoded FILE (not the in-memory struct)
        // restores the same rows, byte-equal at the stored-row level.
        let url = try DataExport.buildFile(store: store)
        defer { try? FileManager.default.removeItem(at: url) }
        let preview = try requirePreview(try Data(contentsOf: url))
        XCTAssertEqual(preview.documents.count, 1)
        XCTAssertEqual(preview.phraseLinks.count, 1)
        XCTAssertEqual(preview.documents[0].importedAtMs, millis(at))

        let restored = try makeStore(fileName: "restored.sqlite")
        XCTAssertNoThrow(try restored.applyImport(preview))
        XCTAssertEqual(
            try restored.allImportedDocuments(),
            [StoredImportedDocument(
                id: doc.id, title: doc.title, content: doc.content,
                byteSize: doc.byteSize, languageSlug: doc.languageSlug,
                sourceFileName: doc.sourceFileName,
                importedAtMs: millis(at))])
        XCTAssertEqual(
            try restored.phraseLinks(),
            [ImportedPhraseLink(phraseId: phrase.id, documentId: doc.id)])
        let restoredDoc = try XCTUnwrap(restored.documents().first)
        XCTAssertEqual(restoredDoc.title, doc.title)
        XCTAssertEqual(restoredDoc.content, doc.content)
        XCTAssertEqual(restoredDoc.byteSize, doc.byteSize)
        XCTAssertEqual(restoredDoc.sourceFileName, doc.sourceFileName)
        XCTAssertEqual(restoredDoc.importedAt, at)
    }

    /// Back-compat is mandatory (§7): a version-1 file — no document
    /// sections — validates unchanged, restores its own sections, and
    /// writes zero document/link rows. A legacy (pre-1.1) file does the
    /// same.
    func testExportDocumentSectionAbsentInLegacyAndVersion1Files() throws {
        let store = try makeStore()
        let phrase = StoredSavedPhrase(
            id: "v1-phrase-1", languageSlug: "french", languageName: "French",
            target: "Le chat", meaning: "The cat", source: "src",
            sourcePackId: "", sourceLessonId: "", savedAtMs: 1_700_000_000_000)

        let v1Preview = try requirePreview(try encodeV1Export(savedPhrases: [phrase]))
        XCTAssertEqual(v1Preview.formatVersion, 1)
        XCTAssertFalse(v1Preview.isLegacy)
        XCTAssertTrue(v1Preview.documents.isEmpty,
                      "a v1 file never carries a document section")
        XCTAssertTrue(v1Preview.phraseLinks.isEmpty)
        XCTAssertNoThrow(try store.applyImport(v1Preview))
        XCTAssertEqual(try rawCount("imported_documents"), 0)
        XCTAssertEqual(try rawCount("imported_phrase_links"), 0)
        XCTAssertEqual(try store.allSavedPhrases().map(\.id), ["v1-phrase-1"],
                       "the v1 sections still restore")

        // A v2 build exporting an empty library also emits empty arrays —
        // the keys exist (a v2 contract), the rows are absent.
        let v2Empty = try loadExport(store: store)
        XCTAssertEqual(v2Empty.importedDocuments, [])
        XCTAssertEqual(v2Empty.importedPhraseLinks, [])

        // Legacy (pre-1.1): app marker, no formatVersion, no documents.
        let legacy = try XCTUnwrap(
            "{\"app\":\"Condisco\",\"exportedAt\":\"2024-01-01T00:00:00Z\"}"
                .data(using: .utf8))
        let legacyPreview = try requirePreview(legacy)
        XCTAssertTrue(legacyPreview.isLegacy)
        XCTAssertTrue(legacyPreview.documents.isEmpty)
        XCTAssertNoThrow(try store.applyImport(legacyPreview))
        XCTAssertEqual(try rawCount("imported_documents"), 0)
        XCTAssertEqual(try rawCount("imported_phrase_links"), 0)
    }

    /// Restoring a v2 export adds the document and link rows and leaves
    /// every other section exactly as it would have been without them —
    /// the library section is additive JSON (design §11.1).
    func testImportRestoresDocumentsAndLinksWithoutTouchingOtherSections() throws {
        let source = try makeStore()
        let pack = try frenchPack()
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        let doc = makeDocument(
            id: "doc-imp", title: "Doc", content: "Contenu.", pack: pack, at: at)
        let phrase = makePhrase(pack: pack, at: at)
        try saveLibraryPhrase(store: source, phrase: phrase, document: doc)
        try source.record(.attempt(makePhraseReviewAttempt(
            id: "pr-imp-1", phraseId: phrase.id, at: at)))
        try source.saveListenPosition(trackId: "t-imp", seconds: 5, at: at)

        let url = try DataExport.buildFile(store: source)
        defer { try? FileManager.default.removeItem(at: url) }
        let preview = try requirePreview(try Data(contentsOf: url))

        // A fresh store with unrelated lesson-known history: the merge
        // must add the file's rows and leave the local ones alone.
        let target = try makeStore(fileName: "target.sqlite")
        let lesson = try XCTUnwrap(pack.lesson(id: "fr-home-foundation"))
        try target.setLessonKnown(pack: pack, lessonId: lesson.id, known: true)
        let targetEventsBefore = try target.allEvents()
        XCTAssertNoThrow(try target.applyImport(preview))

        XCTAssertEqual(try target.documents(), [doc])
        XCTAssertEqual(
            try target.phraseLinks(),
            [ImportedPhraseLink(phraseId: phrase.id, documentId: doc.id)])
        XCTAssertEqual(try target.allSavedPhrases(), try source.allSavedPhrases())
        XCTAssertEqual(try target.allEvents().count, targetEventsBefore.count + 1)
        XCTAssertTrue(try target.allEvents().contains { event in
            guard case .attempt(let attempt) = event else { return false }
            return attempt.id == "pr-imp-1"
        })
        XCTAssertEqual(try target.listenPosition(trackId: "t-imp"), 5)
        XCTAssertEqual(try target.allListenState().count, 1)
        XCTAssertEqual(try target.allListenState(), try source.allListenState())
    }

    /// The restore-preview count lines (`YouView.swift` shows "N library
    /// documents") are fed by the preview's document/link counts, so the
    /// UI numbers and the merge are the same data.
    func testImportPreviewCountsLinesIncludeDocuments() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        let first = makeDocument(
            id: "doc-prev-1", title: "Un", content: "Premier texte.",
            pack: pack, at: at)
        let second = makeDocument(
            id: "doc-prev-2", title: "Deux", content: "Deuxième texte.",
            pack: pack, at: at.addingTimeInterval(60))
        let phrase = makePhrase(pack: pack, at: at)
        try saveLibraryPhrase(store: store, phrase: phrase, document: first)
        try store.saveDocument(second)
        try store.linkPhrase(phraseId: phrase.id, documentId: second.id)

        let url = try DataExport.buildFile(store: store)
        defer { try? FileManager.default.removeItem(at: url) }
        let preview = try requirePreview(try Data(contentsOf: url))
        XCTAssertEqual(preview.documents.count, 2)
        XCTAssertEqual(preview.phraseLinks.count, 2)
        XCTAssertEqual(preview.savedPhrases.count, 1)
        XCTAssertEqual(
            preview.documents.map(\.id).sorted(), ["doc-prev-1", "doc-prev-2"])
    }

    /// Re-importing the same file is a no-op across the library tables:
    /// document and link row counts stay put, and the other sections are
    /// untouched too (the repeat-import contract, extended from the
    /// existing `testRepeatImportIsANoOp` to the document sections).
    func testReimportingExportIsIdempotent() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        let doc = makeDocument(
            id: "doc-idem", title: "Texte", content: "Un texte.", pack: pack, at: at)
        let phrase = makePhrase(pack: pack, at: at)
        try saveLibraryPhrase(store: store, phrase: phrase, document: doc)
        try store.record(.attempt(makePhraseReviewAttempt(
            id: "pr-idem-1", phraseId: phrase.id, at: at)))

        let url = try DataExport.buildFile(store: store)
        defer { try? FileManager.default.removeItem(at: url) }
        let preview = try requirePreview(try Data(contentsOf: url))
        XCTAssertNoThrow(try store.applyImport(preview))
        XCTAssertNoThrow(try store.applyImport(preview))

        XCTAssertEqual(try rawCount("imported_documents"), 1)
        XCTAssertEqual(try rawCount("imported_phrase_links"), 1)
        XCTAssertEqual(try store.documents().count, 1)
        XCTAssertEqual(try store.allEvents().count, 1)
        XCTAssertEqual(try store.allSavedPhrases().count, 1)
        XCTAssertEqual(try store.allListenState().count, 0)
    }

    /// §8 × slice 4: deleting a document removes its rows; re-importing
    /// an older export restores the document and its links while the
    /// phrase's review history — the append-only event log — stays
    /// byte-identical.
    func testDeletingThenReimportingRestoresDocumentWithoutTouchingPhraseReviewState() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        let doc = makeDocument(
            id: "doc-del-rt", title: "À supprimer", content: "Le contenu privé.",
            pack: pack, at: at)
        let phrase = makePhrase(pack: pack, at: at)
        try saveLibraryPhrase(store: store, phrase: phrase, document: doc)
        try store.record(.attempt(makePhraseReviewAttempt(
            id: "pr-del-1", phraseId: phrase.id, at: at)))

        // The export taken BEFORE the delete carries the document.
        let url = try DataExport.buildFile(store: store)
        defer { try? FileManager.default.removeItem(at: url) }
        let file = try Data(contentsOf: url)

        try store.deleteDocument(id: doc.id)
        XCTAssertTrue(try store.documents().isEmpty)
        XCTAssertTrue(try store.phraseLinks().isEmpty)
        let eventsAfterDelete = try rawEventRows()

        // Re-importing the older file brings the document and its link
        // back. The phrase's review events are untouched: the delete wrote
        // no events and the import adds none.
        try store.applyImport(try requirePreview(file))
        XCTAssertEqual(try store.documents(), [doc])
        XCTAssertEqual(
            try store.phraseLinks(),
            [ImportedPhraseLink(phraseId: phrase.id, documentId: doc.id)])
        XCTAssertEqual(try rawEventRows(), eventsAfterDelete)
        XCTAssertEqual(try store.allSavedPhrases().count, 1)

        // And the review queue schedules the phrase again — the link is
        // back, its FSRS history is intact.
        let model = try ReviewModel(
            store: store, packs: [pack], focusSlug: "french")
        let key = LibraryReview.evidenceKey(phraseId: phrase.id)
        XCTAssertEqual(model.due.filter { $0.evidenceKey == key }.count, 1)
    }

    /// The library's only exit is the learner's own DataExport (§7): the
    /// export payload includes the documents, while every other surface —
    /// the CloudKit record types (sync compiled off), the widget snapshot,
    /// the Spotlight/Anki phrase feed, and the sync upload queue — never
    /// sees document rows or content.
    func testExportContainsNoDocumentContentInCloudKitOrWidgetPaths() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        let doc = makeDocument(
            id: "doc-excl", title: "Lecture privée",
            content: "Le contenu privé de cette lecture.", pack: pack, at: at)
        let phrase = makePhrase(pack: pack, at: at)
        try saveLibraryPhrase(store: store, phrase: phrase, document: doc)
        try store.record(.attempt(makePhraseReviewAttempt(
            id: "pr-excl-1", phraseId: phrase.id, at: at)))

        // 1. Include path: DataExport carries the documents.
        let export = try loadExport(store: store)
        XCTAssertEqual(export.importedDocuments?.first?.content, doc.content)

        // 2. Sync queue: the phrase-review attempt is the only uploadable
        // row; documents never reach sync.
        let syncFeed = try store.unsyncedEvents()
        XCTAssertEqual(syncFeed.count, 1)
        XCTAssertEqual(try rawCount("sync_uploads"), 0)
        XCTAssertFalse(String(describing: syncFeed).contains(doc.content))

        // 3. CloudKit: the compiled-off sync layer declares record types
        // for every table it syncs and none for documents (the document
        // tables have no read path there at all — pinned here).
        let recordTypes = [
            CloudKitSync.recordType,
            CloudKitSync.checkpointRecordType,
            CloudKitSync.checkpointTombstoneRecordType,
            CloudKitSync.listenRecordType,
            CloudKitSync.savedPhraseRecordType,
            CloudKitSync.savedPhraseTombstoneRecordType,
        ]
        XCTAssertFalse(recordTypes.contains { $0.contains("Document") })

        // 4. Widget snapshot: the fixed snapshot shape carries no document
        // fields.
        let snapshot = WidgetSnapshotWriter.makeSnapshot(
            packs: [pack], focusSlug: pack.language.slug, progress: [:],
            dueCount: 0, weekFlags: [false], practiceDays: 0)
        XCTAssertFalse(String(describing: snapshot).contains(doc.content))
        XCTAssertFalse(String(describing: snapshot).contains(doc.title))

        // 5. Spotlight + Anki feed: `savedPhrases()` — the only input
        // both surfaces read — carries target/meaning, never document
        // content. Its source is the document title by design (§3.3).
        let phrases = try store.savedPhrases()
        XCTAssertFalse(phrases.contains {
            $0.target.contains(doc.content) || $0.meaning.contains(doc.content)
        })
        XCTAssertEqual(phrases.map(\.source), [doc.title])

        // 6. Anki deck: the .apkg's notes carry target/meaning only.
        let deckURL = try AnkiExporter.export(phrases: phrases)
        defer { try? FileManager.default.removeItem(at: deckURL) }
        let notes = try ankiNoteRows(deckURL: deckURL)
        XCTAssertEqual(notes.count, 1)
        XCTAssertTrue(notes[0].contains(phrase.target))
        XCTAssertTrue(notes[0].contains(phrase.meaning))
        XCTAssertFalse(notes[0].contains(doc.content))
        XCTAssertFalse(notes[0].contains(doc.title))
    }
}

// MARK: - Safe local restore (Slice 1.2)
//
// The write half of data portability: a validated export merges into a
// store transactionally. `ImportValidator` (pure, in the Store target)
// decodes and validates the file BEFORE anything is written; these tests
// drive validation and the transactional merge end to end: valid and
// legacy imports restore counts/identifiers/timestamps, repeat imports
// are no-ops, a conflicting event id aborts the whole transaction with
// the store byte-identical, and corrupt/oversized/unrecognized files are
// rejected with zero writes.

@MainActor
final class ImportRestoreTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("condisco-import-tests-\(UUID().uuidString)")
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

    private var storeURL: URL {
        tempDir.appendingPathComponent("store.sqlite")
    }

    private func frenchPack() throws -> CoursePack {
        try XCTUnwrap(
            PackLoader.loadPacks().first { $0.language == .french })
    }

    /// A valid independent-correct attempt on the first practice step of
    /// fr-home-foundation (a selection activity), same shape as the ones
    /// in `DataExportTests`.
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

    /// The exercise ids a legacy-success lesson requires, from the live
    /// pack — the same ids the projection's legacy-credit check reads.
    private func legacyExerciseIds(
        for lessonId: String, pack: CoursePack
    ) throws -> [String] {
        let lesson = try XCTUnwrap(pack.lesson(id: lessonId))
        guard case .legacySuccess(let ids) = lesson.completionPolicy,
              !ids.isEmpty
        else {
            throw XCTSkip("\(lessonId) must be a legacy-success lesson")
        }
        return ids
    }

    /// Encodes a checkpoint row exactly as the store's export does: raw
    /// payload JSON plus the write timestamp in milliseconds.
    private func storedCheckpointData(
        _ checkpoint: LessonCheckpoint
    ) throws -> StoredCheckpoint {
        StoredCheckpoint(
            packId: checkpoint.packId,
            lessonId: checkpoint.lessonId,
            payload: try XCTUnwrap(
                String(data: JSONEncoder().encode(checkpoint), encoding: .utf8)),
            updatedAtMs: Int64((checkpoint.at.timeIntervalSince1970 * 1_000).rounded()))
    }

    /// Encodes a format-1 export the way `DataExport.buildFile` does
    /// (ISO 8601 dates, sorted keys).
    private func encodeExport(
        events: [LearningEvent] = [],
        checkpoints: [StoredCheckpoint] = [],
        checkpointTombstones: [CheckpointTombstone] = [],
        savedPhrases: [StoredSavedPhrase] = [],
        savedPhraseTombstones: [SavedPhraseTombstone] = [],
        listenState: [ListenStateRow] = [],
        placement: [ExportedPlacement] = [],
        exportedAt: Date = Date(timeIntervalSince1970: 1_730_000_000)
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let payload = ExportedLearningData(
            app: "Condisco",
            formatVersion: DataExport.formatVersion,
            exportedAt: exportedAt,
            events: events,
            checkpoints: checkpoints,
            checkpointTombstones: checkpointTombstones,
            listenState: listenState,
            savedPhrases: savedPhrases,
            savedPhraseTombstones: savedPhraseTombstones,
            placement: placement)
        return try encoder.encode(payload)
    }

    /// Encodes a pre-1.1 export: app marker, no formatVersion, and only
    /// the three sections that existed then.
    private func legacyExportData(
        events: [LearningEvent],
        checkpoints: [StoredCheckpoint],
        listenState: [ListenStateRow],
        exportedAt: String = "2023-11-14T22:13:20Z"
    ) throws -> Data {
        var object: [String: Any] = [
            "app": "Condisco",
            "exportedAt": exportedAt,
        ]
        object["events"] = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(events))
        object["checkpoints"] = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(checkpoints))
        object["listenState"] = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(listenState))
        return try JSONSerialization.data(withJSONObject: object)
    }

    /// Decodes a validated preview or fails the test.
    private func requirePreview(
        _ data: Data, file: StaticString = #filePath, line: UInt = #line
    ) throws -> ImportPreview {
        switch ImportValidator.validate(data) {
        case .success(let preview): return preview
        case .failure(let error):
            XCTFail("expected a valid import, got \(error)", file: file, line: line)
            throw error
        }
    }

    /// Asserts validation fails with a specific error kind.
    private func assertRejected(
        _ data: Data,
        matches: (ImportValidationError) -> Bool,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        switch ImportValidator.validate(data) {
        case .success(let preview):
            XCTFail("expected rejection, got preview with \(preview.events.count) events",
                    file: file, line: line)
        case .failure(let error):
            XCTAssertTrue(matches(error), "unexpected error \(error)",
                          file: file, line: line)
        }
    }

    /// Logical snapshot of every table a restore can touch, for
    /// idempotency / rollback comparisons.
    private struct StoreSnapshot: Equatable {
        var eventIDs: [String]
        var checkpoints: [StoredCheckpoint]
        var checkpointTombstones: [CheckpointTombstone]
        var savedPhrases: [StoredSavedPhrase]
        var savedPhraseTombstones: [SavedPhraseTombstone]
        var listenState: [ListenStateRow]
    }

    private func snapshot(_ store: LearningStore) throws -> StoreSnapshot {
        StoreSnapshot(
            eventIDs: try store.allEvents().map(\.id),
            checkpoints: try store.allCheckpoints(),
            checkpointTombstones: try store.allCheckpointTombstones(),
            savedPhrases: try store.allSavedPhrases(),
            savedPhraseTombstones: try store.allSavedPhraseTombstones(),
            listenState: try store.allListenState())
    }

    // MARK: Valid import

    /// A current-format export restores every section with its identifiers
    /// and raw timestamps intact, and the store's projections (evidence,
    /// due set, practice days) reflect the imported history.
    func testValidExportImportRestoresCountsIdentifiersAndProjections() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let lesson = try XCTUnwrap(pack.lesson(id: "fr-home-foundation"))
        let at = Date(timeIntervalSince1970: 1_700_000_000.123)
        let attempt = try makeAttempt(id: "import-ev-1", pack: pack, at: at)
        let completion = StepCompletion(
            id: "import-ev-2", packId: pack.id, packVersion: pack.version,
            lessonId: lesson.id, lessonRevision: lesson.revision,
            stepId: attempt.stepId, selectedBranchId: nil,
            attemptId: attempt.id, at: at.addingTimeInterval(1))
        let checkpoint = LessonCheckpoint(
            packId: pack.id, lessonId: lesson.id, revision: lesson.revision,
            stepId: attempt.stepId, selectedBranches: [:],
            assistance: [], draft: .text("Le chat"),
            at: Date(timeIntervalSince1970: 1_700_000_000.456))
        let phrase = StoredSavedPhrase(
            id: "import-phrase-1", languageSlug: "french", languageName: "French",
            target: "Le chat", meaning: "The cat", source: "src",
            sourcePackId: pack.id, sourceLessonId: lesson.id,
            savedAtMs: 1_700_000_000_789)
        let listen = ListenStateRow(
            trackId: "import-track", positionSeconds: 17.25,
            listenedAtMs: nil, updatedAtMs: 1_700_000_000_900)
        let tombstone = CheckpointTombstone(
            packId: pack.id, lessonId: "fr-people-foundation",
            deletedAtMs: 1_700_000_001_000)
        let placement = ExportedPlacement(
            packId: "fr-foundations", recommendedLessonId: "fr-identity-foundation")
        defer {
            UserDefaults.standard.removeObject(
                forKey: PlacementStore.key(for: placement.packId))
        }

        let data = try encodeExport(
            events: [.attempt(attempt), .stepCompleted(completion)],
            checkpoints: [try storedCheckpointData(checkpoint)],
            checkpointTombstones: [tombstone],
            savedPhrases: [phrase],
            listenState: [listen],
            placement: [placement],
            exportedAt: Date(timeIntervalSince1970: 1_730_000_000))

        // The preview carries the counts the UI shows before confirmation.
        let preview = try requirePreview(data)
        XCTAssertEqual(preview.formatVersion, DataExport.formatVersion)
        XCTAssertFalse(preview.isLegacy)
        XCTAssertEqual(preview.events.count, 2)
        XCTAssertEqual(preview.checkpoints.count, 1)
        XCTAssertEqual(preview.checkpointTombstones.count, 1)
        XCTAssertEqual(preview.savedPhrases.count, 1)
        XCTAssertEqual(preview.listenState.count, 1)
        XCTAssertEqual(preview.placement.count, 1)
        XCTAssertEqual(preview.exportedAt?.timeIntervalSince1970, 1_730_000_000)

        XCTAssertNoThrow(try store.applyImport(preview))

        // Placement lives in UserDefaults and is applied by the caller
        // (`YouModel.restore`) only after the merge transaction commits,
        // so a failed import writes nothing anywhere. Mirror that step.
        for entry in preview.placement {
            PlacementStore.save(
                packId: entry.packId,
                lessonId: entry.recommendedLessonId)
        }

        // Events restored with ids and full-precision timestamps intact.
        let events = try store.learningEvents(packId: pack.id)
        XCTAssertEqual(events.map(\.id), ["import-ev-1", "import-ev-2"])
        guard case .attempt(let storedAttempt) = events[0],
              case .stepCompleted(let storedCompletion) = events[1]
        else {
            return XCTFail("expected an attempt then a step completion")
        }
        XCTAssertEqual(storedAttempt, attempt)
        XCTAssertEqual(storedCompletion, completion)

        // Checkpoint row and tombstone both land with raw timestamps.
        XCTAssertEqual(try store.allCheckpoints().count, 1)
        XCTAssertEqual(try store.allCheckpoints()[0].updatedAtMs, 1_700_000_000_456)
        XCTAssertEqual(try store.allCheckpointTombstones().count, 1)

        // Saved phrase and listen state land with their raw values.
        let phrases = try store.allSavedPhrases()
        XCTAssertEqual(phrases.count, 1)
        XCTAssertEqual(phrases[0].id, "import-phrase-1")
        XCTAssertEqual(phrases[0].savedAtMs, 1_700_000_000_789)
        XCTAssertEqual(try store.allListenState().count, 1)
        XCTAssertEqual(try store.listenPosition(trackId: "import-track"), 17.25)

        // Placement recommendation lands in UserDefaults.
        XCTAssertEqual(
            PlacementStore.recommendedLessonId(packId: "fr-foundations"),
            "fr-identity-foundation")

        // Projections updated from the imported history.
        let progress = try store.project(pack: pack)
        XCTAssertTrue(progress.quarantined.isEmpty)
        let key = try XCTUnwrap(attempt.evidenceKey)
        XCTAssertEqual(progress.evidence[key]?.successes, 1)
        XCTAssertEqual(progress.skillCounts[.reading]?.independent, 1)
        XCTAssertEqual(try store.practiceDays(), 1)
        XCTAssertEqual(try store.dueEvidence(pack: pack).count, 1)
    }

    // MARK: Legacy (pre-1.1)

    /// A legacy export — app marker, no formatVersion, only events/
    /// checkpoints/listenState — validates as legacy and restores. The v1
    /// practice history still carries its lesson's legacy completion
    /// credit through projection.
    func testLegacyExportWithoutFormatVersionImports() throws {
        let pack = try frenchPack()
        let creditExerciseIDs = try legacyExerciseIds(
            for: "fr-identity-foundation", pack: pack)
        // The lesson's legacy-success policy requires an independent
        // success on EVERY listed exercise, so the history must carry one
        // v1 event per required exercise id.
        let v1Events: [LearningEvent] = creditExerciseIDs.enumerated().map {
            index, exerciseId in
            .practiceV1(PracticeEventV1(
                id: "legacy-ev-\(index + 1)", packId: pack.id, version: "0.9.0",
                exerciseId: exerciseId,
                at: Date(timeIntervalSince1970: 1_600_000_000),
                correct: true, revealed: false))
        }
        let checkpoint = LessonCheckpoint(
            packId: pack.id, lessonId: "fr-home-foundation",
            revision: pack.lesson(id: "fr-home-foundation")?.revision ?? 1,
            stepId: "fr-home-foundation-step-rb2", selectedBranches: [:],
            assistance: [], draft: .text("Le"),
            at: Date(timeIntervalSince1970: 1_600_000_000))
        let listen = ListenStateRow(
            trackId: "legacy-track", positionSeconds: 12.5,
            listenedAtMs: nil, updatedAtMs: 1_600_000_000_000)

        let data = try legacyExportData(
            events: v1Events,
            checkpoints: [try storedCheckpointData(checkpoint)],
            listenState: [listen])

        let preview = try requirePreview(data)
        XCTAssertTrue(preview.isLegacy)
        XCTAssertNil(preview.formatVersion)
        XCTAssertEqual(preview.events.count, creditExerciseIDs.count)
        XCTAssertEqual(preview.checkpoints.count, 1)
        XCTAssertEqual(preview.listenState.count, 1)
        XCTAssertTrue(preview.savedPhrases.isEmpty)
        XCTAssertTrue(preview.checkpointTombstones.isEmpty)

        let store = try makeStore()
        XCTAssertNoThrow(try store.applyImport(preview))

        XCTAssertEqual(
            try store.allEvents().map(\.id),
            (1...creditExerciseIDs.count).map { "legacy-ev-\($0)" })
        XCTAssertEqual(
            try store.loadCheckpoint(packId: pack.id, lessonId: "fr-home-foundation"),
            checkpoint)
        XCTAssertEqual(try store.listenPosition(trackId: "legacy-track"), 12.5)
        XCTAssertEqual(try store.practiceDays(), 1)

        // v1 success history grants its lesson's legacy credit.
        let progress = try store.project(pack: pack)
        XCTAssertTrue(progress.legacyCredits.contains("fr-identity-foundation"))
        XCTAssertTrue(progress.quarantined.isEmpty)
    }

    // MARK: Idempotency

    /// Re-importing the identical file changes nothing: every table is
    /// bit-for-bit (logically) identical after the second import.
    func testRepeatImportIsANoOp() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        let attempt = try makeAttempt(id: "repeat-1", pack: pack, at: at)
        let checkpoint = LessonCheckpoint(
            packId: pack.id, lessonId: "fr-home-foundation",
            revision: pack.lesson(id: "fr-home-foundation")?.revision ?? 1,
            stepId: attempt.stepId, selectedBranches: [:],
            assistance: [], draft: nil, at: at)
        let phrase = StoredSavedPhrase(
            id: "repeat-phrase", languageSlug: "french", languageName: "French",
            target: "Bonjour", meaning: "Hello", source: "src",
            sourcePackId: pack.id, sourceLessonId: "fr-home-foundation",
            savedAtMs: 1_700_000_000_000)
        let listen = ListenStateRow(
            trackId: "repeat-track", positionSeconds: 9.5,
            listenedAtMs: nil, updatedAtMs: 1_700_000_000_500)

        let data = try encodeExport(
            events: [.attempt(attempt)],
            checkpoints: [try storedCheckpointData(checkpoint)],
            savedPhrases: [phrase],
            listenState: [listen])
        let preview = try requirePreview(data)

        try store.applyImport(preview)
        let first = try snapshot(store)
        XCTAssertNoThrow(try store.applyImport(preview))
        let second = try snapshot(store)
        XCTAssertEqual(second, first,
                       "a repeat import of the identical file must be a no-op")
        XCTAssertEqual(try store.allEvents().count, 1)
    }

    // MARK: Conflict → full rollback

    /// A conflicting event id (same id, different payload) inside the
    /// export aborts the ENTIRE transaction: the new event, the extra
    /// event, and the checkpoint all roll back, and the store's file is
    /// byte-identical to before the attempt.
    func testConflictingEventIDAbortsImportLeavingStoreByteIdentical() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        let original = try makeAttempt(id: "restore-conflict", pack: pack, at: at)
        try store.record(.attempt(original))

        let bytesBefore = try Data(contentsOf: storeURL)

        var conflicting = original
        conflicting.evaluation = AttemptEvaluation(
            outcome: .incorrect, independent: false, feedback: "different")
        let extra = try makeAttempt(
            id: "restore-extra", pack: pack, at: at.addingTimeInterval(5))
        let checkpoint = LessonCheckpoint(
            packId: pack.id, lessonId: "fr-home-foundation",
            revision: pack.lesson(id: "fr-home-foundation")?.revision ?? 1,
            stepId: "fr-home-foundation-step-rb2", selectedBranches: [:],
            assistance: [], draft: .text("Le chat"), at: at)

        let preview = try requirePreview(try encodeExport(
            events: [.attempt(conflicting), .attempt(extra)],
            checkpoints: [try storedCheckpointData(checkpoint)]))

        XCTAssertThrowsError(try store.applyImport(preview)) { error in
            guard case LearningStore.StoreError.conflict(let id) = error else {
                return XCTFail("expected store conflict, got \(error)")
            }
            XCTAssertEqual(id, "restore-conflict")
        }

        // Rollback: file bytes unchanged and nothing else landed.
        let bytesAfter = try Data(contentsOf: storeURL)
        XCTAssertEqual(bytesAfter, bytesBefore,
                       "a rolled-back import must leave the store byte-identical")
        XCTAssertEqual(try store.allEvents().map(\.id), ["restore-conflict"])
        XCTAssertTrue(try store.allCheckpoints().isEmpty)
        XCTAssertTrue(try store.savedPhrases().isEmpty)
    }

    // MARK: Zero-write rejections

    /// Truncated or non-JSON files are rejected before any write.
    func testTruncatedAndCorruptJSONRejectedWithZeroWrites() throws {
        let store = try makeStore()
        let bytesBefore = try Data(contentsOf: storeURL)

        let valid = try encodeExport()
        let truncated = valid.dropLast(4) // cut the tail cleanly
        assertRejected(Data(truncated)) { error in
            if case ImportValidationError.invalidJSON = error { return true }
            return false
        }
        assertRejected(Data("this is not json at all".utf8)) { error in
            if case ImportValidationError.invalidJSON = error { return true }
            return false
        }

        // A top-level JSON array (not an object) is also rejected.
        assertRejected(Data("[1,2,3]".utf8)) { error in
            if case ImportValidationError.invalidJSON = error { return true }
            return false
        }

        XCTAssertEqual(try Data(contentsOf: storeURL), bytesBefore)
        XCTAssertTrue(try store.allEvents().isEmpty)
        XCTAssertTrue(try store.savedPhrases().isEmpty)
    }

    /// A formatVersion this build cannot read is rejected outright.
    func testUnsupportedFormatVersionRejectedZeroWrites() throws {
        let store = try makeStore()
        let bytesBefore = try Data(contentsOf: storeURL)
        let json = """
        {"app":"Condisco","formatVersion":99,"exportedAt":"2024-05-01T12:00:00Z","events":[],"checkpoints":[],"checkpointTombstones":[],"listenState":[],"savedPhrases":[],"savedPhraseTombstones":[],"placement":[]}
        """
        assertRejected(Data(json.utf8)) { error in
            if case ImportValidationError.unsupportedFormatVersion(99) = error {
                return true
            }
            return false
        }
        XCTAssertEqual(try Data(contentsOf: storeURL), bytesBefore)
        XCTAssertTrue(try store.allEvents().isEmpty)
    }

    /// An oversized file is rejected by the named cap before any parsing.
    func testOversizedFileRejectedBySizeCap() throws {
        let store = try makeStore()
        let bytesBefore = try Data(contentsOf: storeURL)

        // Pins the exact bound: 50 MB by name.
        XCTAssertEqual(ImportValidator.maxImportSizeBytes, 50 * 1024 * 1024)
        let huge = Data(repeating: 0x41,
                        count: ImportValidator.maxImportSizeBytes + 1)
        assertRejected(huge) { error in
            if case ImportValidationError.tooLarge(let actual, let limit) = error {
                XCTAssertEqual(limit, ImportValidator.maxImportSizeBytes)
                XCTAssertEqual(actual, ImportValidator.maxImportSizeBytes + 1)
                return true
            }
            return false
        }
        XCTAssertEqual(try Data(contentsOf: storeURL), bytesBefore)
        XCTAssertTrue(try store.allEvents().isEmpty)
    }

    /// A listen position that is not a finite non-negative number
    /// (negative garbage here; NaN/Infinity are unrepresentable in strict
    /// JSON) rejects the whole file before any write.
    func testInvalidListenPositionRejectedZeroWrites() throws {
        let store = try makeStore()
        let bytesBefore = try Data(contentsOf: storeURL)

        let negative = """
        {"app":"Condisco","formatVersion":1,"exportedAt":"2024-05-01T12:00:00Z","events":[],"checkpoints":[],"checkpointTombstones":[],"listenState":[{"trackId":"t1","positionSeconds":-5,"listenedAtMs":null,"updatedAtMs":1700000000000}],"savedPhrases":[],"savedPhraseTombstones":[],"placement":[]}
        """
        assertRejected(Data(negative.utf8)) { error in
            if case ImportValidationError.invalidListenPosition(
                trackId: "t1", position: -5) = error {
                return true
            }
            return false
        }

        // A non-numeric position string such as "NaN" cannot decode as a
        // Double at all — rejected at the document layer.
        let nonNumeric = """
        {"app":"Condisco","formatVersion":1,"exportedAt":"2024-05-01T12:00:00Z","events":[],"checkpoints":[],"checkpointTombstones":[],"listenState":[{"trackId":"t1","positionSeconds":"NaN","listenedAtMs":null,"updatedAtMs":1700000000000}],"savedPhrases":[],"savedPhraseTombstones":[],"placement":[]}
        """
        assertRejected(Data(nonNumeric.utf8)) { error in
            if case ImportValidationError.malformedDocument = error { return true }
            return false
        }

        XCTAssertEqual(try Data(contentsOf: storeURL), bytesBefore)
        XCTAssertTrue(try store.allEvents().isEmpty)
    }

    // MARK: Catalog independence

    /// Events for a pack/lesson that is no longer bundled are well-formed
    /// historical data: the validator must NOT filter by the current
    /// catalog, and the import retains them untouched.
    func testEventForPackNotInBundleIsRetained() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let ghost = ActivityAttempt(
            id: "ghost-1", packId: "no-such-pack", packVersion: "1",
            lessonId: "no-such-lesson", lessonRevision: 1,
            stepId: "s", activityId: "a", activityRevision: 1,
            evidenceKey: nil, response: .text("x"), assistance: [],
            evaluation: AttemptEvaluation(
                outcome: .correct, independent: true, feedback: "f"),
            at: Date(timeIntervalSince1970: 1_700_000_000))

        let data = try encodeExport(events: [.attempt(ghost)])
        let preview = try requirePreview(data) // must not consult the catalog
        XCTAssertEqual(preview.events.count, 1)

        XCTAssertNoThrow(try store.applyImport(preview))
        XCTAssertEqual(try store.allEvents().map(\.id), ["ghost-1"])
        XCTAssertEqual(try store.learningEvents(packId: "no-such-pack").count, 1)
        XCTAssertTrue(try store.learningEvents(packId: pack.id).isEmpty)

        // The current bundle's projections are untouched by the ghost.
        let progress = try store.project(pack: pack)
        XCTAssertTrue(progress.evidence.isEmpty)
        XCTAssertTrue(progress.quarantined.isEmpty)
    }

    // MARK: Other rejections

    /// A file whose app marker is not Condisco is not our export.
    func testWrongAppMarkerRejected() throws {
        let json = """
        {"app":"SomeOtherApp","formatVersion":1,"exportedAt":"2024-05-01T12:00:00Z","events":[],"checkpoints":[],"checkpointTombstones":[],"listenState":[],"savedPhrases":[],"savedPhraseTombstones":[],"placement":[]}
        """
        assertRejected(Data(json.utf8)) { error in
            if case ImportValidationError.wrongApp("SomeOtherApp") = error {
                return true
            }
            return false
        }
    }

    /// The same event id twice in one export is corrupt, not dedupable.
    func testDuplicateEventIDsRejected() throws {
        let pack = try frenchPack()
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        let first = try makeAttempt(id: "dup-id", pack: pack, at: at)
        var second = first
        second.evaluation = AttemptEvaluation(
            outcome: .incorrect, independent: false, feedback: "different")

        let data = try encodeExport(events: [.attempt(first), .attempt(second)])
        assertRejected(data) { error in
            if case ImportValidationError.duplicateEventID("dup-id") = error {
                return true
            }
            return false
        }
    }

    /// A step completion that names an attempt the export does not contain
    /// (or that does not match) is internally inconsistent → rejected.
    func testDanglingStepCompletionRejected() throws {
        let pack = try frenchPack()
        let lesson = try XCTUnwrap(pack.lesson(id: "fr-home-foundation"))
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        let completion = StepCompletion(
            id: "comp-1", packId: pack.id, packVersion: pack.version,
            lessonId: lesson.id, lessonRevision: lesson.revision,
            stepId: "fr-home-foundation-step-rb2", selectedBranchId: nil,
            attemptId: "no-such-attempt", at: at)

        let data = try encodeExport(events: [.stepCompleted(completion)])
        assertRejected(data) { error in
            if case ImportValidationError.danglingStepCompletion("comp-1") = error {
                return true
            }
            return false
        }
    }
}

// MARK: - Review scope: Focus course / All courses (slice 2.3)
//
// The Review tab can narrow its queue to the focus course. These pin the
// scope contract: the default All-courses scope matches Home's all-courses
// due count; Focus reuses the same ReviewCatalog load path with a pack
// filter (no second scheduler, FSRS untouched); a verdict in focus scope
// reschedules only the reviewed evidence key; scope switches update counts
// in both directions; and every verdict still lands in the existing event
// log.

@MainActor
final class ReviewScopeTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("condisco-review-scope-tests-\(UUID().uuidString)")
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

    /// A non-focus pack: French is the focus course in these tests, so
    /// any other course stands in for "another pack".
    private func otherPack() throws -> CoursePack {
        try XCTUnwrap(
            PackLoader.loadPacks().first { $0.language != .french })
    }

    /// A valid independent-correct attempt on a real selection or cloze
    /// step of `pack`, dated in the past so FSRS schedules it due now:
    /// the exact shape lessons and the Review tab write, so it passes
    /// projection and resolves through `ReviewCatalog.makeItem`.
    private func makeDueAttempt(
        id: String, pack: CoursePack, at: Date
    ) throws -> ActivityAttempt {
        let lesson = try XCTUnwrap(
            pack.lessons.first { lesson in
                lesson.steps.contains { isChoiceStep($0, in: pack) }
            }, "\(pack.id) needs a lesson with a selection or cloze step")
        let step = try XCTUnwrap(
            lesson.steps.first { isChoiceStep($0, in: pack) })
        let activity = try XCTUnwrap(pack.activity(id: step.activityId))
        let response: AttemptResponse
        switch activity {
        case .selection(let spec):
            response = .selection(ids: spec.acceptedIds)
        case .cloze(let spec):
            response = .cloze(values: Dictionary(
                uniqueKeysWithValues: spec.blanks.map {
                    ($0.key, $0.value.answers.first ?? "")
                }))
        default:
            throw XCTSkip("expected a selection or cloze step")
        }
        return ActivityAttempt(
            id: id, packId: pack.id, packVersion: pack.version,
            lessonId: lesson.id, lessonRevision: lesson.revision,
            stepId: step.id, activityId: activity.id,
            activityRevision: activity.revision,
            evidenceKey: activity.evidenceKey,
            response: response,
            assistance: [],
            evaluation: AttemptEvaluation(
                outcome: .correct, independent: true, feedback: "correct"),
            at: at)
    }

    private func isChoiceStep(_ step: LessonStep, in pack: CoursePack) -> Bool {
        guard let activity = pack.activity(id: step.activityId) else { return false }
        if case .selection = activity { return true }
        if case .cloze = activity { return true }
        return false
    }

    /// The pack's first due review item, resolved the way the Review tab
    /// resolves it.
    private func dueItem(
        pack: CoursePack, store: LearningStore,
        file: StaticString = #filePath, line: UInt = #line
    ) throws -> ReviewItem {
        let due = try ReviewCatalog.loadDue(packs: [pack], store: store, now: Date())
        return try XCTUnwrap(
            due.due.first, "expected a due item for \(pack.id)",
            file: file, line: line)
    }

    // MARK: Mixed due queue across two packs

    /// Default All courses shows both packs' due cards; Focus filters to
    /// the focus pack only.
    func testMixedDueQueueAllShowsBothPacksFocusShowsOnlyFocus() throws {
        let store = try makeStore()
        let french = try frenchPack()
        let other = try otherPack()
        let at = Date(timeIntervalSince1970: 1_700_000_000)

        try store.record(.attempt(makeDueAttempt(id: "scope-mix-fr", pack: french, at: at)))
        try store.record(.attempt(makeDueAttempt(id: "scope-mix-other", pack: other, at: at)))

        let model = try ReviewModel(
            store: store, packs: [french, other], focusSlug: "french")
        XCTAssertEqual(model.scope, .all, "the Review tab must open on All courses")
        XCTAssertEqual(model.due.count, 2)
        XCTAssertEqual(Set(model.due.map(\.packId)), [french.id, other.id])

        model.scope = .focus
        model.applyScope()
        XCTAssertEqual(model.due.count, 1)
        XCTAssertEqual(model.due.map(\.packId), [french.id])
        XCTAssertEqual(model.due.first?.courseTitle, french.title)
    }

    // MARK: Honest empty state in focus scope

    /// No due cards in the focus course while another pack has them:
    /// Focus must show an honest empty queue (nothing due and no
    /// manufactured next date), while All courses still shows the cards.
    func testFocusScopeWithNoDueCardsShowsHonestEmptyQueue() throws {
        let store = try makeStore()
        let french = try frenchPack()
        let other = try otherPack()
        let at = Date(timeIntervalSince1970: 1_700_000_000)

        // Only the non-focus pack has evidence, all of it due.
        try store.record(.attempt(makeDueAttempt(id: "scope-other-only", pack: other, at: at)))

        let model = try ReviewModel(
            store: store, packs: [french, other], focusSlug: "french",
            scope: .focus)
        XCTAssertTrue(model.due.isEmpty,
                      "focus scope must not show another pack's due cards")
        XCTAssertNil(model.nextDueAt,
                     "with no focus-course evidence there is no next date to advertise")

        model.scope = .all
        model.applyScope()
        XCTAssertEqual(model.due.count, 1)
        XCTAssertEqual(model.due.map(\.packId), [other.id])
    }

    // MARK: Switching scope mid-visit

    /// Switching scope mid-visit updates the queue in both directions
    /// immediately: Focus → All reveals the other pack's cards, All →
    /// Focus hides them again.
    func testSwitchingScopeMidVisitUpdatesCountsBothDirections() throws {
        let store = try makeStore()
        let french = try frenchPack()
        let other = try otherPack()
        let at = Date(timeIntervalSince1970: 1_700_000_000)

        try store.record(.attempt(makeDueAttempt(id: "scope-switch-fr", pack: french, at: at)))
        try store.record(.attempt(makeDueAttempt(id: "scope-switch-other", pack: other, at: at)))

        let model = try ReviewModel(
            store: store, packs: [french, other], focusSlug: "french")
        XCTAssertEqual(model.due.count, 2)

        model.scope = .focus
        model.applyScope()
        XCTAssertEqual(model.due.count, 1)
        XCTAssertEqual(model.due.map(\.packId), [french.id])

        model.scope = .all
        model.applyScope()
        XCTAssertEqual(model.due.count, 2)
        XCTAssertEqual(Set(model.due.map(\.packId)), [french.id, other.id])
    }

    // MARK: Verdicts stay pack-scoped

    /// A verdict recorded in focus scope reschedules only the reviewed
    /// evidence key: the focus pack's queue drops the card, the other
    /// pack's due count is unchanged.
    func testVerdictInFocusScopeUpdatesOnlyFocusPackDueState() throws {
        let store = try makeStore()
        let french = try frenchPack()
        let other = try otherPack()
        let at = Date(timeIntervalSince1970: 1_700_000_000)

        try store.record(.attempt(makeDueAttempt(id: "scope-verdict-fr", pack: french, at: at)))
        try store.record(.attempt(makeDueAttempt(id: "scope-verdict-other", pack: other, at: at)))
        let otherKey = try XCTUnwrap(
            ReviewCatalog.loadDue(packs: [other], store: store, now: Date())
                .due.first?.evidenceKey)

        // The focus queue's first card, then the verdict through the same
        // path `ReviewModel.recordVerdict` uses (store.record of the
        // item's attempt) minus the widget snapshot write.
        let item = try dueItem(pack: french, store: store)
        try store.record(.attempt(item.makeAttempt(verdict: .exact, at: Date())))

        // The reviewed card left the focus queue (FSRS rescheduled it out
        // of "due") and the other pack's due count is untouched.
        let frenchDue = try ReviewCatalog.loadDue(packs: [french], store: store, now: Date())
        XCTAssertTrue(frenchDue.due.isEmpty,
                      "the reviewed card must leave the focus pack's due queue")
        let otherDue = try ReviewCatalog.loadDue(packs: [other], store: store, now: Date())
        XCTAssertEqual(otherDue.due.count, 1,
                       "reviewing a focus card must not remove another pack's due card")
        XCTAssertEqual(otherDue.due.first?.evidenceKey, otherKey)
    }

    // MARK: Event log and FSRS untouched

    /// The reviewed card still records through the existing event log:
    /// the verdict creates a second attempt event for the same evidence
    /// key, and the stock scheduler reschedules it (reps advance, the
    /// card leaves "due").
    func testVerdictRecordsThroughExistingEventLogWithFsrsReschedule() throws {
        let store = try makeStore()
        let french = try frenchPack()
        let at = Date(timeIntervalSince1970: 1_700_000_000)

        try store.record(.attempt(makeDueAttempt(id: "scope-log-fr", pack: french, at: at)))
        let item = try dueItem(pack: french, store: store)

        try store.record(.attempt(item.makeAttempt(verdict: .close, at: Date())))

        // The append-only event log holds the seed and the verdict.
        let events = try store.learningEvents(packId: french.id)
        let attempts = events.compactMap { event -> ActivityAttempt? in
            guard case .attempt(let attempt) = event else { return nil }
            return attempt
        }
        XCTAssertEqual(attempts.count, 2)
        let verdictEvent = try XCTUnwrap(attempts.last)
        XCTAssertEqual(verdictEvent.evidenceKey, item.evidenceKey)
        XCTAssertEqual(verdictEvent.response, ReviewVerdict.close.response)

        // The stock scheduler rescheduled the reviewed evidence key.
        let record = try XCTUnwrap(store.project(pack: french).evidence[item.evidenceKey])
        XCTAssertEqual(record.fsrs.reps, 2)
        XCTAssertGreaterThan(
            record.fsrs.dueAt, Date(),
            "a fresh verdict must schedule the card out of 'due'")
    }

    // MARK: Home invitation entry resets scope

    /// Entering Review via Home's Today invitation must reset a narrowed
    /// focus scope to All courses, so the queue Home's all-courses count
    /// opens stays in agreement with the count it displayed. The callback
    /// ContentView's Home invitation handler posts
    /// `.condiscoReviewHomeEntry`; the Review tab observes it and calls
    /// this method.
    func testHomeInvitationEntryResetsNarrowedScopeToAllCourses() throws {
        let store = try makeStore()
        let french = try frenchPack()
        let other = try otherPack()
        let at = Date(timeIntervalSince1970: 1_700_000_000)

        try store.record(.attempt(makeDueAttempt(id: "scope-home-fr", pack: french, at: at)))
        try store.record(.attempt(makeDueAttempt(id: "scope-home-other", pack: other, at: at)))

        // The learner had narrowed the tab to the focus course...
        let model = try ReviewModel(
            store: store, packs: [french, other], focusSlug: "french",
            scope: .focus)
        XCTAssertEqual(model.scope, .focus)
        XCTAssertEqual(model.due.count, 1)

        // ...then tapped Home's Today invitation.
        model.resetScopeForHomeInvitation()

        XCTAssertEqual(model.scope, .all,
                       "Home's invitation must open Review on All courses")
        XCTAssertEqual(model.due.count, 2,
                       "the full all-courses queue returns after the reset")
        XCTAssertEqual(Set(model.due.map(\.packId)), [french.id, other.id],
                       "the reset queue must include every course, not just the focus one")
    }
}

// MARK: - Practice by skill and evidence categories (5.2A)
//
// Slice 5.2A tracks practice by skill and by how independently it was
// done. Evidence categories derive from what the attempt events already
// record — response kind (typed vs picked vs self-rated review), the
// `independent` flag, and review timing — with NO new payload field, so
// old databases replay conservatively and event ids/export bytes are
// untouched. These drills pin the replay rules (old-only, and mixed
// old + new), the category distinctions (assisted vs independent,
// recognition vs production, recalled later vs same-session), and the
// per-skill profile projection for the focus language.

@MainActor
final class PracticeProfileTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("condisco-practice-profile-tests-\(UUID().uuidString)")
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

    private func makeStore(named name: String) throws -> LearningStore {
        try LearningStore(path: tempDir.appendingPathComponent(name).path)
    }

    private func frenchPack() throws -> CoursePack {
        try XCTUnwrap(
            PackLoader.loadPacks().first { $0.language == .french })
    }

    private func spanishPack() throws -> CoursePack {
        try XCTUnwrap(
            PackLoader.loadPacks().first { $0.language == .spanish },
            "the focus-language profile is developed against Spanish")
    }

    /// The exercise ids a legacy-success lesson requires, from the live
    /// pack — the same ids the projection's legacy-credit check reads.
    private func legacyExerciseIds(
        _ lessonId: String, in pack: CoursePack
    ) throws -> [String] {
        let lesson = try XCTUnwrap(pack.lesson(id: lessonId))
        guard case .legacySuccess(let ids) = lesson.completionPolicy,
              !ids.isEmpty
        else {
            throw XCTSkip("\(lessonId) must be a legacy-success lesson")
        }
        return ids
    }

    /// A valid independent-correct selection attempt on the first
    /// practice step of fr-home-foundation — the recognition kind of
    /// attempt, and the shape a pre-5.2 build wrote.
    private func makeSelectionAttempt(
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

    /// A valid independent-correct cloze attempt on fr-home-foundation
    /// step rb7 — production kind, no help.
    private func makeClozeAttempt(
        id: String, pack: CoursePack, at: Date
    ) throws -> ActivityAttempt {
        let lesson = try XCTUnwrap(pack.lesson(id: "fr-home-foundation"))
        let step = try XCTUnwrap(
            lesson.steps.first { $0.id == "fr-home-foundation-step-rb7" })
        let activity = try XCTUnwrap(pack.activity(id: step.activityId))
        guard case .cloze(let spec) = activity else {
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
            response: .cloze(values: Dictionary(
                uniqueKeysWithValues: spec.blanks.map {
                    ($0.key, $0.value.answers.first ?? "")
                })),
            assistance: [],
            evaluation: AttemptEvaluation(
                outcome: .correct, independent: true, feedback: "correct"),
            at: at)
    }

    /// A valid independent-correct text attempt on fr-home-foundation
    /// step rb8 (typed production, no help).
    private func makeTextAttempt(
        id: String, pack: CoursePack, at: Date
    ) throws -> ActivityAttempt {
        let lesson = try XCTUnwrap(pack.lesson(id: "fr-home-foundation"))
        let step = try XCTUnwrap(
            lesson.steps.first { $0.id == "fr-home-foundation-step-rb8" })
        let activity = try XCTUnwrap(pack.activity(id: step.activityId))
        guard case .text(let spec) = activity else {
            throw XCTSkip("expected a text activity")
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
            response: .text(spec.answer.answers.first ?? ""),
            assistance: [],
            evaluation: AttemptEvaluation(
                outcome: .correct, independent: true, feedback: "correct"),
            at: at)
    }

    /// A valid attempt against a real Spanish activity, resolved by
    /// activity id, with the correctly authored response per kind — the
    /// fixture builder for the focus-language (Spanish) profile test.
    private func esAttempt(
        id: String, pack: CoursePack, activityId: String, at: Date,
        outcome: AttemptEvaluation.Outcome = .correct,
        independent: Bool = true
    ) throws -> ActivityAttempt {
        guard let lesson = pack.lessons.first(where: { lesson in
            lesson.steps.contains { $0.activityId == activityId }
        }) else {
            throw XCTSkip("no Spanish lesson hosts \(activityId)")
        }
        let step = try XCTUnwrap(lesson.steps.first { $0.activityId == activityId })
        let activity = try XCTUnwrap(pack.activity(id: step.activityId))
        let response: AttemptResponse
        switch activity {
        case .selection(let spec):
            response = .selection(ids: spec.acceptedIds)
        case .dialogueChoice(let spec):
            response = .selection(ids: spec.acceptedIds)
        case .sceneSelection(let spec):
            response = .selection(ids: spec.acceptedRegionIds)
        case .ordering(let spec):
            guard let order = spec.acceptedOrders.first else {
                throw XCTSkip("\(activityId) has no accepted order")
            }
            response = .ordering(ids: order)
        case .matching(let spec):
            response = .matching(pairs: spec.acceptedPairs.map {
                ResponsePair(leftId: $0.leftId, rightId: $0.rightId)
            })
        case .cloze(let spec):
            response = .cloze(values: Dictionary(
                uniqueKeysWithValues: spec.blanks.map {
                    ($0.key, $0.value.answers.first ?? "")
                }))
        case .text(let spec):
            response = .text(spec.answer.answers.first ?? "")
        default:
            throw XCTSkip("unsupported Spanish activity kind for \(activityId)")
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
            response: response,
            assistance: [],
            evaluation: AttemptEvaluation(
                outcome: outcome, independent: independent, feedback: "correct"),
            at: at)
    }

    // MARK: Old-database replay

    /// Replaying ONLY old-shape events must produce the old progress plus
    /// conservative categories — never invented mastery. The v1 history
    /// still hands out its legacy completion credit, the old-shape v2
    /// selection attempt still projects evidence, and the selection-only
    /// data can only ever prove recognition: no key may claim independent
    /// production, production with help, or recalled-later recall.
    func testOldDatabaseReplayYieldsOldProgressAndConservativeCategories() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        // The old shape of history: v1 practice events (no response kind,
        // no independence flag, no evidence key) granting the lesson's
        // legacy credit, exactly as a previous build wrote them.
        let legacyIds = try legacyExerciseIds("fr-identity-foundation", in: pack)
        for (i, exerciseId) in legacyIds.enumerated() {
            try store.record(.practiceV1(PracticeEventV1(
                id: "replay-v1-\(i)", packId: pack.id, version: "0.9.0",
                exerciseId: exerciseId,
                at: base.addingTimeInterval(Double(i)),
                correct: true, revealed: false)))
        }
        // An old-shape v2 attempt under the previous release's pack
        // version — selection-only data.
        var oldSelection = try makeSelectionAttempt(
            id: "replay-v2-selection", pack: pack,
            at: base.addingTimeInterval(500))
        oldSelection.packVersion = "0.9.0"
        try store.record(.attempt(oldSelection))

        let progress = try store.project(pack: pack)
        XCTAssertTrue(progress.quarantined.isEmpty)

        // Old progress is preserved exactly as before this slice.
        XCTAssertTrue(progress.legacyCredits.contains("fr-identity-foundation"))
        let key = try XCTUnwrap(oldSelection.evidenceKey)
        XCTAssertEqual(progress.evidence[key]?.successes, 1)

        // Conservative categories: selection data proves recognition at
        // most. V1 rows carry no evidence key, so they contribute no
        // category at all — and nothing anywhere claims production.
        let categories = try XCTUnwrap(progress.evidenceCategories[key])
        XCTAssertEqual(categories, [.recognized])
        XCTAssertTrue(progress.evidenceCategories.values.allSatisfy {
            !$0.contains(.producedIndependently)
                && !$0.contains(.producedWithHelp)
                && !$0.contains(.recalledLater)
        })
    }

    // MARK: Mixed old + new

    /// Old and new events in one store both count: v1 legacy credit, an
    /// old-shape selection attempt, a new independent cloze production,
    /// and a new assisted text production project together without a
    /// crash, each key landing exactly the category its recorded fields
    /// support.
    func testMixedOldAndNewEventsBothCountWithCorrectCategories() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        let legacyIds = try legacyExerciseIds("fr-identity-foundation", in: pack)
        for (i, exerciseId) in legacyIds.enumerated() {
            try store.record(.practiceV1(PracticeEventV1(
                id: "mix-v1-\(i)", packId: pack.id, version: "0.9.0",
                exerciseId: exerciseId,
                at: base.addingTimeInterval(Double(i)),
                correct: true, revealed: false)))
        }

        var selection = try makeSelectionAttempt(
            id: "mix-selection", pack: pack, at: base.addingTimeInterval(600))
        selection.packVersion = "0.9.0"
        try store.record(.attempt(selection))

        let cloze = try makeClozeAttempt(
            id: "mix-cloze", pack: pack, at: base.addingTimeInterval(700))
        try store.record(.attempt(cloze))

        var assistedText = try makeTextAttempt(
            id: "mix-text", pack: pack, at: base.addingTimeInterval(800))
        assistedText.assistance = [.model]
        assistedText.evaluation = AttemptEvaluation(
            outcome: .correct, independent: false, feedback: "correct")
        try store.record(.attempt(assistedText))

        let progress = try store.project(pack: pack)
        XCTAssertTrue(progress.quarantined.isEmpty)

        // Old and new progress both count.
        XCTAssertTrue(progress.legacyCredits.contains("fr-identity-foundation"))
        XCTAssertEqual(progress.evidence.count, 3)

        // Categories are exactly what each event shape supports.
        let selKey = try XCTUnwrap(selection.evidenceKey)
        let clozeKey = try XCTUnwrap(cloze.evidenceKey)
        let textKey = try XCTUnwrap(assistedText.evidenceKey)
        XCTAssertEqual(try XCTUnwrap(progress.evidenceCategories[selKey]),
                       [.recognized])
        XCTAssertEqual(try XCTUnwrap(progress.evidenceCategories[clozeKey]),
                       [.producedIndependently])
        XCTAssertEqual(try XCTUnwrap(progress.evidenceCategories[textKey]),
                       [.producedWithHelp])

        // SRS state is untouched by the category derivation: clean
        // successes count, assisted correct work counts as a failure.
        XCTAssertEqual(progress.evidence[selKey]?.successes, 1)
        XCTAssertEqual(progress.evidence[clozeKey]?.successes, 1)
        XCTAssertEqual(progress.evidence[textKey]?.successes, 0)
        XCTAssertEqual(progress.evidence[textKey]?.failures, 1)
    }

    // MARK: Assisted vs independent

    /// Assisted and independent attempts land distinct categories: the
    /// same cloze key practised first with help and later cleanly carries
    /// BOTH categories, while an assisted-correct selection stays "seen"
    /// — recognition proof requires the clean success the SRS counts.
    func testAssistedVersusIndependentAttemptsGetDistinctCategories() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        var helped = try makeClozeAttempt(
            id: "assist-helped", pack: pack, at: base)
        helped.assistance = [.hint]
        helped.evaluation = AttemptEvaluation(
            outcome: .correct, independent: false, feedback: "correct")
        try store.record(.attempt(helped))

        let clean = try makeClozeAttempt(
            id: "assist-clean", pack: pack, at: base.addingTimeInterval(10))
        try store.record(.attempt(clean))

        var hintSelection = try makeSelectionAttempt(
            id: "assist-selection", pack: pack, at: base.addingTimeInterval(20))
        hintSelection.assistance = [.translation]
        hintSelection.evaluation = AttemptEvaluation(
            outcome: .correct, independent: false, feedback: "correct")
        try store.record(.attempt(hintSelection))

        let progress = try store.project(pack: pack)
        let clozeKey = try XCTUnwrap(clean.evidenceKey)
        XCTAssertEqual(try XCTUnwrap(progress.evidenceCategories[clozeKey]),
                       [.producedWithHelp, .producedIndependently])
        let selKey = try XCTUnwrap(hintSelection.evidenceKey)
        XCTAssertEqual(try XCTUnwrap(progress.evidenceCategories[selKey]),
                       [.seen])
        XCTAssertFalse(progress.evidenceCategories[selKey]?.contains(.recognized) ?? true)
    }

    // MARK: Recalled later

    /// "Recalled later" — the rule as implemented: a clean, unassisted
    /// review (Review tab or warm-up) on an evidence key at least one
    /// full day (86,400 s) after the key's first independent production.
    /// A same-session review never counts.
    func testRecalledLaterRequiresFullDayGap() throws {
        let pack = try frenchPack()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let dayGapStore = try makeStore(named: "recall-daygap.sqlite")

        // Day 0: first independent production.
        let production = try makeClozeAttempt(
            id: "recall-prod", pack: pack, at: base)
        try dayGapStore.record(.attempt(production))
        let key = try XCTUnwrap(production.evidenceKey)

        // Day 2: a clean review, resolved the way the Review tab resolves
        // it, recorded through the same event pipeline.
        let item = try XCTUnwrap(ReviewCatalog.makeItem(
            pack: pack, evidenceKey: key, dueAt: base))
        try dayGapStore.record(.attempt(item.makeAttempt(
            verdict: .exact, at: base.addingTimeInterval(2 * 86_400))))

        let gapProgress = try dayGapStore.project(pack: pack)
        XCTAssertEqual(try XCTUnwrap(gapProgress.evidenceCategories[key]),
                       [.producedIndependently, .recalledLater])
        // The category derivation never disturbs the scheduler.
        XCTAssertEqual(gapProgress.evidence[key]?.fsrs.reps, 2)

        // Same-session review: production and a clean review hours later
        // keep production proof only — no recalled-later claim.
        let sameDayStore = try makeStore(named: "recall-sameday.sqlite")
        let production2 = try makeClozeAttempt(
            id: "recall-prod2", pack: pack, at: base)
        try sameDayStore.record(.attempt(production2))
        let item2 = try XCTUnwrap(ReviewCatalog.makeItem(
            pack: pack, evidenceKey: key, dueAt: base))
        try sameDayStore.record(.attempt(item2.makeAttempt(
            verdict: .exact, at: base.addingTimeInterval(3_600))))

        let sameDayProgress = try sameDayStore.project(pack: pack)
        XCTAssertEqual(try XCTUnwrap(sameDayProgress.evidenceCategories[key]),
                       [.producedIndependently])
    }

    // MARK: Profile projection (focus language — Spanish)

    /// The per-skill practice profile for Spanish: every row's practised
    /// count, staleness, and due count match the recorded attempts, the
    /// suggestion names the most-due skill, and with nothing due it falls
    /// back to the stalest practised skill. The profile is per-skill rows
    /// only — no combined score exists, so reading being ahead of
    /// listening (or here, listening having no practice at all) shows
    /// honestly row by row.
    func testProfileProjectionMixedSkillSpanishFixture() throws {
        let store = try makeStore()
        let pack = try spanishPack()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let day: TimeInterval = 86_400

        // reading + vocabulary (selection) — day 0
        try store.record(.attempt(try esAttempt(
            id: "es-read", pack: pack,
            activityId: "es-introductions-foundation-notice", at: base)))
        // vocabulary + writing (text) — day 3
        try store.record(.attempt(try esAttempt(
            id: "es-vocab-write", pack: pack,
            activityId: "es-cafe-mission-act-7",
            at: base.addingTimeInterval(3 * day))))
        // grammar + writing (cloze) — day 1
        try store.record(.attempt(try esAttempt(
            id: "es-grammar-write", pack: pack,
            activityId: "es-directions-foundation-cloze",
            at: base.addingTimeInterval(day))))
        // grammar + writing (ordering) — day 4
        try store.record(.attempt(try esAttempt(
            id: "es-grammar-write2", pack: pack,
            activityId: "es-cafe-mission-act-4",
            at: base.addingTimeInterval(4 * day))))
        // speaking + writing (text) — day 6
        try store.record(.attempt(try esAttempt(
            id: "es-speaking", pack: pack,
            activityId: "es-cafe-mission-act-9",
            at: base.addingTimeInterval(6 * day))))

        let now = base.addingTimeInterval(12 * day)
        let due = try ReviewCatalog.loadDue(
            packs: [pack], store: store, now: now).due
        let events = try store.learningEventsWithQuarantine(
            packId: pack.id).events
        let practice = YouModel.skillPractice(
            pack: pack, events: events, dueItems: due)

        func row(_ skill: Skill) -> YouModel.SkillPractice {
            practice.first { $0.skill == skill }!
        }

        // Writing was practised four times (act-7 day 3, cloze day 1,
        // ordering day 4, mission act-9 day 6 — act-9 is writing +
        // speaking in the pack); last practised day 6; four due cards.
        XCTAssertEqual(row(.writing).practisedTimes, 4)
        XCTAssertEqual(row(.writing).lastPractisedAt,
                       base.addingTimeInterval(6 * day))
        XCTAssertEqual(row(.writing).dueCount, 4)
        // Reading practised once on day 0 — the stalest practised skill.
        XCTAssertEqual(row(.reading).practisedTimes, 1)
        XCTAssertEqual(row(.reading).lastPractisedAt, base)
        XCTAssertEqual(row(.reading).dueCount, 1)
        // Vocabulary: notice (day 0) + act-7 (day 3).
        XCTAssertEqual(row(.vocabulary).practisedTimes, 2)
        XCTAssertEqual(row(.vocabulary).lastPractisedAt,
                       base.addingTimeInterval(3 * day))
        XCTAssertEqual(row(.vocabulary).dueCount, 2)
        // Grammar: cloze (day 1) + ordering (day 4).
        XCTAssertEqual(row(.grammar).practisedTimes, 2)
        XCTAssertEqual(row(.grammar).lastPractisedAt,
                       base.addingTimeInterval(4 * day))
        XCTAssertEqual(row(.grammar).dueCount, 2)
        // Speaking practised once on day 6; listening has NO practice at
        // all — the divergence the profile shows honestly, row by row.
        XCTAssertEqual(row(.speaking).practisedTimes, 1)
        XCTAssertEqual(row(.speaking).lastPractisedAt,
                       base.addingTimeInterval(6 * day))
        XCTAssertEqual(row(.speaking).dueCount, 1)
        XCTAssertEqual(row(.listening).practisedTimes, 0)
        XCTAssertNil(row(.listening).lastPractisedAt)
        XCTAssertEqual(row(.listening).dueCount, 0)

        // Six per-skill rows, six distinct skills: there is no combined
        // or overall score anywhere in the profile.
        XCTAssertEqual(practice.count, 6)
        XCTAssertEqual(Set(practice.map(\.skill)).count, 6)

        // The suggestion names the most-due skill (writing: 4 cards).
        let suggestion = try XCTUnwrap(
            YouModel.suggestedNextTask(in: practice))
        XCTAssertEqual(suggestion, "Review 4 writing cards")

        // With no due cards at all, the suggestion falls back to the
        // stalest practised skill and says plainly why.
        let earlyNow = base.addingTimeInterval(0.5 * day)
        let notDue = try ReviewCatalog.loadDue(
            packs: [pack], store: store, now: earlyNow).due
        XCTAssertTrue(notDue.isEmpty)
        let stalePractice = YouModel.skillPractice(
            pack: pack, events: events, dueItems: notDue)
        let staleSuggestion = try XCTUnwrap(
            YouModel.suggestedNextTask(in: stalePractice))
        XCTAssertEqual(staleSuggestion, "Practise reading — no reviews due")
    }
}

// MARK: - Changed-context review cues (phase 5.2B)
//
// A due card's cue rotates among the *authored* cue texts of its activity
// — the lesson prompt, then the authored hint — seeded by the key's
// completed-review count (FSRS `reps`, or the equivalent per-key rated
// attempt count in the tricky pass), so no new state is persisted. These
// pin the contract: consecutive presentations of a multi-cue key cover
// every variant deterministically before repeating; a single-cue key
// always shows its one cue; rotation never disturbs FSRS (same evidence
// key, same due time, same reps advancement as an unrotated review); and
// a rotated cue is identical per card in focus and all scopes.

@MainActor
final class ReviewCueRotationTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("condisco-review-cue-tests-\(UUID().uuidString)")
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

    /// A real two-cue evidence key: the café greeting selection, whose
    /// activity authors both a prompt and a hint. If the pack ever drops
    /// the hint, the unwrap fails loudly instead of silently skipping.
    private func multiCueFixture(
        pack: CoursePack
    ) throws -> (key: String, prompt: String, hint: String) {
        let activity = try XCTUnwrap(
            pack.activities.first { $0.evidenceKey == "fr-cafe-mission-act-2" })
        let base = try XCTUnwrap(activity.base)
        return (
            try XCTUnwrap(activity.evidenceKey),
            base.prompt,
            try XCTUnwrap(base.hints.first))
    }

    /// A valid independent-correct attempt on the fixture activity, the
    /// exact shape lessons write (so it passes projection).
    private func attempt(
        id: String, pack: CoursePack, activity: Activity, key: String, at: Date
    ) throws -> ActivityAttempt {
        let lesson = try XCTUnwrap(
            pack.lessons.first { lesson in
                lesson.steps.contains { $0.activityId == activity.id }
            })
        let step = try XCTUnwrap(
            lesson.steps.first { $0.activityId == activity.id })
        guard case .selection(let spec) = activity else {
            throw XCTSkip("fixture expected a selection activity")
        }
        return ActivityAttempt(
            id: id, packId: pack.id, packVersion: pack.version,
            lessonId: lesson.id, lessonRevision: lesson.revision,
            stepId: step.id, activityId: activity.id,
            activityRevision: activity.revision,
            evidenceKey: key,
            response: .selection(ids: spec.acceptedIds),
            assistance: [],
            evaluation: AttemptEvaluation(
                outcome: .correct, independent: true, feedback: "correct"),
            at: at)
    }

    /// A schema-valid pack whose only activity ships a single authored
    /// cue (prompt, no hint): the graceful-degradation fixture.
    private func singleCuePack() throws -> CoursePack {
        let json = """
        {"schemaVersion":2,"id":"cue-single","version":"1.0.0","language":"fr","status":"active","title":"Single cue","sourceLanguage":"en","description":"d","attribution":"a",
        "units":[{"id":"u1","title":"Unit","objective":"Objective"}],
        "concepts":[{"id":"c1","title":"Concept","explanation":"Explanation","examples":[],"commonError":""}],
        "vocabulary":[{"id":"v1","word":"Anna","meaning":"Anna","partOfSpeech":"noun","example":"Anna"}],
        "media":[],"stimuli":[],
        "activities":[{"kind":"text","id":"act-single","revision":1,"conceptIds":["c1"],"vocabulary":["v1"],"skills":["writing"],"stimulusId":null,
          "prompt":"Write in French: I am Anna.","hints":[],"feedback":"Je suis Anna.","evidenceKey":"cue-single-key","assistanceAffectsEvidence":["hint","model"],
          "answer":{"answers":["Je suis Anna."],"allowTypo":true,"errors":[]}}],
        "lessons":[{"id":"l1","unitId":"u1","title":"Lesson","objective":"Objective","cefr":"A1","family":"discovery","revision":1,"estimatedMinutes":5,
          "entryStepId":"s1",
          "steps":[{"id":"s1","purpose":"practice","activityId":"act-single","required":true}],
          "completionPolicy":{"kind":"participation"},"prerequisites":[],"conceptIds":["c1"],"vocabulary":[],"legacyExercises":[]}],
        "dialogues":[]}
        """
        return try JSONDecoder().decode(CoursePack.self, from: Data(json.utf8))
    }

    // MARK: Rotation scheme

    /// Consecutive presentations (ordinals 0, 1, 2, …) of a two-cue key
    /// alternate deterministically: prompt, hint, prompt, hint — covering
    /// both variants before the cycle repeats — while the item's identity
    /// and due time never move. Ordinal 0 (the default) is the authored
    /// lesson prompt.
    func testMultiCueKeyCoversAllVariantsBeforeRepeating() throws {
        let pack = try frenchPack()
        let (key, prompt, hint) = try multiCueFixture(pack: pack)
        let dueAt = Date(timeIntervalSince1970: 1_700_000_000)

        let items = try (0..<6).map { ordinal -> ReviewItem in
            try XCTUnwrap(ReviewCatalog.makeItem(
                pack: pack, evidenceKey: key, dueAt: dueAt,
                presentationOrdinal: ordinal))
        }
        XCTAssertEqual(items.map(\.prompt),
                       [prompt, hint, prompt, hint, prompt, hint])
        // Rotation only changes which cue text shows: same key, same due.
        XCTAssertEqual(Set(items.map(\.evidenceKey)), [key])
        XCTAssertEqual(Set(items.map(\.dueAt)), [dueAt])
        // Callers that don't pass an ordinal keep the lesson prompt.
        let defaultItem = try XCTUnwrap(ReviewCatalog.makeItem(
            pack: pack, evidenceKey: key, dueAt: dueAt))
        XCTAssertEqual(defaultItem.prompt, prompt)
    }

    /// A key whose activity authors exactly one cue shows that same cue at
    /// every presentation — no crash, no invented text.
    func testSingleCueKeyAlwaysShowsTheOneAuthoredCue() throws {
        let pack = try singleCuePack()
        let dueAt = Date(timeIntervalSince1970: 1_700_000_000)
        for ordinal in 0..<6 {
            let item = try XCTUnwrap(ReviewCatalog.makeItem(
                pack: pack, evidenceKey: "cue-single-key", dueAt: dueAt,
                presentationOrdinal: ordinal))
            XCTAssertEqual(item.prompt, "Write in French: I am Anna.",
                           "presentation \(ordinal) must keep the one authored cue")
        }
        let defaultItem = try XCTUnwrap(ReviewCatalog.makeItem(
            pack: pack, evidenceKey: "cue-single-key", dueAt: dueAt))
        XCTAssertEqual(defaultItem.prompt, "Write in French: I am Anna.")
    }

    // MARK: Scheduling stays FSRS

    /// End to end through the real load path: a lesson attempt followed by
    /// three reviews of a two-cue key shows hint, prompt, hint — the
    /// rotation seeded by FSRS `reps`. Every cue swap keeps the same
    /// evidence key, reps advance exactly one per verdict, and each next
    /// due is the canonical FSRS projection (reviewedAt + intervalDays):
    /// the rotation never moves or reschedules anything.
    ///
    /// FSRS's canonical ±5% interval fuzz is rolled fresh by every
    /// projection, so the test never compares two separately projected due
    /// dates for equality: each review loads at the projection's own due
    /// widened beyond one fuzz window, records the verdict at the card's
    /// own due moment (one shared clock), and asserts the schedule via
    /// facts the fuzz cannot move — reps, the rotated cue at each ordinal,
    /// and dueAt == lastReviewedAt + intervalDays inside one projection.
    func testDueLoadRotatesCuesWhileSchedulingStaysFSRS() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let (key, prompt, hint) = try multiCueFixture(pack: pack)
        let activity = try XCTUnwrap(
            pack.activities.first { $0.evidenceKey == key })
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let day: TimeInterval = 86_400

        // Lesson presentation: the authored prompt is the lesson cue.
        try store.record(.attempt(try attempt(
            id: "cue-lesson", pack: pack, activity: activity, key: key, at: base)))

        func dueItem(now: Date) throws -> ReviewItem {
            let due = try ReviewCatalog.loadDue(
                packs: [pack], store: store, now: now).due
            return try XCTUnwrap(
                due.first { $0.evidenceKey == key },
                "expected the fixture key due")
        }

        // Three reviews, each at its own due moment. The projection held
        // before the review gives the due window: the card becomes due at
        // the projection's due plus its interval now that the review is
        // recorded, and a re-projection inside loadDue can roll that same
        // interval up to one signed fuzz window away — so load at the
        // projection's due plus a bracket wider than the whole window.
        var record = try XCTUnwrap(store.project(pack: pack).evidence[key])
        var expectedCue = hint
        for ordinal in 1...3 {
            XCTAssertEqual(
                record.fsrs.reps, ordinal,
                "reps must equal the rated-attempt count seeding the rotation")
            let window = (1.5 * Double(record.fsrs.intervalDays) + 10) * day
            let item = try dueItem(
                now: record.fsrs.dueAt.addingTimeInterval(window))
            XCTAssertEqual(item.evidenceKey, key)
            XCTAssertEqual(item.prompt, expectedCue,
                           "presentation \(ordinal) must show the reps-derived cue")
            // The rotated cue rides on the projected due time — untouched:
            // its due is the same projection's due, within one fuzz window.
            XCTAssertLessThanOrEqual(
                abs(item.dueAt.timeIntervalSince(record.fsrs.dueAt)),
                (0.2 * Double(record.fsrs.intervalDays) + 4) * day + 1,
                "the rotated item must keep the schedule's due time")
            try store.record(.attempt(
                item.makeAttempt(verdict: .exact, at: item.dueAt)))
            record = try XCTUnwrap(store.project(pack: pack).evidence[key])
            // The next due is the canonical FSRS projection of the review
            // just recorded: reviewedAt + intervalDays, nothing added or
            // delayed by the rotation.
            XCTAssertEqual(record.fsrs.lastReviewedAt, item.dueAt)
            XCTAssertEqual(
                record.fsrs.dueAt.timeIntervalSince1970,
                item.dueAt.timeIntervalSince1970
                    + Double(record.fsrs.intervalDays) * day)
            expectedCue = ordinal % 2 == 1 ? prompt : hint
        }
        // The queue holds exactly the one key, rescheduled by FSRS alone:
        // reps == rated attempts (1 lesson + 3 reviews).
        XCTAssertEqual(record.fsrs.reps, 4)

        // Every written event is the same item under a rotated cue: the
        // attempt carries the key and activity ids — never the cue text.
        let attempts = try store.learningEvents(packId: pack.id).compactMap {
            event -> ActivityAttempt? in
            guard case .attempt(let a) = event,
                  a.activityId == activity.id else { return nil }
            return a
        }
        XCTAssertEqual(attempts.count, 4)
        XCTAssertTrue(attempts.allSatisfy { $0.evidenceKey == key })
        XCTAssertTrue(attempts.allSatisfy { $0.evaluation.outcome == .correct })
    }

    // MARK: Tricky pass

    /// The tricky pass rotates on the same natural counter as the due pass
    /// (per-key rated attempt count): after a lesson attempt and a "not
    /// yet" review the tricky card shows the ordinal-2 cue — the same cue
    /// the due pass would show at reps 2.
    func testTrickyPassCueRotatesOnAttemptCount() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let (key, prompt, hint) = try multiCueFixture(pack: pack)
        let activity = try XCTUnwrap(
            pack.activities.first { $0.evidenceKey == key })
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        try store.record(.attempt(try attempt(
            id: "tricky-lesson", pack: pack, activity: activity, key: key, at: base)))
        let dueAt = try XCTUnwrap(
            store.project(pack: pack).evidence[key]?.fsrs.dueAt)
        // The learner flags the first review (ordinal 1 → hint) "not yet".
        let due = try ReviewCatalog.loadDue(
            packs: [pack], store: store, now: dueAt.addingTimeInterval(1))
        let firstReview = try XCTUnwrap(due.due.first { $0.evidenceKey == key })
        XCTAssertEqual(firstReview.prompt, hint)
        try store.record(.attempt(
            firstReview.makeAttempt(verdict: .tryAgain, at: dueAt)))

        let tricky = try ReviewCatalog.loadTricky(packs: [pack], store: store)
        let trickyItem = try XCTUnwrap(tricky.first { $0.evidenceKey == key })
        // Two rated attempts → ordinal 2 → the prompt, exactly as the due
        // pass would present it at reps 2.
        XCTAssertEqual(trickyItem.prompt, prompt)
        XCTAssertEqual(trickyItem.evidenceKey, key)
    }

    // MARK: Scope parity

    /// The same rotated card, per key, in focus and all scopes: identical
    /// cue, evidence key, and due time; a verdict in one scope advances
    /// the shared schedule exactly once, and the other scope reloads to
    /// the same rescheduled card when it comes due again.
    ///
    /// A verdict records at the real wall clock (the Review tab's
    /// behavior), so the card leaves both due queues until its rescheduled
    /// date: the reload shows the empty queue with the projection's next
    /// due (equal up to the ±5% fuzz window), and the identical card —
    /// ordinal 2, the authored prompt — returns when loaded at that due.
    func testRotatedCueIdenticalInFocusAndAllScopes() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let (key, prompt, hint) = try multiCueFixture(pack: pack)
        let activity = try XCTUnwrap(
            pack.activities.first { $0.evidenceKey == key })
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let day: TimeInterval = 86_400
        try store.record(.attempt(try attempt(
            id: "scope-lesson", pack: pack, activity: activity, key: key, at: base)))

        let allModel = try ReviewModel(
            store: store, packs: [pack], focusSlug: "french", scope: .all)
        let focusModel = try ReviewModel(
            store: store, packs: [pack], focusSlug: "french", scope: .focus)

        // Both scopes surface the identical rotated card: same evidence
        // key, same due time (the first interval never fuzzes), and the
        // ordinal-1 cue — the authored hint.
        let allItem = try XCTUnwrap(
            allModel.due.first { $0.evidenceKey == key })
        let focusItem = try XCTUnwrap(
            focusModel.due.first { $0.evidenceKey == key })
        XCTAssertEqual(allItem.evidenceKey, focusItem.evidenceKey)
        XCTAssertEqual(allItem.dueAt, focusItem.dueAt)
        XCTAssertEqual(allItem.prompt, focusItem.prompt)
        XCTAssertEqual(allItem.prompt, hint)

        // A verdict in focus scope advances the shared schedule exactly once.
        let beforeReps = try XCTUnwrap(
            store.project(pack: pack).evidence[key]?.fsrs.reps)
        try focusModel.recordVerdict(.exact, for: focusItem)
        let afterReps = try XCTUnwrap(
            store.project(pack: pack).evidence[key]?.fsrs.reps)
        XCTAssertEqual(afterReps, beforeReps + 1)

        // The verdict rescheduled the card out of BOTH due queues: the
        // All-scope model reloads to the same empty queue, whose upcoming
        // due date is the shared schedule's rescheduled one — equal up to
        // the fuzz window a re-projection can roll.
        allModel.applyScope()
        XCTAssertTrue(allModel.due.isEmpty,
                      "a verdict must reschedule the card out of the due queue")
        let rescheduled = try XCTUnwrap(
            store.project(pack: pack).evidence[key]?.fsrs)
        XCTAssertEqual(rescheduled.reps, 2)
        XCTAssertEqual(
            rescheduled.dueAt.timeIntervalSince1970,
            rescheduled.lastReviewedAt.timeIntervalSince1970
                + Double(rescheduled.intervalDays) * day)
        let upcoming = try XCTUnwrap(allModel.nextDueAt)
        XCTAssertLessThanOrEqual(
            abs(upcoming.timeIntervalSince(rescheduled.dueAt)),
            (0.15 * Double(rescheduled.intervalDays) + 5) * day,
            "the reloaded scope must point at the shared schedule's next due")

        // When the rescheduled card comes due again, the identical card —
        // ordinal 2, the authored prompt, same key — returns in All scope.
        let returnAt = rescheduled.dueAt.addingTimeInterval(
            (1.5 * Double(rescheduled.intervalDays) + 10) * day)
        let reloaded = try XCTUnwrap(
            ReviewCatalog.loadDue(packs: [pack], store: store, now: returnAt)
                .due.first { $0.evidenceKey == key })
        XCTAssertEqual(reloaded.prompt, prompt)
        XCTAssertEqual(reloaded.evidenceKey, key)
    }
}

// MARK: - Checkpoint attempts (5.3A)
//
// The recording half of the checkpoint task bank: attempts are practice
// evidence in the event log. Tests pin the event payload (task id, modality
// coverage, assistance, self-rating, date), retake semantics (new row, no
// erased history, no duplicated completion), the reveal-before-answer rule
// (an attempt saved without the reveal marker is never independent), the
// continue-anyway contract (no lock, no progress penalty), and the export →
// validate → import round trip.

@MainActor
final class CheckpointAttemptTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("condisco-checkpoint-tests-\(UUID().uuidString)")
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

    private func makeStore(named name: String) throws -> LearningStore {
        try LearningStore(path: tempDir.appendingPathComponent(name).path)
    }

    private func spanishPack() throws -> CoursePack {
        try XCTUnwrap(
            PackLoader.loadPacks().first { $0.language.slug == "spanish" },
            "the focus-language profile is developed against Spanish")
    }

    /// The Foundation stage-end checkpoint (stable bank id).
    private func foundationCheckpoint(in pack: CoursePack) throws -> CheckpointTask {
        try XCTUnwrap(
            pack.checkpoints.first { $0.id == "es-cp-foundation" },
            "Spanish pack must ship the Foundation checkpoint")
    }

    /// Every recorded field lands in the event log: task id, modality
    /// coverage, assistance, self-rating, dates, and the reveal marker.
    func testCheckpointAttemptRecordsTaskModalityAssistanceRatingAndDate() throws {
        let store = try makeStore()
        let pack = try spanishPack()
        let checkpoint = try foundationCheckpoint(in: pack)
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        let rating = CheckpointSelfRating(criteriaMet: ["c1", "c2"], rating: .good)

        let event = try XCTUnwrap(store.recordCheckpointAttempt(
            pack: pack, checkpointId: checkpoint.id,
            assistance: [.hint], itemsRevealed: true,
            selfRating: rating, at: at))

        let events = try store.learningEvents(packId: pack.id)
        XCTAssertEqual(events.count, 1)
        guard case .checkpointAttempt(let stored) = events[0] else {
            return XCTFail("expected a checkpoint-attempt event")
        }
        XCTAssertEqual(stored, event)
        XCTAssertEqual(stored.checkpointId, checkpoint.id)
        XCTAssertEqual(stored.stage, checkpoint.stage)
        XCTAssertEqual(stored.modalitySlots, checkpoint.modalities)
        XCTAssertEqual(stored.assistance, [.hint])
        XCTAssertEqual(stored.selfRating, rating)
        XCTAssertEqual(stored.at, at)
        XCTAssertTrue(stored.itemsRevealed)
    }

    /// A retake is a new attempt row: the earlier attempt survives, no
    /// completion is duplicated, no known mark or evidence appears, and
    /// replaying the identical event is a no-op.
    func testCheckpointRetakeAppendsWithoutDuplicatingCompletion() throws {
        let store = try makeStore()
        let pack = try spanishPack()
        let checkpoint = try foundationCheckpoint(in: pack)

        let first = try XCTUnwrap(store.recordCheckpointAttempt(
            pack: pack, checkpointId: checkpoint.id, assistance: [],
            itemsRevealed: true, selfRating: nil,
            at: Date(timeIntervalSince1970: 1_700_000_000)))
        let second = try XCTUnwrap(store.recordCheckpointAttempt(
            pack: pack, checkpointId: checkpoint.id, assistance: [],
            itemsRevealed: true,
            selfRating: CheckpointSelfRating(criteriaMet: [], rating: .again),
            at: Date(timeIntervalSince1970: 1_700_000_100)))

        XCTAssertNotEqual(first.id, second.id, "a retake is a fresh attempt row")
        let events = try store.learningEvents(packId: pack.id)
        XCTAssertEqual(events.count, 2)

        let attempts = events.compactMap { event -> CheckpointAttemptEvent? in
            if case .checkpointAttempt(let e) = event { return e }
            return nil
        }
        XCTAssertEqual(attempts.count, 2, "earlier attempts must never be erased")
        XCTAssertEqual(Set(attempts.map(\.id)), [first.id, second.id])

        // Completion is not duplicated — the projection is exactly what it
        // would be with no checkpoint history at all.
        let progress = try store.project(pack: pack)
        XCTAssertTrue(progress.participationCompleted.isEmpty)
        XCTAssertTrue(progress.knownLessons.isEmpty)
        XCTAssertTrue(progress.legacyCredits.isEmpty)
        XCTAssertTrue(progress.evidence.isEmpty)
        XCTAssertEqual(progress.checkpointAttempts.count, 2)

        // Idempotent insert: re-recording the identical event is a no-op.
        try store.record(.checkpointAttempt(first))
        XCTAssertEqual(try store.learningEvents(packId: pack.id).count, 2)
    }

    /// Reveal-before-answer: an attempt saved without the reveal marker is
    /// never independent, and assistance voids independence even after the
    /// reveal. `independent` is derived by the store, so no caller can
    /// bypass the guard.
    func testCheckpointAttemptWithoutRevealCarriesNoIndependentCredit() throws {
        let store = try makeStore()
        let pack = try spanishPack()
        let checkpoint = try foundationCheckpoint(in: pack)

        let hidden = try XCTUnwrap(store.recordCheckpointAttempt(
            pack: pack, checkpointId: checkpoint.id, assistance: [],
            itemsRevealed: false,
            selfRating: CheckpointSelfRating(criteriaMet: [], rating: .again),
            at: Date(timeIntervalSince1970: 1_700_000_000)))
        XCTAssertFalse(hidden.independent,
                       "an attempt saved before the reveal cannot be independent")

        let revealed = try XCTUnwrap(store.recordCheckpointAttempt(
            pack: pack, checkpointId: checkpoint.id, assistance: [],
            itemsRevealed: true, selfRating: nil,
            at: Date(timeIntervalSince1970: 1_700_000_100)))
        XCTAssertTrue(revealed.independent,
                      "revealed + no assistance counts as independent")

        let assisted = try XCTUnwrap(store.recordCheckpointAttempt(
            pack: pack, checkpointId: checkpoint.id,
            assistance: [.model], itemsRevealed: true, selfRating: nil,
            at: Date(timeIntervalSince1970: 1_700_000_200)))
        XCTAssertFalse(assisted.independent,
                       "assistance voids independent credit after the reveal")
    }

    /// Continue-anyway contract: a low self-rated attempt changes nothing in
    /// the projection — no lock state exists, no lesson finishes, no known
    /// mark, no evidence, so the learner can carry on.
    func testLowSelfRatedCheckpointStillLeavesLearnerFreeToContinue() throws {
        let store = try makeStore()
        let pack = try spanishPack()
        let checkpoint = try foundationCheckpoint(in: pack)
        try store.recordCheckpointAttempt(
            pack: pack, checkpointId: checkpoint.id, assistance: [],
            itemsRevealed: true,
            selfRating: CheckpointSelfRating(criteriaMet: [], rating: .again),
            at: Date(timeIntervalSince1970: 1_700_000_000))

        let progress = try store.project(pack: pack)
        XCTAssertTrue(progress.finishedLessons.isEmpty,
                      "no lock or progress penalty from a low rating")
        XCTAssertTrue(progress.evidence.isEmpty,
                      "checkpoint attempts never feed SRS evidence")
        XCTAssertEqual(progress.checkpointAttempts.count, 1,
                       "the attempt stays on record as practice evidence")
        let next = try XCTUnwrap(
            pack.firstUncompletedLesson(completed: progress.finishedLessons))
        let firstId = try XCTUnwrap(pack.lessons.first?.id)
        XCTAssertEqual(next.lesson.id, firstId,
                       "the path still starts at the first lesson")
    }

    /// Export → ImportValidator → import preserves checkpoint attempts:
    /// the generic event union serialises them (YouModel/DataExport) and
    /// the validator accepts them without special-casing (decode-time
    /// validation covers the new kind).
    func testCheckpointAttemptSurvivesExportValidateImportRoundTrip() throws {
        let source = try makeStore()
        let pack = try spanishPack()
        let checkpoint = try foundationCheckpoint(in: pack)

        let first = try XCTUnwrap(source.recordCheckpointAttempt(
            pack: pack, checkpointId: checkpoint.id,
            assistance: [.transcript], itemsRevealed: true,
            selfRating: CheckpointSelfRating(criteriaMet: ["c1", "c4"],
                                             rating: .hard),
            at: Date(timeIntervalSince1970: 1_700_000_000)))
        let second = try XCTUnwrap(source.recordCheckpointAttempt(
            pack: pack, checkpointId: checkpoint.id, assistance: [],
            itemsRevealed: false, selfRating: nil,
            at: Date(timeIntervalSince1970: 1_700_000_100)))

        let url = try DataExport.buildFile(store: source)
        defer { try? FileManager.default.removeItem(at: url) }
        let data = try Data(contentsOf: url)

        let validated = ImportValidator.validate(data)
        guard case .success(let preview) = validated else {
            return XCTFail("export failed validation: \(validated)")
        }
        XCTAssertEqual(preview.events.count, 2,
                       "both checkpoint attempts must validate")

        let restored = try makeStore(named: "restored.sqlite")
        try restored.applyImport(preview)

        let restoredAttempts = try restored.allEvents().compactMap {
            event -> CheckpointAttemptEvent? in
            if case .checkpointAttempt(let e) = event { return e }
            return nil
        }
        XCTAssertEqual(restoredAttempts.count, 2,
                       "import must preserve both checkpoint attempts")
        XCTAssertEqual(Set(restoredAttempts.map(\.id)), [first.id, second.id])
        XCTAssertTrue(restoredAttempts.contains {
            $0.selfRating?.rating == .hard && $0.assistance == [.transcript]
        }, "self-rating and assistance must survive the round trip")
        XCTAssertTrue(restoredAttempts.contains { !$0.itemsRevealed },
                      "the reveal marker must survive the round trip")

        let restoredProgress = try restored.project(pack: pack)
        XCTAssertEqual(restoredProgress.checkpointAttempts.count, 2)
        XCTAssertTrue(restoredProgress.quarantined.isEmpty)
    }
}

// MARK: - Checkpoint flow (5.3B)
//
// The presentation half of the checkpoint task bank: the flow's recording
// path (reveal-before-answer end to end through `recordCheckpointRun`), the
// targeted revisit derivation (suggestions resolve to real lessons in the
// stage, honest empty when the derivation is thin), the completion-free
// contract (attempts never touch lesson progress), and the result copy
// (source phrases present, level/proficiency claims absent).

@MainActor
final class CheckpointFlowTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("condisco-checkpoint-flow-tests-\(UUID().uuidString)")
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

    private func spanishPack() throws -> CoursePack {
        try XCTUnwrap(
            PackLoader.loadPacks().first { $0.language.slug == "spanish" },
            "the focus-language profile is developed against Spanish")
    }

    private func checkpoint(_ id: String, in pack: CoursePack) throws -> CheckpointTask {
        try XCTUnwrap(pack.checkpoints.first { $0.id == id },
                      "Spanish pack must ship \(id)")
    }

    /// The flow's recording path end to end: an attempt saved before the
    /// items and rubric were presented is never independent; once revealed
    /// (and with no help) the store derives independent credit; showing the
    /// passage translation voids it. The payload also carries the task's
    /// stage, modality slots, and self-rating.
    func testFlowRecordingPathHonorsRevealBeforeAnswer() throws {
        let store = try makeStore()
        let pack = try spanishPack()
        let checkpoint = try checkpoint("es-cp-foundation", in: pack)

        // Un-revealed: the learner answered without ever seeing the task.
        var hidden = CheckpointRun(checkpoint: checkpoint)
        hidden.readingSelections["es-cp-foundation-reading-1-q1"] = "a"
        hidden.criteriaMet = ["c1"]
        let hiddenEvent = try XCTUnwrap(
            recordCheckpointRun(pack: pack, store: store, run: hidden))
        XCTAssertFalse(hiddenEvent.independent,
                       "an attempt recorded before the reveal is never independent")

        // Revealed with no help: independent credit derives as authored.
        var revealed = CheckpointRun(checkpoint: checkpoint)
        revealed.itemsRevealed = true
        revealed.readingSelections["es-cp-foundation-reading-1-q1"] = "a"
        revealed.readingSelections["es-cp-foundation-reading-1-q2"] = "a"
        revealed.writingTexts["es-cp-foundation-writing-1"] =
            "Me llamo Ana. Soy de Londres. Mucho gusto."
        revealed.criteriaMet = ["c1", "c2"]
        revealed.rating = .good
        let revealedEvent = try XCTUnwrap(
            recordCheckpointRun(pack: pack, store: store, run: revealed))
        XCTAssertTrue(revealedEvent.independent,
                      "revealed + no help counts as independent")
        XCTAssertEqual(revealedEvent.stage, .foundation)
        XCTAssertEqual(revealedEvent.modalitySlots, checkpoint.modalities)
        let selfRating = try XCTUnwrap(revealedEvent.selfRating)
        XCTAssertEqual(selfRating.criteriaMet, ["c1", "c2"])
        XCTAssertEqual(selfRating.rating, .good)

        // Revealed but assisted (the passage translation): no credit.
        var assisted = revealed
        assisted.assistance = [.translation]
        let assistedEvent = try XCTUnwrap(
            recordCheckpointRun(pack: pack, store: store, run: assisted))
        XCTAssertFalse(assistedEvent.independent,
                       "assistance voids independent credit after the reveal")

        // The store is the single authority: three rows, one independent.
        let progress = try store.project(pack: pack)
        XCTAssertEqual(progress.checkpointAttempts.count, 3)
        XCTAssertEqual(progress.checkpointAttempts.filter(\.independent).count, 1)
    }

    /// Reading grading through the flow's results: the chosen option is
    /// compared against the authored accepted answer with the engine's
    /// set-equality rule; an answered question carries its option text, an
    /// unanswered one never invents a score.
    func testFlowReadingResultsGradeSelectionStyle() throws {
        let pack = try spanishPack()
        let foundation = try checkpoint("es-cp-foundation", in: pack)

        var run = CheckpointRun(checkpoint: foundation)
        run.itemsRevealed = true
        run.readingSelections["es-cp-foundation-reading-1-q1"] = "a" // correct
        run.readingSelections["es-cp-foundation-reading-1-q2"] = "b" // wrong

        let results = checkpointReadingResults(run: run)
        XCTAssertEqual(results.count, 2, "two authored questions")

        let q1 = try XCTUnwrap(results.first { $0.question.id == "es-cp-foundation-reading-1-q1" })
        XCTAssertTrue(q1.correct)
        XCTAssertEqual(q1.selectedOptionText, "Cuatro euros")

        let q2 = try XCTUnwrap(results.first { $0.question.id == "es-cp-foundation-reading-1-q2" })
        XCTAssertFalse(q2.correct)
        XCTAssertEqual(q2.selectedOptionText, "Tres patatas y un kilo de manzanas")

        // The grading rule itself: set-equality over the authored accepted
        // ids, the same shape the engine's selection grading uses.
        let q1spec = try XCTUnwrap(
            readingQuestions(in: foundation).first {
                $0.id == "es-cp-foundation-reading-1-q1"
            })
        XCTAssertTrue(checkpointReadingCorrect(q1spec, selectedIds: ["a"]))
        XCTAssertFalse(checkpointReadingCorrect(q1spec, selectedIds: ["b"]))
        XCTAssertFalse(checkpointReadingCorrect(q1spec, selectedIds: []),
                       "an empty selection is never correct")

        // An unanswered question reads as not correct with no invented text.
        let developing = try checkpoint("es-cp-developing", in: pack)
        var partial = CheckpointRun(checkpoint: developing)
        partial.itemsRevealed = true
        partial.readingSelections["es-cp-developing-reading-1-q2"] = "a"
        let partialResults = checkpointReadingResults(run: partial)
        let unanswered = try XCTUnwrap(
            partialResults.first { $0.question.id == "es-cp-developing-reading-1-q1" })
        XCTAssertFalse(unanswered.correct)
        XCTAssertNil(unanswered.selectedOptionText)
    }

    /// A wrong reading answer on the Foundation task names real Foundation
    /// lessons that practised the passage's themes — never Developing
    /// content, and every id resolves in the pack.
    func testFoundationReadingRevisitResolvesToRealFoundationLessons() throws {
        let pack = try spanishPack()
        let checkpoint = try checkpoint("es-cp-foundation", in: pack)

        var run = CheckpointRun(checkpoint: checkpoint)
        run.itemsRevealed = true
        run.readingSelections["es-cp-foundation-reading-1-q1"] = "b" // wrong
        run.readingSelections["es-cp-foundation-reading-1-q2"] = "a" // correct
        // All criteria ticked so the speaking item adds no suggestion: this
        // test isolates the reading derivation.
        run.criteriaMet = ["c1", "c2", "c3", "c4"]

        let suggestions = checkpointRevisitSuggestions(
            pack: pack, checkpoint: checkpoint, run: run)
        XCTAssertFalse(suggestions.isEmpty,
                       "a wrong reading answer must suggest a lesson")
        let lessonIds = Set(pack.lessons.map(\.id))
        for suggestion in suggestions {
            XCTAssertEqual(suggestion.itemId, "es-cp-foundation-reading-1")
            XCTAssertEqual(suggestion.reason, CheckpointCopy.readingReason)
            XCTAssertTrue(lessonIds.contains(suggestion.lessonId),
                          "\(suggestion.lessonId) must be a real lesson id")
            let lesson = try XCTUnwrap(pack.lesson(id: suggestion.lessonId))
            XCTAssertEqual(checkpointStage(of: lesson), .foundation,
                           "a Foundation checkpoint only points at Foundation lessons")
        }
    }

    /// The Developing task's wrong reading answer resolves to Developing
    /// lessons (the A2 past/weekend concepts the passage draws on).
    func testDevelopingReadingRevisitStaysInDevelopingStage() throws {
        let pack = try spanishPack()
        let checkpoint = try checkpoint("es-cp-developing", in: pack)

        var run = CheckpointRun(checkpoint: checkpoint)
        run.itemsRevealed = true
        run.readingSelections["es-cp-developing-reading-1-q1"] = "b" // wrong
        run.readingSelections["es-cp-developing-reading-1-q2"] = "a" // correct
        // All criteria ticked so no speaking suggestion muddies the check.
        run.criteriaMet = ["c1", "c2", "c3", "c4"]

        let suggestions = checkpointRevisitSuggestions(
            pack: pack, checkpoint: checkpoint, run: run)
        XCTAssertFalse(suggestions.isEmpty,
                       "a wrong Developing reading answer must suggest a lesson")
        for suggestion in suggestions {
            let lesson = try XCTUnwrap(pack.lesson(id: suggestion.lessonId))
            XCTAssertEqual(checkpointStage(of: lesson), .developing,
                           "a Developing checkpoint only points at Developing lessons")
        }
    }

    /// Honest empty: a fully correct attempt (every question right, every
    /// criterion ticked) earns no suggestions, and a Developing speaking
    /// miss earns none either — the A2 stage has no speaking-practice
    /// lessons to point at, so nothing is guessed.
    func testRevisitSuggestionsAreEmptyWhenDerivationIsHonestlyThin() throws {
        let pack = try spanishPack()
        let foundation = try checkpoint("es-cp-foundation", in: pack)

        var clean = CheckpointRun(checkpoint: foundation)
        clean.itemsRevealed = true
        clean.readingSelections["es-cp-foundation-reading-1-q1"] = "a"
        clean.readingSelections["es-cp-foundation-reading-1-q2"] = "a"
        clean.criteriaMet = ["c1", "c2", "c3", "c4"]
        XCTAssertTrue(checkpointRevisitSuggestions(
            pack: pack, checkpoint: foundation, run: clean).isEmpty,
            "a clean attempt has nothing honest to revisit")

        let developing = try checkpoint("es-cp-developing", in: pack)
        var developingCleanReading = CheckpointRun(checkpoint: developing)
        developingCleanReading.itemsRevealed = true
        developingCleanReading.readingSelections["es-cp-developing-reading-1-q1"] = "a"
        developingCleanReading.readingSelections["es-cp-developing-reading-1-q2"] = "a"
        // Speaking criteria all unmet, but the A2 stage has no speaking
        // lessons — the honest answer is no suggestion, not a guess.
        let speakingMisses = checkpointSpeakingSuggestions(
            pack: pack, checkpoint: developing, run: developingCleanReading)
        XCTAssertTrue(speakingMisses.isEmpty,
                      "a stage with no speaking-practice lessons suggests none")
    }

    /// A Foundation speaking miss names the one lesson that practises
    /// speaking out loud in that stage (the café mission's self-compare).
    func testFoundationSpeakingMissSuggestsTheSpeakingLesson() throws {
        let pack = try spanishPack()
        let checkpoint = try checkpoint("es-cp-foundation", in: pack)

        var run = CheckpointRun(checkpoint: checkpoint)
        run.itemsRevealed = true
        run.readingSelections["es-cp-foundation-reading-1-q1"] = "a"
        run.readingSelections["es-cp-foundation-reading-1-q2"] = "a"
        // No criteria ticked: every rubric criterion is unmet.

        let speaking = checkpointSpeakingSuggestions(
            pack: pack, checkpoint: checkpoint, run: run)
        XCTAssertFalse(speaking.isEmpty,
                       "an unmet speaking criterion must name a speaking lesson")
        XCTAssertEqual(speaking.first?.lessonId, "es-cafe-mission")
        XCTAssertEqual(speaking.first?.reason, CheckpointCopy.speakingReason)
    }

    /// Completion-free: recording attempts through the flow's path changes
    /// nothing about lesson progress — no completion, no known marks, no
    /// legacy credit, no SRS evidence. The attempts list grows by one.
    func testFlowAttemptsNeverTouchLessonProgress() throws {
        let store = try makeStore()
        let pack = try spanishPack()
        let checkpoint = try checkpoint("es-cp-foundation", in: pack)

        let before = try store.project(pack: pack)

        var run = CheckpointRun(checkpoint: checkpoint)
        run.itemsRevealed = true
        run.readingSelections["es-cp-foundation-reading-1-q1"] = "b" // wrong
        run.writingTexts["es-cp-foundation-writing-1"] = "Me llamo Ana."
        run.criteriaMet = ["c4"]
        run.rating = .hard
        try recordCheckpointRun(pack: pack, store: store, run: run)

        let after = try store.project(pack: pack)
        XCTAssertEqual(after.checkpointAttempts.count,
                       before.checkpointAttempts.count + 1)
        XCTAssertEqual(after.participationCompleted, before.participationCompleted)
        XCTAssertEqual(after.knownLessons, before.knownLessons)
        XCTAssertEqual(after.legacyCredits, before.legacyCredits)
        XCTAssertEqual(after.evidence.keys.count, before.evidence.keys.count,
                       "checkpoint attempts never feed SRS evidence")
        XCTAssertEqual(after.evidenceCategories.keys.count,
                       before.evidenceCategories.keys.count)
        XCTAssertEqual(after.finishedLessons, before.finishedLessons)
        XCTAssertEqual(after.quarantined, before.quarantined)
    }

    /// Copy pin test: the new strings name the source of every result
    /// ("identified from the passage", "practised in writing", "you
    /// compared your spoken response") and never claim a level or
    /// proficiency ("B1 achieved", "you are …", "CEFR", "achieved").
    func testCheckpointCopyNamesSourcesAndBansLevelClaims() {
        XCTAssertEqual(
            CheckpointCopy.readingSourceCorrect,
            "Identified from the passage — your choice matches what the text says.")
        XCTAssertTrue(
            CheckpointCopy.readingSourceCorrect.contains("Identified from the passage"))
        XCTAssertTrue(
            CheckpointCopy.writingSource.contains("Practised in writing"))
        XCTAssertEqual(
            CheckpointCopy.writingSource,
            "Practised in writing — your response is saved as practice evidence, "
            + "with no right or wrong marked.")
        XCTAssertEqual(
            CheckpointCopy.speakingSource,
            "You compared your spoken response against the criteria.")
        XCTAssertTrue(
            CheckpointCopy.independentSource.contains("recorded as independent practice"))

        // No level/proficiency claim in any new string.
        let forbidden = ["b1", "a1", "cefr", "achieved", "you are", "you're",
                         "passed", "pass rate", "level met"]
        for string in CheckpointCopy.allStrings {
            let lowered = string.lowercased()
            for needle in forbidden {
                XCTAssertFalse(lowered.contains(needle),
                               "\(string) must not claim \(needle)")
            }
        }
    }

    /// All reading questions of a checkpoint task, in item order — a small
    /// helper for the grading-rule test.
    private func readingQuestions(in checkpoint: CheckpointTask) -> [CheckpointReadingQuestion] {
        checkpoint.items.compactMap { item -> [CheckpointReadingQuestion]? in
            if case .reading(let reading) = item { return reading.questions }
            return nil
        }.flatMap { $0 }
    }
}

// MARK: - Pack update safety (§5.4.2)
//
// The update contract: new content may install over existing progress, but
// it must never reset what a learner has already done. Events are
// append-only and packs are read-only projection inputs, so the store
// needs no change — these tests pin that behaviour: an update is a fresh
// pack object (new `version` string, optionally a grown `checkpoints`
// bank) projected over the same store. Anything that starts resetting
// completion, checkpoint attempts or review history on a version bump is
// a regression these tests catch.

@MainActor
final class PackUpdateTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("condisco-pack-update-tests-\(UUID().uuidString)")
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

    func testEarlyListeningAdditionPreservesUnchangedHistoricalEvidence() throws {
        for slug in ["german", "portuguese"] {
            let pack = try XCTUnwrap(PackLoader.loadPacks().first { $0.language.slug == slug })
            for suffix in ["introductions-foundation", "numbers-quantities-foundation"] {
                let lesson = try XCTUnwrap(pack.lessons.first { $0.id.hasSuffix(suffix) })
                let step = try XCTUnwrap(lesson.steps.first { step in
                    guard let activity = pack.activity(id: step.activityId) else { return false }
                    return activity.base != nil && activity.revision == 1 && !activity.id.contains("-listen-")
                })
                let activity = try XCTUnwrap(pack.activity(id: step.activityId))
                let base = try XCTUnwrap(activity.base)
                let store = try LearningStore(path: tempDir.appendingPathComponent("\(lesson.id).sqlite").path)
                let attempt = ActivityAttempt(id: "old", packId: pack.id, packVersion: "previous",
                    lessonId: lesson.id, lessonRevision: 1, stepId: step.id,
                    activityId: activity.id, activityRevision: 1, evidenceKey: base.evidenceKey,
                    response: try acceptedResponse(for: activity), assistance: [],
                    evaluation: AttemptEvaluation(outcome: .correct, independent: true, feedback: "correct"),
                    at: Date(timeIntervalSince1970: 1_700_000_000))
                try store.record(.attempt(attempt))
                let progress = try store.project(pack: pack)
                XCTAssertNotNil(progress.evidence[base.evidenceKey], lesson.id)
                XCTAssertFalse(progress.quarantined.contains(attempt.id), lesson.id)
            }
        }
    }

    func testRecommendedReplayStartsAtEntryAndPreservesCompletedEvidence() throws {
        let pack = try spanishPack()
        let store = try makeStore()
        let lesson = try XCTUnwrap(pack.lesson(id: "es-plural-foundation"))
        try completeLesson(lesson.id, in: pack, store: store, prefix: "prior",
                           at: Date(timeIntervalSince1970: 1_700_000_000))
        let before = try store.project(pack: pack)
        XCTAssertTrue(before.finishedLessons.contains(lesson.id))
        let row = YouModel.SkillPractice(skill: .grammar, practisedTimes: 0, lastPractisedAt: nil, dueCount: 0)
        let replay = YouModel.recommendedPractice(pack: pack, practice: [row],
            completedLessons: Set(pack.lessons.map(\.id)))
        XCTAssertEqual(replay?.startFresh, true)
        let resume = YouModel.recommendedPractice(pack: pack, practice: [row], completedLessons: [])
        XCTAssertEqual(resume?.startFresh, false)
        let fresh = try freshPracticeSession(pack: pack, lessonId: lesson.id)
        XCTAssertEqual(fresh.activeStepId, lesson.entryStepId)
        XCTAssertTrue(fresh.completedStepIds.isEmpty)
        let after = try store.project(pack: pack)
        XCTAssertEqual(before.finishedLessons, after.finishedLessons)
        XCTAssertEqual(fuzzInvariantEvidence(before), fuzzInvariantEvidence(after))
    }

    private func spanishPack() throws -> CoursePack {
        try XCTUnwrap(
            PackLoader.loadPacks().first { $0.language.slug == "spanish" },
            "the §5.4.2 update tests pin the Spanish pack")
    }

    /// The bundled Spanish pack as raw JSON, re-decoded after rewriting the
    /// `version` string — the exact shape the next app update would ship.
    /// Decodes and validates like the loader.
    private func updatedSpanishPack(
        version newVersion: String? = nil
    ) throws -> CoursePack {
        let content = try XCTUnwrap(
            Bundle.main.url(forResource: "Content", withExtension: nil),
            "test host must bundle the Content folder")
        let url = content.appendingPathComponent("packs/spanish.json")
        let raw = try Data(contentsOf: url)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: raw) as? [String: Any],
            "spanish.json must be a JSON object")
        if let newVersion {
            object["version"] = newVersion
        }
        let pack = try JSONDecoder().decode(
            CoursePack.self, from: JSONSerialization.data(withJSONObject: object))
        try PackValidator.validate(pack)
        return pack
    }

    /// A response that would grade correct for each graded activity kind.
    /// The store never re-grades, so the response only needs to be
    /// structurally valid for the event payload.
    private func acceptedResponse(for activity: Activity) throws -> AttemptResponse {
        switch activity {
        case .selection(let spec):
            return .selection(ids: spec.acceptedIds)
        case .ordering(let spec):
            return .ordering(ids: spec.acceptedOrders.first ?? [])
        case .cloze(let spec):
            return .cloze(values: Dictionary(
                uniqueKeysWithValues: spec.blanks.map { ($0.key, $0.value.answers.first ?? "") }))
        case .text(let spec):
            return .text(spec.answer.answers.first ?? "")
        default:
            throw XCTSkip("fixture lesson uses an unsupported activity kind")
        }
    }

    /// Walks a real lesson's step graph and records a valid attempt plus
    /// step completion per step (ungraded steps record a bare completion),
    /// the store-level shape the lesson engine writes — producing a real
    /// participation completion.
    private func completeLesson(
        _ lessonId: String, in pack: CoursePack, store: LearningStore,
        prefix: String, at: Date
    ) throws {
        let lesson = try XCTUnwrap(pack.lesson(id: lessonId), "missing lesson \(lessonId)")
        var tick: TimeInterval = 0
        for step in lesson.steps {
            let stepAt = at.addingTimeInterval(tick)
            let activity = try XCTUnwrap(
                pack.activity(id: step.activityId),
                "missing activity \(step.activityId) in \(lessonId)")
            var attemptId: String? = nil
            if let base = activity.base {
                let attempt = ActivityAttempt(
                    id: "\(prefix)-step-\(step.id)", packId: pack.id,
                    packVersion: pack.version,
                    lessonId: lesson.id, lessonRevision: lesson.revision,
                    stepId: step.id, activityId: activity.id,
                    activityRevision: activity.revision,
                    evidenceKey: base.evidenceKey,
                    response: try acceptedResponse(for: activity),
                    assistance: [],
                    evaluation: AttemptEvaluation(
                        outcome: .correct, independent: true, feedback: "correct"),
                    at: stepAt)
                try store.record(.attempt(attempt))
                attemptId = attempt.id
            }
            try store.record(.stepCompleted(StepCompletion(
                id: "\(prefix)-completion-\(step.id)", packId: pack.id,
                packVersion: pack.version,
                lessonId: lesson.id, lessonRevision: lesson.revision,
                stepId: step.id, selectedBranchId: nil, attemptId: attemptId,
                at: stepAt.addingTimeInterval(1))))
            tick += 2
        }
    }

    private func lesson(
        containingActivityId activityId: String, in pack: CoursePack
    ) throws -> Lesson {
        try XCTUnwrap(
            pack.lessons.first { $0.steps.contains { $0.activityId == activityId } },
            "no lesson references activity \(activityId)")
    }

    /// FSRS's canonical ±5% interval fuzz re-rolls per projection, so
    /// `intervalDays` and `dueAt` legitimately differ between two
    /// projections of the same history. Everything else is deterministic —
    /// the fields an update must preserve exactly.
    private struct FuzzInvariantEvidence: Equatable {
        var stability: Double
        var difficulty: Double
        var lastReviewedAt: Date
        var lastGrade: Int
        var reps: Int
        var successes: Int
        var failures: Int
        var mode: EvidenceMode
    }

    private func fuzzInvariantEvidence(
        _ progress: PackProgress
    ) -> [String: FuzzInvariantEvidence] {
        progress.evidence.mapValues { record in
            FuzzInvariantEvidence(
                stability: record.fsrs.stability,
                difficulty: record.fsrs.difficulty,
                lastReviewedAt: record.fsrs.lastReviewedAt,
                lastGrade: record.fsrs.lastGrade,
                reps: record.fsrs.reps,
                successes: record.successes,
                failures: record.failures,
                mode: record.mode)
        }
    }

    /// §5.4.2: an app update delivered over existing progress — including a
    /// checkpoint attempt (with a retake), lesson completion, and review
    /// history — leaves every projection axis unchanged. The update is a
    /// fresh pack object whose only difference is the version string.
    /// Regression pin on existing behaviour: no code change was needed,
    /// because events are append-only and packs are read-only inputs.
    func testUpdateOverExistingProgressKeepsCompletionCheckpointsAndReviewHistory() throws {
        let store = try makeStore()
        let v1 = try spanishPack()
        let v2 = try updatedSpanishPack(version: "0.8.0")  // the update
        XCTAssertNotEqual(
            v2.version, v1.version,
            "the update must carry a new pack version string")

        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let day: TimeInterval = 86_400

        // Lesson completion — the participation path over real content.
        try completeLesson(
            "es-plural-foundation", in: v1, store: store,
            prefix: "pre-update", at: t0)
        // Legacy credit through the v1 event replay path.
        let cafe = try XCTUnwrap(v1.lesson(id: "es-cafe-requests-foundation"))
        for (index, exerciseId) in (cafe.legacyCompletionExerciseIds ?? []).enumerated() {
            try store.record(.practiceV1(PracticeEventV1(
                id: "pre-update-legacy-\(index)", packId: v1.id, version: v1.version,
                exerciseId: exerciseId,
                at: t0.addingTimeInterval(Double(index) * 2),
                correct: true, revealed: false)))
        }
        // A manual "I know this" mark.
        try store.setLessonKnown(
            pack: v1, lessonId: "es-cafe-requests-foundation", known: true)

        // Review history: a clean independent production, then a clean
        // self-rated recall more than a day later on the same key.
        let recallKey = "es-cafe-requests-foundation-recall"
        let recallActivity = try XCTUnwrap(v1.activity(id: recallKey))
        let recallLesson = try lesson(containingActivityId: recallKey, in: v1)
        let recallStep = try XCTUnwrap(recallLesson.steps.first { $0.activityId == recallKey })
        let recallBase = try XCTUnwrap(recallActivity.base)
        try store.record(.attempt(ActivityAttempt(
            id: "pre-update-recall-lesson", packId: v1.id, packVersion: v1.version,
            lessonId: recallLesson.id, lessonRevision: recallLesson.revision,
            stepId: recallStep.id, activityId: recallKey,
            activityRevision: recallBase.revision,
            evidenceKey: recallKey,
            response: .text("Un café, por favor."),
            assistance: [],
            evaluation: AttemptEvaluation(
                outcome: .correct, independent: true, feedback: "correct"),
            at: t0)))
        try store.record(.attempt(ActivityAttempt(
            id: "pre-update-recall-review", packId: v1.id, packVersion: v1.version,
            lessonId: recallLesson.id, lessonRevision: recallLesson.revision,
            stepId: recallStep.id, activityId: recallKey,
            activityRevision: recallBase.revision,
            evidenceKey: recallKey,
            response: .selfRating(.good),
            assistance: [],
            evaluation: AttemptEvaluation(
                outcome: .correct, independent: true, feedback: ""),
            at: t0.addingTimeInterval(2 * day))))

        // Checkpoint attempts (including a retake) on the real Foundation bank.
        let foundation = try XCTUnwrap(
            v1.checkpoints.first { $0.id == "es-cp-foundation" })
        let firstAttempt = try XCTUnwrap(store.recordCheckpointAttempt(
            pack: v1, checkpointId: foundation.id, assistance: [],
            itemsRevealed: true,
            selfRating: CheckpointSelfRating(criteriaMet: ["c1", "c2"], rating: .good),
            at: t0.addingTimeInterval(4 * day)))
        let retake = try XCTUnwrap(store.recordCheckpointAttempt(
            pack: v1, checkpointId: foundation.id, assistance: [.hint],
            itemsRevealed: true,
            selfRating: CheckpointSelfRating(criteriaMet: [], rating: .again),
            at: t0.addingTimeInterval(4 * day + 100)))

        // ---- The update: the same store, a fresh pack object. ----
        let before = try store.project(pack: v1)
        let after = try store.project(pack: v2)

        // Lesson completion survives on every mechanism.
        XCTAssertEqual(after.participationCompleted, before.participationCompleted)
        XCTAssertEqual(after.legacyCredits, before.legacyCredits)
        XCTAssertEqual(after.knownLessons, before.knownLessons)
        XCTAssertEqual(after.finishedLessons, before.finishedLessons)
        XCTAssertEqual(
            after.finishedLessons,
            Set(["es-plural-foundation", "es-cafe-requests-foundation"]))

        // Checkpoint attempts survive identically, retake included.
        XCTAssertEqual(after.checkpointAttempts, before.checkpointAttempts)
        XCTAssertEqual(
            after.checkpointAttempts.map(\.id), [firstAttempt.id, retake.id])

        // Review history survives identically: categories plus every
        // deterministic FSRS field (fuzz only re-rolls interval/due).
        XCTAssertEqual(after.evidenceCategories, before.evidenceCategories)
        XCTAssertEqual(Set(after.evidence.keys), Set(before.evidence.keys))
        XCTAssertEqual(fuzzInvariantEvidence(after), fuzzInvariantEvidence(before))
        XCTAssertTrue(
            after.evidenceCategories[recallKey]?.contains(.producedIndependently) == true,
            "the lesson production must still be on record after the update")
        XCTAssertTrue(
            after.evidenceCategories[recallKey]?.contains(.recalledLater) == true,
            "the delayed clean review must still be on record after the update")

        // Nothing is held out, and the event log itself is untouched.
        XCTAssertEqual(after.quarantined, before.quarantined)
        XCTAssertTrue(after.quarantined.isEmpty)
        XCTAssertEqual(
            try store.learningEvents(packId: v1.id).map(\.id),
            try store.learningEvents(packId: v2.id).map(\.id))
    }

    /// §5.4.2: the stage-gaining update itself — the Spanish bank adding its
    /// Independent stage-end checkpoint (0.7.8 → 0.7.9) — installs over
    /// existing progress without resetting completion. v1 is the pre-0.7.9
    /// shape (Foundation + Developing only, back-dated to "0.7.8"); v2 is
    /// the live bundled pack with the shipped `es-cp-independent` entry.
    /// The old checkpoint attempt stays valid, the grown bank projects with
    /// nothing quarantined, and the new pathway is immediately usable over
    /// the existing store. Regression pin on existing behaviour; no code
    /// change was needed.
    func testPackWithGrownCheckpointBankInstallsOverExistingProgress() throws {
        let store = try makeStore()
        let v2 = try spanishPack()
        XCTAssertEqual(
            v2.checkpoints.map(\.id),
            ["es-cp-foundation", "es-cp-developing", "es-cp-independent"])

        // v1: the bundled pack without its Independent stage-end entry,
        // back-dated to the previous version string.
        let content = try XCTUnwrap(
            Bundle.main.url(forResource: "Content", withExtension: nil),
            "test host must bundle the Content folder")
        let url = content.appendingPathComponent("packs/spanish.json")
        let raw = try Data(contentsOf: url)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: raw) as? [String: Any],
            "spanish.json must be a JSON object")
        var old = object
        var checkpoints = old["checkpoints"] as? [[String: Any]] ?? []
        checkpoints.removeAll { ($0["id"] as? String) == "es-cp-independent" }
        old["checkpoints"] = checkpoints
        old["version"] = "0.7.8"
        let v1 = try JSONDecoder().decode(
            CoursePack.self, from: JSONSerialization.data(withJSONObject: old))
        try PackValidator.validate(v1)
        XCTAssertEqual(
            v1.checkpoints.map(\.id), ["es-cp-foundation", "es-cp-developing"])

        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        try completeLesson(
            "es-plural-foundation", in: v1, store: store,
            prefix: "pre-stage", at: t0)
        let foundation = try XCTUnwrap(
            v1.checkpoints.first { $0.id == "es-cp-foundation" })
        let attempt = try XCTUnwrap(store.recordCheckpointAttempt(
            pack: v1, checkpointId: foundation.id, assistance: [],
            itemsRevealed: true,
            selfRating: CheckpointSelfRating(criteriaMet: ["c4"], rating: .hard),
            at: t0))

        // The update: the live 0.7.11 bundle projects over the same store.
        let after = try store.project(pack: v2)
        XCTAssertEqual(
            after.participationCompleted, Set(["es-plural-foundation"]),
            "a grown checkpoint bank must not reset lesson completion")
        XCTAssertEqual(
            after.checkpointAttempts.map(\.id), [attempt.id],
            "the recorded Foundation attempt must survive the grown bank")
        XCTAssertEqual(after.checkpointAttempts, [attempt])
        XCTAssertTrue(
            after.quarantined.isEmpty,
            "growing the bank must not quarantine old checkpoint history")
        XCTAssertEqual(after.finishedLessons, Set(["es-plural-foundation"]))

        // The new pathway is immediately usable over the existing store.
        let newAttempt = try XCTUnwrap(store.recordCheckpointAttempt(
            pack: v2, checkpointId: "es-cp-independent", assistance: [],
            itemsRevealed: true, selfRating: nil,
            at: t0.addingTimeInterval(100)))
        XCTAssertEqual(newAttempt.stage, .independent)
        let final = try store.project(pack: v2)
        XCTAssertEqual(final.checkpointAttempts.count, 2)
        XCTAssertEqual(
            final.checkpointAttempts.map(\.id), [attempt.id, newAttempt.id])
        XCTAssertTrue(final.quarantined.isEmpty)
    }
}

// MARK: - Open-task attempts (6.2)
//
// Store-level contract for open-task attempts: the recorded completion
// carries the task binding (lesson/step/activity + revision), the
// modality, the assistance, the model-reveal marker, and the learner's
// OWN self-assessment (rubric ticks + optional rating). It carries
// NOTHING else — no response text, no audio reference, no evidence, and
// no completion credit of its own.

@MainActor
final class OpenTaskAttemptTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("condisco-open-task-tests-\(UUID().uuidString)")
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

    private func spanishPack() throws -> CoursePack {
        try XCTUnwrap(
            PackLoader.loadPacks().first { $0.language.slug == "spanish" },
            "the open-task lane is developed against Spanish")
    }

    private func openTaskSpec(_ id: String, in pack: CoursePack) throws -> OpenTaskActivity {
        let act = try XCTUnwrap(pack.activity(id: id), "missing activity \(id)")
        guard case .openTask(let spec) = act else {
            throw XCTSkip("expected an open task for \(id)")
        }
        return spec
    }

    /// The lesson and step that host an open-task activity.
    private func host(_ activityId: String, in pack: CoursePack) throws -> (lesson: Lesson, step: LessonStep) {
        let lesson = try XCTUnwrap(
            pack.lessons.first { $0.steps.contains { $0.activityId == activityId } },
            "no lesson hosts \(activityId)")
        let step = try XCTUnwrap(lesson.steps.first { $0.activityId == activityId })
        return (lesson, step)
    }

    /// Records one valid attempt per step of a participation lesson, exactly
    /// the shape the lesson engine writes — the open-task step records its
    /// open-task attempt event plus the bare completion (no attemptId),
    /// mirroring `handleOpenTaskSubmit`.
    private func completeParticipationLesson(
        _ lessonId: String, in pack: CoursePack, store: LearningStore,
        prefix: String, at: Date
    ) throws {
        let lesson = try XCTUnwrap(pack.lesson(id: lessonId))
        var tick: TimeInterval = 0
        for step in lesson.steps {
            let stepAt = at.addingTimeInterval(tick)
            let activity = try XCTUnwrap(pack.activity(id: step.activityId))
            var attemptId: String? = nil
            if let base = activity.base {
                let response: AttemptResponse
                if case .selection(let spec) = activity {
                    response = .selection(ids: spec.acceptedIds)
                } else if case .cloze(let spec) = activity {
                    response = .cloze(values: Dictionary(
                        uniqueKeysWithValues: spec.blanks.map {
                            ($0.key, $0.value.answers.first ?? "")
                        }))
                } else if case .text(let spec) = activity {
                    response = .text(spec.answer.answers.first ?? "")
                } else {
                    throw XCTSkip("unsupported graded kind in \(lessonId)")
                }
                let attempt = ActivityAttempt(
                    id: "\(prefix)-attempt-\(step.id)", packId: pack.id,
                    packVersion: pack.version,
                    lessonId: lesson.id, lessonRevision: lesson.revision,
                    stepId: step.id, activityId: activity.id,
                    activityRevision: activity.revision,
                    evidenceKey: base.evidenceKey,
                    response: response,
                    assistance: [],
                    evaluation: AttemptEvaluation(
                        outcome: .correct, independent: true, feedback: "correct"),
                    at: stepAt)
                try store.record(.attempt(attempt))
                attemptId = attempt.id
            } else if case .openTask(let spec) = activity {
                // The lesson engine writes the open-task attempt event
                // alongside the bare completion (handleOpenTaskSubmit):
                // practice evidence bound to the step, never a grade. The
                // .stepCompleted below still rides with attemptId nil.
                try store.record(.openTaskAttempt(OpenTaskAttemptEvent(
                    id: "\(prefix)-attempt-\(step.id)", packId: pack.id,
                    packVersion: pack.version,
                    lessonId: lesson.id, lessonRevision: lesson.revision,
                    stepId: step.id, activityId: activity.id,
                    activityRevision: spec.revision, mode: spec.mode,
                    assistance: [], selfRating: nil, modelRevealed: false,
                    at: stepAt)))
            }
            try store.record(.stepCompleted(StepCompletion(
                id: "\(prefix)-completion-\(step.id)", packId: pack.id,
                packVersion: pack.version,
                lessonId: lesson.id, lessonRevision: lesson.revision,
                stepId: step.id, selectedBranchId: nil, attemptId: attemptId,
                at: stepAt.addingTimeInterval(1))))
            tick += 2
        }
    }

    /// Every recorded field lands in the event log: the lesson/step/
    /// activity binding, the modality, assistance, self-rating, date, and
    /// the model-reveal marker. The payload never carries the response
    /// text or any audio reference.
    func testOpenTaskAttemptRecordsBindingModalityAssistanceRatingAndReveal() throws {
        let store = try makeStore()
        let pack = try spanishPack()
        let spec = try openTaskSpec("es-a2-fin-de-semana-open-task", in: pack)
        let (lesson, step) = try host(spec.id, in: pack)
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertEqual(spec.mode, .written)

        let event = try XCTUnwrap(store.recordOpenTaskAttempt(
            pack: pack, lessonId: lesson.id, stepId: step.id,
            activityId: spec.id, assistance: [.hint], modelRevealed: true,
            selfRating: OpenTaskSelfRating(criteriaMet: ["meaning", "repair"], rating: .good),
            at: at))

        let events = try store.learningEvents(packId: pack.id)
        XCTAssertEqual(events.count, 1)
        guard case .openTaskAttempt(let stored) = events[0] else {
            return XCTFail("expected an open-task-attempt event")
        }
        XCTAssertEqual(stored, event)
        XCTAssertEqual(stored.lessonId, lesson.id)
        XCTAssertEqual(stored.lessonRevision, lesson.revision)
        XCTAssertEqual(stored.stepId, step.id)
        XCTAssertEqual(stored.activityId, spec.id)
        XCTAssertEqual(stored.activityRevision, spec.revision)
        XCTAssertEqual(stored.mode, .written)
        XCTAssertEqual(stored.assistance, [.hint])
        XCTAssertEqual(stored.selfRating?.criteriaMet, ["meaning", "repair"])
        XCTAssertEqual(stored.selfRating?.rating, .good)
        XCTAssertTrue(stored.modelRevealed)
        XCTAssertEqual(stored.at, at)

        // The log records completion/assistance/self-assessment ONLY: no
        // response text, no recording path, no grade.
        let payload = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(LearningEvent.openTaskAttempt(stored)),
            options: []) as? [String: Any]
        XCTAssertNotNil(payload)
        XCTAssertNil(payload?["response"], "open-task log rows never carry the response")
        XCTAssertNil(payload?["text"], "open-task log rows never carry the draft text")
        XCTAssertNil(payload?["audioUrl"], "open-task log rows never carry a recording path")
        XCTAssertNil(payload?["evaluation"], "open-task log rows carry no grade")
    }

    /// A retake is a new attempt row: the earlier attempt survives, no
    /// completion is duplicated, no evidence appears, and replaying the
    /// identical event is a no-op.
    func testOpenTaskRetakeAppendsWithoutDuplicatingCompletion() throws {
        let store = try makeStore()
        let pack = try spanishPack()
        let spec = try openTaskSpec("es-cafe-requests-foundation-open-task", in: pack)
        let (lesson, step) = try host(spec.id, in: pack)

        let first = try XCTUnwrap(store.recordOpenTaskAttempt(
            pack: pack, lessonId: lesson.id, stepId: step.id,
            activityId: spec.id, assistance: [], modelRevealed: false,
            selfRating: OpenTaskSelfRating(criteriaMet: ["meaning"], rating: .good),
            at: Date(timeIntervalSince1970: 1_700_000_000)))
        let second = try XCTUnwrap(store.recordOpenTaskAttempt(
            pack: pack, lessonId: lesson.id, stepId: step.id,
            activityId: spec.id, assistance: [], modelRevealed: true,
            selfRating: OpenTaskSelfRating(criteriaMet: [], rating: .again),
            at: Date(timeIntervalSince1970: 1_700_000_100)))

        XCTAssertNotEqual(first.id, second.id, "a retake is a fresh attempt row")
        let events = try store.learningEvents(packId: pack.id)
        XCTAssertEqual(events.count, 2)

        let progress = try store.project(pack: pack)
        XCTAssertEqual(progress.openTaskAttempts.map(\.id), [first.id, second.id])
        XCTAssertTrue(progress.participationCompleted.isEmpty,
                      "an open-task row grants no completion credit of its own")
        XCTAssertTrue(progress.evidence.isEmpty,
                      "an open-task row never feeds SRS evidence")
        XCTAssertTrue(progress.evidenceCategories.isEmpty,
                      "an open-task row never creates evidence categories")
        XCTAssertTrue(progress.knownLessons.isEmpty)
        XCTAssertTrue(progress.legacyCredits.isEmpty)

        // Idempotent insert: re-recording the identical event is a no-op.
        try store.record(.openTaskAttempt(first))
        XCTAssertEqual(try store.learningEvents(packId: pack.id).count, 2)
    }

    /// Reveal-before-answer: an attempt recorded after the model was shown
    /// is never independent, and assistance voids independence even without
    /// a reveal. `independent` is derived by the store, so no caller can
    /// bypass the guard.
    func testOpenTaskRevealOrHelpVoidsIndependence() throws {
        let store = try makeStore()
        let pack = try spanishPack()
        let spec = try openTaskSpec("es-a2-planes-intenciones-open-task", in: pack)
        let (lesson, step) = try host(spec.id, in: pack)
        XCTAssertEqual(spec.mode, .spoken)

        let clean = try XCTUnwrap(store.recordOpenTaskAttempt(
            pack: pack, lessonId: lesson.id, stepId: step.id,
            activityId: spec.id, assistance: [], modelRevealed: false,
            selfRating: nil, at: Date(timeIntervalSince1970: 1_700_000_000)))
        XCTAssertTrue(clean.independent,
                      "no reveal + no help counts as independent production")

        let revealed = try XCTUnwrap(store.recordOpenTaskAttempt(
            pack: pack, lessonId: lesson.id, stepId: step.id,
            activityId: spec.id, assistance: [], modelRevealed: true,
            selfRating: nil, at: Date(timeIntervalSince1970: 1_700_000_100)))
        XCTAssertFalse(revealed.independent,
                       "an attempt after the model reveal is never independent")

        let helped = try XCTUnwrap(store.recordOpenTaskAttempt(
            pack: pack, lessonId: lesson.id, stepId: step.id,
            activityId: spec.id, assistance: [.hint], modelRevealed: false,
            selfRating: nil, at: Date(timeIntervalSince1970: 1_700_000_200)))
        XCTAssertFalse(helped.independent,
                       "using a hint voids independence even without a reveal")
    }

    /// An unknown binding records nothing — the UI lane reads the task
    /// from the pack before offering it, so a dangling id is a no-op.
    func testOpenTaskUnknownBindingRecordsNothing() throws {
        let store = try makeStore()
        let pack = try spanishPack()

        let nilLesson = try store.recordOpenTaskAttempt(
            pack: pack, lessonId: "no-such-lesson", stepId: "s", activityId: "a",
            assistance: [], modelRevealed: false, selfRating: nil)
        XCTAssertNil(nilLesson)
        let nilStep = try store.recordOpenTaskAttempt(
            pack: pack, lessonId: "es-a2-fin-de-semana", stepId: "no-such-step",
            activityId: "es-a2-fin-de-semana-open-task",
            assistance: [], modelRevealed: false, selfRating: nil)
        XCTAssertNil(nilStep)
        let nilActivity = try store.recordOpenTaskAttempt(
            pack: pack, lessonId: "es-a2-fin-de-semana",
            stepId: "es-a2-fin-de-semana-step-open-task",
            activityId: "es-a2-fin-de-semana-act-rb2",
            assistance: [], modelRevealed: false, selfRating: nil)
        XCTAssertNil(nilActivity)
        XCTAssertTrue(try store.learningEvents(packId: pack.id).isEmpty)
    }

    /// Projection re-validates against the pack: a stale revision, a
    /// remodelled task, or a step that no longer binds the activity lands
    /// in `quarantined`, never in the practice evidence.
    func testOpenTaskProjectionQuarantinesStaleOrRemodelledRows() throws {
        let store = try makeStore()
        let pack = try spanishPack()
        let spec = try openTaskSpec("es-a2-fin-de-semana-open-task", in: pack)
        let (lesson, step) = try host(spec.id, in: pack)

        func attempt(id: String, revision: Int, mode: OpenTaskMode,
                     stepId: String) -> OpenTaskAttemptEvent {
            OpenTaskAttemptEvent(
                id: id, packId: pack.id, packVersion: pack.version,
                lessonId: lesson.id, lessonRevision: lesson.revision,
                stepId: stepId, activityId: spec.id,
                activityRevision: revision, mode: mode,
                assistance: [], selfRating: nil, modelRevealed: false,
                at: Date(timeIntervalSince1970: 1_700_000_000))
        }

        try store.record(.openTaskAttempt(attempt(
            id: "stale-revision", revision: spec.revision + 1, mode: .written,
            stepId: step.id)))
        try store.record(.openTaskAttempt(attempt(
            id: "remodelled", revision: spec.revision, mode: .spoken,
            stepId: step.id)))
        try store.record(.openTaskAttempt(attempt(
            id: "wrong-step", revision: spec.revision, mode: .written,
            stepId: "es-a2-fin-de-semana-step-rb4")))

        let progress = try store.project(pack: pack)
        XCTAssertTrue(progress.openTaskAttempts.isEmpty)
        XCTAssertEqual(
            Set(progress.quarantined),
            ["stale-revision", "remodelled", "wrong-step"])
    }

    /// An open-task step completes through the normal lesson machinery: a
    /// bare step completion (no attemptId) resolves against the ungraded
    /// open task, exactly like information steps, and a participation
    /// lesson finishes with the open task counted among its required steps.
    func testOpenTaskStepCompletionCompletesParticipationLesson() throws {
        let store = try makeStore()
        let pack = try spanishPack()
        let at = Date(timeIntervalSince1970: 1_700_000_000)

        try completeParticipationLesson(
            "es-a2-fin-de-semana", in: pack, store: store,
            prefix: "fin", at: at)

        let progress = try store.project(pack: pack)
        XCTAssertTrue(
            progress.participationCompleted.contains("es-a2-fin-de-semana"),
            "the open-task step must participate in lesson completion")
        XCTAssertTrue(progress.quarantined.isEmpty)
        XCTAssertFalse(
            progress.openTaskAttempts.isEmpty,
            "the recorded open-task completion must be on record")
    }

    /// The engine never grades an open response: any self-assessment
    /// submission completes as self-assessed, and arbitrary writing is
    /// never accepted as correct (no fixed-answer matcher is consulted).
    func testOpenTaskEvaluationNeverGradesAnOpenResponse() throws {
        let pack = try spanishPack()
        let act = try XCTUnwrap(pack.activity(id: "es-a2-fin-de-semana-open-task"))

        let rated = ActivityEvaluation.evaluate(
            activity: act, response: .selfRating(.good), assistance: [])
        XCTAssertEqual(rated.outcome, .selfAssessed,
                       "a rated submission completes as self-assessed, never correct")

        let continued = ActivityEvaluation.evaluate(
            activity: act, response: .continue, assistance: [])
        XCTAssertEqual(continued.outcome, .selfAssessed,
                       "an unrated submission completes as self-assessed too")

        let long = String(repeating: "El sábado fui al mercado. ", count: 400)
        let writing = ActivityEvaluation.evaluate(
            activity: act, response: .text(long), assistance: [])
        XCTAssertNotEqual(writing.outcome, .correct,
                          "arbitrary open writing must never grade correct")
        XCTAssertNotEqual(writing.outcome, .incorrect,
                          "arbitrary open writing must never grade incorrect")
    }

    /// The live Spanish pack with one open task mutated, decoded fresh —
    /// the fixture for validator negatives. Only the open-task fields
    /// change; the rest of the pack is the valid bundled shape.
    private func mutatedOpenTaskPack(
        _ openTaskId: String,
        mutate: (inout [String: Any]) -> Void
    ) throws -> CoursePack {
        let content = try XCTUnwrap(
            Bundle.main.url(forResource: "Content", withExtension: nil),
            "test host must bundle the Content folder")
        let url = content.appendingPathComponent("packs/spanish.json")
        let raw = try Data(contentsOf: url)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: raw) as? [String: Any],
            "spanish.json must be a JSON object")
        var activities = try XCTUnwrap(object["activities"] as? [[String: Any]])
        guard let index = activities.firstIndex(
            where: { $0["id"] as? String == openTaskId }) else {
            throw XCTSkip("no open task \(openTaskId) in the fixture")
        }
        var task = activities[index]
        mutate(&task)
        activities[index] = task
        object["activities"] = activities
        return try JSONDecoder().decode(
            CoursePack.self,
            from: JSONSerialization.data(withJSONObject: object))
    }

    /// Validator negative fixture: an open task with no communicative goal
    /// fails validation.
    func testValidatorRejectsOpenTaskWithEmptyGoal() throws {
        let pack = try mutatedOpenTaskPack("es-a2-fin-de-semana-open-task") { task in
            task["goal"] = "   "
        }
        XCTAssertThrowsError(try PackValidator.validate(pack)) { error in
            XCTAssertTrue(error is PackValidationError,
                          "expected PackValidationError, got \(error)")
        }
    }

    /// Validator negative fixture: an open task with a missing (empty)
    /// self-check rubric fails validation.
    func testValidatorRejectsOpenTaskWithMissingRubric() throws {
        let pack = try mutatedOpenTaskPack("es-a2-fin-de-semana-open-task") { task in
            task["rubric"] = []
        }
        XCTAssertThrowsError(try PackValidator.validate(pack)) { error in
            XCTAssertTrue(error is PackValidationError,
                          "expected PackValidationError, got \(error)")
        }
    }
}

// MARK: - Open-task flow logic (6.2, plan item 4)

/// Headless tests for the flow state logic: submission rules, draft
/// persistence across view re-inits, keyboard-recovery state, the
/// independent-vs-after-reveal distinction, recording deletion, and the
/// learner-facing copy pins. All run without a simulator UI.
@MainActor
final class OpenTaskFlowTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("condisco-open-task-flow-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
    }

    private func makeStore(named name: String = "store.sqlite") throws -> LearningStore {
        try LearningStore(path: tempDir.appendingPathComponent(name).path)
    }

    private func spanishPack() throws -> CoursePack {
        try XCTUnwrap(
            PackLoader.loadPacks().first { $0.language.slug == "spanish" })
    }

    /// The open-task step of a hosted lesson.
    private func openTaskStep(_ activityId: String, in pack: CoursePack) throws -> LessonStep {
        let lesson = try XCTUnwrap(
            pack.lessons.first { $0.steps.contains { $0.activityId == activityId } })
        return try XCTUnwrap(lesson.steps.first { $0.activityId == activityId })
    }

    /// Empty input cannot submit; a long draft (5k+ characters) is
    /// accepted and remains submittable, and whitespace-only text is
    /// empty. Revealing the model never blocks submission — it only
    /// changes how the attempt counts.
    func testWrittenSubmissionRequiresContentAndAcceptsLongDrafts() {
        let empty = OpenTaskSubmission(
            text: "   \n ", criteriaMet: ["meaning"],
            rating: nil, modelRevealed: true, hasRecording: false, micDenied: false)
        XCTAssertFalse(OpenTaskSubmission.canSubmit(mode: .written, submission: empty),
                       "whitespace-only text cannot submit")

        let longText = String(repeating: "El sábado fui al mercado con mi hermana. ", count: 400)
        XCTAssertGreaterThan(longText.count, 5_000)
        let long = OpenTaskSubmission(
            text: longText, criteriaMet: [], rating: nil,
            modelRevealed: true, hasRecording: false, micDenied: false)
        XCTAssertTrue(OpenTaskSubmission.canSubmit(mode: .written, submission: long),
                      "a 5k-character draft is a legitimate connected response")

        let retake = OpenTaskSubmission(
            text: "", criteriaMet: [], rating: nil,
            modelRevealed: true, hasRecording: false, micDenied: false)
        XCTAssertFalse(OpenTaskSubmission.canSubmit(mode: .written, submission: retake),
                       "a cleared draft cannot submit a retry")
    }

    /// Spoken mode needs a finished recording — or, when the mic is
    /// blocked, at least one ticked criterion (the honest degradation).
    func testSpokenSubmissionRequiresRecordingOrMicDeniedTicks() {
        let nothing = OpenTaskSubmission()
        XCTAssertFalse(OpenTaskSubmission.canSubmit(mode: .spoken, submission: nothing))

        let recorded = OpenTaskSubmission(
            text: "", criteriaMet: [], rating: nil, modelRevealed: false,
            hasRecording: true, micDenied: false)
        XCTAssertTrue(OpenTaskSubmission.canSubmit(mode: .spoken, submission: recorded),
                      "a finished take is content")

        let ticksOnly = OpenTaskSubmission(
            criteriaMet: ["meaning"], modelRevealed: false,
            hasRecording: false, micDenied: true)
        XCTAssertTrue(OpenTaskSubmission.canSubmit(mode: .spoken, submission: ticksOnly),
                      "mic blocked + a ticked criterion is the degraded path")

        let ticksWithoutContent = OpenTaskSubmission(
            criteriaMet: ["meaning"], modelRevealed: false,
            hasRecording: false, micDenied: false)
        XCTAssertFalse(OpenTaskSubmission.canSubmit(mode: .spoken, submission: ticksWithoutContent),
                       "ticks alone are not content when recording works")
    }

    /// Draft persistence is the lesson checkpoint: a long written draft
    /// survives a view re-init (a fresh store over the same file) and a
    /// full re-entry through `resumeSession`, which hands the draft back
    /// to a newly created view. Keyboard-recovery state is this same
    /// round trip — text typed before dismissal is never lost.
    func testDraftPersistsAcrossReinitAtFiveThousandCharacters() throws {
        let pack = try spanishPack()
        let step = try openTaskStep("es-a2-fin-de-semana-open-task", in: pack)
        let lesson = try XCTUnwrap(pack.lesson(id: "es-a2-fin-de-semana"))
        let longText = String(repeating: "Me gusta el mercado y la música. ", count: 300)
        XCTAssertGreaterThan(longText.count, 5_000)

        let checkpoint = LessonCheckpoint(
            packId: pack.id, lessonId: lesson.id, revision: lesson.revision,
            stepId: step.id, selectedBranches: [:],
            assistance: [], draft: .text(longText),
            at: Date(timeIntervalSince1970: 1_700_000_000))

        let first = try makeStore(named: "store-a.sqlite")
        try first.saveCheckpoint(checkpoint)
        // The view re-init: a fresh store instance (and later a fresh view)
        // reads the same draft back from disk.
        let second = try makeStore(named: "store-a.sqlite")
        let restored = try XCTUnwrap(
            second.loadCheckpoint(packId: pack.id, lessonId: lesson.id),
            "the draft must survive a store re-init")
        XCTAssertEqual(restored.draft, .text(longText),
                       "the full 5k-character draft round-trips unchanged")

        // Full re-entry: the resumed session hands the draft to the new
        // view's editor, exactly the interrupt/resume path.
        let resume = resumeSession(pack: pack, checkpoint: restored, events: [])
        guard case .resume(let session) = resume else {
            return XCTFail("expected a resume, got \(resume)")
        }
        XCTAssertEqual(session.draftResponse, .text(longText),
                       "resume restores the written draft for keyboard recovery")
    }

    /// The recorded event distinguishes independent production from a
    /// retry made after the model was revealed: the retake is a fresh row
    /// whose reveal marker (and assistance) void independence, while the
    /// earlier independent attempt keeps its credit.
    func testRetryAfterRevealStaysDistinguishableFromIndependent() throws {
        let store = try makeStore()
        let pack = try spanishPack()
        let lesson = try XCTUnwrap(pack.lesson(id: "es-a2-fin-de-semana"))
        let step = try openTaskStep("es-a2-fin-de-semana-open-task", in: pack)

        let independent = try XCTUnwrap(store.recordOpenTaskAttempt(
            pack: pack, lessonId: lesson.id, stepId: step.id,
            activityId: step.activityId, assistance: [], modelRevealed: false,
            selfRating: OpenTaskSelfRating(criteriaMet: ["meaning"], rating: .good),
            at: Date(timeIntervalSince1970: 1_700_000_000)))
        XCTAssertTrue(independent.independent)

        // The retry: the learner revealed the model first, then re-answered.
        let afterReveal = try XCTUnwrap(store.recordOpenTaskAttempt(
            pack: pack, lessonId: lesson.id, stepId: step.id,
            activityId: step.activityId, assistance: [.model], modelRevealed: true,
            selfRating: OpenTaskSelfRating(criteriaMet: ["meaning", "repair"], rating: .good),
            at: Date(timeIntervalSince1970: 1_700_000_100)))
        XCTAssertFalse(afterReveal.independent,
                       "a retry after the reveal must not carry independent credit")

        let progress = try store.project(pack: pack)
        XCTAssertEqual(progress.openTaskAttempts.count, 2)
        XCTAssertEqual(progress.openTaskAttempts[0].id, independent.id)
        XCTAssertTrue(progress.openTaskAttempts[0].independent)
        XCTAssertEqual(progress.openTaskAttempts[1].id, afterReveal.id)
        XCTAssertFalse(progress.openTaskAttempts[1].independent)
    }

    /// Recording deletion is the disposable-take lifecycle: discarding the
    /// take removes the local temp file, so nothing outlives the step.
    func testRecordingDeletionRemovesLocalFile() throws {
        let recorder = LessonStepRecorder()
        let url = tempDir.appendingPathComponent("disposable-take.m4a")
        try Data("aac-audio-stub".utf8).write(to: url)
        recorder.recordingURL = url

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        recorder.discard()
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path),
                       "discarding the take must delete the local file")
        XCTAssertNil(recorder.recordingURL)
    }

    /// Copy pin test (plan 6.2): the new learner-facing strings — app copy
    /// and the authored open-task wording (goal, points, model, rubric,
    /// hints, guidance) — never claim an automatic judgement: no
    /// correct/incorrect, no score, no graded/CEFR/level phrasing.
    func testOpenTaskCopyBansGradingClaims() throws {
        let pack = try spanishPack()
        let tasks = pack.activities.compactMap { activity -> OpenTaskActivity? in
            if case .openTask(let spec) = activity { return spec }
            return nil
        }
        XCTAssertEqual(tasks.count, 12, "the Spanish pack must ship its twelve open tasks")

        var all: [String] = OpenTaskCopy.allStrings
        for task in tasks {
            all.append(task.goal)
            all.append(contentsOf: task.requiredPoints)
            all.append(task.modelResponse)
            all.append(contentsOf: task.rubric.map(\.text))
            all.append(contentsOf: task.hints)
            if let guidance = task.lengthGuidance { all.append(guidance) }
        }

        let forbidden = ["correct", "incorrect", "score", "graded", "cefr", "level"]
        for string in all {
            let lowered = string.lowercased()
            for needle in forbidden {
                XCTAssertFalse(lowered.contains(needle),
                               "\(string) must not claim an automatic \(needle) judgement")
            }
        }
        XCTAssertTrue(
            OpenTaskCopy.allStrings.contains(OpenTaskCopy.selfAssessmentTitle))
        XCTAssertEqual(OpenTaskCopy.selfAssessmentSubline,
                       "Your own judgement against the criteria — nothing here is marked right or wrong.")
    }
}

// MARK: - Dialogue turns and checkpoints (6.3)

/// Store-level contract for branching-exchange practice: each answered
/// turn records one `DialogueTurnEvent` (authored turn order, learner's
/// own self-assessment on open turns, never the draft), replay records a
/// fresh attempt without duplicating rows, the exchange slice survives
/// force-quit through the lesson checkpoint, and the copy never claims an
/// automatic judgement.

@MainActor
final class DialogueStoreTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("condisco-dialogue-store-tests-\(UUID().uuidString)")
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

    private func spanishPack() throws -> CoursePack {
        try XCTUnwrap(
            PackLoader.loadPacks().first { $0.language.slug == "spanish" })
    }

    /// The café exchange's host lesson + dialogue.
    private func cafeBinding(in pack: CoursePack) throws -> (lesson: Lesson, dialogue: Dialogue) {
        let lesson = try XCTUnwrap(pack.lesson(id: "es-cafe-requests-foundation"))
        let dialogue = try XCTUnwrap(pack.dialogue(id: "es-cafe-turno"))
        return (lesson, dialogue)
    }

    /// Turns recorded in authored order read back in authored order —
    /// event rows may sort however they like, `turnIndex` pins the thread.
    func testDialogueTurnsRecordInAuthoredTurnOrder() throws {
        let store = try makeStore()
        let pack = try spanishPack()
        let (lesson, dialogue) = try cafeBinding(in: pack)
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        let turn1 = try XCTUnwrap(store.recordDialogueTurn(
            pack: pack, lessonId: lesson.id, dialogueId: dialogue.id,
            nodeId: "greet", turnIndex: 1, isOpen: false, choiceId: "order-coffee",
            criteriaMet: [], rating: nil, modelRevealed: false,
            at: base))
        let turn2 = try XCTUnwrap(store.recordDialogueTurn(
            pack: pack, lessonId: lesson.id, dialogueId: dialogue.id,
            nodeId: "mishear", turnIndex: 2, isOpen: false, choiceId: "correct-coffee",
            criteriaMet: [], rating: nil, modelRevealed: false,
            at: base.addingTimeInterval(1)))
        let turn3 = try XCTUnwrap(store.recordDialogueTurn(
            pack: pack, lessonId: lesson.id, dialogueId: dialogue.id,
            nodeId: "algo-mas", turnIndex: 3, isOpen: true, choiceId: nil,
            criteriaMet: ["meaning", "useful-language"], rating: .good,
            modelRevealed: false,
            at: base.addingTimeInterval(2)))

        XCTAssertTrue(turn1.isOpen == false && turn2.isOpen == false)
        XCTAssertTrue(turn3.isOpen)
        XCTAssertEqual(turn3.criteriaMet, ["meaning", "useful-language"])
        XCTAssertEqual(turn3.rating, .good)
        XCTAssertFalse(turn3.modelRevealed)

        let progress = try store.project(pack: pack)
        XCTAssertEqual(progress.dialogueTurns.map(\.id),
                       [turn1.id, turn2.id, turn3.id])
        XCTAssertEqual(progress.dialogueTurns.map(\.turnIndex), [1, 2, 3],
                       "the exchange's events replay in authored turn order")
        XCTAssertEqual(progress.dialogueTurns.map(\.dialogueId),
                       [dialogue.id, dialogue.id, dialogue.id])
        XCTAssertEqual(progress.dialogueTurns.map(\.hostLessonId),
                       [lesson.id, lesson.id, lesson.id])
        XCTAssertEqual(progress.dialogueTurns.map(\.hostLessonRevision),
                       [lesson.revision, lesson.revision, lesson.revision])
        XCTAssertTrue(progress.quarantined.isEmpty)
    }

    /// Replay semantics: re-recording the identical event is a no-op, and
    /// a fresh attempt (a new turn with a new id) appends without touching
    /// earlier rows — nothing is ever duplicated or reordered.
    func testDialogueReplayRecordsNoDuplicateEvents() throws {
        let store = try makeStore()
        let pack = try spanishPack()
        let (lesson, dialogue) = try cafeBinding(in: pack)
        let at = Date(timeIntervalSince1970: 1_700_000_200)

        let event = try XCTUnwrap(store.recordDialogueTurn(
            pack: pack, lessonId: lesson.id, dialogueId: dialogue.id,
            nodeId: "greet", turnIndex: 1, isOpen: false, choiceId: "order-coffee",
            criteriaMet: [], rating: nil, modelRevealed: false, at: at))
        // Identical replay of the same attempt turn is a no-op.
        try store.record(.dialogueTurn(event))

        // A fresh attempt answers the same node with a fresh id.
        let retake = try XCTUnwrap(store.recordDialogueTurn(
            pack: pack, lessonId: lesson.id, dialogueId: dialogue.id,
            nodeId: "greet", turnIndex: 1, isOpen: false, choiceId: "order-coffee",
            criteriaMet: [], rating: nil, modelRevealed: false,
            at: at.addingTimeInterval(60)))

        let progress = try store.project(pack: pack)
        XCTAssertEqual(progress.dialogueTurns.map(\.id), [event.id, retake.id])
        XCTAssertEqual(Set(progress.dialogueTurns.map(\.id)).count, 2,
                       "replay as a new attempt adds rows; replay of the SAME attempt adds none")
    }

    /// Reveal-before-answer honesty: an open turn with the model shown is
    /// recorded with the marker, so it stays distinguishable from an
    /// independent composition — never invented as independent.
    func testDialogueOpenTurnModelRevealIsRecorded() throws {
        let store = try makeStore()
        let pack = try spanishPack()
        let (lesson, dialogue) = try cafeBinding(in: pack)
        let at = Date(timeIntervalSince1970: 1_700_000_300)

        let revealed = try XCTUnwrap(store.recordDialogueTurn(
            pack: pack, lessonId: lesson.id, dialogueId: dialogue.id,
            nodeId: "algo-mas", turnIndex: 4, isOpen: true, choiceId: nil,
            criteriaMet: ["meaning"], rating: nil, modelRevealed: true, at: at))
        let progress = try store.project(pack: pack)
        XCTAssertEqual(progress.dialogueTurns.count, 1)
        XCTAssertTrue(progress.dialogueTurns[0].modelRevealed)
        XCTAssertFalse(progress.dialogueTurns[0].criteriaMet.contains("organization"))
        XCTAssertEqual(progress.dialogueTurns[0].id, revealed.id)
    }

    /// A turn whose dialogue (or node) is no longer in the bundled pack
    /// quarantines instead of failing the read — learner-owned history
    /// stays observable, never used.
    func testDialogueTurnUnknownBindingQuarantines() throws {
        let store = try makeStore()
        let pack = try spanishPack()
        let (lesson, _) = try cafeBinding(in: pack)
        let introLesson = try XCTUnwrap(pack.lesson(id: "es-introductions-foundation"))
        let at = Date(timeIntervalSince1970: 1_700_000_400)

        let unknown = DialogueTurnEvent(
            id: "dialogue-turn-ghost", packId: pack.id, packVersion: pack.version,
            dialogueId: "es-dialogue-gone", hostLessonId: lesson.id,
            hostLessonRevision: lesson.revision, nodeId: "greet",
            turnIndex: 1, isOpen: false, choiceId: "x",
            criteriaMet: [], rating: nil, modelRevealed: false, at: at)
        try store.record(.dialogueTurn(unknown))

        // The café dialogue bound to a lesson that does NOT host it.
        let wrongHost = DialogueTurnEvent(
            id: "dialogue-turn-wrong-host", packId: pack.id, packVersion: pack.version,
            dialogueId: "es-cafe-turno", hostLessonId: introLesson.id,
            hostLessonRevision: introLesson.revision, nodeId: "greet",
            turnIndex: 1, isOpen: false, choiceId: "order-coffee",
            criteriaMet: [], rating: nil, modelRevealed: false, at: at)
        try store.record(.dialogueTurn(wrongHost))

        // The record helper refuses a binding that does not resolve: it
        // records nothing rather than minting an event for an unknown host.
        let refused = try store.recordDialogueTurn(
            pack: pack, lessonId: introLesson.id,
            dialogueId: "es-cafe-turno", nodeId: "greet",
            turnIndex: 1, isOpen: false, choiceId: "order-coffee",
            criteriaMet: [], rating: nil, modelRevealed: false, at: at)
        XCTAssertNil(refused,
                     "recordDialogueTurn must refuse a host that does not host the dialogue")

        let progress = try store.project(pack: pack)
        XCTAssertTrue(progress.quarantined.contains(unknown.id),
                      "a turn whose dialogue is gone quarantines")
        XCTAssertTrue(progress.quarantined.contains(wrongHost.id),
                      "a turn whose host lesson does not host its dialogue quarantines")
        XCTAssertTrue(progress.dialogueTurns.isEmpty)
    }

    /// Force-quit continuity: the exchange slice (branch position + the
    /// learner's answered turns + in-progress draft) survives a checkpoint
    /// save/load round-trip byte-identically.
    func testDialogueCheckpointRoundTripPreservesExchange() throws {
        let store = try makeStore()
        let pack = try spanishPack()
        let (lesson, _) = try cafeBinding(in: pack)
        let at = Date(timeIntervalSince1970: 1_700_000_500)

        let dialogue = DialogueCheckpointState(
            dialogueId: "es-cafe-turno",
            currentNodeId: "recover",
            visitedNodeIds: ["greet", "mishear", "recover"],
            turns: [
                DialogueTurnRecord(nodeId: "greet", choiceId: "order-coffee"),
                DialogueTurnRecord(nodeId: "mishear", choiceId: "correct-coffee"),
            ],
            openDraft: nil,
            complete: false)
        let checkpoint = LessonCheckpoint(
            packId: pack.id, lessonId: lesson.id, revision: lesson.revision,
            stepId: lesson.steps.last!.id,
            selectedBranches: [:], assistance: [], draft: nil, at: at,
            dialogue: dialogue)
        try store.saveCheckpoint(checkpoint)

        let loaded = try XCTUnwrap(store.loadCheckpoint(packId: pack.id, lessonId: lesson.id))
        XCTAssertEqual(loaded, checkpoint)
        XCTAssertEqual(loaded.dialogue, dialogue,
                       "branch position + answered turns survive the force-quit round-trip")
        XCTAssertEqual(loaded.dialogue?.visitedNodeIds,
                       ["greet", "mishear", "recover"])
        XCTAssertEqual(loaded.dialogue?.turns.map(\.choiceId),
                       ["order-coffee", "correct-coffee"])
    }

    /// Old checkpoints — saved before 6.3, with no `dialogue` key — decode
    /// unchanged (nil exchange state) and re-encode without the key.
    func testOldCheckpointWithoutDialogueStateStillDecodes() throws {
        var old = LessonCheckpoint(
            packId: "es-foundations", lessonId: "es-cafe-requests-foundation",
            revision: 1, stepId: "es-cafe-requests-foundation-step-intro",
            selectedBranches: [:], assistance: [], draft: nil,
            at: Date(timeIntervalSince1970: 1_700_000_600))
        // Simulate the pre-6.3 encoder: no dialogue key is emitted.
        let encoder = JSONEncoder()
        let data = try encoder.encode(old)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNil(object["dialogue"],
                     "pre-6.3 checkpoints carry no dialogue key")

        let decoded = try JSONDecoder().decode(LessonCheckpoint.self, from: data)
        XCTAssertNil(decoded.dialogue)
        XCTAssertEqual(decoded, old)

        // And a dialogue-bearing checkpoint decodes back fully.
        old.dialogue = DialogueCheckpointState(
            dialogueId: "es-cafe-turno", currentNodeId: "greet",
            visitedNodeIds: ["greet"], turns: [], openDraft: "Hola.",
            complete: false)
        let withDialogue = try JSONDecoder().decode(
            LessonCheckpoint.self, from: try encoder.encode(old))
        XCTAssertEqual(withDialogue.dialogue?.openDraft, "Hola.")
    }

    /// Copy pin test (plan 6.3): the new learner-facing strings — app copy
    /// and the authored exchange wording (lines, meanings, choices,
    /// feedback, prompts, models, rubric criteria) — never claim an
    /// automatic judgement: no correct/incorrect, no score, no
    /// graded/CEFR/level phrasing.
    func testDialogueCopyBansGradingClaims() throws {
        let pack = try spanishPack()
        var all: [String] = DialoguePracticeCopy.allStrings
        for dialogue in pack.dialogues where dialogue.hostLessonId != nil {
            for node in dialogue.nodes {
                all.append(node.line)
                all.append(node.meaning)
                for choice in node.choices {
                    all.append(choice.text)
                    all.append(choice.feedback)
                }
                if let prompt = node.prompt { all.append(prompt) }
                if let model = node.modelResponse { all.append(model) }
                for criterion in node.rubric ?? [] {
                    all.append(criterion.text)
                }
            }
        }
        let forbidden = ["correct", "incorrect", "score", "graded", "cefr", "level"]
        for string in all {
            let lowered = string.lowercased()
            for needle in forbidden {
                XCTAssertFalse(lowered.contains(needle),
                               "\(string) must not claim an automatic \(needle) judgement")
            }
        }
        XCTAssertTrue(DialoguePracticeCopy.allStrings.contains(
            DialoguePracticeCopy.recapNote))
        XCTAssertEqual(DialoguePracticeCopy.hero, "Conversation practice")
    }
}

// MARK: - Practice library (8.2 slice 1): documents + links

/// Store-level slice-1 pins for the practice library (design §3, §8):
/// document CRUD, link dedup, delete semantics, and unsave cleanup.
/// Every row-count assertion reads raw SQLite through a second connection
/// (WAL allows concurrent readers), so "nothing else was written" is
/// checked byte-for-byte.
@MainActor
final class ImportedDocumentTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("condisco-library-tests-\(UUID().uuidString)")
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

    private func storePath() -> String {
        tempDir.appendingPathComponent("store.sqlite").path
    }

    /// Exact row count in `table` as a second connection sees it.
    private func rawCount(_ table: String) throws -> Int {
        let db = try Database(path: storePath())
        var count = 0
        try db.query(
            "SELECT COUNT(*) FROM \(table);",
            row: { count = Int($0.int64(0)) })
        return count
    }

    /// The exact stored event rows (id + payload), byte-for-byte, one
    /// string per row joined with NUL so the comparison type is Equatable
    /// (arrays of tuples are not). SQLite WAL allows concurrent readers,
    /// so a snapshot taken while `store` is open reflects committed state.
    private func rawEventRows() throws -> [String] {
        let db = try Database(path: storePath())
        var rows: [String] = []
        try db.query(
            "SELECT id, payload FROM events ORDER BY at_ms, id;",
            row: { rows.append(($0.text(0) ?? "") + "\u{0}" + ($0.text(1) ?? "")) })
        return rows
    }

    /// A deterministic saved phrase (id = language|target|meaning).
    private func makePhrase(pack: CoursePack, at: Date) -> SavedPhrase {
        let target = "la gare"
        let meaning = "the station"
        return SavedPhrase(
            id: LearningStore.savedPhraseId(
                languageSlug: pack.language.slug, target: target, meaning: meaning),
            languageSlug: pack.language.slug,
            languageName: pack.language.displayName,
            target: target,
            meaning: meaning,
            source: "My document",
            savedAt: at)
    }

    /// A valid independent-correct attempt on the first practice step of
    /// fr-home-foundation (a selection activity) — a realistic event row
    /// the delete transaction must not touch.
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

    private func makeDocument(
        id: String, title: String, content: String, pack: CoursePack,
        at: Date, sourceFileName: String = ""
    ) -> ImportedDocument {
        ImportedDocument(
            id: id,
            title: title,
            content: content,
            byteSize: content.data(using: .utf8)!.count,
            languageSlug: pack.language.slug,
            sourceFileName: sourceFileName,
            importedAt: at)
    }

    func testDocumentSaveAndReadBackPreservesTitleDateAndContent() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let importedAt = Date(timeIntervalSince1970: 1_700_000_123)
        let doc = makeDocument(
            id: "doc-1", title: "Ma première lecture",
            content: "Bonjour tout le monde, je m'appelle Marie.",
            pack: pack, at: importedAt, sourceFileName: "ma-lecture.txt")

        try store.saveDocument(doc)

        let all = try store.documents()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0], doc)
        let loaded = try XCTUnwrap(store.document(id: doc.id))
        XCTAssertEqual(loaded.title, doc.title)
        XCTAssertEqual(loaded.content, doc.content)
        XCTAssertEqual(loaded.byteSize, doc.byteSize)
        XCTAssertEqual(loaded.languageSlug, pack.language.slug)
        XCTAssertEqual(loaded.sourceFileName, "ma-lecture.txt")
        XCTAssertEqual(loaded.importedAt, importedAt)

        // Import order, newest first.
        let older = makeDocument(
            id: "doc-0", title: "Older", content: "Un texte.",
            pack: pack, at: importedAt.addingTimeInterval(-60))
        try store.saveDocument(older)
        XCTAssertEqual(try store.documents().map(\.id), ["doc-1", "doc-0"])

        // Done-when (a) at the store level: the save wrote exactly the
        // document row — zero new rows in the event log or any
        // sync/export-facing table, so the document text lives only in
        // the new tables.
        XCTAssertEqual(try rawCount("events"), 0)
        XCTAssertEqual(try rawCount("sync_uploads"), 0)
        XCTAssertEqual(try rawCount("checkpoints"), 0)
        XCTAssertEqual(try rawCount("checkpoint_tombstones"), 0)
        XCTAssertEqual(try rawCount("saved_phrases"), 0)
        XCTAssertEqual(try rawCount("saved_phrase_tombstones"), 0)
        XCTAssertEqual(try rawCount("listen_state"), 0)
        XCTAssertEqual(try rawCount("kv"), 0)
        XCTAssertEqual(try rawCount("imported_documents"), 2)
        XCTAssertEqual(try rawCount("imported_phrase_links"), 0)
        XCTAssertTrue(try store.unsyncedEvents().isEmpty)
    }

    /// Done-when (c): deleting a document removes its own rows and links
    /// and nothing else — the event log stays byte-identical, and the
    /// phrasebook, checkpoints, tombstones, and sync bookkeeping are
    /// untouched.
    func testDocumentDeleteRemovesOnlyDocumentAndLinkRows() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let at = Date(timeIntervalSince1970: 1_700_000_000)

        // Seed the world the delete must NOT touch.
        let phrase = makePhrase(pack: pack, at: at)
        try store.savePhrase(phrase)
        let attempt = try makeAttempt(id: "lib-event-1", pack: pack, at: at)
        try store.record(.attempt(attempt))
        let lesson = try XCTUnwrap(pack.lesson(id: "fr-home-foundation"))
        let checkpoint = LessonCheckpoint(
            packId: pack.id, lessonId: lesson.id, revision: lesson.revision,
            stepId: lesson.steps.first!.id, selectedBranches: [:],
            assistance: [], draft: nil, at: at)
        try store.saveCheckpoint(checkpoint)

        let doc = makeDocument(
            id: "doc-del", title: "À supprimer", content: "Le contenu privé.",
            pack: pack, at: at)
        try store.saveDocument(doc)
        try store.linkPhrase(phraseId: phrase.id, documentId: doc.id)
        XCTAssertEqual(try rawCount("imported_phrase_links"), 1)

        // Snapshot everything the delete must leave identical.
        let eventsBefore = try rawEventRows()
        let checkpointsBefore = try store.allCheckpoints()
        let savedBefore = try store.allSavedPhrases()
        let tombstonesBefore = try store.allSavedPhraseTombstones()
        let checkpointRowsBefore = try rawCount("checkpoints")
        let syncUploadsBefore = try rawCount("sync_uploads")

        try store.deleteDocument(id: doc.id)

        // The document and its links are gone...
        XCTAssertNil(try store.document(id: doc.id))
        XCTAssertTrue(try store.documents().isEmpty)
        XCTAssertTrue(try store.documentIDs(forPhrase: phrase.id).isEmpty)
        XCTAssertEqual(try rawCount("imported_documents"), 0)
        XCTAssertEqual(try rawCount("imported_phrase_links"), 0)
        // ...and nothing else moved: the event log is byte-identical (row
        // count AND content), and the phrasebook, checkpoints, tombstones,
        // and sync bookkeeping are untouched.
        XCTAssertEqual(try rawEventRows(), eventsBefore)
        XCTAssertEqual(try store.allEvents().count, 1)
        XCTAssertEqual(
            try store.allEvents().compactMap { event -> ActivityAttempt? in
                guard case .attempt(let stored) = event else { return nil }
                return stored
            },
            [attempt])
        XCTAssertEqual(try store.allCheckpoints(), checkpointsBefore)
        XCTAssertEqual(try rawCount("checkpoints"), checkpointRowsBefore)
        XCTAssertEqual(try store.allSavedPhrases(), savedBefore)
        XCTAssertEqual(try store.savedPhrases().map(\.id), [phrase.id])
        XCTAssertEqual(try store.allSavedPhraseTombstones(), tombstonesBefore)
        XCTAssertEqual(try rawCount("sync_uploads"), syncUploadsBefore)
        XCTAssertEqual(try store.unsyncedEvents().count, 1)
    }

    /// §3.3 cleanup: a phrase removed from the phrasebook must not leave
    /// dangling provenance links — the document itself stays.
    func testUnsavePhraseCleansLinks() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        let phrase = makePhrase(pack: pack, at: at)
        let doc = makeDocument(
            id: "doc-1", title: "Doc", content: "Un texte.", pack: pack, at: at)
        try store.savePhrase(phrase)
        try store.saveDocument(doc)
        try store.linkPhrase(phraseId: phrase.id, documentId: doc.id)
        XCTAssertEqual(try rawCount("imported_phrase_links"), 1)

        try store.unsavePhrase(id: phrase.id)

        XCTAssertFalse(try store.isPhraseSaved(id: phrase.id))
        XCTAssertEqual(try rawCount("imported_phrase_links"), 0)
        XCTAssertNotNil(try store.document(id: doc.id),
                        "unsaving a phrase never deletes its document")
    }

    /// §3.2/§6.5: re-linking an existing link is a no-op — one row.
    func testPhraseLinkDeduplicatesOnDoubleInsert() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        let doc = makeDocument(
            id: "doc-1", title: "Doc", content: "Un texte.", pack: pack, at: at)
        try store.saveDocument(doc)
        let phraseId = "\(pack.language.slug)|la gare|the station"

        try store.linkPhrase(phraseId: phraseId, documentId: doc.id)
        try store.linkPhrase(phraseId: phraseId, documentId: doc.id)

        XCTAssertEqual(try rawCount("imported_phrase_links"), 1)
        XCTAssertEqual(try store.documentIDs(forPhrase: phraseId), ["doc-1"])
        XCTAssertEqual(try store.phraseLinks().count, 1)
    }
}

// MARK: - Library import validator (8.2 §5)

/// Pure, side-effect-free validation of raw UTF-8 text: size cap, UTF-8
/// decodability, and non-empty — with plain-language errors, mirroring
/// `ImportValidator`'s discipline.
final class LibraryImportValidatorTests: XCTestCase {

    func testBoundedFileReadRejectsOversizeAndAcceptsExactLimit() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("passage.txt")
        try Data(repeating: 65, count: 1_048_576).write(to: url)
        XCTAssertEqual(try LibraryImportValidator.readFile(url).count, 1_048_576)
        try Data(repeating: 65, count: 4_194_304).write(to: url)
        XCTAssertThrowsError(try LibraryImportValidator.readFile(url)) { error in
            XCTAssertEqual(error as? LibraryImportError,
                           .tooLarge(actualBytes: 1_048_577, limitBytes: 1_048_576))
        }
        try FileManager.default.removeItem(at: url)
        XCTAssertThrowsError(try LibraryImportValidator.readFile(url))
    }

    func testBinaryControlPayloadIsRejected() {
        for bytes: [UInt8] in [[0], [65, 0, 66], [65, 7, 66], [65, 127, 66]] {
            if case .success = LibraryImportValidator.validate(Data(bytes)) {
                XCTFail("binary controls must not be accepted as readable text: \(bytes)")
            }
        }
    }

    func testUTF8BOMIsRemovedWithoutChangingReadableWhitespace() {
        let bytes = Data([0xEF, 0xBB, 0xBF]) + Data("  café\t\nOlá ✨\r\n".utf8)
        XCTAssertEqual(LibraryImportValidator.validate(bytes),
                       .success("  café\t\nOlá ✨\r\n"))
        XCTAssertEqual(LibraryImportValidator.validate(Data([0xEF, 0xBB, 0xBF])),
                       .failure(.empty))
    }

    func testValidUTF8TextAccepted() throws {
        let text = "Bonjour ! Ceci est un texte UTF-8. ✨"
        let data = try XCTUnwrap(text.data(using: .utf8))
        let result = LibraryImportValidator.validate(data)
        guard case .success(let decoded) = result else {
            return XCTFail("valid UTF-8 must pass, got \(result)")
        }
        XCTAssertEqual(decoded, text)
        let reencoded = try XCTUnwrap(decoded.data(using: .utf8))
        XCTAssertEqual(reencoded, data,
                       "the decoded text is returned as-is, whitespace included")
    }

    func testOverSizedTextRejectedWithPlainCopy() {
        // Exactly at the limit passes (boundary pinned), one byte over
        // fails before any decoding.
        let atLimit = Data(repeating: 0x61, count: LibraryImportValidator.maxDocumentBytes)
        guard case .success = LibraryImportValidator.validate(atLimit) else {
            return XCTFail("text at exactly the limit must pass")
        }
        let over = Data(repeating: 0x61, count: LibraryImportValidator.maxDocumentBytes + 1)
        let result = LibraryImportValidator.validate(over)
        guard case .failure(let error) = result else {
            return XCTFail("oversize text must be rejected, got \(result)")
        }
        XCTAssertEqual(error, .tooLarge(
            actualBytes: LibraryImportValidator.maxDocumentBytes + 1,
            limitBytes: LibraryImportValidator.maxDocumentBytes))
        XCTAssertEqual(
            error.description,
            "This text is too long to import (the limit is 1 MB).")
    }

    func testNonUTF8DataRejectedWithPlainCopy() {
        // 0xC3 starts a two-byte sequence; 0x28 ('(') is not a valid
        // continuation byte, so this is undecodable UTF-8.
        let binary: [UInt8] = [0xC3, 0x28]
        let result = LibraryImportValidator.validate(Data(binary))
        guard case .failure(let error) = result else {
            return XCTFail("undecodable data must be rejected, got \(result)")
        }
        XCTAssertEqual(error, .notUTF8)
        XCTAssertEqual(
            error.description,
            "This file isn't readable as UTF-8 text. Nothing was imported.")
    }

    func testEmptyTextRejected() {
        XCTAssertEqual(LibraryImportValidator.validate(Data()), .failure(.empty))
        let whitespace = Data(" \n\t  ".utf8)
        XCTAssertEqual(
            LibraryImportValidator.validate(whitespace), .failure(.empty))
        XCTAssertEqual(
            LibraryImportError.empty.description,
            "There's no text here to import.")
    }
}

// MARK: - Library import/save commit path (8.2 §5-§6)

/// Slice-3 model-layer tests for the two UI commit paths: the import
/// gateway (raw bytes → validator → document row) and the save sheet's
/// phrase + link action. The views themselves are thin — all of the logic
/// they run lives in `LibraryImport` and `LibrarySavePhrase`, which are
/// UIKit-free by construction.
@MainActor
final class LibraryCommitTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("condisco-library-commit-tests-\(UUID().uuidString)")
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

    private func storePath() -> String {
        tempDir.appendingPathComponent("store.sqlite").path
    }

    private func rawCount(_ table: String) throws -> Int {
        let db = try Database(path: storePath())
        var count = 0
        try db.query(
            "SELECT COUNT(*) FROM \(table);",
            row: { count = Int($0.int64(0)) })
        return count
    }

    /// The import commit path both entry points run (§5): raw bytes →
    /// `LibraryImport.makeDocument` (the single validator gateway) → the
    /// store row, preserving title, content, byte count, language, and
    /// the original file name.
    func testImportCommitValidatesBytesAndWritesDocumentRow() throws {
        let store = try makeStore()
        let importedAt = Date(timeIntervalSince1970: 1_700_000_123)
        let text = "Bonjour tout le monde, je m'appelle Marie."
        let data = try XCTUnwrap(text.data(using: .utf8))

        let made = LibraryImport.makeDocument(
            data: data, title: "ma-lecture", languageSlug: "french",
            sourceFileName: "ma-lecture.txt", importedAt: importedAt)
        guard case .success(let document) = made else {
            return XCTFail("valid UTF-8 text must commit, got \(made)")
        }
        try store.saveDocument(document)

        let loaded = try XCTUnwrap(store.document(id: document.id))
        XCTAssertEqual(loaded.title, "ma-lecture")
        XCTAssertEqual(loaded.title, document.title)
        XCTAssertEqual(loaded.content, text)
        XCTAssertEqual(loaded.byteSize, data.count)
        XCTAssertEqual(loaded.languageSlug, "french")
        XCTAssertEqual(loaded.sourceFileName, "ma-lecture.txt")
        XCTAssertEqual(loaded.importedAt, importedAt)
        XCTAssertEqual(try rawCount("imported_documents"), 1)
        XCTAssertEqual(try rawCount("events"), 0,
                       "an import writes no event-log rows")
    }

    /// Safe rejection (§5.2): an oversized document fails the single
    /// gateway with the pinned plain copy, and nothing is written.
    func testImportCommitRejectsOversizeAndWritesNothing() throws {
        let store = try makeStore()
        let over = Data(repeating: 0x61,
                        count: LibraryImportValidator.maxDocumentBytes + 1)

        let made = LibraryImport.makeDocument(
            data: over, title: "Big", languageSlug: "french",
            sourceFileName: "big.txt", importedAt: Date())
        guard case .failure(let error) = made else {
            return XCTFail("oversize text must be rejected, got \(made)")
        }
        XCTAssertEqual(error, .tooLarge(
            actualBytes: LibraryImportValidator.maxDocumentBytes + 1,
            limitBytes: LibraryImportValidator.maxDocumentBytes))
        XCTAssertEqual(
            error.description,
            "This text is too long to import (the limit is 1 MB).")
        XCTAssertTrue(try store.documents().isEmpty,
                      "a rejected import writes nothing")
        XCTAssertEqual(try rawCount("imported_documents"), 0)
    }

    /// Safe rejection (§5.2): undecodable data fails the gateway with the
    /// plain copy, and nothing is written.
    func testImportCommitRejectsNonUTF8AndWritesNothing() throws {
        let store = try makeStore()
        let binary: [UInt8] = [0xC3, 0x28]

        let made = LibraryImport.makeDocument(
            data: Data(binary), title: "Binary", languageSlug: "french",
            sourceFileName: "binary.txt", importedAt: Date())
        guard case .failure(let error) = made else {
            return XCTFail("undecodable data must be rejected, got \(made)")
        }
        XCTAssertEqual(error, .notUTF8)
        XCTAssertEqual(
            error.description,
            "This file isn't readable as UTF-8 text. Nothing was imported.")
        XCTAssertTrue(try store.documents().isEmpty)
        XCTAssertEqual(try rawCount("imported_documents"), 0)
    }

    /// §3.1: a blank or whitespace title falls back to "Untitled"; the
    /// paste default ("Pasted text") and file titles pass through as-is.
    func testImportCommitFallsBackToUntitledForBlankTitle() throws {
        for blank in ["", "   ", "\n\t"] {
            let made = LibraryImport.makeDocument(
                data: Data("Un texte.".utf8), title: blank,
                languageSlug: "french", sourceFileName: "", importedAt: Date())
            guard case .success(let document) = made else {
                return XCTFail("valid text must commit, got \(made)")
            }
            XCTAssertEqual(document.title, "Untitled",
                           "blank title \(blank.debugDescription) falls back")
        }
        let pasted = LibraryImport.makeDocument(
            data: Data("Un texte.".utf8), title: "Pasted text",
            languageSlug: "french", sourceFileName: "", importedAt: Date())
        guard case .success(let document) = pasted else {
            return XCTFail("valid text must commit, got \(pasted)")
        }
        XCTAssertEqual(document.title, "Pasted text")
        XCTAssertEqual(document.sourceFileName, "",
                       "paste imports carry no file name")
    }

    /// §5.1: the file-name title heuristic strips the extension, and a
    /// name that doesn't survive stripping falls back to the paste label.
    func testDocumentTitleFromFileURLStripsExtension() {
        let url = URL(fileURLWithPath: "/tmp/ma-lecture.txt")
        XCTAssertEqual(LibraryImport.title(fromFileURL: url), "ma-lecture")
        let nested = URL(fileURLWithPath: "/some/dir/chapitre-3.md")
        XCTAssertEqual(LibraryImport.title(fromFileURL: nested), "chapitre-3")
        XCTAssertEqual(
            LibraryImport.title(fromFileURL: URL(fileURLWithPath: "/tmp/README")),
            "README")
        XCTAssertEqual(
            LibraryImport.title(fromFileURL: URL(fileURLWithPath: "/tmp/")),
            "Pasted text")
    }

    /// §6.2/§11.3: the reader selection becomes a phrase only when it is
    /// non-empty after trimming and at most 200 characters — boundary
    /// pinned in both directions.
    func testPhraseTargetTrimsSelectionAndCapsAtTwoHundredChars() {
        XCTAssertNil(LibraryImport.phraseTarget(from: ""))
        XCTAssertNil(LibraryImport.phraseTarget(from: "   \n\t  "))
        XCTAssertEqual(
            LibraryImport.phraseTarget(from: "  Le chat  "), "Le chat")
        let atLimit = String(repeating: "a", count: LibraryImport.maxSelectionLength)
        XCTAssertEqual(
            LibraryImport.phraseTarget(from: atLimit), atLimit)
        let over = String(repeating: "a", count: LibraryImport.maxSelectionLength + 1)
        XCTAssertNil(LibraryImport.phraseTarget(from: over))
    }

    /// §6.5: the save sheet's single action writes exactly one phrase row
    /// plus one link row, with the document title as `source` and empty
    /// `sourcePackId`/`sourceLessonId` — so the phrasebook never
    /// deep-links into a document (§3.3) — and the linked phrase becomes a
    /// review candidate (§4.2).
    func testSaveSheetCommitWritesPhraseAndLinkWithEmptyPackSources() throws {
        let store = try makeStore()
        let made = LibraryImport.makeDocument(
            data: Data("La gare est grande.".utf8),
            title: "La ville", languageSlug: "french",
            sourceFileName: "la-ville.txt", importedAt: Date())
        guard case .success(let document) = made else {
            return XCTFail("valid text must commit, got \(made)")
        }
        try store.saveDocument(document)

        let savedAt = Date(timeIntervalSince1970: 1_700_000_500)
        let phrase = try LibrarySavePhrase.commit(
            store: store, document: document,
            target: "  la gare  ", meaning: "the station", savedAt: savedAt)

        XCTAssertEqual(
            phrase.id,
            LearningStore.savedPhraseId(
                languageSlug: "french", target: "la gare", meaning: "the station"),
            "the phrase id stays the deterministic language|target|meaning key")
        let rows = try store.savedPhrases()
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].source, document.title,
                       "source is the document title (§6.5.3)")
        XCTAssertEqual(rows[0].sourcePackId, "",
                       "library saves never carry a pack id")
        XCTAssertEqual(rows[0].sourceLessonId, "",
                       "library saves never carry a lesson id")
        XCTAssertEqual(rows[0].target, "la gare", "target is trimmed")
        XCTAssertEqual(rows[0].meaning, "the station")

        XCTAssertEqual(try rawCount("imported_phrase_links"), 1)
        XCTAssertEqual(try store.phraseLinks(), [ImportedPhraseLink(
            phraseId: phrase.id, documentId: document.id)])

        // The linked phrase is a live review candidate; the same save from
        // a second document is one phrase + one due item (§4.3).
        let candidates = LibraryReview.candidatePhrases(
            phrases: try store.savedPhrases(), links: try store.phraseLinks())
        XCTAssertEqual(candidates.map(\.id), [phrase.id])
    }
}

// MARK: - Phrase-review projection (8.2 §4)

/// The pure phrase-review projection: the exact FSRS fold from
/// `project(pack:)`, the deterministic evidence key, and the
/// link-joined candidate rule.
@MainActor
final class LibraryReviewTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("condisco-library-review-tests-\(UUID().uuidString)")
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

    private func storePath() -> String {
        tempDir.appendingPathComponent("store.sqlite").path
    }

    private func rawCount(_ table: String) throws -> Int {
        let db = try Database(path: storePath())
        var count = 0
        try db.query(
            "SELECT COUNT(*) FROM \(table);",
            row: { count = Int($0.int64(0)) })
        return count
    }

    private func makePhrase(pack: CoursePack, at: Date) -> SavedPhrase {
        let target = "la gare"
        let meaning = "the station"
        return SavedPhrase(
            id: LearningStore.savedPhraseId(
                languageSlug: pack.language.slug, target: target, meaning: meaning),
            languageSlug: pack.language.slug,
            languageName: pack.language.displayName,
            target: target,
            meaning: meaning,
            source: "Ma première lecture",
            savedAt: at)
    }

    /// A phrase-review attempt of the exact shape
    /// `ReviewItem.makeAttempt(verdict:)` records: self-rated, verdict
    /// mapped to outcome/independence, pack id `practice-library`.
    private func makePhraseAttempt(
        id: String, phraseId: String, verdict: ReviewVerdict, at: Date
    ) -> ActivityAttempt {
        ActivityAttempt(
            id: id,
            packId: LibraryReview.packId,
            packVersion: LibraryReview.packVersion,
            lessonId: "",
            lessonRevision: 0,
            stepId: "review",
            activityId: "phrase-review",
            activityRevision: 0,
            evidenceKey: LibraryReview.evidenceKey(phraseId: phraseId),
            response: verdict.response,
            assistance: [],
            evaluation: AttemptEvaluation(
                outcome: verdict.outcome,
                independent: verdict.independent,
                feedback: ""),
            at: at)
    }

    /// A pack-valid attempt on fr-home-foundation-step-rb2 (a selection
    /// activity) carrying the same verdict, so the pack fold sees the same
    /// grade and timing as the phrase fold.
    private func makeLessonVerdictAttempt(
        id: String, pack: CoursePack, verdict: ReviewVerdict, at: Date
    ) throws -> ActivityAttempt {
        let lesson = try XCTUnwrap(pack.lesson(id: "fr-home-foundation"))
        let step = try XCTUnwrap(
            lesson.steps.first { $0.id == "fr-home-foundation-step-rb2" })
        let activity = try XCTUnwrap(pack.activity(id: step.activityId))
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
            response: verdict.response,
            assistance: [],
            evaluation: AttemptEvaluation(
                outcome: verdict.outcome,
                independent: verdict.independent,
                feedback: ""),
            at: at)
    }

    /// §4.2: the phrase-review fold is the pack fold with a fixed mode —
    /// identical grades and timings produce the identical `FsrsState` and
    /// success/failure tallies from both paths, and the projected record
    /// drives a due card exactly like the pack side.
    func testLibraryProjectionMirrorsLessonFoldExactly() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let phraseId = "\(pack.language.slug)|la gare|the station"
        // One-second spacings and good/again/hard grades keep the FSRS
        // interval fuzz out of the picture (stability stays below the
        // 2.5-day fuzz threshold), so this pins the exact same numbers.
        let times = [
            Date(timeIntervalSince1970: 1_700_000_000),
            Date(timeIntervalSince1970: 1_700_000_001),
            Date(timeIntervalSince1970: 1_700_000_002),
            Date(timeIntervalSince1970: 1_700_000_003),
        ]
        let verdicts: [ReviewVerdict] = [.exact, .exact, .tryAgain, .close]

        var lessonAttempts: [ActivityAttempt] = []
        var phraseAttempts: [ActivityAttempt] = []
        for (index, verdict) in verdicts.enumerated() {
            lessonAttempts.append(try makeLessonVerdictAttempt(
                id: "mirror-lesson-\(index)", pack: pack,
                verdict: verdict, at: times[index]))
            phraseAttempts.append(makePhraseAttempt(
                id: "mirror-phrase-\(index)", phraseId: phraseId,
                verdict: verdict, at: times[index]))
        }
        for attempt in lessonAttempts {
            try store.record(.attempt(attempt))
        }

        let lessonKey = try XCTUnwrap(lessonAttempts.first?.evidenceKey)
        let progress = try store.project(pack: pack)
        let lessonRecord = try XCTUnwrap(progress.evidence[lessonKey])
        let phraseKey = LibraryReview.evidenceKey(phraseId: phraseId)
        let phraseRecord = try XCTUnwrap(
            LibraryReview.project(attempts: phraseAttempts)[phraseKey])

        XCTAssertEqual(phraseRecord.fsrs, lessonRecord.fsrs)
        XCTAssertEqual(phraseRecord.successes, lessonRecord.successes)
        XCTAssertEqual(phraseRecord.failures, lessonRecord.failures)
        XCTAssertEqual(phraseRecord.successes, 2)
        XCTAssertEqual(phraseRecord.failures, 2)
        XCTAssertEqual(phraseRecord.mode, .production)

        // The projected record drives a due card exactly like the pack
        // side: same dueAt (the same fold), same presentation ordinal.
        let phrase = SavedPhrase(
            id: phraseId,
            languageSlug: pack.language.slug,
            languageName: pack.language.displayName,
            target: "la gare",
            meaning: "the station",
            source: "Ma première lecture",
            savedAt: times[0])
        // The card surfaces exactly when its folded schedule says it is
        // due — ask one second past dueAt instead of assuming an absolute
        // horizon (the FSRS interval after these four grades is longer
        // than a minute). XCTUnwrap instead of subscript so a regression
        // fails cleanly instead of crashing the whole test run.
        let (due, _) = LibraryReview.loadDuePhrases(
            phrases: [phrase], attempts: phraseAttempts,
            now: phraseRecord.fsrs.dueAt.addingTimeInterval(1))
        XCTAssertEqual(due.count, 1)
        let card = try XCTUnwrap(due.first)
        XCTAssertEqual(card.evidenceKey, phraseKey)
        XCTAssertEqual(card.dueAt, phraseRecord.fsrs.dueAt)
        XCTAssertEqual(card.dueAt, lessonRecord.fsrs.dueAt)
        XCTAssertEqual(card.prompt, "la gare")
        XCTAssertEqual(card.answerText, "the station")
        XCTAssertEqual(card.courseTitle, "French")
        XCTAssertEqual(card.lessonTitle, "Ma première lecture")
        XCTAssertEqual(card.packId, LibraryReview.packId)
        XCTAssertEqual(card.packVersion, LibraryReview.packVersion)
    }

    /// §4.3: the evidence key is a pure function of the deterministic
    /// savedPhraseId — one phrase row ⇔ one evidence key, stable across
    /// re-saves, distinct across distinct phrases.
    func testPhraseReviewEvidenceKeyIsDeterministicPerPhraseId() {
        let first = LibraryReview.evidenceKey(phraseId: "french|la gare|the station")
        XCTAssertEqual(first, "phrase-review|french|la gare|the station")
        // Deterministic: same phrase id → same key, every time.
        XCTAssertEqual(
            LibraryReview.evidenceKey(phraseId: "french|la gare|the station"),
            first)
        // Distinct phrase id → distinct key.
        XCTAssertNotEqual(
            LibraryReview.evidenceKey(phraseId: "french|la gare|the station"),
            LibraryReview.evidenceKey(phraseId: "french|la gare|the bus stop"))
        XCTAssertNotEqual(
            LibraryReview.evidenceKey(phraseId: "french|la gare|the station"),
            LibraryReview.evidenceKey(phraseId: "french|le train|the train"))
        // The key is exactly the savedPhraseId under the phrase-review
        // prefix — the identity chain the dedup story rests on.
        XCTAssertEqual(
            LibraryReview.evidenceKey(
                phraseId: LearningStore.savedPhraseId(
                    languageSlug: "french", target: "la gare",
                    meaning: "the station")),
            first)
    }

    /// §4.3.2: saving the same phrase twice — same document — collapses
    /// to one saved_phrases row, one link row, one evidence key, and one
    /// (immediately-due) card. No duplicate cards by construction.
    func testDuplicateSaveProducesOneRowOneEvidenceKey() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        let phrase = makePhrase(pack: pack, at: at)
        let doc = ImportedDocument(
            id: "doc-1", title: "La ville", content: "La gare est grande.",
            byteSize: "La gare est grande.".data(using: .utf8)!.count,
            languageSlug: pack.language.slug, sourceFileName: "",
            importedAt: at)
        try store.saveDocument(doc)

        try store.savePhrase(phrase)
        try store.linkPhrase(phraseId: phrase.id, documentId: doc.id)
        // The same save again: deterministic id → no-op everywhere.
        try store.savePhrase(phrase)
        try store.linkPhrase(phraseId: phrase.id, documentId: doc.id)

        XCTAssertEqual(try store.savedPhrases().count, 1)
        XCTAssertEqual(try rawCount("saved_phrases"), 1)
        XCTAssertEqual(try rawCount("imported_phrase_links"), 1)

        // One candidate, one evidence key, one due card.
        let key = LibraryReview.evidenceKey(phraseId: phrase.id)
        let candidates = LibraryReview.candidatePhrases(
            phrases: try store.savedPhrases(), links: try store.phraseLinks())
        XCTAssertEqual(candidates.count, 1)
        let (due, _) = LibraryReview.loadDuePhrases(
            phrases: candidates, attempts: [], now: at.addingTimeInterval(60))
        XCTAssertEqual(due.count, 1)
        XCTAssertEqual(due[0].evidenceKey, key)
        XCTAssertEqual(due[0].prompt, phrase.target)
        // A fresh phrase is due immediately: Fsrs.initial at save time.
        XCTAssertEqual(due[0].dueAt, at)
    }

    /// §4.2/§8.2: the queue reflects live documents only — a saved phrase
    /// with no imported_phrase_links row (lesson-saved, or its documents
    /// deleted) is not a candidate and never enters the due queue.
    func testPhraseWithoutLinkIsNotACandidate() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        let unlinked = makePhrase(pack: pack, at: at)
        try store.savePhrase(unlinked)

        // No links at all → no candidates.
        let none = LibraryReview.candidatePhrases(
            phrases: try store.savedPhrases(), links: try store.phraseLinks())
        XCTAssertTrue(none.isEmpty)
        let (dueNone, _) = LibraryReview.loadDuePhrases(
            phrases: none, attempts: [], now: at.addingTimeInterval(60))
        XCTAssertTrue(dueNone.isEmpty)

        // Linking one of two phrases admits exactly that one.
        let linked = SavedPhrase(
            id: LearningStore.savedPhraseId(
                languageSlug: pack.language.slug, target: "le train",
                meaning: "the train"),
            languageSlug: pack.language.slug,
            languageName: pack.language.displayName,
            target: "le train",
            meaning: "the train",
            source: "Doc",
            savedAt: at)
        try store.savePhrase(linked)
        try store.linkPhrase(phraseId: linked.id, documentId: "doc-1")

        let after = LibraryReview.candidatePhrases(
            phrases: try store.savedPhrases(), links: try store.phraseLinks())
        XCTAssertEqual(after.map(\.id), [linked.id])
        let (due, _) = LibraryReview.loadDuePhrases(
            phrases: after, attempts: [], now: at.addingTimeInterval(60))
        XCTAssertEqual(
            due.map(\.evidenceKey),
            [LibraryReview.evidenceKey(phraseId: linked.id)])
    }
}

// MARK: - ReviewModel × library merge (8.2 §4.2, slice 2)

/// The library stream merged into the Review tab: phrases saved from live
/// documents enter the All-courses due queue, tricky list, and forecast
/// through `ReviewModel.reloadScoped()` — one phrase row ⇔ one evidence
/// key ⇔ one FSRS chain, so duplicates collapse by construction. The
/// focus-course scope, Home, widgets, reminders, and warm-ups stay on
/// bundled packs only.
@MainActor
final class ReviewLibraryTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("condisco-review-library-tests-\(UUID().uuidString)")
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

    private func storePath() -> String {
        tempDir.appendingPathComponent("store.sqlite").path
    }

    private func frenchPack() throws -> CoursePack {
        try XCTUnwrap(
            PackLoader.loadPacks().first { $0.language == .french })
    }

    private func rawCount(_ table: String) throws -> Int {
        let db = try Database(path: storePath())
        var count = 0
        try db.query(
            "SELECT COUNT(*) FROM \(table);",
            row: { count = Int($0.int64(0)) })
        return count
    }

    /// The exact stored event rows (id + payload), one string per row
    /// joined with NUL — a byte-for-byte comparison of the event log.
    private func rawEventRows() throws -> [String] {
        let db = try Database(path: storePath())
        var rows: [String] = []
        try db.query(
            "SELECT id, payload FROM events ORDER BY at_ms, id;",
            row: { rows.append(($0.text(0) ?? "") + "\u{0}" + ($0.text(1) ?? "")) })
        return rows
    }

    /// A deterministic saved phrase (id = language|target|meaning) whose
    /// savedAt is the queue's "date saved" for a fresh, never-reviewed card.
    private func makePhrase(pack: CoursePack, at: Date) -> SavedPhrase {
        let target = "la gare"
        let meaning = "the station"
        return SavedPhrase(
            id: LearningStore.savedPhraseId(
                languageSlug: pack.language.slug, target: target, meaning: meaning),
            languageSlug: pack.language.slug,
            languageName: pack.language.displayName,
            target: target,
            meaning: meaning,
            source: "Ma première lecture",
            savedAt: at)
    }

    private func makeDocument(
        id: String, title: String, content: String, pack: CoursePack,
        at: Date
    ) -> ImportedDocument {
        ImportedDocument(
            id: id, title: title, content: content,
            byteSize: content.data(using: .utf8)!.count,
            languageSlug: pack.language.slug, sourceFileName: "",
            importedAt: at)
    }

    /// Saves the phrase to a live document — the exact store calls the
    /// save sheet runs (§6.5) — so the phrase becomes a review candidate.
    /// The sheet prefills `source` with the document title (read-only,
    /// §6.5.3), so the saved row carries it as its provenance (§3.3);
    /// `sourcePackId`/`sourceLessonId` stay empty so the phrasebook's
    /// "open lesson" tap never deep-links into a document (§3.3).
    private func saveLibraryPhrase(
        store: LearningStore, phrase: SavedPhrase, document: ImportedDocument
    ) throws {
        try store.saveDocument(document)
        var fromDocument = phrase
        fromDocument.source = document.title
        try store.savePhrase(fromDocument)
        try store.linkPhrase(phraseId: phrase.id, documentId: document.id)
    }

    /// A phrase-review attempt of the exact shape
    /// `ReviewItem.makeAttempt(verdict:)` records: self-rated, verdict
    /// mapped to outcome/independence, pack id `practice-library`.
    private func makePhraseAttempt(
        id: String, phraseId: String, verdict: ReviewVerdict, at: Date
    ) -> ActivityAttempt {
        ActivityAttempt(
            id: id,
            packId: LibraryReview.packId,
            packVersion: LibraryReview.packVersion,
            lessonId: "",
            lessonRevision: 0,
            stepId: "review",
            activityId: "phrase-review",
            activityRevision: 0,
            evidenceKey: LibraryReview.evidenceKey(phraseId: phraseId),
            response: verdict.response,
            assistance: [],
            evaluation: AttemptEvaluation(
                outcome: verdict.outcome,
                independent: verdict.independent,
                feedback: ""),
            at: at)
    }

    /// A pack-valid due attempt (a selection or cloze step of the first
    /// available lesson), so the merged queue has a pack card to coexist
    /// with the phrase card.
    private func makeDueAttempt(
        id: String, pack: CoursePack, at: Date
    ) throws -> ActivityAttempt {
        let lesson = try XCTUnwrap(
            pack.lessons.first { lesson in
                lesson.steps.contains { isChoiceStep($0, in: pack) }
            }, "\(pack.id) needs a lesson with a selection or cloze step")
        let step = try XCTUnwrap(
            lesson.steps.first { isChoiceStep($0, in: pack) })
        let activity = try XCTUnwrap(pack.activity(id: step.activityId))
        let response: AttemptResponse
        switch activity {
        case .selection(let spec):
            response = .selection(ids: spec.acceptedIds)
        case .cloze(let spec):
            response = .cloze(values: Dictionary(
                uniqueKeysWithValues: spec.blanks.map {
                    ($0.key, $0.value.answers.first ?? "")
                }))
        default:
            throw XCTSkip("expected a selection or cloze step")
        }
        return ActivityAttempt(
            id: id, packId: pack.id, packVersion: pack.version,
            lessonId: lesson.id, lessonRevision: lesson.revision,
            stepId: step.id, activityId: activity.id,
            activityRevision: activity.revision,
            evidenceKey: activity.evidenceKey,
            response: response,
            assistance: [],
            evaluation: AttemptEvaluation(
                outcome: .correct, independent: true, feedback: "correct"),
            at: at)
    }

    private func isChoiceStep(_ step: LessonStep, in pack: CoursePack) -> Bool {
        guard let activity = pack.activity(id: step.activityId) else { return false }
        if case .selection = activity { return true }
        if case .cloze = activity { return true }
        return false
    }

    /// The stored phrase-review attempt events, oldest first.
    private func phraseAttempts(in events: [LearningEvent]) -> [ActivityAttempt] {
        events.compactMap { event -> ActivityAttempt? in
            guard case .attempt(let attempt) = event,
                  attempt.packId == LibraryReview.packId else { return nil }
            return attempt
        }
    }

    // MARK: Due queue: one linked phrase, one due card

    /// Done-when (b): a linked saved phrase with no review history is due
    /// in the merged queue exactly once — immediately at its save time,
    /// with one evidence key and provenance + TTS language on the card.
    func testLibraryPhrasesEnterDueQueueAfterSave() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        let phrase = makePhrase(pack: pack, at: at)
        let doc = makeDocument(
            id: "doc-1", title: "La ville", content: "La gare est grande.",
            pack: pack, at: at)
        try saveLibraryPhrase(store: store, phrase: phrase, document: doc)

        let model = try ReviewModel(
            store: store, packs: [pack], focusSlug: "french")
        let key = LibraryReview.evidenceKey(phraseId: phrase.id)
        XCTAssertEqual(model.due.filter { $0.evidenceKey == key }.count, 1,
                       "a linked new phrase is due exactly once")
        let item = try XCTUnwrap(
            model.due.first { $0.evidenceKey == key })
        XCTAssertEqual(item.packId, LibraryReview.packId)
        // A fresh phrase is due immediately: Fsrs.initial at save time.
        XCTAssertEqual(item.dueAt, at)
        XCTAssertEqual(item.prompt, phrase.target)
        XCTAssertEqual(item.answerText, phrase.meaning)
        XCTAssertEqual(item.courseTitle, pack.language.displayName)
        XCTAssertEqual(item.lessonTitle, doc.title)
        // TTS resolves the phrase's saved language, not the English fallback.
        XCTAssertEqual(model.languageCode(for: item),
                       ShadowVoice.languageCode(for: phrase.languageSlug))
        XCTAssertTrue(model.tricky.isEmpty)
        XCTAssertEqual(model.dueTomorrowCount, 0)
        XCTAssertNil(model.nextDueAt)
    }

    /// §4.3: saving the same phrase twice — from two different documents —
    /// yields one saved row, one evidence key, and exactly ONE due item in
    /// the merged queue. No duplicate cards, no duplicate keys.
    func testSamePhraseSavedTwiceYieldsOneDueItem() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        let phrase = makePhrase(pack: pack, at: at)
        let firstDoc = makeDocument(
            id: "doc-a", title: "La ville", content: "La gare est grande.",
            pack: pack, at: at)
        let secondDoc = makeDocument(
            id: "doc-b", title: "Le train", content: "Le train part.",
            pack: pack, at: at)
        // The same deterministic phrase saved from both documents.
        try saveLibraryPhrase(store: store, phrase: phrase, document: firstDoc)
        try saveLibraryPhrase(store: store, phrase: phrase, document: secondDoc)
        XCTAssertEqual(try store.savedPhrases().count, 1,
                       "re-saving the same phrase must not add a row")
        XCTAssertEqual(try rawCount("imported_phrase_links"), 2,
                       "one link row per source document")

        let model = try ReviewModel(
            store: store, packs: [pack], focusSlug: "french")
        let key = LibraryReview.evidenceKey(phraseId: phrase.id)
        XCTAssertEqual(model.due.filter { $0.evidenceKey == key }.count, 1,
                       "two saves must still yield exactly one due item")
        XCTAssertEqual(model.due.map(\.evidenceKey), [key],
                       "exactly one evidence key in the due queue")
    }

    // MARK: Verdict round-trip through the existing pipeline

    /// The graded phrase card records through the untouched
    /// `ReviewItem.makeAttempt` → `store.record(.attempt)` pipeline with
    /// the library pack id and the phrase evidence key, leaves the merged
    /// due queue, and returns when its scheduled dueAt arrives —
    /// schedule-relative, exactly like the projection mirror test.
    func testPhraseSaveReschedulesThroughSameFsrsFoldAsLessonReview() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        let phrase = makePhrase(pack: pack, at: at)
        let doc = makeDocument(
            id: "doc-1", title: "La ville", content: "La gare est grande.",
            pack: pack, at: at)
        try saveLibraryPhrase(store: store, phrase: phrase, document: doc)

        let model = try ReviewModel(
            store: store, packs: [pack], focusSlug: "french")
        let key = LibraryReview.evidenceKey(phraseId: phrase.id)
        let item = try XCTUnwrap(
            model.due.first { $0.evidenceKey == key },
            "the phrase card must be due before grading")
        XCTAssertEqual(item.packId, LibraryReview.packId)

        // Grade through the exact pipeline `ReviewModel.recordVerdict`
        // uses (store.record of the item's attempt) minus the widget
        // snapshot write.
        let gradedAt = Date()
        try store.record(.attempt(item.makeAttempt(verdict: .exact, at: gradedAt)))

        // A new `.attempt` event landed: library pack id + phrase key.
        let (events, _) = try store.allEventsWithQuarantine()
        let attempts = phraseAttempts(in: events)
        XCTAssertEqual(attempts.count, 1)
        let recorded = try XCTUnwrap(attempts.first)
        XCTAssertEqual(recorded.packId, LibraryReview.packId)
        XCTAssertEqual(recorded.packVersion, LibraryReview.packVersion)
        XCTAssertEqual(recorded.evidenceKey, key)
        XCTAssertEqual(recorded.response, ReviewVerdict.exact.response)
        XCTAssertTrue(recorded.evaluation.outcome == .correct)
        XCTAssertTrue(recorded.evaluation.independent)

        // The FSRS chain advanced and the card left the due queue.
        let record = try XCTUnwrap(
            LibraryReview.project(attempts: attempts)[key])
        XCTAssertEqual(record.fsrs.reps, 1)
        XCTAssertGreaterThan(record.fsrs.dueAt, gradedAt)
        let refreshed = try ReviewModel(
            store: store, packs: [pack], focusSlug: "french")
        XCTAssertFalse(
            refreshed.due.contains { $0.evidenceKey == key },
            "a fresh verdict must schedule the phrase out of 'due'")

        // ...and it returns when its scheduled dueAt arrives: ask one
        // second past the projected dueAt (never an absolute horizon).
        let candidates = LibraryReview.candidatePhrases(
            phrases: try store.savedPhrases(), links: try store.phraseLinks())
        let (dueAgain, _) = LibraryReview.loadDuePhrases(
            phrases: candidates, attempts: attempts,
            now: record.fsrs.dueAt.addingTimeInterval(1))
        XCTAssertEqual(dueAgain.count, 1)
        let returned = try XCTUnwrap(dueAgain.first)
        XCTAssertEqual(returned.evidenceKey, key)
        XCTAssertEqual(returned.dueAt, record.fsrs.dueAt)
    }

    /// §4.2/§8.2: a phrase with no live document link — saved from a
    /// lesson, or its document deleted — never enters the merged queue.
    /// Linking it admits exactly that one on the next reload.
    func testUnlinkedPhraseNeverAppears() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        let phrase = makePhrase(pack: pack, at: at)
        try store.savePhrase(phrase)

        let model = try ReviewModel(
            store: store, packs: [pack], focusSlug: "french")
        XCTAssertTrue(model.due.isEmpty, "an unlinked phrase must never be due")

        let doc = makeDocument(
            id: "doc-1", title: "La ville", content: "La gare est grande.",
            pack: pack, at: at)
        let key = LibraryReview.evidenceKey(phraseId: phrase.id)
        try store.saveDocument(doc)
        try store.linkPhrase(phraseId: phrase.id, documentId: doc.id)
        model.applyScope()
        XCTAssertEqual(model.due.filter { $0.evidenceKey == key }.count, 1)
    }

    /// Integration does not double-count or re-init: a phrase already
    /// carrying FSRS history (pre-seeded attempt events) projects with the
    /// same dueAt in the merged queue as in the pure projection — one item,
    /// not two, never re-initialized at its save time.
    func testPhraseWithHistoryProjectsSameDueAtInMergedQueue() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        let phrase = makePhrase(pack: pack, at: at)
        let doc = makeDocument(
            id: "doc-1", title: "La ville", content: "La gare est grande.",
            pack: pack, at: at)
        try saveLibraryPhrase(store: store, phrase: phrase, document: doc)

        // Pre-seeded review history: two real phrase-review attempts.
        for (index, verdict) in [ReviewVerdict.exact, .close].enumerated() {
            try store.record(.attempt(makePhraseAttempt(
                id: "lib-hist-\(index)", phraseId: phrase.id,
                verdict: verdict, at: at.addingTimeInterval(Double(index)))))
        }
        let attempts = phraseAttempts(in: try store.allEventsWithQuarantine().events)
        let key = LibraryReview.evidenceKey(phraseId: phrase.id)
        let expected = try XCTUnwrap(
            LibraryReview.project(attempts: attempts)[key])

        let model = try ReviewModel(
            store: store, packs: [pack], focusSlug: "french")
        let items = model.due.filter { $0.evidenceKey == key }
        XCTAssertEqual(items.count, 1,
                       "integration must not double-count a key with history")
        let item = try XCTUnwrap(items.first)
        XCTAssertEqual(item.dueAt, expected.fsrs.dueAt,
                       "the merged queue reuses the pure projection's dueAt")
        XCTAssertNotEqual(item.dueAt, at,
                          "history must not re-init the chain at save time")
        XCTAssertEqual(expected.fsrs.reps, 2)
    }

    /// No regression: a pack due item and a phrase due item coexist in one
    /// `reloadScoped()` call, each exactly once, with distinct evidence
    /// keys.
    func testPackAndPhraseDueCardsCoexistInOneReload() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        try store.record(.attempt(
            makeDueAttempt(id: "lib-pack-due", pack: pack, at: at)))
        let phrase = makePhrase(pack: pack, at: at)
        let doc = makeDocument(
            id: "doc-1", title: "La ville", content: "La gare est grande.",
            pack: pack, at: at)
        try saveLibraryPhrase(store: store, phrase: phrase, document: doc)

        let model = try ReviewModel(
            store: store, packs: [pack], focusSlug: "french")
        let phraseKey = LibraryReview.evidenceKey(phraseId: phrase.id)
        let packItem = try XCTUnwrap(
            model.due.first { $0.packId == pack.id },
            "pack due items must still appear in the merged queue")
        XCTAssertEqual(model.due.count, 2)
        XCTAssertEqual(model.due.filter { $0.packId == pack.id }.count, 1)
        XCTAssertEqual(model.due.filter { $0.evidenceKey == phraseKey }.count, 1)
        XCTAssertNotEqual(phraseKey, packItem.evidenceKey)
        // The pack card still gets its bundled-course voice.
        XCTAssertEqual(model.languageCode(for: packItem),
                       ShadowVoice.languageCode(for: pack.language.slug))
    }

    /// §4.2 scope semantics: the All-courses scope merges the library
    /// stream; the focus-course scope excludes it (the library is not a
    /// course). Switching mid-visit reveals and hides the phrase cards.
    func testFocusScopeExcludesLibraryWhileAllIncludesIt() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        let phrase = makePhrase(pack: pack, at: at)
        let doc = makeDocument(
            id: "doc-1", title: "La ville", content: "La gare est grande.",
            pack: pack, at: at)
        try saveLibraryPhrase(store: store, phrase: phrase, document: doc)

        let model = try ReviewModel(
            store: store, packs: [pack], focusSlug: "french")
        let key = LibraryReview.evidenceKey(phraseId: phrase.id)
        XCTAssertEqual(model.scope, .all)
        XCTAssertEqual(model.due.filter { $0.evidenceKey == key }.count, 1,
                       "All courses must include the library stream")

        model.scope = .focus
        model.applyScope()
        XCTAssertTrue(model.due.isEmpty,
                      "the focus-course scope must exclude library phrases")

        model.scope = .all
        model.applyScope()
        XCTAssertEqual(model.due.filter { $0.evidenceKey == key }.count, 1)
    }

    /// Shared all-course invitations include due library history.
    func testLibraryReviewCountsAgreeWithAllCourseInvitation() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        // A pack due item, so the bundled path has exactly one card.
        try store.record(.attempt(
            makeDueAttempt(id: "lib-home-pack", pack: pack, at: at)))
        let phrase = makePhrase(pack: pack, at: at)
        let doc = makeDocument(
            id: "doc-1", title: "La ville", content: "La gare est grande.",
            pack: pack, at: at)
        try saveLibraryPhrase(store: store, phrase: phrase, document: doc)
        // The phrase already has review history — the stream is live.
        let seeded = try ReviewModel(
            store: store, packs: [pack], focusSlug: "french")
        let phraseItem = try XCTUnwrap(
            seeded.due.first { $0.packId == LibraryReview.packId })
        try store.record(.attempt(phraseItem.makeAttempt(verdict: .exact, at: at)))

        let due = try ReviewCatalog.loadDue(packs: [pack], store: store)
        XCTAssertEqual(due.due.count, 2,
                       "all-course invitations must include due library phrases")
        let all = try ReviewModel(store: store, packs: [pack], focusSlug: "french")
        XCTAssertEqual(due.due.map(\.evidenceKey), all.due.map(\.evidenceKey))
        let tricky = try ReviewCatalog.loadTricky(packs: [pack], store: store)
        XCTAssertTrue(tricky.isEmpty)
        XCTAssertEqual(
            try ReviewCatalog.countDueWithin(packs: [pack], store: store, days: 1),
            0)
    }

    /// Done-when (b) + §8.2: deleting a document stops the queue from
    /// scheduling its phrases — the phrase drops out of the merged due
    /// queue, stays in the phrasebook, and every phrase-review event stays
    /// in the append-only log.
    func testDeletingDocumentStopsSchedulingButKeepsPhraseAndEvents() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        let phrase = makePhrase(pack: pack, at: at)
        let doc = makeDocument(
            id: "doc-del", title: "À supprimer", content: "Le contenu privé.",
            pack: pack, at: at)
        try saveLibraryPhrase(store: store, phrase: phrase, document: doc)
        let key = LibraryReview.evidenceKey(phraseId: phrase.id)

        let before = try ReviewModel(
            store: store, packs: [pack], focusSlug: "french")
        XCTAssertEqual(before.due.filter { $0.evidenceKey == key }.count, 1)

        // Review history the delete must not touch.
        try store.record(.attempt(makePhraseAttempt(
            id: "lib-del-1", phraseId: phrase.id, verdict: .close, at: at)))
        let eventsBefore = try rawEventRows()

        try store.deleteDocument(id: doc.id)

        let after = try ReviewModel(
            store: store, packs: [pack], focusSlug: "french")
        XCTAssertTrue(after.due.isEmpty,
                      "deleting the document must stop scheduling its phrase")
        XCTAssertEqual(try store.savedPhrases().map(\.id), [phrase.id],
                       "the phrase stays in the phrasebook")
        XCTAssertTrue(try store.documentIDs(forPhrase: phrase.id).isEmpty)
        XCTAssertEqual(try rawEventRows(), eventsBefore,
                       "the delete must not touch the event log")
    }

    /// The tricky list merges too: a phrase card rated "not yet" joins the
    /// tricky pass, and a later clean rating retires it.
    func testPhraseRatedNotYetEntersTrickyList() throws {
        let store = try makeStore()
        let pack = try frenchPack()
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        let phrase = makePhrase(pack: pack, at: at)
        let doc = makeDocument(
            id: "doc-1", title: "La ville", content: "La gare est grande.",
            pack: pack, at: at)
        try saveLibraryPhrase(store: store, phrase: phrase, document: doc)
        let key = LibraryReview.evidenceKey(phraseId: phrase.id)

        let model = try ReviewModel(
            store: store, packs: [pack], focusSlug: "french")
        XCTAssertTrue(model.tricky.isEmpty)

        let item = try XCTUnwrap(model.due.first { $0.evidenceKey == key })
        try store.record(.attempt(item.makeAttempt(verdict: .tryAgain, at: Date())))
        model.applyScope()
        let tricky = model.tricky.filter { $0.evidenceKey == key }
        XCTAssertEqual(tricky.count, 1,
                       "a 'not yet' rating must put the phrase in the tricky list")
        XCTAssertEqual(tricky.first?.packId, LibraryReview.packId)

        // A clean rating retires it from the tricky list.
        try store.record(.attempt(item.makeAttempt(verdict: .exact, at: Date())))
        model.applyScope()
        XCTAssertTrue(model.tricky.filter { $0.evidenceKey == key }.isEmpty)
    }
}


@MainActor
final class PracticeRecommendationTests: XCTestCase {
    func testSelfCompareSpeakingPracticeUpdatesRecencyWithoutDueEvidence() throws {
        let pack = try XCTUnwrap(PackLoader.loadPacks().first { $0.language == .french })
        let lesson = try XCTUnwrap(pack.lesson(id: "fr-cafe-mission"))
        let step = try XCTUnwrap(lesson.steps.first { $0.activityId == "fr-cafe-listen-say" })
        let activity = try XCTUnwrap(pack.activity(id: step.activityId))
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        let attempt = ActivityAttempt(id: "self-compare", packId: pack.id, packVersion: pack.version,
            lessonId: lesson.id, lessonRevision: lesson.revision, stepId: step.id,
            activityId: activity.id, activityRevision: activity.revision, evidenceKey: nil,
            response: .selfRating(.good), assistance: [],
            evaluation: AttemptEvaluation(outcome: .selfAssessed, independent: false, feedback: ""), at: at)
        let speaking = try XCTUnwrap(YouModel.skillPractice(pack: pack,
            events: [.attempt(attempt)], dueItems: []).first { $0.skill == .speaking })
        XCTAssertEqual(speaking.practisedTimes, 1)
        XCTAssertEqual(speaking.lastPractisedAt, at)
        XCTAssertEqual(speaking.dueCount, 0)
    }

    func testOpenSpokenPracticeUpdatesSpeakingRecencyWithoutCreatingDueCards() throws {
        let pack = try XCTUnwrap(PackLoader.loadPacks().first { $0.language == .german })
        let lesson = try XCTUnwrap(pack.lesson(id: "de-introductions-foundation"))
        let step = try XCTUnwrap(lesson.steps.first { $0.activityId == "de-introductions-listen-reply" })
        guard case .openTask(let spec)? = pack.activity(id: step.activityId) else {
            return XCTFail("expected the open spoken task")
        }
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        let event = OpenTaskAttemptEvent(id: "spoken", packId: pack.id, packVersion: pack.version,
            lessonId: lesson.id, lessonRevision: lesson.revision, stepId: step.id,
            activityId: spec.id, activityRevision: spec.revision, mode: .spoken,
            assistance: [], selfRating: nil, modelRevealed: true, at: at)
        let rows = YouModel.skillPractice(pack: pack, events: [.openTaskAttempt(event)], dueItems: [])
        let speaking = try XCTUnwrap(rows.first { $0.skill == .speaking })
        XCTAssertEqual(speaking.practisedTimes, 1)
        XCTAssertEqual(speaking.lastPractisedAt, at)
        XCTAssertEqual(speaking.dueCount, 0)
        var stale = event
        stale.activityRevision += 1
        XCTAssertEqual(YouModel.skillPractice(pack: pack, events: [.openTaskAttempt(stale)],
            dueItems: []).first { $0.skill == .speaking }?.practisedTimes, 0)
    }

    func testOpenResponseSummarySeparatesModelAndHelpFromUnassistedWork() {
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        func attempt(_ id: String, model: Bool, assistance: [AssistanceKind]) -> OpenTaskAttemptEvent {
            OpenTaskAttemptEvent(id: id, packId: "es-foundations", packVersion: "1",
                lessonId: "lesson", lessonRevision: 1, stepId: "step", activityId: "activity",
                activityRevision: 1, mode: .spoken, assistance: assistance,
                selfRating: nil, modelRevealed: model, at: at)
        }
        var progress = PackProgress()
        progress.openTaskAttempts = [attempt("a", model: false, assistance: []),
            attempt("b", model: true, assistance: []), attempt("c", model: false, assistance: [.hint])]
        let summary = YouModel.openResponseSummary(progress: progress)
        XCTAssertEqual(summary.withoutModelOrHelp, 1)
        XCTAssertEqual(summary.withModelOrHelp, 2)
    }
    func testNeverPractisedAvailableSkillOpensItsLesson() throws {
        let pack = try XCTUnwrap(PackLoader.loadPacks().first { $0.language == .french })
        let practice: [YouModel.SkillPractice] = [
            .init(skill: .reading, practisedTimes: 3, lastPractisedAt: Date(), dueCount: 0),
            .init(skill: .listening, practisedTimes: 0, lastPractisedAt: nil, dueCount: 0)
        ]
        let next = try XCTUnwrap(YouModel.recommendedPractice(
            pack: pack, practice: practice, completedLessons: []))
        XCTAssertEqual(next.skill, .listening)
        let lesson = try XCTUnwrap(next.lessonId.flatMap { pack.lesson(id: $0) })
        XCTAssertTrue(lesson.steps.contains { step in
            pack.activity(id: step.activityId).map { activitySkills($0).contains(.listening) } ?? false
        })
        XCTAssertEqual(next.packId, pack.id)
    }

    func testDueReviewWinsAndCompletedCourseStillOffersPractice() throws {
        let pack = try XCTUnwrap(PackLoader.loadPacks().first { $0.language == .french })
        var practice: [YouModel.SkillPractice] = [
            .init(skill: .reading, practisedTimes: 1, lastPractisedAt: Date(), dueCount: 2)
        ]
        let review = try XCTUnwrap(YouModel.recommendedPractice(
            pack: pack, practice: practice, completedLessons: []))
        XCTAssertNil(review.lessonId)
        practice[0].dueCount = 0
        let repeatLesson = try XCTUnwrap(YouModel.recommendedPractice(
            pack: pack, practice: practice, completedLessons: Set(pack.lessons.map(\.id))))
        XCTAssertNotNil(repeatLesson.lessonId.flatMap { pack.lesson(id: $0) })
    }

    func testUnavailableSkillProducesNoBrokenDestination() throws {
        let pack = try XCTUnwrap(PackLoader.loadPacks().first { $0.language == .french })
        let practice: [YouModel.SkillPractice] = [
            .init(skill: .grammar, practisedTimes: 0, lastPractisedAt: nil, dueCount: 0)
        ]
        let next = try XCTUnwrap(YouModel.recommendedPractice(
            pack: pack, practice: practice, completedLessons: []))
        XCTAssertNotNil(next.lessonId.flatMap { pack.lesson(id: $0) })
        XCTAssertNil(YouModel.recommendedPractice(pack: pack, practice: [], completedLessons: []))
        let source = try XCTUnwrap(PackLoader.contentDirectory())
            .appendingPathComponent("packs/french.json")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: source)) as? [String: Any])
        var activities = try XCTUnwrap(json["activities"] as? [[String: Any]])
        for index in activities.indices { activities[index]["skills"] = [] }
        json["activities"] = activities
        let noSkillPack = try JSONDecoder().decode(CoursePack.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(YouModel.recommendedPractice(pack: noSkillPack, practice: practice, completedLessons: []))
    }
}
