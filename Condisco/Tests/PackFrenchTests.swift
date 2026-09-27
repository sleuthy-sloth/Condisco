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

    // MARK: - Wave D (the ten remaining French A2 discovery lessons)

    /// The ten French discovery lessons of Wave D (fr-units 9–13), keyed by
    /// the path activity ids each lesson references (graded steps only).
    /// These cover the passé composé, the imparfait and their choice, the
    /// futur simple, the conditional of politeness, y/en, qui/que/où,
    /// comparatives, superlatives, and the subjunctive after il faut que.
    private static let batch4Lessons: [String: [String]] = [
        "fr-a2-passe-compose-formation": [
            "fr-a2-passe-compose-formation-meet", "fr-a2-passe-compose-formation-think",
            "fr-a2-passe-compose-formation-cloze", "fr-a2-passe-compose-formation-notice",
            "fr-a2-passe-compose-formation-build", "fr-a2-passe-compose-formation-vary",
            "fr-a2-passe-compose-formation-read",
        ],
        "fr-a2-imparfait-formation": [
            "fr-a2-imparfait-formation-think", "fr-a2-imparfait-formation-meet",
            "fr-a2-imparfait-formation-build", "fr-a2-imparfait-formation-notice",
            "fr-a2-imparfait-formation-vary", "fr-a2-imparfait-formation-cloze",
        ],
        "fr-a2-passe-imparfait-choix": [
            "fr-a2-passe-imparfait-choix-meet", "fr-a2-passe-imparfait-choix-notice",
            "fr-a2-passe-imparfait-choix-think", "fr-a2-passe-imparfait-choix-match",
            "fr-a2-passe-imparfait-choix-cloze", "fr-a2-passe-imparfait-choix-vary",
            "fr-a2-passe-imparfait-choix-read",
        ],
        "fr-a2-futur-formation": [
            "fr-a2-futur-formation-meet", "fr-a2-futur-formation-cloze",
            "fr-a2-futur-formation-think", "fr-a2-futur-formation-notice",
            "fr-a2-futur-formation-vary", "fr-a2-futur-formation-build",
            "fr-a2-futur-formation-read",
        ],
        "fr-a2-conditionnel-politesse": [
            "fr-a2-conditionnel-politesse-meet", "fr-a2-conditionnel-politesse-think",
            "fr-a2-conditionnel-politesse-cloze", "fr-a2-conditionnel-politesse-notice",
            "fr-a2-conditionnel-politesse-vary", "fr-a2-conditionnel-politesse-build",
            "fr-a2-conditionnel-politesse-read",
        ],
        "fr-a2-pronoms-y-en": [
            "fr-a2-pronoms-y-en-meet", "fr-a2-pronoms-y-en-match",
            "fr-a2-pronoms-y-en-think", "fr-a2-pronoms-y-en-notice",
            "fr-a2-pronoms-y-en-cloze", "fr-a2-pronoms-y-en-vary",
        ],
        "fr-a2-relatifs-qui-que-ou": [
            "fr-a2-relatifs-qui-que-ou-think", "fr-a2-relatifs-qui-que-ou-meet",
            "fr-a2-relatifs-qui-que-ou-notice", "fr-a2-relatifs-qui-que-ou-build",
            "fr-a2-relatifs-qui-que-ou-cloze", "fr-a2-relatifs-qui-que-ou-vary",
            "fr-a2-relatifs-qui-que-ou-read",
        ],
        "fr-a2-comparatifs": [
            "fr-a2-comparatifs-meet", "fr-a2-comparatifs-think",
            "fr-a2-comparatifs-notice", "fr-a2-comparatifs-cloze",
            "fr-a2-comparatifs-build", "fr-a2-comparatifs-vary",
        ],
        "fr-a2-superlatifs": [
            "fr-a2-superlatifs-meet", "fr-a2-superlatifs-think",
            "fr-a2-superlatifs-notice", "fr-a2-superlatifs-vary",
            "fr-a2-superlatifs-match", "fr-a2-superlatifs-cloze",
            "fr-a2-superlatifs-read",
        ],
        "fr-a2-subjonctif-intro": [
            "fr-a2-subjonctif-intro-meet", "fr-a2-subjonctif-intro-think",
            "fr-a2-subjonctif-intro-notice", "fr-a2-subjonctif-intro-build",
            "fr-a2-subjonctif-intro-cloze", "fr-a2-subjonctif-intro-vary",
        ],
    ]

    /// Every graded step in the ten Wave D discovery lessons has a real
    /// authored hint, not the runtime generic fallbacks.
    func testBatch4GradedStepsHaveAuthoredHints() throws {
        let pack = try frenchPack()
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

    /// Every text activity and cloze blank in the Wave D discovery lessons
    /// authors error-specific feedback.
    func testBatch4TextActivitiesAuthorErrors() throws {
        let pack = try frenchPack()
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

    /// Plausible wrong answers in the Wave D discovery lessons hit their
    /// authored category + explanation and are never accepted.
    func testBatch4ErrorsFireForPlausibleWrongAnswers() throws {
        let pack = try frenchPack()

        // fr-a2-passe-compose-formation
        var result = try gradeText("fr-a2-passe-compose-formation-think", in: pack, "J'ai finir.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("fr-a2-passe-compose-formation-think", in: pack, "Je fini.")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeText("fr-a2-passe-compose-formation-think", in: pack, "Je ai fini.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeBlank("fr-a2-passe-compose-formation-cloze", blank: "b1", in: pack, "sommes")
        XCTAssertEqual(result.category, "wrong auxiliary")
        result = try gradeBlank("fr-a2-passe-compose-formation-cloze", blank: "b1", in: pack, "avions")
        XCTAssertEqual(result.category, "wrong tense")
        result = try gradeText("fr-a2-passe-compose-formation-vary", in: pack, "Tu as parler.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("fr-a2-passe-compose-formation-vary", in: pack, "Tu a parlé.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("fr-a2-passe-compose-formation-vary", in: pack, "Tu es parlé.")
        XCTAssertEqual(result.category, "wrong auxiliary")
        result = try gradeText("fr-a2-passe-compose-formation-read", in: pack, "Le menu")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeText("fr-a2-passe-compose-formation-read", in: pack, "La pizza")
        XCTAssertEqual(result.category, "incorrect answer")

        // fr-a2-imparfait-formation
        result = try gradeText("fr-a2-imparfait-formation-think", in: pack, "J'ai fini.")
        XCTAssertEqual(result.category, "wrong tense")
        result = try gradeText("fr-a2-imparfait-formation-think", in: pack, "Je finisais.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-a2-imparfait-formation-think", in: pack, "Je finissait.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("fr-a2-imparfait-formation-vary", in: pack, "Ils prennent.")
        XCTAssertEqual(result.category, "wrong tense")
        result = try gradeText("fr-a2-imparfait-formation-vary", in: pack, "Ils prenait.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeBlank("fr-a2-imparfait-formation-cloze", blank: "b1", in: pack, "allons")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeBlank("fr-a2-imparfait-formation-cloze", blank: "b1", in: pack, "irons")
        XCTAssertEqual(result.category, "wrong tense")

        // fr-a2-passe-imparfait-choix
        result = try gradeText("fr-a2-passe-imparfait-choix-think", in: pack, "Le téléphone sonnait.")
        XCTAssertEqual(result.category, "wrong tense")
        result = try gradeText("fr-a2-passe-imparfait-choix-think", in: pack, "Le téléphone a sonner.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("fr-a2-passe-imparfait-choix-think", in: pack, "Le téléphone est sonné.")
        XCTAssertEqual(result.category, "wrong auxiliary")
        result = try gradeBlank("fr-a2-passe-imparfait-choix-cloze", blank: "b1", in: pack, "avait")
        XCTAssertEqual(result.category, "wrong tense")
        result = try gradeBlank("fr-a2-passe-imparfait-choix-cloze", blank: "b1", in: pack, "a")
        XCTAssertEqual(result.category, "wrong tense")
        result = try gradeText("fr-a2-passe-imparfait-choix-vary", in: pack, "Nous avons mangé à midi.")
        XCTAssertEqual(result.category, "wrong tense")
        result = try gradeText("fr-a2-passe-imparfait-choix-vary", in: pack, "Nous mangions à le midi.")
        XCTAssertEqual(result.category, "wrong article")
        result = try gradeText("fr-a2-passe-imparfait-choix-read", in: pack, "Le téléphone")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-a2-passe-imparfait-choix-read", in: pack, "Médecin")
        XCTAssertEqual(result.category, "missing word")

        // fr-a2-futur-formation
        result = try gradeText("fr-a2-futur-formation-think", in: pack, "Tu finis.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("fr-a2-futur-formation-think", in: pack, "Tu finissais.")
        XCTAssertEqual(result.category, "wrong tense")
        result = try gradeBlank("fr-a2-futur-formation-cloze", blank: "b1", in: pack, "travailles")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeBlank("fr-a2-futur-formation-cloze", blank: "b1", in: pack, "travaillera")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("fr-a2-futur-formation-vary", in: pack, "Je serai la.")
        XCTAssertEqual(result.category, "accent/diacritic issue")
        XCTAssertFalse(result.accepted, "la without the accent is not 'there'")
        result = try gradeText("fr-a2-futur-formation-vary", in: pack, "Je serais là.")
        XCTAssertEqual(result.category, "wrong tense")
        result = try gradeText("fr-a2-futur-formation-read", in: pack, "À neuf heures")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-a2-futur-formation-read", in: pack, "Neuf heures")
        XCTAssertEqual(result.category, "incorrect answer")

        // fr-a2-conditionnel-politesse
        result = try gradeText("fr-a2-conditionnel-politesse-think", in: pack, "Pouvez-vous m'aider ?")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("fr-a2-conditionnel-politesse-think", in: pack, "Pourriez-vous me aider ?")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeBlank("fr-a2-conditionnel-politesse-cloze", blank: "b1", in: pack, "veux")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeBlank("fr-a2-conditionnel-politesse-cloze", blank: "b1", in: pack, "voudrai")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("fr-a2-conditionnel-politesse-vary", in: pack, "Pourriez-vous montrer moi ?")
        XCTAssertEqual(result.category, "word-order problem")
        result = try gradeText("fr-a2-conditionnel-politesse-read", in: pack, "Une nuit")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-a2-conditionnel-politesse-read", in: pack, "Trois nuits")
        XCTAssertEqual(result.category, "incorrect answer")

        // fr-a2-pronoms-y-en
        result = try gradeText("fr-a2-pronoms-y-en-think", in: pack, "Tu veux du gâteau ?")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-a2-pronoms-y-en-think", in: pack, "Tu en veux du gâteau ?")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-a2-pronoms-y-en-think", in: pack, "Tu veux en ?")
        XCTAssertEqual(result.category, "word-order problem")
        result = try gradeBlank("fr-a2-pronoms-y-en-cloze", blank: "b1", in: pack, "y")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-a2-pronoms-y-en-vary", in: pack, "Je vais au café.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-a2-pronoms-y-en-vary", in: pack, "Je vais y.")
        XCTAssertEqual(result.category, "word-order problem")
        result = try gradeText("fr-a2-pronoms-y-en-vary", in: pack, "Je y vais.")
        XCTAssertEqual(result.category, "incorrect answer")

        // fr-a2-relatifs-qui-que-ou
        result = try gradeText("fr-a2-relatifs-qui-que-ou-think", in: pack, "Le rapport qui j'écris.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-a2-relatifs-qui-que-ou-think", in: pack, "Le rapport que je écris.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-a2-relatifs-qui-que-ou-think", in: pack, "Je écris le rapport.")
        XCTAssertEqual(result.category, "word-order problem")
        result = try gradeBlank("fr-a2-relatifs-qui-que-ou-cloze", blank: "b1", in: pack, "qui")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeBlank("fr-a2-relatifs-qui-que-ou-cloze", blank: "b1", in: pack, "où")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-a2-relatifs-qui-que-ou-vary", in: pack, "Le collègue que m'aide est sympa.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-a2-relatifs-qui-que-ou-vary", in: pack, "Le collègue qui aide moi est sympa.")
        XCTAssertEqual(result.category, "word-order problem")
        result = try gradeText("fr-a2-relatifs-qui-que-ou-read", in: pack, "Le rapport")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-a2-relatifs-qui-que-ou-read", in: pack, "Une fenêtre")
        XCTAssertEqual(result.category, "missing word")

        // fr-a2-comparatifs
        result = try gradeText("fr-a2-comparatifs-think", in: pack, "Le train est moins chère.")
        XCTAssertEqual(result.category, "wrong gender")
        result = try gradeText("fr-a2-comparatifs-think", in: pack, "Le train est moins.")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeText("fr-a2-comparatifs-think", in: pack, "Le train coûte moins cher.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeBlank("fr-a2-comparatifs-cloze", blank: "b1", in: pack, "moins")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeBlank("fr-a2-comparatifs-cloze", blank: "b1", in: pack, "aussi")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-a2-comparatifs-vary", in: pack, "L'avion est plus rapide que la train.")
        XCTAssertEqual(result.category, "wrong article")
        result = try gradeText("fr-a2-comparatifs-vary", in: pack, "L'avion est plus rapide le train.")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeText("fr-a2-comparatifs-vary", in: pack, "L'avion est plus vite que le train.")
        XCTAssertEqual(result.category, "incorrect answer")

        // fr-a2-superlatifs
        result = try gradeText("fr-a2-superlatifs-think", in: pack, "C'est le moins chère.")
        XCTAssertEqual(result.category, "wrong article")
        result = try gradeText("fr-a2-superlatifs-think", in: pack, "C'est la moins cher.")
        XCTAssertEqual(result.category, "wrong gender")
        result = try gradeText("fr-a2-superlatifs-think", in: pack, "C'est la plus chère.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeBlank("fr-a2-superlatifs-cloze", blank: "b1", in: pack, "le plus bon")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeBlank("fr-a2-superlatifs-cloze", blank: "b1", in: pack, "la meilleure")
        XCTAssertEqual(result.category, "wrong gender")
        result = try gradeText("fr-a2-superlatifs-vary", in: pack, "Le plus célèbre monument.")
        XCTAssertEqual(result.category, "word-order problem")
        result = try gradeText("fr-a2-superlatifs-vary", in: pack, "La monument le plus célèbre.")
        XCTAssertEqual(result.category, "wrong article")
        result = try gradeText("fr-a2-superlatifs-read", in: pack, "Le monument le plus célèbre")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-a2-superlatifs-read", in: pack, "The most beautiful view.")
        XCTAssertEqual(result.category, "incorrect answer")

        // fr-a2-subjonctif-intro
        result = try gradeText("fr-a2-subjonctif-intro-think", in: pack, "Il faut que tu bois de l'eau.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("fr-a2-subjonctif-intro-think", in: pack, "Il faut que tu boire de l'eau.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("fr-a2-subjonctif-intro-think", in: pack, "Il faut tu boives de l'eau.")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeBlank("fr-a2-subjonctif-intro-cloze", blank: "b1", in: pack, "prends")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeBlank("fr-a2-subjonctif-intro-cloze", blank: "b1", in: pack, "prenne")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("fr-a2-subjonctif-intro-vary", in: pack, "Il faut que elle dorme huit heures.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-a2-subjonctif-intro-vary", in: pack, "Il faut qu'elle dort huit heures.")
        XCTAssertEqual(result.category, "wrong conjugation")
    }

    /// Wave D alignment fixes (H1): natural alternatives accepted where the
    /// prompt legitimately allows them.
    func testBatch4AcceptsNaturalAlternatives() throws {
        let pack = try frenchPack()

        // Reading comprehension — full natural English answers.
        var result = try gradeText("fr-a2-passe-compose-formation-read", in: pack, "The menu of the day.")
        XCTAssertTrue(result.accepted, "full English set-menu answer must be accepted")
        result = try gradeText("fr-a2-passe-compose-formation-read", in: pack, "The set menu.")
        XCTAssertTrue(result.accepted, "'the set menu' is the natural rendering of le menu du jour")

        // The full adjective is standard French alongside the colloquial sympa.
        result = try gradeText("fr-a2-relatifs-qui-que-ou-vary", in: pack, "Le collègue qui m'aide est sympathique.")
        XCTAssertTrue(result.accepted, "sympathique must be accepted alongside sympa")

        // The dictated future form is the only accepted rendering.
        result = try gradeText("fr-a2-futur-formation-vary", in: pack, "Je serai là.")
        XCTAssertTrue(result.accepted)
    }

    /// Wave D prompt/answer alignment (H1): the cloze prompts that previously
    /// left the tense or direction under-determined now dictate the target,
    /// and the dictation no longer accepts a wrong word for a dictated one.
    func testBatch4PromptNarrowingHolds() throws {
        let pack = try frenchPack()

        // The comparative cloze now dictates "more", so moins/aussi are
        // rejectable without being arbitrary.
        var base = try XCTUnwrap(pack.activity(id: "fr-a2-comparatifs-cloze")?.base)
        XCTAssertTrue(base.prompt.contains("more comfortable"),
                      "comparatives cloze must dictate the comparison direction")

        // The tense-naming cloze prompts now name the tense under test.
        base = try XCTUnwrap(pack.activity(id: "fr-a2-passe-compose-formation-cloze")?.base)
        XCTAssertTrue(base.prompt.contains("passé composé"),
                      "passé composé cloze must dictate the tense")
        base = try XCTUnwrap(pack.activity(id: "fr-a2-imparfait-formation-cloze")?.base)
        XCTAssertTrue(base.prompt.contains("imparfait"),
                      "imparfait cloze must dictate the tense")
        base = try XCTUnwrap(pack.activity(id: "fr-a2-futur-formation-cloze")?.base)
        XCTAssertTrue(base.prompt.contains("futur"),
                      "futur cloze must dictate the tense")
        base = try XCTUnwrap(pack.activity(id: "fr-a2-subjonctif-intro-cloze")?.base)
        XCTAssertTrue(base.prompt.contains("subjonctif"),
                      "subjunctive cloze must dictate the mood")

        // The superlative think step previously glossed "(hotel)" while
        // drilling the feminine crown — incoherent; it now dictates feminine.
        base = try XCTUnwrap(pack.activity(id: "fr-a2-superlatifs-think")?.base)
        XCTAssertFalse(base.prompt.contains("hotel"),
                       "superlatives think must not contradict its feminine answer")
        XCTAssertTrue(base.prompt.contains("cheapest"),
                      "superlatives think must keep the cheapest direction")

        // The dictation "I will be there" accepts only là; the accentless la
        // (the article) is an authored accent error, not an accepted answer.
        let spec = try gradeText("fr-a2-futur-formation-vary", in: pack, "Je serai la.")
        XCTAssertEqual(spec.category, "accent/diacritic issue")
        XCTAssertFalse(spec.accepted, "accentless la must not be silently accepted")
        let accepted = try activity("fr-a2-futur-formation-vary", in: pack)
        guard case .text(let textSpec) = accepted else {
            return XCTFail("fr-a2-futur-formation-vary must be a text activity")
        }
        XCTAssertFalse(
            textSpec.answer.answers.contains { $0.hasSuffix("la.") },
            "the accentless la must not sit in the accepted list")
    }

    // MARK: - Wave E (the seven French conversation lessons)

    /// The seven conversation lessons of Wave E (fr-units 4–6), keyed by the
    /// path activity ids each lesson references (graded steps only). These
    /// cover polite requests, weather small talk, market prices, doctor and
    /// pharmacy visits, invitations, and café ordering/paying.
    private static let batch5Lessons: [String: [String]] = [
        "fr-weather-foundation": [
            "fr-weather-foundation-act-rb2", "fr-weather-foundation-meet",
            "fr-weather-foundation-produce", "fr-weather-foundation-act-rb3",
            "fr-weather-foundation-act-rb4", "fr-weather-foundation-meaning",
            "fr-weather-foundation-act-rb5",
        ],
        "fr-market-foundation": [
            "fr-market-foundation-act-rb2", "fr-market-foundation-meet",
            "fr-market-foundation-produce", "fr-market-foundation-act-rb3",
            "fr-market-foundation-act-rb4", "fr-market-foundation-meaning",
            "fr-market-foundation-act-rb5",
        ],
        "fr-health-foundation": [
            "fr-health-foundation-act-rb2", "fr-health-foundation-meet",
            "fr-health-foundation-produce", "fr-health-foundation-act-rb3",
            "fr-health-foundation-act-rb4", "fr-health-foundation-meaning",
            "fr-health-foundation-act-rb5",
        ],
        "fr-pharmacy-foundation": [
            "fr-pharmacy-foundation-act-rb2", "fr-pharmacy-foundation-meet",
            "fr-pharmacy-foundation-produce", "fr-pharmacy-foundation-act-rb3",
            "fr-pharmacy-foundation-act-rb4", "fr-pharmacy-foundation-meaning",
            "fr-pharmacy-foundation-act-rb5",
        ],
        "fr-invitations-foundation": [
            "fr-invitations-foundation-act-rb2", "fr-invitations-foundation-meet",
            "fr-invitations-foundation-produce", "fr-invitations-foundation-act-rb3",
            "fr-invitations-foundation-act-rb4", "fr-invitations-foundation-meaning",
            "fr-invitations-foundation-act-rb5",
        ],
        "fr-requests-foundation": [
            "fr-requests-foundation-act-rb2", "fr-requests-foundation-meet",
            "fr-requests-foundation-produce", "fr-requests-foundation-act-rb3",
            "fr-requests-foundation-act-rb4", "fr-requests-foundation-meaning",
            "fr-requests-foundation-act-rb5",
        ],
        "fr-cafe-order-foundation": [
            "fr-cafe-order-foundation-meet", "fr-cafe-order-foundation-meaning",
            "fr-cafe-order-foundation-cloze", "fr-cafe-order-foundation-order",
            "fr-cafe-order-foundation-transform", "fr-cafe-order-foundation-produce",
            "fr-cafe-order-foundation-read", "fr-cafe-order-foundation-review",
            "fr-cafe-order-foundation-listen-model", "fr-cafe-order-transfer",
        ],
    ]

    /// Every graded step in the seven Wave E conversation lessons has a real
    /// authored hint, not the runtime generic fallbacks.
    func testBatch5GradedStepsHaveAuthoredHints() throws {
        let pack = try frenchPack()
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

    /// Every text activity and cloze blank in the Wave E conversation lessons
    /// authors error-specific feedback.
    func testBatch5TextActivitiesAuthorErrors() throws {
        let pack = try frenchPack()
        for (lessonId, activityIds) in Self.batch5Lessons {
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

    /// Plausible wrong answers in the Wave E conversations hit their authored
    /// category + explanation and are never accepted.
    func testBatch5ErrorsFireForPlausibleWrongAnswers() throws {
        let pack = try frenchPack()

        // fr-weather-foundation — faire vs être, target adjective slips.
        var result = try gradeText("fr-weather-foundation-produce", in: pack, "Aujourd'hui, il est froid.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("fr-weather-foundation-produce", in: pack, "Il fait chaud aujourd'hui.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-weather-foundation-meaning", in: pack, "It is cold.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-weather-foundation-meaning", in: pack, "There is sun.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-weather-foundation-act-rb5", in: pack, "Quel temps fait-il ?")
        XCTAssertEqual(result.category, "incorrect answer")

        // fr-market-foundation — singular verb with un kilo, item named.
        result = try gradeText("fr-market-foundation-produce", in: pack, "Combien coûtent un kilo de pommes ?")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("fr-market-foundation-produce", in: pack, "Combien coûte le kilo de pommes ?")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-market-foundation-meaning", in: pack, "I have three euros.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-market-foundation-act-rb5", in: pack, "Combien coûtent un kilo de pain ?")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("fr-market-foundation-act-rb5", in: pack, "Ça coûte combien ?")
        XCTAssertEqual(result.category, "incorrect answer")

        // fr-health-foundation — avoir mal à construction, fever symptom.
        result = try gradeText("fr-health-foundation-produce", in: pack, "Ma tête est mal.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-health-foundation-produce", in: pack, "J'ai mal la tête.")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeText("fr-health-foundation-meaning", in: pack, "I have a headache.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-health-foundation-meaning", in: pack, "I am a fever.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-health-foundation-act-rb5", in: pack, "J'ai mal à la tête.")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeText("fr-health-foundation-act-rb5", in: pack, "Ma tête est mal depuis hier.")
        XCTAssertEqual(result.category, "incorrect answer")

        // fr-pharmacy-foundation — masculine médicament, je veux register.
        result = try gradeText("fr-pharmacy-foundation-produce", in: pack, "Je voudrais une médicament.")
        XCTAssertEqual(result.category, "wrong gender")
        result = try gradeText("fr-pharmacy-foundation-produce", in: pack, "Je veux un médicament.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-pharmacy-foundation-meaning", in: pack, "It costs fifty euros.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-pharmacy-foundation-act-rb5", in: pack, "Je veux un médicament, s'il vous plaît.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-pharmacy-foundation-act-rb5", in: pack, "Je voudrais une médicament, s'il vous plaît.")
        XCTAssertEqual(result.category, "wrong gender")

        // fr-invitations-foundation — venir not aller, refusal register.
        result = try gradeText("fr-invitations-foundation-produce", in: pack, "Tu veux aller dîner samedi ?")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-invitations-foundation-produce", in: pack, "Je veux venir dîner samedi ?")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-invitations-foundation-meaning", in: pack, "I am sorry, I do not want.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-invitations-foundation-act-rb5", in: pack, "Avec plaisir !")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-invitations-foundation-act-rb5", in: pack, "Désolé, je ne peux pas.")
        XCTAssertEqual(result.category, "incorrect answer")

        // fr-requests-foundation — infinitive after peux, tu/je mix.
        result = try gradeText("fr-requests-foundation-produce", in: pack, "Je peux prends un café.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("fr-requests-foundation-produce", in: pack, "Est-ce que je peux prendre le café ?")
        XCTAssertEqual(result.category, "wrong article")
        result = try gradeText("fr-requests-foundation-meaning", in: pack, "I can study at home.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-requests-foundation-act-rb5", in: pack, "Tu peux prendre un café, s'il vous plaît ?")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-requests-foundation-act-rb5", in: pack, "Je peux prends un café, s'il vous plaît ?")
        XCTAssertEqual(result.category, "wrong conjugation")

        // fr-cafe-order-foundation — re-authored from invitation to café theme:
        // voudrais register, un café gender, false-friend addition, price word
        // order, and the terminal price question.
        result = try gradeText("fr-cafe-order-foundation-meaning", in: pack, "The addition, please.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeBlank("fr-cafe-order-foundation-cloze", blank: "b1", in: pack, "addition")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeBlank("fr-cafe-order-foundation-cloze", blank: "b1", in: pack, "thé")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-cafe-order-foundation-transform", in: pack, "Je veux un café, s'il vous plaît.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-cafe-order-foundation-transform", in: pack, "Je voudrais une café, s'il vous plaît.")
        XCTAssertEqual(result.category, "wrong gender")
        result = try gradeText("fr-cafe-order-foundation-produce", in: pack, "Je veux un café, s'il vous plaît.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-cafe-order-foundation-produce", in: pack, "Je voudrais un café.")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeText("fr-cafe-order-foundation-read", in: pack, "deux")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-cafe-order-foundation-read", in: pack, "three")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-cafe-order-foundation-review", in: pack, "Appelez une ambulance !")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeText("fr-cafe-order-foundation-review", in: pack, "Au secours ! Appeler une ambulance !")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("fr-cafe-order-foundation-listen-model", in: pack, "Je voudrais un café.")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeText("fr-cafe-order-transfer", in: pack, "Combien coûte ça ?")
        XCTAssertEqual(result.category, "word-order problem")
        result = try gradeText("fr-cafe-order-transfer", in: pack, "Je voudrais un café, s'il vous plaît.")
        XCTAssertEqual(result.category, "incorrect answer")
    }

    /// Wave E alignment fixes (H1/M4): natural renderings and natural spoken
    /// French variants accepted where the prompt legitimately allows them.
    func testBatch5AcceptsNaturalAlternatives() throws {
        let pack = try frenchPack()

        // English meanings — contracted natural forms.
        var result = try gradeText("fr-weather-foundation-meaning", in: pack, "It's sunny.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("fr-market-foundation-meaning", in: pack, "That's three euros.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("fr-market-foundation-meaning", in: pack, "It makes three euros.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("fr-health-foundation-meaning", in: pack, "I've got a fever.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("fr-pharmacy-foundation-meaning", in: pack, "That costs five euros.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("fr-invitations-foundation-meaning", in: pack, "Sorry, I can't.")
        XCTAssertTrue(result.accepted)

        // The café bill: US "check" is as natural as UK "bill".
        result = try gradeText("fr-cafe-order-foundation-meaning", in: pack, "The check, please.")
        XCTAssertTrue(result.accepted)

        // Natural spoken price questions for the café terminal.
        result = try gradeText("fr-cafe-order-transfer", in: pack, "Ça coûte combien ?")
        XCTAssertTrue(result.accepted)
        result = try gradeText("fr-cafe-order-transfer", in: pack, "C'est combien ?")
        XCTAssertTrue(result.accepted)

        // Weather opener short form and the read answer with the unit.
        result = try gradeText("fr-weather-foundation-act-rb5", in: pack, "Il fait beau, non ?")
        XCTAssertTrue(result.accepted)
        result = try gradeText("fr-cafe-order-foundation-read", in: pack, "trois euros")
        XCTAssertTrue(result.accepted)

        // Pharmacy transfer: with or without s'il vous plaît.
        result = try gradeText("fr-pharmacy-foundation-act-rb5", in: pack, "Je voudrais un médicament.")
        XCTAssertTrue(result.accepted)
    }

    /// Wave E prompt/answer alignment (H1): the transfer prompts previously
    /// invited open speech against a fixed list; each now dictates the exact
    /// taught line, and the old open answers are rejectable authored errors.
    func testBatch5PromptNarrowingHolds() throws {
        let pack = try frenchPack()

        // Weather transfer: the model opener is dictated; the generic
        // "Quel temps fait-il ?" is a rejectable authored error.
        var base = try XCTUnwrap(pack.activity(id: "fr-weather-foundation-act-rb5")?.base)
        XCTAssertTrue(base.prompt.contains("Write in French"),
                      "weather transfer must dictate the model opener")

        // Market transfer: names the kilo of bread.
        base = try XCTUnwrap(pack.activity(id: "fr-market-foundation-act-rb5")?.base)
        XCTAssertTrue(base.prompt.contains("un kilo de pain"),
                      "market transfer must name the item and quantity")

        // Health transfer: dictates the depuis hier line, so the bare
        // symptom sentence is an authored missing-word error.
        base = try XCTUnwrap(pack.activity(id: "fr-health-foundation-act-rb5")?.base)
        XCTAssertTrue(base.prompt.contains("since yesterday"),
                      "health transfer must dictate the depuis hier line")

        // Pharmacy transfer: polite register dictated.
        base = try XCTUnwrap(pack.activity(id: "fr-pharmacy-foundation-act-rb5")?.base)
        XCTAssertTrue(base.prompt.contains("I would like some medicine"),
                      "pharmacy transfer must dictate the polite request")

        // Invitations transfer: the warm refusal reply is dictated, so the
        // acceptance phrase is a rejectable authored error.
        base = try XCTUnwrap(pack.activity(id: "fr-invitations-foundation-act-rb5")?.base)
        XCTAssertTrue(base.prompt.contains("warm reply"),
                      "invitations transfer must dictate the warm reply")
        let inviteResult = try gradeText("fr-invitations-foundation-act-rb5", in: pack, "Avec plaisir !")
        XCTAssertFalse(inviteResult.accepted, "acceptance phrase must not auto-grade on a refusal step")

        // Requests transfer: the polite café request with s'il vous plaît is
        // dictated, so the uninverted "Je peux prendre un café." is an
        // authored missing-word error, not an accepted answer.
        base = try XCTUnwrap(pack.activity(id: "fr-requests-foundation-act-rb5")?.base)
        XCTAssertTrue(base.prompt.contains("please"),
                      "requests transfer must dictate the polite register")
        let requestResult = try gradeText("fr-requests-foundation-act-rb5", in: pack, "Je peux prendre un café.")
        XCTAssertFalse(requestResult.accepted, "s'il vous plaît must stay required")

        // Café-order re-authoring: no invitation content may survive in the
        // café lesson's answers, prompts, or read passage.
        let oldInvite = try gradeText("fr-cafe-order-foundation-produce", in: pack, "Tu veux venir dîner samedi ?")
        XCTAssertFalse(oldInvite.accepted, "invitation line must not be accepted in the café lesson")
        let oldTransform = try activity("fr-cafe-order-foundation-transform", in: pack)
        guard case .text(let transformSpec) = oldTransform else {
            return XCTFail("fr-cafe-order-foundation-transform must be a text activity")
        }
        XCTAssertFalse(
            transformSpec.answer.answers.contains { $0.contains("venir café") },
            "the broken 'venir café' answer must be gone")
        let readSpec = try activity("fr-cafe-order-foundation-read", in: pack)
        guard case .text(let readTextSpec) = readSpec else {
            return XCTFail("fr-cafe-order-foundation-read must be a text activity")
        }
        XCTAssertFalse(
            readTextSpec.answer.answers.contains { $0.contains("aujourd") },
            "the invitation-era 'aujourd'hui' answer must be gone")
        XCTAssertTrue(
            readTextSpec.answer.answers.contains { $0 == "trois" },
            "the café read must answer the price with the French number")
    }

    /// Every Wave E conversation ends on a text final-response step (M5-style
    /// outcome coherence, audit final-response shape).
    func testBatch5ConversationsEndWithTextFinalResponse() throws {
        let pack = try frenchPack()
        for lessonId in Self.batch5Lessons.keys.sorted() {
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

    // MARK: - Wave F (the twelve French construction + recall lessons)

    /// The twelve Wave F lessons (5 construction: negation/possession/
    /// questions/café-build/home-build; 7 recall: days/time/first-steps/
    /// future/resolutions/travail/A1-rappel), keyed by the path activity ids
    /// each lesson references (graded steps only).
    private static let batch6Lessons: [String: [String]] = [
        "fr-negation-foundation": [
            "fr-negation-foundation-order", "fr-negation-foundation-act-rb2",
            "fr-negation-foundation-act-rb3", "fr-negation-foundation-cloze",
            "fr-negation-foundation-produce", "fr-negation-foundation-meet",
        ],
        "fr-possession-foundation": [
            "fr-possession-foundation-order", "fr-possession-foundation-act-rb2",
            "fr-possession-foundation-act-rb3", "fr-possession-foundation-cloze",
            "fr-possession-foundation-produce", "fr-possession-foundation-meet",
        ],
        "fr-questions-foundation": [
            "fr-questions-foundation-order", "fr-questions-foundation-act-rb2",
            "fr-questions-foundation-act-rb3", "fr-questions-foundation-cloze",
            "fr-questions-foundation-produce", "fr-questions-foundation-meet",
        ],
        "fr-cafe-build-construction": [
            "fr-cafe-build-construction-act-2", "fr-cafe-build-construction-act-3",
            "fr-cafe-build-construction-act-4", "fr-cafe-build-construction-act-5",
            "fr-cafe-build-construction-act-6", "fr-cafe-build-construction-act-7",
            "fr-cafe-build-construction-act-8", "fr-cafe-build-construction-act-9",
        ],
        "fr-home-build-construction": [
            "fr-home-build-construction-act-2", "fr-home-build-construction-act-3",
            "fr-home-build-construction-act-4", "fr-home-build-construction-act-5",
            "fr-home-build-construction-act-6", "fr-home-build-construction-act-7",
            "fr-home-build-construction-act-8", "fr-home-build-construction-act-9",
        ],
        "fr-days-foundation": [
            "fr-days-foundation-meet", "fr-days-foundation-act-rb2",
            "fr-days-foundation-produce", "fr-days-foundation-act-rb3",
            "fr-days-foundation-cloze", "fr-days-foundation-read",
        ],
        "fr-time-foundation": [
            "fr-time-foundation-meet", "fr-time-foundation-act-rb2",
            "fr-time-foundation-produce", "fr-time-foundation-act-rb3",
            "fr-time-foundation-cloze", "fr-time-foundation-read",
        ],
        "fr-first-steps-recall": [
            "fr-first-steps-recall-act-2", "fr-first-steps-recall-act-3",
            "fr-first-steps-recall-act-4", "fr-first-steps-recall-act-5",
            "fr-first-steps-recall-act-6", "fr-first-steps-recall-act-7",
            "fr-first-steps-recall-act-8", "fr-first-steps-recall-act-9",
        ],
        "fr-a2-futur-emplois": [
            "fr-a2-futur-emplois-meet", "fr-a2-futur-emplois-act-rb2",
            "fr-a2-futur-emplois-think", "fr-a2-futur-emplois-notice",
            "fr-a2-futur-emplois-cloze", "fr-a2-futur-emplois-vary",
        ],
        "fr-a2-projets-resolutions": [
            "fr-a2-projets-resolutions-meet", "fr-a2-projets-resolutions-act-rb2",
            "fr-a2-projets-resolutions-think", "fr-a2-projets-resolutions-notice",
            "fr-a2-projets-resolutions-cloze", "fr-a2-projets-resolutions-vary",
        ],
        "fr-a2-travail-vocab": [
            "fr-a2-travail-vocab-meet", "fr-a2-travail-vocab-act-rb2",
            "fr-a2-travail-vocab-think", "fr-a2-travail-vocab-notice",
            "fr-a2-travail-vocab-cloze", "fr-a2-travail-vocab-vary",
        ],
        "fr-a2-rappel-a1": [
            "fr-a2-rappel-a1-act-2", "fr-a2-rappel-a1-act-3",
            "fr-a2-rappel-a1-act-4", "fr-a2-rappel-a1-act-5",
            "fr-a2-rappel-a1-act-6", "fr-a2-rappel-a1-act-7",
            "fr-a2-rappel-a1-act-8", "fr-a2-rappel-a1-act-9",
        ],
    ]

    /// Every graded step in the twelve Wave F construction/recall lessons has
    /// a real authored hint, not the runtime generic fallbacks.
    func testBatch6GradedStepsHaveAuthoredHints() throws {
        let pack = try frenchPack()
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

    /// Every text activity and cloze blank in the Wave F lessons authors
    /// error-specific feedback.
    func testBatch6TextActivitiesAuthorErrors() throws {
        let pack = try frenchPack()
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

    /// Plausible wrong answers in the Wave F lessons hit their authored
    /// category + explanation and are never accepted.
    func testBatch6ErrorsFireForPlausibleWrongAnswers() throws {
        let pack = try frenchPack()

        // fr-negation-foundation — sandwich slots, written-form policy.
        var result = try gradeBlank("fr-negation-foundation-cloze", blank: "b1", in: pack, "ne")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("fr-negation-foundation-produce", in: pack, "Je ne travaille.")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeText("fr-negation-foundation-produce", in: pack, "Je travaille pas.")
        XCTAssertEqual(result.category, "incorrect answer")

        // fr-possession-foundation — gender agreement on the possessed noun.
        result = try gradeBlank("fr-possession-foundation-cloze", blank: "b1", in: pack, "Mon")
        XCTAssertEqual(result.category, "wrong gender")
        result = try gradeText("fr-possession-foundation-produce", in: pack, "Ma maison est blanc.")
        XCTAssertEqual(result.category, "wrong gender")
        result = try gradeText("fr-possession-foundation-produce", in: pack, "La maison est blanche.")
        XCTAssertEqual(result.category, "missing word")

        // fr-questions-foundation — tu -es, vous register, missing que.
        result = try gradeBlank("fr-questions-foundation-cloze", blank: "b1", in: pack, "travaille")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("fr-questions-foundation-produce", in: pack, "Est-ce que vous travaillez ?")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-questions-foundation-produce", in: pack, "Est-ce tu travailles ?")
        XCTAssertEqual(result.category, "missing word")

        // fr-cafe-build-construction — polite register, prendre conjugation.
        result = try gradeBlank("fr-cafe-build-construction-act-4", blank: "b1", in: pack, "veux")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeBlank("fr-cafe-build-construction-act-4", blank: "b1", in: pack, "voudrai")
        XCTAssertEqual(result.category, "wrong tense")
        result = try gradeText("fr-cafe-build-construction-act-6", in: pack, "Je prend un café.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("fr-cafe-build-construction-act-6", in: pack, "Je prends le café.")
        XCTAssertEqual(result.category, "wrong article")
        result = try gradeBlank("fr-cafe-build-construction-act-8", blank: "b1", in: pack, "Vous")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-cafe-build-construction-act-9", in: pack, "La addition, s'il vous plaît.")
        XCTAssertEqual(result.category, "incorrect answer")

        // fr-home-build-construction — agreement on both sides of the verb.
        result = try gradeBlank("fr-home-build-construction-act-5", blank: "b1", in: pack, "grande")
        XCTAssertEqual(result.category, "wrong number")
        result = try gradeBlank("fr-home-build-construction-act-5", blank: "b1", in: pack, "grands")
        XCTAssertEqual(result.category, "wrong gender")
        result = try gradeBlank("fr-home-build-construction-act-6", blank: "b1", in: pack, "Mon")
        XCTAssertEqual(result.category, "wrong gender")
        result = try gradeText("fr-home-build-construction-act-7", in: pack, "Mes livres sont blanc.")
        XCTAssertEqual(result.category, "wrong number")
        result = try gradeText("fr-home-build-construction-act-9", in: pack, "Ta livre est grand.")
        XCTAssertEqual(result.category, "wrong gender")

        // fr-days-foundation — date number, article, order.
        result = try gradeBlank("fr-days-foundation-act-rb2", blank: "b1", in: pack, "trente")
        XCTAssertEqual(result.category, "wrong number")
        result = try gradeBlank("fr-days-foundation-cloze", blank: "b1", in: pack, "deux")
        XCTAssertEqual(result.category, "wrong number")
        result = try gradeText("fr-days-foundation-read", in: pack, "trois mai")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeText("fr-days-foundation-read", in: pack, "le mai trois")
        XCTAssertEqual(result.category, "word-order problem")
        result = try gradeText("fr-days-foundation-produce", in: pack, "Aujourd'hui, il est lundi.")
        XCTAssertEqual(result.category, "incorrect answer")

        // fr-time-foundation — clock subjects and the arrival decoy.
        result = try gradeBlank("fr-time-foundation-act-rb2", blank: "b1", in: pack, "Hier")
        XCTAssertEqual(result.category, "wrong tense")
        result = try gradeBlank("fr-time-foundation-cloze", blank: "b1", in: pack, "Elle")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-time-foundation-read", in: pack, "à huit heures")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeText("fr-time-foundation-read", in: pack, "midi")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-time-foundation-produce", in: pack, "Il est trois heures et demi.")
        XCTAssertEqual(result.category, "wrong gender")

        // fr-first-steps-recall — avoir-age, thanks, negation verb.
        result = try gradeBlank("fr-first-steps-recall-act-3", blank: "b1", in: pack, "dix")
        XCTAssertEqual(result.category, "wrong number")
        result = try gradeText("fr-first-steps-recall-act-4", in: pack, "Merci beaucoup.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeBlank("fr-first-steps-recall-act-6", blank: "b1", in: pack, "travailler")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("fr-first-steps-recall-act-8", in: pack, "Je suis vingt ans.")
        XCTAssertEqual(result.category, "wrong auxiliary")
        result = try gradeText("fr-first-steps-recall-act-8", in: pack, "J'ai vingt.")
        XCTAssertEqual(result.category, "missing word")

        // fr-a2-futur-emplois — future endings, tense family, double-l.
        result = try gradeBlank("fr-a2-futur-emplois-act-rb2", blank: "b1", in: pack, "travaillera")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeBlank("fr-a2-futur-emplois-act-rb2", blank: "b1", in: pack, "vais travailler")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-a2-futur-emplois-think", in: pack, "Je vais t'appeler.")
        XCTAssertEqual(result.category, "wrong tense")
        result = try gradeText("fr-a2-futur-emplois-think", in: pack, "Je t'appelerai.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeBlank("fr-a2-futur-emplois-cloze", blank: "b1", in: pack, "réussis")
        XCTAssertEqual(result.category, "wrong tense")
        result = try gradeText("fr-a2-futur-emplois-vary", in: pack, "Il va pleuvoir demain.")
        XCTAssertEqual(result.category, "wrong tense")

        // fr-a2-projets-resolutions — plan words, élision, near-future terminal.
        result = try gradeBlank("fr-a2-projets-resolutions-act-rb2", blank: "b1", in: pack, "Hier")
        XCTAssertEqual(result.category, "wrong tense")
        result = try gradeText("fr-a2-projets-resolutions-think", in: pack, "J'ai décidé de arrêter.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeBlank("fr-a2-projets-resolutions-cloze", blank: "b1", in: pack, "décidée")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-a2-projets-resolutions-vary", in: pack, "Je dormirai huit heures.")
        XCTAssertEqual(result.category, "wrong tense")
        result = try gradeText("fr-a2-projets-resolutions-vary", in: pack, "Je vais dormir huit heure.")
        XCTAssertEqual(result.category, "wrong number")

        // fr-a2-travail-vocab — work nouns, gender, false friends.
        result = try gradeBlank("fr-a2-travail-vocab-act-rb2", blank: "b1", in: pack, "travaille")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-a2-travail-vocab-think", in: pack, "La patron est en réunion.")
        XCTAssertEqual(result.category, "wrong gender")
        result = try gradeBlank("fr-a2-travail-vocab-cloze", blank: "b1", in: pack, "bureau")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeBlank("fr-a2-travail-vocab-cloze", blank: "b1", in: pack, "chef")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("fr-a2-travail-vocab-vary", in: pack, "La salaire est correct.")
        XCTAssertEqual(result.category, "wrong gender")
        result = try gradeText("fr-a2-travail-vocab-vary", in: pack, "Le salaire est fin.")
        XCTAssertEqual(result.category, "incorrect answer")

        // fr-a2-rappel-a1 — A1 retrieval with specific error categories.
        result = try gradeBlank("fr-a2-rappel-a1-act-3", blank: "b1", in: pack, "pas")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("fr-a2-rappel-a1-act-4", in: pack, "Ou est la gare ?")
        XCTAssertEqual(result.category, "accent/diacritic issue")
        result = try gradeText("fr-a2-rappel-a1-act-4", in: pack, "Où est le gare ?")
        XCTAssertEqual(result.category, "wrong gender")
        result = try gradeBlank("fr-a2-rappel-a1-act-6", blank: "b1", in: pack, "suis")
        XCTAssertEqual(result.category, "wrong auxiliary")
        result = try gradeText("fr-a2-rappel-a1-act-8", in: pack, "Je ne comprend pas.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("fr-a2-rappel-a1-act-8", in: pack, "Je ne comprends.")
        XCTAssertEqual(result.category, "missing word")
    }

    /// Wave F alignment fixes: natural renderings accepted where the prompt
    /// legitimately allows them.
    func testBatch6AcceptsNaturalAlternatives() throws {
        let pack = try frenchPack()

        // Days produce: today-is-Monday with the day first is natural French.
        var result = try gradeText("fr-days-foundation-produce", in: pack, "C'est lundi aujourd'hui.")
        XCTAssertTrue(result.accepted)

        // Time read: the bare departure time and the full sentence both answer
        // the when-question naturally.
        result = try gradeText("fr-time-foundation-read", in: pack, "huit heures et demie")
        XCTAssertTrue(result.accepted)
        result = try gradeText("fr-time-foundation-read", in: pack, "Le train part à huit heures et demie.")
        XCTAssertTrue(result.accepted)

        // Questions produce: the rising-intonation form is the lesson's own
        // sanctioned alternative to Est-ce que.
        result = try gradeText("fr-questions-foundation-produce", in: pack, "Tu travailles ?")
        XCTAssertTrue(result.accepted)

        // Resolutions vary: the re-authored near-future terminal is the model.
        result = try gradeText("fr-a2-projets-resolutions-vary", in: pack, "Je vais dormir huit heures.")
        XCTAssertTrue(result.accepted)
    }

    /// Wave F prompt/answer alignment (H1): cloze prompts that previously left
    /// the blank under-determined now dictate the target, and the resolutions
    /// terminal no longer silently accepts the off-theme futur simple.
    func testBatch6PromptNarrowingHolds() throws {
        let pack = try frenchPack()

        // The date cloze now dictates the day-number 3.
        var base = try XCTUnwrap(pack.activity(id: "fr-days-foundation-cloze")?.base)
        XCTAssertTrue(base.prompt.contains("(3)"),
                      "days cloze must dictate the date number")

        // The age cloze now dictates twenty.
        base = try XCTUnwrap(pack.activity(id: "fr-first-steps-recall-act-3")?.base)
        XCTAssertTrue(base.prompt.contains("(twenty)"),
                      "age cloze must dictate the number")

        // The possession cloze now dictates "my house".
        base = try XCTUnwrap(pack.activity(id: "fr-possession-foundation-cloze")?.base)
        XCTAssertTrue(base.prompt.contains("My house is white"),
                      "possession cloze must dictate the possessive")

        // The questions cloze now dictates the verb.
        base = try XCTUnwrap(pack.activity(id: "fr-questions-foundation-cloze")?.base)
        XCTAssertTrue(base.prompt.contains("(work)"),
                      "questions cloze must dictate the verb")

        // The resolutions terminal is the near future again; the futur simple
        // answer must not be silently accepted on a near-future lesson.
        base = try XCTUnwrap(pack.activity(id: "fr-a2-projets-resolutions-vary")?.base)
        XCTAssertTrue(base.prompt.contains("going to sleep"),
                      "resolutions vary must dictate the near future")
        let oldFuture = try gradeText("fr-a2-projets-resolutions-vary", in: pack, "Je dormirai huit heures.")
        XCTAssertFalse(oldFuture.accepted,
                       "the futur simple must not auto-grade on the near-future terminal")
        let nearFuture = try gradeText("fr-a2-projets-resolutions-vary", in: pack, "Je vais dormir huit heures.")
        XCTAssertTrue(nearFuture.accepted,
                      "the near-future model must be the accepted answer")
    }

    /// Every Wave F construction/recall lesson ends on a specific graded
    /// response step — never an ungraded or open-ended terminal (M5-style
    /// outcome coherence for these families).
    func testBatch6LessonsEndOnGradedResponse() throws {
        let pack = try frenchPack()
        for lessonId in Self.batch6Lessons.keys.sorted() {
            let lesson = try XCTUnwrap(pack.lesson(id: lessonId), lessonId)
            let terminals = lesson.steps.filter { $0.nextStepId == nil && $0.branches.isEmpty }
            XCTAssertFalse(terminals.isEmpty, "\(lessonId) must have a terminal step")
            for step in terminals {
                let act = try activity(step.activityId, in: pack)
                guard case .information = act else {
                    continue
                }
                XCTFail("\(lessonId): terminal step \(step.id) must be graded, not information")
            }
        }
    }

    // MARK: - Slice 2.2 comprehension fixes (2026-09-26 worklist)

    /// Comprehension reads widened to standard surface forms: the written
    /// digit date, the bare time, and the bare number answer now pass, while
    /// meaning-changing near misses still fail. The promoted forms must also
    /// be gone from the authored error lists.
    func testComprehensionVariantWidening() throws {
        let pack = try frenchPack()

        // fr-days-foundation-read: the written digit date is standard French.
        var result = try gradeText("fr-days-foundation-read", in: pack, "le 3 mai")
        XCTAssertTrue(result.accepted, "digit date must be accepted")
        result = try gradeText("fr-days-foundation-read", in: pack, "le 3 avril")
        XCTAssertFalse(result.accepted, "a wrong month must still fail")

        // fr-a2-futur-formation-read: the bare time answers the when-question.
        result = try gradeText("fr-a2-futur-formation-read", in: pack, "dix heures")
        XCTAssertTrue(result.accepted, "bare time must be accepted")
        result = try gradeText("fr-a2-futur-formation-read", in: pack, "À neuf heures")
        XCTAssertFalse(result.accepted, "the boss's nine o'clock must still fail")

        // fr-a2-conditionnel-politesse-read: the bare number answers how many.
        result = try gradeText("fr-a2-conditionnel-politesse-read", in: pack, "Deux.")
        XCTAssertTrue(result.accepted, "French bare number must be accepted")
        result = try gradeText("fr-a2-conditionnel-politesse-read", in: pack, "Two.")
        XCTAssertTrue(result.accepted, "English bare number must be accepted")
        result = try gradeText("fr-a2-conditionnel-politesse-read", in: pack, "Une nuit")
        XCTAssertFalse(result.accepted, "one night must still fail")

        // The promoted forms must not double as authored errors.
        let futurAct = try activity("fr-a2-futur-formation-read", in: pack)
        guard case .text(let futurSpec) = futurAct else {
            return XCTFail("fr-a2-futur-formation-read must be a text activity")
        }
        XCTAssertFalse(
            futurSpec.answer.errors.contains { $0.answer == "Dix heures" },
            "accepted bare time must not be authored as a missing word")
        let nightsAct = try activity("fr-a2-conditionnel-politesse-read", in: pack)
        guard case .text(let nightsSpec) = nightsAct else {
            return XCTFail("fr-a2-conditionnel-politesse-read must be a text activity")
        }
        XCTAssertFalse(
            nightsSpec.answer.errors.contains { $0.answer == "Two." },
            "accepted bare number must not be authored as a missing word")
    }

}
