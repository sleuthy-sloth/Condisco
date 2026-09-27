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

// MARK: - v2 checkpoint attempt (5.3A)

/// The learner's self-assessment of one open checkpoint response.
/// Optional on the attempt: a spoken item carries ticked rubric criteria
/// (ids from the authored `CheckpointSpeakingItem.rubric`), and an overall
/// confidence rating on the review scale may ride along. A written item may
/// carry neither.
struct CheckpointSelfRating: Codable, Equatable {
    /// Rubric criterion ids the learner ticked.
    var criteriaMet: [String]
    /// Optional overall confidence (again/hard/good/easy).
    var rating: AttemptResponse.SelfRating?
}

/// A learner's recorded attempt on a checkpoint task. Practice evidence —
/// never an automatic pass. The event names the task, its modality
/// coverage, the assistance used, the learner's self-assessment, and the
/// date. Retakes are new rows with fresh ids; earlier attempts are never
/// erased and completion is never duplicated (the row carries no lesson,
/// activity, or evidence columns).
struct CheckpointAttemptEvent: Codable, Equatable {
    var eventVersion: Int = 2
    /// Serialized as "type".
    var eventType: String = "checkpoint-attempt"
    var id: String
    var packId: String
    var packVersion: String
    var checkpointId: String
    /// The checkpoint's authored stage, denormalised at record time from
    /// the pack (the projection re-validates against the pack).
    var stage: CheckpointStage
    /// The checkpoint's declared modality coverage, denormalised at record
    /// time (projection re-validates against the pack).
    var modalitySlots: [CheckpointModality]
    /// Assistance used on the attempt (existing kinds; empty = none).
    var assistance: [AssistanceKind]
    /// Self-assessment of the open response, optional.
    var selfRating: CheckpointSelfRating?
    /// Reveal-before-answer marker: true only once the learner has seen the
    /// checkpoint's items and self-assessment rubric. Independent credit
    /// derives from this field — the 5.3B UI lane must set it only after
    /// presenting the task, and an attempt saved without it is never
    /// independent (see `independent`).
    var itemsRevealed: Bool
    var at: Date

    /// The reveal-before-answer rule, enforced at the store: an open
    /// checkpoint response counts as independent only when the learner saw
    /// the items and rubric before answering (`itemsRevealed`) and used no
    /// assistance. The record API derives exactly this, so a caller can
    /// never mark an un-revealed attempt independent. It is practice
    /// evidence, not a gate: a low self-rating still leaves the learner
    /// free to continue, with a targeted revisit offered by the UI lane.
    var independent: Bool { itemsRevealed && assistance.isEmpty }

    private enum CodingKeys: String, CodingKey {
        case eventVersion
        case eventType = "type"
        case id, packId, packVersion, checkpointId, stage, modalitySlots
        case assistance, selfRating, itemsRevealed, at
    }

    init(id: String, packId: String, packVersion: String, checkpointId: String,
         stage: CheckpointStage, modalitySlots: [CheckpointModality],
         assistance: [AssistanceKind], selfRating: CheckpointSelfRating?,
         itemsRevealed: Bool, at: Date) {
        self.id = id
        self.packId = packId
        self.packVersion = packVersion
        self.checkpointId = checkpointId
        self.stage = stage
        self.modalitySlots = modalitySlots
        self.assistance = assistance
        self.selfRating = selfRating
        self.itemsRevealed = itemsRevealed
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
        checkpointId = try container.decode(String.self, forKey: .checkpointId)
        stage = try container.decode(CheckpointStage.self, forKey: .stage)
        modalitySlots = try container.decode(
            [CheckpointModality].self, forKey: .modalitySlots)
        assistance = try container.decode([AssistanceKind].self, forKey: .assistance)
        selfRating = try container.decodeIfPresent(
            CheckpointSelfRating.self, forKey: .selfRating)
        itemsRevealed = try container.decode(Bool.self, forKey: .itemsRevealed)
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
        try container.encode(checkpointId, forKey: .checkpointId)
        try container.encode(stage, forKey: .stage)
        try container.encode(modalitySlots, forKey: .modalitySlots)
        try container.encode(assistance, forKey: .assistance)
        try container.encodeIfPresent(selfRating, forKey: .selfRating)
        try container.encode(itemsRevealed, forKey: .itemsRevealed)
        try container.encode(ISO8601.string(from: at), forKey: .at)
    }
}

