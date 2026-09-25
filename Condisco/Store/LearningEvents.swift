import Foundation

// MARK: - ISO 8601 dates

/// The web app serializes every timestamp with `toISOString()`.
/// This matches that format: UTC, fractional seconds when present.
enum ISO8601 {
    static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let plainFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }

    static func date(from string: String) -> Date? {
        if let d = formatter.date(from: string) { return d }
        return plainFormatter.date(from: string)
    }
}

// MARK: - Attempt response

struct ResponsePair: Codable, Equatable {
    var leftId: String
    var rightId: String
}

/// The learner's answer on an attempt. `kind` discriminates, mirroring the
/// zod `responseSchema` in the web app. Unrecognized kinds are rejected.
enum AttemptResponse: Codable, Equatable {
    case text(String)
    case selection(ids: [String])
    case ordering(ids: [String])
    case matching(pairs: [ResponsePair])
    case cloze(values: [String: String])
    case selfRating(SelfRating)
    case `continue`

    enum SelfRating: String, Codable {
        case again, comfortable, hard, good, easy
    }

    private enum CodingKeys: String, CodingKey {
        case kind, text, ids, pairs, values, rating
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        switch kind {
        case "text":
            self = .text(try container.decode(String.self, forKey: .text))
        case "selection":
            self = .selection(ids: try container.decode([String].self, forKey: .ids))
        case "ordering":
            self = .ordering(ids: try container.decode([String].self, forKey: .ids))
        case "matching":
            self = .matching(pairs: try container.decode([ResponsePair].self, forKey: .pairs))
        case "cloze":
            self = .cloze(values: try container.decode([String: String].self, forKey: .values))
        case "self":
            self = .selfRating(try container.decode(SelfRating.self, forKey: .rating))
        case "continue":
            self = .continue
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind, in: container,
                debugDescription: "unknown response kind \(kind)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .kind)
            try container.encode(text, forKey: .text)
        case .selection(let ids):
            try container.encode("selection", forKey: .kind)
            try container.encode(ids, forKey: .ids)
        case .ordering(let ids):
            try container.encode("ordering", forKey: .kind)
            try container.encode(ids, forKey: .ids)
        case .matching(let pairs):
            try container.encode("matching", forKey: .kind)
            try container.encode(pairs, forKey: .pairs)
        case .cloze(let values):
            try container.encode("cloze", forKey: .kind)
            try container.encode(values, forKey: .values)
        case .selfRating(let rating):
            try container.encode("self", forKey: .kind)
            try container.encode(rating, forKey: .rating)
        case .continue:
            try container.encode("continue", forKey: .kind)
        }
    }
}

// MARK: - Evaluation

/// The recorded grading of an attempt. The lesson engine evaluates *before*
/// recording, so stored evaluations are already consistent; the store trusts
/// them the way the web projection trusts re-evaluation.
struct AttemptEvaluation: Codable, Equatable {
    enum Outcome: String, Codable {
        case correct, incorrect
        case selfAssessed = "self-assessed"
        case ungraded, blocked
    }

    var outcome: Outcome
    /// True only when no assistance tainted the attempt.
    var independent: Bool
    var feedback: String
    /// Specific model or correction shown after checking an answer.
    var correction: String? = nil
}

// MARK: - v1 practice event (pre-v2 format, kept for migration)

struct PracticeEventV1: Codable, Equatable {
    var id: String
    var packId: String
    var version: String
    var exerciseId: String
    var at: Date
    var correct: Bool
    var revealed: Bool

    private enum CodingKeys: String, CodingKey {
        case id, packId, version, exerciseId, at, correct, revealed
    }

    init(id: String, packId: String, version: String, exerciseId: String,
         at: Date, correct: Bool, revealed: Bool) {
        self.id = id
        self.packId = packId
        self.version = version
        self.exerciseId = exerciseId
        self.at = at
        self.correct = correct
        self.revealed = revealed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        packId = try container.decode(String.self, forKey: .packId)
        version = try container.decode(String.self, forKey: .version)
        exerciseId = try container.decode(String.self, forKey: .exerciseId)
        correct = try container.decode(Bool.self, forKey: .correct)
        revealed = try container.decode(Bool.self, forKey: .revealed)
        let atString = try container.decode(String.self, forKey: .at)
        guard let date = ISO8601.date(from: atString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .at, in: container,
                debugDescription: "invalid ISO 8601 date \(atString)")
        }
        at = date
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(packId, forKey: .packId)
        try container.encode(version, forKey: .version)
        try container.encode(exerciseId, forKey: .exerciseId)
        try container.encode(ISO8601.string(from: at), forKey: .at)
        try container.encode(correct, forKey: .correct)
        try container.encode(revealed, forKey: .revealed)
    }
}

