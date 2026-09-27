import Combine
import Foundation
import os

// MARK: - Projection output

enum EvidenceMode: String, Codable {
    case production, recognition, listening
}

// MARK: - Evidence categories (5.2A)
//
/// What the recorded attempts prove about how the learner worked with an
/// evidence key. The five plan categories, derived from stored fields
/// only — response kind (typed vs picked vs self-rated), the `independent`
/// flag, and review timing. Conservative by design: a category is never
/// assigned when the events cannot prove it, so replaying old databases
/// yields old progress plus the weakest honest category, never invented
/// mastery. No new payload field was needed; see `LearningStore.project`
/// for the derivation table.
enum EvidenceCategory: Hashable, CaseIterable {
    /// Encountered the material, but no clean success on record.
    case seen
    /// Recognised it: a clean (independent) success on a picking/arranging
    /// activity — selection, ordering, matching, dialogue-choice,
    /// scene-selection.
    case recognized
    /// Produced target-language output correctly, but only with help
    /// (typing or cloze with assistance).
    case producedWithHelp
    /// Produced target-language output correctly with no help (typing or
    /// cloze, independent).
    case producedIndependently
    /// Recalled it later: a clean review success at least one full day
    /// (86,400 s) after the key's first independent production.
    case recalledLater
}

struct EvidenceRecord {
    var fsrs: FsrsState
    var successes: Int
    var failures: Int
    var mode: EvidenceMode
}

struct SkillCount {
    var independent: Int = 0
    var assisted: Int = 0
}

/// Everything the UI needs, derived from the event log.
/// Mirrors `projectLessonEvidence` in the web app.
struct PackProgress {
    /// Lesson ids whose required steps completed along the chosen path.
    var participationCompleted: Set<String> = []
    /// Lessons unlocked by legacy success credit (never relocked by v2).
    var legacyCredits: Set<String> = []
    /// Lessons carrying a live manual "I know this" mark.
    var knownLessons: Set<String> = []
    /// SRS state per independent evidence key.
    var evidence: [String: EvidenceRecord] = [:]
    /// Evidence categories per key: what the recorded attempts actually
    /// prove (seen / recognised / produced with help / produced
    /// independently / recalled later). Derived at read time from
    /// response kind + independence + review timing; conservative for
    /// old databases. See `EvidenceCategory`.
    var evidenceCategories: [String: Set<EvidenceCategory>] = [:]
    /// Correct attempts per skill, split by independence.
    var skillCounts: [Skill: SkillCount] = [:]
    /// Checkpoint task attempts (5.3A), oldest first: the learner's open
    /// practice evidence for stage-end tasks. Practice evidence only — it
    /// never grants completion, never locks, and never feeds SRS; a retake
    /// merely adds a row. Rows whose checkpoint id is no longer in the
    /// bundled pack land in `quarantined` instead (learner-owned history,
    /// kept observable, never used for credit).
    var checkpointAttempts: [CheckpointAttemptEvent] = []
    /// Open-task attempts (6.2): the learner's connected-production
    /// practice evidence from open tasks bound into lesson steps. Practice
    /// evidence only — it never feeds SRS, never creates evidence
    /// categories, and never duplicates completion; a retake adds a row.
    /// Rows whose activity is no longer an open task in the bundled pack
    /// land in `quarantined` instead (learner-owned history, kept
    /// observable, never used for credit).
    var openTaskAttempts: [OpenTaskAttemptEvent] = []
    /// Branching-exchange turns (6.3): one `DialogueTurnEvent` per answered
    /// turn of a practised hosted dialogue, in authored turn order (`turnIndex`).
    /// Practice evidence only — it never feeds SRS, never creates evidence
    /// categories, and never duplicates anything; a retake answers fresh
    /// turns with fresh ids. Rows whose dialogue/node/host binding no longer
    /// resolves in the bundled pack land in `quarantined` instead.
    var dialogueTurns: [DialogueTurnEvent] = []
    /// Event ids held out of projection: stored rows whose payload could
    /// not be decoded (kept observable, never failing the read), plus
    /// revision drift and retired targets.
    var quarantined: [String] = []
}

extension PackProgress {
    /// Every lesson that counts as finished on the learner's path: walked-through
    /// lessons, legacy credits, and manual "I know this" marks.
    var finishedLessons: Set<String> {
        participationCompleted.union(legacyCredits).union(knownLessons)
    }
}

extension CoursePack {
    /// The first lesson the learner hasn't completed yet, walked in
    /// unit/lesson order — the single source of truth for "what comes
    /// next on the path". Shared by the Home tab's continue card,
    /// `condisco://continue`, and the widget snapshot, so every surface
    /// points at the same next lesson.
    ///
    /// Lessons whose `unitId` has no matching `CourseUnit` in `units` are
    /// skipped: the authored pack can carry orphaned lesson ids, and they
    /// are not part of the learner's path.
    ///
    /// - Parameter completed: lesson ids already finished along the chosen
    ///   path — pass `PackProgress.finishedLessons`. Each caller
    ///   projects its own set so it controls freshness (cached projection
    ///   on Home, fresh projection for a deep link).
    /// - Returns: the next lesson together with its unit, or nil when every
    ///   lesson is complete.
    func firstUncompletedLesson(
        completed: Set<String>
    ) -> (lesson: Lesson, unit: CourseUnit)? {
        var unitIds: [String] = []
        for lesson in lessons where !unitIds.contains(lesson.unitId) {
            unitIds.append(lesson.unitId)
        }
        for unitId in unitIds {
            guard let unit = units.first(where: { $0.id == unitId }) else { continue }
            for lesson in lessons where lesson.unitId == unitId {
                if !completed.contains(lesson.id) { return (lesson, unit) }
            }
        }
        return nil
    }

    /// The next unfinished lesson after a recap, using the authored path.
    func nextUncompletedLesson(
        after lessonId: String,
        completed: Set<String>
    ) -> Lesson? {
        guard let index = lessons.firstIndex(where: { $0.id == lessonId }) else {
            return nil
        }
        let unitIds = Set(units.map(\.id))
        return lessons.dropFirst(index + 1).first {
            unitIds.contains($0.unitId) && !completed.contains($0.id)
        }
    }
}

// MARK: - Activity helpers (projection-only views over CoursePack models)

private func activityRevision(_ activity: Activity) -> Int {
    switch activity {
    case .legacy(let a): return a.base.revision
    case .information(let a): return a.revision
    case .text(let a): return a.base.revision
    case .selection(let a): return a.base.revision
    case .ordering(let a): return a.base.revision
    case .matching(let a): return a.base.revision
    case .cloze(let a): return a.base.revision
    case .dialogueChoice(let a): return a.base.revision
    case .sceneSelection(let a): return a.base.revision
    case .selfCompare(let a): return a.revision
    case .openTask(let a): return a.revision
    }
}

/// The skills an activity exercises, from its authored `skills` token
/// list. Shared by the SRS evidence projection and the You-screen
/// per-skill practice profile, so both derive counts from one mapping.
func activitySkills(_ activity: Activity) -> [Skill] {
    switch activity {
    case .legacy(let a): return a.base.skills
    case .information: return []
    case .text(let a): return a.base.skills
    case .selection(let a): return a.base.skills
    case .ordering(let a): return a.base.skills
    case .matching(let a): return a.base.skills
    case .cloze(let a): return a.base.skills
    case .dialogueChoice(let a): return a.base.skills
    case .sceneSelection(let a): return a.base.skills
    case .selfCompare: return []
    case .openTask: return []
    }
}

private func isUngradedKind(_ activity: Activity) -> Bool {
    switch activity {
    case .information, .selfCompare, .openTask: return true
    default: return false
    }
}

private func skillMode(_ skills: [Skill]) -> EvidenceMode {
    if skills.contains(.listening) { return .listening }
    if skills.contains(.writing) { return .production }
    return .recognition
}

// MARK: - Attempt proof kind (5.2A)

/// How an attempt proves practice, for the evidence-category derivation.
/// Reviews — the Review tab and the lesson warm-up — always carry a
/// `.selfRating` response; lesson attempts never do, so the response kind
/// reliably separates "self-rated recall" from typed/picked work even
/// though review attempts reference the original activity.
private enum AttemptProofKind {
    /// Typed target-language output: text, cloze, and the retained legacy
    /// text exercises.
    case production
    /// Picking or arranging: selection, ordering, matching,
    /// dialogue-choice, scene-selection.
    case recognition
    /// Self-rated recall (Review tab / lesson warm-up).
    case review
    /// Information and self-compare moments prove nothing graded.
    case none
}

private func proofKind(for activity: Activity, response: AttemptResponse) -> AttemptProofKind {
    if case .selfRating = response { return .review }
    switch activity {
    case .information, .selfCompare, .openTask: return .none
    case .text, .cloze, .legacy: return .production
    case .selection, .ordering, .matching,
         .dialogueChoice, .sceneSelection: return .recognition
    }
}

// MARK: - Store

/// A checkpoint row with its write timestamp, for cross-device merge
/// (last-write-wins) and data export.
struct StoredCheckpoint: Codable, Equatable, Sendable {
    var packId: String
    var lessonId: String
    /// JSON-encoded LessonCheckpoint.
    var payload: String
    var updatedAtMs: Int64
}

/// A deleted checkpoint's marker, for cross-device merge. A tombstone at
/// least as new as a checkpoint row deletes it; a newer checkpoint row
/// retires the tombstone. Without this, a cleared checkpoint would
/// resurrect the next time another device's row synced down.
struct CheckpointTombstone: Codable, Equatable, Sendable {
    var packId: String
    var lessonId: String
    var deletedAtMs: Int64
}