// MARK: - Open task attempts (Phase 6.2)
//
// A learner's recorded completion of a connected-production open task
// bound into a lesson step. Practice evidence — never an automatic pass
// and never graded: the event carries the task binding (lesson/step/
// activity + revision), the modality, the assistance used, whether the
// model was revealed, the learner's own self-assessment (rubric ticks +
// optional rating), and the date. The response text or recording is NOT
// stored here — the draft stays local and the recording is a disposable
// temp file. Retakes are fresh rows with new ids; earlier attempts are
// never erased and no completion/evidence is duplicated (the row carries
// no evidence column and the step completion for an open-task step is a
// bare completion with no attemptId).

/// The learner's self-assessment of one open-task response: the rubric
/// criterion ids they ticked (from the activity's authored rubric) and an
/// optional overall rating on the review scale.
struct OpenTaskSelfRating: Codable, Equatable {
    /// Rubric criterion ids the learner ticked.
    var criteriaMet: [String]
    /// Optional overall confidence (again/hard/good/easy).
    var rating: AttemptResponse.SelfRating?
}

/// A recorded open-task completion. `independent` derives from the reveal
/// marker and assistance: a response produced after the model was shown
/// (or with any help) is never independent — retries after a reveal stay
/// distinguishable from independent production.
struct OpenTaskAttemptEvent: Codable, Equatable {
    var eventVersion: Int = 2
    /// Serialized as "type".
    var eventType: String = "open-task-attempt"
    var id: String
    var packId: String
    var packVersion: String
    var lessonId: String
    var lessonRevision: Int
    var stepId: String
    var activityId: String
    var activityRevision: Int
    /// The task's authored modality, denormalised at record time from the
    /// pack (the projection re-validates against the pack).
    var mode: OpenTaskMode
    /// Assistance used on the attempt (existing kinds; empty = none).
    var assistance: [AssistanceKind]
    /// The learner's own self-assessment, optional.
    var selfRating: OpenTaskSelfRating?
    /// True only once the learner revealed the model on this attempt. An
    /// attempt saved with the model shown is never independent, and neither
    /// is one that used assistance.
    var modelRevealed: Bool
    var at: Date

    /// The reveal-before-answer rule, enforced at the store: an open
    /// response counts as independent only when the learner produced it
    /// without revealing the model and used no assistance. Retries after a
    /// reveal record `modelRevealed: true`, so they stay distinguishable
    /// from independent production. Practice evidence, not a gate: a
    /// helped or revealed attempt still completes the lesson step.
    var independent: Bool { !modelRevealed && assistance.isEmpty }

    private enum CodingKeys: String, CodingKey {
        case eventVersion
        case eventType = "type"
        case id, packId, packVersion, lessonId, lessonRevision, stepId
        case activityId, activityRevision, mode, assistance, selfRating
        case modelRevealed, at
    }

