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
        "Each pairing must use listed items exactly once.",
        "Each region counts once. Try again.",
    ]

    /// Grade a single cloze blank against its authored AnswerSpec.
    private func gradeClozeBlank(
        _ id: String, in pack: CoursePack, blank: String, _ response: String
    ) throws -> AnswerEvaluation {
        let act = try activity(id, in: pack)
        guard case .cloze(let spec) = act else {
            throw XCTSkip("expected a cloze activity for \(id)")
        }
        let blankSpec = try XCTUnwrap(spec.blanks[blank], "missing blank \(blank) in \(id)")
        return AnswerEngine.evaluate(response: response, spec: blankSpec)
    }

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

    /// The seven mission-family lessons outside es-unit-1/es-unit-2
    /// (wave B scope), keyed by their graded path activities.
    private static let batch2Lessons: [String: [String]] = [
        "es-directions-foundation": [
            "es-directions-foundation-act-rb2", "es-directions-foundation-meet",
            "es-directions-foundation-build", "es-directions-foundation-cloze",
            "es-directions-foundation-ask", "es-directions-foundation-act-rb3",
            "es-directions-foundation-vary",
        ],
        "es-find-cafe-mission": [
            "es-find-cafe-mission-act-2", "es-find-cafe-mission-act-3",
            "es-find-cafe-mission-act-5", "es-find-cafe-mission-act-6",
            "es-find-cafe-mission-act-7", "es-find-cafe-mission-act-8",
            "es-find-cafe-mission-act-10",
        ],
        "es-directions-mission": [
            "es-directions-mission-act-2", "es-directions-mission-act-3",
            "es-directions-mission-act-5", "es-directions-mission-act-6",
            "es-directions-mission-act-7", "es-directions-mission-act-8",
            "es-directions-mission-act-9", "es-directions-mission-act-10",
        ],
        "es-party-mission": [
            "es-party-mission-act-2", "es-party-mission-act-3",
            "es-party-mission-act-4", "es-party-mission-act-5",
            "es-party-mission-act-6", "es-party-mission-act-7",
            "es-party-mission-act-8", "es-party-mission-act-9",
            "es-party-mission-act-10",
        ],
        "es-market-foundation": [
            "es-market-foundation-meet", "es-market-foundation-notice",
            "es-market-foundation-build", "es-market-foundation-fill",
            "es-market-foundation-think", "es-market-foundation-act-rb2",
            "es-market-foundation-write",
        ],
        "es-pharmacy-foundation": [
            "es-pharmacy-foundation-meet", "es-pharmacy-foundation-notice",
            "es-pharmacy-foundation-build", "es-pharmacy-foundation-fill",
            "es-pharmacy-foundation-think", "es-pharmacy-foundation-act-rb2",
            "es-pharmacy-foundation-write",
        ],
        "es-a2-hotel-mission": [
            "es-a2-hotel-mission-act-2", "es-a2-hotel-mission-act-3",
            "es-a2-hotel-mission-act-4", "es-a2-hotel-mission-act-5",
            "es-a2-hotel-mission-act-6", "es-a2-hotel-mission-act-7",
            "es-a2-hotel-mission-act-8", "es-a2-hotel-mission-act-9",
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

    // MARK: - Wave B (missions outside units 1–2, rubric H4/H3)

    /// Every graded step in wave-B lessons has a real authored hint
    /// (audit_editorial hint-gap must stay 0 for these lessons).
    func testBatch2GradedStepsHaveAuthoredHints() throws {
        let pack = try spanishPack()
        for (lessonId, activityIds) in Self.batch2Lessons {
            for activityId in activityIds {
                let act = try activity(activityId, in: pack)
                let base = try XCTUnwrap(act.base, "\(lessonId): \(activityId) has no graded base")
                XCTAssertFalse(
                    base.hints.allSatisfy { Self.genericHints.contains($0) },
                    "\(lessonId): \(activityId) lacks an authored hint: \(base.hints)")
            }
        }
    }

    /// Every text answer and every cloze blank in wave-B lessons authors
    /// error-specific feedback (audit_editorial error-gap must stay 0).
    func testBatch2TextAndClozeActivitiesAuthorErrors() throws {
        let pack = try spanishPack()
        for (lessonId, activityIds) in Self.batch2Lessons {
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

    /// Plausible wrong answers in wave-B lessons hit their authored category
    /// + explanation (text and cloze surfaces).
    func testBatch2AuthoredErrorsFireForPlausibleWrongAnswers() throws {
        let pack = try spanishPack()

        // es-directions-foundation-ask
        var result = try gradeText("es-directions-foundation-ask", in: pack, "¿Dónde es el baño?")
        XCTAssertEqual(result.category, "wrong conjugation")
        XCTAssertFalse(result.accepted)
        result = try gradeText("es-directions-foundation-ask", in: pack, "¿Dónde está la baño?")
        XCTAssertEqual(result.category, "wrong article")
        result = try gradeText("es-directions-foundation-ask", in: pack, "¿Dónde está baño?")
        XCTAssertEqual(result.category, "missing word")

        // es-directions-foundation-vary
        result = try gradeText("es-directions-foundation-vary", in: pack, "¿Dónde está la estación?")
        XCTAssertEqual(result.category, "missing word", "Perdone must be flagged as missing")
        result = try gradeText("es-directions-foundation-vary", in: pack, "Perdona, ¿dónde está la estación?")
        XCTAssertEqual(result.category, "wrong conjugation")

        // es-directions-foundation-cloze b1
        result = try gradeClozeBlank("es-directions-foundation-cloze", in: pack, blank: "b1", "derecha")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeClozeBlank("es-directions-foundation-cloze", in: pack, blank: "b1", "izquierdo")
        XCTAssertEqual(result.category, "wrong gender")

        // es-find-cafe-mission-act-10
        result = try gradeText("es-find-cafe-mission-act-10", in: pack, "La cuenta.")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeText("es-find-cafe-mission-act-10", in: pack, "Cuenta, por favor.")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeText("es-find-cafe-mission-act-10", in: pack, "La cuenta, porfavor.")
        XCTAssertEqual(result.category, "incorrect answer")

        // es-find-cafe-mission-act-6 b1
        result = try gradeClozeBlank("es-find-cafe-mission-act-6", in: pack, blank: "b1", "izquierda")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeClozeBlank("es-find-cafe-mission-act-6", in: pack, blank: "b1", "derecho")
        XCTAssertEqual(result.category, "wrong gender")

        // es-directions-mission-act-9
        result = try gradeText("es-directions-mission-act-9", in: pack, "¿Dónde es el museo?")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("es-directions-mission-act-9", in: pack, "¿Dónde está museo?")
        XCTAssertEqual(result.category, "missing word")

        // es-directions-mission-act-10
        result = try gradeText("es-directions-mission-act-10", in: pack, "Hola.")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeText("es-directions-mission-act-10", in: pack, "Adiós. Gracias.")
        XCTAssertEqual(result.category, "incorrect answer")

        // es-party-mission-act-9
        result = try gradeText("es-party-mission-act-9", in: pack, "Mucho gusta.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("es-party-mission-act-9", in: pack, "Mucho gracias.")
        XCTAssertEqual(result.category, "incorrect answer")

        // es-party-mission-act-8 b1
        result = try gradeClozeBlank("es-party-mission-act-8", in: pack, blank: "b1", "La")
        XCTAssertEqual(result.category, "wrong article")
        result = try gradeClozeBlank("es-party-mission-act-8", in: pack, blank: "b1", "Los")
        XCTAssertEqual(result.category, "wrong number")

        // es-market-foundation-think
        result = try gradeText("es-market-foundation-think", in: pack, "Un botella de agua, por favor.")
        XCTAssertEqual(result.category, "wrong article")
        result = try gradeText("es-market-foundation-think", in: pack, "Una botella de agua.")
        XCTAssertEqual(result.category, "missing word")

        // es-market-foundation-write
        result = try gradeText("es-market-foundation-write", in: pack, "Esta pan está fresco.")
        XCTAssertEqual(result.category, "wrong article")
        result = try gradeText("es-market-foundation-write", in: pack, "Este pan es fresco.")
        XCTAssertEqual(result.category, "wrong conjugation")

        // es-pharmacy-foundation-think
        result = try gradeText("es-pharmacy-foundation-think", in: pack, "Necesito esta pastillas.")
        XCTAssertEqual(result.category, "wrong number")
        result = try gradeText("es-pharmacy-foundation-think", in: pack, "Necesito estos pastillas.")
        XCTAssertEqual(result.category, "wrong article")

        // es-pharmacy-foundation-write
        result = try gradeText("es-pharmacy-foundation-write", in: pack, "Necesito un receta.")
        XCTAssertEqual(result.category, "wrong article")
        result = try gradeText("es-pharmacy-foundation-write", in: pack, "Necesito receta.")
        XCTAssertEqual(result.category, "missing word")

        // es-a2-hotel-mission-act-3
        result = try gradeText("es-a2-hotel-mission-act-3", in: pack, "Tengo una reserva con nombre de García.")
        XCTAssertEqual(result.category, "wrong preposition")
        result = try gradeText("es-a2-hotel-mission-act-3", in: pack, "Tengo una reserva nombre de García.")
        XCTAssertEqual(result.category, "missing word")

        // es-a2-hotel-mission-act-8 / act-9
        result = try gradeText("es-a2-hotel-mission-act-8", in: pack, "La habitación es muy bien.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("es-a2-hotel-mission-act-9", in: pack, "¿Qué hora es el desayuno?")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeText("es-a2-hotel-mission-act-9", in: pack, "¿A qué hora está el desayuno?")
        XCTAssertEqual(result.category, "wrong conjugation")
    }

    /// The authored accepted answers for wave-B text surfaces stay accepted.
    func testBatch2AcceptsAuthoredAnswers() throws {
        let pack = try spanishPack()

        var result = try gradeText("es-find-cafe-mission-act-10", in: pack, "La cuenta, por favor.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("es-find-cafe-mission-act-10", in: pack, "La cuenta por favor.")
        XCTAssertTrue(result.accepted, "comma-less polite form is authored")

        result = try gradeText("es-party-mission-act-10", in: pack, "Me llamo Leo.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("es-party-mission-act-10", in: pack, "Soy Leo.")
        XCTAssertTrue(result.accepted, "Soy alternative is authored")

        result = try gradeText("es-a2-hotel-mission-act-9", in: pack, "¿A qué hora es el desayuno?")
        XCTAssertTrue(result.accepted)

        result = try gradeText("es-directions-mission-act-10", in: pack, "Hola. Gracias.")
        XCTAssertTrue(result.accepted)

        result = try gradeClozeBlank("es-market-foundation-fill", in: pack, blank: "b1", "botella")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank("es-pharmacy-foundation-fill", in: pack, blank: "b1", "cerca")
        XCTAssertTrue(result.accepted)
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