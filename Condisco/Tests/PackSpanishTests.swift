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

    /// The eight story-family lessons of wave C (units 7–14), keyed by
    /// their six graded path activities.
    private static let batch3Lessons: [String: [String]] = [
        "es-home-foundation": [
            "es-home-foundation-meet", "es-home-foundation-think",
            "es-home-foundation-notice", "es-home-foundation-fill",
            "es-home-foundation-write", "es-home-foundation-act-rb3",
        ],
        "es-routine-foundation": [
            "es-routine-foundation-meet", "es-routine-foundation-think",
            "es-routine-foundation-notice", "es-routine-foundation-fill",
            "es-routine-foundation-write", "es-routine-foundation-act-rb3",
        ],
        "es-food-foundation": [
            "es-food-foundation-meet", "es-food-foundation-think",
            "es-food-foundation-notice", "es-food-foundation-fill",
            "es-food-foundation-write", "es-food-foundation-act-rb3",
        ],
        "es-transport-foundation": [
            "es-transport-foundation-meet", "es-transport-foundation-think",
            "es-transport-foundation-notice", "es-transport-foundation-fill",
            "es-transport-foundation-write", "es-transport-foundation-act-rb3",
        ],
        "es-weather-foundation": [
            "es-weather-foundation-meet", "es-weather-foundation-think",
            "es-weather-foundation-notice", "es-weather-foundation-fill",
            "es-weather-foundation-write", "es-weather-foundation-act-rb3",
        ],
        "es-health-foundation": [
            "es-health-foundation-meet", "es-health-foundation-think",
            "es-health-foundation-notice", "es-health-foundation-fill",
            "es-health-foundation-write", "es-health-foundation-act-rb3",
        ],
        "es-a2-imperfecto": [
            "es-a2-imperfecto-meet", "es-a2-imperfecto-think",
            "es-a2-imperfecto-notice", "es-a2-imperfecto-fill",
            "es-a2-imperfecto-write", "es-a2-imperfecto-act-rb3",
        ],
        "es-a2-futuro-usos": [
            "es-a2-futuro-usos-meet", "es-a2-futuro-usos-think",
            "es-a2-futuro-usos-notice", "es-a2-futuro-usos-fill",
            "es-a2-futuro-usos-write", "es-a2-futuro-usos-act-rb3",
        ],
    ]

    // MARK: - Wave C (story family, units 7–14, rubric H4/H3 + M5)

    /// Every graded step in wave-C story lessons has a real authored hint
    /// (audit_editorial hint-gap must stay 0 for these lessons).
    func testBatch3GradedStepsHaveAuthoredHints() throws {
        let pack = try spanishPack()
        for (lessonId, activityIds) in Self.batch3Lessons {
            for activityId in activityIds {
                let act = try activity(activityId, in: pack)
                let base = try XCTUnwrap(act.base, "\(lessonId): \(activityId) has no graded base")
                XCTAssertFalse(
                    base.hints.allSatisfy { Self.genericHints.contains($0) },
                    "\(lessonId): \(activityId) lacks an authored hint: \(base.hints)")
            }
        }
    }

    /// Every text answer and every cloze blank in wave-C lessons authors
    /// error-specific feedback (audit_editorial error-gap must stay 0).
    func testBatch3TextAndClozeActivitiesAuthorErrors() throws {
        let pack = try spanishPack()
        for (lessonId, activityIds) in Self.batch3Lessons {
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

    /// Every wave-C story lesson closes with a text final-response step (M5)
    /// and carries a non-empty objective (M2).
    func testBatch3StoryLessonsEndWithTextFinalResponse() throws {
        let pack = try spanishPack()
        for lessonId in Self.batch3Lessons.keys {
            let lesson = try XCTUnwrap(pack.lessons.first { $0.id == lessonId }, "missing lesson \(lessonId)")
            XCTAssertEqual(lesson.family, .story, "\(lessonId) must be a story lesson")
            XCTAssertFalse(
                lesson.objective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                "\(lessonId) must have an objective")
            let terminals = lesson.steps.filter { $0.nextStepId == nil && $0.branches.isEmpty }
            XCTAssertFalse(terminals.isEmpty, "\(lessonId) must have a terminal step")
            var hasTextTerminal = false
            for step in terminals {
                let act = try activity(step.activityId, in: pack)
                if case .text = act { hasTextTerminal = true }
            }
            XCTAssertTrue(hasTextTerminal, "\(lessonId) must end with a text final-response step (M5)")
        }
    }

    /// Plausible wrong answers in wave-C lessons hit their authored category
    /// + explanation (text and cloze surfaces).
    func testBatch3AuthoredErrorsFireForPlausibleWrongAnswers() throws {
        let pack = try spanishPack()

        // es-home-foundation
        var result = try gradeText("es-home-foundation-think", in: pack, "La mesa es en la cocina.")
        XCTAssertEqual(result.category, "wrong conjugation")
        XCTAssertFalse(result.accepted)
        result = try gradeText("es-home-foundation-think", in: pack, "La mesa está en cocina.")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeClozeBlank("es-home-foundation-fill", in: pack, blank: "b1", "La")
        XCTAssertEqual(result.category, "wrong article")
        result = try gradeClozeBlank("es-home-foundation-fill", in: pack, blank: "b1", "Los")
        XCTAssertEqual(result.category, "wrong number")
        result = try gradeText("es-home-foundation-write", in: pack, "Vengo de el salón.")
        XCTAssertEqual(result.category, "extra word")
        result = try gradeText("es-home-foundation-write", in: pack, "Vengo del baño.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("es-home-foundation-act-rb3", in: pack, "La cocina es grande y las dormitorios son pequeños.")
        XCTAssertEqual(result.category, "wrong article")

        // es-routine-foundation
        result = try gradeText("es-routine-foundation-think", in: pack, "Estudiar por la tarde.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("es-routine-foundation-think", in: pack, "Estudia en la tarde.")
        XCTAssertEqual(result.category, "wrong preposition")
        result = try gradeClozeBlank("es-routine-foundation-fill", in: pack, blank: "b1", "trabajo")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("es-routine-foundation-write", in: pack, "Estudio en la noche.")
        XCTAssertEqual(result.category, "wrong preposition")
        result = try gradeText("es-routine-foundation-act-rb3", in: pack, "Trabaja por la mañana y estudio por la noche.")
        XCTAssertEqual(result.category, "wrong conjugation")

        // es-food-foundation
        result = try gradeText("es-food-foundation-think", in: pack, "Beber agua.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("es-food-foundation-think", in: pack, "Bebo el agua.")
        XCTAssertEqual(result.category, "extra word")
        result = try gradeClozeBlank("es-food-foundation-fill", in: pack, blank: "b1", "bebe")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("es-food-foundation-write", in: pack, "Como pan.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("es-food-foundation-act-rb3", in: pack, "Me gusto el pan y bebo agua.")
        XCTAssertEqual(result.category, "wrong conjugation")

        // es-transport-foundation
        result = try gradeText("es-transport-foundation-think", in: pack, "Voy a pie.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("es-transport-foundation-think", in: pack, "Vamos en pie.")
        XCTAssertEqual(result.category, "wrong preposition")
        result = try gradeClozeBlank("es-transport-foundation-fill", in: pack, blank: "b1", "Como")
        XCTAssertEqual(result.category, "accent/diacritic issue")
        result = try gradeText("es-transport-foundation-write", in: pack, "Voy a Madrid en coche.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("es-transport-foundation-act-rb3", in: pack, "Voy en metro y luego en pie.")
        XCTAssertEqual(result.category, "wrong preposition")

        // es-weather-foundation
        result = try gradeText("es-weather-foundation-think", in: pack, "Está frío.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("es-weather-foundation-think", in: pack, "Hace caliente.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("es-weather-foundation-think", in: pack, "Hace frio.")
        XCTAssertEqual(result.category, "accent/diacritic issue")
        result = try gradeClozeBlank("es-weather-foundation-fill", in: pack, blank: "b1", "es")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeClozeBlank("es-weather-foundation-fill", in: pack, blank: "b1", "esta")
        XCTAssertEqual(result.category, "accent/diacritic issue")
        result = try gradeText("es-weather-foundation-write", in: pack, "Hace nublado.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("es-weather-foundation-act-rb3", in: pack, "Es sol aquí y hace frío en las montañas.")
        XCTAssertEqual(result.category, "wrong conjugation")

        // es-health-foundation
        result = try gradeText("es-health-foundation-think", in: pack, "Me duele las manos.")
        XCTAssertEqual(result.category, "wrong number")
        result = try gradeText("es-health-foundation-think", in: pack, "Me duelo las manos.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeClozeBlank("es-health-foundation-fill", in: pack, blank: "b1", "mi cabeza")
        XCTAssertEqual(result.category, "wrong article")
        result = try gradeClozeBlank("es-health-foundation-fill", in: pack, blank: "b1", "cabeza")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeText("es-health-foundation-write", in: pack, "Estoy fiebre.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("es-health-foundation-write", in: pack, "Tengo la fiebre.")
        XCTAssertEqual(result.category, "extra word")
        result = try gradeText("es-health-foundation-act-rb3", in: pack, "Me duele mi cabeza y tengo fiebre.")
        XCTAssertEqual(result.category, "wrong article")

        // es-a2-imperfecto
        result = try gradeText("es-a2-imperfecto-think", in: pack, "fue")
        XCTAssertEqual(result.category, "wrong tense")
        result = try gradeText("es-a2-imperfecto-think", in: pack, "es")
        XCTAssertEqual(result.category, "wrong tense")
        result = try gradeClozeBlank("es-a2-imperfecto-fill", in: pack, blank: "b1", "jugué")
        XCTAssertEqual(result.category, "wrong tense")
        result = try gradeText("es-a2-imperfecto-write", in: pack, "Hay mucha gente en la plaza.")
        XCTAssertEqual(result.category, "wrong tense")
        result = try gradeText("es-a2-imperfecto-write", in: pack, "Había mucha gente en el plaza.")
        XCTAssertEqual(result.category, "wrong article")
        result = try gradeText("es-a2-imperfecto-act-rb3", in: pack, "De niño jugué al fútbol todos los días.")
        XCTAssertEqual(result.category, "wrong tense")

        // es-a2-futuro-usos
        result = try gradeText("es-a2-futuro-usos-think", in: pack, "Hay")
        XCTAssertEqual(result.category, "wrong tense")
        result = try gradeText("es-a2-futuro-usos-think", in: pack, "Habra")
        XCTAssertEqual(result.category, "accent/diacritic issue")
        result = try gradeClozeBlank("es-a2-futuro-usos-fill", in: pack, blank: "b1", "Cree")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeClozeBlank("es-a2-futuro-usos-fill", in: pack, blank: "b1", "Creo que")
        XCTAssertEqual(result.category, "extra word")
        result = try gradeText("es-a2-futuro-usos-write", in: pack, "Creo que llueve mañana.")
        XCTAssertEqual(result.category, "wrong tense")
        result = try gradeText("es-a2-futuro-usos-write", in: pack, "Creo que llovera mañana.")
        XCTAssertEqual(result.category, "accent/diacritic issue")
        result = try gradeText("es-a2-futuro-usos-act-rb3", in: pack, "Probablemente viene mañana.")
        XCTAssertEqual(result.category, "wrong tense")
    }

    /// The authored accepted answers for wave-C surfaces stay accepted,
    /// including the natural Spanish alternatives.
    func testBatch3AcceptsAuthoredAnswers() throws {
        let pack = try spanishPack()

        var result = try gradeText("es-home-foundation-think", in: pack, "La mesa está en la cocina.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("es-home-foundation-write", in: pack, "Vengo del salón.")
        XCTAssertTrue(result.accepted)

        result = try gradeText("es-routine-foundation-think", in: pack, "Ella estudia por la tarde.")
        XCTAssertTrue(result.accepted, "Ella alternative is authored")

        result = try gradeText("es-food-foundation-write", in: pack, "Ella come pan.")
        XCTAssertTrue(result.accepted, "Ella alternative is authored")

        result = try gradeText("es-transport-foundation-write", in: pack, "Él va a Madrid en coche.")
        XCTAssertTrue(result.accepted, "Él alternative is authored")

        result = try gradeText("es-weather-foundation-act-rb3", in: pack, "Hace sol aquí y hace frío en las montañas.")
        XCTAssertTrue(result.accepted)

        result = try gradeClozeBlank("es-health-foundation-fill", in: pack, blank: "b1", "la cabeza")
        XCTAssertTrue(result.accepted)

        result = try gradeText("es-a2-imperfecto-act-rb3", in: pack, "Cuando era niño jugaba al fútbol todos los días.")
        XCTAssertTrue(result.accepted, "cuando-era alternative is authored")

        result = try gradeText("es-a2-futuro-usos-write", in: pack, "Creo que mañana lloverá.")
        XCTAssertTrue(result.accepted, "mañana-first alternative is authored")
    }

    // MARK: - Wave D (discovery family outside units 1–2, rubric H4/H3)

    /// The thirteen discovery-family lessons of wave D (units 4–17), keyed
    /// by their seven graded path activities.
    private static let batch4Lessons: [String: [String]] = [
        "es-time-days-foundation": [
            "es-time-days-foundation-meet", "es-time-days-foundation-think",
            "es-time-days-foundation-build", "es-time-days-foundation-notice",
            "es-time-days-foundation-cloze", "es-time-days-foundation-meaning",
            "es-time-days-foundation-read",
        ],
        "es-descriptions-foundation": [
            "es-descriptions-foundation-meet", "es-descriptions-foundation-think",
            "es-descriptions-foundation-build", "es-descriptions-foundation-notice",
            "es-descriptions-foundation-fill", "es-descriptions-foundation-write",
            "es-descriptions-foundation-read",
        ],
        "es-past-foundation": [
            "es-past-foundation-build", "es-past-foundation-meet",
            "es-past-foundation-think", "es-past-foundation-fill",
            "es-past-foundation-notice", "es-past-foundation-write",
            "es-past-foundation-read",
        ],
        "es-months-foundation": [
            "es-months-foundation-meet", "es-months-foundation-think",
            "es-months-foundation-build", "es-months-foundation-notice",
            "es-months-foundation-fill", "es-months-foundation-write",
            "es-months-foundation-read",
        ],
        "es-emergency-foundation": [
            "es-emergency-foundation-build", "es-emergency-foundation-meet",
            "es-emergency-foundation-think", "es-emergency-foundation-fill",
            "es-emergency-foundation-notice", "es-emergency-foundation-write",
            "es-emergency-foundation-read",
        ],
        "es-a2-preterito-formacion": [
            "es-a2-preterito-formacion-meet", "es-a2-preterito-formacion-think",
            "es-a2-preterito-formacion-build", "es-a2-preterito-formacion-notice",
            "es-a2-preterito-formacion-fill", "es-a2-preterito-formacion-write",
            "es-a2-preterito-formacion-read",
        ],
        "es-a2-futuro-formacion": [
            "es-a2-futuro-formacion-build", "es-a2-futuro-formacion-meet",
            "es-a2-futuro-formacion-think", "es-a2-futuro-formacion-fill",
            "es-a2-futuro-formacion-notice", "es-a2-futuro-formacion-write",
            "es-a2-futuro-formacion-read",
        ],
        "es-a2-planes-intenciones": [
            "es-a2-planes-intenciones-meet", "es-a2-planes-intenciones-fill",
            "es-a2-planes-intenciones-think", "es-a2-planes-intenciones-build",
            "es-a2-planes-intenciones-notice", "es-a2-planes-intenciones-write",
            "es-a2-planes-intenciones-read",
        ],
        "es-a2-subjuntivo-intro": [
            "es-a2-subjuntivo-intro-meet", "es-a2-subjuntivo-intro-think",
            "es-a2-subjuntivo-intro-build", "es-a2-subjuntivo-intro-notice",
            "es-a2-subjuntivo-intro-fill", "es-a2-subjuntivo-intro-write",
            "es-a2-subjuntivo-intro-read",
        ],
        "es-a2-comparativos": [
            "es-a2-comparativos-meet", "es-a2-comparativos-fill",
            "es-a2-comparativos-think", "es-a2-comparativos-build",
            "es-a2-comparativos-notice", "es-a2-comparativos-write",
            "es-a2-comparativos-read",
        ],
        "es-a2-por-para": [
            "es-a2-por-para-build", "es-a2-por-para-meet",
            "es-a2-por-para-think", "es-a2-por-para-fill",
            "es-a2-por-para-notice", "es-a2-por-para-write",
            "es-a2-por-para-read",
        ],
        "es-a2-superlativos": [
            "es-a2-superlativos-meet", "es-a2-superlativos-fill",
            "es-a2-superlativos-think", "es-a2-superlativos-build",
            "es-a2-superlativos-notice", "es-a2-superlativos-write",
            "es-a2-superlativos-read",
        ],
        "es-a2-tecnologia": [
            "es-a2-tecnologia-meet", "es-a2-tecnologia-fill",
            "es-a2-tecnologia-think", "es-a2-tecnologia-build",
            "es-a2-tecnologia-notice", "es-a2-tecnologia-write",
            "es-a2-tecnologia-read",
        ],
    ]

    /// Every graded step in wave-D discovery lessons has a real authored hint
    /// (audit_editorial hint-gap must stay 0 for these lessons).
    func testBatch4GradedStepsHaveAuthoredHints() throws {
        let pack = try spanishPack()
        for (lessonId, activityIds) in Self.batch4Lessons {
            for activityId in activityIds {
                let act = try activity(activityId, in: pack)
                let base = try XCTUnwrap(act.base, "\(lessonId): \(activityId) has no graded base")
                XCTAssertFalse(
                    base.hints.allSatisfy { Self.genericHints.contains($0) },
                    "\(lessonId): \(activityId) lacks an authored hint: \(base.hints)")
            }
        }
    }

    /// Every text answer and every cloze blank in wave-D lessons authors
    /// error-specific feedback (audit_editorial error-gap must stay 0).
    func testBatch4TextAndClozeActivitiesAuthorErrors() throws {
        let pack = try spanishPack()
        for (lessonId, activityIds) in Self.batch4Lessons {
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

    /// Every wave-D discovery lesson carries a non-empty objective (M2) and
    /// closes with a text final-response step (M5 outcome coherence).
    func testBatch4DiscoveryLessonsEndWithTextFinalResponse() throws {
        let pack = try spanishPack()
        for lessonId in Self.batch4Lessons.keys {
            let lesson = try XCTUnwrap(pack.lessons.first { $0.id == lessonId }, "missing lesson \(lessonId)")
            XCTAssertEqual(lesson.family, .discovery, "\(lessonId) must be a discovery lesson")
            XCTAssertFalse(
                lesson.objective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                "\(lessonId) must have an objective")
            let terminals = lesson.steps.filter { $0.nextStepId == nil && $0.branches.isEmpty }
            XCTAssertFalse(terminals.isEmpty, "\(lessonId) must have a terminal step")
            var hasTextTerminal = false
            for step in terminals {
                let act = try activity(step.activityId, in: pack)
                if case .text = act { hasTextTerminal = true }
            }
            XCTAssertTrue(hasTextTerminal, "\(lessonId) must end with a text final-response step (M5)")
        }
    }

    /// Plausible wrong answers in wave-D lessons hit their authored category
    /// + explanation (text and cloze surfaces).
    func testBatch4AuthoredErrorsFireForPlausibleWrongAnswers() throws {
        let pack = try spanishPack()

        // es-time-days-foundation
        var result = try gradeClozeBlank("es-time-days-foundation-cloze", in: pack, blank: "b1", "El")
        XCTAssertEqual(result.category, "wrong number")
        XCTAssertFalse(result.accepted)
        result = try gradeText("es-time-days-foundation-think", in: pack, "Hoy está viernes.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("es-time-days-foundation-meaning", in: pack, "Monday I work.")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeText("es-time-days-foundation-read", in: pack, "Martes.")
        XCTAssertEqual(result.category, "incorrect answer")

        // es-descriptions-foundation
        result = try gradeClozeBlank("es-descriptions-foundation-fill", in: pack, blank: "b1", "nueva")
        XCTAssertEqual(result.category, "wrong gender")
        result = try gradeText("es-descriptions-foundation-think", in: pack, "El casa es grande.")
        XCTAssertEqual(result.category, "wrong article")
        result = try gradeText("es-descriptions-foundation-write", in: pack, "Son alto.")
        XCTAssertEqual(result.category, "wrong number")
        result = try gradeText("es-descriptions-foundation-read", in: pack, "Nueva.")
        XCTAssertEqual(result.category, "incorrect answer")

        // es-past-foundation
        result = try gradeClozeBlank("es-past-foundation-fill", in: pack, blank: "b1", "hablo")
        XCTAssertEqual(result.category, "wrong tense")
        result = try gradeText("es-past-foundation-think", in: pack, "Como pan.")
        XCTAssertEqual(result.category, "wrong tense")
        result = try gradeText("es-past-foundation-write", in: pack, "Ayer trabajo mucho.")
        XCTAssertEqual(result.category, "wrong tense")
        result = try gradeText("es-past-foundation-read", in: pack, "Con mi familia.")
        XCTAssertEqual(result.category, "incorrect answer")

        // es-months-foundation
        result = try gradeClozeBlank("es-months-foundation-fill", in: pack, blank: "b1", "enero")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("es-months-foundation-think", in: pack, "Mi cumpleaños es junio.")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeText("es-months-foundation-write", in: pack, "Hoy es mayo 3.")
        XCTAssertEqual(result.category, "word-order problem")
        result = try gradeText("es-months-foundation-read", in: pack, "El 10 de enero.")
        XCTAssertEqual(result.category, "incorrect answer")

        // es-emergency-foundation
        result = try gradeClozeBlank("es-emergency-foundation-fill", in: pack, blank: "b1", "Ayuda")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("es-emergency-foundation-think", in: pack, "¿Dónde es el hospital?")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("es-emergency-foundation-write", in: pack, "Necesito la ayuda.")
        XCTAssertEqual(result.category, "extra word")

        // es-a2-preterito-formacion
        result = try gradeClozeBlank("es-a2-preterito-formacion-fill", in: pack, blank: "b1", "hago")
        XCTAssertEqual(result.category, "wrong tense")
        result = try gradeText("es-a2-preterito-formacion-think", in: pack, "comi")
        XCTAssertEqual(result.category, "accent/diacritic issue")
        result = try gradeText("es-a2-preterito-formacion-write", in: pack, "Me dijo no.")
        XCTAssertEqual(result.category, "missing word")

        // es-a2-futuro-formacion
        result = try gradeClozeBlank("es-a2-futuro-formacion-fill", in: pack, blank: "b1", "saliremos")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("es-a2-futuro-formacion-think", in: pack, "comía")
        XCTAssertEqual(result.category, "wrong tense")
        result = try gradeText("es-a2-futuro-formacion-write", in: pack, "Comemos a las dos.")
        XCTAssertEqual(result.category, "wrong tense")

        // es-a2-planes-intenciones
        result = try gradeClozeBlank("es-a2-planes-intenciones-fill", in: pack, blank: "b1", "Voy")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("es-a2-planes-intenciones-think", in: pack, "Vamos")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("es-a2-planes-intenciones-write", in: pack, "Vamos a viajamos en verano.")
        XCTAssertEqual(result.category, "wrong conjugation")

        // es-a2-subjuntivo-intro
        result = try gradeClozeBlank("es-a2-subjuntivo-intro-fill", in: pack, blank: "b1", "vienes")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("es-a2-subjuntivo-intro-think", in: pack, "hablas")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("es-a2-subjuntivo-intro-write", in: pack, "Es importante que estudias.")
        XCTAssertEqual(result.category, "wrong conjugation")

        // es-a2-comparativos
        result = try gradeClozeBlank("es-a2-comparativos-fill", in: pack, blank: "b1", "más")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("es-a2-comparativos-think", in: pack, "más bueno")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("es-a2-comparativos-write", in: pack, "Mi piso es menos caro que tuyo.")
        XCTAssertEqual(result.category, "missing word")

        // es-a2-por-para
        result = try gradeClozeBlank("es-a2-por-para-fill", in: pack, blank: "b1", "para")
        XCTAssertEqual(result.category, "wrong preposition")
        result = try gradeText("es-a2-por-para-think", in: pack, "para")
        XCTAssertEqual(result.category, "wrong preposition")
        result = try gradeText("es-a2-por-para-write", in: pack, "Lo necesito por mañana.")
        XCTAssertEqual(result.category, "wrong preposition")
        result = try gradeText("es-a2-por-para-read", in: pack, "Mañana.")
        XCTAssertEqual(result.category, "incorrect answer")

        // es-a2-superlativos
        result = try gradeClozeBlank("es-a2-superlativos-fill", in: pack, blank: "b1", "el")
        XCTAssertEqual(result.category, "wrong number")
        result = try gradeText("es-a2-superlativos-think", in: pack, "bueno")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("es-a2-superlativos-write", in: pack, "Mi horario está flexible.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("es-a2-superlativos-read", in: pack, "Cinco días.")
        XCTAssertEqual(result.category, "incorrect answer")

        // es-a2-tecnologia
        result = try gradeClozeBlank("es-a2-tecnologia-fill", in: pack, blank: "b1", "envio")
        XCTAssertEqual(result.category, "accent/diacritic issue")
        result = try gradeText("es-a2-tecnologia-think", in: pack, "envió")
        XCTAssertEqual(result.category, "wrong tense")
        result = try gradeText("es-a2-tecnologia-write", in: pack, "La pantalla está roto.")
        XCTAssertEqual(result.category, "wrong gender")
        result = try gradeText("es-a2-tecnologia-read", in: pack, "La pantalla.")
        XCTAssertEqual(result.category, "incorrect answer")
    }

    /// The authored accepted answers for wave-D surfaces stay accepted,
    /// including the natural digit alternative.
    func testBatch4AcceptsAuthoredAnswers() throws {
        let pack = try spanishPack()

        var result = try gradeText("es-a2-futuro-formacion-write", in: pack, "Comeremos a las dos.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("es-a2-futuro-formacion-write", in: pack, "Comeremos a las 2.")
        XCTAssertTrue(result.accepted, "digit time is authored alongside the word form")

        result = try gradeText("es-emergency-foundation-write", in: pack, "¡Necesito ayuda!")
        XCTAssertTrue(result.accepted)
        result = try gradeText("es-a2-subjuntivo-intro-write", in: pack, "Es importante que estudies.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("es-a2-tecnologia-write", in: pack, "La pantalla está rota.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("es-past-foundation-write", in: pack, "Ayer trabajé mucho.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("es-descriptions-foundation-write", in: pack, "Son altos.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("es-months-foundation-write", in: pack, "Hoy es el 3 de mayo.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("es-a2-por-para-think", in: pack, "por")
        XCTAssertTrue(result.accepted)

        result = try gradeClozeBlank("es-a2-comparativos-fill", in: pack, blank: "b1", "tan")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank("es-time-days-foundation-cloze", in: pack, blank: "b1", "Los")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank("es-a2-superlativos-fill", in: pack, blank: "b1", "los")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank("es-a2-tecnologia-fill", in: pack, blank: "b1", "envío")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank("es-a2-subjuntivo-intro-fill", in: pack, blank: "b1", "vengas")
        XCTAssertTrue(result.accepted)
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