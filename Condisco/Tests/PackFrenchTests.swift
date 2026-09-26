import XCTest
@testable import Condisco

/// Per-pack editorial regression tests for the French pack.
///
/// Owned by the French editorial lane: add targeted answer/evaluation
/// tests here for content fixes (resolved high-confidence errors,
/// narrowed accepted-answer sets, authored error feedback). Do not put
/// other packs' tests in this file.
final class PackFrenchTests: XCTestCase {

    // MARK: - Helpers

    private func frenchPack() throws -> CoursePack {
        try XCTUnwrap(PackLoader.loadPacks().first { $0.language.slug == "french" })
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

    /// Grade a cloze blank's response against its authored AnswerSpec.
    private func gradeBlank(_ id: String, blank: String, in pack: CoursePack, _ response: String) throws -> AnswerEvaluation {
        let act = try activity(id, in: pack)
        guard case .cloze(let spec) = act else {
            throw XCTSkip("expected a cloze activity for \(id)")
        }
        guard let blankSpec = spec.blanks[blank] else {
            throw XCTSkip("expected blank \(blank) in \(id)")
        }
        return AnswerEngine.evaluate(response: response, spec: blankSpec)
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

    /// The five fr-unit-1 and four fr-unit-2 lessons of batch 1, keyed by
    /// the path activity ids each lesson references (graded steps only).
    private static let batch1Lessons: [String: [String]] = [
        "fr-cafe-mission": [
            "fr-cafe-mission-act-2", "fr-cafe-mission-act-4",
            "fr-cafe-mission-act-6", "fr-cafe-mission-act-7",
            "fr-cafe-mission-act-8", "fr-cafe-mission-act-9",
        ],
        "fr-identity-foundation": [
            "fr-identity-foundation-meet", "fr-identity-foundation-think-marc",
            "fr-identity-foundation-notice", "fr-identity-foundation-think-marie",
            "fr-identity-foundation-order", "fr-identity-foundation-transfer",
            "fr-identity-foundation-meaning", "fr-identity-foundation-cloze",
            "fr-identity-foundation-read", "fr-identity-foundation-listen-model",
        ],
        "fr-people-foundation": [
            "fr-people-foundation-meet", "fr-people-foundation-meaning",
            "fr-people-foundation-cloze", "fr-people-foundation-order",
            "fr-people-foundation-transform", "fr-people-foundation-produce",
            "fr-people-foundation-read", "fr-people-foundation-review",
            "fr-people-foundation-listen-model",
        ],
        "fr-family-foundation": [
            "fr-family-foundation-meet", "fr-family-foundation-produce",
            "fr-family-foundation-transform", "fr-family-foundation-order",
            "fr-family-foundation-cloze", "fr-family-foundation-meaning",
            "fr-family-foundation-read", "fr-family-foundation-review",
            "fr-family-foundation-listen-model",
        ],
        "fr-numbers-foundation": [
            "fr-numbers-foundation-meet", "fr-numbers-foundation-read",
            "fr-numbers-foundation-meaning", "fr-numbers-foundation-transform",
            "fr-numbers-foundation-order", "fr-numbers-foundation-cloze",
            "fr-numbers-foundation-produce", "fr-numbers-foundation-review",
            "fr-numbers-foundation-listen-model",
        ],
        "fr-home-foundation": [
            "fr-home-foundation-act-rb2", "fr-home-foundation-act-rb4",
            "fr-home-foundation-meet", "fr-home-foundation-cloze",
            "fr-home-foundation-act-rb6", "fr-home-foundation-act-rb7",
        ],
        "fr-descriptions-foundation": [
            "fr-descriptions-foundation-order", "fr-descriptions-foundation-act-rb2",
            "fr-descriptions-foundation-act-rb3", "fr-descriptions-foundation-cloze",
            "fr-descriptions-foundation-produce", "fr-descriptions-foundation-meet",
        ],
        "fr-plural-foundation": [
            "fr-plural-foundation-order", "fr-plural-foundation-act-rb2",
            "fr-plural-foundation-act-rb3", "fr-plural-foundation-cloze",
            "fr-plural-foundation-produce", "fr-plural-foundation-meet",
        ],
        "fr-routine-foundation": [
            "fr-routine-foundation-act-rb2", "fr-routine-foundation-act-rb4",
            "fr-routine-foundation-meet", "fr-routine-foundation-cloze",
            "fr-routine-foundation-act-rb6", "fr-routine-foundation-act-rb7",
        ],
    ]

    /// The seven Wave B French mission lessons (all missions outside
    /// fr-unit-1/fr-unit-2), keyed by the path activity ids each lesson
    /// references (graded steps only).
    private static let batch2Lessons: [String: [String]] = [
        "fr-food-foundation": [
            "fr-food-foundation-meet", "fr-food-foundation-act-rb2",
            "fr-food-foundation-order", "fr-food-foundation-cloze",
            "fr-food-foundation-produce", "fr-food-foundation-act-rb3",
            "fr-food-foundation-act-rb4",
        ],
        "fr-transport-foundation": [
            "fr-transport-foundation-meet", "fr-transport-foundation-act-rb2",
            "fr-transport-foundation-order", "fr-transport-foundation-cloze",
            "fr-transport-foundation-produce", "fr-transport-foundation-act-rb3",
            "fr-transport-foundation-act-rb4",
        ],
        "fr-emergency-foundation": [
            "fr-emergency-foundation-meet", "fr-emergency-foundation-act-rb2",
            "fr-emergency-foundation-order", "fr-emergency-foundation-cloze",
            "fr-emergency-foundation-produce", "fr-emergency-foundation-act-rb3",
            "fr-emergency-foundation-act-rb4",
        ],
        "fr-picnic-plan-mission": [
            "fr-picnic-plan-mission-act-2", "fr-picnic-plan-mission-act-3",
            "fr-picnic-plan-mission-act-4", "fr-picnic-plan-mission-act-5",
            "fr-picnic-plan-mission-act-6", "fr-picnic-plan-mission-act-7",
            "fr-picnic-plan-mission-act-8", "fr-picnic-plan-mission-act-9",
        ],
        "fr-city-mission": [
            "fr-city-mission-act-2", "fr-city-mission-act-3",
            "fr-city-mission-act-4", "fr-city-mission-act-5",
            "fr-city-mission-act-6", "fr-city-mission-act-7",
            "fr-city-mission-act-8", "fr-city-mission-act-9",
            "fr-city-mission-act-10",
        ],
        "fr-pharmacy-mission": [
            "fr-pharmacy-mission-act-2", "fr-pharmacy-mission-act-3",
            "fr-pharmacy-mission-act-4", "fr-pharmacy-mission-act-5",
            "fr-pharmacy-mission-act-6", "fr-pharmacy-mission-act-7",
            "fr-pharmacy-mission-act-8", "fr-pharmacy-mission-act-9",
            "fr-pharmacy-mission-act-10",
        ],
        "fr-a2-hotel-mission": [
            "fr-a2-hotel-mission-act-2", "fr-a2-hotel-mission-act-3",
            "fr-a2-hotel-mission-act-4", "fr-a2-hotel-mission-act-5",
            "fr-a2-hotel-mission-act-6", "fr-a2-hotel-mission-act-7",
            "fr-a2-hotel-mission-act-8", "fr-a2-hotel-mission-act-9",
        ],
    ]

    // MARK: - Pack load

    func testFrenchPackLoadsAndValidates() throws {
        let packs = try PackLoader.loadPacks()
        let pack = try XCTUnwrap(packs.first { $0.language.slug == "french" })
        XCTAssertFalse(pack.lessons.isEmpty, "French pack must ship lessons")
        XCTAssertNoThrow(try PackValidator.validate(pack), pack.id)
    }

    // MARK: - Hints (rubric H4)

    /// Every graded step in batch-1 lessons has a real authored hint, not the
    /// runtime generic fallbacks (audit_editorial hint-gap must stay 0).
    func testBatch1GradedStepsHaveAuthoredHints() throws {
        let pack = try frenchPack()
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
        let pack = try frenchPack()
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
        let pack = try frenchPack()

        // fr-identity-foundation
        var result = try gradeText("fr-identity-foundation-think-marc", in: pack, "Je suis Marie.")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeText("fr-identity-foundation-think-marc", in: pack, "Je Marc.")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeText("fr-identity-foundation-think-marie", in: pack, "Je suis français.")
        XCTAssertEqual(result.category, "wrong gender")
        result = try gradeText("fr-identity-foundation-transfer", in: pack, "Je suis Anna.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-identity-foundation-meaning", in: pack, "I am France.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeBlank("fr-identity-foundation-cloze", blank: "b1", in: pack, "est")
        XCTAssertEqual(result.category, "wrong conjugation")

        // fr-people-foundation
        result = try gradeText("fr-people-foundation-transform", in: pack, "Tu est française.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("fr-people-foundation-read", in: pack, "Marc")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-people-foundation-review", in: pack, "Tu es Anna.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeBlank("fr-people-foundation-cloze", blank: "b1", in: pack, "suis")
        XCTAssertEqual(result.category, "wrong conjugation")

        // fr-family-foundation
        result = try gradeText("fr-family-foundation-transform", in: pack, "J'ai un sœur.")
        XCTAssertEqual(result.category, "wrong article")
        result = try gradeText("fr-family-foundation-transform", in: pack, "Je ai une sœur.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-family-foundation-meaning", in: pack, "You have a brother.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-family-foundation-read", in: pack, "no")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeBlank("fr-family-foundation-cloze", blank: "b1", in: pack, "as")
        XCTAssertEqual(result.category, "wrong conjugation")

        // fr-numbers-foundation
        result = try gradeText("fr-numbers-foundation-read", in: pack, "vingt")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-numbers-foundation-transform", in: pack, "Tu ai vingt ans.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("fr-numbers-foundation-transform", in: pack, "Tu es vingt ans.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-numbers-foundation-listen-model", in: pack, "Je suis trente ans.")
        XCTAssertEqual(result.category, "incorrect answer")

        // fr-home-foundation
        result = try gradeBlank("fr-home-foundation-cloze", blank: "b1", in: pack, "La")
        XCTAssertEqual(result.category, "wrong article")
        result = try gradeBlank("fr-home-foundation-cloze", blank: "b1", in: pack, "Son")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-home-foundation-act-rb6", in: pack, "Le chat est sur le table.")
        XCTAssertEqual(result.category, "wrong article")
        result = try gradeText("fr-home-foundation-act-rb7", in: pack, "La maison de Marie est petit et blanc.")
        XCTAssertEqual(result.category, "wrong gender")
        result = try gradeText("fr-home-foundation-act-rb7", in: pack, "Le maison de Marie est petite et blanche.")
        XCTAssertEqual(result.category, "wrong article")

        // fr-descriptions-foundation
        result = try gradeBlank("fr-descriptions-foundation-cloze", blank: "b1", in: pack, "blanc")
        XCTAssertEqual(result.category, "wrong gender")
        result = try gradeBlank("fr-descriptions-foundation-cloze", blank: "b1", in: pack, "grande")
        XCTAssertEqual(result.category, "incorrect answer")

        // fr-plural-foundation
        result = try gradeBlank("fr-plural-foundation-cloze", blank: "b1", in: pack, "est")
        XCTAssertEqual(result.category, "wrong number")

        // fr-routine-foundation
        result = try gradeBlank("fr-routine-foundation-cloze", blank: "b1", in: pack, "es")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeBlank("fr-routine-foundation-cloze", blank: "b1", in: pack, "étudies")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-routine-foundation-act-rb6", in: pack, "Demain, elle va étudie.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("fr-routine-foundation-act-rb7", in: pack, "J'étudie français chaque jour.")
        XCTAssertEqual(result.category, "missing word")

        // fr-cafe-mission
        result = try gradeText("fr-cafe-mission-act-7", in: pack, "Un café.")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeText("fr-cafe-mission-act-7", in: pack, "Un café, s'il te plaît.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-cafe-mission-act-9", in: pack, "Bonjour. Merci. Un café, s'il vous plaît.")
        XCTAssertEqual(result.category, "word-order problem")
    }

    // MARK: - Accepted answers (prompt ↔ answers alignment)

    /// Natural replies accepted for comprehension/meaning prompts (batch-1
    /// alignment fixes: added answers no learner would be wrong to give).
    func testBatch1AcceptsNaturalAlternatives() throws {
        let pack = try frenchPack()

        // Reading comprehension — answers in full natural English.
        var result = try gradeText("fr-identity-foundation-read", in: pack, "Her name is Anna.")
        XCTAssertTrue(result.accepted, "full-sentence name answer must be accepted")
        result = try gradeText("fr-people-foundation-read", in: pack, "Anna is French.")
        XCTAssertTrue(result.accepted, "full-sentence subject answer must be accepted")
        result = try gradeText("fr-family-foundation-read", in: pack, "Yes, she does.")
        XCTAssertTrue(result.accepted, "'Yes, she does.' must be accepted")
        result = try gradeText("fr-family-foundation-read", in: pack, "She has a brother.")
        XCTAssertTrue(result.accepted, "'She has a brother.' must be accepted")

        // Number-answer reading comprehension: the age with 'ans' is fine.
        result = try gradeText("fr-numbers-foundation-read", in: pack, "trente ans")
        XCTAssertTrue(result.accepted, "'trente ans' must be accepted")

        // English meanings — natural contractions and short forms.
        result = try gradeText("fr-people-foundation-meaning", in: pack, "She's French.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("fr-family-foundation-meaning", in: pack, "You've got a sister.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("fr-numbers-foundation-meaning", in: pack, "You are thirty.")
        XCTAssertTrue(result.accepted)

        // fr-home-foundation final response: the story's own sentence is a
        // correct description of where the cat is.
        result = try gradeText("fr-home-foundation-act-rb6", in: pack, "Le chat dort sur le livre.")
        XCTAssertTrue(result.accepted, "story-accurate sentence must be accepted")

        // fr-routine-foundation: natural adverb placement.
        result = try gradeText("fr-routine-foundation-act-rb7", in: pack, "J'étudie chaque jour le français.")
        XCTAssertTrue(result.accepted, "adverb-between-verb-and-object placement must be accepted")
    }

    /// The four batch-1 prompts narrowed so fixed-string grading is fair:
    /// each now dictates the target form instead of inviting alternatives
    /// the answer key cannot accept.
    func testBatch1PromptNarrowingHolds() throws {
        let pack = try frenchPack()

        var base = try XCTUnwrap(pack.activity(id: "fr-home-foundation-cloze")?.base)
        XCTAssertTrue(base.prompt.contains("word for 'the'"),
                      "home cloze must dictate the definite article")
        base = try XCTUnwrap(pack.activity(id: "fr-home-foundation-act-rb6")?.base)
        XCTAssertEqual(base.prompt, "Write in French: The cat is on the book.",
                       "home final response must dictate the exact sentence")
        base = try XCTUnwrap(pack.activity(id: "fr-descriptions-foundation-cloze")?.base)
        XCTAssertTrue(base.prompt.contains("(white)"),
                      "descriptions cloze must dictate the adjective meaning")
        base = try XCTUnwrap(pack.activity(id: "fr-routine-foundation-cloze")?.base)
        XCTAssertTrue(base.prompt.contains("Anna’s words to Marc"),
                      "routine cloze must dictate the speaking context")
    }

    // MARK: - Wave B (missions outside fr-unit-1/fr-unit-2)

    /// Every graded step in the seven Wave B mission lessons has a real
    /// authored hint, not the runtime generic fallbacks.
    func testBatch2GradedStepsHaveAuthoredHints() throws {
        let pack = try frenchPack()
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

    /// Every text activity and cloze blank in the Wave B mission lessons
    /// authors error-specific feedback.
    func testBatch2TextActivitiesAuthorErrors() throws {
        let pack = try frenchPack()
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

    /// Plausible wrong answers in the Wave B missions hit their authored
    /// category + explanation and are never accepted.
    func testBatch2ErrorsFireForPlausibleWrongAnswers() throws {
        let pack = try frenchPack()

        // fr-food-foundation
        var result = try gradeText("fr-food-foundation-act-rb4", in: pack, "Je prends un café.")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeText("fr-food-foundation-act-rb4", in: pack, "Je prends un café et une thé.")
        XCTAssertEqual(result.category, "wrong article")
        result = try gradeText("fr-food-foundation-act-rb4", in: pack, "Je prend un café et un thé, s'il vous plaît.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeBlank("fr-food-foundation-cloze", blank: "b1", in: pack, "prendre")
        XCTAssertEqual(result.category, "incorrect answer")

        // fr-transport-foundation
        result = try gradeBlank("fr-transport-foundation-cloze", blank: "b1", in: pack, "vas")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("fr-transport-foundation-act-rb4", in: pack, "Je vais à la gare.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-transport-foundation-act-rb4", in: pack, "Je vas à Paris.")
        XCTAssertEqual(result.category, "wrong conjugation")

        // fr-emergency-foundation
        result = try gradeBlank("fr-emergency-foundation-cloze", blank: "b1", in: pack, "secours")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-emergency-foundation-act-rb4", in: pack, "12 rue de la Paix.")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeText("fr-emergency-foundation-act-rb4", in: pack, "Paris, 12 rue de la Paix.")
        XCTAssertEqual(result.category, "word-order problem")

        // fr-picnic-plan-mission
        result = try gradeBlank("fr-picnic-plan-mission-act-4", blank: "b1", in: pack, "trois")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeBlank("fr-picnic-plan-mission-act-6", blank: "b1", in: pack, "plaisirs")
        XCTAssertEqual(result.category, "wrong number")
        result = try gradeText("fr-picnic-plan-mission-act-8", in: pack, "Comment ça coûte ?")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-picnic-plan-mission-act-8", in: pack, "Combien coûte ça ?")
        XCTAssertEqual(result.category, "word-order problem")
        result = try gradeText("fr-picnic-plan-mission-act-9", in: pack, "Je vais le marché samedi.")
        XCTAssertEqual(result.category, "wrong preposition")
        result = try gradeText("fr-picnic-plan-mission-act-9", in: pack, "Tu vas au marché samedi.")
        XCTAssertEqual(result.category, "wrong conjugation")

        // fr-city-mission
        result = try gradeBlank("fr-city-mission-act-6", blank: "b1", in: pack, "vais")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("fr-city-mission-act-7", in: pack, "Où est la marché ?")
        XCTAssertEqual(result.category, "wrong article")
        result = try gradeText("fr-city-mission-act-7", in: pack, "Ou est le marché ?")
        XCTAssertEqual(result.category, "accent/diacritic issue")
        result = try gradeText("fr-city-mission-act-10", in: pack, "Je vais à la maison.")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeText("fr-city-mission-act-10", in: pack, "Je vais à le maison à midi.")
        XCTAssertEqual(result.category, "wrong article")

        // fr-pharmacy-mission
        result = try gradeBlank("fr-pharmacy-mission-act-5", blank: "b1", in: pack, "bois")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-pharmacy-mission-act-7", in: pack, "Je veux un médicament, s'il vous plaît.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-pharmacy-mission-act-7", in: pack, "Je voudrais un médicament.")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeText("fr-pharmacy-mission-act-10", in: pack, "Je prends un comprimé.")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeText("fr-pharmacy-mission-act-10", in: pack, "Je bois un comprimé ce soir.")
        XCTAssertEqual(result.category, "incorrect answer")

        // fr-a2-hotel-mission
        result = try gradeText("fr-a2-hotel-mission-act-3", in: pack, "J'ai réserver une chambre.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("fr-a2-hotel-mission-act-3", in: pack, "Je suis réservé une chambre.")
        XCTAssertEqual(result.category, "wrong auxiliary")
        result = try gradeBlank("fr-a2-hotel-mission-act-5", blank: "b1", in: pack, "deux")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-a2-hotel-mission-act-7", in: pack, "Avez-vous un chambre calme ?")
        XCTAssertEqual(result.category, "wrong article")
        result = try gradeText("fr-a2-hotel-mission-act-7", in: pack, "Tu as une chambre calme ?")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-a2-hotel-mission-act-9", in: pack, "Bonjour, j'ai réservé une chambre.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-a2-hotel-mission-act-9", in: pack, "Bonsoir, j'ai réservé chambre.")
        XCTAssertEqual(result.category, "missing word")
    }

    /// Natural alternative answers accepted for the Wave B missions (Wave B
    /// alignment fixes).
    func testBatch2AcceptsNaturalAlternatives() throws {
        let pack = try frenchPack()

        // Market price question — inverted word order is natural French.
        var result = try gradeText("fr-picnic-plan-mission-act-8", in: pack, "Ça coûte combien ?")
        XCTAssertTrue(result.accepted)

        // Hotel — non-inverted spoken question and 'second' for the floor.
        result = try gradeText("fr-a2-hotel-mission-act-7", in: pack, "Vous avez une chambre calme ?")
        XCTAssertTrue(result.accepted, "'Vous avez…' without inversion must be accepted")
        result = try gradeText("fr-a2-hotel-mission-act-7", in: pack, "Est-ce que vous avez une chambre calme ?")
        XCTAssertTrue(result.accepted)
        result = try gradeBlank("fr-a2-hotel-mission-act-5", blank: "b1", in: pack, "second")
        XCTAssertTrue(result.accepted, "'second' for the second floor must be accepted")
    }

    /// Every Wave B mission ends on a text final-response step (rubric M5,
    /// audit final-response gap). The two lessons that previously ended on an
    /// ordering step now close with a typed line.
    func testBatch2MissionsEndWithTextFinalResponse() throws {
        let pack = try frenchPack()
        for lessonId in Self.batch2Lessons.keys.sorted() {
            let lesson = try XCTUnwrap(pack.lesson(id: lessonId), lessonId)
            let terminals = lesson.steps.filter { $0.nextStepId == nil && $0.branches.isEmpty }
            XCTAssertFalse(terminals.isEmpty, "\(lessonId) must have a terminal step")
            for step in terminals {
                let act = try activity(step.activityId, in: pack)
                guard case .text = act else {
                    XCTFail("\(lessonId): terminal step \(step.id) must be a text activity")
                    continue
                }
            }
        }
        // The two repaired missions close on the dictated production line.
        let city = try XCTUnwrap(pack.lesson(id: "fr-city-mission"))
        XCTAssertTrue(city.steps.contains { $0.id == "fr-city-mission-step-10" },
                      "city mission must end at step-10")
        let pharmacy = try XCTUnwrap(pack.lesson(id: "fr-pharmacy-mission"))
        XCTAssertTrue(pharmacy.steps.contains { $0.id == "fr-pharmacy-mission-step-10" },
                      "pharmacy mission must end at step-10")
    }

    // MARK: - Wave C (the five remaining French story lessons)

    /// The five story lessons of Wave C (fr-unit-4, fr-unit-9, fr-unit-11),
    /// keyed by the path activity ids each lesson references (graded steps
    /// only).
    private static let batch3Lessons: [String: [String]] = [
        "fr-past-foundation": [
            "fr-past-foundation-act-rb2", "fr-past-foundation-act-rb4",
            "fr-past-foundation-meet", "fr-past-foundation-cloze",
            "fr-past-foundation-act-rb6", "fr-past-foundation-act-rb7",
        ],
        "fr-plans-foundation": [
            "fr-plans-foundation-act-rb2", "fr-plans-foundation-act-rb4",
            "fr-plans-foundation-meet", "fr-plans-foundation-cloze",
            "fr-plans-foundation-act-rb6", "fr-plans-foundation-act-rb7",
        ],
        "fr-a2-journee-recit": [
            "fr-a2-journee-recit-meet", "fr-a2-journee-recit-notice",
            "fr-a2-journee-recit-act-rb6", "fr-a2-journee-recit-cloze",
            "fr-a2-journee-recit-act-rb7",
        ],
        "fr-a2-conditionnel-souhait": [
            "fr-a2-conditionnel-souhait-meet", "fr-a2-conditionnel-souhait-notice",
            "fr-a2-conditionnel-souhait-act-rb6", "fr-a2-conditionnel-souhait-cloze",
            "fr-a2-conditionnel-souhait-act-rb7", "fr-a2-conditionnel-souhait-vary",
        ],
        "fr-a2-si-imparfait-intro": [
            "fr-a2-si-imparfait-intro-meet", "fr-a2-si-imparfait-intro-notice",
            "fr-a2-si-imparfait-intro-act-rb6", "fr-a2-si-imparfait-intro-cloze",
            "fr-a2-si-imparfait-intro-act-rb7", "fr-a2-si-imparfait-intro-vary",
        ],
    ]

    /// Every graded step in the five Wave C story lessons has a real authored
    /// hint, not the runtime generic fallbacks.
    func testBatch3GradedStepsHaveAuthoredHints() throws {
        let pack = try frenchPack()
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

    /// Every text activity and cloze blank in the Wave C story lessons
    /// authors error-specific feedback.
    func testBatch3TextActivitiesAuthorErrors() throws {
        let pack = try frenchPack()
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

    /// Plausible wrong answers in the Wave C stories hit their authored
    /// category + explanation and are never accepted.
    func testBatch3ErrorsFireForPlausibleWrongAnswers() throws {
        let pack = try frenchPack()

        // fr-past-foundation
        var result = try gradeBlank("fr-past-foundation-cloze", blank: "b1", in: pack, "suis")
        XCTAssertEqual(result.category, "wrong auxiliary")
        result = try gradeBlank("fr-past-foundation-cloze", blank: "b1", in: pack, "a")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("fr-past-foundation-act-rb6", in: pack, "Aujourd'hui, il repose.")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeText("fr-past-foundation-act-rb7", in: pack, "Hier, elle est travaillé.")
        XCTAssertEqual(result.category, "wrong auxiliary")
        result = try gradeText("fr-past-foundation-act-rb7", in: pack, "Hier, elle travaillé.")
        XCTAssertEqual(result.category, "missing word")

        // fr-plans-foundation
        result = try gradeBlank("fr-plans-foundation-cloze", blank: "b1", in: pack, "étudie")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("fr-plans-foundation-act-rb6", in: pack, "Demain, elle va étudie.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("fr-plans-foundation-act-rb6", in: pack, "Demain, elle va à étudier.")
        XCTAssertEqual(result.category, "wrong preposition")
        result = try gradeText("fr-plans-foundation-act-rb7", in: pack, "Demain, il va travaille à la maison.")
        XCTAssertEqual(result.category, "wrong conjugation")

        // fr-a2-journee-recit
        result = try gradeBlank("fr-a2-journee-recit-cloze", blank: "b1", in: pack, "Ensuite")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-a2-journee-recit-act-rb7", in: pack, "Enfin, je suis rentrer.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("fr-a2-journee-recit-act-rb7", in: pack, "Enfin, je rentré.")
        XCTAssertEqual(result.category, "missing word")

        // fr-a2-conditionnel-souhait
        result = try gradeBlank("fr-a2-conditionnel-souhait-cloze", blank: "b1", in: pack, "aimerais")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("fr-a2-conditionnel-souhait-act-rb7", in: pack, "J'aimerais visiter Paris.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-a2-conditionnel-souhait-act-rb7", in: pack, "J'aimerai visiter Rome.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("fr-a2-conditionnel-souhait-vary", in: pack, "Ils visiterons Rome.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("fr-a2-conditionnel-souhait-vary", in: pack, "Il visiterait Rome.")
        XCTAssertEqual(result.category, "wrong conjugation")

        // fr-a2-si-imparfait-intro
        result = try gradeBlank("fr-a2-si-imparfait-intro-cloze", blank: "b1", in: pack, "viens")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("fr-a2-si-imparfait-intro-act-rb7", in: pack, "Si j'ai le temps, je voyagerais.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("fr-a2-si-imparfait-intro-act-rb7", in: pack, "Si j'avais le temps, je dormirais.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-a2-si-imparfait-intro-vary", in: pack, "Si j'étais riche, j'achète une maison.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("fr-a2-si-imparfait-intro-vary", in: pack, "Si j'étais riche, j'achèterais un maison.")
        XCTAssertEqual(result.category, "wrong article")
    }

    /// Wave C prompt/answer alignment (H1): dictated forms stay accepted, and
    /// the free variants previously auto-graded as correct are now rejected
    /// because the prompt dictates the exact sentence.
    func testBatch3PromptAnswerAlignmentHolds() throws {
        let pack = try frenchPack()

        // fr-past-foundation — both natural word orders of the dictated
        // sentence are accepted.
        var result = try gradeText("fr-past-foundation-act-rb7", in: pack, "Hier, elle a travaillé.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("fr-past-foundation-act-rb7", in: pack, "Elle a travaillé hier.")
        XCTAssertTrue(result.accepted)

        // fr-a2-journee-recit — the narrator's gender is unstated, so both
        // rentré and rentrée are legitimately accepted.
        result = try gradeText("fr-a2-journee-recit-act-rb7", in: pack, "Enfin, je suis rentré.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("fr-a2-journee-recit-act-rb7", in: pack, "Enfin, je suis rentrée.")
        XCTAssertTrue(result.accepted)

        // fr-a2-conditionnel-souhait — dictated note line accepted (both
        // fixed renderings); the previous free variants are rejected.
        result = try gradeText("fr-a2-conditionnel-souhait-act-rb7", in: pack, "J'aimerais visiter Rome.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("fr-a2-conditionnel-souhait-act-rb7", in: pack, "Je voudrais visiter Rome.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("fr-a2-conditionnel-souhait-act-rb7", in: pack, "J'aimerais voyager.")
        XCTAssertFalse(result.accepted, "non-dictated variant must not be auto-graded as correct")
        result = try gradeText("fr-a2-conditionnel-souhait-act-rb7", in: pack, "Je voudrais voir le monde.")
        XCTAssertFalse(result.accepted, "non-dictated variant must not be auto-graded as correct")

        // fr-a2-si-imparfait-intro — only the dictated daydream accepted.
        result = try gradeText("fr-a2-si-imparfait-intro-act-rb7", in: pack, "Si j'avais le temps, je voyagerais.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("fr-a2-si-imparfait-intro-act-rb7", in: pack, "Si j'avais le temps, je dormirais.")
        XCTAssertFalse(result.accepted, "non-dictated daydream must not be auto-graded as correct")
        result = try gradeText("fr-a2-si-imparfait-intro-act-rb7", in: pack, "Je voyagerais.")
        XCTAssertFalse(result.accepted, "dropping the si-clause must not be auto-graded as correct")
    }

    /// Every Wave C story ends on a text final-response step (rubric M5,
    /// audit final-response gap stays 0).
    func testBatch3StoriesEndWithTextFinalResponse() throws {
        let pack = try frenchPack()
        for lessonId in Self.batch3Lessons.keys.sorted() {
            let lesson = try XCTUnwrap(pack.lesson(id: lessonId), lessonId)
            let terminals = lesson.steps.filter { $0.nextStepId == nil && $0.branches.isEmpty }
            XCTAssertFalse(terminals.isEmpty, "\(lessonId) must have a terminal step")
            for step in terminals {
                let act = try activity(step.activityId, in: pack)
                guard case .text = act else {
                    XCTFail("\(lessonId): terminal step \(step.id) must be a text activity")
                    continue
                }
            }
        }
    }
}