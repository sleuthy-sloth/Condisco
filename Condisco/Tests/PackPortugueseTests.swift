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