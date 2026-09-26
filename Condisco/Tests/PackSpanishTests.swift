import XCTest
@testable import Condisco

/// Per-pack editorial regression tests for the Spanish pack.
///
/// Owned by the Spanish editorial lane: add targeted answer/evaluation
/// tests here for content fixes (resolved high-confidence errors,
/// narrowed accepted-answer sets, authored error feedback). Do not put
/// other packs' tests in this file.
final class PackSpanishTests: XCTestCase {

    // MARK: - Helpers

    private func spanishPack() throws -> CoursePack {
        try XCTUnwrap(PackLoader.loadPacks().first { $0.language.slug == "spanish" })
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

    /// The four lessons in es-unit-1 and es-unit-2 (batch 1 scope), keyed by
    /// the activity ids each lesson's path references.
    private static let batch1Lessons: [String: [String]] = [
        "es-cafe-mission": [
            "es-cafe-mission-act-2", "es-cafe-mission-act-4",
            "es-cafe-mission-act-6", "es-cafe-mission-act-7",
            "es-cafe-mission-act-8", "es-cafe-mission-act-9",
        ],
        "es-introductions-foundation": [
            "es-introductions-foundation-notice", "es-introductions-foundation-ask",
            "es-introductions-foundation-read", "es-introductions-foundation-reply",
            "es-introductions-foundation-build", "es-introductions-foundation-recall",
        ],
        "es-cafe-requests-foundation": [
            "es-cafe-requests-foundation-choose", "es-cafe-requests-foundation-vary",
            "es-cafe-requests-foundation-read", "es-cafe-requests-foundation-meaning",
            "es-cafe-requests-foundation-build", "es-cafe-requests-foundation-recall",
        ],
        "es-numbers-quantities-foundation": [
            "es-numbers-quantities-foundation-meet", "es-numbers-quantities-foundation-read",
            "es-numbers-quantities-foundation-order", "es-numbers-quantities-foundation-quantity",
            "es-numbers-quantities-foundation-think",
        ],
    ]

    // MARK: - Pack load

    func testSpanishPackLoadsAndValidates() throws {
        let packs = try PackLoader.loadPacks()
        let pack = try XCTUnwrap(packs.first { $0.language.slug == "spanish" })
        XCTAssertFalse(pack.lessons.isEmpty, "Spanish pack must ship lessons")
        XCTAssertNoThrow(try PackValidator.validate(pack), pack.id)
    }

    // MARK: - Hints (rubric H4)

    /// Every graded step in batch-1 lessons has a real authored hint, not the
    /// runtime generic fallbacks (audit_editorial hint-gap must stay 0).
    func testBatch1GradedStepsHaveAuthoredHints() throws {
        let pack = try spanishPack()
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
        let pack = try spanishPack()
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
        let pack = try spanishPack()

        // es-introductions-foundation-ask
        var result = try gradeText("es-introductions-foundation-ask", in: pack, "Me llamo Ana.")
        XCTAssertEqual(result.category, "wrong conjugation")
        XCTAssertFalse(result.accepted)
        result = try gradeText("es-introductions-foundation-ask", in: pack, "¿Cómo me llamas?")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("es-introductions-foundation-ask", in: pack, "¿Qué es tu nombre?")
        XCTAssertEqual(result.category, "incorrect answer")

        // es-introductions-foundation-recall
        result = try gradeText("es-introductions-foundation-recall", in: pack, "Llamo Ana.")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeText("es-introductions-foundation-recall", in: pack, "Soy Ana.")
        XCTAssertEqual(result.category, "incorrect answer")

        // es-cafe-requests-foundation-vary
        result = try gradeText("es-cafe-requests-foundation-vary", in: pack, "Quiero un té, por favor.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("es-cafe-requests-foundation-vary", in: pack, "Quisiera un te, por favor.")
        XCTAssertEqual(result.category, "accent/diacritic issue")
        result = try gradeText("es-cafe-requests-foundation-vary", in: pack, "Quisiera un té.")
        XCTAssertEqual(result.category, "missing word")

        // es-numbers-quantities-foundation-quantity
        result = try gradeText("es-numbers-quantities-foundation-quantity", in: pack, "Dos manzana, por favor.")
        XCTAssertEqual(result.category, "wrong number")
        result = try gradeText("es-numbers-quantities-foundation-quantity", in: pack, "Una manzana, por favor.")
        XCTAssertEqual(result.category, "wrong number")
        result = try gradeText("es-numbers-quantities-foundation-quantity", in: pack, "Dos manzanas.")
        XCTAssertEqual(result.category, "missing word")

        // es-numbers-quantities-foundation-think
        result = try gradeText("es-numbers-quantities-foundation-think", in: pack, "¿Cuánto cuesta un manzana?")
        XCTAssertEqual(result.category, "wrong article")
        result = try gradeText("es-numbers-quantities-foundation-think", in: pack, "¿Cuánto cuesta manzana?")
        XCTAssertEqual(result.category, "missing word")

        // es-cafe-mission
        result = try gradeText("es-cafe-mission-act-7", in: pack, "Café, por favor.")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeText("es-cafe-mission-act-7", in: pack, "Un café porfavor.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("es-cafe-mission-act-9", in: pack, "Hola. Un café. Gracias.")
        XCTAssertEqual(result.category, "missing word")
    }

    // MARK: - Accepted answers (prompt ↔ answers alignment)

    /// Natural Spanish replies for comprehension/quantity prompts are accepted
    /// alongside the English forms (fixes from batch 1 review).
    func testBatch1AcceptsNaturalSpanishAlternatives() throws {
        let pack = try spanishPack()

        // Café exchange comprehension: answer in Spanish.
        var result = try gradeText("es-cafe-requests-foundation-read", in: pack, "Dos.")
        XCTAssertTrue(result.accepted, "Dos. must be accepted")
        result = try gradeText("es-cafe-requests-foundation-read", in: pack, "Two.")
        XCTAssertTrue(result.accepted)

        // Price board comprehension: answer in Spanish or as a numeral.
        result = try gradeText("es-numbers-quantities-foundation-read", in: pack, "Tres euros.")
        XCTAssertTrue(result.accepted, "Tres euros. must be accepted")
        result = try gradeText("es-numbers-quantities-foundation-read", in: pack, "3 euros.")
        XCTAssertTrue(result.accepted, "3 euros. must be accepted")

        // Short café request: the full polite form is correct Spanish too.
        result = try gradeText("es-cafe-requests-foundation-recall", in: pack, "Quisiera un café, por favor.")
        XCTAssertTrue(result.accepted, "full polite request must be accepted")
    }
}