    init(id: String, packId: String, packVersion: String, lessonId: String,
         lessonRevision: Int, stepId: String, activityId: String,
         activityRevision: Int, mode: OpenTaskMode,
         assistance: [AssistanceKind], selfRating: OpenTaskSelfRating?,
         modelRevealed: Bool, at: Date) {
        self.id = id
        self.packId = packId
        self.packVersion = packVersion
        self.lessonId = lessonId
        self.lessonRevision = lessonRevision
        self.stepId = stepId
        self.activityId = activityId
        self.activityRevision = activityRevision
        self.mode = mode
        self.assistance = assistance
        self.selfRating = selfRating
        self.modelRevealed = modelRevealed
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
        mode = try container.decode(OpenTaskMode.self, forKey: .mode)
        assistance = try container.decode([AssistanceKind].self, forKey: .assistance)
        selfRating = try container.decodeIfPresent(
            OpenTaskSelfRating.self, forKey: .selfRating)
        modelRevealed = try container.decode(Bool.self, forKey: .modelRevealed)
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
        try container.encode(mode, forKey: .mode)
        try container.encode(assistance, forKey: .assistance)
        try container.encodeIfPresent(selfRating, forKey: .selfRating)
        try container.encode(modelRevealed, forKey: .modelRevealed)
        try container.encode(ISO8601.string(from: at), forKey: .at)
    }
}

// MARK: - Dialogue turns and checkpoints (Phase 6.3)
//
// A branching exchange (a hosted `Dialogue` in the pack) is practised one
// learner turn at a time. Each answered turn appends a `DialogueTurnEvent`
// in authored turn order; the half-completed exchange itself lives in the
// lesson checkpoint (`LessonCheckpoint.dialogue`), so branch position and
// the learner's own replies survive force quit exactly like the lesson
// step position does. The learner's composed draft and their picked choice
// are stored locally in the checkpoint (for the recap) — never in the
// event log, the same discipline open tasks use.

/// One answered turn of an exchange, as recorded in the checkpoint: which
/// node was answered, and what the learner independently supplied. Choice
/// turns carry `choiceId` (a pack-authored option); open turns carry the
/// learner's own `draft` plus their self-assessment (`criteriaMet`,
/// optional `rating`) and whether the model was revealed.
struct DialogueTurnRecord: Codable, Equatable {
    var nodeId: String
    var choiceId: String?
    var draft: String?
    var criteriaMet: [String]
    var rating: AttemptResponse.SelfRating?
    var modelRevealed: Bool

    init(nodeId: String, choiceId: String? = nil, draft: String? = nil,
         criteriaMet: [String] = [], rating: AttemptResponse.SelfRating? = nil,
         modelRevealed: Bool = false) {
        self.nodeId = nodeId
        self.choiceId = choiceId
        self.draft = draft
        self.criteriaMet = criteriaMet
        self.rating = rating
        self.modelRevealed = modelRevealed
    }
}

/// The exchange slice of a lesson checkpoint: branch position
/// (`currentNodeId` + the visited thread), the turns answered so far in
/// authored order, an in-progress open-turn draft for resume, and whether
/// the exchange reached its end state. Additive: checkpoints saved before
/// 6.3 carry no `dialogue` key and decode unchanged.
struct DialogueCheckpointState: Codable, Equatable {
    var dialogueId: String
    var currentNodeId: String
    var visitedNodeIds: [String]
    var turns: [DialogueTurnRecord]
    var openDraft: String?
    var complete: Bool

    private enum CodingKeys: String, CodingKey {
        case dialogueId, currentNodeId, visitedNodeIds, turns, openDraft, complete
    }

    init(dialogueId: String, currentNodeId: String, visitedNodeIds: [String],
         turns: [DialogueTurnRecord], openDraft: String?, complete: Bool) {
        self.dialogueId = dialogueId
        self.currentNodeId = currentNodeId
        self.visitedNodeIds = visitedNodeIds
        self.turns = turns
        self.openDraft = openDraft
        self.complete = complete
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dialogueId = try container.decode(String.self, forKey: .dialogueId)
        currentNodeId = try container.decode(String.self, forKey: .currentNodeId)
        visitedNodeIds = try container.decode([String].self, forKey: .visitedNodeIds)
        turns = try container.decode([DialogueTurnRecord].self, forKey: .turns)
        openDraft = try container.decodeIfPresent(String.self, forKey: .openDraft)
        complete = try container.decodeIfPresent(Bool.self, forKey: .complete) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(dialogueId, forKey: .dialogueId)
        try container.encode(currentNodeId, forKey: .currentNodeId)
        try container.encode(visitedNodeIds, forKey: .visitedNodeIds)
        try container.encode(turns, forKey: .turns)
        try container.encodeIfPresent(openDraft, forKey: .openDraft)
        try container.encode(complete, forKey: .complete)
    }
}

