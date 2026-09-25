import Foundation

/// FSRS v6 spaced-repetition state per evidence key.
///
/// Implements the canonical scheduler from open-spaced-repetition
/// fsrs4anki v6 (fixed default parameters, desired retention 0.9),
/// replacing the old SM-2 scheduler. State is derived by projecting the
/// attempt event log, so existing history replays through FSRS
/// automatically. The tolerant decoder below also converts any old
/// SM-2-shaped payload via the canonical `convert_states` mapping, so
/// payloads from disk or another device never fail to decode.
///
/// Condisco skips the v6 short-term-stability machinery: there are no
/// sub-day learning steps, so the minimum interval stays one day.
struct FsrsState: Codable, Equatable {
    /// Memory stability (S): days until retrievability decays to 0.9.
    var stability: Double
    /// Memory difficulty (D): 1 (easy) … 10 (hard).
    var difficulty: Double
    /// Whole days until the next review.
    var intervalDays: Int
    /// When the next review is due.
    var dueAt: Date
    /// When the card was last reviewed.
    var lastReviewedAt: Date
    /// FSRS grade of the last review (1…4); 0 means never reviewed.
    var lastGrade: Int
    /// Number of completed reviews; 0 means never reviewed.
    var reps: Int

    private enum CodingKeys: String, CodingKey {
        case stability, difficulty, intervalDays, dueAt
        case lastReviewedAt, lastGrade, reps
        // Legacy SM-2 keys: decoded tolerantly, never encoded.
        case easeFactor, repetitions, lapseCount, lastQuality, lastLatencyMs
    }

    init(
        stability: Double,
        difficulty: Double,
        intervalDays: Int,
        dueAt: Date,
        lastReviewedAt: Date,
        lastGrade: Int,
        reps: Int
    ) {
        self.stability = stability
        self.difficulty = difficulty
        self.intervalDays = intervalDays
        self.dueAt = dueAt
        self.lastReviewedAt = lastReviewedAt
        self.lastGrade = lastGrade
        self.reps = reps
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.stability) {
            stability = try container.decode(Double.self, forKey: .stability)
            difficulty = try container.decode(Double.self, forKey: .difficulty)
            intervalDays = try container.decode(Int.self, forKey: .intervalDays)
            dueAt = try container.decode(Date.self, forKey: .dueAt)
            lastReviewedAt = try container.decode(Date.self, forKey: .lastReviewedAt)
            lastGrade = try container.decode(Int.self, forKey: .lastGrade)
            reps = try container.decode(Int.self, forKey: .reps)
            return
        }
        // Old SM-2 payload: canonical convert_states mapping.
        let easeFactor = try container.decode(Double.self, forKey: .easeFactor)
        intervalDays = try container.decode(Int.self, forKey: .intervalDays)
        dueAt = try container.decode(Date.self, forKey: .dueAt)
        reps = try container.decodeIfPresent(Int.self, forKey: .repetitions) ?? 0
        let s = max(Double(intervalDays), 0.1)
        stability = s
        difficulty = Fsrs.constrainDifficulty(
            11 - (easeFactor - 1)
                / (exp(Fsrs.w[8]) * pow(s, -Fsrs.w[9])
                    * (exp(0.1 * Fsrs.w[10]) - 1)))
        lastReviewedAt = dueAt.addingTimeInterval(
            -Double(intervalDays) * Fsrs.secondsPerDay)
        // SM-2 quality (0…5) is informational only; map it coarsely.
        let quality = try container.decodeIfPresent(Int.self, forKey: .lastQuality) ?? 0
        lastGrade = quality >= 4 ? 3 : (quality == 3 ? 2 : 1)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(stability, forKey: .stability)
        try container.encode(difficulty, forKey: .difficulty)
        try container.encode(intervalDays, forKey: .intervalDays)
        try container.encode(dueAt, forKey: .dueAt)
        try container.encode(lastReviewedAt, forKey: .lastReviewedAt)
        try container.encode(lastGrade, forKey: .lastGrade)
        try container.encode(reps, forKey: .reps)
    }
}

/// FSRS v6's four native grades.
enum FsrsGrade: Int {
    case again = 1, hard = 2, good = 3, easy = 4
}

enum Fsrs {
    static let secondsPerDay: Double = 86_400

    /// Default FSRS v6 parameters (fsrs4anki 6.x).
    static let w: [Double] = [
        0.212, 1.2931, 2.3065, 8.2956, 6.4133, 0.8334, 3.0194, 0.001,
        1.8722, 0.1666, 0.796, 1.4835, 0.0614, 0.2629, 1.6483, 0.6014,
        1.8729, 0.5425, 0.0912, 0.0658, 0.1542,
    ]

    /// Desired retention. Fixed; a user-facing knob is future work.
    static let requestRetention: Double = 0.9
    static let maximumInterval: Int = 36500

    private static let decay: Double = -w[20]
    private static let factor: Double = pow(requestRetention, 1 / decay) - 1

    static func constrainDifficulty(_ difficulty: Double) -> Double {
        min(max(difficulty, 1), 10)
    }

