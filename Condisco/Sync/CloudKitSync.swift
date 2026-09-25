import CloudKit
import CryptoKit
import Foundation

// MARK: - Sync issues

/// User-facing sync failures. The local SQLite store is always the source of
/// truth; these describe why the background copy in CloudKit could not be
/// reached or updated.
enum SyncIssue: LocalizedError {
    case notSignedIn
    case noICloudAccount
    case cloudKit(Error)

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Sign in with Apple to sync."
        case .noICloudAccount:
            return "Sign in to iCloud in Settings to sync."
        case .cloudKit(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - CloudKit sync
//
// Six record types live in the private LearningZone:
//
// - LearningEvent: the immutable event log. Events are facts, never mutated:
//   each carries a UUID, so the merge of two devices is the union of both
//   logs. Uploads are idempotent and downloads feed through
//   LearningStore.record, which ignores events it already holds. Pulled by
//   server change token, so steady-state syncs fetch only what is new.
// - LessonCheckpoint: one row per lesson, last-write-wins by updated_at_ms.
//   Download-then-upload ordering makes the newest write converge everywhere.
// - CheckpointTombstone: a cleared lesson's delete marker. A tombstone at
//   least as new as a checkpoint row deletes it (and its server record);
//   a newer checkpoint row retires the tombstone. Without this, a cleared
//   checkpoint would resurrect the next time another device's row synced down.
// - ListenState: one row per track (resume position + listened mark),
//   last-write-wins the same way.
// - SavedPhrase: one row per phrasebook entry, last-write-wins by saved_at.
// - SavedPhraseTombstone: an unsaved phrase's delete marker, merging exactly
//   like CheckpointTombstone so an unsave never resurrects.
//
// Local SQLite remains the source of truth and the app works fully offline;
// CloudKit is a background copy that follows the learner between devices.

final class CloudKitSync: ObservableObject {
    static let recordType = "LearningEvent"
    static let checkpointRecordType = "LessonCheckpoint"
    static let checkpointTombstoneRecordType = "CheckpointTombstone"
    static let listenRecordType = "ListenState"
    static let savedPhraseRecordType = "SavedPhrase"
    static let savedPhraseTombstoneRecordType = "SavedPhraseTombstone"
    static let zoneName = "LearningZone"
    private static let lastSyncedKey = "verbalibera.sync.lastSyncedAt"
    private static let changeTokenKey = "condisco.sync.eventChangeToken"

    @MainActor @Published private(set) var isSyncing = false
    @MainActor @Published private(set) var lastErrorMessage: String?
    @MainActor @Published private(set) var lastSyncedAt: Date? = {
        let raw = UserDefaults.standard.double(
            forKey: CloudKitSync.lastSyncedKey)
        return raw > 0 ? Date(timeIntervalSince1970: raw) : nil
    }()

    /// Uploads new local state, then pulls what the other devices uploaded.
    /// Safe to call whenever; concurrent calls collapse into one.
    @MainActor
    func sync(store: LearningStore, signedIn: Bool) async {
        // One-time migration of legacy listen state; runs even signed out so
        // the store is the single source of truth either way.
        ListenHistory.migrateFromUserDefaultsIfNeeded(store: store)
        guard !isSyncing else { return }
        guard signedIn else {
            lastErrorMessage = SyncIssue.notSignedIn.errorDescription
            return
        }
        isSyncing = true
        defer { isSyncing = false }
        do {
            // 1. Events: upload new, then delta-pull by server change token.
            let toUpload = try store.unsyncedEvents()
            let uploadedIds = try await Self.push(events: toUpload)
            let downloaded: [LearningEvent]
            let newToken: CKServerChangeToken?
            do {
                (downloaded, newToken) = try await Self.pullEventChanges(
                    since: Self.loadChangeToken(store: store))
            } catch {
                // The server forgets old tokens; start the feed over.
                if (error as? CKError)?.code == .changeTokenExpired {
                    try store.kvSet(Self.changeTokenKey, "")
                    (downloaded, newToken) = try await Self.pullEventChanges(
                        since: nil)
                } else {
                    throw error
                }
            }
            try store.ingestSynced(
                downloaded: downloaded, uploadedIds: uploadedIds)
            try Self.saveChangeToken(newToken, store: store)
            // 2. Checkpoints + listen state + phrasebook: last-write-wins merge.
            try await Self.syncCheckpoints(store: store)
            try await Self.syncListenState(store: store)
            try await Self.syncSavedPhrases(store: store)
            let now = Date()
            lastSyncedAt = now
            UserDefaults.standard.set(
                now.timeIntervalSince1970, forKey: Self.lastSyncedKey)
            lastErrorMessage = nil
        } catch {
            let issue: SyncIssue
            if let syncIssue = error as? SyncIssue {
                issue = syncIssue
            } else {
                issue = .cloudKit(error)
            }
            lastErrorMessage = issue.errorDescription
        }
    }

    @MainActor
    func clearError() {
        lastErrorMessage = nil
    }
}

// MARK: - Change token persistence (MainActor: touches the store)

extension CloudKitSync {
    @MainActor
    static func loadChangeToken(store: LearningStore) -> CKServerChangeToken? {
        guard let encoded = try? store.kvGet(changeTokenKey),
              !encoded.isEmpty,
              let data = Data(base64Encoded: encoded),
              let token = try? NSKeyedUnarchiver.unarchivedObject(
                ofClass: CKServerChangeToken.self, from: data)
        else { return nil }
        return token
    }

    @MainActor
    static func saveChangeToken(
        _ token: CKServerChangeToken?, store: LearningStore
    ) throws {
        guard let token,
              let data = try? NSKeyedArchiver.archivedData(
                withRootObject: token, requiringSecureCoding: true)
        else { return }
        try store.kvSet(changeTokenKey, data.base64EncodedString())
    }
}

// MARK: - Merge phases (MainActor: store reads/writes stay local)

extension CloudKitSync {
    /// Downloads remote tombstones, merges them first, then merges
    /// checkpoints tombstone-aware, then retires the server records the
    /// tombstones killed and uploads the converged set.
    @MainActor
    static func syncCheckpoints(store: LearningStore) async throws {
        // 1. Tombstones first: a cleared lesson must die before any
        //    checkpoint row gets a chance to resurrect it.
        for tombstone in try await fetchCheckpointTombstones() {
            try store.mergeCheckpointTombstone(tombstone)
        }
        // 2. Checkpoints. mergeCheckpoint is tombstone-aware: a covered row
        //    is skipped, and a newer row retires its tombstone.
        for row in try await fetchCheckpoints() {
            try store.mergeCheckpoint(row)
        }
        let tombstones = try store.allCheckpointTombstones()
        let checkpoints = try store.allCheckpoints()
        let zoneID = try await ensureZone()
        // 3. Retire server checkpoint records covered by a tombstone, so a
        //    cleared lesson can never resurrect on another device's fetch.
        try await deleteRecords(
            tombstones.map {
                CKRecord.ID(
                    recordName: "ckpt-\($0.packId)-\($0.lessonId)",
                    zoneID: zoneID)
            },
            in: zoneID)
        // 4. Upload the converged set.
        try await pushCheckpoints(checkpoints)
        try await pushCheckpointTombstones(tombstones)
    }

    /// Same merge for listen resume positions and listened marks.
    @MainActor
    static func syncListenState(store: LearningStore) async throws {
        for row in try await fetchListenState() {
            try store.mergeListenState(row)
        }
        try await pushListenState(try store.allListenState())
    }

    /// Downloads remote tombstones, merges them first, then merges phrases
    /// tombstone-aware, then retires the server records the tombstones
    /// killed and uploads the converged set. Mirrors syncCheckpoints.
    @MainActor
    static func syncSavedPhrases(store: LearningStore) async throws {
        for tombstone in try await fetchSavedPhraseTombstones() {
            try store.mergeSavedPhraseTombstone(tombstone)
        }
        for phrase in try await fetchSavedPhrases() {
            try store.mergeSavedPhrase(phrase)
        }
        let tombstones = try store.allSavedPhraseTombstones()
        let phrases = try store.savedPhrases()
        let zoneID = try await ensureZone()
        try await deleteRecords(
            tombstones.map {
                CKRecord.ID(
                    recordName: savedPhraseRecordName(for: $0.id),
                    zoneID: zoneID)
            },
            in: zoneID)
        try await pushSavedPhrases(phrases)
        try await pushSavedPhraseTombstones(tombstones)
    }
}

// MARK: - Transport (no actor isolation; only Sendable values cross over)

extension CloudKitSync {
    private nonisolated static var database: CKDatabase {
        CKContainer.default().privateCloudDatabase
    }

    /// Uploads events; returns the ids the server accepted.
    nonisolated static func push(events: [LearningEvent]) async throws
        -> [String]
    {
        guard !events.isEmpty else { return [] }
        guard try await CKContainer.default().accountStatus() == .available
        else { throw SyncIssue.noICloudAccount }
        let zoneID = try await ensureZone()
        let payloads = try events.map { (event: LearningEvent) throws -> (
            id: String, record: CKRecord
        ) in
            (event.id, try makeRecord(for: event, zoneID: zoneID))
        }
        var accepted: [String] = []
        // CloudKit caps a modify at 400 records; stay well under it.
        for chunk in payloads.chunked(into: 200) {
            let result = try await database.modifyRecords(
                saving: chunk.map(\.record),
                deleting: [],
                savePolicy: .allKeys)
            for (recordID, saveResult) in result.saveResults {
                switch saveResult {
                case .success:
                    if let id = chunk.first(where: {
                        $0.record.recordID == recordID
                    })?.id {
                        accepted.append(id)
                    }
                case .failure(let error):
                    throw error
                }
            }
        }
        return accepted
    }

    /// Delta-pulls LearningEvent records via the server change feed. A nil
    /// token fetches everything (first sync); the returned token feeds the
    /// next call. Only event records are decoded; checkpoint/listen records
    /// in the zone are ignored here and merged by their own phases.
    nonisolated static func pullEventChanges(since token: CKServerChangeToken?)
        async throws -> (events: [LearningEvent], newToken: CKServerChangeToken?)
    {
        guard try await CKContainer.default().accountStatus() == .available
        else { throw SyncIssue.noICloudAccount }
        let zoneID = try await ensureZone()
        var events: [LearningEvent] = []
        var currentToken = token
        var moreComing = true
        while moreComing {
            let page = try await fetchEventChangePage(
                zoneID: zoneID, since: currentToken)
            events.append(contentsOf: page.events)
            currentToken = page.newToken ?? currentToken
            moreComing = page.moreComing
        }
        return (events, currentToken)
    }

    nonisolated static func fetchEventChangePage(
        zoneID: CKRecordZone.ID, since token: CKServerChangeToken?
    ) async throws -> (
        events: [LearningEvent],
        newToken: CKServerChangeToken?,
        moreComing: Bool
    ) {
        try await withCheckedThrowingContinuation { continuation in
            let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            configuration.previousServerChangeToken = token
            let operation = CKFetchRecordZoneChangesOperation(
                recordZoneIDs: [zoneID],
                configurationsByRecordZoneID: [zoneID: configuration])
            var events: [LearningEvent] = []
            var resumed = false
            func finish(_ result: Result<(
                events: [LearningEvent],
                newToken: CKServerChangeToken?,
                moreComing: Bool
            ), Error>) {
                guard !resumed else { return }
                resumed = true
                continuation.resume(with: result)
            }
            operation.recordWasChangedBlock = { _, result in
                if case .success(let record) = result,
                   record.recordType == recordType,
                   let event = decodeEvent(from: record) {
                    events.append(event)
                }
            }
            operation.recordZoneFetchResultBlock = { _, result in
                switch result {
                case .success(let (serverToken, _, moreComing)):
                    finish(.success(
                        (events, serverToken, moreComing)))
                case .failure(let error):
                    finish(.failure(error))
                }
            }
            database.add(operation)
        }
    }

    /// Fetches every record of one type in the sync zone. Used for the small
    /// checkpoint/listen tables; events use the change-token feed instead.
    nonisolated static func fetchAll(
        ofType type: String, zoneID: CKRecordZone.ID
    ) async throws -> [CKRecord] {
        let query = CKQuery(
            recordType: type,
            predicate: NSPredicate(value: true))
        var out: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?
        repeat {
            let page: (
                matchResults: [(CKRecord.ID, Result<CKRecord, Error>)],
                queryCursor: CKQueryOperation.Cursor?
            )
            if let cursor {
                page = try await database.records(
                    continuingMatchFrom: cursor, desiredKeys: nil)
            } else {
                page = try await database.records(
                    matching: query,
                    inZoneWith: zoneID,
                    desiredKeys: nil,
                    resultsLimit: 200)
            }
            for (_, result) in page.matchResults {
                if case .success(let record) = result {
                    out.append(record)
                }
            }
            cursor = page.queryCursor
        } while cursor != nil
        return out
    }

    nonisolated static func fetchCheckpoints() async throws
        -> [StoredCheckpoint]
    {
        guard try await CKContainer.default().accountStatus() == .available
        else { throw SyncIssue.noICloudAccount }
        let zoneID = try await ensureZone()
        return try await fetchAll(ofType: checkpointRecordType, zoneID: zoneID)
            .compactMap(decodeCheckpoint(from:))
    }

    nonisolated static func pushCheckpoints(_ rows: [StoredCheckpoint])
        async throws
    {
        guard !rows.isEmpty else { return }
        guard try await CKContainer.default().accountStatus() == .available
        else { throw SyncIssue.noICloudAccount }
        let zoneID = try await ensureZone()
        let records = rows.map { makeCheckpointRecord($0, zoneID: zoneID) }
        for chunk in records.chunked(into: 200) {
            _ = try await database.modifyRecords(
                saving: chunk, deleting: [], savePolicy: .allKeys)
        }
    }

    nonisolated static func fetchCheckpointTombstones() async throws
        -> [CheckpointTombstone]
    {
        guard try await CKContainer.default().accountStatus() == .available
        else { throw SyncIssue.noICloudAccount }
        let zoneID = try await ensureZone()
        return try await fetchAll(
            ofType: checkpointTombstoneRecordType, zoneID: zoneID)
            .compactMap(decodeCheckpointTombstone(from:))
    }

    nonisolated static func pushCheckpointTombstones(
        _ rows: [CheckpointTombstone]
    ) async throws {
        guard !rows.isEmpty else { return }
        guard try await CKContainer.default().accountStatus() == .available
        else { throw SyncIssue.noICloudAccount }
        let zoneID = try await ensureZone()
        let records = rows.map {
            makeCheckpointTombstoneRecord($0, zoneID: zoneID)
        }
        for chunk in records.chunked(into: 200) {
            _ = try await database.modifyRecords(
                saving: chunk, deleting: [], savePolicy: .allKeys)
        }
    }

    /// Deletes records by id. Ids the server no longer holds are not a
    /// failure; everything else throws.
    nonisolated static func deleteRecords(
        _ ids: [CKRecord.ID], in zoneID: CKRecordZone.ID
    ) async throws {
        guard !ids.isEmpty else { return }
        guard try await CKContainer.default().accountStatus() == .available
        else { throw SyncIssue.noICloudAccount }
        for chunk in ids.chunked(into: 200) {
            let result = try await database.modifyRecords(
                saving: [], deleting: chunk, savePolicy: .allKeys)
            for (_, deleteResult) in result.deleteResults {
                if case .failure(let error) = deleteResult,
                   (error as? CKError)?.code != .unknownItem {
                    throw error
                }
            }
        }
    }

    nonisolated static func fetchListenState() async throws -> [ListenStateRow]
    {
        guard try await CKContainer.default().accountStatus() == .available
        else { throw SyncIssue.noICloudAccount }
        let zoneID = try await ensureZone()
        return try await fetchAll(ofType: listenRecordType, zoneID: zoneID)
            .compactMap(decodeListenState(from:))
    }

    nonisolated static func pushListenState(_ rows: [ListenStateRow])
        async throws
    {
        guard !rows.isEmpty else { return }
        guard try await CKContainer.default().accountStatus() == .available
        else { throw SyncIssue.noICloudAccount }
        let zoneID = try await ensureZone()
        let records = rows.map { makeListenStateRecord($0, zoneID: zoneID) }
        for chunk in records.chunked(into: 200) {
            _ = try await database.modifyRecords(
                saving: chunk, deleting: [], savePolicy: .allKeys)
        }
    }

    nonisolated static func fetchSavedPhrases() async throws -> [SavedPhrase]
    {
        guard try await CKContainer.default().accountStatus() == .available
        else { throw SyncIssue.noICloudAccount }
        let zoneID = try await ensureZone()
        return try await fetchAll(ofType: savedPhraseRecordType, zoneID: zoneID)
            .compactMap(decodeSavedPhrase(from:))
    }

    nonisolated static func pushSavedPhrases(_ phrases: [SavedPhrase])
        async throws
    {
        guard !phrases.isEmpty else { return }
        guard try await CKContainer.default().accountStatus() == .available
        else { throw SyncIssue.noICloudAccount }
        let zoneID = try await ensureZone()
        let records = phrases.map { makeSavedPhraseRecord($0, zoneID: zoneID) }
        for chunk in records.chunked(into: 200) {
            _ = try await database.modifyRecords(
                saving: chunk, deleting: [], savePolicy: .allKeys)
        }
    }

    nonisolated static func fetchSavedPhraseTombstones() async throws
        -> [SavedPhraseTombstone]
    {
        guard try await CKContainer.default().accountStatus() == .available
        else { throw SyncIssue.noICloudAccount }
        let zoneID = try await ensureZone()
        return try await fetchAll(
            ofType: savedPhraseTombstoneRecordType, zoneID: zoneID)
            .compactMap(decodeSavedPhraseTombstone(from:))
    }

    nonisolated static func pushSavedPhraseTombstones(
        _ rows: [SavedPhraseTombstone]
    ) async throws {
        guard !rows.isEmpty else { return }
        guard try await CKContainer.default().accountStatus() == .available
        else { throw SyncIssue.noICloudAccount }
        let zoneID = try await ensureZone()
        let records = rows.map {
            makeSavedPhraseTombstoneRecord($0, zoneID: zoneID)
        }
        for chunk in records.chunked(into: 200) {
            _ = try await database.modifyRecords(
                saving: chunk, deleting: [], savePolicy: .allKeys)
        }
    }

    /// The private sync zone, created on first use.
    nonisolated static func ensureZone() async throws -> CKRecordZone.ID {
        let zoneID = CKRecordZone.ID(
            zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        do {
            _ = try await database.recordZone(for: zoneID)
            return zoneID
        } catch {
            let zone = try await database.save(
                CKRecordZone(zoneName: zoneName))
            return zone.zoneID
        }
    }

    nonisolated static func makeRecord(
        for event: LearningEvent, zoneID: CKRecordZone.ID
    ) throws -> CKRecord {
        let recordID = CKRecord.ID(
            recordName: "evt-\(event.id)", zoneID: zoneID)
        let record = CKRecord(recordType: recordType, recordID: recordID)
        let payloadData = try JSONEncoder().encode(event)
        guard let payload = String(data: payloadData, encoding: .utf8) else {
            throw SyncIssue.cloudKit(
                NSError(
                    domain: "CondiscoSync", code: -1,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Could not encode event \(event.id)."
                    ]))
        }
        record["eventId"] = event.id as CKRecordValue
        record["packId"] = event.packId as CKRecordValue
        record["kind"] = event.kindString as CKRecordValue
        record["at"] = event.at as CKRecordValue
        record["payload"] = payload as CKRecordValue
        return record
    }

    nonisolated static func decodeEvent(from record: CKRecord) -> LearningEvent?
    {
        guard let payload = record["payload"] as? String,
              let data = payload.data(using: .utf8),
              let event = try? JSONDecoder().decode(
                LearningEvent.self, from: data)
        else { return nil }
        return event
    }

    nonisolated static func makeCheckpointRecord(
        _ row: StoredCheckpoint, zoneID: CKRecordZone.ID
    ) -> CKRecord {
        let recordID = CKRecord.ID(
            recordName: "ckpt-\(row.packId)-\(row.lessonId)", zoneID: zoneID)
        let record = CKRecord(
            recordType: checkpointRecordType, recordID: recordID)
        record["packId"] = row.packId as CKRecordValue
        record["lessonId"] = row.lessonId as CKRecordValue
        record["payload"] = row.payload as CKRecordValue
        record["updatedAt"] = dateFromMillis(row.updatedAtMs) as CKRecordValue
        return record
    }

    nonisolated static func decodeCheckpoint(from record: CKRecord)
        -> StoredCheckpoint?
    {
        guard let packId = record["packId"] as? String,
              let lessonId = record["lessonId"] as? String,
              let payload = record["payload"] as? String,
              let updatedAt = record["updatedAt"] as? Date
        else { return nil }
        return StoredCheckpoint(
            packId: packId, lessonId: lessonId, payload: payload,
            updatedAtMs: millisFromDate(updatedAt))
    }

    nonisolated static func makeCheckpointTombstoneRecord(
        _ tombstone: CheckpointTombstone, zoneID: CKRecordZone.ID
    ) -> CKRecord {
        let recordID = CKRecord.ID(
            recordName: "ckpt-tomb-\(tombstone.packId)-\(tombstone.lessonId)",
            zoneID: zoneID)
        let record = CKRecord(
            recordType: checkpointTombstoneRecordType, recordID: recordID)
        record["packId"] = tombstone.packId as CKRecordValue
        record["lessonId"] = tombstone.lessonId as CKRecordValue
        record["deletedAt"] = dateFromMillis(
            tombstone.deletedAtMs) as CKRecordValue
        return record
    }

    nonisolated static func decodeCheckpointTombstone(from record: CKRecord)
        -> CheckpointTombstone?
    {
        guard let packId = record["packId"] as? String,
              let lessonId = record["lessonId"] as? String,
              let deletedAt = record["deletedAt"] as? Date
        else { return nil }
        return CheckpointTombstone(
            packId: packId, lessonId: lessonId,
            deletedAtMs: millisFromDate(deletedAt))
    }

    nonisolated static func makeListenStateRecord(
        _ row: ListenStateRow, zoneID: CKRecordZone.ID
    ) -> CKRecord {
        let recordID = CKRecord.ID(
            recordName: "listen-\(row.trackId)", zoneID: zoneID)
        let record = CKRecord(
            recordType: listenRecordType, recordID: recordID)
        record["trackId"] = row.trackId as CKRecordValue
        record["positionSeconds"] = row.positionSeconds as CKRecordValue
        if let listenedAtMs = row.listenedAtMs {
            record["listenedAt"] = dateFromMillis(listenedAtMs) as CKRecordValue
        }
        record["updatedAt"] = dateFromMillis(row.updatedAtMs) as CKRecordValue
        return record
    }

    nonisolated static func decodeListenState(from record: CKRecord)
        -> ListenStateRow?
    {
        guard let trackId = record["trackId"] as? String,
              let positionSeconds = record["positionSeconds"] as? Double,
              let updatedAt = record["updatedAt"] as? Date
        else { return nil }
        let listenedAtMs = (record["listenedAt"] as? Date)
            .map(millisFromDate)
        return ListenStateRow(
            trackId: trackId, positionSeconds: positionSeconds,
            listenedAtMs: listenedAtMs, updatedAtMs: millisFromDate(updatedAt))
    }

    /// Deterministic, CloudKit-safe record name for a phrase id. The id
    /// itself (language|target|meaning) can hold anything, so it travels
    /// in fields and the name carries its SHA-256 instead.
    nonisolated static func savedPhraseRecordName(for id: String) -> String {
        let digest = SHA256.hash(data: Data(id.utf8))
        return "phrase-" + digest.map { String(format: "%02x", $0) }.joined()
    }

    nonisolated static func savedPhraseTombstoneRecordName(for id: String) -> String {
        "tomb-" + savedPhraseRecordName(for: id)
    }

    nonisolated static func makeSavedPhraseRecord(
        _ phrase: SavedPhrase, zoneID: CKRecordZone.ID
    ) -> CKRecord {
        let recordID = CKRecord.ID(
            recordName: savedPhraseRecordName(for: phrase.id), zoneID: zoneID)
        let record = CKRecord(
            recordType: savedPhraseRecordType, recordID: recordID)
        record["languageSlug"] = phrase.languageSlug as CKRecordValue
        record["languageName"] = phrase.languageName as CKRecordValue
        record["target"] = phrase.target as CKRecordValue
        record["meaning"] = phrase.meaning as CKRecordValue
        record["source"] = phrase.source as CKRecordValue
        record["sourcePackId"] = phrase.sourcePackId as CKRecordValue
        record["sourceLessonId"] = phrase.sourceLessonId as CKRecordValue
        record["savedAt"] = phrase.savedAt as CKRecordValue
        return record
    }

    nonisolated static func decodeSavedPhrase(from record: CKRecord)
        -> SavedPhrase?
    {
        guard let languageSlug = record["languageSlug"] as? String,
              let languageName = record["languageName"] as? String,
              let target = record["target"] as? String,
              let meaning = record["meaning"] as? String,
              let savedAt = record["savedAt"] as? Date
        else { return nil }
        return SavedPhrase(
            id: LearningStore.savedPhraseId(
                languageSlug: languageSlug, target: target, meaning: meaning),
            languageSlug: languageSlug,
            languageName: languageName,
            target: target,
            meaning: meaning,
            source: record["source"] as? String ?? "",
            // Records written before deep-link ids existed simply lack
            // these fields.
            sourcePackId: record["sourcePackId"] as? String ?? "",
            sourceLessonId: record["sourceLessonId"] as? String ?? "",
            savedAt: savedAt)
    }

    nonisolated static func makeSavedPhraseTombstoneRecord(
        _ tombstone: SavedPhraseTombstone, zoneID: CKRecordZone.ID
    ) -> CKRecord {
        let recordID = CKRecord.ID(
            recordName: savedPhraseTombstoneRecordName(for: tombstone.id),
            zoneID: zoneID)
        let record = CKRecord(
            recordType: savedPhraseTombstoneRecordType, recordID: recordID)
        record["phraseId"] = tombstone.id as CKRecordValue
        record["deletedAt"] = dateFromMillis(
            tombstone.deletedAtMs) as CKRecordValue
        return record
    }

    nonisolated static func decodeSavedPhraseTombstone(from record: CKRecord)
        -> SavedPhraseTombstone?
    {
        guard let id = record["phraseId"] as? String,
              let deletedAt = record["deletedAt"] as? Date
        else { return nil }
        return SavedPhraseTombstone(
            id: id, deletedAtMs: millisFromDate(deletedAt))
    }

    nonisolated static func dateFromMillis(_ millis: Int64) -> Date {
        Date(timeIntervalSince1970: Double(millis) / 1000)
    }

    nonisolated static func millisFromDate(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1000).rounded())
    }
}

// MARK: - Chunking

extension Array {
    fileprivate func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        var out: [[Element]] = []
        var index = startIndex
        while index < endIndex {
            let end = self.index(
                index, offsetBy: size, limitedBy: endIndex) ?? endIndex
            out.append(Array(self[index..<end]))
            index = end
        }
        return out
    }
}
