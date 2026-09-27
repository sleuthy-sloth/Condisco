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

    // MARK: - Checkpoint task bank (5.3A)

    /// The authored checkpoint tasks decode with stable, unique ids and the
    /// expected stage coverage: one stage-end task per shipped stage
    /// (Foundation, Developing, and Independent), each sampling reading,
    /// writing, and speaking (listening is omitted by design — see
    /// `CheckpointModality`).
    func testCheckpointTasksDecodeWithStableUniqueIds() throws {
        let pack = try spanishPack()
        let checkpoints = pack.checkpoints
        XCTAssertEqual(checkpoints.map(\.id),
                       ["es-cp-foundation", "es-cp-developing", "es-cp-independent"],
                       "checkpoint task ids must be stable (unseen bank ids)")
        XCTAssertEqual(Set(checkpoints.map(\.id)).count, checkpoints.count,
                       "checkpoint task ids must be unique")
        XCTAssertEqual(Set(checkpoints.map(\.stage)),
                       [.foundation, .developing, .independent],
                       "one checkpoint task ships per stage (Foundation, Developing, Independent)")
        for checkpoint in checkpoints {
            XCTAssertEqual(Set(checkpoint.items.map(\.modality)),
                           [.reading, .writing, .speaking],
                           "\(checkpoint.id) samples reading, writing, speaking")
            XCTAssertEqual(Set(checkpoint.items.map(\.id)).count,
                           checkpoint.items.count,
                           "\(checkpoint.id) item ids must be unique")
        }
    }

    /// The declared modality coverage must cover every modality the items
    /// actually exercise (requirement 5, "declares ≥ the slots it contains").
    func testCheckpointTasksDeclareTheirModalityCoverage() throws {
        let pack = try spanishPack()
        for checkpoint in pack.checkpoints {
            let declared = Set(checkpoint.modalities)
            let exercised = Set(checkpoint.items.map(\.modality))
            XCTAssertTrue(exercised.isSubset(of: declared),
                          "\(checkpoint.id) must declare every exercised modality")
            XCTAssertFalse(declared.isEmpty, "\(checkpoint.id) must declare coverage")
            XCTAssertTrue(declared.isSubset(of: [.reading, .listening, .writing, .speaking]),
                          "\(checkpoint.id) declares unknown modality")
        }
    }

    /// Leak check (requirement 5): no lesson step references a checkpoint
    /// item as a path or support activity — the bank stays unseen material.
    func testNoLessonStepReferencesCheckpointItem() throws {
        let pack = try spanishPack()
        let itemIds = Set(pack.checkpoints.flatMap { $0.items.map(\.id) })
        XCTAssertFalse(itemIds.isEmpty, "checkpoint bank must not be empty")
        let stepActivityIds = Set(pack.lessons.flatMap { lesson in
            lesson.steps.flatMap { step -> [String] in
                var ids = [step.activityId]
                if let supportId = step.supportActivityId { ids.append(supportId) }
                return ids
            }
        })
        XCTAssertTrue(stepActivityIds.isDisjoint(with: itemIds),
                      "lesson steps must never reference checkpoint items")
    }

    /// Reading items are well-formed recognition (unique options, accepted
    /// ids are options); speaking items carry a 2-4 point rubric.
    func testCheckpointItemsAreWellFormed() throws {
        let pack = try spanishPack()
        for checkpoint in pack.checkpoints {
            for item in checkpoint.items {
                switch item {
                case .reading(let reading):
                    XCTAssertFalse(reading.questions.isEmpty,
                                   "\(reading.id) must ship comprehension questions")
                    for question in reading.questions {
                        let optionIds = question.options.map(\.id)
                        XCTAssertEqual(Set(optionIds).count, optionIds.count,
                                       "\(question.id) option ids must be unique")
                        XCTAssertFalse(question.acceptedIds.isEmpty,
                                       "\(question.id) must accept an option")
                        XCTAssertTrue(question.acceptedIds.allSatisfy(optionIds.contains),
                                      "\(question.id) acceptedIds must name options")
                    }
                case .writing:
                    // Free production: completes on submission, never auto-graded.
                    break
                case .speaking(let speaking):
                    XCTAssertTrue((2...4).contains(speaking.rubric.count),
                                  "\(speaking.id) needs a 2-4 point rubric")
                    let criterionIds = speaking.rubric.map(\.id)
                    XCTAssertEqual(Set(criterionIds).count, criterionIds.count,
                                   "\(speaking.id) rubric ids must be unique")
                }
            }
        }
    }

    /// Fallback (requirement 1): a pack without the `checkpoints` key — the
    /// old five-pack JSON shape — still decodes with an empty bank and
    /// unchanged content. Strips the live Spanish pack's key and reloads.
    func testPackWithoutCheckpointsFieldStillLoadsUnchanged() throws {
        let content = try XCTUnwrap(
            Bundle.main.url(forResource: "Content", withExtension: nil),
            "test host must bundle the Content folder")
        let url = content.appendingPathComponent("packs/spanish.json")
        let raw = try Data(contentsOf: url)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: raw) as? [String: Any],
            "spanish.json must be a JSON object")
        var stripped = object
        stripped.removeValue(forKey: "checkpoints")

        let pack = try JSONDecoder().decode(
            CoursePack.self,
            from: JSONSerialization.data(withJSONObject: stripped))
        XCTAssertTrue(pack.checkpoints.isEmpty,
                      "packs without the key decode to an empty checkpoint bank")
        XCTAssertEqual(pack.version, "0.7.15")
        XCTAssertEqual(pack.lessons.count, 106)
        XCTAssertEqual(pack.activities.count, 899)
        XCTAssertEqual(pack.units.count, 26)
        XCTAssertNoThrow(try PackValidator.validate(pack),
                         "an old five-pack JSON must still validate")
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

    // MARK: - Wave E (conversation family, rubric H4/H3 + M5)

    /// The six conversation-family lessons in wave E scope (units 3, 4, 8,
    /// 9, 12, 15), keyed by their seven graded path activities.
    private static let batch5Lessons: [String: [String]] = [
        "es-shopping-foundation": [
            "es-shopping-foundation-act-rb2", "es-shopping-foundation-meet",
            "es-shopping-foundation-think", "es-shopping-foundation-act-rb5",
            "es-shopping-foundation-act-rb4", "es-shopping-foundation-vary",
            "es-shopping-foundation-ask",
        ],
        "es-family-people-foundation": [
            "es-family-people-foundation-act-rb2", "es-family-people-foundation-meet",
            "es-family-people-foundation-think", "es-family-people-foundation-act-rb3",
            "es-family-people-foundation-notice", "es-family-people-foundation-read",
            "es-family-people-foundation-vary",
        ],
        "es-questions-foundation": [
            "es-questions-foundation-act-rb2", "es-questions-foundation-meet",
            "es-questions-foundation-think", "es-questions-foundation-act-rb3",
            "es-questions-foundation-notice", "es-questions-foundation-write",
            "es-questions-foundation-read",
        ],
        "es-requests-foundation": [
            "es-requests-foundation-act-rb2", "es-requests-foundation-meet",
            "es-requests-foundation-think", "es-requests-foundation-act-rb3",
            "es-requests-foundation-notice", "es-requests-foundation-write",
            "es-requests-foundation-read",
        ],
        "es-invitations-foundation": [
            "es-invitations-foundation-act-rb2", "es-invitations-foundation-meet",
            "es-invitations-foundation-think", "es-invitations-foundation-act-rb3",
            "es-invitations-foundation-notice", "es-invitations-foundation-write",
            "es-invitations-foundation-read",
        ],
        "es-a2-condicional": [
            "es-a2-condicional-act-rb2", "es-a2-condicional-meet",
            "es-a2-condicional-think", "es-a2-condicional-act-rb3",
            "es-a2-condicional-notice", "es-a2-condicional-write",
            "es-a2-condicional-read",
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

    // MARK: - Wave E (conversation family, rubric H4/H3 + M5)

    /// Every graded step in wave-E conversation lessons has a real authored
    /// hint (audit_editorial hint-gap must stay 0 for these lessons).
    func testBatch5GradedStepsHaveAuthoredHints() throws {
        let pack = try spanishPack()
        for (lessonId, activityIds) in Self.batch5Lessons {
            for activityId in activityIds {
                let act = try activity(activityId, in: pack)
                let base = try XCTUnwrap(act.base, "\(lessonId): \(activityId) has no graded base")
                XCTAssertFalse(
                    base.hints.allSatisfy { Self.genericHints.contains($0) },
                    "\(lessonId): \(activityId) lacks an authored hint: \(base.hints)")
            }
        }
    }

    /// Every text answer in wave-E lessons authors error-specific feedback
    /// (audit_editorial error-gap must stay 0 for these lessons).
    func testBatch5TextActivitiesAuthorErrors() throws {
        let pack = try spanishPack()
        for (lessonId, activityIds) in Self.batch5Lessons {
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

    /// Every wave-E conversation lesson carries a non-empty objective (M2)
    /// and closes with a text final-response step (M5 outcome coherence).
    func testBatch5ConversationLessonsEndWithTextFinalResponse() throws {
        let pack = try spanishPack()
        for lessonId in Self.batch5Lessons.keys {
            let lesson = try XCTUnwrap(pack.lessons.first { $0.id == lessonId }, "missing lesson \(lessonId)")
            XCTAssertEqual(lesson.family, .conversation, "\(lessonId) must be a conversation lesson")
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

    /// Plausible wrong answers in wave-E lessons hit their authored category
    /// + explanation (text surfaces).
    func testBatch5AuthoredErrorsFireForPlausibleWrongAnswers() throws {
        let pack = try spanishPack()

        // es-shopping-foundation
        var result = try gradeText("es-shopping-foundation-think", in: pack, "¿Cuánto cuestan un café?")
        XCTAssertEqual(result.category, "wrong number")
        XCTAssertFalse(result.accepted)
        result = try gradeText("es-shopping-foundation-vary", in: pack, "Es no caro.")
        XCTAssertEqual(result.category, "word-order problem")
        result = try gradeText("es-shopping-foundation-ask", in: pack, "El cuenta, por favor.")
        XCTAssertEqual(result.category, "wrong article")

        // es-family-people-foundation
        result = try gradeText("es-family-people-foundation-think", in: pack, "Tene un hermano.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("es-family-people-foundation-vary", in: pack, "Tengo dos hermana.")
        XCTAssertEqual(result.category, "wrong number")
        result = try gradeText("es-family-people-foundation-read", in: pack, "Sevilla.")
        XCTAssertEqual(result.category, "incorrect answer")

        // es-questions-foundation
        result = try gradeText("es-questions-foundation-think", in: pack, "¿Qué comer?")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("es-questions-foundation-write", in: pack, "¿Quien trabaja aquí?")
        XCTAssertEqual(result.category, "accent/diacritic issue")
        result = try gradeText("es-questions-foundation-read", in: pack, "A las ocho.")
        XCTAssertEqual(result.category, "incorrect answer")

        // es-requests-foundation
        result = try gradeText("es-requests-foundation-think", in: pack, "¿Puede ayudarme?")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("es-requests-foundation-write", in: pack, "Quería un café, por favor.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("es-requests-foundation-read", in: pack, "La cuenta.")
        XCTAssertEqual(result.category, "incorrect answer")

        // es-invitations-foundation
        result = try gradeText("es-invitations-foundation-think", in: pack, "¿Quiere venir?")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("es-invitations-foundation-write", in: pack, "Lo siento, no poder.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("es-invitations-foundation-read", in: pack, "No.")
        XCTAssertEqual(result.category, "incorrect answer")

        // es-a2-condicional
        result = try gradeText("es-a2-condicional-think", in: pack, "me gustaría")
        XCTAssertEqual(result.category, "extra word")
        result = try gradeText("es-a2-condicional-write", in: pack, "Debes descansar más.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("es-a2-condicional-read", in: pack, "A comer sushi.")
        XCTAssertEqual(result.category, "incorrect answer")
    }

    /// The authored accepted answers for wave-E text surfaces stay accepted,
    /// including the natural explicit-subject alternative.
    func testBatch5AcceptsAuthoredAnswers() throws {
        let pack = try spanishPack()

        var result = try gradeText("es-shopping-foundation-think", in: pack, "¿Cuánto cuesta un café?")
        XCTAssertTrue(result.accepted)
        result = try gradeText("es-shopping-foundation-vary", in: pack, "No es caro.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("es-shopping-foundation-ask", in: pack, "La cuenta, por favor.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("es-shopping-foundation-ask", in: pack, "La cuenta por favor.")
        XCTAssertTrue(result.accepted, "comma-less polite form is authored")

        result = try gradeText("es-family-people-foundation-think", in: pack, "Tengo un hermano.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("es-family-people-foundation-vary", in: pack, "Tengo dos hermanas.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("es-family-people-foundation-read", in: pack, "Madrid.")
        XCTAssertTrue(result.accepted)

        result = try gradeText("es-questions-foundation-think", in: pack, "¿Qué come?")
        XCTAssertTrue(result.accepted)
        result = try gradeText("es-questions-foundation-think", in: pack, "¿Qué come él?")
        XCTAssertTrue(result.accepted, "explicit-subject question is authored")
        result = try gradeText("es-questions-foundation-write", in: pack, "¿Quién trabaja aquí?")
        XCTAssertTrue(result.accepted)
        result = try gradeText("es-questions-foundation-read", in: pack, "En mi casa.")
        XCTAssertTrue(result.accepted)

        result = try gradeText("es-requests-foundation-think", in: pack, "¿Puedes ayudarme?")
        XCTAssertTrue(result.accepted)
        result = try gradeText("es-requests-foundation-write", in: pack, "Querría un café, por favor.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("es-requests-foundation-read", in: pack, "Un café.")
        XCTAssertTrue(result.accepted)

        result = try gradeText("es-invitations-foundation-think", in: pack, "¿Quieres venir?")
        XCTAssertTrue(result.accepted)
        result = try gradeText("es-invitations-foundation-write", in: pack, "Lo siento, no puedo.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("es-invitations-foundation-read", in: pack, "¡Claro que sí!")
        XCTAssertTrue(result.accepted)

        result = try gradeText("es-a2-condicional-think", in: pack, "gustaría")
        XCTAssertTrue(result.accepted)
        result = try gradeText("es-a2-condicional-write", in: pack, "Deberías descansar más.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("es-a2-condicional-read", in: pack, "A Japón.")
        XCTAssertTrue(result.accepted)
    }

    // MARK: - Wave F (construction + recall families, rubric H4/H3 + M5)

    /// The seven construction-family and seven recall-family lessons in wave F
    /// scope (units 5–16), keyed by their graded path activities.
    private static let batch6Lessons: [String: [String]] = [
        "es-cafe-order-construction": [
            "es-cafe-order-construction-act-2", "es-cafe-order-construction-act-3",
            "es-cafe-order-construction-act-4", "es-cafe-order-construction-act-5",
            "es-cafe-order-construction-act-6", "es-cafe-order-construction-act-7",
            "es-cafe-order-construction-act-8", "es-cafe-order-construction-act-9",
        ],
        "es-family-construction": [
            "es-family-construction-act-2", "es-family-construction-act-3",
            "es-family-construction-act-4", "es-family-construction-act-5",
            "es-family-construction-act-6", "es-family-construction-act-7",
            "es-family-construction-act-8", "es-family-construction-act-9",
            "es-family-construction-act-10",
        ],
        "es-plural-foundation": [
            "es-plural-foundation-build", "es-plural-foundation-act-rb1",
            "es-plural-foundation-meet", "es-plural-foundation-fill",
            "es-plural-foundation-think", "es-plural-foundation-notice",
        ],
        "es-negation-foundation": [
            "es-negation-foundation-build", "es-negation-foundation-act-rb1",
            "es-negation-foundation-meet", "es-negation-foundation-fill",
            "es-negation-foundation-think", "es-negation-foundation-notice",
        ],
        "es-possession-foundation": [
            "es-possession-foundation-build", "es-possession-foundation-act-rb1",
            "es-possession-foundation-meet", "es-possession-foundation-fill",
            "es-possession-foundation-think", "es-possession-foundation-notice",
        ],
        "es-a2-relativos": [
            "es-a2-relativos-build", "es-a2-relativos-act-rb1",
            "es-a2-relativos-meet", "es-a2-relativos-fill",
            "es-a2-relativos-think", "es-a2-relativos-notice",
        ],
        "es-a2-pronombres-od-oi": [
            "es-a2-pronombres-od-oi-build", "es-a2-pronombres-od-oi-act-rb1",
            "es-a2-pronombres-od-oi-meet", "es-a2-pronombres-od-oi-fill",
            "es-a2-pronombres-od-oi-think", "es-a2-pronombres-od-oi-notice",
        ],
        "es-basics-recall": [
            "es-basics-recall-act-2", "es-basics-recall-act-3",
            "es-basics-recall-act-4", "es-basics-recall-act-5",
            "es-basics-recall-act-6", "es-basics-recall-act-7",
            "es-basics-recall-act-8", "es-basics-recall-act-9",
            "es-basics-recall-act-10",
        ],
        "es-plans-foundation": [
            "es-plans-foundation-act-rb2", "es-plans-foundation-act-rb3",
            "es-plans-foundation-act-rb4", "es-plans-foundation-act-rb5",
            "es-plans-foundation-act-rb6", "es-plans-foundation-act-rb7",
            "es-plans-foundation-act-rb8",
        ],
        "es-time-telling-foundation": [
            "es-time-telling-foundation-act-rb2", "es-time-telling-foundation-act-rb3",
            "es-time-telling-foundation-act-rb4", "es-time-telling-foundation-act-rb5",
            "es-time-telling-foundation-act-rb6", "es-time-telling-foundation-act-rb7",
            "es-time-telling-foundation-act-rb8",
        ],
        "es-free-time-foundation": [
            "es-free-time-foundation-act-rb2", "es-free-time-foundation-act-rb3",
            "es-free-time-foundation-act-rb4", "es-free-time-foundation-act-rb5",
            "es-free-time-foundation-act-rb6", "es-free-time-foundation-act-rb7",
            "es-free-time-foundation-act-rb8",
        ],
        "es-a2-preterito-imperfecto": [
            "es-a2-preterito-imperfecto-act-rb2", "es-a2-preterito-imperfecto-act-rb3",
            "es-a2-preterito-imperfecto-act-rb4", "es-a2-preterito-imperfecto-act-rb5",
            "es-a2-preterito-imperfecto-act-rb6", "es-a2-preterito-imperfecto-act-rb7",
            "es-a2-preterito-imperfecto-act-rb8",
        ],
        "es-a2-fin-de-semana": [
            "es-a2-fin-de-semana-act-rb2", "es-a2-fin-de-semana-act-rb3",
            "es-a2-fin-de-semana-act-rb4", "es-a2-fin-de-semana-act-rb5",
            "es-a2-fin-de-semana-act-rb6", "es-a2-fin-de-semana-act-rb7",
            "es-a2-fin-de-semana-act-rb8",
        ],
        "es-a2-me-gustaria": [
            "es-a2-me-gustaria-act-rb2", "es-a2-me-gustaria-act-rb3",
            "es-a2-me-gustaria-act-rb4", "es-a2-me-gustaria-act-rb5",
            "es-a2-me-gustaria-act-rb6", "es-a2-me-gustaria-act-rb7",
            "es-a2-me-gustaria-act-rb8",
        ],
    ]

    /// Every graded step in wave-F lessons has a real authored hint
    /// (audit_editorial hint-gap must stay 0 for these lessons).
    func testBatch6GradedStepsHaveAuthoredHints() throws {
        let pack = try spanishPack()
        for (lessonId, activityIds) in Self.batch6Lessons {
            for activityId in activityIds {
                let act = try activity(activityId, in: pack)
                let base = try XCTUnwrap(act.base, "\(lessonId): \(activityId) has no graded base")
                XCTAssertFalse(
                    base.hints.allSatisfy { Self.genericHints.contains($0) },
                    "\(lessonId): \(activityId) lacks an authored hint: \(base.hints)")
            }
        }
    }

    /// Every text answer and every cloze blank in wave-F lessons authors
    /// error-specific feedback (audit_editorial error-gap must stay 0).
    func testBatch6TextAndClozeActivitiesAuthorErrors() throws {
        let pack = try spanishPack()
        for (lessonId, activityIds) in Self.batch6Lessons {
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

    /// Every wave-F lesson carries a non-empty objective and closes on a
    /// graded distinct final response (M5 outcome coherence: construction
    /// ends building the target from memory, recall ends retrieving it).
    func testBatch6LessonsEndWithGradedTerminal() throws {
        let pack = try spanishPack()
        for (lessonId, _) in Self.batch6Lessons {
            let lesson = try XCTUnwrap(pack.lessons.first { $0.id == lessonId }, "missing lesson \(lessonId)")
            XCTAssertTrue(
                lesson.family == .construction || lesson.family == .recall,
                "\(lessonId) must be construction or recall")
            XCTAssertFalse(
                lesson.objective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                "\(lessonId) must have an objective")
            let terminals = lesson.steps.filter { $0.nextStepId == nil && $0.branches.isEmpty }
            XCTAssertFalse(terminals.isEmpty, "\(lessonId) must have a terminal step")
            var allGraded = true
            for step in terminals {
                let act = try activity(step.activityId, in: pack)
                if act.base == nil { allGraded = false }
            }
            XCTAssertTrue(allGraded, "\(lessonId) must end on a graded final-response step (M5)")
        }
    }

    /// Plausible wrong answers in wave-F lessons hit their authored category
    /// + explanation (text and cloze-blank surfaces).
    func testBatch6AuthoredErrorsFireForPlausibleWrongAnswers() throws {
        let pack = try spanishPack()

        // es-cafe-order-construction
        var result = try gradeClozeBlank("es-cafe-order-construction-act-4", in: pack, blank: "b1", "Quiero")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("es-cafe-order-construction-act-7", in: pack, "Quiero un té por favor")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeClozeBlank("es-cafe-order-construction-act-8", in: pack, blank: "b1", "te")
        XCTAssertEqual(result.category, "accent/diacritic issue")

        // es-family-construction
        result = try gradeClozeBlank("es-family-construction-act-4", in: pack, blank: "b1", "hermano")
        XCTAssertEqual(result.category, "wrong gender")
        result = try gradeText("es-family-construction-act-7", in: pack, "Me llama Ana")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeClozeBlank("es-family-construction-act-8", in: pack, blank: "b1", "la")
        XCTAssertEqual(result.category, "wrong gender")

        // es-plural-foundation
        result = try gradeClozeBlank("es-plural-foundation-fill", in: pack, blank: "b1", "lápiz")
        XCTAssertEqual(result.category, "wrong number")
        result = try gradeText("es-plural-foundation-think", in: pack, "dos mesa")
        XCTAssertEqual(result.category, "wrong number")

        // es-negation-foundation
        result = try gradeClozeBlank("es-negation-foundation-fill", in: pack, blank: "b1", "Nada")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("es-negation-foundation-think", in: pack, "No estudiar")
        XCTAssertEqual(result.category, "wrong conjugation")

        // es-possession-foundation
        result = try gradeClozeBlank("es-possession-foundation-fill", in: pack, blank: "b1", "Mi")
        XCTAssertEqual(result.category, "wrong number")
        result = try gradeText("es-possession-foundation-think", in: pack, "Mi amigos viven aquí")
        XCTAssertEqual(result.category, "wrong number")

        // es-a2-relativos
        result = try gradeClozeBlank("es-a2-relativos-fill", in: pack, blank: "b1", "quién")
        XCTAssertEqual(result.category, "accent/diacritic issue")
        result = try gradeText("es-a2-relativos-think", in: pack, "dondé")
        XCTAssertEqual(result.category, "accent/diacritic issue")

        // es-a2-pronombres-od-oi
        result = try gradeClozeBlank("es-a2-pronombres-od-oi-fill", in: pack, blank: "b1", "Lo")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("es-a2-pronombres-od-oi-think", in: pack, "le lo")
        XCTAssertEqual(result.category, "incorrect answer")

        // es-basics-recall
        result = try gradeClozeBlank("es-basics-recall-act-3", in: pack, blank: "b1", "Mi")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("es-basics-recall-act-4", in: pack, "Me llama Ana")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("es-basics-recall-act-9", in: pack, "Si gracias")
        XCTAssertEqual(result.category, "accent/diacritic issue")

        // es-plans-foundation
        result = try gradeClozeBlank("es-plans-foundation-act-rb3", in: pack, blank: "b1", "al")
        XCTAssertEqual(result.category, "wrong preposition")
        result = try gradeText("es-plans-foundation-act-rb4", in: pack, "Voy en pie")
        XCTAssertEqual(result.category, "wrong preposition")
        result = try gradeClozeBlank("es-plans-foundation-act-rb6", in: pack, blank: "b1", "Vas")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("es-plans-foundation-act-rb7", in: pack, "Vamos a coche")
        XCTAssertEqual(result.category, "wrong preposition")

        // es-time-telling-foundation
        result = try gradeClozeBlank("es-time-telling-foundation-act-rb3", in: pack, blank: "b1", "cuatro")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("es-time-telling-foundation-act-rb4", in: pack, "seis")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeClozeBlank("es-time-telling-foundation-act-rb6", in: pack, blank: "b1", "manzano")
        XCTAssertEqual(result.category, "wrong gender")
        result = try gradeText("es-time-telling-foundation-act-rb7", in: pack, "dieciséis")
        XCTAssertEqual(result.category, "incorrect answer")

        // es-free-time-foundation
        result = try gradeClozeBlank("es-free-time-foundation-act-rb3", in: pack, blank: "b1", "la")
        XCTAssertEqual(result.category, "wrong gender")
        result = try gradeText("es-free-time-foundation-act-rb4", in: pack, "Me gusta el fruta")
        XCTAssertEqual(result.category, "wrong gender")
        result = try gradeClozeBlank("es-free-time-foundation-act-rb6", in: pack, blank: "b1", "leche")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("es-free-time-foundation-act-rb7", in: pack, "la queso")
        XCTAssertEqual(result.category, "wrong gender")

        // es-a2-preterito-imperfecto
        result = try gradeClozeBlank("es-a2-preterito-imperfecto-act-rb3", in: pack, blank: "b1", "jugué")
        XCTAssertEqual(result.category, "wrong tense")
        result = try gradeText("es-a2-preterito-imperfecto-act-rb4", in: pack, "comemos")
        XCTAssertEqual(result.category, "wrong tense")
        result = try gradeClozeBlank("es-a2-preterito-imperfecto-act-rb6", in: pack, blank: "b1", "Tenía")
        XCTAssertEqual(result.category, "wrong tense")
        result = try gradeText("es-a2-preterito-imperfecto-act-rb7", in: pack, "Hubo mucha gente")
        XCTAssertEqual(result.category, "wrong tense")

        // es-a2-fin-de-semana
        result = try gradeClozeBlank("es-a2-fin-de-semana-act-rb3", in: pack, blank: "b1", "Hoy")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("es-a2-fin-de-semana-act-rb4", in: pack, "como")
        XCTAssertEqual(result.category, "wrong tense")
        result = try gradeClozeBlank("es-a2-fin-de-semana-act-rb6", in: pack, blank: "b1", "era")
        XCTAssertEqual(result.category, "wrong tense")
        result = try gradeText("es-a2-fin-de-semana-act-rb7", in: pack, "anoche")
        XCTAssertEqual(result.category, "incorrect answer")

        // es-a2-me-gustaria
        result = try gradeClozeBlank("es-a2-me-gustaria-act-rb3", in: pack, blank: "b1", "Puede")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("es-a2-me-gustaria-act-rb4", in: pack, "Quiero café")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeClozeBlank("es-a2-me-gustaria-act-rb6", in: pack, blank: "b1", "ayuda")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("es-a2-me-gustaria-act-rb7", in: pack, "Quiero la cuenta por favor")
        XCTAssertEqual(result.category, "wrong conjugation")
    }

    /// The authored accepted answers for wave-F surfaces stay accepted,
    /// including the accented forms the construction steps insist on.
    func testBatch6AcceptsAuthoredAnswers() throws {
        let pack = try spanishPack()

        // es-cafe-order-construction
        var result = try gradeText("es-cafe-order-construction-act-7", in: pack, "Quisiera un té, por favor.")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank("es-cafe-order-construction-act-8", in: pack, blank: "b1", "té")
        XCTAssertTrue(result.accepted)

        // es-family-construction
        result = try gradeText("es-family-construction-act-7", in: pack, "Me llamo Ana.")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank("es-family-construction-act-8", in: pack, blank: "b1", "el")
        XCTAssertTrue(result.accepted)

        // es-plural-foundation
        result = try gradeClozeBlank("es-plural-foundation-fill", in: pack, blank: "b1", "lápices")
        XCTAssertTrue(result.accepted)
        result = try gradeText("es-plural-foundation-think", in: pack, "dos mesas")
        XCTAssertTrue(result.accepted)

        // es-negation-foundation
        result = try gradeText("es-negation-foundation-think", in: pack, "No estudia.")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank("es-negation-foundation-fill", in: pack, blank: "b1", "Nadie")
        XCTAssertTrue(result.accepted)

        // es-possession-foundation
        result = try gradeText("es-possession-foundation-think", in: pack, "Mis amigos viven aquí.")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank("es-possession-foundation-fill", in: pack, blank: "b1", "Mis")
        XCTAssertTrue(result.accepted)

        // es-a2-relativos
        result = try gradeClozeBlank("es-a2-relativos-fill", in: pack, blank: "b1", "quien")
        XCTAssertTrue(result.accepted)
        result = try gradeText("es-a2-relativos-think", in: pack, "donde")
        XCTAssertTrue(result.accepted)

        // es-a2-pronombres-od-oi
        result = try gradeClozeBlank("es-a2-pronombres-od-oi-fill", in: pack, blank: "b1", "Le")
        XCTAssertTrue(result.accepted)
        result = try gradeText("es-a2-pronombres-od-oi-think", in: pack, "lo")
        XCTAssertTrue(result.accepted)

        // es-basics-recall
        result = try gradeText("es-basics-recall-act-4", in: pack, "Me llamo Ana.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("es-basics-recall-act-9", in: pack, "Sí, gracias.")
        XCTAssertTrue(result.accepted)

        // es-plans-foundation
        result = try gradeText("es-plans-foundation-act-rb4", in: pack, "Voy a pie.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("es-plans-foundation-act-rb7", in: pack, "Vamos en coche.")
        XCTAssertTrue(result.accepted)

        // es-time-telling-foundation
        result = try gradeText("es-time-telling-foundation-act-rb4", in: pack, "ocho")
        XCTAssertTrue(result.accepted)
        result = try gradeText("es-time-telling-foundation-act-rb7", in: pack, "diez")
        XCTAssertTrue(result.accepted)

        // es-free-time-foundation
        result = try gradeText("es-free-time-foundation-act-rb4", in: pack, "Me gusta la fruta.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("es-free-time-foundation-act-rb7", in: pack, "el queso")
        XCTAssertTrue(result.accepted)

        // es-a2-preterito-imperfecto
        result = try gradeText("es-a2-preterito-imperfecto-act-rb4", in: pack, "comimos")
        XCTAssertTrue(result.accepted)
        result = try gradeText("es-a2-preterito-imperfecto-act-rb7", in: pack, "Había mucha gente.")
        XCTAssertTrue(result.accepted)

        // es-a2-fin-de-semana
        result = try gradeText("es-a2-fin-de-semana-act-rb4", in: pack, "comí")
        XCTAssertTrue(result.accepted)
        result = try gradeText("es-a2-fin-de-semana-act-rb7", in: pack, "ayer")
        XCTAssertTrue(result.accepted)

        // es-a2-me-gustaria
        result = try gradeText("es-a2-me-gustaria-act-rb4", in: pack, "Quiero un café.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("es-a2-me-gustaria-act-rb7", in: pack, "Querría la cuenta, por favor.")
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

    // MARK: - Café listen pilot (Phase 3.1)

    /// The Phase 3.1 listening pilot in es-cafe-mission: new steps decode and
    /// chain, the audio stimulus/media resolve, and the selection answers are
    /// honestly gradeable (exactly one accepted option; the meaning-changing
    /// near miss — Para llevar, which the audio actually contains — is
    /// rejected).
    func testCafeListenPilotStepsResolveAndGrade() throws {
        let pack = try spanishPack()
        let lesson = try XCTUnwrap(pack.lesson(id: "es-cafe-mission"), "missing es-cafe-mission")
        let steps = lesson.steps
        let byID = Dictionary(uniqueKeysWithValues: steps.map { ($0.id, $0) })

        // Media + stimulus exist and are bound.
        guard case .audio(let stimMediaId)? = pack.stimulus(id: "es-cafe-listen-stim") else {
            return XCTFail("es-cafe-listen-stim must be an audio stimulus")
        }
        XCTAssertEqual(stimMediaId.mediaId, "es-cafe-listen-audio")
        guard case .audio? = pack.media(id: "es-cafe-listen-audio") else {
            return XCTFail("es-cafe-listen-audio must be an audio media item")
        }
        guard case .audio? = pack.media(id: "es-cafe-listen-model") else {
            return XCTFail("es-cafe-listen-model must be an audio media item")
        }

        // New steps exist and chain: step-8 (matching) -> step-10 ... step-14
        // -> step-9 (existing terminal text step, unchanged).
        let expected: [(String, String, String)] = [
            ("es-cafe-mission-step-10", "notice", "es-cafe-listen-act-1"),
            ("es-cafe-mission-step-11", "practice", "es-cafe-listen-gist"),
            ("es-cafe-mission-step-12", "practice", "es-cafe-listen-drink"),
            ("es-cafe-mission-step-13", "practice", "es-cafe-listen-here"),
            ("es-cafe-mission-step-14", "practice", "es-cafe-listen-say"),
        ]
        for (stepID, purpose, activityID) in expected {
            let step = try XCTUnwrap(byID[stepID], "missing \(stepID)")
            XCTAssertEqual(step.purpose.rawValue, purpose, "\(stepID) purpose")
            XCTAssertEqual(step.activityId, activityID, "\(stepID) activity")
            XCTAssertTrue(step.required, "\(stepID) must be required")
        }
        XCTAssertEqual(byID["es-cafe-mission-step-8"]?.nextStepId,
                       "es-cafe-mission-step-10", "step-8 must route into the pilot")
        XCTAssertEqual(byID["es-cafe-mission-step-14"]?.nextStepId,
                       "es-cafe-mission-step-9", "pilot must route back to the final response")
        XCTAssertNil(byID["es-cafe-mission-step-9"]?.nextStepId,
                     "step-9 stays the terminal step (text final response, M5)")

        // The information step presents the audio stimulus.
        let notice = try XCTUnwrap(pack.activity(id: "es-cafe-listen-act-1"))
        XCTAssertEqual(notice.stimulusId, "es-cafe-listen-stim", "notice step shows the audio")

        // Selection comprehension steps: bound to the stimulus, listening
        // skill, single-select with exactly one accepted option, and the
        // meaning-changing near miss is NOT accepted.
        let selections: [(String, String, [String], String?)] = [
            // (activity id, accepted option id, near-miss option ids, near-miss text kept out of acceptedIds)
            ("es-cafe-listen-gist", "cafe", ["pan", "super"], nil),
            ("es-cafe-listen-drink", "cafe", ["te", "zumo"], nil),
            ("es-cafe-listen-here", "aqui", ["llevar"], "Para llevar"),
        ]
        for (activityID, acceptedID, rejectedIDs, _) in selections {
            let act = try activity(activityID, in: pack)
            guard case .selection(let spec) = act else {
                return XCTFail("\(activityID) must be a selection activity")
            }
            XCTAssertEqual(spec.base.stimulusId, "es-cafe-listen-stim",
                           "\(activityID) must bind the audio stimulus")
            XCTAssertTrue(spec.base.skills.contains(.listening),
                          "\(activityID) must train listening")
            XCTAssertEqual(Set(spec.base.assistanceAffectsEvidence), [.transcript, .model],
                           "\(activityID) model reveal must affect evidence")
            XCTAssertEqual(spec.options.map(\.id).count, Set(spec.options.map(\.id)).count,
                           "\(activityID) option ids must be unique")
            XCTAssertFalse(spec.multiple, "\(activityID) must be single-select")
            XCTAssertEqual(spec.acceptedIds, [acceptedID],
                           "\(activityID) must accept exactly \(acceptedID)")
            XCTAssertTrue(spec.acceptedIds.allSatisfy { $0 == acceptedID },
                          "\(activityID) must not accept any near miss")
            for rejected in rejectedIDs {
                XCTAssertFalse(spec.acceptedIds.contains(rejected),
                               "\(activityID) must reject option \(rejected)")
            }
        }
        // Explicitly: the audio says "para llevar" (the server's question) but
        // the customer answers "para tomar aquí" — accepting Para llevar would
        // grade the meaning-changing near miss as correct.
        let hereAct = try activity("es-cafe-listen-here", in: pack)
        guard case .selection(let hereSpec) = hereAct else {
            return XCTFail("es-cafe-listen-here must be a selection activity")
        }
        XCTAssertTrue(hereSpec.options.contains { $0.id == "llevar" && $0.text == "Para llevar" })
        XCTAssertFalse(hereSpec.acceptedIds.contains("llevar"))

        // Respond step: self-compare with an authored Spanish model and audio.
        let sayAct = try activity("es-cafe-listen-say", in: pack)
        guard case .selfCompare(let saySpec) = sayAct else {
            return XCTFail("es-cafe-listen-say must be a self-compare activity")
        }
        XCTAssertEqual(saySpec.modelText, "Un café, por favor.")
        XCTAssertEqual(saySpec.modelAudioId, "es-cafe-listen-model")
        XCTAssertTrue(saySpec.skills.contains(.speaking))
    }

    // MARK: - Sustained reading & listening (Phase 6.1A)

    /// Fallback (item 4): a pack without the `sustainedTexts` /
    /// `sustainedListenings` keys — the old five-pack JSON shape — still
    /// decodes with empty arrays and unchanged content. Mirrors the
    /// `checkpoints` fallback test. 6.1A only *added* sustained material
    /// (and 6.2 only *added* open tasks), so the honest pre-6.1A pack is
    /// this one minus every trace of both: no top-level arrays, no
    /// `*-launch` activities, no open-task activities or
    /// steps, the original `nextStepId` chains restored
    /// (rb7→rb8 / rb8→rb9, cafe recall→nil, planes read→nil), and version
    /// 0.7.2.
    func testPackWithoutSustainedFieldsStillLoadsUnchanged() throws {
        let content = try XCTUnwrap(
            Bundle.main.url(forResource: "Content", withExtension: nil),
            "test host must bundle the Content folder")
        let url = content.appendingPathComponent("packs/spanish.json")
        let raw = try Data(contentsOf: url)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: raw) as? [String: Any],
            "spanish.json must be a JSON object")

        var old = object
        old.removeValue(forKey: "sustainedTexts")
        old.removeValue(forKey: "sustainedListenings")
        old["version"] = "0.7.2"

        // Remove the launch activities that backed the removed steps (the
        // four 6.1A pilots, Unit 18's sustained text and listening launches,
        // Unit 19's, Unit 20's, Unit 21's, Unit 22's, and Unit 23's — they
        // would otherwise orphan after their steps strip).
        let launchActivities: Set<String> = [
            "es-sustained-text-mensajes-launch",
            "es-sustained-text-articulo-launch",
            "es-sustained-text-narracion-launch",
            "es-sustained-listen-llamada-launch",
            "es-b1-text-vuelo-cancelado-launch",
            "es-b1-listen-aeropuerto-launch",
            "es-b1-text-entrevista-launch",
            "es-b1-listen-oferta-launch",
            "es-b1-text-aniversario-launch",
            "es-b1-listen-fiesta-launch",
            "es-b1-listen-anecdota-launch",
            "es-b1-text-cambio-planes-launch",
            "es-b1-listen-discusion-launch",
            "es-b1-listen-reparacion-launch",
            "es-b1-listen-charla-launch",
            "es-b1-text-cronica-launch",
            "es-b2-listen-debate-launch",
            "es-b2-text-postura-launch",
        ]
        // Phase 6.2 open tasks are even newer than the sustained material:
        // the honest pre-6.1A pack strips their steps too and restores the
        // original chains, proving the additive decode boundary both ways.
        let openTaskActivities: Set<String> = [
            "es-a2-fin-de-semana-open-task",
            "es-cafe-requests-foundation-open-task",
            "es-a2-planes-intenciones-open-task",
            "es-b1-viaje-escrito-open-task",
            "es-b1-plan-escrito-open-task",
            "es-b1-decision-escrito-open-task",
            "es-b1-historia-escrito-open-task",
            "es-b1-consecuencia-escrito-open-task",
            "es-b1-opinion-escrito-open-task",
            "es-b1-problema-escrito-open-task",
            "es-b1-resumen-escrito-open-task",
            "es-b2-argumento-open-task",
        ]
        let removedActivities = launchActivities.union(openTaskActivities)
        let activities = try XCTUnwrap(old["activities"] as? [[String: Any]])
        old["activities"] = activities.filter {
            guard let id = $0["id"] as? String else { return true }
            return !removedActivities.contains(id)
        }

        // Drop the sustained binding steps and the open-task steps, and
        // rewire each predecessor to the step the removed step used to
        // point at, so the original chains (rb7→rb8, rb8→rb9, cafe
        // recall→nil, planes read→nil) are restored exactly.
        let openTaskStepIds: Set<String> = [
            "es-a2-fin-de-semana-step-open-task",
            "es-cafe-requests-foundation-step-open-task",
            "es-a2-planes-intenciones-step-open-task",
            "es-b1-viaje-escrito-step-open-task",
            "es-b1-plan-escrito-step-open-task",
            "es-b1-decision-escrito-step-open-task",
            "es-b1-historia-escrito-step-open-task",
            "es-b1-consecuencia-escrito-step-open-task",
            "es-b1-opinion-escrito-step-open-task",
            "es-b1-problema-escrito-step-open-task",
            "es-b1-resumen-escrito-step-open-task",
            "es-b2-argumento-escrito-step-open-task",
        ]
        let lessons = try XCTUnwrap(old["lessons"] as? [[String: Any]])
        old["lessons"] = lessons.map { lesson -> [String: Any] in
            var lesson = lesson
            guard let rawSteps = lesson["steps"] as? [[String: Any]] else { return lesson }
            // A removed step's successor may itself be removed (sustained →
            // open-task → terminal), so the predecessor reroutes to the
            // surviving next step, restoring the original chain.
            var removedNext = [String: String?]()
            var kept: [[String: Any]] = []
            for step in rawSteps {
                if step["sustainedTextId"] != nil || step["sustainedListeningId"] != nil
                    || (step["id"] as? String).map(openTaskStepIds.contains) == true {
                    if let id = step["id"] as? String {
                        removedNext[id] = step["nextStepId"] as? String
                    }
                } else {
                    kept.append(step)
                }
            }
            // Collapse chains: a removed step whose next is itself removed
            // (sustained → open-task → terminal) follows the removed step's
            // own replacement, so rb7 lands on the surviving rb8.
            for id in removedNext.keys {
                var cursor = removedNext[id] ?? nil
                while let target = cursor, removedNext[target] != nil {
                    cursor = removedNext[target] ?? nil
                }
                removedNext[id] = cursor
            }
            lesson["steps"] = kept.map { step -> [String: Any] in
                var step = step
                if let id = step["id"] as? String,
                   let next = step["nextStepId"] as? String,
                   let replacement = removedNext[next] {
                    step["nextStepId"] = replacement
                }
                return step
            }
            return lesson
        }

        let pack = try JSONDecoder().decode(
            CoursePack.self,
            from: JSONSerialization.data(withJSONObject: old))
        XCTAssertTrue(pack.sustainedTexts.isEmpty,
                      "packs without the keys decode to an empty sustained-text array")
        XCTAssertTrue(pack.sustainedListenings.isEmpty,
                      "packs without the keys decode to an empty sustained-listening array")
        XCTAssertEqual(pack.version, "0.7.2")
        XCTAssertEqual(pack.lessons.count, 106)
        XCTAssertEqual(pack.activities.count, 869,
                       "the pre-6.1A activity count (899 − 16 launch − 11 open tasks − 2 unit-26 launches − 1 unit-26 open task) is unchanged")
        XCTAssertEqual(pack.units.count, 26)
        XCTAssertNoThrow(try PackValidator.validate(pack),
                         "an old five-pack JSON must still validate")
    }

    /// The three pilot genres decode with all required metadata:
    /// multi-paragraph sections with markers and per-section accessibility
    /// labels, a section-list accessible summary, a 4-8 entry glossary with
    /// unique terms, and a dated provenance statement.
    func testSustainedTextsDecodeWithRequiredMetadata() throws {
        let pack = try spanishPack()
        let texts = pack.sustainedTexts
        XCTAssertEqual(Set(texts.map(\.genre)),
                       Set(SustainedGenre.allCases),
                       "the pilot path must author one text of each genre")
        for text in texts {
            XCTAssertFalse(text.title.isEmpty, "\(text.id) must have a title")
            XCTAssertGreaterThanOrEqual(text.sections.count, 3,
                                        "\(text.id) must be multi-paragraph")
            let markers = text.sections.map(\.marker)
            XCTAssertEqual(Set(markers).count, markers.count,
                           "\(text.id) section markers must be unique")
            for section in text.sections {
                XCTAssertFalse(
                    section.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    "\(text.id) section \(section.marker) must have a body")
                XCTAssertFalse(section.heading.isEmpty,
                               "\(text.id) section \(section.marker) must have a heading")
                XCTAssertFalse(section.accessibilityLabel.isEmpty,
                               "\(text.id) section \(section.marker) must carry an accessibility label")
            }
            XCTAssertFalse(text.accessibleSummary.isEmpty,
                           "\(text.id) must carry a section-list accessible summary")
            XCTAssertTrue((4...8).contains(text.glossary.count),
                          "\(text.id) must ship a 4-8 entry glossary")
            XCTAssertEqual(Set(text.glossary.map(\.term)).count, text.glossary.count,
                           "\(text.id) glossary terms must be unique")
            XCTAssertFalse(text.provenance.statement.isEmpty,
                           "\(text.id) must state its provenance")
            XCTAssertFalse(text.provenance.date.isEmpty,
                           "\(text.id) must date its provenance")
        }
    }

    /// Each sustained text embeds exactly one question per kind and every
    /// question is deterministically answerable: exactly one accepted option
    /// that exists, gradeable by the same set-equality rule the checkpoint
    /// reading items use (never open auto-grading).
    func testSustainedTextQuestionsCoverKindsAndResolve() throws {
        let pack = try spanishPack()
        for text in pack.sustainedTexts {
            XCTAssertEqual(Set(text.questions.map(\.kind)),
                           Set(SustainedQuestionKind.allCases),
                           "\(text.id) must ask one main-idea, one key-detail and one speaker-intent question")
            for question in text.questions {
                let optionIds = question.options.map(\.id)
                XCTAssertEqual(Set(optionIds).count, optionIds.count,
                               "\(question.id) option ids must be unique")
                XCTAssertEqual(question.acceptedIds.count, 1,
                               "\(question.id) must accept exactly one option")
                XCTAssertTrue(question.acceptedIds.allSatisfy(optionIds.contains),
                              "\(question.id) acceptedIds must name options")
                // Deterministic set-equality grading (the checkpoint rule):
                // selecting exactly the accepted option is correct, any other
                // option is wrong — no open auto-grading anywhere.
                for option in question.options {
                    let correct = Set([option.id]) == Set(question.acceptedIds)
                    XCTAssertEqual(correct, option.id == question.acceptedIds.first,
                                   "\(question.id) option \(option.id) gradeability")
                }
            }
        }
    }

    /// The sustained listening passages decode with ordered sections, two
    /// distinct voice ids that carry their language tags, per-section
    /// synthesised voice labels, and a transcript that equals the section
    /// texts (whitespace-insensitive).
    func testSustainedListeningDecodesWithOrderedSectionsAndVoiceLabels() throws {
        let pack = try spanishPack()
        let passages = pack.sustainedListenings
        XCTAssertEqual(passages.count, 9, "the pack ships the sustained listening passages")
        for passage in passages {
            XCTAssertGreaterThanOrEqual(passage.sections.count, 4,
                                        "\(passage.id) must be multi-section (multi-minute)")
            let markers = passage.sections.map(\.marker)
            XCTAssertEqual(Set(markers).count, markers.count,
                           "\(passage.id) section markers must be unique")
            let voices = Set(passage.sections.map(\.voiceId))
            XCTAssertGreaterThanOrEqual(voices.count, 2,
                                        "\(passage.id) must use at least two distinct voices")
            for section in passage.sections {
                XCTAssertTrue(
                    section.voiceId.lowercased().contains(section.languageCode.lowercased()),
                    "\(passage.id) section \(section.marker) voice id must carry its language tag")
                XCTAssertTrue(section.languageCode.lowercased().hasPrefix("es-"),
                              "\(passage.id) section \(section.marker) must be an es language tag")
                XCTAssertTrue(section.accessibilityLabel.lowercased().contains("synth"),
                              "\(passage.id) section \(section.marker) must label its voice as synthesised")
                XCTAssertFalse(section.text.isEmpty,
                               "\(passage.id) section \(section.marker) must have text to synthesise")
            }
            XCTAssertFalse(passage.transcript.isEmpty, "\(passage.id) must carry a transcript")
            let joined = passage.sections.map(\.text).joined(separator: "\n\n")
            XCTAssertEqual(Self.collapsed(passage.transcript), Self.collapsed(joined),
                           "\(passage.id) transcript must equal the section texts in order")
        }
    }

    /// The four materials bind to host lesson steps; each binding step is
    /// required, routes back into the original lesson, and the lesson's
    /// terminal step stays untouched.
    func testSustainedMaterialsBoundToHostLessons() throws {
        let pack = try spanishPack()
        let expectations: [(lesson: String, step: String, text: String?, listening: String?)] = [
            ("es-plans-foundation", "es-plans-foundation-step-sustained", "es-sustained-text-mensajes", nil),
            ("es-market-foundation", "es-market-foundation-step-sustained", "es-sustained-text-articulo", nil),
            ("es-a2-fin-de-semana", "es-a2-fin-de-semana-step-sustained", "es-sustained-text-narracion", nil),
            ("es-a2-imperfecto", "es-a2-imperfecto-step-listen", nil, "es-sustained-listen-llamada"),
        ]
        for expected in expectations {
            let lesson = try XCTUnwrap(pack.lesson(id: expected.lesson), "missing \(expected.lesson)")
            let step = try XCTUnwrap(lesson.steps.first { $0.id == expected.step },
                                     "missing \(expected.step)")
            XCTAssertEqual(step.sustainedTextId, expected.text, "\(expected.step) text binding")
            XCTAssertEqual(step.sustainedListeningId, expected.listening,
                           "\(expected.step) listening binding")
            XCTAssertTrue(step.required, "\(expected.step) must be required")
            XCTAssertNotNil(step.nextStepId, "\(expected.step) must route back into the lesson")
            let terminals = lesson.steps.filter { $0.nextStepId == nil && $0.branches.isEmpty }
            XCTAssertEqual(terminals.count, 1, "\(expected.lesson) must keep its single terminal step")
            XCTAssertTrue(terminals.first?.id.hasSuffix("-rb8") == true
                          || terminals.first?.id == "es-a2-imperfecto-step-rb9",
                          "\(expected.lesson) terminal step must be unchanged")
        }
        // Every authored material is referenced by exactly one lesson step.
        let bindings = pack.lessons.flatMap { lesson in
            lesson.steps.compactMap { $0.sustainedTextId ?? $0.sustainedListeningId }
        }
        XCTAssertEqual(Set(bindings).count, bindings.count,
                       "materials must bind to exactly one step each")
        XCTAssertEqual(Set(bindings),
                       Set(pack.sustainedTexts.map(\.id) + pack.sustainedListenings.map(\.id)),
                       "every authored material must be bound to a lesson step")
    }

    // MARK: - Sustained fixtures (negative validator probes)

    private static func collapsed(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private func fixtureQuestion(_ id: String, _ kind: String, _ text: String) -> [String: Any] {
        ["id": id, "kind": kind, "question": text,
         "options": [
            ["id": "a", "text": "First option"],
            ["id": "b", "text": "Second option"],
            ["id": "c", "text": "Third option"],
         ],
         "acceptedIds": ["a"]]
    }

    private func fixtureText(_ id: String, genre: String, marker: String) -> [String: Any] {
        ["id": id, "title": "Fixture \(id)", "genre": genre,
         "sections": (1...4).map { n in
            ["marker": "\(marker)-\(n)", "heading": "Heading \(n)",
             "body": "Paragraph number \(n) of the fixture text \(id).",
             "accessibilityLabel": "Section \(n) of the fixture text."]
         },
         "accessibleSummary": "A fixture text for validator probes.",
         "glossary": (1...4).map { n in
            ["term": "term\(n)-\(id)", "definition": "Definition \(n)."]
         },
         "provenance": ["statement": "Original fixture text.", "date": "2026-09-26"],
         "questions": [
            fixtureQuestion("\(id)-q1", "main-idea", "What is the main idea of the fixture?"),
            fixtureQuestion("\(id)-q2", "key-detail", "What key detail does the fixture mention?"),
            fixtureQuestion("\(id)-q3", "speaker-intent", "Why does the fixture speak?"),
         ]]
    }

    private func fixtureListening() -> [String: Any] {
        let texts = [
            "First section of the listening fixture.",
            "Second section of the listening fixture.",
            "Third section of the listening fixture.",
            "Fourth section of the listening fixture.",
            "Fifth section of the listening fixture.",
        ]
        let voices: [(id: String, lang: String)] = [
            ("com.apple.voice.compact.es-ES.Fixture", "es-ES"),
            ("com.apple.voice.compact.es-MX.Fixture", "es-MX"),
        ]
        return ["id": "listen1", "title": "Fixture listening",
         "sections": texts.enumerated().map { (index, text) in
            let voice = voices[index % 2]
            return ["marker": "\(index + 1)", "heading": "Heading \(index + 1)",
                    "text": text,
                    "voiceId": voice.id, "languageCode": voice.lang,
                    "accessibilityLabel": "Spoken by a synthesised voice."]
         },
         "transcript": texts.joined(separator: "\n\n"),
         "accessibleSummary": "A fixture listening passage.",
         "glossary": (1...4).map { n in
            ["term": "lterm\(n)", "definition": "Definition \(n)."]
         },
         "provenance": ["statement": "Original fixture text.", "date": "2026-09-26"],
         "questions": [
            fixtureQuestion("listen1-q1", "main-idea", "What is the call about?"),
            fixtureQuestion("listen1-q2", "key-detail", "What detail is mentioned?"),
            fixtureQuestion("listen1-q3", "speaker-intent", "Why does the speaker call?"),
         ]]
    }

    private func minimalSustainedPackJSON(
        texts: [[String: Any]]? = nil,
        listenings: [[String: Any]]? = nil,
        bindText: String? = "t1",
        bindListening: String? = "listen1",
        unboundTextID: String? = nil
    ) -> [String: Any] {
        let texts = texts ?? [
            fixtureText("t1", genre: "message-thread", marker: "1"),
            fixtureText("t2", genre: "short-article", marker: "2"),
            fixtureText("t3", genre: "personal-narrative", marker: "3"),
        ]
        let listenings = listenings ?? [fixtureListening()]

        // Every authored passage must be reachable from a lesson step
        // (orphan discipline), so give each text and each listening its
        // own notice step, chained into a single selection step that
        // terminates the lesson. The first text and first listening bind
        // the caller-controlled ids (`bindText`/`bindListening`, so a
        // fixture can point a step at an unknown id); `unboundTextID`
        // leaves one passage unreferenced so the orphan discipline itself
        // can be probed.
        var bindings: [(stepID: String, activityID: String,
                        textID: String?, listeningID: String?)] = []
        for (index, text) in texts.enumerated() {
            let id = text["id"] as? String ?? "t\(index + 1)"
            var bound: String?
            if index == 0 {
                bound = bindText ?? id
            } else if id != unboundTextID {
                bound = id
            }
            bindings.append(("s\(index + 1)", "a\(index + 1)", bound, nil))
        }
        let textCount = texts.count
        for (index, passage) in listenings.enumerated() {
            let id = passage["id"] as? String ?? "listen\(index + 1)"
            let bound = index == 0 ? (bindListening ?? id) : id
            bindings.append(("s\(textCount + index + 1)",
                             "a\(textCount + index + 1)", nil, bound))
        }
        let terminalStepID = "s\(bindings.count + 1)"
        let terminalActivityID = "a\(bindings.count + 1)"

        var steps: [[String: Any]] = []
        for (index, binding) in bindings.enumerated() {
            var step: [String: Any] = [
                "id": binding.stepID, "purpose": "notice",
                "activityId": binding.activityID, "required": true,
            ]
            if let textID = binding.textID { step["sustainedTextId"] = textID }
            if let listeningID = binding.listeningID { step["sustainedListeningId"] = listeningID }
            step["nextStepId"] = index + 1 < bindings.count
                ? bindings[index + 1].stepID : terminalStepID
            steps.append(step)
        }
        steps.append(["id": terminalStepID, "purpose": "practice",
                      "activityId": terminalActivityID, "required": true])

        var activities: [[String: Any]] = bindings.map { binding in
            ["kind": "information", "id": binding.activityID, "revision": 1,
             "body": "Read the fixture."]
        }
        activities.append([
            "kind": "selection", "id": terminalActivityID, "revision": 1,
            "conceptIds": [], "vocabulary": [], "skills": ["reading"],
            "prompt": "Which option?", "hints": [],
            "feedback": "That is correct.", "evidenceKey": terminalActivityID,
            "assistanceAffectsEvidence": ["model"],
            "options": [["id": "o1", "text": "One"], ["id": "o2", "text": "Two"]],
            "acceptedIds": ["o1"], "multiple": false,
        ])

        return [
            "schemaVersion": 2, "id": "probe", "version": "0", "language": "es",
            "status": "active", "title": "probe", "sourceLanguage": "en",
            "description": "probe", "attribution": "probe",
            "units": [["id": "u1", "title": "U", "objective": "O"]],
            "concepts": [["id": "c1", "title": "C", "explanation": "E",
                          "examples": [["target": "T", "meaning": "M"]],
                          "commonError": "CE"]],
            "vocabulary": [], "media": [], "stimuli": [],
            "activities": activities,
            "lessons": [[
                "id": "l1", "unitId": "u1", "title": "L", "objective": "O",
                "family": "recall", "revision": 1, "estimatedMinutes": 5,
                "entryStepId": "s1", "steps": steps,
                "completionPolicy": ["kind": "participation"],
                "conceptIds": [], "vocabulary": [], "prerequisites": [],
            ]],
            "checkpoints": [], "dialogues": [],
            "sustainedTexts": texts,
            "sustainedListenings": listenings,
        ]
    }

    private func decodeProbe(_ json: [String: Any]) throws -> CoursePack {
        try JSONDecoder().decode(CoursePack.self,
                                 from: JSONSerialization.data(withJSONObject: json))
    }

    /// A minimally valid pack carrying the three fixture texts and one
    /// listening passage validates cleanly — the baseline the broken
    /// fixtures are measured against.
    func testSustainedMinimalPackValidates() throws {
        let pack = try decodeProbe(minimalSustainedPackJSON())
        XCTAssertEqual(pack.sustainedTexts.count, 3)
        XCTAssertEqual(pack.sustainedListenings.count, 1)
        XCTAssertNoThrow(try PackValidator.validate(pack),
                         "baseline probe pack must validate")
    }

    /// The validator catches deliberately broken sustained fixtures —
    /// duplicated section markers, unresolvable question answers, a missing
    /// question kind, a single-voice listening passage, a transcript that
    /// does not match the sections, an unknown step binding, and an orphaned
    /// passage each throw a PackValidationError naming the problem.
    func testSustainedValidatorCatchesBrokenFixtures() throws {
        func threeTexts(_ first: [String: Any]) -> [[String: Any]] {
            [first,
             fixtureText("t2", genre: "short-article", marker: "2"),
             fixtureText("t3", genre: "personal-narrative", marker: "3")]
        }
        func assertRejects(_ json: [String: Any], _ fragment: String,
                           file: StaticString = #filePath, line: UInt = #line) {
            do {
                let pack = try JSONDecoder().decode(
                    CoursePack.self,
                    from: JSONSerialization.data(withJSONObject: json))
                do {
                    try PackValidator.validate(pack)
                    XCTFail("expected validation failure containing \(fragment)",
                            file: file, line: line)
                } catch let error as PackValidationError {
                    XCTAssertTrue(error.description.contains(fragment),
                                  "expected \(fragment) in \(error.description)",
                                  file: file, line: line)
                } catch {
                    XCTFail("unexpected error type: \(error)", file: file, line: line)
                }
            } catch {
                XCTFail("fixture should decode: \(error)", file: file, line: line)
            }
        }

        // A: duplicated section markers.
        var text = fixtureText("t1", genre: "message-thread", marker: "1")
        var sections = text["sections"] as! [[String: Any]]
        sections[1]["marker"] = sections[0]["marker"]
        text["sections"] = sections
        assertRejects(minimalSustainedPackJSON(texts: threeTexts(text)),
                      "duplicate section marker")

        // B: a question accepts an option that is not in its options list.
        text = fixtureText("t1", genre: "message-thread", marker: "1")
        var questions = text["questions"] as! [[String: Any]]
        questions[0]["acceptedIds"] = ["zzz"]
        text["questions"] = questions
        assertRejects(minimalSustainedPackJSON(texts: threeTexts(text)),
                      "accepts unknown option")

        // C: a missing question kind (only two of the three).
        text = fixtureText("t1", genre: "message-thread", marker: "1")
        questions = text["questions"] as! [[String: Any]]
        questions.removeLast()
        text["questions"] = questions
        assertRejects(minimalSustainedPackJSON(texts: threeTexts(text)),
                      "one question of each kind")

        // D: a listening passage with a single voice across all sections.
        var listening = fixtureListening()
        var listenSections = listening["sections"] as! [[String: Any]]
        for index in listenSections.indices {
            listenSections[index]["voiceId"] = "com.apple.voice.compact.es-ES.Fixture"
            listenSections[index]["languageCode"] = "es-ES"
        }
        listening["sections"] = listenSections
        assertRejects(minimalSustainedPackJSON(listenings: [listening]),
                      "at least two distinct voices")

        // E: a transcript that does not equal the section texts.
        listening = fixtureListening()
        listening["transcript"] = "This transcript is not what the sections say."
        assertRejects(minimalSustainedPackJSON(listenings: [listening]),
                      "transcript must equal")

        // F: a step binding an unknown sustained text id.
        assertRejects(minimalSustainedPackJSON(bindText: "nope"),
                      "references unknown sustained text")

        // G: an orphaned passage (bound by no lesson step).
        assertRejects(minimalSustainedPackJSON(
            texts: threeTexts(fixtureText("t1", genre: "message-thread", marker: "1"))
                + [fixtureText("t4", genre: "message-thread", marker: "4")],
            unboundTextID: "t4"),
            "orphaned sustained text")
    }
}

// MARK: - Sustained experience behaviour (Phase 6.1B)

/// Behaviour tests for the sustained reading/listening experience lane:
/// question grading + reveal gating, glossary save-to-review through the real
/// phrasebook API, offline voice-fallback resolution, the transcript
/// visibility state machine, and the host-step shape. All headless — no TTS,
/// no device audio.
@MainActor
final class SustainedExperienceTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("condisco-sustained-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        tempDir = nil
    }

    private func makeStore() throws -> LearningStore {
        try LearningStore(path: tempDir.appendingPathComponent("store.sqlite").path)
    }

    private func spanishPack() throws -> CoursePack {
        try XCTUnwrap(PackLoader.loadPacks().first { $0.language.slug == "spanish" })
    }

    /// Resolve an authored activity by id inside `pack` (mirrors the
    /// same-named helper in `PackSpanishTests`).
    private func activity(_ id: String, in pack: CoursePack) throws -> Activity {
        try XCTUnwrap(pack.activity(id: id), "missing activity \(id)")
    }

    // MARK: Question grading + reveal gating

    /// The deterministic set-equality grading: the authored accepted option
    /// passes, every other option fails, and an unanswered submission fails.
    func testSustainedQuestionGradingAcceptsOnlyTheAcceptedOption() throws {
        let pack = try spanishPack()
        let passage = try XCTUnwrap(pack.sustainedText(id: "es-sustained-text-mensajes"))
        for question in passage.questions {
            let accepted = try XCTUnwrap(question.acceptedIds.first,
                                         "\(question.id) must accept exactly one option")
            XCTAssertTrue(sustainedQuestionCorrect(question, selectedIds: [accepted]),
                          "\(question.id) must accept its authored option")
            for option in question.options where option.id != accepted {
                XCTAssertFalse(sustainedQuestionCorrect(question, selectedIds: [option.id]),
                               "\(question.id) must reject a wrong option")
            }
            XCTAssertFalse(sustainedQuestionCorrect(question, selectedIds: []),
                           "\(question.id) must reject an unanswered submission")
        }
    }

    /// Results exist only after the reveal gate flips: the submit stays
    /// disabled until every question has an answer, and the chosen answers
    /// lock once submitted.
    func testSustainedQuestionResultsExistOnlyAfterSubmission() throws {
        let pack = try spanishPack()
        let passage = try XCTUnwrap(pack.sustainedListening(id: "es-sustained-listen-llamada"))
        var state = SustainedAnswersState()
        XCTAssertFalse(state.answersSubmitted)
        XCTAssertFalse(state.isComplete(passage.questions),
                       "all three questions must be answered before checking")

        state.select("a", for: passage.questions[0].id)
        XCTAssertFalse(state.isComplete(passage.questions),
                       "two unanswered questions keep the check gated")
        state.select("b", for: passage.questions[1].id)
        state.select("a", for: passage.questions[1].id)
        state.select("c", for: passage.questions[2].id)
        XCTAssertTrue(state.isComplete(passage.questions),
                      "one answer per question opens the check")

        // The reveal is gated on submission: the result set is produced only
        // from the submitted selections, never pre-answer.
        let results = sustainedQuestionResults(
            questions: passage.questions, selections: state.selections)
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0].correct, true, "main idea accepted option a")
        XCTAssertEqual(results[1].correct, true, "key detail accepted option a")
        XCTAssertEqual(results[2].correct, false, "speaker intent chose c, accepted a")
        XCTAssertEqual(results[2].selectedOptionId, "c")

        // Submission locks the answers in place.
        state.submit()
        XCTAssertTrue(state.answersSubmitted)
        XCTAssertTrue(state.isComplete(passage.questions))
        state.select("a", for: passage.questions[2].id)
        XCTAssertEqual(state.selections[passage.questions[2].id], "c",
                       "submitted answers must not change")
    }

    /// Results preserve the authored question order (kind order is authored
    /// order — main idea, key detail, speaker intent).
    func testSustainedQuestionResultsKeepAuthoredOrder() throws {
        let pack = try spanishPack()
        let passage = try XCTUnwrap(pack.sustainedText(id: "es-sustained-text-articulo"))
        let selections = Dictionary(uniqueKeysWithValues: passage.questions.map {
            ($0.id, $0.acceptedIds.first ?? "")
        })
        let results = sustainedQuestionResults(
            questions: passage.questions, selections: selections)
        XCTAssertEqual(results.map(\.question.id), passage.questions.map(\.id))
        XCTAssertEqual(results.map(\.question.kind), passage.questions.map(\.kind))
        XCTAssertTrue(results.allSatisfy { $0.correct })
    }

    // MARK: Glossary save-to-review

    /// The glossary popover's save path — `LearningStore.savePhrase` on the
    /// real phrasebook API — against a throwaway store: save once, no-op on
    /// re-save (deterministic id), and unsave records the removal.
    func testGlossarySaveToReviewWritesThroughThePhrasebookAPI() throws {
        let store = try makeStore()
        let pack = try spanishPack()
        let passage = try XCTUnwrap(pack.sustainedText(id: "es-sustained-text-mensajes"))
        let entry = try XCTUnwrap(passage.glossary.first)

        let phraseId = LearningStore.savedPhraseId(
            languageSlug: pack.language.slug, target: entry.term, meaning: entry.definition)

        try store.savePhrase(SavedPhrase(
            id: phraseId,
            languageSlug: pack.language.slug,
            languageName: pack.language.displayName,
            target: entry.term,
            meaning: entry.definition,
            source: "Planes para el sábado",
            sourcePackId: pack.id,
            sourceLessonId: "es-plans-foundation",
            savedAt: Date()))

        var all = try store.savedPhrases()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0].id, phraseId)
        XCTAssertEqual(all[0].target, entry.term)
        XCTAssertEqual(all[0].meaning, entry.definition)
        XCTAssertTrue(try store.isPhraseSaved(id: phraseId))

        // Deterministic id: re-saving the same glossary term is a no-op.
        try store.savePhrase(SavedPhrase(
            id: phraseId,
            languageSlug: pack.language.slug,
            languageName: pack.language.displayName,
            target: entry.term,
            meaning: entry.definition,
            source: "Planes para el sábado",
            sourcePackId: pack.id,
            sourceLessonId: "es-plans-foundation",
            savedAt: Date()))
        all = try store.savedPhrases()
        XCTAssertEqual(all.count, 1, "a repeat save must not duplicate the phrase")

        try store.unsavePhrase(id: phraseId)
        XCTAssertFalse(try store.isPhraseSaved(id: phraseId),
                       "unsave must remove the phrase")
    }

    // MARK: Voice fallback resolution

    func testVoiceResolutionPrefersTheDeclaredVoice() {
        let installed = [
            InstalledVoice(identifier: "com.apple.voice.compact.es-ES.Monica",
                           language: "es-ES"),
            InstalledVoice(identifier: "com.apple.voice.compact.es-MX.Paulina",
                           language: "es-MX"),
        ]
        XCTAssertEqual(
            SustainedVoiceResolver.resolve(
                declaredVoiceId: "com.apple.voice.compact.es-ES.Monica",
                languageCode: "es-ES",
                installed: installed),
            "com.apple.voice.compact.es-ES.Monica",
            "the declared voice is used when it is installed")
    }

    func testVoiceResolutionFallsBackToAnyInstalledLanguageVoice() {
        // Monica (es-ES) is declared but the device carries only an es-MX
        // voice — the schema's offline fallback: ANY installed voice whose
        // language matches the section's language root reads the section.
        let installed = [
            InstalledVoice(identifier: "com.apple.voice.premium.es-MX.Luciana",
                           language: "es-MX"),
        ]
        XCTAssertEqual(
            SustainedVoiceResolver.resolve(
                declaredVoiceId: "com.apple.voice.compact.es-ES.Monica",
                languageCode: "es-ES",
                installed: installed),
            "com.apple.voice.premium.es-MX.Luciana")
    }

    func testVoiceResolutionWithNoInstalledLanguageVoiceResolvesNil() {
        let installed = [
            InstalledVoice(identifier: "com.apple.voice.compact.fr-FR.Amelie",
                           language: "fr-FR"),
        ]
        XCTAssertNil(SustainedVoiceResolver.resolve(
            declaredVoiceId: "com.apple.voice.compact.es-ES.Monica",
            languageCode: "es-ES",
            installed: installed),
            "no installed Spanish voice → nil; the renderer falls back to the "
            + "language's system voice and the section still plays")
    }

    func testMissingVoiceRecordingReportsAbsentDeclaredVoicesOnce() {
        let installed = [
            InstalledVoice(identifier: "com.apple.voice.compact.es-MX.Paulina",
                           language: "es-MX"),
        ]
        let missing = SustainedVoiceResolver.missingVoices(
            declaredVoiceIds: [
                "com.apple.voice.compact.es-ES.Monica",
                "com.apple.voice.compact.es-MX.Paulina",
                "com.apple.voice.compact.es-ES.Monica",
            ],
            installed: installed)
        XCTAssertEqual(missing, ["com.apple.voice.compact.es-ES.Monica"],
                       "missing voices are recorded once, in declared order")
    }

    // MARK: Transcript visibility state machine

    func testTranscriptStaysHiddenThroughTheFirstPass() {
        var state = SustainedTranscriptState(sectionCount: 5)
        XCTAssertFalse(state.isRevealed, "the transcript is hidden before the first pass")
        state.markPlayed(0)
        state.markPlayed(2)
        XCTAssertFalse(state.isRevealed,
                       "a part-heard passage keeps the transcript hidden")
        for index in [1, 3, 4] { state.markPlayed(index) }
        XCTAssertTrue(state.firstPassComplete)
        XCTAssertTrue(state.isRevealed,
                      "the transcript appears after the full first pass")
    }

    func testTranscriptExplicitRevealIsDeliberateAndImmediate() {
        var state = SustainedTranscriptState(sectionCount: 3)
        state.reveal()
        XCTAssertTrue(state.isRevealed,
                      "a deliberate reveal beats the first-pass gate")
        XCTAssertFalse(state.firstPassComplete,
                       "revealing the transcript is not a full pass")
    }

    func testTranscriptStateIgnoresOutOfRangeSections() {
        var state = SustainedTranscriptState(sectionCount: 2)
        state.markPlayed(5)
        state.markPlayed(-1)
        XCTAssertFalse(state.firstPassComplete, "out-of-range sections are ignored")
        state.markPlayed(0)
        state.markPlayed(1)
        XCTAssertTrue(state.firstPassComplete)
        var zero = SustainedTranscriptState(sectionCount: 0)
        zero.markPlayed(0)
        XCTAssertFalse(zero.firstPassComplete, "an empty passage never completes a pass")
    }

    // MARK: Host-step shape

    /// Every 6.1B launch step is a required information step whose activity
    /// resolves and whose material resolves — the shape the experience lanes
    /// (and the lesson player's Continue button) depend on.
    func testSustainedLaunchStepsAreInformationStepsWithResolvableMaterial() throws {
        let pack = try spanishPack()
        var sustainedSteps = 0
        for lesson in pack.lessons {
            for step in lesson.steps {
                guard step.sustainedTextId != nil || step.sustainedListeningId != nil else {
                    continue
                }
                sustainedSteps += 1
                XCTAssertTrue(step.required, "launch step \(step.id) must be required")
                guard let activity = pack.activity(id: step.activityId) else {
                    XCTFail("launch step \(step.id) has no activity")
                    continue
                }
                guard case .information = activity else {
                    XCTFail("launch step \(step.id) must be an information step")
                    continue
                }
                if let textId = step.sustainedTextId {
                    XCTAssertNotNil(pack.sustainedText(id: textId),
                                    "step \(step.id) must resolve text \(textId)")
                }
                if let listeningId = step.sustainedListeningId {
                    XCTAssertNotNil(pack.sustainedListening(id: listeningId),
                                    "step \(step.id) must resolve listening \(listeningId)")
                }
            }
        }
        XCTAssertEqual(sustainedSteps, 18, "the pack ships eighteen sustained launch steps")
    }

    // MARK: Copy discipline

    /// The lane's learner-facing copy never claims a level, CEFR band, or
    /// proficiency — and every synthesised-audio string says so somewhere.
    func testSustainedCopyHasNoLevelOrProficiencyClaims() {
        let banned = ["level", "cefr", "a1", "a2", "b1", "b2",
                      "proficien", "mastery", "fluent", "native"]
        for string in SustainedCopy.allStrings {
            let folded = string.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "en"))
            for word in banned where folded.localizedCaseInsensitiveContains(word) {
                XCTFail("copy must not claim a level or proficiency: "
                        + "\"\(string)\" mentions \"\(word)\"")
            }
        }
        XCTAssertTrue(SustainedCopy.synthesisedNote("Spanish")
                        .localizedCaseInsensitiveContains("synth"),
                      "the synthesised-audio label must use the app's synth wording")
        XCTAssertTrue(SustainedCopy.synthesisedHint
                        .localizedCaseInsensitiveContains("synth"),
                      "the voice hints must label the audio as synthesised")
    }

    // MARK: - Open tasks (Phase 6.2)

    /// The authored Spanish open tasks, verbatim — the developer
    /// approves the goal / required points / model / rubric copy here in
    /// one place (plan 6.2), and these pins keep it stable.
    func testOpenTasksAreAuthoredAsApproved() throws {
        let pack = try spanishPack()
        func openTask(_ id: String) throws -> OpenTaskActivity {
            let act = try activity(id, in: pack)
            guard case .openTask(let spec) = act else {
                throw NSError(
                    domain: "PackSpanishTests", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "\(id) must be an open task"])
            }
            return spec
        }

        // 1. Written narrative retell — hosted by «Contar el fin de semana».
        let fin = try openTask("es-a2-fin-de-semana-open-task")
        XCTAssertEqual(fin.mode, .written)
        XCTAssertTrue(fin.skills.contains(.writing))
        XCTAssertEqual(
            fin.goal,
            "Write about your last weekend in a few connected sentences, the way the narrative did.")
        XCTAssertEqual(fin.requiredPoints, [
            "Say where you were or what you did — use past verbs (fui, hablé, comí…).",
            "Add at least one time word (el sábado, ayer, por la mañana…).",
            "Close with how it went: La comida fue buena / La película fue divertida…",
        ])
        XCTAssertEqual(
            fin.modelResponse,
            "El sábado fui al mercado con mi hermana. Compramos fruta y hablamos con el señor de las naranjas. Por la tarde comí en casa de mi abuela — la comida fue muy buena.")
        XCTAssertEqual(fin.rubric.map(\.id),
                       ["meaning", "organization", "useful-language", "repair"])
        XCTAssertEqual(fin.rubric.map(\.text), [
            "My sentences say something real about my weekend.",
            "It hangs together: what, when, and how it ended.",
            "I used past verbs and a time word I have practised.",
            "I noticed a mistake and fixed it while writing.",
        ])
        XCTAssertEqual(fin.lengthGuidance,
                       "A few connected sentences (three or four is plenty).")

        // 2. Spoken café order — hosted by «At the café».
        let cafe = try openTask("es-cafe-requests-foundation-open-task")
        XCTAssertEqual(cafe.mode, .spoken)
        XCTAssertTrue(cafe.skills.contains(.speaking))
        XCTAssertEqual(
            cafe.goal,
            "At the café counter, make your order out loud: greet, ask politely with quisiera, and close politely.")
        XCTAssertEqual(cafe.requiredPoints, [
            "Use the polite request: Quisiera…, por favor.",
            "Name the drink with its article (un café / un té) and keep the accents.",
            "Add the exchange you might hear back: ¿Algo más? → No, gracias.",
        ])
        XCTAssertEqual(
            cafe.modelResponse,
            "Hola. Quisiera un café, por favor. — Claro. ¿Algo más? — No, gracias.")
        XCTAssertEqual(cafe.rubric.map(\.text), [
            "My request would be understood at a café counter.",
            "I greet, order, and close in a natural order.",
            "I used quisiera + the drink + por favor, with the accents right.",
            "I heard myself and fixed a slip by re-recording.",
        ])
        XCTAssertEqual(cafe.lengthGuidance,
                       "About a minute of speaking (60–90 seconds is a soft target).")

        // 3. Spoken weekend plans — hosted by «Plans and intentions».
        let plans = try openTask("es-a2-planes-intenciones-open-task")
        XCTAssertEqual(plans.mode, .spoken)
        XCTAssertTrue(plans.skills.contains(.speaking))
        XCTAssertEqual(
            plans.goal,
            "Tell a friend your plans for this weekend out loud, using ir a for the decided plans.")
        XCTAssertEqual(plans.requiredPoints, [
            "Open with one decided plan: Voy a… / Vamos a…",
            "Add a second plan with the same frame.",
            "Say what you are looking forward to with Quiero… — the wish behind the plan.",
        ])
        XCTAssertEqual(
            plans.modelResponse,
            "Este fin de semana voy a visitar a mi familia en Sevilla. El sábado vamos a comer en casa de mi tía. Quiero ver a mis primos — hace tiempo que no los veo.")
        XCTAssertEqual(plans.rubric.map(\.text), [
            "My plans would be clear to a friend.",
            "One plan, then another, then the wish behind them.",
            "I used ir a (voy a / vamos a) and quiero, and the second verb stayed unchanged.",
            "I heard a slip (like vas a instead of voy a) and re-recorded to fix it.",
        ])

        // Every task ships one authored hint and the four-dimension rubric.
        for task in [fin, cafe, plans] {
            XCTAssertEqual(task.hints.count, 1, "\(task.id) ships one hint")
            XCTAssertFalse(task.hints[0].isEmpty)
            XCTAssertEqual(task.rubric.count, 4, "\(task.id) uses the four-dimension rubric")
            XCTAssertEqual(Set(task.rubric.map(\.id)).count, 4,
                           "\(task.id) rubric ids are unique")
        }
    }

    /// Binding discipline: each open task is hosted by a required step on
    /// its lesson's trail — the fin-de-semana task sits between the
    /// sustained narrative and the recall step, while the café and plans
    /// tasks sit before their lessons' text final-response close (M5) —
    /// and the whole pack still validates.
    func testOpenTasksAreHostedOnTheLessonTrail() throws {
        let pack = try spanishPack()
        XCTAssertNoThrow(try PackValidator.validate(pack),
                         "the pack with open tasks must validate")

        let fin = try XCTUnwrap(pack.lesson(id: "es-a2-fin-de-semana"))
        let finStep = try XCTUnwrap(
            fin.steps.first { $0.id == "es-a2-fin-de-semana-step-open-task" })
        XCTAssertEqual(finStep.activityId, "es-a2-fin-de-semana-open-task")
        XCTAssertTrue(finStep.required)
        XCTAssertEqual(finStep.purpose, .transfer)
        let sustained = try XCTUnwrap(
            fin.steps.first { $0.id == "es-a2-fin-de-semana-step-sustained" })
        XCTAssertEqual(sustained.nextStepId, finStep.id,
                       "the task follows the sustained narrative")
        XCTAssertEqual(finStep.nextStepId, "es-a2-fin-de-semana-step-rb8",
                       "the task precedes the recall close")

        let cafeStep = try XCTUnwrap(
            pack.steps(hosting: "es-cafe-requests-foundation-open-task"))
        XCTAssertEqual(cafeStep.nextStepId,
                       "es-cafe-requests-foundation-step-es-cafe-requests-foundation-recall",
                       "the café task precedes the recall final response")
        XCTAssertTrue(cafeStep.required)

        let plansStep = try XCTUnwrap(
            pack.steps(hosting: "es-a2-planes-intenciones-open-task"))
        XCTAssertEqual(plansStep.nextStepId,
                       "es-a2-planes-intenciones-step-es-a2-planes-intenciones-read",
                       "the plans task precedes the read final response")
        XCTAssertTrue(plansStep.required)
    }

    /// Fallback (plan 6.2, item 4): a pack without any open tasks — the
    /// six-month-old five-pack shape plus sustained material — still
    /// decodes with zero open tasks and unchanged content. 6.2 only
    /// *added* open tasks: no authored id, prompt, answer, or revision
    /// changed, only `nextStepId` chains restored.
    func testPackWithoutOpenTasksStillLoadsUnchanged() throws {
        let content = try XCTUnwrap(
            Bundle.main.url(forResource: "Content", withExtension: nil),
            "test host must bundle the Content folder")
        let url = content.appendingPathComponent("packs/spanish.json")
        let raw = try Data(contentsOf: url)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: raw) as? [String: Any],
            "spanish.json must be a JSON object")

        let openTaskActivities: Set<String> = [
            "es-a2-fin-de-semana-open-task",
            "es-cafe-requests-foundation-open-task",
            "es-a2-planes-intenciones-open-task",
            "es-b1-viaje-escrito-open-task",
            "es-b1-plan-escrito-open-task",
            "es-b1-decision-escrito-open-task",
            "es-b1-historia-escrito-open-task",
            "es-b1-consecuencia-escrito-open-task",
            "es-b1-opinion-escrito-open-task",
            "es-b1-problema-escrito-open-task",
            "es-b1-resumen-escrito-open-task",
            "es-b2-argumento-open-task",
        ]
        let openTaskSteps: Set<String> = [
            "es-a2-fin-de-semana-step-open-task",
            "es-cafe-requests-foundation-step-open-task",
            "es-a2-planes-intenciones-step-open-task",
            "es-b1-viaje-escrito-step-open-task",
            "es-b1-plan-escrito-step-open-task",
            "es-b1-decision-escrito-step-open-task",
            "es-b1-historia-escrito-step-open-task",
            "es-b1-consecuencia-escrito-step-open-task",
            "es-b1-opinion-escrito-step-open-task",
            "es-b1-problema-escrito-step-open-task",
            "es-b1-resumen-escrito-step-open-task",
            "es-b2-argumento-escrito-step-open-task",
        ]
        var old = object
        let activities = try XCTUnwrap(old["activities"] as? [[String: Any]])
        old["activities"] = activities.filter {
            guard let id = $0["id"] as? String else { return true }
            return !openTaskActivities.contains(id)
        }
        let lessons = try XCTUnwrap(old["lessons"] as? [[String: Any]])
        old["lessons"] = lessons.map { lesson -> [String: Any] in
            var lesson = lesson
            guard let rawSteps = lesson["steps"] as? [[String: Any]] else { return lesson }
            // A removed step's successor may itself be removed (sustained →
            // open-task in the fin-de-semana lesson), so each predecessor
            // reroutes onto the surviving next step and the original
            // chains (rb7→rb8, café build→recall, plans write→read) are
            // restored with no dangling pointers.
            var removedNext = [String: String?]()
            var kept: [[String: Any]] = []
            for step in rawSteps {
                if (step["id"] as? String).map(openTaskSteps.contains) == true {
                    if let id = step["id"] as? String {
                        removedNext[id] = step["nextStepId"] as? String
                    }
                } else {
                    kept.append(step)
                }
            }
            lesson["steps"] = kept.map { step -> [String: Any] in
                var step = step
                if let id = step["id"] as? String,
                   let next = step["nextStepId"] as? String,
                   let replacement = removedNext[next] {
                    step["nextStepId"] = replacement
                }
                return step
            }
            return lesson
        }

        let pack = try JSONDecoder().decode(
            CoursePack.self,
            from: JSONSerialization.data(withJSONObject: old))
        let taskCount = pack.activities.reduce(into: 0) { count, activity in
            if case .openTask = activity { count += 1 }
        }
        XCTAssertEqual(taskCount, 0,
                       "packs without open tasks carry none")
        XCTAssertEqual(pack.activities.count, 887,
                       "the pre-6.2 activity count (899 − 11 open tasks − 1 unit-26 open task) is unchanged")
        XCTAssertEqual(pack.lessons.count, 106)
        XCTAssertEqual(pack.version, "0.7.15",
                       "only the version string may differ between 6.3 and its pre-6.3 shape")
        XCTAssertNoThrow(try PackValidator.validate(pack),
                         "a pack without open tasks must still validate")
    }

    // MARK: - Phase 6.3 branching exchanges

    /// The hosted Spanish exchanges, pinned verbatim — the developer
    /// approves the clarification + misunderstanding-recovery copy here in
    /// one place (plan 6.3), and these pins keep it stable. Choice turns
    /// are deterministic (authored option -> partner's next line); open
    /// turns are self-assessed against a 6.2-style rubric, never graded.
    func testDialogueExchangesAreAuthoredAsApproved() throws {
        let pack = try spanishPack()
        func dialogue(_ id: String) throws -> Dialogue {
            try XCTUnwrap(pack.dialogue(id: id), "missing dialogue \(id)")
        }
        func node(_ id: String, in d: Dialogue) throws -> DialogueNode {
            try XCTUnwrap(d.node(id: id), "missing node \(id) in \(d.id)")
        }

        // 1. Café — hosted by «At the café» (Foundation).
        let cafe = try dialogue("es-cafe-turno")
        XCTAssertEqual(cafe.hostLessonId, "es-cafe-requests-foundation")
        XCTAssertEqual(cafe.prerequisite, "es-cafe-requests-foundation")
        XCTAssertEqual(cafe.partner, "Waiter")
        XCTAssertEqual(cafe.goal,
                       "Order a coffee and sort out a misunderstanding with the waiter.")
        XCTAssertEqual(cafe.start, "greet")

        // The misunderstanding: the waiter mishears the coffee order as tea.
        // REQUIRED TURN — every path passes through it.
        let mishear = try node("mishear", in: cafe)
        XCTAssertEqual(mishear.kind, .misunderstanding)
        XCTAssertEqual(mishear.line, "¿Un té? Muy bien. Enseguida se lo traigo.")
        XCTAssertEqual(mishear.meaning, "A tea? Very good. I'll bring it right away.")
        // The authored recovery route: the corrective choice lands on a
        // recovery node, never a dead end.
        let repairChoice = try XCTUnwrap(
            mishear.choices.first { $0.id == "correct-coffee" })
        XCTAssertEqual(repairChoice.text, "No, perdón — un café, por favor.")
        XCTAssertEqual(repairChoice.next, "recover")
        let recover = try node("recover", in: cafe)
        XCTAssertEqual(recover.kind, .recovery)
        XCTAssertEqual(recover.line, "Ah, un café. Perdón, no le he oído bien.")
        XCTAssertEqual(recover.meaning, "Ah, a coffee. Sorry, I didn't hear you well.")

        // The ask-for-clarification move: the learner asks the waiter to
        // repeat, the waiter clarifies, the thread rejoins the misread.
        let clarifyGreet = try node("clarify-greet", in: cafe)
        XCTAssertEqual(clarifyGreet.kind, .clarification)
        XCTAssertEqual(clarifyGreet.line, "Claro. Le preguntaba qué quiere tomar.")
        XCTAssertEqual(clarifyGreet.meaning,
                       "Of course. I was asking what you would like to drink.")
        let clarifyMisread = try node("clarify-misread", in: cafe)
        XCTAssertEqual(clarifyMisread.kind, .clarification)
        XCTAssertEqual(clarifyMisread.line,
                       "He dicho que le traigo un té. ¿Es eso lo que quiere?")
        XCTAssertEqual(clarifyMisread.meaning,
                       "I said I'd bring you a tea. Is that what you want?")

        // The open turn: compose the reply, self-assess (never graded).
        let openTurn = try node("algo-mas", in: cafe)
        XCTAssertNil(openTurn.kind)
        XCTAssertTrue(openTurn.choices.isEmpty)
        XCTAssertEqual(openTurn.line, "¿Algo más?")
        XCTAssertEqual(
            openTurn.prompt,
            "The waiter asks if you want anything else. Compose your answer in Spanish: no, nothing else — thank you.")
        XCTAssertEqual(openTurn.modelResponse, "No, nada más, gracias.")
        XCTAssertEqual(openTurn.next, "done")
        XCTAssertEqual(openTurn.rubric?.map(\.id),
                       ["meaning", "organization", "useful-language", "repair"])
        XCTAssertEqual(openTurn.rubric?.map(\.text), [
            "My reply would be understood at a café.",
            "It fits the exchange: a polite no, and thanks.",
            "I used words from this lesson (nada más, gracias…).",
            "I caught a slip while writing and fixed it.",
        ])
        // Explicit end states.
        XCTAssertTrue(try node("done", in: cafe).complete)
        XCTAssertEqual(try node("done", in: cafe).line, "Perfecto. Aquí tiene. ¡Que lo disfrute!")
        XCTAssertTrue(try node("tea-done", in: cafe).complete)
        XCTAssertEqual(try node("tea-done", in: cafe).line, "Un té con leche. Enseguida se lo traigo.")

        // 2. Saturday plans — hosted by «Plans and intentions» (Developing).
        let plans = try dialogue("es-a2-planes-sabado")
        XCTAssertEqual(plans.hostLessonId, "es-a2-planes-intenciones")
        XCTAssertEqual(plans.prerequisite, "es-a2-planes-intenciones")
        XCTAssertEqual(plans.partner, "Friend")
        XCTAssertEqual(plans.goal,
                       "Agree on Saturday plans and repair a misunderstanding about the day.")
        XCTAssertEqual(plans.start, "invite")

        let mishearDay = try node("mishear-day", in: plans)
        XCTAssertEqual(mishearDay.kind, .misunderstanding)
        XCTAssertEqual(mishearDay.line, "¿El domingo? El domingo no puedo, lo siento.")
        XCTAssertEqual(mishearDay.meaning, "Sunday? I can't on Sunday, sorry.")
        let dayRepair = try XCTUnwrap(
            mishearDay.choices.first { $0.id == "fix-saturday" })
        XCTAssertEqual(dayRepair.text, "No, digo el sábado, no el domingo.")
        XCTAssertEqual(dayRepair.next, "recover-day")
        XCTAssertEqual(try node("recover-day", in: plans).kind, .recovery)
        XCTAssertEqual(try node("recover-day", in: plans).line, "¡Ah, el sábado! Sí, perfecto.")
        XCTAssertEqual(try node("clarify-invite", in: plans).kind, .clarification)
        XCTAssertEqual(try node("clarify-day", in: plans).kind, .clarification)

        let plansOpen = try node("plan-open", in: plans)
        XCTAssertTrue(plansOpen.choices.isEmpty)
        XCTAssertEqual(plansOpen.line, "Me encanta. ¿Y tú qué planes tienes el sábado?")
        XCTAssertEqual(
            plansOpen.prompt,
            "Your friend asks about your plans. Compose your answer in Spanish: your plan for Saturday in one or two sentences using voy a.")
        XCTAssertEqual(plansOpen.modelResponse,
                       "El sábado voy a ir al cine contigo y después voy a cenar con mis amigos.")
        XCTAssertEqual(plansOpen.next, "done")
        XCTAssertEqual(plansOpen.rubric?.map(\.id),
                       ["meaning", "organization", "useful-language", "repair"])
        XCTAssertTrue(try node("done", in: plans).complete)
        XCTAssertEqual(try node("done", in: plans).line, "¡Y yo voy contigo! Quedamos a las seis.")

        // Every open turn: 3-6 unique rubric criteria with text, one
        // model response, and a resolvable `next`. Open turns never carry
        // choices (the learner composes, never picks from authored options).
        for d in [cafe, plans] {
            for n in d.nodes where n.prompt != nil {
                XCTAssertTrue(n.choices.isEmpty,
                              "\(d.id) \(n.id): an open turn must not also offer choices")
                guard let rubric = n.rubric else {
                    return XCTFail("\(d.id) \(n.id): open turn needs a rubric")
                }
                XCTAssertTrue((3...6).contains(rubric.count),
                              "\(d.id) \(n.id): rubric out of 3-6 range")
                XCTAssertEqual(Set(rubric.map(\.id)).count, rubric.count,
                               "\(d.id) \(n.id): rubric ids unique")
                XCTAssertNotNil(d.node(id: n.next ?? ""),
                                "\(d.id) \(n.id): open turn next must resolve")
            }
        }
    }

    /// Graph hygiene for every authored exchange (validator-level, re-run
    /// headless in the test): every node reachable from the start, no
    /// dead ends (each non-end node continues), an explicit end state
    /// exists, and every end state is reachable along a real path.
    func testDialogueGraphReachabilityAndNoDeadEnds() throws {
        let pack = try spanishPack()
        XCTAssertNoThrow(try PackValidator.validate(pack),
                         "the pack with hosted exchanges must validate")

        let exchanges = pack.dialogues.filter { $0.hostLessonId != nil }
        XCTAssertFalse(exchanges.isEmpty)
        for dialogue in exchanges {
            let nodesById = Dictionary(uniqueKeysWithValues: dialogue.nodes.map { ($0.id, $0) })
            // Reachability from start.
            var visited = Set<String>()
            func visit(_ nodeId: String) {
                guard !visited.contains(nodeId), let node = nodesById[nodeId] else { return }
                visited.insert(nodeId)
                for choice in node.choices { visit(choice.next) }
                if let next = node.next { visit(next) }
            }
            visit(dialogue.start)
            XCTAssertEqual(visited, Set(dialogue.nodes.map(\.id)),
                           "\(dialogue.id): every node must be reachable from the start")

            // Explicit end states, reachable, and no dead ends.
            let ends = dialogue.nodes.filter(\.complete)
            XCTAssertFalse(ends.isEmpty, "\(dialogue.id): needs an explicit end state")
            for end in ends {
                XCTAssertTrue(visited.contains(end.id),
                              "\(dialogue.id): end state \(end.id) must be reachable")
            }
            for node in dialogue.nodes where !node.complete {
                let continues = !node.choices.isEmpty || node.next != nil
                XCTAssertTrue(continues, "\(dialogue.id) \(node.id): non-end node is a dead end")
                for choice in node.choices {
                    XCTAssertNotNil(nodesById[choice.next],
                                    "\(dialogue.id) \(node.id): choice target \(choice.next) must resolve")
                }
            }
        }
    }

    /// Required turns not skippable: breaking every path down, each path
    /// passes at least three learner turns (the partner's reply changes
    /// with the learner's own response) and lands on an explicit end state
    /// with no repeated node.
    func testEveryDialoguePathHasThreeOrMoreTurnsAndAnExplicitEnd() throws {
        let pack = try spanishPack()
        for dialogue in pack.dialogues where dialogue.hostLessonId != nil {
            let nodesById = Dictionary(uniqueKeysWithValues: dialogue.nodes.map { ($0.id, $0) })
            var paths: [[String]] = []
            func walk(_ nodeId: String, _ trail: [String]) {
                let path = trail + [nodeId]
                if nodesById[nodeId]!.complete {
                    paths.append(path)
                    return
                }
                var successors = nodesById[nodeId]!.choices.map(\.next)
                if let next = nodesById[nodeId]!.next { successors.append(next) }
                for successor in successors {
                    XCTAssertFalse(path.contains(successor),
                                   "\(dialogue.id): cycle at \(successor)")
                    walk(successor, path)
                }
            }
            walk(dialogue.start, [])
            XCTAssertFalse(paths.isEmpty, "\(dialogue.id): must have a path")

            for path in paths {
                let turns = path.filter { !nodesById[$0]!.complete }
                XCTAssertGreaterThanOrEqual(
                    turns.count, 3,
                    "\(dialogue.id) path \(path.joined(separator: " → ")): fewer than three learner turns")
                XCTAssertEqual(Set(path).count, path.count,
                               "\(dialogue.id): no node repeats on a path (nothing skippable, nothing doubled)")
                XCTAssertTrue(nodesById[path.last!]!.complete,
                              "\(dialogue.id): every path ends on an explicit end state")
                // Consecutive nodes follow real edges: choice next or open next.
                for index in 0..<(path.count - 1) {
                    let node = nodesById[path[index]]!
                    let follows = node.choices.contains { $0.next == path[index + 1] }
                        || node.next == path[index + 1]
                    XCTAssertTrue(follows,
                                  "\(dialogue.id): \(path[index]) does not route to \(path[index + 1])")
                }
            }
        }
    }

    /// Clarification and misunderstanding-repair routes: every hosted
    /// exchange ships both moves, every misunderstanding carries an
    /// authored recovery route, and both routes end in an explicit end
    /// state (no dead ends, no skipped required turns).
    func testDialogueClarificationAndRecoveryRoutesEndExplicitly() throws {
        let pack = try spanishPack()
        for dialogue in pack.dialogues where dialogue.hostLessonId != nil {
            let explanations = dialogue.nodes.compactMap(\.kind)
            XCTAssertTrue(explanations.contains(.clarification),
                          "\(dialogue.id): must include an ask-for-clarification move")
            XCTAssertTrue(explanations.contains(.misunderstanding),
                          "\(dialogue.id): must include a misunderstanding to repair")
            XCTAssertTrue(explanations.contains(.recovery),
                          "\(dialogue.id): must include an authored recovery node")

            let nodesById = Dictionary(uniqueKeysWithValues: dialogue.nodes.map { ($0.id, $0) })
            for node in dialogue.nodes where node.kind == .misunderstanding {
                let recoveryTargets = node.choices.compactMap { choice in
                    nodesById[choice.next]?.kind == .recovery ? choice.next : nil
                }
                XCTAssertFalse(recoveryTargets.isEmpty,
                               "\(dialogue.id) \(node.id): misunderstanding has no recovery route")

                // Every route from the misunderstanding lands on an explicit
                // end state (each recovery node is a turn with a route on).
                for recoveryId in recoveryTargets {
                    var reachedEnd = false
                    func walk(_ nodeId: String, _ trail: [String]) {
                        let path = trail + [nodeId]
                        if nodesById[nodeId]!.complete { reachedEnd = true; return }
                        for choice in nodesById[nodeId]!.choices {
                            guard !path.contains(choice.next) else { continue }
                            walk(choice.next, path)
                        }
                        if let next = nodesById[nodeId]!.next, !path.contains(next) {
                            walk(next, path)
                        }
                    }
                    walk(recoveryId, [])
                    XCTAssertTrue(reachedEnd,
                                   "\(dialogue.id): recovery route \(recoveryId) must reach an explicit end state")
                }
            }
        }
    }

    /// Host binding: each exchange is hosted by exactly one lesson, the
    /// host resolve, and the pack lookup mirrors the binding.
    func testHostedDialoguesBindToOneLessonEach() throws {
        let pack = try spanishPack()
        let hosted = pack.dialogues.filter { $0.hostLessonId != nil }
        XCTAssertEqual(hosted.count, 11)
        var hosts = Set<String>()
        for dialogue in hosted {
            let host = try XCTUnwrap(dialogue.hostLessonId)
            XCTAssertTrue(hosts.insert(host).inserted,
                          "a lesson hosts one dialogue each: \(host) duplicated")
            XCTAssertNotNil(pack.lesson(id: host),
                            "\(dialogue.id) host \(host) must be a lesson")
            XCTAssertEqual(pack.dialogue(hostedBy: host)?.id, dialogue.id,
                           "\(dialogue.id): pack.dialogue(hostedBy:) must resolve the binding")
        }
        XCTAssertEqual(hosts, Set(["es-cafe-requests-foundation",
                                   "es-a2-planes-intenciones",
                                   "es-b1-reprogramar-dialogo",
                                   "es-b1-decision-dialogo",
                                   "es-b1-plan-dialogo",
                                   "es-b1-reaccion-dialogo",
                                   "es-b1-cambio-dialogo",
                                   "es-b1-opinion-dialogo",
                                   "es-b1-problema-dialogo",
                                   "es-b1-aclarar-dialogo",
                                   "es-b2-dialogo-mediar"]),
                       "the Foundation café exchange, the Developing plans exchange, the B1 rebooking dialogue, the B1 job-offer dialogue, the B1 birthday-plan dialogue, the B1 storytelling-reaction dialogue, the B1 plan-change negotiation dialogue, the B1 opinion discussion dialogue, the B1 problem-fix negotiation dialogue, the B1 clarification dialogue, and the B2 street-debate mediation dialogue")
        // No orphaned host bindings — every host lesson exists (checked
        // above) and unhosted dialogues stay validated-only.
        for dialogue in pack.dialogues where dialogue.hostLessonId == nil {
            XCTAssertFalse(
                dialogue.nodes.contains { $0.prompt != nil || $0.kind != nil },
                "\(dialogue.id): unhosted dialogues must stay in the base (pre-6.3) shape")
        }
    }

    /// Fallback (plan 6.3, item 4): a pack without the dialogues — the
    /// pre-6.3 Spanish shape plus every other addition — still decodes
    /// with zero exchanges and unchanged content. 6.3 only *added*
    /// dialogues: no authored id, prompt, answer, or revision changed.
    func testPackWithoutDialogueFieldsStillLoadsUnchanged() throws {
        let content = try XCTUnwrap(
            Bundle.main.url(forResource: "Content", withExtension: nil),
            "test host must bundle the Content folder")
        let url = content.appendingPathComponent("packs/spanish.json")
        let raw = try Data(contentsOf: url)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: raw) as? [String: Any],
            "spanish.json must be a JSON object")
        var old = object
        old.removeValue(forKey: "dialogues")

        let pack = try JSONDecoder().decode(
            CoursePack.self,
            from: JSONSerialization.data(withJSONObject: old))
        XCTAssertTrue(pack.dialogues.isEmpty,
                      "packs without the key decode to an empty exchange array")
        XCTAssertEqual(pack.activities.count, 899)
        XCTAssertEqual(pack.lessons.count, 106)
        XCTAssertEqual(pack.version, "0.7.15",
                       "only the version string may differ between 6.3 and its pre-6.3 shape")
        XCTAssertNoThrow(try PackValidator.validate(pack),
                         "a pack without dialogues must still validate")
    }

    /// Unseen-wording discipline (plan 6.3): every learner-facing dialogue
    /// string — line, meaning, choice text/feedback, open prompt, model,
    /// rubric — uses wording unseen in the lesson activities (including
    /// open-task goal/model), checkpoint items, and sustained questions.
    /// Mirrors `verifyDialogueWording` in tools/check_packs.swift so the
    /// suite is headless.
    func testDialogueWordingIsUnseenAcrossThePack() throws {
        let pack = try spanishPack()
        func comparable(_ text: String) -> String {
            text.folding(options: .caseInsensitive, locale: nil)
                .unicodeScalars.filter { CharacterSet.letters.contains($0)
                    || CharacterSet.decimalDigits.contains($0) }
                .map(String.init).joined()
        }
        var activityTexts = Set<String>()
        for activity in pack.activities {
            let text: String
            switch activity {
            case .information(let info): text = info.body
            case .selfCompare(let sc): text = sc.prompt
            case .openTask(let ot): text = "\(ot.goal) \(ot.modelResponse)"
            default: text = activity.base?.prompt ?? ""
            }
            if !text.isEmpty { activityTexts.insert(comparable(text)) }
        }
        var checkpointTexts = Set<String>()
        for checkpoint in pack.checkpoints {
            for item in checkpoint.items {
                switch item {
                case .reading(let r): checkpointTexts.formUnion(
                    r.questions.map { comparable($0.question) })
                case .writing(let w): checkpointTexts.insert(comparable(w.prompt))
                case .speaking(let s): checkpointTexts.insert(comparable(s.prompt))
                }
            }
        }
        var sustainedTexts = Set<String>()
        for text in pack.sustainedTexts {
            sustainedTexts.formUnion(text.questions.map { comparable($0.question) })
        }
        for passage in pack.sustainedListenings {
            sustainedTexts.formUnion(passage.questions.map { comparable($0.question) })
        }

        var checked = 0
        for dialogue in pack.dialogues {
            for node in dialogue.nodes {
                func assertUnseen(_ string: String, _ context: String) {
                    checked += 1
                    let norm = comparable(string)
                    XCTAssertFalse(activityTexts.contains(norm),
                                   "\(dialogue.id) \(node.id) \(context) duplicates a lesson activity text")
                    XCTAssertFalse(checkpointTexts.contains(norm),
                                   "\(dialogue.id) \(node.id) \(context) duplicates a checkpoint text")
                    XCTAssertFalse(sustainedTexts.contains(norm),
                                   "\(dialogue.id) \(node.id) \(context) duplicates a sustained question")
                }
                assertUnseen(node.line, "line")
                assertUnseen(node.meaning, "meaning")
                if let prompt = node.prompt {
                    assertUnseen(prompt, "prompt")
                    assertUnseen(node.modelResponse ?? "", "model")
                    for criterion in node.rubric ?? [] {
                        assertUnseen(criterion.text, "rubric")
                    }
                }
                for choice in node.choices {
                    assertUnseen(choice.text, "choice text")
                    assertUnseen(choice.feedback, "choice feedback")
                }
            }
        }
        XCTAssertGreaterThan(checked, 50,
                             "the pin must cover every hosted exchange's learner-facing strings")
    }
}