    static func initDifficulty(_ grade: FsrsGrade) -> Double {
        constrainDifficulty(
            w[4] - exp(w[5] * Double(grade.rawValue - 1)) + 1)
    }

    static func initStability(_ grade: FsrsGrade) -> Double {
        max(w[grade.rawValue - 1], 0.1)
    }

    /// Probability of recall after `elapsedDays` at stability `s`.
    static func forgettingCurve(elapsedDays: Double, stability: Double) -> Double {
        pow(1 + factor * elapsedDays / stability, decay)
    }

    static func nextDifficulty(_ difficulty: Double, grade: FsrsGrade) -> Double {
        let deltaD = -w[6] * Double(grade.rawValue - 3)
        let next = difficulty + deltaD * (10 - difficulty) / 9
        return constrainDifficulty(w[7] * initDifficulty(.easy) + (1 - w[7]) * next)
    }

    static func nextRecallStability(
        difficulty: Double, stability: Double,
        retrievability: Double, grade: FsrsGrade
    ) -> Double {
        let hardPenalty = grade == .hard ? w[15] : 1
        let easyBonus = grade == .easy ? w[16] : 1
        return stability * (1 + exp(w[8]) * (11 - difficulty)
            * pow(stability, -w[9])
            * (exp((1 - retrievability) * w[10]) - 1)
            * hardPenalty * easyBonus)
    }

    static func nextForgetStability(
        difficulty: Double, stability: Double, retrievability: Double
    ) -> Double {
        let recalled = w[11] * pow(difficulty, -w[12])
            * (pow(stability + 1, w[13]) - 1)
            * exp((1 - retrievability) * w[14])
        return min(recalled, stability / exp(w[17] * w[18]))
    }

    /// Whole days until the next review at the desired retention,
    /// with the canonical ±5% fuzz.
    static func nextInterval(stability: Double, previousIntervalDays: Int?) -> Int {
        let raw = stability / factor * (pow(requestRetention, 1 / decay) - 1)
        guard raw >= 2.5 else { return max(1, Int(raw.rounded())) }
        let interval = Int(raw.rounded())
        var low = max(2, Int((Double(interval) * 0.95 - 1).rounded()))
        let high = Int((Double(interval) * 1.05 + 1).rounded())
        if let previous = previousIntervalDays, interval > previous {
            // The fuzz must never shorten below the previously scheduled span.
            low = max(low, previous + 1)
        }
        let clampedLow = min(low, high)
        return min(max(Int.random(in: clampedLow...high), 1), maximumInterval)
    }

    /// Initial state for an evidence key first seen at `at`.
    /// Stability and difficulty are assigned lazily on the first review.
    static func initial(at: Date) -> FsrsState {
        FsrsState(
            stability: 0,
            difficulty: 0,
            intervalDays: 0,
            dueAt: at,
            lastReviewedAt: at,
            lastGrade: 0,
            reps: 0)
    }

    /// Schedules the next review. `dueAt` is `reviewedAt + intervalDays`
    /// in UTC epoch time, so rollover happens at UTC midnight.
    static func scheduleReview(
        previous: FsrsState, grade: FsrsGrade, reviewedAt: Date
    ) -> FsrsState {
        let stability: Double
        let difficulty: Double
        if previous.reps == 0 {
            stability = initStability(grade)
            difficulty = initDifficulty(grade)
        } else {
            let elapsed = max(
                0,
                reviewedAt.timeIntervalSince(previous.lastReviewedAt) / secondsPerDay)
            let retrievability = forgettingCurve(
                elapsedDays: elapsed, stability: previous.stability)
            // Stability always updates against the *old* difficulty.
            stability = grade == .again
                ? nextForgetStability(
                    difficulty: previous.difficulty,
                    stability: previous.stability,
                    retrievability: retrievability)
                : nextRecallStability(
                    difficulty: previous.difficulty,
                    stability: previous.stability,
                    retrievability: retrievability,
                    grade: grade)
            difficulty = nextDifficulty(previous.difficulty, grade: grade)
        }
        let intervalDays = nextInterval(
            stability: stability,
            previousIntervalDays: previous.reps == 0 ? nil : previous.intervalDays)
        return FsrsState(
            stability: stability,
            difficulty: difficulty,
            intervalDays: intervalDays,
            dueAt: reviewedAt.addingTimeInterval(Double(intervalDays) * secondsPerDay),
            lastReviewedAt: reviewedAt,
            lastGrade: grade.rawValue,
            reps: previous.reps + 1)
    }

    /// FSRS grade for a recorded attempt.
    ///
    /// Review self-ratings carry the grade directly (legacy
    /// `.comfortable` ratings from before FSRS map to Good). Lesson work
    /// maps to Good for clean independent recall, Hard for correct-but-
    /// assisted, and Again for a miss.
    static func grade(for attempt: ActivityAttempt) -> FsrsGrade {
        if case .selfRating(let rating) = attempt.response {
            switch rating {
            case .again: return .again
            case .hard: return .hard
            case .good: return .good
            case .easy: return .easy
            case .comfortable: return .good
            }
        }
        guard attempt.evaluation.outcome == .correct else { return .again }
        return attempt.evaluation.independent ? .good : .hard
    }
}