// MARK: - v2 activity attempt

struct ActivityAttempt: Codable, Equatable {
    var eventVersion: Int = 2
    /// Serialized as "type".
    var eventType: String = "attempt"
    var id: String
    var packId: String
    var packVersion: String
    var lessonId: String
    var lessonRevision: Int
    var stepId: String
    var activityId: String
    var activityRevision: Int
    var evidenceKey: String?
    var response: AttemptResponse
    var assistance: [AssistanceKind]
    var evaluation: AttemptEvaluation
    var at: Date

    private enum CodingKeys: String, CodingKey {
        case eventVersion
        case eventType = "type"
        case id, packId, packVersion, lessonId, lessonRevision, stepId
        case activityId, activityRevision, evidenceKey, response, assistance
        case evaluation, at
    }

    init(id: String, packId: String, packVersion: String, lessonId: String,
         lessonRevision: Int, stepId: String, activityId: String,
         activityRevision: Int, evidenceKey: String?, response: AttemptResponse,
         assistance: [AssistanceKind], evaluation: AttemptEvaluation, at: Date) {
        self.id = id
        self.packId = packId
        self.packVersion = packVersion
        self.lessonId = lessonId
        self.lessonRevision = lessonRevision
        self.stepId = stepId
        self.activityId = activityId
        self.activityRevision = activityRevision
        self.evidenceKey = evidenceKey
        self.response = response
        self.assistance = assistance
        self.evaluation = evaluation
        self.at = at
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        eventVersion = try container.decode(Int.self, forKey: .eventVersion)
        guard eventVersion == 2 else {
            throw DecodingError.dataCorruptedError(
                forKey: .eventVersion, in: container,
                debugDescription: "unsupported event version \(eventVersion)")
        }
        eventType = try container.decode(String.self, forKey: .eventType)
        id = try container.decode(String.self, forKey: .id)
        packId = try container.decode(String.self, forKey: .packId)
        packVersion = try container.decode(String.self, forKey: .packVersion)
        lessonId = try container.decode(String.self, forKey: .lessonId)
        lessonRevision = try container.decode(Int.self, forKey: .lessonRevision)
        stepId = try container.decode(String.self, forKey: .stepId)
        activityId = try container.decode(String.self, forKey: .activityId)
        activityRevision = try container.decode(Int.self, forKey: .activityRevision)
        evidenceKey = try container.decodeIfPresent(String.self, forKey: .evidenceKey)
        response = try container.decode(AttemptResponse.self, forKey: .response)
        assistance = try container.decode([AssistanceKind].self, forKey: .assistance)
        evaluation = try container.decode(AttemptEvaluation.self, forKey: .evaluation)
        let atString = try container.decode(String.self, forKey: .at)
        guard let date = ISO8601.date(from: atString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .at, in: container,
                debugDescription: "invalid ISO 8601 date \(atString)")
        }
        at = date
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(eventVersion, forKey: .eventVersion)
        try container.encode(eventType, forKey: .eventType)
        try container.encode(id, forKey: .id)
        try container.encode(packId, forKey: .packId)
        try container.encode(packVersion, forKey: .packVersion)
        try container.encode(lessonId, forKey: .lessonId)
        try container.encode(lessonRevision, forKey: .lessonRevision)
        try container.encode(stepId, forKey: .stepId)
        try container.encode(activityId, forKey: .activityId)
        try container.encode(activityRevision, forKey: .activityRevision)
        try container.encodeIfPresent(evidenceKey, forKey: .evidenceKey)
        try container.encode(response, forKey: .response)
        try container.encode(assistance, forKey: .assistance)
        try container.encode(evaluation, forKey: .evaluation)
        try container.encode(ISO8601.string(from: at), forKey: .at)
    }
}

// MARK: - v2 step completion

struct StepCompletion: Codable, Equatable {
    var eventVersion: Int = 2
    /// Serialized as "type".
    var eventType: String = "step-completed"
    var id: String
    var packId: String
    var packVersion: String
    var lessonId: String
    var lessonRevision: Int
    var stepId: String
    var selectedBranchId: String?
    var attemptId: String?
    var at: Date

    private enum CodingKeys: String, CodingKey {
        case eventVersion
        case eventType = "type"
        case id, packId, packVersion, lessonId, lessonRevision, stepId
        case selectedBranchId, attemptId, at
    }