/// One answered turn of a practised exchange, recorded as practice
/// evidence in authored turn order. Never auto-graded: open turns carry the
/// learner's own self-assessment (rubric ticks + optional rating) and the
/// model-reveal marker; the composed draft itself is NOT stored here (it
/// lives in the lesson checkpoint for the recap). Choice turns record the
/// pack-authored `choiceId` the learner picked (like a step's branch id).
/// A retake of the exchange answers fresh turns with fresh ids — earlier
/// rows are never erased or reordered, so replaying a completed exchange
/// re-presents it without duplicating events.
struct DialogueTurnEvent: Codable, Equatable {
    var eventVersion: Int = 2
    /// Serialized as "type".
    var eventType: String = "dialogue-turn"
    var id: String
    var packId: String
    var packVersion: String
    var dialogueId: String
    /// The lesson hosting this exchange, denormalised at record time
    /// (the projection re-validates against the pack).
    var hostLessonId: String
    var hostLessonRevision: Int
    /// The node answered by this turn.
    var nodeId: String
    /// 1-based position of this turn within the attempt: events of one
    /// exchange read back in exactly the authored turn order.
    var turnIndex: Int
    /// True for an open (composed) turn, false for a choice turn.
    var isOpen: Bool
    /// Choice turns only: the pack-authored option the learner picked.
    var choiceId: String?
    /// Open turns only: the learner's self-assessment rubric ticks.
    var criteriaMet: [String]
    /// Open turns only: optional overall rating.
    var rating: AttemptResponse.SelfRating?
    /// Open turns only: true once the model was revealed on this turn.
    var modelRevealed: Bool
    var at: Date

    private enum CodingKeys: String, CodingKey {
        case eventVersion
        case eventType = "type"
        case id, packId, packVersion, dialogueId, hostLessonId,
             hostLessonRevision, nodeId, turnIndex, isOpen, choiceId,
             criteriaMet, rating, modelRevealed, at
    }

