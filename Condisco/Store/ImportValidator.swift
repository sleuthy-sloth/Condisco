import Foundation

// MARK: - Import validation (Slice 1.2: safe local restore)
//
// Pure, side-effect-free validation of an export file BEFORE anything is
// written to the store. The exported file is untrusted input: it may be
// truncated, hand-edited, from a different (newer or older) build, or not
// a Condisco export at all. Every check runs on the `Data` alone — no
// store, no UserDefaults, no file I/O — so a failed validation can
// guarantee zero writes by construction: the caller has nothing to write.
//
// The result is an `ImportPreview`: the fully decoded contents plus the
// counts and `exportedAt` the restore UI shows before asking for explicit
// confirmation.

/// The fully validated contents of an export file, ready to preview and —
/// only after explicit confirmation — to merge into the store.
struct ImportPreview: Identifiable {
    var app: String
    /// The export format version. `nil` for legacy (pre-1.1) exports,
    /// which predate the `formatVersion` field entirely.
    var formatVersion: Int?
    /// True when the file is a pre-1.1 export (no `formatVersion`).
    var isLegacy: Bool { formatVersion == nil }
    /// When the export was produced. `nil` for a legacy file that did not
    /// carry a date.
    var exportedAt: Date?
    var events: [LearningEvent]
    var checkpoints: [StoredCheckpoint]
    var checkpointTombstones: [CheckpointTombstone]
    var savedPhrases: [StoredSavedPhrase]
    var savedPhraseTombstones: [SavedPhraseTombstone]
    var listenState: [ListenStateRow]
    var placement: [ExportedPlacement]

    var id: String { UUID().uuidString }
}

/// Why an export file was rejected. Messages are written plainly so they
/// can be shown to the learner as-is.
enum ImportValidationError: Error, CustomStringConvertible, Equatable {
    /// File bytes exceed the hard cap.
    case tooLarge(actualBytes: Int, limitBytes: Int)
    /// The data is not decodable JSON at all (truncated, binary, garbage).
    case invalidJSON(detail: String)
    /// The file declares a producer other than "Condisco".
    case wrongApp(String)
    /// A `formatVersion` this build cannot read.
    case unsupportedFormatVersion(Int)
    /// Decoded as JSON but not a well-formed Condisco export for its
    /// declared format.
    case malformedDocument(detail: String)
    /// The export lists the same event id more than once.
    case duplicateEventID(String)
    /// An event that fails validation (e.g. an empty id).
    case invalidEvent(detail: String)
    /// A step completion names an attempt id the export does not contain,
    /// or that does not match the completion's lesson/step.
    case danglingStepCompletion(String)
    /// A checkpoint payload is not a readable LessonCheckpoint, or its
    /// payload disagrees with the row's pack/lesson ids.
    case invalidCheckpoint(packId: String, lessonId: String)
    /// A listen position is not a finite, non-negative number.
    case invalidListenPosition(trackId: String, position: Double)

    var description: String {
        switch self {
        case .tooLarge:
            return "This file is too large to restore (the limit is 50 MB)."
        case .invalidJSON(let detail):
            return "This file could not be read as a Condisco export. \(detail)"
        case .wrongApp(let found):
            let marker = found.isEmpty ? "(missing)" : "\"\(found)\""
            return "This file was not made by Condisco (its app marker is \(marker)). Nothing was imported."
        case .unsupportedFormatVersion(let version):
            return "This export uses format version \(version), which this build cannot read. Nothing was imported."
        case .malformedDocument(let detail):
            return "This file is not a valid Condisco export. \(detail) Nothing was imported."
        case .duplicateEventID(let id):
            return "This export lists the learning event \(id) more than once. Nothing was imported."
        case .invalidEvent(let detail):
            return "This export contains an invalid learning event. \(detail) Nothing was imported."
        case .danglingStepCompletion(let id):
            return "Step completion \(id) refers to an attempt this export does not contain. Nothing was imported."
        case .invalidCheckpoint(let packId, let lessonId):
            return "A checkpoint in \(packId)/\(lessonId) could not be read. Nothing was imported."
        case .invalidListenPosition(let trackId, let position):
            return "The listen position for \(trackId) is not a valid number (\(position)). Nothing was imported."
        }
    }
}

enum ImportValidator {
    /// Hard cap on import file size. Exports are plain JSON learning
    /// history; 50 MB is far beyond even a multi-year log while staying
    /// comfortably below the point where parsing a hostile file becomes a
    /// memory or battery risk. Named and pinned so the bound is auditable.
    static let maxImportSizeBytes = 50 * 1024 * 1024

    /// The export-format version this build can read (see
    /// `DataExport.formatVersion`).
    static let supportedFormatVersion = 1

    /// The app marker every export carries. Files without it are not
    /// Condisco exports.
    static let appMarker = "Condisco"