    init(id: String, packId: String, packVersion: String, lessonId: String,
         lessonRevision: Int, stepId: String, selectedBranchId: String?,
         attemptId: String?, at: Date) {
        self.id = id
        self.packId = packId
        self.packVersion = packVersion
        self.lessonId = lessonId
        self.lessonRevision = lessonRevision
        self.stepId = stepId
        self.selectedBranchId = selectedBranchId
        self.attemptId = attemptId
        self.at = at
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        eventVersion = try container.decode(Int.self, forKey: .eventVersion)
        guard eventVersion == 2 else {
            throw DecodingError.dataCorruptedError(
                forKey: .eventVersion, in: container,
                debugDescription: "unsupported event version \(eventVersion)")
        }
        eventType = try container.decode(String.self, forKey: .eventType)
        id = try container.decode(String.self, forKey: .id)
        packId = try container.decode(String.self, forKey: .packId)
        packVersion = try container.decode(String.self, forKey: .packVersion)
        lessonId = try container.decode(String.self, forKey: .lessonId)
        lessonRevision = try container.decode(Int.self, forKey: .lessonRevision)
        stepId = try container.decode(String.self, forKey: .stepId)
        selectedBranchId = try container.decodeIfPresent(String.self, forKey: .selectedBranchId)
        attemptId = try container.decodeIfPresent(String.self, forKey: .attemptId)
        let atString = try container.decode(String.self, forKey: .at)
        guard let date = ISO8601.date(from: atString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .at, in: container,
                debugDescription: "invalid ISO 8601 date \(atString)")
        }
        at = date
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(eventVersion, forKey: .eventVersion)
        try container.encode(eventType, forKey: .eventType)
        try container.encode(id, forKey: .id)
        try container.encode(packId, forKey: .packId)
        try container.encode(packVersion, forKey: .packVersion)
        try container.encode(lessonId, forKey: .lessonId)
        try container.encode(lessonRevision, forKey: .lessonRevision)
        try container.encode(stepId, forKey: .stepId)
        try container.encodeIfPresent(selectedBranchId, forKey: .selectedBranchId)
        try container.encodeIfPresent(attemptId, forKey: .attemptId)
        try container.encode(ISO8601.string(from: at), forKey: .at)
    }
}

// MARK: - v2 lesson known mark ("I know this")

/// A manual "I know this" mark on a whole lesson, or its removal.
/// Unlike attempts and step completions it carries no evidence and never
/// feeds SRS; projection treats the latest mark per lesson as completion
/// credit. `known == false` removes a previous mark — event-sourced, so
/// undo needs no tombstones and syncs as an ordinary event.
struct LessonKnownEvent: Codable, Equatable {
    var eventVersion: Int = 2
    /// Serialized as "type".
    var eventType: String = "lesson-known"
    var id: String
    var packId: String
    var packVersion: String
    var lessonId: String
    var lessonRevision: Int
    var known: Bool
    var at: Date

    private enum CodingKeys: String, CodingKey {
        case eventVersion
        case eventType = "type"
        case id, packId, packVersion, lessonId, lessonRevision, known, at
    }

    init(id: String, packId: String, packVersion: String, lessonId: String,
         lessonRevision: Int, known: Bool, at: Date) {
        self.id = id
        self.packId = packId
        self.packVersion = packVersion
        self.lessonId = lessonId
        self.lessonRevision = lessonRevision
        self.known = known
        self.at = at
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        eventVersion = try container.decode(Int.self, forKey: .eventVersion)
        guard eventVersion == 2 else {
            throw DecodingError.dataCorruptedError(
                forKey: .eventVersion, in: container,
                debugDescription: "unsupported event version \(eventVersion)")
        }
        eventType = try container.decode(String.self, forKey: .eventType)
        id = try container.decode(String.self, forKey: .id)
        packId = try container.decode(String.self, forKey: .packId)
        packVersion = try container.decode(String.self, forKey: .packVersion)
        lessonId = try container.decode(String.self, forKey: .lessonId)
        lessonRevision = try container.decode(Int.self, forKey: .lessonRevision)
        known = try container.decode(Bool.self, forKey: .known)
        let atString = try container.decode(String.self, forKey: .at)
        guard let date = ISO8601.date(from: atString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .at, in: container,
                debugDescription: "invalid ISO 8601 date \(atString)")
        }
        at = date
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(eventVersion, forKey: .eventVersion)
        try container.encode(eventType, forKey: .eventType)
        try container.encode(id, forKey: .id)
        try container.encode(packId, forKey: .packId)
        try container.encode(packVersion, forKey: .packVersion)
        try container.encode(lessonId, forKey: .lessonId)
        try container.encode(lessonRevision, forKey: .lessonRevision)
        try container.encode(known, forKey: .known)
        try container.encode(ISO8601.string(from: at), forKey: .at)
    }
}

