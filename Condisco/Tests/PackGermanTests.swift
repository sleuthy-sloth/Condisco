import XCTest
@testable import Condisco

/// Per-pack editorial regression tests for the German pack.
///
/// Owned by the German editorial lane: add targeted answer/evaluation
/// tests here for content fixes (resolved high-confidence errors,
/// narrowed accepted-answer sets, authored error feedback). Do not put
/// other packs' tests in this file.
final class PackGermanTests: XCTestCase {

    // MARK: - Helpers

    private func germanPack() throws -> CoursePack {
        try XCTUnwrap(PackLoader.loadPacks().first { $0.language.slug == "german" })
    }

    private func activity(_ id: String, in pack: CoursePack) throws -> Activity {
        try XCTUnwrap(pack.activity(id: id), "missing activity \(id)")
    }

    /// Grade a free-text response against an activity's authored AnswerSpec.
    private func gradeText(_ id: String, in pack: CoursePack, _ response: String) throws -> AnswerEvaluation {
        let act = try activity(id, in: pack)
        guard case .text(let spec) = act else {
            throw XCTSkip("expected a text activity for \(id)")
        }
        return AnswerEngine.evaluate(response: response, spec: spec.answer)
    }

    private static let genericHints: Set<String> = [
        "Try it", "Try again", "Not quite — try again.",
        "That selection is not valid. Try again.",
        "The order is not right yet. Try again.",
        "Some pairs are off. Try again.",
        "Place every token exactly once.",
    ]

    /// The four lessons in de-unit-1 and de-unit-2 (batch 1 scope), keyed by
    /// the activity ids each lesson's path references.
    private static let batch1Lessons: [String: [String]] = [
        "de-cafe-mission": [
            "de-cafe-mission-act-2", "de-cafe-mission-act-4",
            "de-cafe-mission-act-6", "de-cafe-mission-act-7",
            "de-cafe-mission-act-8", "de-cafe-mission-act-9",
        ],
        "de-introductions-foundation": [
            "de-introductions-foundation-notice", "de-introductions-foundation-recall",
            "de-introductions-foundation-build", "de-introductions-foundation-reply",
            "de-introductions-foundation-ask", "de-introductions-foundation-read",
        ],
        "de-cafe-requests-foundation": [
            "de-cafe-requests-foundation-choose", "de-cafe-requests-foundation-recall",
            "de-cafe-requests-foundation-build", "de-cafe-requests-foundation-vary",
            "de-cafe-requests-foundation-meaning", "de-cafe-requests-foundation-read",
        ],
        "de-numbers-quantities-foundation": [
            "de-numbers-quantities-foundation-meet", "de-numbers-quantities-foundation-order",
            "de-numbers-quantities-foundation-quantity", "de-numbers-quantities-foundation-think",
        ],
    ]

    // MARK: - Pack load

    func testGermanPackLoadsAndValidates() throws {
        let packs = try PackLoader.loadPacks()
        let pack = try XCTUnwrap(packs.first { $0.language.slug == "german" })
        XCTAssertFalse(pack.lessons.isEmpty, "German pack must ship lessons")
        XCTAssertNoThrow(try PackValidator.validate(pack), pack.id)
    }

    // MARK: - Pack-level copy (honest review-status wording)

    /// The pack description and attribution must not claim completed
    /// native-speaker review or repeat the old double-counted lesson math.
    func testPackCopyHasNoUnverifiedNativeReviewClaim() throws {
        let pack = try germanPack()
        for copy in [pack.description, pack.attribution] {
            XCTAssertFalse(
                copy.lowercased().contains("native-speaker review: lessons"),
                "unverified per-lesson native-review claim: \(copy.prefix(80))")
            XCTAssertFalse(
                copy.contains("have been through native-speaker review"),
                "unverified native-review claim: \(copy.prefix(80))")
        }
        let description = pack.description
        XCTAssertTrue(description.contains("52 German lessons"), "description must state the real lesson count")
        XCTAssertTrue(description.contains("native-speaker review is pending"),
                      "description must keep native-speaker review honestly open")
    }

    // MARK: - Hints (rubric H4)

    /// Every graded step in batch-1 lessons has a real authored hint, not the
    /// runtime generic fallbacks (audit_editorial hint-gap must stay 0).
    func testBatch1GradedStepsHaveAuthoredHints() throws {
        let pack = try germanPack()
        for (lessonId, activityIds) in Self.batch1Lessons {
            for activityId in activityIds {
                let act = try activity(activityId, in: pack)
                let base = try XCTUnwrap(act.base, "\(lessonId): \(activityId) has no graded base")
                XCTAssertFalse(
                    base.hints.allSatisfy { Self.genericHints.contains($0) },
                    "\(lessonId): \(activityId) lacks an authored hint: \(base.hints)")
            }
        }
    }

    // MARK: - Error feedback (rubric H3)

