import Combine
import Foundation

// MARK: - Projection output

enum EvidenceMode: String, Codable {
    case production, recognition, listening
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
    /// Correct attempts per skill, split by independence.
    var skillCounts: [Skill: SkillCount] = [:]
    /// Event ids held out of projection (revision drift, retired targets).
    var quarantined: [String] = []
}

extension PackProgress {
    /// Every lesson that counts as finished for display: walked-through
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
    ///   path — pass `PackProgress.participationCompleted`. Each caller
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
    }
}

private func activitySkills(_ activity: Activity) -> [Skill] {
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
    }
}

private func isUngradedKind(_ activity: Activity) -> Bool {
    switch activity {
    case .information, .selfCompare: return true
    default: return false
    }
}

private func skillMode(_ skills: [Skill]) -> EvidenceMode {
    if skills.contains(.listening) { return .listening }
    if skills.contains(.writing) { return .production }
    return .recognition
}

// MARK: - Store

/// A checkpoint row with its write timestamp, for cross-device merge
/// (last-write-wins) and data export.
struct StoredCheckpoint: Codable, Sendable {
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
struct CheckpointTombstone: Codable, Sendable {
    var packId: String
    var lessonId: String
    var deletedAtMs: Int64
}

/// A deleted phrasebook entry's marker, for cross-device merge. A tombstone
/// at least as new as a saved-phrase row deletes it; a newer save retires
/// the tombstone. Without this, an unsaved phrase would resurrect the next
/// time another device's row synced down.
struct SavedPhraseTombstone: Codable, Sendable {
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

/// A listen-state row with its write timestamp, for merge and export.
struct ListenStateRow: Codable, Sendable {
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

    /// Appends an event. A duplicate id with identical content is a no-op;
    /// a duplicate id with different content throws.
    func record(_ event: LearningEvent) throws {
        let payloadData = try jsonEncoder.encode(event)
        guard let payload = String(data: payloadData, encoding: .utf8) else {
            throw StoreError.corruptPayload(event.id)
        }
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
        }

        try db.transaction {
            var existing: String?
            try self.db.query(
                "SELECT payload FROM events WHERE id = ?;",
                bind: { try $0.bindText(1, event.id) },
                row: { existing = $0.text(0) })
            if let old = existing {
                if old != payload { throw StoreError.conflict(event.id) }
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
    }

    /// All events for a pack, merged and sorted by (at, id).
    /// A corrupt stored payload throws rather than silently dropping history.
    func learningEvents(packId: String) throws -> [LearningEvent] {
        var events: [LearningEvent] = []
        try db.query(
            "SELECT id, payload FROM events WHERE pack_id = ? ORDER BY at_ms, id;",
            bind: { try $0.bindText(1, packId) },
            row: { statement in
                guard let payload = statement.text(1),
                      let data = payload.data(using: .utf8) else {
                    throw StoreError.corruptPayload(statement.text(0) ?? "?")
                }
                do {
                    events.append(try self.jsonDecoder.decode(LearningEvent.self, from: data))
                } catch {
                    throw StoreError.corruptPayload(statement.text(0) ?? "?")
                }
            })
        return events
    }

    // MARK: - Sync bookkeeping

    /// Events the server has not acknowledged yet, oldest first.
    /// Downloaded events are marked on ingest, so each event uploads once.
    func unsyncedEvents() throws -> [LearningEvent] {
        var events: [LearningEvent] = []
        try db.query(
            """
            SELECT id, payload FROM events
            WHERE id NOT IN (SELECT event_id FROM sync_uploads)
            ORDER BY at_ms, id;
            """,
            row: { statement in
                guard let payload = statement.text(1),
                      let data = payload.data(using: .utf8)
                else {
                    throw StoreError.corruptPayload(statement.text(0) ?? "?")
                }
                do {
                    events.append(try self.jsonDecoder.decode(
                        LearningEvent.self, from: data))
                } catch {
                    throw StoreError.corruptPayload(statement.text(0) ?? "?")
                }
            })
        return events
    }

    /// Records downloaded events and marks everything the server now holds.
    /// Downloads feed through the idempotent insert, so events already on
    /// this device are no-ops; a conflicting id (same id, other payload) is
    /// skipped rather than failing the whole sync.
    func ingestSynced(
        downloaded: [LearningEvent], uploadedIds: [String]
    ) throws {
        for event in downloaded {
            do {
                try record(event)
            } catch {
                continue
            }
        }
        let ids = Set(uploadedIds + downloaded.map(\.id))
        guard !ids.isEmpty else { return }
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
    }

    /// Merges a phrase received from another device, last-write-wins by
    /// saved_at_ms. A tombstone at least as new as the row keeps the phrase
    /// unsaved; a newer row retires its tombstone.
    func mergeSavedPhrase(_ phrase: SavedPhrase) throws {
        let atMs = LearningStore.millis(phrase.savedAt)
        try db.transaction {
            try self.db.execute(
                "DELETE FROM saved_phrase_tombstones WHERE id = ? AND deleted_at_ms < ?;",
                bind: {
                    try $0.bindText(1, phrase.id)
                    try $0.bindInt64(2, atMs)
                })
            var tombstoneMs: Int64?
            try self.db.query(
                "SELECT deleted_at_ms FROM saved_phrase_tombstones WHERE id = ?;",
                bind: { try $0.bindText(1, phrase.id) },
                row: { tombstoneMs = $0.int64(0) })
            if let tombstoneMs, tombstoneMs >= atMs {
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
        }
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

    /// The full immutable event log, oldest first, for data export.
    func allEvents() throws -> [LearningEvent] {
        var events: [LearningEvent] = []
        try db.query(
            "SELECT id, payload FROM events ORDER BY at_ms, id;",
            row: { statement in
                guard let payload = statement.text(1),
                      let data = payload.data(using: .utf8)
                else {
                    throw StoreError.corruptPayload(statement.text(0) ?? "?")
                }
                do {
                    events.append(try self.jsonDecoder.decode(
                        LearningEvent.self, from: data))
                } catch {
                    throw StoreError.corruptPayload(statement.text(0) ?? "?")
                }
            })
        return events
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
        let events = try learningEvents(packId: pack.id)

        var v1: [PracticeEventV1] = []
        var attempts: [ActivityAttempt] = []
        var completions: [StepCompletion] = []
        var knownMarks: [LessonKnownEvent] = []
        for event in events {
            switch event {
            case .practiceV1(let e): v1.append(e)
            case .attempt(let e): attempts.append(e)
            case .stepCompleted(let e): completions.append(e)
            case .lessonKnown(let e): knownMarks.append(e)
            }
        }

        let lessonsById = Dictionary(uniqueKeysWithValues: pack.lessons.map { ($0.id, $0) })
        let activitiesById = Dictionary(uniqueKeysWithValues: pack.activities.map { ($0.id, $0) })
        let exercisesById = Dictionary(
            uniqueKeysWithValues: pack.lessons.flatMap { $0.legacyExercises }.map { ($0.id, $0) })

        var quarantined: [String] = []

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

        return PackProgress(
            participationCompleted: participationCompleted,
            legacyCredits: legacyCredits,
            knownLessons: knownLessons,
            evidence: evidence,
            skillCounts: skillCounts,
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