// MARK: - Lesson checkpoint (resume state)

/// Saved when the learner leaves a lesson mid-step. Mirrors
/// `lessonCheckpointSchema` in the web app.
struct LessonCheckpoint: Codable, Equatable {
    var packId: String
    var lessonId: String
    var revision: Int
    var stepId: String
    var selectedBranches: [String: String]
    var assistance: [AssistanceKind]
    var draft: AttemptResponse?
    var at: Date

    private enum CodingKeys: String, CodingKey {
        case packId, lessonId, revision, stepId, selectedBranches, assistance, draft, at
    }

    init(packId: String, lessonId: String, revision: Int, stepId: String,
         selectedBranches: [String: String], assistance: [AssistanceKind],
         draft: AttemptResponse?, at: Date) {
        self.packId = packId
        self.lessonId = lessonId
        self.revision = revision
        self.stepId = stepId
        self.selectedBranches = selectedBranches
        self.assistance = assistance
        self.draft = draft
        self.at = at
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        packId = try container.decode(String.self, forKey: .packId)
        lessonId = try container.decode(String.self, forKey: .lessonId)
        revision = try container.decode(Int.self, forKey: .revision)
        stepId = try container.decode(String.self, forKey: .stepId)
        selectedBranches = try container.decode([String: String].self, forKey: .selectedBranches)
        assistance = try container.decode([AssistanceKind].self, forKey: .assistance)
        draft = try container.decodeIfPresent(AttemptResponse.self, forKey: .draft)
        let atString = try container.decode(String.self, forKey: .at)
        guard let date = ISO8601.date(from: atString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .at, in: container,
                debugDescription: "invalid ISO 8601 date \(atString)")
        }
        at = date
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(packId, forKey: .packId)
        try container.encode(lessonId, forKey: .lessonId)
        try container.encode(revision, forKey: .revision)
        try container.encode(stepId, forKey: .stepId)
        try container.encode(selectedBranches, forKey: .selectedBranches)
        try container.encode(assistance, forKey: .assistance)
        try container.encodeIfPresent(draft, forKey: .draft)
        try container.encode(ISO8601.string(from: at), forKey: .at)
    }
}

// MARK: - LearningEvent union

/// The append-only event log. V1 rows carry no `type`/`eventVersion`;
/// v2 rows carry both. Dispatch mirrors `parseLearningEvent`.
enum LearningEvent {
    case practiceV1(PracticeEventV1)
    case attempt(ActivityAttempt)
    case stepCompleted(StepCompletion)
    case lessonKnown(LessonKnownEvent)
}

extension LearningEvent: Codable {
    private struct Header: Decodable {
        var eventVersion: Int?
        var type: String?
    }

    var id: String {
        switch self {
        case .practiceV1(let e): return e.id
        case .attempt(let e): return e.id
        case .stepCompleted(let e): return e.id
        case .lessonKnown(let e): return e.id
        }
    }

    var packId: String {
        switch self {
        case .practiceV1(let e): return e.packId
        case .attempt(let e): return e.packId
        case .stepCompleted(let e): return e.packId
        case .lessonKnown(let e): return e.packId
        }
    }

    var at: Date {
        switch self {
        case .practiceV1(let e): return e.at
        case .attempt(let e): return e.at
        case .stepCompleted(let e): return e.at
        case .lessonKnown(let e): return e.at
        }
    }

    /// The sync record kind, matching the `type` column in the store.
    var kindString: String {
        switch self {
        case .practiceV1: return "practice"
        case .attempt: return "attempt"
        case .stepCompleted: return "step-completed"
        case .lessonKnown: return "lesson-known"
        }
    }

    init(from decoder: Decoder) throws {
        let header = try Header(from: decoder)
        switch (header.eventVersion, header.type) {
        case (2, "attempt"):
            self = .attempt(try ActivityAttempt(from: decoder))
        case (2, "step-completed"):
            self = .stepCompleted(try StepCompletion(from: decoder))
        case (2, "lesson-known"):
            self = .lessonKnown(try LessonKnownEvent(from: decoder))
        case (nil, nil):
            self = .practiceV1(try PracticeEventV1(from: decoder))
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "unsupported learning event version/type: " +
                        "\(String(describing: header.eventVersion))/\(String(describing: header.type))"))
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .practiceV1(let e): try e.encode(to: encoder)
        case .attempt(let e): try e.encode(to: encoder)
        case .stepCompleted(let e): try e.encode(to: encoder)
        case .lessonKnown(let e): try e.encode(to: encoder)
        }
    }
}