    /// Every text activity in batch-1 lessons authors error-specific feedback
    /// for at least the top likely mistakes (audit_editorial error-feedback
    /// gap must stay 0 for these lessons).
    func testBatch1TextActivitiesAuthorErrors() throws {
        let pack = try germanPack()
        for (lessonId, activityIds) in Self.batch1Lessons {
            for activityId in activityIds {
                let act = try activity(activityId, in: pack)
                switch act {
                case .text(let spec):
                    XCTAssertFalse(
                        spec.answer.errors.isEmpty,
                        "\(lessonId): \(activityId) must author error feedback")
                default:
                    break
                }
            }
        }
    }

    /// Plausible wrong answers hit their authored category + explanation.
    func testAuthoredErrorsFireForPlausibleWrongAnswers() throws {
        let pack = try germanPack()

        // de-introductions-foundation-recall
        var result = try gradeText("de-introductions-foundation-recall", in: pack, "Ich bin Anna.")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-introductions-foundation-recall", in: pack, "Ich heißt Anna.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("de-introductions-foundation-recall", in: pack, "Ich heiße.")
        XCTAssertEqual(result.category, "missing word")

        // de-introductions-foundation-ask
        result = try gradeText("de-introductions-foundation-ask", in: pack, "Wie heiße du?")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("de-introductions-foundation-ask", in: pack, "Heißt du?")
        XCTAssertEqual(result.category, "missing word")

        // de-introductions-foundation-read
        result = try gradeText("de-introductions-foundation-read", in: pack, "Anna")
        XCTAssertEqual(result.category, "incorrect answer")

        // de-cafe-requests-foundation-recall
        result = try gradeText("de-cafe-requests-foundation-recall", in: pack, "Ein Kaffee, bitte.")
        XCTAssertEqual(result.category, "wrong article")
        result = try gradeText("de-cafe-requests-foundation-recall", in: pack, "Einen Kaffee.")
        XCTAssertEqual(result.category, "missing word")

        // de-cafe-requests-foundation-vary
        result = try gradeText("de-cafe-requests-foundation-vary", in: pack, "Ich möchte ein Tee, bitte.")
        XCTAssertEqual(result.category, "wrong article")
        result = try gradeText("de-cafe-requests-foundation-vary", in: pack, "Ich möchte einen Kaffee, bitte.")
        XCTAssertEqual(result.category, "incorrect answer")

        // de-cafe-requests-foundation-meaning
        result = try gradeText("de-cafe-requests-foundation-meaning", in: pack, "I want a coffee, please.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("de-cafe-requests-foundation-meaning", in: pack, "A coffee, please.")
        XCTAssertEqual(result.category, "missing word")

        // de-cafe-requests-foundation-read
        result = try gradeText("de-cafe-requests-foundation-read", in: pack, "Kaffee")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("de-cafe-requests-foundation-read", in: pack, "ein")
        XCTAssertEqual(result.category, "incorrect answer")

        // de-numbers-quantities-foundation-quantity
        result = try gradeText("de-numbers-quantities-foundation-quantity", in: pack, "Zwei Apfel, bitte.")
        XCTAssertEqual(result.category, "wrong number")
        XCTAssertFalse(result.accepted, "missing umlaut plural must not be accepted")
        result = try gradeText("de-numbers-quantities-foundation-quantity", in: pack, "Ein Apfel, bitte.")
        XCTAssertEqual(result.category, "wrong number")
        result = try gradeText("de-numbers-quantities-foundation-quantity", in: pack, "Zwei Äpfel.")
        XCTAssertEqual(result.category, "missing word")

        // de-numbers-quantities-foundation-think
        result = try gradeText("de-numbers-quantities-foundation-think", in: pack, "Was kostet einen Kaffee?")
        XCTAssertEqual(result.category, "wrong article")

        // de-cafe-mission
        result = try gradeText("de-cafe-mission-act-7", in: pack, "Ein Kaffee, bitte.")
        XCTAssertEqual(result.category, "wrong article")
        result = try gradeText("de-cafe-mission-act-7", in: pack, "Einen Kaffee.")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeText("de-cafe-mission-act-9", in: pack, "Hallo. Danke. Einen Kaffee, bitte.")
        XCTAssertEqual(result.category, "word-order problem")
    }

    // MARK: - Accepted answers (prompt ↔ answers alignment)

    /// Natural German alternatives and the dictated-copy forms are accepted.
    func testBatch1AcceptsNaturalGermanAlternatives() throws {
        let pack = try germanPack()

        // Price question: the synonym Wie viel kostet … is equally natural.
        var result = try gradeText("de-numbers-quantities-foundation-think", in: pack, "Wie viel kostet ein Kaffee?")
        XCTAssertTrue(result.accepted, "Wie viel kostet ein Kaffee? must be accepted")
        result = try gradeText("de-numbers-quantities-foundation-think", in: pack, "Was kostet ein Kaffee?")
        XCTAssertTrue(result.accepted)

        // Meaning drill: both apostrophe renderings of the contraction.
        result = try gradeText("de-cafe-requests-foundation-meaning", in: pack, "I'd like a coffee, please.")
        XCTAssertTrue(result.accepted)

        // Short café request still accepts the dictated short form.
        result = try gradeText("de-cafe-requests-foundation-recall", in: pack, "Einen Kaffee, bitte.")
        XCTAssertTrue(result.accepted)
    }
}