/// A deleted phrasebook entry's marker, for cross-device merge. A tombstone
/// at least as new as a saved-phrase row deletes it; a newer save retires
/// the tombstone. Without this, an unsaved phrase would resurrect the next
/// time another device's row synced down.
struct SavedPhraseTombstone: Codable, Equatable, Sendable {
    var id: String
    var deletedAtMs: Int64
}

/// A phrase the learner saved to their phrasebook. The id is deterministic
/// (language + target + meaning) so re-saving is a no-op and sync merges
/// by key.
struct SavedPhrase: Hashable, Identifiable, Sendable {
    var id: String
    var languageSlug: String
    var languageName: String
    var target: String
    var meaning: String
    var source: String
    /// Deep-link target for "open the lesson this phrase came from".
    /// Empty for phrases saved before deep links existed.
    var sourcePackId: String = ""
    var sourceLessonId: String = ""
    var savedAt: Date
}

/// A saved-phrase row with its write timestamp, for cross-device merge
/// (last-write-wins) and data export. The timestamp rides as raw
/// milliseconds so an export never rounds or reformats it.
struct StoredSavedPhrase: Codable, Equatable, Sendable {
    var id: String
    var languageSlug: String
    var languageName: String
    var target: String
    var meaning: String
    var source: String
    var sourcePackId: String
    var sourceLessonId: String
    var savedAtMs: Int64
}

/// A listen-state row with its write timestamp, for merge and export.
struct ListenStateRow: Codable, Equatable, Sendable {
    var trackId: String
    var positionSeconds: Double
    var listenedAtMs: Int64?
    var updatedAtMs: Int64
}

/// Append-only learning event log plus projections, backed by SQLite.
///
/// Events are the source of truth; everything else (SRS state, completion,
/// skill counts) is projected from them, exactly like the web app. V1 rows
/// are never modified: a conflicting id with different content aborts the
/// write instead of merging.
@MainActor
final class LearningStore: ObservableObject {
    enum StoreError: Error, CustomStringConvertible {
        case conflict(String)
        case danglingCompletion(String)
        case corruptPayload(String)

        var description: String {
            switch self {
            case .conflict(let id):
                return "Conflicting practice mutation ID \(id). Import was not applied."
            case .danglingCompletion(let id):
                return "Step completion \(id) has no matching attempt. Import was not applied."
            case .corruptPayload(let id):
                return "Stored event \(id) failed to decode."
            }
        }
    }

    private let db: Database
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()
    /// Canonical payload encoder for the duplicate check. `.sortedKeys`
    /// makes equal content compare equal regardless of JSON key order, so a
    /// semantically identical re-record (or CloudKit replay) is a no-op
    /// instead of a spurious `.conflict`.
    private let canonicalJsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    init(path: String) throws {
        db = try Database(path: path)
        try db.exec(
            """
            CREATE TABLE IF NOT EXISTS events(
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
            CREATE TABLE IF NOT EXISTS checkpoints(
              pack_id TEXT NOT NULL,
              lesson_id TEXT NOT NULL,
              payload TEXT NOT NULL,
              updated_at_ms INTEGER NOT NULL,
              PRIMARY KEY (pack_id, lesson_id)
            );
            CREATE TABLE IF NOT EXISTS checkpoint_tombstones(
              pack_id TEXT NOT NULL,
              lesson_id TEXT NOT NULL,
              deleted_at_ms INTEGER NOT NULL,
              PRIMARY KEY (pack_id, lesson_id)
            );
            CREATE TABLE IF NOT EXISTS listen_state(
              track_id TEXT PRIMARY KEY,
              position_seconds REAL NOT NULL DEFAULT 0,
              listened_at_ms INTEGER,
              updated_at_ms INTEGER NOT NULL
            );
            CREATE TABLE IF NOT EXISTS kv(
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS sync_uploads(
              event_id TEXT PRIMARY KEY,
              uploaded_at_ms INTEGER NOT NULL
            );
            CREATE TABLE IF NOT EXISTS saved_phrases(
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
            CREATE TABLE IF NOT EXISTS saved_phrase_tombstones(
              id TEXT PRIMARY KEY,
              deleted_at_ms INTEGER NOT NULL
            );
            """)

        // Migration: saved_phrases gained source_pack_id / source_lesson_id
        // (deep-link targets for the phrasebook). Older databases get the
        // columns with empty defaults; new phrases carry real ids.
        var savedPhraseColumns: [String] = []
        try db.query("PRAGMA table_info(saved_phrases);") { row in
            savedPhraseColumns.append(row.text(1) ?? "")
        }
        for column in ["source_pack_id", "source_lesson_id"] {
            if !savedPhraseColumns.contains(column) {
                try db.execute(
                    "ALTER TABLE saved_phrases ADD COLUMN \(column) TEXT NOT NULL DEFAULT '';")
            }
        }

        // Observability (non-fatal): surface any undecodable stored event
        // rows at open, so local corruption is visible even before the first
        // sync runs. The resilient reads skip these rows and keep the app —
        // lessons, review, export — fully usable.
        if let corruptIds = try? corruptEventIds(), !corruptIds.isEmpty {
            Self.logCorruptRows(corruptIds)
        }
    }