    /// Validates export file contents.
    ///
    /// - Returns: `.success(preview)` with the decoded, internally
    ///   consistent contents, or `.failure` naming the first problem.
    ///   On failure nothing has been written — this function has no side
    ///   effects at all.
    static func validate(_ data: Data) -> Result<ImportPreview, ImportValidationError> {
        // 1. Size cap before any parsing.
        guard data.count <= maxImportSizeBytes else {
            return .failure(.tooLarge(
                actualBytes: data.count, limitBytes: maxImportSizeBytes))
        }

        // 2. Must be a JSON object.
        let json: Any
        do {
            json = try JSONSerialization.jsonObject(with: data)
        } catch {
            return .failure(.invalidJSON(detail: error.localizedDescription))
        }
        guard let object = json as? [String: Any] else {
            return .failure(.invalidJSON(
                detail: "The top level of the file is not a JSON object."))
        }

        // 3. App marker.
        guard let app = object["app"] as? String, app == appMarker else {
            return .failure(.wrongApp((object["app"] as? String) ?? ""))
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let preview: ImportPreview
        if let version = object["formatVersion"] as? Int {
            // A versioned, modern export.
            guard version == supportedFormatVersion else {
                return .failure(.unsupportedFormatVersion(version))
            }
            do {
                let document = try decoder.decode(
                    ExportedLearningData.self, from: data)
                preview = ImportPreview(
                    app: document.app,
                    formatVersion: document.formatVersion,
                    exportedAt: document.exportedAt,
                    events: document.events,
                    checkpoints: document.checkpoints,
                    checkpointTombstones: document.checkpointTombstones,
                    savedPhrases: document.savedPhrases,
                    savedPhraseTombstones: document.savedPhraseTombstones,
                    listenState: document.listenState,
                    placement: document.placement)
            } catch {
                return .failure(.malformedDocument(
                    detail: "The export data could not be decoded (\(error.localizedDescription))."))
            }
        } else if object["formatVersion"] != nil {
            // Present but not an integer → malformed, not legacy.
            return .failure(.malformedDocument(
                detail: "The field \"formatVersion\" is not an integer."))
        } else {
            // Legacy (pre-1.1) export: the app marker existed but
            // `formatVersion` did not, and the file carried only
            // events/checkpoints/listenState (saved phrases, tombstones,
            // and placement are 1.1 additions). The legacy decoder is
            // deliberately lenient: those three arrays are optional and
            // everything else is ignored, so a genuine pre-1.1 file
            // restores without pretending to understand fields that did
            // not exist yet. The row shapes for the three arrays are
            // identical to today's, so the decode below is faithful.
            do {
                let legacy = try decoder.decode(LegacyExport.self, from: data)
                preview = ImportPreview(
                    app: legacy.app,
                    formatVersion: nil,
                    exportedAt: legacy.exportedAt,
                    events: legacy.events ?? [],
                    checkpoints: legacy.checkpoints ?? [],
                    checkpointTombstones: [],
                    savedPhrases: [],
                    savedPhraseTombstones: [],
                    listenState: legacy.listenState ?? [],
                    placement: [])
            } catch {
                return .failure(.malformedDocument(
                    detail: "The file does not look like a Condisco export from any version (\(error.localizedDescription))."))
            }
        }

        // 4. Content checks on the decoded payloads.
        return Self.validateContent(preview).map { preview }
    }

    // MARK: - Content checks

    /// Validates the *decoded* contents: id uniqueness, internally
    /// consistent references, and finite listen positions.
    ///
    /// Deliberately NOT checked: whether a pack/lesson/activity exists in
    /// the current bundle. Well-formed historical events for courses that
    /// are no longer bundled are learner-owned history and must be
    /// retained — the projection layer already quarantines (never
    /// rejects) references the current catalog does not know.
    private static func validateContent(
        _ preview: ImportPreview
    ) -> Result<Void, ImportValidationError> {
        var seenIDs: Set<String> = []
        for event in preview.events {
            guard !event.id.isEmpty else {
                return .failure(.invalidEvent(detail: "An event has an empty id."))
            }
            guard seenIDs.insert(event.id).inserted else {
                return .failure(.duplicateEventID(event.id))
            }
        }

        // Internally consistent references: a step completion that names
        // an attempt must reference one inside this export, matching the
        // same lesson and step. (Payload validity itself is guaranteed by
        // decode — `LearningEvent` rejects unknown types/versions.)
        var attemptsByID: [String: ActivityAttempt] = [:]
        for event in preview.events {
            if case .attempt(let attempt) = event {
                attemptsByID[attempt.id] = attempt
            }
        }
        for event in preview.events {
            guard case .stepCompleted(let completion) = event,
                  let attemptID = completion.attemptId
            else { continue }
            guard let attempt = attemptsByID[attemptID],
                  attempt.lessonId == completion.lessonId,
                  attempt.stepId == completion.stepId
            else {
                return .failure(.danglingStepCompletion(completion.id))
            }
        }

        // Checkpoints must carry a payload that decodes as the lesson
        // checkpoint it claims to be, with matching ids.
        let checkpointDecoder = JSONDecoder()
        for row in preview.checkpoints {
            guard let payloadData = row.payload.data(using: .utf8),
                  let checkpoint = try? checkpointDecoder.decode(
                      LessonCheckpoint.self, from: payloadData),
                  checkpoint.packId == row.packId,
                  checkpoint.lessonId == row.lessonId
            else {
                return .failure(.invalidCheckpoint(
                    packId: row.packId, lessonId: row.lessonId))
            }
        }

        // Listen positions must be finite and non-negative. (Strict JSON
        // cannot literally carry NaN or Infinity — JSONSerialization and
        // JSONDecoder both reject them — but a negative or non-numeric
        // position is real corrupted input, and the finite check keeps a
        // future permissive decoder from ever writing a NaN into SQLite.)
        for row in preview.listenState {
            guard row.positionSeconds.isFinite, row.positionSeconds >= 0 else {
                return .failure(.invalidListenPosition(
                    trackId: row.trackId, position: row.positionSeconds))
            }
        }

        return .success(())
    }
}

// MARK: - Legacy (pre-1.1) export shape

/// The pre-1.1 export: app marker, optional export date, and only the
/// three sections that existed then (events/checkpoints/listenState).
private struct LegacyExport: Decodable {
    var app: String
    var exportedAt: Date?
    var events: [LearningEvent]?
    var checkpoints: [StoredCheckpoint]?
    var listenState: [ListenStateRow]?
}