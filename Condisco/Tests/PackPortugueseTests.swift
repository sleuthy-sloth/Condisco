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

    /// The seven Wave B mission lessons (units 3–17, outside pt-unit-1/2),
    /// keyed by the graded path activity ids each lesson references.
    /// NOTE: pt-transport/pt-market/pt-emergency foundations are family
    /// == "mission" per the pack and are part of the Wave B editorial lane.
    private static let batch2Lessons: [String: [String]] = [
        "pt-market-trip-mission": [
            "pt-market-trip-mission-act-2", "pt-market-trip-mission-act-3",
            "pt-market-trip-mission-act-4", "pt-market-trip-mission-act-5",
            "pt-market-trip-mission-act-6", "pt-market-trip-mission-act-7",
            "pt-market-trip-mission-act-8", "pt-market-trip-mission-act-9",
        ],
        "pt-station-mission": [
            "pt-station-mission-act-2", "pt-station-mission-act-3",
            "pt-station-mission-act-4", "pt-station-mission-act-5",
            "pt-station-mission-act-6", "pt-station-mission-act-7",
            "pt-station-mission-act-8", "pt-station-mission-act-9",
        ],
        "pt-hotel-mission": [
            "pt-hotel-mission-act-2", "pt-hotel-mission-act-3",
            "pt-hotel-mission-act-4", "pt-hotel-mission-act-5",
            "pt-hotel-mission-act-6", "pt-hotel-mission-act-7",
            "pt-hotel-mission-act-8",
        ],
        "pt-transport-foundation": [
            "pt-transport-foundation-meet", "pt-transport-foundation-notice",
            "pt-transport-foundation-build", "pt-transport-foundation-cloze",
            "pt-transport-foundation-think", "pt-transport-foundation-vary",
        ],
        "pt-market-foundation": [
            "pt-market-foundation-meet", "pt-market-foundation-notice",
            "pt-market-foundation-build", "pt-market-foundation-cloze",
            "pt-market-foundation-think", "pt-market-foundation-vary",
        ],
        "pt-emergency-foundation": [
            "pt-emergency-foundation-meet", "pt-emergency-foundation-notice",
            "pt-emergency-foundation-build", "pt-emergency-foundation-cloze",
            "pt-emergency-foundation-think", "pt-emergency-foundation-act-rb1",
            "pt-emergency-foundation-vary",
        ],
        "pt-a2-no-hotel": [
            "pt-a2-no-hotel-act-2", "pt-a2-no-hotel-act-3",
            "pt-a2-no-hotel-act-4", "pt-a2-no-hotel-act-5",
            "pt-a2-no-hotel-act-6", "pt-a2-no-hotel-act-7",
            "pt-a2-no-hotel-act-8", "pt-a2-no-hotel-act-9",
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

    // MARK: - Wave B hints (rubric H4)

    /// Every graded step in Wave B lessons has a real authored hint, not the
    /// runtime generic fallbacks (audit_editorial hint-gap must stay 0).
    func testWaveBGradedStepsHaveAuthoredHints() throws {
        let pack = try portuguesePack()
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

    // MARK: - Wave B error feedback (rubric H3)

    /// Every text/cloze surface in Wave B lessons authors error-specific
    /// feedback (audit_editorial error-feedback gap must stay 0 for these).
    func testWaveBTextActivitiesAuthorErrors() throws {
        let pack = try portuguesePack()
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

    /// Grade one cloze blank against its authored AnswerSpec.
    private func gradeClozeBlank(_ id: String, blank: String, in pack: CoursePack,
                                 _ response: String) throws -> AnswerEvaluation {
        let act = try activity(id, in: pack)
        guard case .cloze(let spec) = act else {
            throw XCTSkip("expected a cloze activity for \(id)")
        }
        let blankSpec = try XCTUnwrap(spec.blanks[blank], "\(id)#\(blank) missing")
        return AnswerEngine.evaluate(response: response, spec: blankSpec)
    }

    /// Ordering accepted orders must assemble the exact taught sentence.
    func testWaveBOrderingBuildsTheTaughtSentence() throws {
        let pack = try portuguesePack()

        // pt-station-mission act-3: Onde fica a estação? (was wrongly 'Onde a fica estação?')
        var act = try activity("pt-station-mission-act-3", in: pack)
        guard case .ordering(let spec) = act else {
            throw XCTSkip("expected ordering for pt-station-mission-act-3")
        }
        var text = spec.acceptedOrders[0].map { id in
            spec.tokens.first { $0.id == id }!.text
        }.joined(separator: " ")
        XCTAssertEqual(text, "Onde fica a estação?")
        var evaluation = ActivityEvaluation.evaluate(activity: act, response: .ordering(ids: spec.acceptedOrders[0]), assistance: [])
        XCTAssertEqual(evaluation.outcome, .correct)

        // pt-a2-no-hotel act-4: A que horas é o pequeno-almoço?
        act = try activity("pt-a2-no-hotel-act-4", in: pack)
        guard case .ordering(let a2Spec) = act else {
            throw XCTSkip("expected ordering for pt-a2-no-hotel-act-4")
        }
        text = a2Spec.acceptedOrders[0].map { id in
            a2Spec.tokens.first { $0.id == id }!.text
        }.joined(separator: " ")
        XCTAssertEqual(text, "A que horas é o pequeno-almoço?")
        evaluation = ActivityEvaluation.evaluate(activity: act, response: .ordering(ids: a2Spec.acceptedOrders[0]), assistance: [])
        XCTAssertEqual(evaluation.outcome, .correct)
    }

    /// Plausible wrong answers hit their authored category + explanation.
    func testWaveBAuthoredErrorsFireForPlausibleWrongAnswers() throws {
        let pack = try portuguesePack()

        // pt-market-trip-mission
        var result = try gradeClozeBlank("pt-market-trip-mission-act-4", blank: "b1", in: pack, "Quanta")
        XCTAssertEqual(result.category, "wrong gender")
        result = try gradeText("pt-market-trip-mission-act-6", in: pack, "É caro.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("pt-market-trip-mission-act-8", in: pack, "Custa quanto um café?")
        XCTAssertEqual(result.category, "word-order problem")
        result = try gradeText("pt-market-trip-mission-act-9", in: pack, "O conta, por favor.")
        XCTAssertEqual(result.category, "wrong gender")

        // pt-station-mission
        result = try gradeText("pt-station-mission-act-8", in: pack, "Gracias")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("pt-station-mission-act-9", in: pack, "Onde fica a estação? Olá. Obrigado.")
        XCTAssertEqual(result.category, "word-order problem")

        // pt-hotel-mission
        result = try gradeText("pt-hotel-mission-act-5", in: pack, "seis")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("pt-hotel-mission-act-8", in: pack, "Olá. Meu nome é Ana. A conta, por favor.")
        XCTAssertEqual(result.category, "missing word")

        // pt-transport-foundation
        result = try gradeClozeBlank("pt-transport-foundation-cloze", blank: "b1", in: pack, "no")
        XCTAssertEqual(result.category, "wrong preposition")
        result = try gradeText("pt-transport-foundation-think", in: pack, "Vou ao centro com metro.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("pt-transport-foundation-vary", in: pack, "Vou a metro.")
        XCTAssertEqual(result.category, "wrong preposition")

        // pt-market-foundation
        result = try gradeClozeBlank("pt-market-foundation-cloze", blank: "b1", in: pack, "fresca")
        XCTAssertEqual(result.category, "wrong gender")
        result = try gradeText("pt-market-foundation-think", in: pack, "Queria um quilo maçãs.")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeText("pt-market-foundation-vary", in: pack, "Meia quilo de queijo.")
        XCTAssertEqual(result.category, "wrong gender")

        // pt-emergency-foundation
        result = try gradeText("pt-emergency-foundation-think", in: pack, "Chama uma ambulância!")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("pt-emergency-foundation-vary", in: pack, "Chame a ambulância!")
        XCTAssertEqual(result.category, "incorrect answer")

        // pt-a2-no-hotel
        result = try gradeText("pt-a2-no-hotel-act-3", in: pack, "Tenho uma reserva para Silva.")
        XCTAssertEqual(result.category, "wrong preposition")
        result = try gradeText("pt-a2-no-hotel-act-7", in: pack, "A que horas e o pequeno-almoço?")
        XCTAssertEqual(result.category, "accent/diacritic issue")
        result = try gradeText("pt-a2-no-hotel-act-9", in: pack, "Quero fazer o check-in.")
        XCTAssertEqual(result.category, "incorrect answer")
    }

    // MARK: - Wave B accepted answers (prompt ↔ answers alignment)

    /// Natural full/alternative lines are accepted where the learner would
    /// not be wrong to give them; the wrong-but-taught lines are rejected.
    func testWaveBAcceptsNaturalAlternatives() throws {
        let pack = try portuguesePack()

        // Thanks with the feminine speaker form and the fuller help-phrase.
        var result = try gradeText("pt-station-mission-act-8", in: pack, "Obrigada")
        XCTAssertTrue(result.accepted, "Obrigada must be accepted for a woman speaking")
        result = try gradeText("pt-station-mission-act-8", in: pack, "Obrigado pela ajuda.")
        XCTAssertTrue(result.accepted, "Obrigado pela ajuda. must be accepted")

        // The recap accepts the female-speaker thanks form too.
        result = try gradeText("pt-station-mission-act-9", in: pack, "Olá. Onde fica a estação? Obrigada.")
        XCTAssertTrue(result.accepted, "female thanks form must be accepted in the recap")

        // Both natural word orders of the metro sentence are fine pt-PT.
        result = try gradeText("pt-transport-foundation-think", in: pack, "Vou de metro ao centro.")
        XCTAssertTrue(result.accepted, "Vou de metro ao centro. must be accepted")

        // Wrong lines still fail.
        result = try gradeText("pt-transport-foundation-think", in: pack, "Vou a pé.")
        XCTAssertFalse(result.accepted, "changing the transport must not pass")
    }

    /// The hotel mission keeps the European possessive (article o) that Wave
    /// A established in unit-1 — in the phrase strip, the ordering tiles, and
    /// the final recap — and the articleless Brazilian form must not pass.
    func testHotelMissionEuropeanPossessive() throws {
        let pack = try portuguesePack()
        let stim = try XCTUnwrap(pack.stimuli.first { $0.id == "pt-hotel-mission-stim-1" })
        guard case .examples(_, let pairs) = stim else {
            throw XCTSkip("expected example pairs in pt-hotel-mission-stim-1")
        }
        XCTAssertTrue(
            pairs.contains { $0.target == "O meu nome é Ana." },
            "hotel phrase strip must carry the European form: \(pairs.map(\.target))")

        var act = try activity("pt-hotel-mission-act-3", in: pack)
        guard case .ordering(let spec) = act else {
            throw XCTSkip("expected ordering for pt-hotel-mission-act-3")
        }
        let sentence = spec.acceptedOrders[0].map { id in
            spec.tokens.first { $0.id == id }!.text
        }.joined(separator: " ")
        XCTAssertEqual(sentence, "O meu nome é Ana.")
        let evaluation = ActivityEvaluation.evaluate(activity: act, response: .ordering(ids: spec.acceptedOrders[0]), assistance: [])
        XCTAssertEqual(evaluation.outcome, .correct)

        var result = try gradeText("pt-hotel-mission-act-8", in: pack, "Olá. O meu nome é Ana. A conta, por favor.")
        XCTAssertTrue(result.accepted, "European recap must be accepted")
        result = try gradeText("pt-hotel-mission-act-8", in: pack, "Olá. Meu nome é Ana. A conta, por favor.")
        XCTAssertFalse(result.accepted, "articleless Brazilian-style form must not pass")
        XCTAssertEqual(result.category, "missing word")
    }

    // MARK: - Wave B mission final response (rubric M5)

    /// The two missions that ended on a closing information epilogue now end
    /// with a graded text final response (the audit's final-response check).
    func testWaveBFinalStepsAreTextResponses() throws {
        let pack = try portuguesePack()
        let cases: [String: String] = [
            "pt-station-mission": "pt-station-mission-step-9",
            "pt-hotel-mission": "pt-hotel-mission-step-8",
        ]
        for (lessonId, terminalStepId) in cases {
            let lesson = try XCTUnwrap(pack.lesson(id: lessonId))
            let terminal = try XCTUnwrap(
                lesson.steps.first { $0.nextStepId == nil && $0.branches.isEmpty })
            XCTAssertEqual(terminal.id, terminalStepId, "terminal step moved for \(lessonId)")
            let act = try activity(terminal.activityId, in: pack)
            guard case .text = act else {
                XCTFail("\(lessonId) terminal \(terminal.id) must be a text activity")
                continue
            }
            XCTAssertFalse(
                try XCTUnwrap(act.base).hints.allSatisfy { Self.genericHints.contains($0) },
                "\(lessonId) final response must have an authored hint")
        }
    }

    // MARK: - Wave C story lessons (rubric H4/H3/M5)

    /// The eight Wave C story lessons (units 3–16), keyed by the graded
    /// path activity ids each lesson references.
    private static let batch3Lessons: [String: [String]] = [
        "pt-directions-foundation": [
            "pt-directions-foundation-meet", "pt-directions-foundation-ask",
            "pt-directions-foundation-act-rb3", "pt-directions-foundation-vary",
            "pt-directions-foundation-cloze", "pt-directions-foundation-read",
        ],
        "pt-food-foundation": [
            "pt-food-foundation-meet", "pt-food-foundation-think",
            "pt-food-foundation-notice", "pt-food-foundation-vary",
            "pt-food-foundation-cloze", "pt-food-foundation-read",
        ],
        "pt-free-time-foundation": [
            "pt-free-time-foundation-meet", "pt-free-time-foundation-think",
            "pt-free-time-foundation-notice", "pt-free-time-foundation-vary",
            "pt-free-time-foundation-cloze", "pt-free-time-foundation-read",
        ],
        "pt-health-foundation": [
            "pt-health-foundation-meet", "pt-health-foundation-think",
            "pt-health-foundation-notice", "pt-health-foundation-vary",
            "pt-health-foundation-cloze", "pt-health-foundation-read",
        ],
        "pt-a2-preterito-perfeito": [
            "pt-a2-preterito-perfeito-meet", "pt-a2-preterito-perfeito-think",
            "pt-a2-preterito-perfeito-notice", "pt-a2-preterito-perfeito-vary",
            "pt-a2-preterito-perfeito-cloze", "pt-a2-preterito-perfeito-read",
        ],
        "pt-a2-futuro-simples": [
            "pt-a2-futuro-simples-meet", "pt-a2-futuro-simples-think",
            "pt-a2-futuro-simples-notice", "pt-a2-futuro-simples-vary",
            "pt-a2-futuro-simples-cloze", "pt-a2-futuro-simples-read",
        ],
        "pt-a2-gostaria-queria": [
            "pt-a2-gostaria-queria-meet", "pt-a2-gostaria-queria-think",
            "pt-a2-gostaria-queria-notice", "pt-a2-gostaria-queria-vary",
            "pt-a2-gostaria-queria-cloze", "pt-a2-gostaria-queria-read",
        ],
        "pt-a2-pronomes-preposicoes": [
            "pt-a2-pronomes-preposicoes-meet", "pt-a2-pronomes-preposicoes-think",
            "pt-a2-pronomes-preposicoes-notice", "pt-a2-pronomes-preposicoes-vary",
            "pt-a2-pronomes-preposicoes-cloze", "pt-a2-pronomes-preposicoes-read",
        ],
    ]

    /// Every graded step in the Wave C story lessons has a real authored
    /// hint, not the runtime generic fallbacks (audit hint-gap must be 0).
    func testWaveCGradedStepsHaveAuthoredHints() throws {
        let pack = try portuguesePack()
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

    /// Every text/cloze surface in the Wave C story lessons authors
    /// error-specific feedback (audit error-feedback gap must be 0).
    func testWaveCTextActivitiesAuthorErrors() throws {
        let pack = try portuguesePack()
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

    /// Plausible wrong answers hit their authored category + explanation.
    func testWaveCAuthoredErrorsFireForPlausibleWrongAnswers() throws {
        let pack = try portuguesePack()

        // pt-directions-foundation
        var result = try gradeText("pt-directions-foundation-ask", in: pack, "Onde fica o casa de banho?")
        XCTAssertEqual(result.category, "wrong article")
        result = try gradeText("pt-directions-foundation-vary", in: pack, "Onde fica a estação, desculpe?")
        XCTAssertEqual(result.category, "word-order problem")
        result = try gradeClozeBlank("pt-directions-foundation-cloze", blank: "b1", in: pack, "direita")
        XCTAssertEqual(result.category, "incorrect answer")

        // pt-food-foundation
        result = try gradeText("pt-food-foundation-think", in: pack, "Comer sopa ao almoço.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("pt-food-foundation-vary", in: pack, "Bebo aguá.")
        XCTAssertEqual(result.category, "accent/diacritic issue")
        result = try gradeClozeBlank("pt-food-foundation-cloze", blank: "b1", in: pack, "Gosto a fruta.")
        XCTAssertEqual(result.category, "wrong preposition")

        // pt-free-time-foundation
        result = try gradeText("pt-free-time-foundation-think", in: pack, "Gosto ler.")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeText("pt-free-time-foundation-vary", in: pack, "Gosto de nado.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeClozeBlank("pt-free-time-foundation-cloze", blank: "b1", in: pack, "no")
        XCTAssertEqual(result.category, "wrong preposition")

        // pt-health-foundation
        result = try gradeText("pt-health-foundation-think", in: pack, "Dói-me a braço.")
        XCTAssertEqual(result.category, "wrong gender")
        result = try gradeText("pt-health-foundation-vary", in: pack, "Sou doente.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeClozeBlank("pt-health-foundation-cloze", blank: "b1", in: pack, "o")
        XCTAssertEqual(result.category, "wrong gender")

        // pt-a2-preterito-perfeito
        result = try gradeText("pt-a2-preterito-perfeito-think", in: pack, "Comiste o bolo todo?")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("pt-a2-preterito-perfeito-vary", in: pack, "Compramos pão de manhã.")
        XCTAssertEqual(result.category, "accent/diacritic issue")
        result = try gradeClozeBlank("pt-a2-preterito-perfeito-cloze", blank: "b1", in: pack, "parte")
        XCTAssertEqual(result.category, "wrong tense")

        // pt-a2-futuro-simples
        result = try gradeText("pt-a2-futuro-simples-think", in: pack, "Amanhã falei com o chefe.")
        XCTAssertEqual(result.category, "wrong tense")
        result = try gradeText("pt-a2-futuro-simples-vary", in: pack, "Ajudarei com os malas.")
        XCTAssertEqual(result.category, "wrong gender")
        result = try gradeClozeBlank("pt-a2-futuro-simples-cloze", blank: "b1", in: pack, "Sou")
        XCTAssertEqual(result.category, "wrong tense")

        // pt-a2-gostaria-queria
        result = try gradeText("pt-a2-gostaria-queria-think", in: pack, "Gostaria reservar uma mesa.")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeText("pt-a2-gostaria-queria-vary", in: pack, "Queremos reservar uma mesa para dois.")
        XCTAssertEqual(result.category, "wrong tense")
        result = try gradeClozeBlank("pt-a2-gostaria-queria-cloze", blank: "b1", in: pack, "Gosto")
        XCTAssertEqual(result.category, "wrong tense")

        // pt-a2-pronomes-preposicoes
        result = try gradeText("pt-a2-pronomes-preposicoes-think", in: pack, "Este café é para eu.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("pt-a2-pronomes-preposicoes-vary", in: pack, "Este presente é para tu.")
        XCTAssertFalse(result.accepted, "para tu must not pass")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeClozeBlank("pt-a2-pronomes-preposicoes-cloze", blank: "b1", in: pack, "contigo")
        XCTAssertEqual(result.category, "incorrect answer")
    }

    /// Natural full/alternative lines are accepted where the learner would
    /// not be wrong to give them.
    func testWaveCAcceptsNaturalAlternatives() throws {
        let pack = try portuguesePack()

        // todo-o-bolo ordering variant is fine pt-PT.
        var result = try gradeText("pt-a2-preterito-perfeito-think", in: pack, "Comeste todo o bolo?")
        XCTAssertTrue(result.accepted, "Comeste todo o bolo? must be accepted")

        // The first-person reading note takes the bare answer form.
        result = try gradeText("pt-a2-preterito-perfeito-read", in: pack, "Ate a sandwich and left for work.")
        XCTAssertTrue(result.accepted, "bare afternoon answer must be accepted")

        // The ir + infinitive future is a natural alternative.
        result = try gradeText("pt-a2-futuro-simples-read", in: pack, "Vai estudar para o exame.")
        XCTAssertTrue(result.accepted, "Vai estudar para o exame. must be accepted")

        // Short count answers stay accepted.
        result = try gradeText("pt-a2-pronomes-preposicoes-read", in: pack, "Dois.")
        XCTAssertTrue(result.accepted, "Dois. must be accepted")

        // Wrong line still fails.
        result = try gradeText("pt-a2-pronomes-preposicoes-vary", in: pack, "Este presente é para mim.")
        XCTAssertFalse(result.accepted, "para mim changes the meaning and must not pass")
    }

    /// Wave C story lessons all close on a graded text final response with
    /// an authored hint (audit final-response check).
    func testWaveCStoryFinalStepsAreTextResponses() throws {
        let pack = try portuguesePack()
        for lessonId in Self.batch3Lessons.keys {
            let lesson = try XCTUnwrap(pack.lesson(id: lessonId))
            let terminal = try XCTUnwrap(
                lesson.steps.first { $0.nextStepId == nil && $0.branches.isEmpty },
                "\(lessonId) has no terminal step")
            let act = try activity(terminal.activityId, in: pack)
            guard case .text = act else {
                XCTFail("\(lessonId) terminal \(terminal.id) must be a text activity")
                continue
            }
            XCTAssertFalse(
                try XCTUnwrap(act.base).hints.allSatisfy { Self.genericHints.contains($0) },
                "\(lessonId) final response must have an authored hint")
        }
    }

    // MARK: - Wave D discovery lessons (rubric H4/H3/H1/M5)

    /// The thirteen Wave D discovery lessons (units 4–17), keyed by the
    /// graded path activity ids each lesson references.
    private static let batch4Lessons: [String: [String]] = [
        "pt-time-days-foundation": [
            "pt-time-days-foundation-meet", "pt-time-days-foundation-think",
            "pt-time-days-foundation-build", "pt-time-days-foundation-notice",
            "pt-time-days-foundation-cloze", "pt-time-days-foundation-meaning",
            "pt-time-days-foundation-read",
        ],
        "pt-home-foundation": [
            "pt-home-foundation-meet", "pt-home-foundation-think",
            "pt-home-foundation-notice", "pt-home-foundation-build",
            "pt-home-foundation-vary", "pt-home-foundation-cloze",
            "pt-home-foundation-read",
        ],
        "pt-descriptions-foundation": [
            "pt-descriptions-foundation-meet", "pt-descriptions-foundation-think",
            "pt-descriptions-foundation-notice", "pt-descriptions-foundation-vary",
            "pt-descriptions-foundation-build", "pt-descriptions-foundation-cloze",
            "pt-descriptions-foundation-read",
        ],
        "pt-plural-foundation": [
            "pt-plural-foundation-meet", "pt-plural-foundation-think",
            "pt-plural-foundation-notice", "pt-plural-foundation-build",
            "pt-plural-foundation-vary", "pt-plural-foundation-cloze",
            "pt-plural-foundation-read",
        ],
        "pt-negation-foundation": [
            "pt-negation-foundation-meet", "pt-negation-foundation-think",
            "pt-negation-foundation-notice", "pt-negation-foundation-build",
            "pt-negation-foundation-vary", "pt-negation-foundation-cloze",
            "pt-negation-foundation-read",
        ],
        "pt-possession-foundation": [
            "pt-possession-foundation-meet", "pt-possession-foundation-think",
            "pt-possession-foundation-notice", "pt-possession-foundation-vary",
            "pt-possession-foundation-build", "pt-possession-foundation-cloze",
            "pt-possession-foundation-read",
        ],
        "pt-weather-foundation": [
            "pt-weather-foundation-meet", "pt-weather-foundation-notice",
            "pt-weather-foundation-think", "pt-weather-foundation-vary",
            "pt-weather-foundation-build", "pt-weather-foundation-cloze",
            "pt-weather-foundation-read",
        ],
        "pt-time-telling-foundation": [
            "pt-time-telling-foundation-meet", "pt-time-telling-foundation-notice",
            "pt-time-telling-foundation-think", "pt-time-telling-foundation-vary",
            "pt-time-telling-foundation-build", "pt-time-telling-foundation-cloze",
            "pt-time-telling-foundation-read",
        ],
        "pt-months-foundation": [
            "pt-months-foundation-meet", "pt-months-foundation-notice",
            "pt-months-foundation-think", "pt-months-foundation-vary",
            "pt-months-foundation-build", "pt-months-foundation-cloze",
            "pt-months-foundation-read",
        ],
        "pt-a2-imperfeito": [
            "pt-a2-imperfeito-meet", "pt-a2-imperfeito-think",
            "pt-a2-imperfeito-build", "pt-a2-imperfeito-notice",
            "pt-a2-imperfeito-cloze", "pt-a2-imperfeito-vary",
            "pt-a2-imperfeito-read",
        ],
        "pt-a2-conjuntivo-intro": [
            "pt-a2-conjuntivo-intro-meet", "pt-a2-conjuntivo-intro-notice",
            "pt-a2-conjuntivo-intro-think", "pt-a2-conjuntivo-intro-cloze",
            "pt-a2-conjuntivo-intro-build", "pt-a2-conjuntivo-intro-read",
        ],
        "pt-a2-comparativos": [
            "pt-a2-comparativos-meet", "pt-a2-comparativos-notice",
            "pt-a2-comparativos-think", "pt-a2-comparativos-cloze",
            "pt-a2-comparativos-match", "pt-a2-comparativos-vary",
            "pt-a2-comparativos-read",
        ],
        "pt-a2-superlativos-trabalho": [
            "pt-a2-superlativos-trabalho-meet", "pt-a2-superlativos-trabalho-think",
            "pt-a2-superlativos-trabalho-build", "pt-a2-superlativos-trabalho-cloze",
            "pt-a2-superlativos-trabalho-vary", "pt-a2-superlativos-trabalho-read",
        ],
    ]

    /// Every graded step in the Wave D discovery lessons has a real authored
    /// hint, not the runtime generic fallbacks (audit hint-gap must be 0).
    func testWaveDGradedStepsHaveAuthoredHints() throws {
        let pack = try portuguesePack()
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

    /// Every text/cloze surface in the Wave D discovery lessons authors
    /// error-specific feedback (audit error-feedback gap must be 0).
    func testWaveDTextActivitiesAuthorErrors() throws {
        let pack = try portuguesePack()
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

    /// Plausible wrong answers hit their authored category + explanation.
    func testWaveDAuthoredErrorsFireForPlausibleWrongAnswers() throws {
        let pack = try portuguesePack()

        // pt-time-days-foundation
        var result = try gradeText("pt-time-days-foundation-think", in: pack, "Hoje e segunda-feira.")
        XCTAssertEqual(result.category, "accent/diacritic issue")
        result = try gradeText("pt-time-days-foundation-think", in: pack, "Hoje é terça-feira.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeClozeBlank("pt-time-days-foundation-cloze", blank: "b1", in: pack, "amanhã")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("pt-time-days-foundation-read", in: pack, "Monday.")
        XCTAssertEqual(result.category, "incorrect answer")

        // pt-home-foundation
        result = try gradeText("pt-home-foundation-think", in: pack, "em o quarto")
        XCTAssertEqual(result.category, "wrong preposition")
        result = try gradeText("pt-home-foundation-vary", in: pack, "O gato está no cozinha.")
        XCTAssertEqual(result.category, "wrong gender")
        result = try gradeClozeBlank("pt-home-foundation-cloze", blank: "b1", in: pack, "no")
        XCTAssertEqual(result.category, "wrong gender")

        // pt-descriptions-foundation
        result = try gradeText("pt-descriptions-foundation-think", in: pack, "A casa é novo.")
        XCTAssertEqual(result.category, "wrong gender")
        result = try gradeText("pt-descriptions-foundation-vary", in: pack, "A minha irmã é alto.")
        XCTAssertEqual(result.category, "wrong gender")
        result = try gradeClozeBlank("pt-descriptions-foundation-cloze", blank: "b1", in: pack, "muita")
        XCTAssertEqual(result.category, "wrong gender")

        // pt-plural-foundation
        result = try gradeText("pt-plural-foundation-think", in: pack, "os casas")
        XCTAssertEqual(result.category, "wrong gender")
        result = try gradeText("pt-plural-foundation-vary", in: pack, "As janelas estão aberta.")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeClozeBlank("pt-plural-foundation-cloze", blank: "b1", in: pack, "duas")
        XCTAssertEqual(result.category, "wrong gender")

        // pt-negation-foundation
        result = try gradeText("pt-negation-foundation-think", in: pack, "Falo não português.")
        XCTAssertEqual(result.category, "word-order problem")
        result = try gradeText("pt-negation-foundation-vary", in: pack, "Não nunca como carne.")
        XCTAssertEqual(result.category, "extra word")
        result = try gradeClozeBlank("pt-negation-foundation-cloze", blank: "b1", in: pack, "nada")
        XCTAssertEqual(result.category, "incorrect answer")

        // pt-possession-foundation
        result = try gradeText("pt-possession-foundation-think", in: pack, "As minhas amigos vivem aqui.")
        XCTAssertEqual(result.category, "wrong gender")
        result = try gradeText("pt-possession-foundation-vary", in: pack, "O tua carro é novo.")
        XCTAssertEqual(result.category, "wrong gender")
        result = try gradeClozeBlank("pt-possession-foundation-cloze", blank: "b1", in: pack, "Minha")
        XCTAssertEqual(result.category, "missing word")

        // pt-weather-foundation
        result = try gradeText("pt-weather-foundation-think", in: pack, "Faz sol hoje.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("pt-weather-foundation-vary", in: pack, "O inverno é fria.")
        XCTAssertEqual(result.category, "wrong gender")
        result = try gradeClozeBlank("pt-weather-foundation-cloze", blank: "b1", in: pack, "em")
        XCTAssertEqual(result.category, "wrong preposition")

        // pt-time-telling-foundation
        result = try gradeText("pt-time-telling-foundation-think", in: pack, "São uma hora.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("pt-time-telling-foundation-vary", in: pack, "São três e um quarto.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeClozeBlank("pt-time-telling-foundation-cloze", blank: "b1", in: pack, "São")
        XCTAssertEqual(result.category, "wrong conjugation")

        // pt-months-foundation
        result = try gradeText("pt-months-foundation-think", in: pack, "Meu aniversário é em junho.")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeText("pt-months-foundation-vary", in: pack, "Em maio faz flores.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeClozeBlank("pt-months-foundation-cloze", blank: "b1", in: pack, "mêses")
        XCTAssertEqual(result.category, "accent/diacritic issue")

        // pt-a2-imperfeito
        result = try gradeText("pt-a2-imperfeito-think", in: pack, "Ele comeu sempre às sete.")
        XCTAssertEqual(result.category, "wrong tense")
        result = try gradeText("pt-a2-imperfeito-vary", in: pack, "Estamos a ver televisão.")
        XCTAssertEqual(result.category, "wrong tense")
        result = try gradeClozeBlank("pt-a2-imperfeito-cloze", blank: "b1", in: pack, "come")
        XCTAssertEqual(result.category, "wrong tense")
        result = try gradeText("pt-a2-imperfeito-read", in: pack, "By bus.")
        XCTAssertEqual(result.category, "incorrect answer")

        // pt-a2-conjuntivo-intro
        result = try gradeText("pt-a2-conjuntivo-intro-think", in: pack, "É preciso que estudas para o exame.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeClozeBlank("pt-a2-conjuntivo-intro-cloze", blank: "b1", in: pack, "falas")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("pt-a2-conjuntivo-intro-read", in: pack, "At eight.")
        XCTAssertEqual(result.category, "incorrect answer")

        // pt-a2-comparativos
        result = try gradeText("pt-a2-comparativos-think", in: pack, "O Porto é mais pequeno que Lisboa.")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeClozeBlank("pt-a2-comparativos-cloze", blank: "b1", in: pack, "mais melhor")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("pt-a2-comparativos-vary", in: pack, "Hoje o trânsito está melhor.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("pt-a2-comparativos-read", in: pack, "It's cosier.")
        XCTAssertEqual(result.category, "incorrect answer")

        // pt-a2-superlativos-trabalho
        result = try gradeText("pt-a2-superlativos-trabalho-think", in: pack, "Ela é a funcionária mais pontuais.")
        XCTAssertEqual(result.category, "wrong gender")
        result = try gradeClozeBlank("pt-a2-superlativos-trabalho-cloze", blank: "b1", in: pack, "rapidissimo")
        XCTAssertEqual(result.category, "accent/diacritic issue")
        result = try gradeText("pt-a2-superlativos-trabalho-vary", in: pack, "O meu chefe é fixíssima.")
        XCTAssertEqual(result.category, "wrong gender")
        result = try gradeText("pt-a2-superlativos-trabalho-read", in: pack, "At eight.")
        XCTAssertEqual(result.category, "incorrect answer")
    }

    /// Natural full-sentence and fuller-form answers are accepted where an
    /// open comprehension prompt would otherwise falsely reject them.
    func testWaveDAcceptsNaturalAlternatives() throws {
        let pack = try portuguesePack()

        // Open "Where…?"/"What…?"/"When…?"/"How…?" comprehension prompts now
        // accept the natural full-sentence response, not just the short form.
        var result = try gradeText("pt-home-foundation-read", in: pack, "The cat sleeps in the living room.")
        XCTAssertTrue(result.accepted, "full-sentence home answer must be accepted")
        result = try gradeText("pt-negation-foundation-read", in: pack, "They drink tea.")
        XCTAssertTrue(result.accepted, "full-sentence tea answer must be accepted")
        result = try gradeText("pt-time-telling-foundation-read", in: pack, "The train leaves at four.")
        XCTAssertTrue(result.accepted, "full-sentence train answer must be accepted")
        result = try gradeText("pt-months-foundation-read", in: pack, "The party is on June 15th.")
        XCTAssertTrue(result.accepted, "full-sentence date answer must be accepted")
        result = try gradeText("pt-weather-foundation-read", in: pack, "It will be cloudy and rainy.")
        XCTAssertTrue(result.accepted, "full-sentence forecast answer must be accepted")
        result = try gradeText("pt-a2-conjuntivo-intro-read", in: pack, "He must be home at ten.")
        XCTAssertTrue(result.accepted, "full-sentence curfew answer must be accepted")
        result = try gradeText("pt-a2-superlativos-trabalho-read", in: pack, "The first meeting was at nine.")
        XCTAssertTrue(result.accepted, "full-sentence meeting answer must be accepted")

        // The boss sentence accepts either gender, since the prompt gives none.
        result = try gradeText("pt-a2-superlativos-trabalho-vary", in: pack, "A minha chefe é fixíssima.")
        XCTAssertTrue(result.accepted, "female-boss form must be accepted")

        // Wrong-but-plausible lines still fail.
        result = try gradeText("pt-possession-foundation-read", in: pack, "In the garage.")
        XCTAssertFalse(result.accepted, "garage holds the other car, not the keys")
    }

    /// Wave D discovery lessons all close on a graded text final response
    /// with an authored hint (rubric M5, audit final-response check).
    func testWaveDDiscoveryFinalStepsAreTextResponses() throws {
        let pack = try portuguesePack()
        for lessonId in Self.batch4Lessons.keys {
            let lesson = try XCTUnwrap(pack.lesson(id: lessonId))
            let terminal = try XCTUnwrap(
                lesson.steps.first { $0.nextStepId == nil && $0.branches.isEmpty },
                "\(lessonId) has no terminal step")
            let act = try activity(terminal.activityId, in: pack)
            guard case .text = act else {
                XCTFail("\(lessonId) terminal \(terminal.id) must be a text activity")
                continue
            }
            XCTAssertFalse(
                try XCTUnwrap(act.base).hints.allSatisfy { Self.genericHints.contains($0) },
                "\(lessonId) final response must have an authored hint")
        }
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