    static func inDocuments() throws -> LearningStore {
        let url = try FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true)
        let path = url.appendingPathComponent("verbalibera.sqlite").path
        return try LearningStore(path: path)
    }

    // MARK: - Events

    private static func millis(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1_000).rounded())
    }

    private static func date(_ millis: Int64) -> Date {
        Date(timeIntervalSince1970: Double(millis) / 1_000)
    }

    /// Order-stable JSON for an event, used by `record()`'s duplicate
    /// check. JSONEncoder does not guarantee key order across encodes, so
    /// two encodings of the same semantic event can differ byte-for-byte;
    /// sorting keys makes the comparison insensitive to key order.
    private func canonicalPayloadJSON(for event: LearningEvent) throws -> String {
        let data = try canonicalJsonEncoder.encode(event)
        guard let string = String(data: data, encoding: .utf8) else {
            throw StoreError.corruptPayload(event.id)
        }
        return string
    }

    /// Canonical form of a stored payload. Decodes and re-encodes with
    /// sorted keys so it compares cleanly against a freshly encoded event;
    /// falls back to the raw string when the stored payload cannot be
    /// decoded, keeping the comparison safe for corrupt rows.
    ///
    /// Accepted behavior: payloads that differ only in fields the schema
    /// does not know about compare equal ("lenient dedup"). Unknown fields
    /// are dropped by the decode and never enter the canonical form, so a
    /// semantically identical duplicate is a no-op even when the raw bytes
    /// carry extra keys — nothing is lost from storage either way.
    private func canonicalPayloadJSON(stored: String) -> String {
        guard let data = stored.data(using: .utf8),
              let event = try? jsonDecoder.decode(LearningEvent.self, from: data),
              let reencoded = try? canonicalJsonEncoder.encode(event),
              let string = String(data: reencoded, encoding: .utf8)
        else { return stored }
        return string
    }

    /// Appends an event. A duplicate id with identical content is a no-op;
    /// a duplicate id with different content throws. Content is compared in
    /// canonical (key-sorted) JSON form, so JSON key order never decides
    /// the outcome.
    func record(_ event: LearningEvent) throws {
        try db.transaction {
            try self.insertEvent(event)
        }
    }

    /// Idempotent event insert WITHOUT its own transaction, so a batch
    /// (data import) can record many events inside one surrounding
    /// transaction. Same rules as `record`: identical content is a no-op,
    /// different content throws `StoreError.conflict`.
    private func insertEvent(_ event: LearningEvent) throws {
        let payloadData = try jsonEncoder.encode(event)
        guard let payload = String(data: payloadData, encoding: .utf8) else {
            throw StoreError.corruptPayload(event.id)
        }
        // Canonical form of the incoming content for the duplicate check.
        let canonicalPayload = try canonicalPayloadJSON(for: event)
        let atMs = LearningStore.millis(event.at)
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

        var existing: String?
        try self.db.query(
            "SELECT payload FROM events WHERE id = ?;",
            bind: { try $0.bindText(1, event.id) },
            row: { existing = $0.text(0) })
        if let old = existing {
            // Compare content, not raw bytes: identical semantics in
            // any JSON key order is a no-op; different content conflicts.
            if canonicalPayloadJSON(stored: old) != canonicalPayload {
                throw StoreError.conflict(event.id)
            }
            return
        }
        try self.db.execute(
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

    /// Decodes stored event rows, returning the decodable events in query
    /// order together with the ids of rows whose payload cannot be decoded,
    /// in the order they were encountered. An undecodable row is skipped,
    /// never failing the read, so a single corrupt row cannot wedge
    /// projection or sync; the skipped ids surface the corruption instead
    /// of hiding it.
    ///
    /// - Precondition: the SQL must select the row id as column 0 and the
    ///   payload as column 1.
    private func decodeEventRows(
        sql: String,
        bind: ((Statement) throws -> Void)? = nil
    ) throws -> (events: [LearningEvent], skipped: [String]) {
        var events: [LearningEvent] = []
        var skipped: [String] = []
        try db.query(sql, bind: bind, row: { statement in
            let id = statement.text(0) ?? "?"
            guard let payload = statement.text(1),
                  let data = payload.data(using: .utf8),
                  let event = try? self.jsonDecoder.decode(
                      LearningEvent.self, from: data)
            else {
                if !skipped.contains(id) { skipped.append(id) }
                return
            }
            events.append(event)
        })
        return (events, skipped)
    }

    /// All events for a pack, merged and sorted by (at, id).
    ///
    /// Fail-loud raw-log read: a corrupt stored payload throws
    /// `StoreError.corruptPayload` naming the first offending id rather
    /// than silently dropping history. Projection and lesson boot use the
    /// tolerant paths instead — `project(pack:)` reports such ids in
    /// `PackProgress.quarantined`, `learningEventsWithQuarantine(packId:)`
    /// returns them alongside the decodable events, and `unsyncedEvents()`
    /// skips them (ids via `corruptEventIds()`).
    func learningEvents(packId: String) throws -> [LearningEvent] {
        let (events, skipped) = try decodeEventRows(
            sql: "SELECT id, payload FROM events WHERE pack_id = ? ORDER BY at_ms, id;",
            bind: { try $0.bindText(1, packId) })
        if let firstBad = skipped.first {
            throw StoreError.corruptPayload(firstBad)
        }
        return events
    }

    /// All events for a pack, merged and sorted by (at, id), together with
    /// the ids of stored rows whose payload could not be decoded.
    ///
    /// Tolerant pack-scoped read for lesson boot: an undecodable row is
    /// skipped and reported in the returned `skipped` list instead of
    /// failing the read, so one corrupt row can never block opening or
    /// resuming a lesson in that pack. Callers that need the fail-loud
    /// raw-log read use `learningEvents(packId:)`.
    func learningEventsWithQuarantine(packId: String) throws
        -> (events: [LearningEvent], skipped: [String]) {
        try decodeEventRows(
            sql: "SELECT id, payload FROM events WHERE pack_id = ? ORDER BY at_ms, id;",
            bind: { try $0.bindText(1, packId) })
    }

    // MARK: - Sync bookkeeping

    /// Events the server has not acknowledged yet, oldest first.
    /// Downloaded events are marked on ingest, so each event uploads once.
    ///
    /// Resilient read: rows whose stored payload cannot be decoded are
    /// skipped so a single corrupt row cannot wedge the upload; their ids
    /// stay observable via `corruptEventIds()`.
    func unsyncedEvents() throws -> [LearningEvent] {
        try decodeEventRows(sql: """
            SELECT id, payload FROM events
            WHERE id NOT IN (SELECT event_id FROM sync_uploads)
            ORDER BY at_ms, id;
            """).events
    }

    /// Records downloaded events and marks everything the server now holds.
    /// Downloads feed through the idempotent insert, so events already on
    /// this device are no-ops; a conflicting id (same id, other payload) is
    /// skipped rather than failing the whole sync.
    ///
    /// - Returns: the ids of downloaded events that `record()` rejected as
    ///   `.conflict`. Behavior otherwise is unchanged — the ids are still
    ///   marked uploaded (pre-existing behavior; the server holds them) —
    ///   but the returned set makes skipped conflicts observable instead of
    ///   silently lost.
    @discardableResult
    func ingestSynced(
        downloaded: [LearningEvent], uploadedIds: [String]
    ) throws -> Set<String> {
        var skippedConflicts: Set<String> = []
        for event in downloaded {
            do {
                try record(event)
            } catch {
                // Keep catch-and-continue for every error so one bad row
                // never fails the whole sync; surface genuine conflicts so
                // callers can count what was skipped.
                if case StoreError.conflict = error {
                    skippedConflicts.insert(event.id)
                }
                continue
            }
        }
        let ids = Set(uploadedIds + downloaded.map(\.id))
        guard !ids.isEmpty else { return skippedConflicts }
        let nowMs = Self.millis(Date())
        try db.transaction {
            for id in ids {
                try self.db.execute(
                    """
                    INSERT OR IGNORE INTO sync_uploads(event_id, uploaded_at_ms)
                    VALUES (?, ?);
                    """,
                    bind: {
                        try $0.bindText(1, id)
                        try $0.bindInt64(2, nowMs)
                    })
            }
        }
        return skippedConflicts
    }

    /// Distinct UTC days with at least one recorded event.
    func practiceDays() throws -> Int {
        var days = 0
        try db.query(
            "SELECT COUNT(DISTINCT date(at_ms / 1000, 'unixepoch')) FROM events;",
            row: { days = Int($0.int64(0)) })
        return days
    }

    /// For each date in `days` (oldest first), whether any learning event
    /// was recorded on that calendar day in the device's local timezone.
    /// Backs the Home tab's calendar-week activity strip.
    func practiceDayFlags(for days: [Date]) throws -> [Bool] {
        var active = Set<String>()
        try db.query(
            "SELECT DISTINCT date(at_ms / 1000, 'unixepoch', 'localtime') FROM events;",
            row: { if let day = $0.text(0) { active.insert(day) } })
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return days.map { date in
            let comps = calendar.dateComponents([.year, .month, .day], from: date)
            let key = String(format: "%04d-%02d-%02d",
                             comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
            return active.contains(key)
        }
    }

    // MARK: - Checkpoints

    func saveCheckpoint(_ checkpoint: LessonCheckpoint) throws {
        let data = try jsonEncoder.encode(checkpoint)
        guard let payload = String(data: data, encoding: .utf8) else {
            throw StoreError.corruptPayload(checkpoint.lessonId)
        }
        let atMs = LearningStore.millis(checkpoint.at)
        try db.transaction {
            try self.db.execute(
                """
                INSERT INTO checkpoints(pack_id, lesson_id, payload, updated_at_ms)
                VALUES (?, ?, ?, ?)
                ON CONFLICT(pack_id, lesson_id)
                DO UPDATE SET payload = excluded.payload, updated_at_ms = excluded.updated_at_ms;
                """,
                bind: {
                    try $0.bindText(1, checkpoint.packId)
                    try $0.bindText(2, checkpoint.lessonId)
                    try $0.bindText(3, payload)
                    try $0.bindInt64(4, atMs)
                })
            // A fresh write supersedes an older delete.
            try self.db.execute(
                """
                DELETE FROM checkpoint_tombstones
                WHERE pack_id = ? AND lesson_id = ? AND deleted_at_ms <= ?;
                """,
                bind: {
                    try $0.bindText(1, checkpoint.packId)
                    try $0.bindText(2, checkpoint.lessonId)
                    try $0.bindInt64(3, atMs)
                })
        }
    }

    func loadCheckpoint(packId: String, lessonId: String) throws -> LessonCheckpoint? {
        var result: LessonCheckpoint?
        try db.query(
            "SELECT payload FROM checkpoints WHERE pack_id = ? AND lesson_id = ?;",
            bind: {
                try $0.bindText(1, packId)
                try $0.bindText(2, lessonId)
            },
            row: { statement in
                guard let payload = statement.text(0),
                      let data = payload.data(using: .utf8) else { return }
                result = try self.jsonDecoder.decode(LessonCheckpoint.self, from: data)
            })
        return result
    }

    /// Deletes the checkpoint and records a tombstone, so the delete
    /// spreads to the learner's other devices on sync instead of the row
    /// resurrecting from another device's copy.
    func clearCheckpoint(packId: String, lessonId: String) throws {
        let nowMs = LearningStore.millis(Date())
        try db.transaction {
            try self.db.execute(
                "DELETE FROM checkpoints WHERE pack_id = ? AND lesson_id = ?;",
                bind: {
                    try $0.bindText(1, packId)
                    try $0.bindText(2, lessonId)
                })
            try self.db.execute(
                """
                INSERT INTO checkpoint_tombstones(pack_id, lesson_id, deleted_at_ms)
                VALUES (?, ?, ?)
                ON CONFLICT(pack_id, lesson_id)
                DO UPDATE SET deleted_at_ms = excluded.deleted_at_ms
                WHERE excluded.deleted_at_ms > checkpoint_tombstones.deleted_at_ms;
                """,
                bind: {
                    try $0.bindText(1, packId)
                    try $0.bindText(2, lessonId)
                    try $0.bindInt64(3, nowMs)
                })
        }
    }

    // MARK: - Sync rows
    //
    // Checkpoints and listen state merge across devices last-write-wins by
    // updated_at_ms; the immutable event log merges by union instead.

    /// Every checkpoint with its write timestamp, for CloudKit merge + export.
    func allCheckpoints() throws -> [StoredCheckpoint] {
        var rows: [StoredCheckpoint] = []
        try db.query(
            "SELECT pack_id, lesson_id, payload, updated_at_ms FROM checkpoints;",
            row: { statement in
                rows.append(StoredCheckpoint(
                    packId: statement.text(0) ?? "",
                    lessonId: statement.text(1) ?? "",
                    payload: statement.text(2) ?? "",
                    updatedAtMs: statement.int64(3)))
            })
        return rows
    }

    /// Merges a checkpoint received from another device. The newer write
    /// wins; an older remote row never clobbers local progress. A tombstone
    /// at least as new as the row keeps the checkpoint deleted; a newer
    /// row retires its tombstone.
    func mergeCheckpoint(_ row: StoredCheckpoint) throws {
        try db.transaction {
            try self.mergeCheckpointRow(row)
        }
    }

    /// Transaction-free checkpoint merge, for batching inside one
    /// transaction (data import). Same rules as `mergeCheckpoint`.
    private func mergeCheckpointRow(_ row: StoredCheckpoint) throws {
        try self.db.execute(
            """
            DELETE FROM checkpoint_tombstones
            WHERE pack_id = ? AND lesson_id = ? AND deleted_at_ms < ?;
            """,
            bind: {
                try $0.bindText(1, row.packId)
                try $0.bindText(2, row.lessonId)
                try $0.bindInt64(3, row.updatedAtMs)
            })
        var tombstoneMs: Int64?
        try self.db.query(
            """
            SELECT deleted_at_ms FROM checkpoint_tombstones
            WHERE pack_id = ? AND lesson_id = ?;
            """,
            bind: {
                try $0.bindText(1, row.packId)
                try $0.bindText(2, row.lessonId)
            },
            row: { tombstoneMs = $0.int64(0) })
        if let tombstoneMs, tombstoneMs >= row.updatedAtMs {
            return
        }
        try self.db.execute(
            """
            INSERT INTO checkpoints(pack_id, lesson_id, payload, updated_at_ms)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(pack_id, lesson_id)
            DO UPDATE SET payload = excluded.payload,
                          updated_at_ms = excluded.updated_at_ms
            WHERE excluded.updated_at_ms > checkpoints.updated_at_ms;
            """,
            bind: {
                try $0.bindText(1, row.packId)
                try $0.bindText(2, row.lessonId)
                try $0.bindText(3, row.payload)
                try $0.bindInt64(4, row.updatedAtMs)
            })
    }

    /// Every checkpoint tombstone, for CloudKit upload.
    func allCheckpointTombstones() throws -> [CheckpointTombstone] {
        var rows: [CheckpointTombstone] = []
        try db.query(
            "SELECT pack_id, lesson_id, deleted_at_ms FROM checkpoint_tombstones;",
            row: { statement in
                rows.append(CheckpointTombstone(
                    packId: statement.text(0) ?? "",
                    lessonId: statement.text(1) ?? "",
                    deletedAtMs: statement.int64(2)))
            })
        return rows
    }

    /// Merges a tombstone received from another device. A tombstone at
    /// least as new as the local checkpoint row deletes it; a newer local
    /// row drops the tombstone instead.
    func mergeCheckpointTombstone(_ tombstone: CheckpointTombstone) throws {
        try db.transaction {
            try self.mergeCheckpointTombstoneRow(tombstone)
        }
    }

    /// Transaction-free checkpoint-tombstone merge, for batching inside
    /// one transaction (data import).
    private func mergeCheckpointTombstoneRow(_ tombstone: CheckpointTombstone) throws {
        var localMs: Int64?
        try self.db.query(
            """
            SELECT updated_at_ms FROM checkpoints
            WHERE pack_id = ? AND lesson_id = ?;
            """,
            bind: {
                try $0.bindText(1, tombstone.packId)
                try $0.bindText(2, tombstone.lessonId)
            },
            row: { localMs = $0.int64(0) })
        if let localMs, localMs > tombstone.deletedAtMs {
            try self.db.execute(
                "DELETE FROM checkpoint_tombstones WHERE pack_id = ? AND lesson_id = ?;",
                bind: {
                    try $0.bindText(1, tombstone.packId)
                    try $0.bindText(2, tombstone.lessonId)
                })
            return
        }
        try self.db.execute(
            "DELETE FROM checkpoints WHERE pack_id = ? AND lesson_id = ?;",
            bind: {
                try $0.bindText(1, tombstone.packId)
                try $0.bindText(2, tombstone.lessonId)
            })
        try self.db.execute(
            """
            INSERT INTO checkpoint_tombstones(pack_id, lesson_id, deleted_at_ms)
            VALUES (?, ?, ?)
            ON CONFLICT(pack_id, lesson_id)
            DO UPDATE SET deleted_at_ms = excluded.deleted_at_ms
            WHERE excluded.deleted_at_ms > checkpoint_tombstones.deleted_at_ms;
            """,
            bind: {
                try $0.bindText(1, tombstone.packId)
                try $0.bindText(2, tombstone.lessonId)
                try $0.bindInt64(3, tombstone.deletedAtMs)
            })
    }

    /// Every saved-phrase tombstone, for CloudKit upload.
    func allSavedPhraseTombstones() throws -> [SavedPhraseTombstone] {
        var rows: [SavedPhraseTombstone] = []
        try db.query(
            "SELECT id, deleted_at_ms FROM saved_phrase_tombstones;",
            row: { statement in
                rows.append(SavedPhraseTombstone(
                    id: statement.text(0) ?? "",
                    deletedAtMs: statement.int64(1)))
            })
        return rows
    }

    /// Merges a tombstone received from another device. A tombstone at
    /// least as new as the local saved-phrase row deletes it; a newer local
    /// save drops the tombstone instead.
    func mergeSavedPhraseTombstone(_ tombstone: SavedPhraseTombstone) throws {
        try db.transaction {
            try self.mergeSavedPhraseTombstoneRow(tombstone)
        }
    }

    /// Transaction-free saved-phrase-tombstone merge, for batching inside
    /// one transaction (data import). A tombstone wins over an older row;
    /// a newer row retires the tombstone.
    private func mergeSavedPhraseTombstoneRow(_ tombstone: SavedPhraseTombstone) throws {
        var localMs: Int64?
        try self.db.query(
            "SELECT saved_at_ms FROM saved_phrases WHERE id = ?;",
            bind: { try $0.bindText(1, tombstone.id) },
            row: { localMs = $0.int64(0) })
        if let localMs, localMs > tombstone.deletedAtMs {
            try self.db.execute(
                "DELETE FROM saved_phrase_tombstones WHERE id = ?;",
                bind: { try $0.bindText(1, tombstone.id) })
            return
        }
        try self.db.execute(
            "DELETE FROM saved_phrases WHERE id = ?;",
            bind: { try $0.bindText(1, tombstone.id) })
        try self.db.execute(
            """
            INSERT INTO saved_phrase_tombstones(id, deleted_at_ms)
            VALUES (?, ?)
            ON CONFLICT(id)
            DO UPDATE SET deleted_at_ms = excluded.deleted_at_ms
            WHERE excluded.deleted_at_ms > saved_phrase_tombstones.deleted_at_ms;
            """,
            bind: {
                try $0.bindText(1, tombstone.id)
                try $0.bindInt64(2, tombstone.deletedAtMs)
            })
    }

    /// Merges a phrase received from another device, last-write-wins by
    /// saved_at_ms. A tombstone at least as new as the row keeps the phrase
    /// unsaved; a newer row retires its tombstone.
    func mergeSavedPhrase(_ phrase: SavedPhrase) throws {
        let atMs = LearningStore.millis(phrase.savedAt)
        try db.transaction {
            try self.mergeSavedPhraseRow(StoredSavedPhrase(
                id: phrase.id,
                languageSlug: phrase.languageSlug,
                languageName: phrase.languageName,
                target: phrase.target,
                meaning: phrase.meaning,
                source: phrase.source,
                sourcePackId: phrase.sourcePackId,
                sourceLessonId: phrase.sourceLessonId,
                savedAtMs: atMs))
        }
    }

    /// Transaction-free saved-phrase merge by raw row, for batching inside
    /// one transaction (data import). Same rules as `mergeSavedPhrase`.
    private func mergeSavedPhraseRow(_ row: StoredSavedPhrase) throws {
        try self.db.execute(
            "DELETE FROM saved_phrase_tombstones WHERE id = ? AND deleted_at_ms < ?;",
            bind: {
                try $0.bindText(1, row.id)
                try $0.bindInt64(2, row.savedAtMs)
            })
        var tombstoneMs: Int64?
        try self.db.query(
            "SELECT deleted_at_ms FROM saved_phrase_tombstones WHERE id = ?;",
            bind: { try $0.bindText(1, row.id) },
            row: { tombstoneMs = $0.int64(0) })
        if let tombstoneMs, tombstoneMs >= row.savedAtMs {
            return
        }
        try self.db.execute(
            """
            INSERT INTO saved_phrases(id, language_slug, language_name, target, meaning, source, source_pack_id, source_lesson_id, saved_at_ms)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id)
            DO UPDATE SET language_slug = excluded.language_slug,
                          language_name = excluded.language_name,
                          target = excluded.target,
                          meaning = excluded.meaning,
                          source = excluded.source,
                          source_pack_id = excluded.source_pack_id,
                          source_lesson_id = excluded.source_lesson_id,
                          saved_at_ms = excluded.saved_at_ms
            WHERE excluded.saved_at_ms > saved_phrases.saved_at_ms;
            """,
            bind: {
                try $0.bindText(1, row.id)
                try $0.bindText(2, row.languageSlug)
                try $0.bindText(3, row.languageName)
                try $0.bindText(4, row.target)
                try $0.bindText(5, row.meaning)
                try $0.bindText(6, row.source)
                try $0.bindText(7, row.sourcePackId)
                try $0.bindText(8, row.sourceLessonId)
                try $0.bindInt64(9, row.savedAtMs)
            })
    }

    /// Every listen-state row with its write timestamp, for merge + export.
    func allListenState() throws -> [ListenStateRow] {
        var rows: [ListenStateRow] = []
        try db.query(
            """
            SELECT track_id, position_seconds, listened_at_ms, updated_at_ms
            FROM listen_state;
            """,
            row: { statement in
                rows.append(ListenStateRow(
                    trackId: statement.text(0) ?? "",
                    positionSeconds: statement.double(1),
                    listenedAtMs: statement.isNull(2)
                        ? nil : statement.int64(2),
                    updatedAtMs: statement.int64(3)))
            })
        return rows
    }

    /// Merges listen state from another device, last-write-wins.
    func mergeListenState(_ row: ListenStateRow) throws {
        try db.transaction {
            try self.mergeListenStateRow(row)
        }
    }

    /// Transaction-free listen-state merge, for batching inside one
    /// transaction (data import). Same last-write-wins rule.
    private func mergeListenStateRow(_ row: ListenStateRow) throws {
        try db.execute(
            """
            INSERT INTO listen_state(track_id, position_seconds, listened_at_ms, updated_at_ms)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(track_id)
            DO UPDATE SET position_seconds = excluded.position_seconds,
                          listened_at_ms = excluded.listened_at_ms,
                          updated_at_ms = excluded.updated_at_ms
            WHERE excluded.updated_at_ms > listen_state.updated_at_ms;
            """,
            bind: {
                try $0.bindText(1, row.trackId)
                try $0.bindDouble(2, row.positionSeconds)
                if let listened = row.listenedAtMs {
                    try $0.bindInt64(3, listened)
                } else {
                    try $0.bindNull(3)
                }
                try $0.bindInt64(4, row.updatedAtMs)
            })
    }

    /// Clears the resume position but keeps the listened mark, if any.
    func clearListenPosition(trackId: String) throws {
        try db.execute(
            """
            UPDATE listen_state
            SET position_seconds = 0, updated_at_ms = ?
            WHERE track_id = ?;
            """,
            bind: {
                try $0.bindInt64(1, LearningStore.millis(Date()))
                try $0.bindText(2, trackId)
            })
    }

    // MARK: - Restore (validated import)

    /// Applies a fully validated export in ONE SQLite transaction.
    ///
    /// Every section reuses the store's existing merge rules, so a restore
    /// behaves exactly like a third device syncing down:
    /// - Events go through the idempotent insert (`record`'s rule): the
    ///   same id with identical content is a no-op; the same id with
    ///   different content throws `StoreError.conflict`, which aborts the
    ///   whole transaction — rollback leaves the store exactly as it was.
    /// - Saved phrases merge last-write-wins with their tombstones, and a
    ///   tombstone wins over an older phrase row; checkpoint rows and
    ///   tombstones follow the same rules; listen state is last-write-wins
    ///   per track.
    /// - Because every write is idempotent or where-guarded, re-importing
    ///   the identical file changes nothing.
    ///
    /// Placement recommendations live in UserDefaults and are applied by
    /// the caller (`YouModel.restore`) only after this transaction has
    /// committed, so a failed import writes nothing anywhere.
    func applyImport(_ preview: ImportPreview) throws {
        try db.transaction {
            for event in preview.events {
                try self.insertEvent(event)
            }
            for checkpoint in preview.checkpoints {
                try self.mergeCheckpointRow(checkpoint)
            }
            for tombstone in preview.checkpointTombstones {
                try self.mergeCheckpointTombstoneRow(tombstone)
            }
            for phrase in preview.savedPhrases {
                try self.mergeSavedPhraseRow(phrase)
            }
            for tombstone in preview.savedPhraseTombstones {
                try self.mergeSavedPhraseTombstoneRow(tombstone)
            }
            for row in preview.listenState {
                try self.mergeListenStateRow(row)
            }
        }
    }

    /// The full immutable event log, oldest first, for data export.
    ///
    /// Fail-loud raw-log read like `learningEvents(packId:)`: throws
    /// `StoreError.corruptPayload` on the first undecodable row, because an
    /// export must not silently lose history. Tolerant consumers use
    /// `unsyncedEvents()` / `project(pack:)`, `allEventsWithQuarantine()`,
    /// or read `corruptEventIds()`.
    func allEvents() throws -> [LearningEvent] {
        let (events, skipped) = try decodeEventRows(
            sql: "SELECT id, payload FROM events ORDER BY at_ms, id;")
        if let firstBad = skipped.first {
            throw StoreError.corruptPayload(firstBad)
        }
        return events
    }

    /// The full immutable event log, oldest first, together with the ids of
    /// stored rows whose payload could not be decoded.
    ///
    /// Tolerant global read for review feeds: an undecodable row is skipped
    /// and reported in the returned `skipped` list instead of failing the
    /// whole Review tab, so a corrupt row in any pack — even one never
    /// opened — cannot degrade review. Data export still uses the fail-loud
    /// `allEvents()`, which must never silently drop history.
    func allEventsWithQuarantine() throws
        -> (events: [LearningEvent], skipped: [String]) {
        try decodeEventRows(
            sql: "SELECT id, payload FROM events ORDER BY at_ms, id;")
    }

    /// Ids of stored event rows whose payload cannot be decoded, oldest
    /// first. The resilient reads skip these rows instead of failing —
    /// `project(pack:)` reports the pack-scoped subset in
    /// `PackProgress.quarantined`, while `unsyncedEvents()` drops them from
    /// the pending upload — so this accessor (alongside the two raw-log
    /// reads above, which throw) keeps local corruption observable.
    ///
    /// Follow-up only (deliberately not implemented here): self-healing a
    /// corrupt row by replacing it with the server's copy. Until a repair
    /// pass can prove which copy is authoritative, the row stays skipped and
    /// observable rather than silently rewritten.
    func corruptEventIds() throws -> [String] {
        try decodeEventRows(
            sql: "SELECT id, payload FROM events ORDER BY at_ms, id;").skipped
    }

    // MARK: - Observability

    private static let corruptRowsLog = Logger(
        subsystem: "com.sleuthysloth.condisco", category: "LearningStore")

    /// Logs ids of stored event rows that the resilient reads skipped, for
    /// every surface that observes local corruption: store open, sync, and
    /// the review catalog. Non-fatal by design — the rows stay skipped so
    /// the rest of the log keeps working.
    static func logCorruptRows(_ ids: [String]) {
        guard !ids.isEmpty else { return }
        corruptRowsLog.error(
            "Skipped \(ids.count, privacy: .public) undecodable stored event row(s): \(ids.joined(separator: ", "), privacy: .public)")
    }

    // MARK: - Listen state

    /// Resume position in seconds. Never claims progress or mastery;
    /// finishing a track records that it was heard, nothing more.
    func listenPosition(trackId: String) throws -> Double {
        var position: Double = 0
        try db.query(
            "SELECT position_seconds FROM listen_state WHERE track_id = ?;",
            bind: { try $0.bindText(1, trackId) },
            row: { position = $0.double(0) })
        return position
    }

    func saveListenPosition(trackId: String, seconds: Double, at: Date = Date()) throws {
        try db.execute(
            """
            INSERT INTO listen_state(track_id, position_seconds, listened_at_ms, updated_at_ms)
            VALUES (?, ?, NULL, ?)
            ON CONFLICT(track_id)
            DO UPDATE SET position_seconds = excluded.position_seconds,
                          updated_at_ms = excluded.updated_at_ms;
            """,
            bind: {
                try $0.bindText(1, trackId)
                try $0.bindDouble(2, seconds)
                try $0.bindInt64(3, LearningStore.millis(at))
            })
    }

    func markListened(trackId: String, at: Date = Date()) throws {
        let ms = LearningStore.millis(at)
        try db.execute(
            """
            INSERT INTO listen_state(track_id, position_seconds, listened_at_ms, updated_at_ms)
            VALUES (?, 0, ?, ?)
            ON CONFLICT(track_id)
            DO UPDATE SET listened_at_ms = excluded.listened_at_ms,
                          updated_at_ms = excluded.updated_at_ms;
            """,
            bind: {
                try $0.bindText(1, trackId)
                try $0.bindInt64(2, ms)
                try $0.bindInt64(3, ms)
            })
    }

    func listenedAt(trackId: String) throws -> Date? {
        var result: Date?
        try db.query(
            "SELECT listened_at_ms FROM listen_state WHERE track_id = ?;",
            bind: { try $0.bindText(1, trackId) },
            row: {
                if !$0.isNull(0) { result = LearningStore.date($0.int64(0)) }
            })
        return result
    }

    // MARK: - Saved phrases (phrasebook)

    /// Deterministic id (language + target + meaning) so saving the same
    /// phrase twice is a no-op and sync can merge by key. Nonisolated so
    /// the CloudKit decode path can rebuild ids off the main actor.
    nonisolated static func savedPhraseId(languageSlug: String, target: String, meaning: String) -> String {
        "\(languageSlug)|\(target)|\(meaning)"
    }

    func savePhrase(_ phrase: SavedPhrase) throws {
        let atMs = LearningStore.millis(phrase.savedAt)
        try db.transaction {
            try self.db.execute(
                """
                INSERT INTO saved_phrases(id, language_slug, language_name, target, meaning, source, source_pack_id, source_lesson_id, saved_at_ms)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO NOTHING;
                """,
                bind: {
                    try $0.bindText(1, phrase.id)
                    try $0.bindText(2, phrase.languageSlug)
                    try $0.bindText(3, phrase.languageName)
                    try $0.bindText(4, phrase.target)
                    try $0.bindText(5, phrase.meaning)
                    try $0.bindText(6, phrase.source)
                    try $0.bindText(7, phrase.sourcePackId)
                    try $0.bindText(8, phrase.sourceLessonId)
                    try $0.bindInt64(9, atMs)
                })
            // A fresh save supersedes an older delete.
            try self.db.execute(
                "DELETE FROM saved_phrase_tombstones WHERE id = ? AND deleted_at_ms <= ?;",
                bind: {
                    try $0.bindText(1, phrase.id)
                    try $0.bindInt64(2, atMs)
                })
        }
    }

    /// Deletes the phrase and records a tombstone, so the unsave spreads
    /// to the learner's other devices on sync instead of the row
    /// resurrecting from another device's copy.
    func unsavePhrase(id: String) throws {
        let nowMs = LearningStore.millis(Date())
        try db.transaction {
            try self.db.execute(
                "DELETE FROM saved_phrases WHERE id = ?;",
                bind: { try $0.bindText(1, id) })
            try self.db.execute(
                """
                INSERT INTO saved_phrase_tombstones(id, deleted_at_ms)
                VALUES (?, ?)
                ON CONFLICT(id)
                DO UPDATE SET deleted_at_ms = excluded.deleted_at_ms
                WHERE excluded.deleted_at_ms > saved_phrase_tombstones.deleted_at_ms;
                """,
                bind: {
                    try $0.bindText(1, id)
                    try $0.bindInt64(2, nowMs)
                })
        }
    }

    func isPhraseSaved(id: String) throws -> Bool {
        var found = false
        try db.query(
            "SELECT 1 FROM saved_phrases WHERE id = ? LIMIT 1;",
            bind: { try $0.bindText(1, id) },
            row: { _ in found = true })
        return found
    }

    /// Newest first, for the phrasebook.
    func savedPhrases() throws -> [SavedPhrase] {
        var phrases: [SavedPhrase] = []
        try db.query(
            """
            SELECT id, language_slug, language_name, target, meaning, source, source_pack_id, source_lesson_id, saved_at_ms
            FROM saved_phrases
            ORDER BY saved_at_ms DESC, id;
            """,
            row: {
                phrases.append(SavedPhrase(
                    id: $0.text(0) ?? "",
                    languageSlug: $0.text(1) ?? "",
                    languageName: $0.text(2) ?? "",
                    target: $0.text(3) ?? "",
                    meaning: $0.text(4) ?? "",
                    source: $0.text(5) ?? "",
                    sourcePackId: $0.text(6) ?? "",
                    sourceLessonId: $0.text(7) ?? "",
                    savedAt: LearningStore.date($0.int64(8))))
            })
        return phrases
    }

    /// Every saved phrase with its raw write timestamp, for merge + export.
    /// Oldest first for a deterministic export.
    func allSavedPhrases() throws -> [StoredSavedPhrase] {
        var phrases: [StoredSavedPhrase] = []
        try db.query(
            """
            SELECT id, language_slug, language_name, target, meaning, source, source_pack_id, source_lesson_id, saved_at_ms
            FROM saved_phrases
            ORDER BY saved_at_ms, id;
            """,
            row: { statement in
                phrases.append(StoredSavedPhrase(
                    id: statement.text(0) ?? "",
                    languageSlug: statement.text(1) ?? "",
                    languageName: statement.text(2) ?? "",
                    target: statement.text(3) ?? "",
                    meaning: statement.text(4) ?? "",
                    source: statement.text(5) ?? "",
                    sourcePackId: statement.text(6) ?? "",
                    sourceLessonId: statement.text(7) ?? "",
                    savedAtMs: statement.int64(8)))
            })
        return phrases
    }

    // MARK: - Key/value (sync metadata, device id)

    func kvGet(_ key: String) throws -> String? {
        var result: String?
        try db.query(
            "SELECT value FROM kv WHERE key = ?;",
            bind: { try $0.bindText(1, key) },
            row: { result = $0.text(0) })
        return result
    }

    func kvSet(_ key: String, _ value: String) throws {
        try db.execute(
            "INSERT INTO kv(key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value;",
            bind: {
                try $0.bindText(1, key)
                try $0.bindText(2, value)
            })
    }

    /// Removes a kv row entirely. Used by local-only markers to un-mark
    /// them — the row's absence (like an empty value) reads as "not set",
    /// so a delete and a clear are indistinguishable to `kvGet`.
    func kvDelete(_ key: String) throws {
        try db.execute(
            "DELETE FROM kv WHERE key = ?;",
            bind: { try $0.bindText(1, key) })
    }

    /// Stable per-install device id for future sync. Created once, never reset.
    func deviceId() throws -> String {
        if let existing = try kvGet("device_id") { return existing }
        let id = UUID().uuidString
        try kvSet("device_id", id)
        return id
    }

    // MARK: - Projection

    /// Projects a pack's progress from its event log.
    /// Mirrors `projectLessonEvidence` in the web app.
    ///
    /// Evaluation consistency (re-running `evaluateActivity` over recorded
    /// responses) is enforced by the lesson engine at record time, so the
    /// store validates structure, identity, and revisions here.
    func project(pack: CoursePack) throws -> PackProgress {
        // Tolerant read: an undecodable stored row is skipped and its id
        // lands in `quarantined` below instead of failing the whole pack.
        let (events, skipped) = try decodeEventRows(
            sql: "SELECT id, payload FROM events WHERE pack_id = ? ORDER BY at_ms, id;",
            bind: { try $0.bindText(1, pack.id) })

        var v1: [PracticeEventV1] = []
        var attempts: [ActivityAttempt] = []
        var completions: [StepCompletion] = []
        var knownMarks: [LessonKnownEvent] = []
        var checkpointAttempts: [CheckpointAttemptEvent] = []
        var openTaskAttempts: [OpenTaskAttemptEvent] = []
        var dialogueTurnEvents: [DialogueTurnEvent] = []
        for event in events {
            switch event {
            case .practiceV1(let e): v1.append(e)
            case .attempt(let e): attempts.append(e)
            case .stepCompleted(let e): completions.append(e)
            case .lessonKnown(let e): knownMarks.append(e)
            case .checkpointAttempt(let e): checkpointAttempts.append(e)
            case .openTaskAttempt(let e): openTaskAttempts.append(e)
            case .dialogueTurn(let e): dialogueTurnEvents.append(e)
            }
        }

        let lessonsById = Dictionary(uniqueKeysWithValues: pack.lessons.map { ($0.id, $0) })
        let activitiesById = Dictionary(uniqueKeysWithValues: pack.activities.map { ($0.id, $0) })
        let exercisesById = Dictionary(
            uniqueKeysWithValues: pack.lessons.flatMap { $0.legacyExercises }.map { ($0.id, $0) })

        var quarantined: [String] = []
        // Undecodable stored rows are held out of projection entirely; their
        // ids ride along in `quarantined` (stable query order, deduped) so
        // the corruption stays observable without failing the whole pack.
        quarantined.append(contentsOf: skipped)

        // Valid attempts: reference an existing lesson/step/activity with
        // matching revisions and the activity's own evidence key.
        var validAttempts: [String: ActivityAttempt] = [:]
        for attempt in attempts {
            guard let lesson = lessonsById[attempt.lessonId],
                  let activity = activitiesById[attempt.activityId],
                  let step = lesson.steps.first(where: { $0.id == attempt.stepId }),
                  step.activityId == attempt.activityId,
                  lesson.revision == attempt.lessonRevision,
                  activityRevision(activity) == attempt.activityRevision,
                  activity.evidenceKey == attempt.evidenceKey
            else {
                quarantined.append(attempt.id)
                continue
            }
            validAttempts[attempt.id] = attempt
        }
        let attemptsById = Dictionary(uniqueKeysWithValues: attempts.map { ($0.id, $0) })
        let orderedAttempts = validAttempts.values.sorted {
            if $0.at != $1.at { return $0.at < $1.at }
            return $0.id < $1.id
        }

        // Valid completions. A graded step completion without a matching
        // attempt aborts, exactly like the web importer.
        var validCompletions: [StepCompletion] = []
        for completion in completions {
            guard let lesson = lessonsById[completion.lessonId],
                  lesson.revision == completion.lessonRevision,
                  let step = lesson.steps.first(where: { $0.id == completion.stepId }),
                  let activity = activitiesById[step.activityId]
            else {
                quarantined.append(completion.id)
                continue
            }
            let attempt = completion.attemptId.flatMap { attemptsById[$0] }
            if !isUngradedKind(activity) {
                guard let found = attempt,
                      found.lessonId == completion.lessonId,
                      found.stepId == completion.stepId,
                      found.activityId == step.activityId,
                      found.lessonRevision == completion.lessonRevision
                else { throw StoreError.danglingCompletion(completion.id) }
            }
            var ok = true
            if completion.attemptId != nil && attempt == nil { ok = false }
            if let found = attempt {
                let outcomeOk: Bool = {
                    switch found.evaluation.outcome {
                    case .correct, .ungraded, .selfAssessed: return true
                    case .incorrect, .blocked: return false
                    }
                }()
                if found.lessonId != completion.lessonId ||
                    found.stepId != completion.stepId ||
                    found.activityId != step.activityId ||
                    validAttempts[found.id] == nil ||
                    found.at > completion.at ||
                    !outcomeOk {
                    ok = false
                }
            }
            let branchKeys = Array(step.branches.keys)
            if !branchKeys.isEmpty {
                let selected = completion.selectedBranchId
                let responseOk: Bool = {
                    guard let found = attempt,
                          let selected = selected,
                          case .selection(let ids) = found.response
                    else { return false }
                    return ids.count == 1 && ids[0] == selected
                }()
                if selected == nil || !branchKeys.contains(selected!) || !responseOk {
                    ok = false
                }
            } else if completion.selectedBranchId != nil {
                ok = false
            }
            if !ok {
                quarantined.append(completion.id)
                continue
            }
            validCompletions.append(completion)
        }

        // Participation: walk the chosen path; every required step must be done.
        var completedByLesson: [String: Set<String>] = [:]
        for completion in validCompletions {
            completedByLesson[completion.lessonId, default: []].insert(completion.stepId)
        }
        var participationCompleted = Set<String>()
        for lesson in pack.lessons {
            guard let done = completedByLesson[lesson.id] else { continue }
            let stepsById = Dictionary(uniqueKeysWithValues: lesson.steps.map { ($0.id, $0) })
            var trail: [String] = []
            var current: String? = lesson.entryStepId
            var seen = Set<String>()
            var resolvedPath = true
            while let stepId = current, !seen.contains(stepId) {
                seen.insert(stepId)
                trail.append(stepId)
                guard let step = stepsById[stepId] else { break }
                if step.branches.isEmpty {
                    current = step.nextStepId
                } else {
                    let completion = validCompletions.last(where: {
                        $0.lessonId == lesson.id &&
                        $0.stepId == stepId &&
                        $0.lessonRevision == lesson.revision
                    })
                    if let selected = completion?.selectedBranchId,
                       let next = step.branches[selected] {
                        current = next
                    } else {
                        resolvedPath = false
                        current = nil
                    }
                }
            }
            let requiredDone = trail.allSatisfy { stepId in
                guard let step = stepsById[stepId] else { return true }
                return !step.required || done.contains(stepId)
            }
            if resolvedPath && current == nil && requiredDone {
                participationCompleted.insert(lesson.id)
            }
        }

        // Legacy credit: v1 successes plus independent-correct v2 work on
        // legacy activities and converted v1 exercises.
        var successByExercise: [String: Bool] = [:]
        for event in v1 {
            if event.correct && !event.revealed {
                successByExercise[event.exerciseId] = true
            } else if successByExercise[event.exerciseId] == nil {
                successByExercise[event.exerciseId] = false
            }
        }
        for attempt in orderedAttempts {
            guard attempt.evaluation.outcome == .correct,
                  attempt.evaluation.independent,
                  let activity = activitiesById[attempt.activityId]
            else { continue }
            switch activity {
            case .legacy(let a):
                if exercisesById[a.exerciseId] != nil {
                    successByExercise[a.exerciseId] = true
                }
            case .information:
                break
            default:
                // Converted v1 exercises keep their exercise id as the activity id.
                if exercisesById[attempt.activityId] != nil {
                    successByExercise[attempt.activityId] = true
                }
            }
        }
        var legacyCredits = Set<String>()
        for lesson in pack.lessons {
            let legacyIds: [String]
            if let explicit = lesson.legacyCompletionExerciseIds {
                legacyIds = explicit
            } else if case .legacySuccess(let ids) = lesson.completionPolicy {
                legacyIds = ids
            } else {
                legacyIds = []
            }
            if !legacyIds.isEmpty && legacyIds.allSatisfy({ successByExercise[$0] == true }) {
                legacyCredits.insert(lesson.id)
            }
        }

        // Manual "I know this" marks: the latest mark per lesson wins.
        // Events arrive sorted by (at, id), so a plain fold applies them in
        // order. Marks against a missing lesson or a stale lesson revision
        // are quarantined — changed content re-earns its credit.
        var knownLessons = Set<String>()
        for mark in knownMarks {
            guard let lesson = lessonsById[mark.lessonId],
                  lesson.revision == mark.lessonRevision
            else {
                quarantined.append(mark.id)
                continue
            }
            if mark.known {
                knownLessons.insert(mark.lessonId)
            } else {
                knownLessons.remove(mark.lessonId)
            }
        }

        // Checkpoint attempts (5.3A): open practice evidence, never
        // completion credit, SRS input, or a lock. A checkpoint no longer
        // in the bundled pack quarantines the attempt (learner-owned
        // history stays observable) instead of failing the read.
        let checkpointsById = Dictionary(
            uniqueKeysWithValues: pack.checkpoints.map { ($0.id, $0) })
        var validCheckpointAttempts: [CheckpointAttemptEvent] = []
        for attempt in checkpointAttempts {
            guard checkpointsById[attempt.checkpointId] != nil else {
                quarantined.append(attempt.id)
                continue
            }
            validCheckpointAttempts.append(attempt)
        }

        // Open-task attempts (6.2): practice evidence bound to a lesson
        // step, never completion credit, SRS input, or a lock. A row whose
        // activity is no longer an open task in the bundled pack (or whose
        // lesson/step/revision no longer resolves) quarantines the attempt
        // instead of failing the read — learner-owned history stays
        // observable.
        var validOpenTaskAttempts: [OpenTaskAttemptEvent] = []
        for attempt in openTaskAttempts {
            guard let lesson = lessonsById[attempt.lessonId],
                  lesson.revision == attempt.lessonRevision,
                  let step = lesson.steps.first(where: { $0.id == attempt.stepId }),
                  step.activityId == attempt.activityId,
                  let activity = activitiesById[attempt.activityId],
                  case .openTask(let spec) = activity,
                  spec.revision == attempt.activityRevision,
                  spec.mode == attempt.mode
            else {
                quarantined.append(attempt.id)
                continue
            }
            validOpenTaskAttempts.append(attempt)
        }

        // Dialogue turns (6.3): practice evidence per answered exchange
        // turn, never completion credit, SRS input, or a lock. A row whose
        // dialogue/node is no longer in the bundled pack (or whose host
        // binding/revision no longer resolves) quarantines the attempt —
        // learner-owned history stays observable.
        let dialoguesById = Dictionary(uniqueKeysWithValues: pack.dialogues.map { ($0.id, $0) })
        var validDialogueTurns: [DialogueTurnEvent] = []
        for turn in dialogueTurnEvents {
            guard let dialogue = dialoguesById[turn.dialogueId],
                  dialogue.nodes.contains(where: { $0.id == turn.nodeId }),
                  let hostLesson = lessonsById[turn.hostLessonId],
                  hostLesson.revision == turn.hostLessonRevision,
                  dialogue.hostLessonId == turn.hostLessonId
            else {
                quarantined.append(turn.id)
                continue
            }
            validDialogueTurns.append(turn)
        }

        // Independent evidence SRS per evidence key.
        var evidence: [String: EvidenceRecord] = [:]
        for attempt in orderedAttempts {
            guard let key = attempt.evidenceKey else { continue }
            switch attempt.evaluation.outcome {
            case .blocked, .ungraded, .selfAssessed:
                continue
            case .correct, .incorrect:
                break
            }
            guard let activity = activitiesById[attempt.activityId] else { continue }
            let at = attempt.at
            let previous = evidence[key] ?? EvidenceRecord(
                fsrs: Fsrs.initial(at: at),
                successes: 0,
                failures: 0,
                mode: skillMode(activitySkills(activity)))
            let success = attempt.evaluation.outcome == .correct && attempt.evaluation.independent
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

        // Skill counts from correct attempts.
        var skillCounts: [Skill: SkillCount] = [
            .reading: SkillCount(), .listening: SkillCount(), .writing: SkillCount(),
            .speaking: SkillCount(), .grammar: SkillCount(), .vocabulary: SkillCount(),
        ]
        for attempt in orderedAttempts {
            guard attempt.evaluation.outcome == .correct,
                  let activity = activitiesById[attempt.activityId]
            else { continue }
            for skill in activitySkills(activity) {
                if attempt.evaluation.independent {
                    skillCounts[skill]?.independent += 1
                } else {
                    skillCounts[skill]?.assisted += 1
                }
            }
        }

        // Evidence categories (5.2A): what the attempts prove per key,
        // derived strictly from stored fields so old payloads replay
        // conservatively. V1 rows carry no response kind, no independence
        // flag, and no evidence key — they never contribute a category,
        // so old history yields old progress (legacy credit) plus the
        // weakest honest category, never invented production mastery.
        //
        // Derivation table (one category per attempt):
        //   review (selfRating response, i.e. Review tab / lesson warm-up)
        //     · clean success (correct + independent) ≥ 86,400 s after the
        //       key's first independent production → .recalledLater
        //     · clean success within the same day                          → (none;
        //       the production categories already cover the key)
        //     · anything else (miss, or correct-but-assisted)              → .seen
        //   production kind (text / cloze / legacy) + correct + independent
        //                                                               → .producedIndependently
        //   production kind + correct + assisted                         → .producedWithHelp
        //   production kind + incorrect                                  → .seen
        //   recognition kind (selection / ordering / matching /
        //     dialogue-choice / scene-selection) + correct + independent → .recognized
        //   recognition kind otherwise (miss, or assisted correct —
        //     a hint-guided pick cannot prove recognition)               → .seen
        //   information / self-compare                                   → (none)
        //
        // "Recalled later" rule (documented at the implementation site):
        // a successful, unassisted review on the evidence key at least one
        // full day (86,400 s) after the key's first independent
        // production. Same-session reviews never count.
        var evidenceCategories: [String: Set<EvidenceCategory>] = [:]
        var firstIndependentProductionAt: [String: Date] = [:]
        for attempt in orderedAttempts {
            guard let key = attempt.evidenceKey,
                  let activity = activitiesById[attempt.activityId]
            else { continue }
            switch attempt.evaluation.outcome {
            case .blocked, .ungraded, .selfAssessed:
                continue  // nothing graded on record
            case .correct, .incorrect:
                break
            }
            switch proofKind(for: activity, response: attempt.response) {
            case .none:
                continue
            case .review:
                if attempt.evaluation.outcome == .correct,
                   attempt.evaluation.independent,
                   let first = firstIndependentProductionAt[key],
                   attempt.at.timeIntervalSince(first) >= 86_400 {
                    evidenceCategories[key, default: []].insert(.recalledLater)
                } else if attempt.evaluation.outcome != .correct
                            || !attempt.evaluation.independent {
                    // A review the learner did not pass cleanly only proves
                    // the card was seen.
                    evidenceCategories[key, default: []].insert(.seen)
                }
            case .production:
                if attempt.evaluation.outcome == .correct {
                    if attempt.evaluation.independent {
                        evidenceCategories[key, default: []].insert(.producedIndependently)
                        if firstIndependentProductionAt[key] == nil {
                            firstIndependentProductionAt[key] = attempt.at
                        }
                    } else {
                        evidenceCategories[key, default: []].insert(.producedWithHelp)
                    }
                } else {
                    evidenceCategories[key, default: []].insert(.seen)
                }
            case .recognition:
                if attempt.evaluation.outcome == .correct
                    && attempt.evaluation.independent {
                    evidenceCategories[key, default: []].insert(.recognized)
                } else {
                    evidenceCategories[key, default: []].insert(.seen)
                }
            }
        }

        return PackProgress(
            participationCompleted: participationCompleted,
            legacyCredits: legacyCredits,
            knownLessons: knownLessons,
            evidence: evidence,
            evidenceCategories: evidenceCategories,
            skillCounts: skillCounts,
            checkpointAttempts: validCheckpointAttempts,
            openTaskAttempts: validOpenTaskAttempts,
            dialogueTurns: validDialogueTurns,
            quarantined: quarantined)
    }

    /// Records a manual "I know this" mark — or its removal — for a
    /// lesson. The mark counts toward completion but carries no evidence
    /// and never schedules reviews. Syncs as an ordinary event.
    func setLessonKnown(pack: CoursePack, lessonId: String, known: Bool) throws {
        guard let lesson = pack.lessons.first(where: { $0.id == lessonId })
        else { return }
        try record(.lessonKnown(LessonKnownEvent(
            id: UUID().uuidString,
            packId: pack.id,
            packVersion: pack.version,
            lessonId: lesson.id,
            lessonRevision: lesson.revision,
            known: known,
            at: Date())))
    }

    /// Records a checkpoint attempt as practice evidence (5.3A). Stage and
    /// modality coverage are denormalised from the authored task at record
    /// time; the projection re-validates against the pack.
    ///
    /// Semantics, enforced here:
    /// - One SQLite transaction, idempotent insert (same rules as
    ///   `record`): replaying the identical event is a no-op. A retake is a
    ///   fresh event with a new id — the earlier attempt stays on record
    ///   and no completion, known mark, or evidence is duplicated, because
    ///   checkpoint rows carry no lesson/step/activity/evidence columns.
    /// - The learner can always continue: no lock, no streak, no progress
    ///   penalty. A low self-rating is practice evidence like any other.
    /// - Reveal-before-answer guard: `independent` is derived as
    ///   `itemsRevealed && assistance.isEmpty`, so an attempt saved without
    ///   the reveal marker can never carry independent credit. The 5.3B UI
    ///   lane must pass `itemsRevealed: true` only after presenting the
    ///   task's items and rubric (then `selfRating` carries the ticks).
    ///
    /// - Returns: the stored event, or nil when the checkpoint is not in
    ///   the bundled pack (nothing is recorded for an unknown id — the UI
    ///   lane reads the task from the pack before offering it).
    @discardableResult
    func recordCheckpointAttempt(
        pack: CoursePack,
        checkpointId: String,
        assistance: [AssistanceKind],
        itemsRevealed: Bool,
        selfRating: CheckpointSelfRating?,
        at: Date = Date()
    ) throws -> CheckpointAttemptEvent? {
        guard let checkpoint = pack.checkpoints.first(where: { $0.id == checkpointId })
        else { return nil }
        let event = CheckpointAttemptEvent(
            id: UUID().uuidString,
            packId: pack.id,
            packVersion: pack.version,
            checkpointId: checkpoint.id,
            stage: checkpoint.stage,
            modalitySlots: checkpoint.modalities,
            assistance: assistance,
            selfRating: selfRating,
            itemsRevealed: itemsRevealed,
            at: at)
        try record(.checkpointAttempt(event))
        return event
    }

    /// Records an open-task completion as practice evidence (6.2). The
    /// lesson/step/activity binding and the task's modality are
    /// denormalised from the authored pack at record time; the projection
    /// re-validates against the pack.
    ///
    /// Semantics, enforced here:
    /// - One SQLite transaction, idempotent insert (same rules as
    ///   `record`): replaying the identical event is a no-op. A retake is a
    ///   fresh event with a new id — the earlier attempt stays on record
    ///   and no completion, known mark, or evidence is duplicated, because
    ///   the row carries no evidence column and an open-task step's
    ///   completion is a bare step-completed row with no attemptId.
    /// - The learner can always continue: no lock, no streak, no progress
    ///   penalty. The response text or recording is NEVER stored here —
    ///   the written draft stays local (lesson checkpoint) and the
    ///   recording is a disposable temp file.
    /// - Reveal-before-answer guard: `independent` is derived as
    ///   `!modelRevealed && assistance.isEmpty`, so an attempt saved after
    ///   the model was shown — or with any help — can never carry
    ///   independent credit. A retry after the reveal records
    ///   `modelRevealed: true`, keeping it distinguishable from
    ///   independent production.
    ///
    /// - Returns: the stored event, or nil when the activity is not an
    ///   open task bound to the given lesson step in the bundled pack
    ///   (nothing is recorded for an unknown binding — the UI lane reads
    ///   the task from the pack before offering it).
    @discardableResult
    func recordOpenTaskAttempt(
        pack: CoursePack,
        lessonId: String,
        stepId: String,
        activityId: String,
        assistance: [AssistanceKind],
        modelRevealed: Bool,
        selfRating: OpenTaskSelfRating?,
        at: Date = Date()
    ) throws -> OpenTaskAttemptEvent? {
        guard let lesson = pack.lessons.first(where: { $0.id == lessonId }),
              let step = lesson.steps.first(where: { $0.id == stepId }),
              step.activityId == activityId,
              let activity = pack.activities.first(where: { $0.id == activityId }),
              case .openTask(let spec) = activity
        else { return nil }
        let event = OpenTaskAttemptEvent(
            id: UUID().uuidString,
            packId: pack.id,
            packVersion: pack.version,
            lessonId: lesson.id,
            lessonRevision: lesson.revision,
            stepId: step.id,
            activityId: activity.id,
            activityRevision: spec.revision,
            mode: spec.mode,
            assistance: assistance,
            selfRating: selfRating,
            modelRevealed: modelRevealed,
            at: at)
        try record(.openTaskAttempt(event))
        return event
    }

    /// Records one answered exchange turn as practice evidence (6.3). The
    /// dialogue/host-lesson binding and revisions are denormalised from the
    /// authored pack at record time; the projection re-validates against
    /// the pack.
    ///
    /// Semantics, enforced here:
    /// - One SQLite transaction, idempotent insert (same rules as
    ///   `record`): replaying the identical event is a no-op. A retake of
    ///   the exchange answers fresh turns with fresh ids — earlier rows are
    ///   never erased, reordered, or duplicated.
    /// - The learner can always continue: no lock, no streak, no progress
    ///   penalty. Open turns are NEVER auto-graded — the event carries only
    ///   the learner's own self-assessment (rubric ticks + optional rating)
    ///   and the model-reveal marker; the composed draft is never stored
    ///   here (it lives in the lesson checkpoint for the recap).
    /// - `turnIndex` is the 1-based position of the turn within the
    ///   attempt, so the exchange's events read back in authored order
    ///   regardless of row ordering.
    ///
    /// - Returns: the stored event, or nil when the dialogue is not hosted
    ///   by the given lesson in the bundled pack (nothing is recorded for
    ///   an unknown binding — the UI lane reads the exchange from the pack
    ///   before offering it).
    @discardableResult
    func recordDialogueTurn(
        pack: CoursePack,
        lessonId: String,
        dialogueId: String,
        nodeId: String,
        turnIndex: Int,
        isOpen: Bool,
        choiceId: String?,
        criteriaMet: [String],
        rating: AttemptResponse.SelfRating?,
        modelRevealed: Bool,
        at: Date = Date()
    ) throws -> DialogueTurnEvent? {
        guard let lesson = pack.lessons.first(where: { $0.id == lessonId }),
              let dialogue = pack.dialogues.first(where: { $0.id == dialogueId }),
              dialogue.hostLessonId == lesson.id,
              dialogue.nodes.contains(where: { $0.id == nodeId })
        else { return nil }
        let event = DialogueTurnEvent(
            id: UUID().uuidString,
            packId: pack.id,
            packVersion: pack.version,
            dialogueId: dialogue.id,
            hostLessonId: lesson.id,
            hostLessonRevision: lesson.revision,
            nodeId: nodeId,
            turnIndex: turnIndex,
            isOpen: isOpen,
            choiceId: choiceId,
            criteriaMet: criteriaMet,
            rating: rating,
            modelRevealed: modelRevealed,
            at: at)
        try record(.dialogueTurn(event))
        return event
    }

    /// Evidence keys due for review, oldest first.
    func dueEvidence(
        pack: CoursePack, now: Date = Date()
    ) throws -> [(key: String, record: EvidenceRecord)] {
        let progress = try project(pack: pack)
        return progress.evidence
            .filter { $0.value.fsrs.dueAt <= now }
            .sorted { $0.value.fsrs.dueAt < $1.value.fsrs.dueAt }
            .map { (key: $0.key, record: $0.value) }
    }
}
