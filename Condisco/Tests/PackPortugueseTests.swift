import XCTest
@testable import Condisco

/// Per-pack editorial regression tests for the Portuguese pack.
///
/// Owned by the Portuguese editorial lane: add targeted answer/evaluation
/// tests here for content fixes (resolved high-confidence errors,
/// narrowed accepted-answer sets, authored error feedback). Do not put
/// other packs' tests in this file.
final class PackPortugueseTests: XCTestCase {

    // MARK: - Helpers

    private func portuguesePack() throws -> CoursePack {
        try XCTUnwrap(PackLoader.loadPacks().first { $0.language.slug == "portuguese" })
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

    /// The engine's generic fallbacks (audit_editorial.swift genericHints):
    /// an activity whose hints are all in this set has no authored hint.
    private static let genericHints: Set<String> = [
        "Try it", "Try again", "Not quite — try again.",
        "That selection is not valid. Try again.",
        "The order is not right yet. Try again.",
        "Some pairs are off. Try again.",
        "Place every token exactly once.",
        "Each pairing must use listed items exactly once.",
        "Each region counts once. Try again.",
    ]

    /// The three pt-unit-1 and one pt-unit-2 lessons of batch 1, keyed by
    /// the path activity ids each lesson references (graded steps only).
    private static let batch1Lessons: [String: [String]] = [
        "pt-cafe-mission": [
            "pt-cafe-mission-act-2", "pt-cafe-mission-act-4",
            "pt-cafe-mission-act-6", "pt-cafe-mission-act-7",
            "pt-cafe-mission-act-8", "pt-cafe-mission-act-9",
        ],
        "pt-introductions-foundation": [
            "pt-introductions-foundation-notice", "pt-introductions-foundation-build",
            "pt-introductions-foundation-ask", "pt-introductions-foundation-recall",
            "pt-introductions-foundation-read", "pt-introductions-foundation-reply",
        ],
        "pt-cafe-requests-foundation": [
            "pt-cafe-requests-foundation-choose", "pt-cafe-requests-foundation-build",
            "pt-cafe-requests-foundation-vary", "pt-cafe-requests-foundation-recall",
            "pt-cafe-requests-foundation-read", "pt-cafe-requests-foundation-meaning",
        ],
        "pt-numbers-quantities-foundation": [
            "pt-numbers-quantities-foundation-meet", "pt-numbers-quantities-foundation-quantity",
            "pt-numbers-quantities-foundation-think", "pt-numbers-quantities-foundation-order",
        ],
    ]

    // MARK: - Pack load

    func testPortuguesePackLoadsAndValidates() throws {
        let packs = try PackLoader.loadPacks()
        let pack = try XCTUnwrap(packs.first { $0.language.slug == "portuguese" })
        XCTAssertFalse(pack.lessons.isEmpty, "Portuguese pack must ship lessons")
        XCTAssertNoThrow(try PackValidator.validate(pack), pack.id)
    }

    // MARK: - Hints (rubric H4)

    /// Every graded step in batch-1 lessons has a real authored hint, not the
    /// runtime generic fallbacks (audit_editorial hint-gap must stay 0).
    func testBatch1GradedStepsHaveAuthoredHints() throws {
        let pack = try portuguesePack()
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
    /// (audit_editorial error-feedback gap must stay 0 for these lessons).
    func testBatch1TextActivitiesAuthorErrors() throws {
        let pack = try portuguesePack()
        for (lessonId, activityIds) in Self.batch1Lessons {
            for activityId in activityIds {
                let act = try activity(activityId, in: pack)
                switch act {
                case .text(let spec):
                    XCTAssertFalse(
                        spec.answer.errors.isEmpty,
                        "\(lessonId): \(activityId) must author error feedback")
                case .cloze(let spec):
                    for (blank, blankSpec) in spec.blanks {
                        XCTAssertFalse(
                            blankSpec.errors.isEmpty,
                            "\(lessonId): \(activityId)#\(blank) must author error feedback")
                    }
                default:
                    break
                }
            }
        }
    }

    /// Plausible wrong answers hit their authored category + explanation.
    func testAuthoredErrorsFireForPlausibleWrongAnswers() throws {
        let pack = try portuguesePack()

        // pt-cafe-mission
        var result = try gradeText("pt-cafe-mission-act-7", in: pack, "Café, por favor.")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeText("pt-cafe-mission-act-7", in: pack, "Quero um café, por favor.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("pt-cafe-mission-act-9", in: pack, "Obrigado. Olá. Um café, por favor.")
        XCTAssertEqual(result.category, "word-order problem")
        result = try gradeText("pt-cafe-mission-act-9", in: pack, "Olá. Um café, por favor.")
        XCTAssertEqual(result.category, "missing word")

        // pt-introductions-foundation
        result = try gradeText("pt-introductions-foundation-ask", in: pack, "Qual e o seu nome?")
        XCTAssertEqual(result.category, "accent/diacritic issue")
        result = try gradeText("pt-introductions-foundation-ask", in: pack, "Qual é seu nome?")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeText("pt-introductions-foundation-recall", in: pack, "Meu nome é Ana.")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeText("pt-introductions-foundation-recall", in: pack, "O meu nome e Ana.")
        XCTAssertEqual(result.category, "accent/diacritic issue")
        result = try gradeText("pt-introductions-foundation-read", in: pack, "Ana")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("pt-introductions-foundation-reply", in: pack, "Obrigado")
        XCTAssertEqual(result.category, "incorrect answer")

        // pt-cafe-requests-foundation
        result = try gradeText("pt-cafe-requests-foundation-vary", in: pack, "Eu gostaria um chá, por favor.")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeText("pt-cafe-requests-foundation-vary", in: pack, "Quero um chá, por favor.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("pt-cafe-requests-foundation-recall", in: pack, "Eu gostaria de um café, por favor.")
        XCTAssertEqual(result.category, "extra word")
        result = try gradeText("pt-cafe-requests-foundation-read", in: pack, "Obrigado")
        XCTAssertEqual(result.category, "wrong gender")
        result = try gradeText("pt-cafe-requests-foundation-meaning", in: pack, "I want a coffee, please.")
        XCTAssertEqual(result.category, "incorrect answer")

        // pt-numbers-quantities-foundation
        result = try gradeText("pt-numbers-quantities-foundation-quantity", in: pack, "Dois maçãs, por favor.")
        XCTAssertEqual(result.category, "wrong gender")
        result = try gradeText("pt-numbers-quantities-foundation-quantity", in: pack, "Duas maças, por favor.")
        XCTAssertEqual(result.category, "accent/diacritic issue")
        result = try gradeText("pt-numbers-quantities-foundation-think", in: pack, "Quanto custa uma café?")
        XCTAssertEqual(result.category, "wrong gender")
        result = try gradeText("pt-numbers-quantities-foundation-think", in: pack, "Custa quanto um café?")
        XCTAssertEqual(result.category, "word-order problem")
    }

    // MARK: - Accepted answers (prompt ↔ answers alignment)

    /// The pack declares European Portuguese, so the possessive carries the
    /// article: O meu nome é Ana is the taught form. The Brazilian-style
    /// articleless Meu nome é Ana must not be accepted as the target.
    func testEuropeanPossessiveFormIsTheAcceptedTarget() throws {
        let pack = try portuguesePack()

        var result = try gradeText("pt-introductions-foundation-recall", in: pack, "O meu nome é Ana.")
        XCTAssertTrue(result.accepted, "European form O meu nome é Ana must be accepted")
        result = try gradeText("pt-introductions-foundation-recall", in: pack, "Meu nome é Ana.")
        XCTAssertFalse(result.accepted, "articleless Brazilian-style form must not pass")
        XCTAssertEqual(result.category, "missing word")

        // The ordering build must now score the five-token European form.
        let act = try activity("pt-introductions-foundation-build", in: pack)
        guard case .ordering = act else {
            throw XCTSkip("expected an ordering activity for pt-introductions-foundation-build")
        }
        let evaluation = ActivityEvaluation.evaluate(
            activity: act,
            response: .ordering(ids: ["t5", "t4", "t3", "t2", "t1"]),
            assistance: [])
        XCTAssertEqual(evaluation.outcome, .correct,
                       "O meu nome é Ana must be the accepted build order")
    }

    /// Natural full-line and fuller-form replies are accepted where a learner
    /// would not be wrong to give them.
    func testBatch1AcceptsNaturalAlternatives() throws {
        let pack = try portuguesePack()

        // Reading comprehension — the evidence line itself answers "who is it?".
        var result = try gradeText("pt-introductions-foundation-read", in: pack, "Sou Leo")
        XCTAssertTrue(result.accepted, "'Sou Leo' must be accepted")

        // The fuller introduction phrase is correct Portuguese too.
        result = try gradeText("pt-introductions-foundation-reply", in: pack, "Muito prazer.")
        XCTAssertTrue(result.accepted, "'Muito prazer.' must be accepted")

        // English meaning — the contracted form is already accepted.
        result = try gradeText("pt-cafe-requests-foundation-meaning", in: pack, "I'd like a coffee, please.")
        XCTAssertTrue(result.accepted, "'I'd like a coffee, please.' must be accepted")
    }

    // MARK: - Retained v1 legacy exercises stay in sync

    /// The lesson-level legacyExercises mirror the path activities; the
    /// regional possessive fix and the recalled answers must be in both.
    func testLegacyExercisesMatchEuropeanForms() throws {
        let pack = try portuguesePack()
        let lesson = try XCTUnwrap(pack.lesson(id: "pt-introductions-foundation"))
        let recall = try XCTUnwrap(
            lesson.legacyExercises.first { $0.id == "pt-introductions-foundation-recall" })
        XCTAssertTrue(
            recall.base.answers.contains("O meu nome é Ana."),
            "legacy recall must carry the European form: \(recall.base.answers)")
        let build = try XCTUnwrap(
            lesson.legacyExercises.first { $0.id == "pt-introductions-foundation-build" })
        XCTAssertTrue(
            build.base.answers.contains("O meu nome é Ana."),
            "legacy build must carry the European form: \(build.base.answers)")
    }
}