    init(id: String, packId: String, packVersion: String, dialogueId: String,
         hostLessonId: String, hostLessonRevision: Int, nodeId: String,
         turnIndex: Int, isOpen: Bool, choiceId: String?, criteriaMet: [String],
         rating: AttemptResponse.SelfRating?, modelRevealed: Bool, at: Date) {
        self.id = id
        self.packId = packId
        self.packVersion = packVersion
        self.dialogueId = dialogueId
        self.hostLessonId = hostLessonId
        self.hostLessonRevision = hostLessonRevision
        self.nodeId = nodeId
        self.turnIndex = turnIndex
        self.isOpen = isOpen
        self.choiceId = choiceId
        self.criteriaMet = criteriaMet
        self.rating = rating
        self.modelRevealed = modelRevealed
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
        dialogueId = try container.decode(String.self, forKey: .dialogueId)
        hostLessonId = try container.decode(String.self, forKey: .hostLessonId)
        hostLessonRevision = try container.decode(Int.self, forKey: .hostLessonRevision)
        nodeId = try container.decode(String.self, forKey: .nodeId)
        turnIndex = try container.decode(Int.self, forKey: .turnIndex)
        isOpen = try container.decode(Bool.self, forKey: .isOpen)
        choiceId = try container.decodeIfPresent(String.self, forKey: .choiceId)
        criteriaMet = try container.decodeIfPresent([String].self, forKey: .criteriaMet) ?? []
        rating = try container.decodeIfPresent(AttemptResponse.SelfRating.self, forKey: .rating)
        modelRevealed = try container.decodeIfPresent(Bool.self, forKey: .modelRevealed) ?? false
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
        try container.encode(dialogueId, forKey: .dialogueId)
        try container.encode(hostLessonId, forKey: .hostLessonId)
        try container.encode(hostLessonRevision, forKey: .hostLessonRevision)
        try container.encode(nodeId, forKey: .nodeId)
        try container.encode(turnIndex, forKey: .turnIndex)
        try container.encode(isOpen, forKey: .isOpen)
        try container.encodeIfPresent(choiceId, forKey: .choiceId)
        try container.encode(criteriaMet, forKey: .criteriaMet)
        try container.encodeIfPresent(rating, forKey: .rating)
        try container.encode(modelRevealed, forKey: .modelRevealed)
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
    /// Phase 6.3 exchange state: branch position + answered turns of a
    /// hosted dialogue, so force-quitting mid-exchange resumes exactly
    /// where the learner stopped. Additive — old checkpoints carry no
    /// `dialogue` key and decode unchanged.
    var dialogue: DialogueCheckpointState?
    var at: Date

    private enum CodingKeys: String, CodingKey {
        case packId, lessonId, revision, stepId, selectedBranches, assistance,
             draft, dialogue, at
    }

    init(packId: String, lessonId: String, revision: Int, stepId: String,
         selectedBranches: [String: String], assistance: [AssistanceKind],
         draft: AttemptResponse?, at: Date,
         dialogue: DialogueCheckpointState? = nil) {
        self.packId = packId
        self.lessonId = lessonId
        self.revision = revision
        self.stepId = stepId
        self.selectedBranches = selectedBranches
        self.assistance = assistance
        self.draft = draft
        self.dialogue = dialogue
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
        dialogue = try container.decodeIfPresent(
            DialogueCheckpointState.self, forKey: .dialogue)
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
        try container.encodeIfPresent(dialogue, forKey: .dialogue)
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
    case checkpointAttempt(CheckpointAttemptEvent)
    case openTaskAttempt(OpenTaskAttemptEvent)
    case dialogueTurn(DialogueTurnEvent)
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
        case .checkpointAttempt(let e): return e.id
        case .openTaskAttempt(let e): return e.id
        case .dialogueTurn(let e): return e.id
        }
    }

    var packId: String {
        switch self {
        case .practiceV1(let e): return e.packId
        case .attempt(let e): return e.packId
        case .stepCompleted(let e): return e.packId
        case .lessonKnown(let e): return e.packId
        case .checkpointAttempt(let e): return e.packId
        case .openTaskAttempt(let e): return e.packId
        case .dialogueTurn(let e): return e.packId
        }
    }

    var at: Date {
        switch self {
        case .practiceV1(let e): return e.at
        case .attempt(let e): return e.at
        case .stepCompleted(let e): return e.at
        case .lessonKnown(let e): return e.at
        case .checkpointAttempt(let e): return e.at
        case .openTaskAttempt(let e): return e.at
        case .dialogueTurn(let e): return e.at
        }
    }

    /// The sync record kind, matching the `type` column in the store.
    var kindString: String {
        switch self {
        case .practiceV1: return "practice"
        case .attempt: return "attempt"
        case .stepCompleted: return "step-completed"
        case .lessonKnown: return "lesson-known"
        case .checkpointAttempt: return "checkpoint-attempt"
        case .openTaskAttempt: return "open-task-attempt"
        case .dialogueTurn: return "dialogue-turn"
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
        case (2, "checkpoint-attempt"):
            self = .checkpointAttempt(try CheckpointAttemptEvent(from: decoder))
        case (2, "open-task-attempt"):
            self = .openTaskAttempt(try OpenTaskAttemptEvent(from: decoder))
        case (2, "dialogue-turn"):
            self = .dialogueTurn(try DialogueTurnEvent(from: decoder))
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
        case .checkpointAttempt(let e): try e.encode(to: encoder)
        case .openTaskAttempt(let e): try e.encode(to: encoder)
        case .dialogueTurn(let e): try e.encode(to: encoder)
        }
    }
}
