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

    /// The seven mission lessons edited in wave B (units 3–17 beyond the
    /// wave-A unit-1/2 scope), keyed by the graded activity ids each lesson's
    /// path references.
    private static let batch2Lessons: [String: [String]] = [
        "de-market-run-mission": [
            "de-market-run-mission-act-2", "de-market-run-mission-act-4",
            "de-market-run-mission-act-5", "de-market-run-mission-act-7",
            "de-market-run-mission-act-8", "de-market-run-mission-act-9",
        ],
        "de-train-mission": [
            "de-train-mission-act-2", "de-train-mission-act-3",
            "de-train-mission-act-4", "de-train-mission-act-5",
            "de-train-mission-act-6", "de-train-mission-act-7",
            "de-train-mission-act-8", "de-train-mission-act-9",
        ],
        "de-family-visit-mission": [
            "de-family-visit-mission-act-2", "de-family-visit-mission-act-3",
            "de-family-visit-mission-act-4", "de-family-visit-mission-act-5",
            "de-family-visit-mission-act-6", "de-family-visit-mission-act-7",
            "de-family-visit-mission-act-8", "de-family-visit-mission-act-9",
        ],
        "de-market-foundation": [
            "de-market-foundation-meet", "de-market-foundation-notice",
            "de-market-foundation-build", "de-market-foundation-cloze",
            "de-market-foundation-think", "de-market-foundation-act-rb2",
            "de-market-foundation-vary",
        ],
        "de-pharmacy-foundation": [
            "de-pharmacy-foundation-meet", "de-pharmacy-foundation-notice",
            "de-pharmacy-foundation-build", "de-pharmacy-foundation-cloze",
            "de-pharmacy-foundation-think", "de-pharmacy-foundation-act-rb2",
            "de-pharmacy-foundation-vary",
        ],
        "de-emergency-foundation": [
            "de-emergency-foundation-meet", "de-emergency-foundation-notice",
            "de-emergency-foundation-build", "de-emergency-foundation-cloze",
            "de-emergency-foundation-think", "de-emergency-foundation-vary",
        ],
        "de-a2-bewerbungsgespraech-mission": [
            "de-a2-bewerbungsgespraech-mission-act-2",
            "de-a2-bewerbungsgespraech-mission-act-4",
            "de-a2-bewerbungsgespraech-mission-act-5",
            "de-a2-bewerbungsgespraech-mission-act-6",
            "de-a2-bewerbungsgespraech-mission-act-8",
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

    // MARK: - Wave B (7 mission lessons, units 3–17)

    /// Every graded step in wave-B lessons has a real authored hint
    /// (audit_editorial hint-gap must stay 0 for these lessons).
    func testBatch2GradedStepsHaveAuthoredHints() throws {
        let pack = try germanPack()
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
        let pack = try germanPack()
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

    /// Plausible wrong answers for wave-B lessons hit their authored
    /// category + explanation instead of the generic fallback.
    func testBatch2AuthoredErrorsFireForPlausibleWrongAnswers() throws {
        let pack = try germanPack()

        // de-market-run-mission-act-8 (Ja, danke.)
        var result = try gradeText("de-market-run-mission-act-8", in: pack, "Ja, bitte.")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-market-run-mission-act-8", in: pack, "Danke, ja.")
        XCTAssertEqual(result.category, "word-order problem")
        result = try gradeText("de-market-run-mission-act-8", in: pack, "Ja.")
        XCTAssertEqual(result.category, "missing word")

        // de-market-run-mission-act-9 (Einen Kaffee, bitte.)
        result = try gradeText("de-market-run-mission-act-9", in: pack, "Ein Kaffee, bitte.")
        XCTAssertEqual(result.category, "wrong article")
        result = try gradeText("de-market-run-mission-act-9", in: pack, "Einen Kaffee.")
        XCTAssertEqual(result.category, "missing word")

        // de-market-run-mission-act-4 (günstig)
        result = try gradeClozeBlank("de-market-run-mission-act-4", in: pack, blank: "b1", "teuer")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeClozeBlank("de-market-run-mission-act-4", in: pack, blank: "b1", "billig")
        XCTAssertEqual(result.category, "incorrect answer")

        // de-market-run-mission-act-7 (Die Rechnung)
        result = try gradeClozeBlank("de-market-run-mission-act-7", in: pack, blank: "b1", "Der")
        XCTAssertEqual(result.category, "wrong gender")
        XCTAssertFalse(result.accepted)
        result = try gradeClozeBlank("de-market-run-mission-act-7", in: pack, blank: "b1", "Den")
        XCTAssertEqual(result.category, "wrong gender")
        result = try gradeClozeBlank("de-market-run-mission-act-7", in: pack, blank: "b1", "Eine")
        XCTAssertEqual(result.category, "incorrect answer")

        // de-train-mission-act-3 (Ich möchte eine Fahrkarte.)
        result = try gradeText("de-train-mission-act-3", in: pack, "Ich möchte ein Fahrkarte.")
        XCTAssertEqual(result.category, "wrong article")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-train-mission-act-3", in: pack, "Ich möchte eine Karte.")
        XCTAssertEqual(result.category, "incorrect answer")

        // de-train-mission-act-5 (zehn)
        result = try gradeClozeBlank("de-train-mission-act-5", in: pack, blank: "b1", "zehn Euro")
        XCTAssertEqual(result.category, "extra word")
        XCTAssertFalse(result.accepted)
        result = try gradeClozeBlank("de-train-mission-act-5", in: pack, blank: "b1", "10")
        XCTAssertEqual(result.category, "incorrect answer")

        // de-train-mission-act-8 (rechts)
        result = try gradeClozeBlank("de-train-mission-act-8", in: pack, blank: "b1", "links")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeClozeBlank("de-train-mission-act-8", in: pack, blank: "b1", "nach rechts")
        XCTAssertEqual(result.category, "extra word")

        // de-train-mission-act-9 (Danke.)
        result = try gradeText("de-train-mission-act-9", in: pack, "Vielen Dank.")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)

        // de-family-visit-mission-act-3 (Ich heiße Anna.)
        result = try gradeText("de-family-visit-mission-act-3", in: pack, "Ich bin Anna.")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-family-visit-mission-act-3", in: pack, "Ich heißt Anna.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("de-family-visit-mission-act-3", in: pack, "Ich heiße.")
        XCTAssertEqual(result.category, "missing word")

        // de-family-visit-mission-act-7 (Bruder)
        result = try gradeClozeBlank("de-family-visit-mission-act-7", in: pack, blank: "b1", "Schwester")
        XCTAssertEqual(result.category, "wrong gender")
        XCTAssertFalse(result.accepted)
        result = try gradeClozeBlank("de-family-visit-mission-act-7", in: pack, blank: "b1", "Brüder")
        XCTAssertEqual(result.category, "wrong number")

        // de-family-visit-mission-act-9 (Hallo, ich heiße Anna.)
        result = try gradeText("de-family-visit-mission-act-9", in: pack, "Ich heiße Anna. Hallo.")
        XCTAssertEqual(result.category, "word-order problem")
        XCTAssertFalse(result.accepted)

        // de-market-foundation-cloze (nehme)
        result = try gradeClozeBlank("de-market-foundation-cloze", in: pack, blank: "b1", "nehmen")
        XCTAssertEqual(result.category, "wrong conjugation")
        XCTAssertFalse(result.accepted)
        result = try gradeClozeBlank("de-market-foundation-cloze", in: pack, blank: "b1", "kaufen")
        XCTAssertEqual(result.category, "incorrect answer")

        // de-market-foundation-think (Ich nehme ein Kilo Äpfel.)
        result = try gradeText("de-market-foundation-think", in: pack, "Ich nehme eine Kilo Äpfel.")
        XCTAssertEqual(result.category, "wrong article")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-market-foundation-think", in: pack, "Ich nehme ein Kilo Äpfeln.")
        XCTAssertEqual(result.category, "wrong number")

        // de-market-foundation-vary (Ich nehme eine Flasche Wasser.)
        result = try gradeText("de-market-foundation-vary", in: pack, "Ich nehme ein Flasche Wasser.")
        XCTAssertEqual(result.category, "wrong article")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-market-foundation-vary", in: pack, "Ich nehme eine Flasche Wassers.")
        XCTAssertEqual(result.category, "incorrect answer")

        // de-pharmacy-foundation-cloze (etwas)
        result = try gradeClozeBlank("de-pharmacy-foundation-cloze", in: pack, blank: "b1", "nichts")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeClozeBlank("de-pharmacy-foundation-cloze", in: pack, blank: "b1", "ein")
        XCTAssertEqual(result.category, "incorrect answer")

        // de-pharmacy-foundation-think (Ich brauche eine Tablette.)
        result = try gradeText("de-pharmacy-foundation-think", in: pack, "Ich brauche ein Tablette.")
        XCTAssertEqual(result.category, "wrong article")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-pharmacy-foundation-think", in: pack, "Ich brauche eine Tabletten.")
        XCTAssertEqual(result.category, "wrong number")

        // de-pharmacy-foundation-vary (Ich brauche ein Medikament.)
        result = try gradeText("de-pharmacy-foundation-vary", in: pack, "Ich brauche eine Medikament.")
        XCTAssertEqual(result.category, "wrong article")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-pharmacy-foundation-vary", in: pack, "Ich brauche Medikament.")
        XCTAssertEqual(result.category, "missing word")

        // de-emergency-foundation-cloze (Rufen)
        result = try gradeClozeBlank("de-emergency-foundation-cloze", in: pack, blank: "b1", "Ruf")
        XCTAssertEqual(result.category, "wrong conjugation")
        XCTAssertFalse(result.accepted)
        result = try gradeClozeBlank("de-emergency-foundation-cloze", in: pack, blank: "b1", "Rufe")
        XCTAssertEqual(result.category, "wrong conjugation")

        // de-emergency-foundation-think (Rufen Sie den Arzt!)
        result = try gradeText("de-emergency-foundation-think", in: pack, "Rufen Sie der Arzt!")
        XCTAssertEqual(result.category, "wrong article")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-emergency-foundation-think", in: pack, "Ruf den Arzt!")
        XCTAssertEqual(result.category, "incorrect answer")

        // de-emergency-foundation-vary (Ruf den Arzt!)
        result = try gradeText("de-emergency-foundation-vary", in: pack, "Rufen den Arzt!")
        XCTAssertEqual(result.category, "wrong conjugation")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-emergency-foundation-vary", in: pack, "Ruf Sie den Arzt!")
        XCTAssertEqual(result.category, "extra word")

        // de-a2-bewerbungsgespraech-mission-act-5 (wiederholen)
        result = try gradeClozeBlank(
            "de-a2-bewerbungsgespraech-mission-act-5", in: pack, blank: "b1", "wiederholt")
        XCTAssertEqual(result.category, "wrong conjugation")
        XCTAssertFalse(result.accepted)

        // de-a2-bewerbungsgespraech-mission-act-8 (Vielen Dank für das Gespräch.)
        result = try gradeText(
            "de-a2-bewerbungsgespraech-mission-act-8", in: pack, "Vielen Dank für die Gespräch.")
        XCTAssertEqual(result.category, "wrong article")
        XCTAssertFalse(result.accepted)
    }

    /// Wave-B lessons accept their dictated target lines, natural German
    /// forms, and second accepted variants.
    func testBatch2AcceptsAuthoredAnswers() throws {
        let pack = try germanPack()

        // Mission lines and request forms.
        var result = try gradeText("de-market-run-mission-act-8", in: pack, "Ja, danke.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-market-run-mission-act-9", in: pack, "Einen Kaffee, bitte.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-train-mission-act-3", in: pack, "Ich möchte eine Fahrkarte.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-train-mission-act-9", in: pack, "Danke.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-family-visit-mission-act-3", in: pack, "Ich heiße Anna.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-family-visit-mission-act-9", in: pack, "Hallo, ich heiße Anna.")
        XCTAssertTrue(result.accepted)

        // Foundation lesson target lines.
        result = try gradeText("de-market-foundation-think", in: pack, "Ich nehme ein Kilo Äpfel.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-market-foundation-vary", in: pack, "Ich nehme eine Flasche Wasser.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-pharmacy-foundation-think", in: pack, "Ich brauche eine Tablette.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-pharmacy-foundation-vary", in: pack, "Ich brauche ein Medikament.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-emergency-foundation-think", in: pack, "Rufen Sie den Arzt!")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-emergency-foundation-vary", in: pack, "Ruf den Arzt!")
        XCTAssertTrue(result.accepted)

        // Cloze blanks accept the taught word (article case is irrelevant).
        result = try gradeClozeBlank("de-market-run-mission-act-4", in: pack, blank: "b1", "günstig")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank("de-market-run-mission-act-7", in: pack, blank: "b1", "die")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank("de-train-mission-act-5", in: pack, blank: "b1", "zehn")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank("de-train-mission-act-8", in: pack, blank: "b1", "rechts")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank("de-family-visit-mission-act-7", in: pack, blank: "b1", "Bruder")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank("de-market-foundation-cloze", in: pack, blank: "b1", "nehme")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank("de-pharmacy-foundation-cloze", in: pack, blank: "b1", "etwas")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank("de-emergency-foundation-cloze", in: pack, blank: "b1", "Rufen")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank(
            "de-a2-bewerbungsgespraech-mission-act-5", in: pack, blank: "b1", "wiederholen")
        XCTAssertTrue(result.accepted)

        // A2 closing thanks accepts both authored variants.
        result = try gradeText(
            "de-a2-bewerbungsgespraech-mission-act-8", in: pack, "Danke für das Gespräch.")
        XCTAssertTrue(result.accepted)
    }

    // MARK: - Wave C (8 story lessons, units 3–14)

    /// The eight German story-family lessons edited in wave C (family ==
    /// "story", unreviewed before this batch), keyed by the graded activity
    /// ids each lesson's path references.
    private static let batch3Lessons: [String: [String]] = [
        "de-directions-foundation": [
            "de-directions-foundation-meet", "de-directions-foundation-act-rb4",
            "de-directions-foundation-cloze", "de-directions-foundation-ask",
            "de-directions-foundation-act-rb5",
        ],
        "de-weather-foundation": [
            "de-weather-foundation-meet", "de-weather-foundation-notice",
            "de-weather-foundation-cloze", "de-weather-foundation-think",
            "de-weather-foundation-act-rb4",
        ],
        "de-free-time-foundation": [
            "de-free-time-foundation-meet", "de-free-time-foundation-notice",
            "de-free-time-foundation-cloze", "de-free-time-foundation-think",
            "de-free-time-foundation-act-rb4",
        ],
        "de-transport-foundation": [
            "de-transport-foundation-meet", "de-transport-foundation-notice",
            "de-transport-foundation-cloze", "de-transport-foundation-vary",
            "de-transport-foundation-act-rb4",
        ],
        "de-past-foundation": [
            "de-past-foundation-meet", "de-past-foundation-notice",
            "de-past-foundation-cloze", "de-past-foundation-vary",
            "de-past-foundation-act-rb4",
        ],
        "de-a2-wochenende-erzaehlen": [
            "de-a2-wochenende-erzaehlen-meet", "de-a2-wochenende-erzaehlen-notice",
            "de-a2-wochenende-erzaehlen-cloze", "de-a2-wochenende-erzaehlen-think",
            "de-a2-wochenende-erzaehlen-act-rb4",
        ],
        "de-a2-futur-vermutung": [
            "de-a2-futur-vermutung-meet", "de-a2-futur-vermutung-notice",
            "de-a2-futur-vermutung-cloze", "de-a2-futur-vermutung-vary",
            "de-a2-futur-vermutung-act-rb4",
        ],
        "de-a2-plaene-vorsaetze": [
            "de-a2-plaene-vorsaetze-meet", "de-a2-plaene-vorsaetze-notice",
            "de-a2-plaene-vorsaetze-cloze", "de-a2-plaene-vorsaetze-think",
            "de-a2-plaene-vorsaetze-act-rb4",
        ],
    ]

    /// Every graded step in wave-C lessons has a real authored hint
    /// (audit_editorial hint-gap must stay 0 for these lessons).
    func testBatch3GradedStepsHaveAuthoredHints() throws {
        let pack = try germanPack()
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
        let pack = try germanPack()
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

    /// Plausible wrong answers for wave-C lessons hit their authored
    /// category + explanation instead of the generic fallback.
    func testBatch3AuthoredErrorsFireForPlausibleWrongAnswers() throws {
        let pack = try germanPack()

        // de-directions-foundation-cloze (links)
        var result = try gradeClozeBlank("de-directions-foundation-cloze", in: pack, blank: "b1", "rechts")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeClozeBlank("de-directions-foundation-cloze", in: pack, blank: "b1", "geradeaus")
        XCTAssertEqual(result.category, "incorrect answer")

        // de-directions-foundation-ask (Wo ist die Toilette?)
        result = try gradeText("de-directions-foundation-ask", in: pack, "Wo ist der Toilette?")
        XCTAssertEqual(result.category, "wrong gender")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-directions-foundation-ask", in: pack, "Wo ist das Toilette?")
        XCTAssertEqual(result.category, "wrong article")
        result = try gradeText("de-directions-foundation-ask", in: pack, "Wo die Toilette ist?")
        XCTAssertEqual(result.category, "word-order problem")

        // de-directions-foundation-act-rb5 (Geradeaus, dann links.)
        result = try gradeText("de-directions-foundation-act-rb5", in: pack, "Geradeaus, dann rechts.")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-directions-foundation-act-rb5", in: pack, "Links, dann geradeaus.")
        XCTAssertEqual(result.category, "word-order problem")

        // de-weather-foundation-cloze (Es)
        result = try gradeClozeBlank("de-weather-foundation-cloze", in: pack, blank: "b1", "Das")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeClozeBlank("de-weather-foundation-cloze", in: pack, blank: "b1", "Regnet es.")
        XCTAssertEqual(result.category, "word-order problem")

        // de-weather-foundation-think (Es regnet.)
        result = try gradeText("de-weather-foundation-think", in: pack, "Regnet es.")
        XCTAssertEqual(result.category, "word-order problem")
        result = try gradeText("de-weather-foundation-think", in: pack, "Es regnen.")
        XCTAssertEqual(result.category, "wrong conjugation")

        // de-weather-foundation-act-rb4 (Die Sonne scheint, aber es ist kalt.)
        result = try gradeText(
            "de-weather-foundation-act-rb4", in: pack, "Es scheint die Sonne, aber es ist kalt.")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-weather-foundation-act-rb4", in: pack, "Die Sonne scheint, aber ist kalt.")
        XCTAssertEqual(result.category, "missing word")

        // de-free-time-foundation-cloze (gern)
        result = try gradeClozeBlank("de-free-time-foundation-cloze", in: pack, blank: "b1", "nicht")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeClozeBlank("de-free-time-foundation-cloze", in: pack, blank: "b1", "Tennis")
        XCTAssertEqual(result.category, "incorrect answer")

        // de-free-time-foundation-think (Ich lese gern.)
        result = try gradeText("de-free-time-foundation-think", in: pack, "Ich gern lese.")
        XCTAssertEqual(result.category, "word-order problem")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-free-time-foundation-think", in: pack, "Ich lesen gern.")
        XCTAssertEqual(result.category, "wrong conjugation")

        // de-free-time-foundation-act-rb4 (Ich spiele gern Tennis.)
        result = try gradeText("de-free-time-foundation-act-rb4", in: pack, "Ich gern spiele Tennis.")
        XCTAssertEqual(result.category, "word-order problem")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-free-time-foundation-act-rb4", in: pack, "Ich spiele gern Fußball.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("de-free-time-foundation-act-rb4", in: pack, "Ich spiele gern.")
        XCTAssertEqual(result.category, "missing word")

        // de-transport-foundation-cloze (zu)
        result = try gradeClozeBlank("de-transport-foundation-cloze", in: pack, blank: "b1", "mit")
        XCTAssertEqual(result.category, "wrong preposition")
        XCTAssertFalse(result.accepted)
        result = try gradeClozeBlank("de-transport-foundation-cloze", in: pack, blank: "b1", "in")
        XCTAssertEqual(result.category, "wrong preposition")

        // de-transport-foundation-vary (Ich fahre mit dem Zug.)
        result = try gradeText("de-transport-foundation-vary", in: pack, "Ich fahre mit die Zug.")
        XCTAssertEqual(result.category, "wrong article")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-transport-foundation-vary", in: pack, "Ich gehe mit dem Zug.")
        XCTAssertEqual(result.category, "incorrect answer")

        // de-transport-foundation-act-rb4 (Ich bin in Berlin.)
        result = try gradeText("de-transport-foundation-act-rb4", in: pack, "Ich habe in Berlin.")
        XCTAssertEqual(result.category, "wrong auxiliary")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-transport-foundation-act-rb4", in: pack, "Ich fahre in Berlin.")
        XCTAssertEqual(result.category, "incorrect answer")

        // de-past-foundation-cloze (gearbeitet)
        result = try gradeClozeBlank("de-past-foundation-cloze", in: pack, blank: "b1", "arbeitet")
        XCTAssertEqual(result.category, "wrong conjugation")
        XCTAssertFalse(result.accepted)
        result = try gradeClozeBlank("de-past-foundation-cloze", in: pack, blank: "b1", "gearbeitt")
        XCTAssertEqual(result.category, "wrong conjugation")

        // de-past-foundation-vary (Ich habe getrunken.)
        result = try gradeText("de-past-foundation-vary", in: pack, "Ich habe trinken.")
        XCTAssertEqual(result.category, "wrong conjugation")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-past-foundation-vary", in: pack, "Ich getrunken habe.")
        XCTAssertEqual(result.category, "word-order problem")
        result = try gradeText("de-past-foundation-vary", in: pack, "Ich habe getrinkt.")
        XCTAssertEqual(result.category, "wrong conjugation")

        // de-past-foundation-act-rb4 (Ich habe gespielt.)
        result = try gradeText("de-past-foundation-act-rb4", in: pack, "Ich habe spielen.")
        XCTAssertEqual(result.category, "wrong conjugation")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-past-foundation-act-rb4", in: pack, "Ich gespielt habe.")
        XCTAssertEqual(result.category, "word-order problem")

        // de-a2-wochenende-erzaehlen-cloze (Am)
        result = try gradeClozeBlank("de-a2-wochenende-erzaehlen-cloze", in: pack, blank: "b1", "An")
        XCTAssertEqual(result.category, "wrong preposition")
        XCTAssertFalse(result.accepted)
        result = try gradeClozeBlank("de-a2-wochenende-erzaehlen-cloze", in: pack, blank: "b1", "Zum")
        XCTAssertEqual(result.category, "wrong preposition")

        // de-a2-wochenende-erzaehlen-think (Dann bin ich spazieren gegangen.)
        result = try gradeText(
            "de-a2-wochenende-erzaehlen-think", in: pack, "Dann habe ich spazieren gegangen.")
        XCTAssertEqual(result.category, "wrong auxiliary")
        XCTAssertFalse(result.accepted)
        result = try gradeText(
            "de-a2-wochenende-erzaehlen-think", in: pack, "Dann bin ich spazieren gehen.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText(
            "de-a2-wochenende-erzaehlen-think", in: pack, "Dann ich bin spazieren gegangen.")
        XCTAssertEqual(result.category, "word-order problem")

        // de-a2-wochenende-erzaehlen-act-rb4 (Zuerst habe ich gefrühstückt.)
        result = try gradeText(
            "de-a2-wochenende-erzaehlen-act-rb4", in: pack, "Zuerst ich habe gefrühstückt.")
        XCTAssertEqual(result.category, "word-order problem")
        XCTAssertFalse(result.accepted)

        // de-a2-futur-vermutung-cloze (wohl)
        result = try gradeClozeBlank("de-a2-futur-vermutung-cloze", in: pack, blank: "b1", "sicherlich")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeClozeBlank("de-a2-futur-vermutung-cloze", in: pack, blank: "b1", "schon")
        XCTAssertEqual(result.category, "incorrect answer")

        // de-a2-futur-vermutung-vary (Er wird wohl krank sein.)
        result = try gradeText("de-a2-futur-vermutung-vary", in: pack, "Er wird krank sein.")
        XCTAssertEqual(result.category, "missing word")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-a2-futur-vermutung-vary", in: pack, "Er ist wohl krank.")
        XCTAssertEqual(result.category, "wrong tense")
        result = try gradeText("de-a2-futur-vermutung-vary", in: pack, "Er wird wohl krank.")
        XCTAssertEqual(result.category, "missing word")

        // de-a2-futur-vermutung-act-rb4 (Er wird wohl braun sein.)
        result = try gradeText("de-a2-futur-vermutung-act-rb4", in: pack, "Er ist wohl braun.")
        XCTAssertEqual(result.category, "wrong tense")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-a2-futur-vermutung-act-rb4", in: pack, "Er wird wohl braun.")
        XCTAssertEqual(result.category, "missing word")

        // de-a2-plaene-vorsaetze-cloze (mehr)
        result = try gradeClozeBlank("de-a2-plaene-vorsaetze-cloze", in: pack, blank: "b1", "kein")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeClozeBlank("de-a2-plaene-vorsaetze-cloze", in: pack, blank: "b1", "viel")
        XCTAssertEqual(result.category, "incorrect answer")

        // de-a2-plaene-vorsaetze-think (Ich habe vor, mehr Sport zu machen.)
        result = try gradeText(
            "de-a2-plaene-vorsaetze-think", in: pack, "Ich habe vor, mehr Sport machen.")
        XCTAssertEqual(result.category, "missing word")
        XCTAssertFalse(result.accepted)
        result = try gradeText(
            "de-a2-plaene-vorsaetze-think", in: pack, "Ich vorhabe, mehr Sport zu machen.")
        XCTAssertEqual(result.category, "word-order problem")

        // de-a2-plaene-vorsaetze-act-rb4 (Ich habe vor, weniger zu naschen.)
        result = try gradeText(
            "de-a2-plaene-vorsaetze-act-rb4", in: pack, "Ich habe vor, weniger naschen.")
        XCTAssertEqual(result.category, "missing word")
        XCTAssertFalse(result.accepted)
        result = try gradeText(
            "de-a2-plaene-vorsaetze-act-rb4", in: pack, "Ich habe vor, mehr zu naschen.")
        XCTAssertEqual(result.category, "incorrect answer")
    }

    /// Wave-C lessons accept their dictated target lines, natural German
    /// forms, and second accepted variants.
    func testBatch3AcceptsAuthoredAnswers() throws {
        let pack = try germanPack()

        // de-directions-foundation
        var result = try gradeClozeBlank("de-directions-foundation-cloze", in: pack, blank: "b1", "links")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-directions-foundation-ask", in: pack, "Wo ist die Toilette?")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-directions-foundation-act-rb5", in: pack, "Geradeaus, dann links.")
        XCTAssertTrue(result.accepted)

        // de-weather-foundation (placeholder case is irrelevant)
        result = try gradeClozeBlank("de-weather-foundation-cloze", in: pack, blank: "b1", "es")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-weather-foundation-think", in: pack, "Es regnet.")
        XCTAssertTrue(result.accepted)
        result = try gradeText(
            "de-weather-foundation-act-rb4", in: pack, "Die Sonne scheint, aber es ist kalt.")
        XCTAssertTrue(result.accepted)

        // de-free-time-foundation (gern / gerne are free variants)
        result = try gradeClozeBlank("de-free-time-foundation-cloze", in: pack, blank: "b1", "gern")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank("de-free-time-foundation-cloze", in: pack, blank: "b1", "gerne")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-free-time-foundation-think", in: pack, "Ich lese gern.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-free-time-foundation-think", in: pack, "Ich lese gerne.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-free-time-foundation-act-rb4", in: pack, "Ich spiele gern Tennis.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-free-time-foundation-act-rb4", in: pack, "Ich spiele gerne Tennis.")
        XCTAssertTrue(result.accepted)

        // de-transport-foundation
        result = try gradeClozeBlank("de-transport-foundation-cloze", in: pack, blank: "b1", "zu")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-transport-foundation-vary", in: pack, "Ich fahre mit dem Zug.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-transport-foundation-act-rb4", in: pack, "Ich bin in Berlin.")
        XCTAssertTrue(result.accepted)

        // de-past-foundation
        result = try gradeClozeBlank("de-past-foundation-cloze", in: pack, blank: "b1", "gearbeitet")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-past-foundation-vary", in: pack, "Ich habe getrunken.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-past-foundation-act-rb4", in: pack, "Ich habe gespielt.")
        XCTAssertTrue(result.accepted)

        // de-a2-wochenende-erzaehlen
        result = try gradeClozeBlank("de-a2-wochenende-erzaehlen-cloze", in: pack, blank: "b1", "Am")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank("de-a2-wochenende-erzaehlen-cloze", in: pack, blank: "b1", "am")
        XCTAssertTrue(result.accepted)
        result = try gradeText(
            "de-a2-wochenende-erzaehlen-think", in: pack, "Dann bin ich spazieren gegangen.")
        XCTAssertTrue(result.accepted)
        result = try gradeText(
            "de-a2-wochenende-erzaehlen-act-rb4", in: pack, "Zuerst habe ich gefrühstückt.")
        XCTAssertTrue(result.accepted)

        // de-a2-futur-vermutung
        result = try gradeClozeBlank("de-a2-futur-vermutung-cloze", in: pack, blank: "b1", "wohl")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-a2-futur-vermutung-vary", in: pack, "Er wird wohl krank sein.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-a2-futur-vermutung-act-rb4", in: pack, "Er wird wohl braun sein.")
        XCTAssertTrue(result.accepted)

        // de-a2-plaene-vorsaetze
        result = try gradeClozeBlank("de-a2-plaene-vorsaetze-cloze", in: pack, blank: "b1", "mehr")
        XCTAssertTrue(result.accepted)
        result = try gradeText(
            "de-a2-plaene-vorsaetze-think", in: pack, "Ich habe vor, mehr Sport zu machen.")
        XCTAssertTrue(result.accepted)
        result = try gradeText(
            "de-a2-plaene-vorsaetze-act-rb4", in: pack, "Ich habe vor, weniger zu naschen.")
        XCTAssertTrue(result.accepted)
    }

    // MARK: - Wave D (13 discovery lessons, units 4–17)

    /// The thirteen German discovery-family lessons edited in wave D (family
    /// == "discovery", unreviewed before this batch), keyed by the graded
    /// activity ids each lesson's path references.
    private static let batch4Lessons: [String: [String]] = [
        "de-time-days-foundation": [
            "de-time-days-foundation-meet", "de-time-days-foundation-notice",
            "de-time-days-foundation-read", "de-time-days-foundation-build",
            "de-time-days-foundation-cloze", "de-time-days-foundation-think",
            "de-time-days-foundation-meaning",
        ],
        "de-home-foundation": [
            "de-home-foundation-meet", "de-home-foundation-think",
            "de-home-foundation-notice", "de-home-foundation-build",
            "de-home-foundation-cloze", "de-home-foundation-vary",
            "de-home-foundation-read",
        ],
        "de-descriptions-foundation": [
            "de-descriptions-foundation-meet", "de-descriptions-foundation-think",
            "de-descriptions-foundation-notice", "de-descriptions-foundation-build",
            "de-descriptions-foundation-cloze", "de-descriptions-foundation-vary",
            "de-descriptions-foundation-read",
        ],
        "de-routine-foundation": [
            "de-routine-foundation-meet", "de-routine-foundation-think",
            "de-routine-foundation-notice", "de-routine-foundation-build",
            "de-routine-foundation-cloze", "de-routine-foundation-vary",
            "de-routine-foundation-read",
        ],
        "de-food-foundation": [
            "de-food-foundation-think", "de-food-foundation-meet",
            "de-food-foundation-build", "de-food-foundation-vary",
            "de-food-foundation-notice", "de-food-foundation-cloze",
            "de-food-foundation-read",
        ],
        "de-possession-foundation": [
            "de-possession-foundation-think", "de-possession-foundation-meet",
            "de-possession-foundation-build", "de-possession-foundation-vary",
            "de-possession-foundation-notice", "de-possession-foundation-cloze",
            "de-possession-foundation-read",
        ],
        "de-plans-foundation": [
            "de-plans-foundation-think", "de-plans-foundation-meet",
            "de-plans-foundation-build", "de-plans-foundation-vary",
            "de-plans-foundation-notice", "de-plans-foundation-cloze",
            "de-plans-foundation-read",
        ],
        "de-months-foundation": [
            "de-months-foundation-meet", "de-months-foundation-cloze",
            "de-months-foundation-think", "de-months-foundation-build",
            "de-months-foundation-vary", "de-months-foundation-notice",
            "de-months-foundation-read",
        ],
        "de-a2-konjunktiv-wuerde": [
            "de-a2-konjunktiv-wuerde-meet", "de-a2-konjunktiv-wuerde-cloze",
            "de-a2-konjunktiv-wuerde-think", "de-a2-konjunktiv-wuerde-build",
            "de-a2-konjunktiv-wuerde-vary", "de-a2-konjunktiv-wuerde-notice",
            "de-a2-konjunktiv-wuerde-read",
        ],
        "de-a2-komparativ": [
            "de-a2-komparativ-meet", "de-a2-komparativ-cloze",
            "de-a2-komparativ-think", "de-a2-komparativ-build",
            "de-a2-komparativ-vary", "de-a2-komparativ-notice",
            "de-a2-komparativ-read",
        ],
        "de-a2-wechselpraepositionen": [
            "de-a2-wechselpraepositionen-build", "de-a2-wechselpraepositionen-meet",
            "de-a2-wechselpraepositionen-think", "de-a2-wechselpraepositionen-cloze",
            "de-a2-wechselpraepositionen-vary", "de-a2-wechselpraepositionen-notice",
            "de-a2-wechselpraepositionen-read",
        ],
        "de-a2-passiv-intro": [
            "de-a2-passiv-intro-build", "de-a2-passiv-intro-meet",
            "de-a2-passiv-intro-think", "de-a2-passiv-intro-cloze",
            "de-a2-passiv-intro-vary", "de-a2-passiv-intro-notice",
            "de-a2-passiv-intro-read",
        ],
        "de-a2-berufsvokabular": [
            "de-a2-berufsvokabular-build", "de-a2-berufsvokabular-meet",
            "de-a2-berufsvokabular-think", "de-a2-berufsvokabular-cloze",
            "de-a2-berufsvokabular-vary", "de-a2-berufsvokabular-notice",
            "de-a2-berufsvokabular-read",
        ],
    ]

    /// Every graded step in wave-D lessons has a real authored hint
    /// (audit_editorial hint-gap must stay 0 for these lessons).
    func testBatch4GradedStepsHaveAuthoredHints() throws {
        let pack = try germanPack()
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
        let pack = try germanPack()
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

    /// Plausible wrong answers for wave-D lessons hit their authored
    /// category + explanation instead of the generic fallback.
    func testBatch4AuthoredErrorsFireForPlausibleWrongAnswers() throws {
        let pack = try germanPack()

        // de-time-days-foundation
        var result = try gradeClozeBlank("de-time-days-foundation-cloze", in: pack, blank: "b1", "morgens")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-time-days-foundation-think", in: pack, "Heute ist Montag.")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-time-days-foundation-think", in: pack, "Heute Sonntag ist.")
        XCTAssertEqual(result.category, "word-order problem")
        result = try gradeText("de-time-days-foundation-read", in: pack, "Donnerstag")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-time-days-foundation-meaning", in: pack, "I work Monday.")
        XCTAssertEqual(result.category, "missing word")
        XCTAssertFalse(result.accepted)

        // de-home-foundation
        result = try gradeText("de-home-foundation-think", in: pack, "Das ist eine Stuhl.")
        XCTAssertEqual(result.category, "wrong article")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-home-foundation-think", in: pack, "Das ist einen Stuhl.")
        XCTAssertEqual(result.category, "wrong article")
        result = try gradeClozeBlank("de-home-foundation-cloze", in: pack, blank: "b1", "eine")
        XCTAssertEqual(result.category, "wrong article")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-home-foundation-vary", in: pack, "Das ist eine Bett.")
        XCTAssertEqual(result.category, "wrong article")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-home-foundation-vary", in: pack, "Das ist Bett.")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeText("de-home-foundation-read", in: pack, "Das Zimmer.")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)

        // de-descriptions-foundation
        result = try gradeText("de-descriptions-foundation-think", in: pack, "Das Zimmer ist kleine.")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-descriptions-foundation-think", in: pack, "Das Zimmer klein ist.")
        XCTAssertEqual(result.category, "word-order problem")
        result = try gradeClozeBlank("de-descriptions-foundation-cloze", in: pack, blank: "b1", "so")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeClozeBlank("de-descriptions-foundation-cloze", in: pack, blank: "b1", "sehr groß")
        XCTAssertEqual(result.category, "extra word")
        result = try gradeText("de-descriptions-foundation-vary", in: pack, "Das Auto ist neu.")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-descriptions-foundation-vary", in: pack, "Das Auto ist sehr alt.")
        XCTAssertEqual(result.category, "extra word")
        result = try gradeText("de-descriptions-foundation-read", in: pack, "Das Zimmer.")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)

        // de-routine-foundation
        result = try gradeText("de-routine-foundation-think", in: pack, "Ich abends lerne.")
        XCTAssertEqual(result.category, "word-order problem")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-routine-foundation-think", in: pack, "Ich lernen abends.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeClozeBlank("de-routine-foundation-cloze", in: pack, blank: "b1", "arbeitet")
        XCTAssertEqual(result.category, "wrong conjugation")
        XCTAssertFalse(result.accepted)
        result = try gradeClozeBlank("de-routine-foundation-cloze", in: pack, blank: "b1", "arbeiten")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("de-routine-foundation-vary", in: pack, "Ich arbeite morgens.")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-routine-foundation-vary", in: pack, "Ich arbeitet abends.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("de-routine-foundation-read", in: pack, "Abends")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)

        // de-food-foundation
        result = try gradeText("de-food-foundation-think", in: pack, "Ich essen Brot.")
        XCTAssertEqual(result.category, "wrong conjugation")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-food-foundation-think", in: pack, "Ich isst Brot.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("de-food-foundation-vary", in: pack, "Ich mag Käse.")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-food-foundation-vary", in: pack, "Ich mögen Brot.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeClozeBlank("de-food-foundation-cloze", in: pack, blank: "b1", "ein")
        XCTAssertEqual(result.category, "wrong article")
        XCTAssertFalse(result.accepted)
        result = try gradeClozeBlank("de-food-foundation-cloze", in: pack, blank: "b1", "eine")
        XCTAssertEqual(result.category, "wrong article")
        result = try gradeText("de-food-foundation-read", in: pack, "Brot")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)

        // de-possession-foundation
        result = try gradeText("de-possession-foundation-think", in: pack, "Das ist mein Tasche.")
        XCTAssertEqual(result.category, "wrong article")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-possession-foundation-think", in: pack, "Das ist meinen Tasche.")
        XCTAssertEqual(result.category, "wrong article")
        result = try gradeText("de-possession-foundation-vary", in: pack, "Das ist ihre Auto.")
        XCTAssertEqual(result.category, "wrong article")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-possession-foundation-vary", in: pack, "Das ist sein Auto.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeClozeBlank("de-possession-foundation-cloze", in: pack, blank: "b1", "deine")
        XCTAssertEqual(result.category, "wrong article")
        XCTAssertFalse(result.accepted)
        result = try gradeClozeBlank("de-possession-foundation-cloze", in: pack, blank: "b1", "deinen")
        XCTAssertEqual(result.category, "wrong article")
        result = try gradeText("de-possession-foundation-read", in: pack, "mein Bruder")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-possession-foundation-read", in: pack, "ihre Tasche")
        XCTAssertEqual(result.category, "incorrect answer")

        // de-plans-foundation
        result = try gradeText("de-plans-foundation-think", in: pack, "Morgen ich arbeite.")
        XCTAssertEqual(result.category, "word-order problem")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-plans-foundation-think", in: pack, "Morgen arbeiten ich.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("de-plans-foundation-vary", in: pack, "Nächste Wochen arbeite ich.")
        XCTAssertEqual(result.category, "wrong number")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-plans-foundation-vary", in: pack, "Nächste Woche ich arbeite.")
        XCTAssertEqual(result.category, "word-order problem")
        result = try gradeClozeBlank("de-plans-foundation-cloze", in: pack, blank: "b1", "Morgen")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-plans-foundation-read", in: pack, "Bald")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)

        // de-months-foundation
        result = try gradeClozeBlank("de-months-foundation-cloze", in: pack, blank: "b1", "am")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeClozeBlank("de-months-foundation-cloze", in: pack, blank: "b1", "in")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("de-months-foundation-think", in: pack, "Mein Geburtstag ist in Mai.")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-months-foundation-think", in: pack, "Mein Geburtstag ist am Mai.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("de-months-foundation-vary", in: pack, "Der Sommer ist kalt.")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-months-foundation-vary", in: pack, "Der Winter ist warm.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("de-months-foundation-read", in: pack, "Am 3. März")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)

        // de-a2-konjunktiv-wuerde
        result = try gradeClozeBlank("de-a2-konjunktiv-wuerde-cloze", in: pack, blank: "b1", "werde")
        XCTAssertEqual(result.category, "wrong tense")
        XCTAssertFalse(result.accepted)
        result = try gradeClozeBlank("de-a2-konjunktiv-wuerde-cloze", in: pack, blank: "b1", "würdest")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("de-a2-konjunktiv-wuerde-think", in: pack, "Ich würde gern reise.")
        XCTAssertEqual(result.category, "wrong conjugation")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-a2-konjunktiv-wuerde-think", in: pack, "Ich werde gern reisen.")
        XCTAssertEqual(result.category, "wrong tense")
        result = try gradeText("de-a2-konjunktiv-wuerde-vary", in: pack, "Würde du mir helfen?")
        XCTAssertEqual(result.category, "wrong conjugation")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-a2-konjunktiv-wuerde-vary", in: pack, "Würdest du mir helfe?")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("de-a2-konjunktiv-wuerde-read", in: pack, "Mehr reisen")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)

        // de-a2-komparativ
        result = try gradeClozeBlank("de-a2-komparativ-cloze", in: pack, blank: "b1", "wie")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeClozeBlank("de-a2-komparativ-cloze", in: pack, blank: "b1", "als wie")
        XCTAssertEqual(result.category, "extra word")
        result = try gradeText("de-a2-komparativ-think", in: pack, "Berlin ist größer wie München.")
        XCTAssertEqual(result.category, "wrong preposition")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-a2-komparativ-think", in: pack, "Berlin ist größer München.")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeText("de-a2-komparativ-vary", in: pack, "Das Hostel ist teurer als das Hotel.")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-a2-komparativ-vary", in: pack, "Das Hotel ist teuer als das Hostel.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("de-a2-komparativ-read", in: pack, "Das Hostel")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)

        // de-a2-wechselpraepositionen
        result = try gradeText(
            "de-a2-wechselpraepositionen-think", in: pack, "Das Buch liegt auf den Tisch.")
        XCTAssertEqual(result.category, "wrong article")
        XCTAssertFalse(result.accepted)
        result = try gradeText(
            "de-a2-wechselpraepositionen-think", in: pack, "Das Buch liegt auf der Tisch.")
        XCTAssertEqual(result.category, "wrong article")
        result = try gradeClozeBlank("de-a2-wechselpraepositionen-cloze", in: pack, blank: "b1", "dem")
        XCTAssertEqual(result.category, "wrong article")
        XCTAssertFalse(result.accepted)
        result = try gradeText(
            "de-a2-wechselpraepositionen-vary", in: pack, "Ich hänge das Bild an der Wand.")
        XCTAssertEqual(result.category, "wrong article")
        XCTAssertFalse(result.accepted)
        result = try gradeText(
            "de-a2-wechselpraepositionen-vary", in: pack, "Das Bild hängt an die Wand.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("de-a2-wechselpraepositionen-read", in: pack, "An der Wand")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)

        // de-a2-passiv-intro
        result = try gradeText("de-a2-passiv-intro-think", in: pack, "Das Auto wird reparieren.")
        XCTAssertEqual(result.category, "wrong conjugation")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-a2-passiv-intro-think", in: pack, "Das Auto ist repariert.")
        XCTAssertEqual(result.category, "wrong tense")
        result = try gradeClozeBlank("de-a2-passiv-intro-cloze", in: pack, blank: "b1", "liefern")
        XCTAssertEqual(result.category, "wrong conjugation")
        XCTAssertFalse(result.accepted)
        result = try gradeClozeBlank("de-a2-passiv-intro-cloze", in: pack, blank: "b1", "werden geliefert")
        XCTAssertEqual(result.category, "extra word")
        result = try gradeText("de-a2-passiv-intro-vary", in: pack, "Man wird das Auto repariert.")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-a2-passiv-intro-vary", in: pack, "Das Auto wird reparieren.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("de-a2-passiv-intro-read", in: pack, "Sie werden geliefert.")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)

        // de-a2-berufsvokabular
        result = try gradeText(
            "de-a2-berufsvokabular-think", in: pack, "Das Vorstellungsgespräch ist in Montag.")
        XCTAssertEqual(result.category, "wrong preposition")
        XCTAssertFalse(result.accepted)
        result = try gradeText(
            "de-a2-berufsvokabular-think", in: pack, "Die Vorstellungsgespräch ist am Montag.")
        XCTAssertEqual(result.category, "wrong article")
        result = try gradeClozeBlank("de-a2-berufsvokabular-cloze", in: pack, blank: "b1", "für")
        XCTAssertEqual(result.category, "wrong preposition")
        XCTAssertFalse(result.accepted)
        result = try gradeClozeBlank("de-a2-berufsvokabular-cloze", in: pack, blank: "b1", "bei")
        XCTAssertEqual(result.category, "wrong preposition")
        result = try gradeText("de-a2-berufsvokabular-vary", in: pack, "Ich bewerbe um die Stelle.")
        XCTAssertEqual(result.category, "missing word")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-a2-berufsvokabular-vary", in: pack, "Ich bewerbe mir um die Stelle.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("de-a2-berufsvokabular-read", in: pack, "Das Gehalt")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
    }

    /// Wave-D lessons accept their dictated target lines, natural German
    /// forms, and second accepted variants.
    func testBatch4AcceptsAuthoredAnswers() throws {
        let pack = try germanPack()

        // de-time-days-foundation
        var result = try gradeText("de-time-days-foundation-think", in: pack, "Heute ist Sonntag.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-time-days-foundation-read", in: pack, "Mittwoch")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-time-days-foundation-read", in: pack, "Wednesday")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank("de-time-days-foundation-cloze", in: pack, blank: "b1", "Morgen")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank("de-time-days-foundation-cloze", in: pack, blank: "b1", "morgen")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-time-days-foundation-meaning", in: pack, "On Monday I work.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-time-days-foundation-meaning", in: pack, "I work on Monday.")
        XCTAssertTrue(result.accepted)

        // de-home-foundation
        result = try gradeText("de-home-foundation-think", in: pack, "Das ist ein Stuhl.")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank("de-home-foundation-cloze", in: pack, blank: "b1", "ein")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-home-foundation-vary", in: pack, "Das ist ein Bett.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-home-foundation-read", in: pack, "Die Küche.")
        XCTAssertTrue(result.accepted)

        // de-descriptions-foundation
        result = try gradeText("de-descriptions-foundation-think", in: pack, "Das Zimmer ist klein.")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank("de-descriptions-foundation-cloze", in: pack, blank: "b1", "sehr")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-descriptions-foundation-vary", in: pack, "Das Auto ist alt.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-descriptions-foundation-read", in: pack, "Küche")
        XCTAssertTrue(result.accepted)

        // de-routine-foundation
        result = try gradeText("de-routine-foundation-think", in: pack, "Ich lerne abends.")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank("de-routine-foundation-cloze", in: pack, blank: "b1", "arbeite")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-routine-foundation-vary", in: pack, "Ich arbeite abends.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-routine-foundation-read", in: pack, "Mittags.")
        XCTAssertTrue(result.accepted)

        // de-food-foundation
        result = try gradeText("de-food-foundation-think", in: pack, "Ich esse Brot.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-food-foundation-vary", in: pack, "Ich mag Brot.")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank("de-food-foundation-cloze", in: pack, blank: "b1", "einen")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-food-foundation-read", in: pack, "Wasser.")
        XCTAssertTrue(result.accepted)

        // de-possession-foundation
        result = try gradeText("de-possession-foundation-think", in: pack, "Das ist meine Tasche.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-possession-foundation-vary", in: pack, "Das ist ihr Auto.")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank("de-possession-foundation-cloze", in: pack, blank: "b1", "dein")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-possession-foundation-read", in: pack, "meine Schwester")
        XCTAssertTrue(result.accepted)

        // de-plans-foundation
        result = try gradeText("de-plans-foundation-think", in: pack, "Morgen arbeite ich.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-plans-foundation-vary", in: pack, "Nächste Woche arbeite ich.")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank("de-plans-foundation-cloze", in: pack, blank: "b1", "Bald")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-plans-foundation-read", in: pack, "Nächste Woche")
        XCTAssertTrue(result.accepted)

        // de-months-foundation
        result = try gradeClozeBlank("de-months-foundation-cloze", in: pack, blank: "b1", "im")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-months-foundation-think", in: pack, "Mein Geburtstag ist im Mai.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-months-foundation-vary", in: pack, "Der Winter ist kalt.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-months-foundation-read", in: pack, "Am 3. Mai.")
        XCTAssertTrue(result.accepted)

        // de-a2-konjunktiv-wuerde
        result = try gradeClozeBlank("de-a2-konjunktiv-wuerde-cloze", in: pack, blank: "b1", "würde")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-a2-konjunktiv-wuerde-think", in: pack, "Ich würde gern reisen.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-a2-konjunktiv-wuerde-vary", in: pack, "Würdest du mir helfen?")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-a2-konjunktiv-wuerde-read", in: pack, "In Italien.")
        XCTAssertTrue(result.accepted)

        // de-a2-komparativ
        result = try gradeClozeBlank("de-a2-komparativ-cloze", in: pack, blank: "b1", "als")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-a2-komparativ-think", in: pack, "Berlin ist größer als München.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-a2-komparativ-vary", in: pack, "Das Hotel ist teurer als das Hostel.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-a2-komparativ-read", in: pack, "Das Frühstück.")
        XCTAssertTrue(result.accepted)

        // de-a2-wechselpraepositionen
        result = try gradeText(
            "de-a2-wechselpraepositionen-think", in: pack, "Das Buch liegt auf dem Tisch.")
        XCTAssertTrue(result.accepted)
        result = try gradeText(
            "de-a2-wechselpraepositionen-think", in: pack, "Das Buch ist auf dem Tisch.")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank("de-a2-wechselpraepositionen-cloze", in: pack, blank: "b1", "den")
        XCTAssertTrue(result.accepted)
        result = try gradeText(
            "de-a2-wechselpraepositionen-vary", in: pack, "Ich hänge das Bild an die Wand.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-a2-wechselpraepositionen-read", in: pack, "Über dem Sofa.")
        XCTAssertTrue(result.accepted)

        // de-a2-passiv-intro
        result = try gradeText("de-a2-passiv-intro-think", in: pack, "Das Auto wird repariert.")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank("de-a2-passiv-intro-cloze", in: pack, blank: "b1", "geliefert")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-a2-passiv-intro-vary", in: pack, "Das Auto wird repariert.")
        XCTAssertTrue(result.accepted)
        result = try gradeText(
            "de-a2-passiv-intro-read", in: pack, "Sie werden gebaut und verkauft.")
        XCTAssertTrue(result.accepted)

        // de-a2-berufsvokabular
        result = try gradeText(
            "de-a2-berufsvokabular-think", in: pack, "Das Vorstellungsgespräch ist am Montag.")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank("de-a2-berufsvokabular-cloze", in: pack, blank: "b1", "um")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-a2-berufsvokabular-vary", in: pack, "Ich bewerbe mich um die Stelle.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-a2-berufsvokabular-read", in: pack, "Ihren Lebenslauf.")
        XCTAssertTrue(result.accepted)
    }

    // MARK: - Wave E (6 conversation lessons, units 3–15)

    /// The six German conversation-family lessons edited in wave E (family
    /// == "conversation", unreviewed before this batch), keyed by the graded
    /// activity ids each lesson's path references.
    private static let batch5Lessons: [String: [String]] = [
        "de-shopping-foundation": [
            "de-shopping-foundation-act-rb2", "de-shopping-foundation-meet",
            "de-shopping-foundation-vary", "de-shopping-foundation-act-rb4",
            "de-shopping-foundation-act-rb3", "de-shopping-foundation-think",
            "de-shopping-foundation-ask",
        ],
        "de-family-people-foundation": [
            "de-family-people-foundation-act-rb2", "de-family-people-foundation-meet",
            "de-family-people-foundation-think", "de-family-people-foundation-act-rb3",
            "de-family-people-foundation-notice", "de-family-people-foundation-vary",
            "de-family-people-foundation-read",
        ],
        "de-questions-foundation": [
            "de-questions-foundation-act-rb2", "de-questions-foundation-meet",
            "de-questions-foundation-think", "de-questions-foundation-act-rb3",
            "de-questions-foundation-notice", "de-questions-foundation-vary",
            "de-questions-foundation-read",
        ],
        "de-health-foundation": [
            "de-health-foundation-act-rb2", "de-health-foundation-meet",
            "de-health-foundation-think", "de-health-foundation-act-rb3",
            "de-health-foundation-notice", "de-health-foundation-vary",
            "de-health-foundation-read",
        ],
        "de-invitations-foundation": [
            "de-invitations-foundation-act-rb2", "de-invitations-foundation-meet",
            "de-invitations-foundation-think", "de-invitations-foundation-act-rb3",
            "de-invitations-foundation-notice", "de-invitations-foundation-vary",
            "de-invitations-foundation-read",
        ],
        "de-a2-hoefliche-bitten": [
            "de-a2-hoefliche-bitten-act-rb2", "de-a2-hoefliche-bitten-meet",
            "de-a2-hoefliche-bitten-think", "de-a2-hoefliche-bitten-act-rb3",
            "de-a2-hoefliche-bitten-notice", "de-a2-hoefliche-bitten-vary",
            "de-a2-hoefliche-bitten-read",
        ],
    ]

    /// Every graded step in wave-E lessons has a real authored hint
    /// (audit_editorial hint-gap must stay 0 for these lessons).
    func testBatch5GradedStepsHaveAuthoredHints() throws {
        let pack = try germanPack()
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

    /// Every text answer and every cloze blank in wave-E lessons authors
    /// error-specific feedback (audit_editorial error-gap must stay 0).
    func testBatch5TextAndClozeActivitiesAuthorErrors() throws {
        let pack = try germanPack()
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

    /// Plausible wrong answers for wave-E lessons hit their authored
    /// category + explanation instead of the generic fallback.
    func testBatch5AuthoredErrorsFireForPlausibleWrongAnswers() throws {
        let pack = try germanPack()

        // de-shopping-foundation-vary (Es ist nicht teuer.)
        var result = try gradeText("de-shopping-foundation-vary", in: pack, "Es ist teuer nicht.")
        XCTAssertEqual(result.category, "word-order problem")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-shopping-foundation-vary", in: pack, "Es nicht ist teuer.")
        XCTAssertEqual(result.category, "word-order problem")
        result = try gradeText("de-shopping-foundation-vary", in: pack, "Es ist nicht billig.")
        XCTAssertEqual(result.category, "incorrect answer")

        // de-shopping-foundation-think (Was kostet ein Kaffee?)
        result = try gradeText("de-shopping-foundation-think", in: pack, "Was kostet einen Kaffee?")
        XCTAssertEqual(result.category, "wrong article")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-shopping-foundation-think", in: pack, "Was kostest ein Kaffee?")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("de-shopping-foundation-think", in: pack, "Ein Kaffee kostet was?")
        XCTAssertEqual(result.category, "word-order problem")

        // de-shopping-foundation-ask (Die Rechnung, bitte.)
        result = try gradeText("de-shopping-foundation-ask", in: pack, "Der Rechnung, bitte.")
        XCTAssertEqual(result.category, "wrong gender")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-shopping-foundation-ask", in: pack, "Das Rechnung, bitte.")
        XCTAssertEqual(result.category, "wrong article")
        result = try gradeText("de-shopping-foundation-ask", in: pack, "Die Rechnung.")
        XCTAssertEqual(result.category, "missing word")

        // de-family-people-foundation-think (Ich habe einen Bruder.)
        result = try gradeText("de-family-people-foundation-think", in: pack, "Ich habe ein Bruder.")
        XCTAssertEqual(result.category, "wrong article")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-family-people-foundation-think", in: pack, "Ich habe eine Bruder.")
        XCTAssertEqual(result.category, "wrong article")
        result = try gradeText("de-family-people-foundation-think", in: pack, "Ich habe einen Schwester.")
        XCTAssertEqual(result.category, "wrong gender")

        // de-family-people-foundation-vary (Ich habe zwei Schwestern.)
        result = try gradeText("de-family-people-foundation-vary", in: pack, "Ich habe zwei Schwester.")
        XCTAssertEqual(result.category, "wrong number")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-family-people-foundation-vary", in: pack, "Ich habe eine Schwestern.")
        XCTAssertEqual(result.category, "wrong number")
        result = try gradeText("de-family-people-foundation-vary", in: pack, "Ich habe zwei Brüder.")
        XCTAssertEqual(result.category, "incorrect answer")

        // de-family-people-foundation-read (Berlin)
        result = try gradeText("de-family-people-foundation-read", in: pack, "Hamburg.")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-family-people-foundation-read", in: pack, "Wien.")
        XCTAssertEqual(result.category, "incorrect answer")

        // de-questions-foundation-think (Wo arbeitest du?)
        result = try gradeText("de-questions-foundation-think", in: pack, "Wo du arbeitest?")
        XCTAssertEqual(result.category, "word-order problem")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-questions-foundation-think", in: pack, "Wo arbeiten du?")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("de-questions-foundation-think", in: pack, "Wo arbeitet du?")
        XCTAssertEqual(result.category, "wrong conjugation")

        // de-questions-foundation-vary (Wo arbeitest du?)
        result = try gradeText("de-questions-foundation-vary", in: pack, "Wann arbeitest du?")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-questions-foundation-vary", in: pack, "Wo du arbeitest?")
        XCTAssertEqual(result.category, "word-order problem")
        result = try gradeText("de-questions-foundation-vary", in: pack, "Wo arbeiten du?")
        XCTAssertEqual(result.category, "wrong conjugation")

        // de-questions-foundation-read (In Berlin.)
        result = try gradeText("de-questions-foundation-read", in: pack, "Ich wohne in Berlin.")
        XCTAssertEqual(result.category, "extra word")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-questions-foundation-read", in: pack, "Anna.")
        XCTAssertEqual(result.category, "incorrect answer")

        // de-health-foundation-think (Mir tut der Kopf weh.)
        result = try gradeText("de-health-foundation-think", in: pack, "Mein Kopf tut weh.")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-health-foundation-think", in: pack, "Mir tut meine Kopf weh.")
        XCTAssertEqual(result.category, "wrong article")
        result = try gradeText("de-health-foundation-think", in: pack, "Ich habe Kopfschmerzen.")
        XCTAssertEqual(result.category, "incorrect answer")

        // de-health-foundation-vary (Mir tut der Arm weh.)
        result = try gradeText("de-health-foundation-vary", in: pack, "Mir tut die Arm weh.")
        XCTAssertEqual(result.category, "wrong article")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-health-foundation-vary", in: pack, "Mir tut der Bein weh.")
        XCTAssertEqual(result.category, "wrong article")
        result = try gradeText("de-health-foundation-vary", in: pack, "Mein Arm tut weh.")
        XCTAssertEqual(result.category, "incorrect answer")

        // de-health-foundation-read (zum Arzt)
        result = try gradeText("de-health-foundation-read", in: pack, "Zu Hause.")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-health-foundation-read", in: pack, "Der Arzt.")
        XCTAssertEqual(result.category, "incorrect answer")

        // de-invitations-foundation-think (Ich lade dich ein.)
        result = try gradeText("de-invitations-foundation-think", in: pack, "Ich einlade dich.")
        XCTAssertEqual(result.category, "word-order problem")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-invitations-foundation-think", in: pack, "Ich lade ein dich.")
        XCTAssertEqual(result.category, "word-order problem")
        result = try gradeText("de-invitations-foundation-think", in: pack, "Ich lade du ein.")
        XCTAssertEqual(result.category, "incorrect answer")

        // de-invitations-foundation-vary (Leider kann ich nicht.)
        result = try gradeText("de-invitations-foundation-vary", in: pack, "Ich kann nicht.")
        XCTAssertEqual(result.category, "missing word")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-invitations-foundation-vary", in: pack, "Nein.")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText("de-invitations-foundation-vary", in: pack, "Leider nicht kann ich.")
        XCTAssertEqual(result.category, "word-order problem")

        // de-invitations-foundation-read (Am Samstag.)
        result = try gradeText("de-invitations-foundation-read", in: pack, "Am Sonntag.")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-invitations-foundation-read", in: pack, "Gern.")
        XCTAssertEqual(result.category, "incorrect answer")

        // de-a2-hoefliche-bitten-think (Könnten Sie bitte das Fenster öffnen?)
        result = try gradeText(
            "de-a2-hoefliche-bitten-think", in: pack, "Können Sie bitte das Fenster öffnen?")
        XCTAssertEqual(result.category, "wrong tense")
        XCTAssertFalse(result.accepted)
        result = try gradeText(
            "de-a2-hoefliche-bitten-think", in: pack, "Könntest du bitte das Fenster öffnen?")
        XCTAssertEqual(result.category, "incorrect answer")
        result = try gradeText(
            "de-a2-hoefliche-bitten-think", in: pack, "Könnten Sie bitte das Fenster öffnet?")
        XCTAssertEqual(result.category, "wrong conjugation")

        // de-a2-hoefliche-bitten-vary (Könnten Sie bitte die Tür schließen?)
        result = try gradeText(
            "de-a2-hoefliche-bitten-vary", in: pack, "Können Sie bitte die Tür schließen?")
        XCTAssertEqual(result.category, "wrong tense")
        XCTAssertFalse(result.accepted)
        result = try gradeText(
            "de-a2-hoefliche-bitten-vary", in: pack, "Könnten Sie bitte die Tür schließt?")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("de-a2-hoefliche-bitten-vary", in: pack, "Mach die Tür zu!")
        XCTAssertEqual(result.category, "incorrect answer")

        // de-a2-hoefliche-bitten-read (das Fenster öffnen)
        result = try gradeText("de-a2-hoefliche-bitten-read", in: pack, "Einen Moment warten.")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-a2-hoefliche-bitten-read", in: pack, "Später zu kommen.")
        XCTAssertEqual(result.category, "incorrect answer")
    }

    /// Wave-E lessons accept their dictated target lines, natural German
    /// forms, and second accepted variants.
    func testBatch5AcceptsAuthoredAnswers() throws {
        let pack = try germanPack()

        // de-shopping-foundation
        var result = try gradeText("de-shopping-foundation-vary", in: pack, "Es ist nicht teuer.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-shopping-foundation-think", in: pack, "Was kostet ein Kaffee?")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-shopping-foundation-ask", in: pack, "Die Rechnung, bitte.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-shopping-foundation-ask", in: pack, "Die Rechnung bitte.")
        XCTAssertTrue(result.accepted)

        // de-family-people-foundation
        result = try gradeText("de-family-people-foundation-think", in: pack, "Ich habe einen Bruder.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-family-people-foundation-vary", in: pack, "Ich habe zwei Schwestern.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-family-people-foundation-read", in: pack, "Berlin.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-family-people-foundation-read", in: pack, "In Berlin.")
        XCTAssertTrue(result.accepted)

        // de-questions-foundation
        result = try gradeText("de-questions-foundation-think", in: pack, "Wo arbeitest du?")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-questions-foundation-vary", in: pack, "Wo arbeitest du?")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-questions-foundation-read", in: pack, "Berlin")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-questions-foundation-read", in: pack, "in Berlin")
        XCTAssertTrue(result.accepted)

        // de-health-foundation
        result = try gradeText("de-health-foundation-think", in: pack, "Mir tut der Kopf weh.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-health-foundation-vary", in: pack, "Mir tut der Arm weh.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-health-foundation-read", in: pack, "Zum Arzt.")
        XCTAssertTrue(result.accepted)

        // de-invitations-foundation
        result = try gradeText("de-invitations-foundation-think", in: pack, "Ich lade dich ein.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-invitations-foundation-vary", in: pack, "Leider kann ich nicht.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-invitations-foundation-read", in: pack, "Am Samstag.")
        XCTAssertTrue(result.accepted)

        // de-a2-hoefliche-bitten
        result = try gradeText(
            "de-a2-hoefliche-bitten-think", in: pack, "Könnten Sie bitte das Fenster öffnen?")
        XCTAssertTrue(result.accepted)
        result = try gradeText(
            "de-a2-hoefliche-bitten-think", in: pack, "Könnten Sie das Fenster bitte öffnen?")
        XCTAssertTrue(result.accepted)
        result = try gradeText(
            "de-a2-hoefliche-bitten-vary", in: pack, "Würden Sie bitte die Tür schließen?")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-a2-hoefliche-bitten-read", in: pack, "Das Fenster öffnen.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-a2-hoefliche-bitten-read", in: pack, "Ein offenes Fenster.")
        XCTAssertTrue(result.accepted)
    }

    // MARK: - Wave F (batch 6): construction + recall families

    /// The fourteen construction/recall lessons dispositioned in wave F,
    /// keyed by the graded activity ids each lesson's path references.
    private static let batch6Lessons: [String: [String]] = [
        "de-requests-build-construction": [
            "de-requests-build-construction-act-2", "de-requests-build-construction-act-3",
            "de-requests-build-construction-act-4", "de-requests-build-construction-act-5",
            "de-requests-build-construction-act-6", "de-requests-build-construction-act-7",
            "de-requests-build-construction-act-8", "de-requests-build-construction-act-9",
        ],
        "de-remember-recall": [
            "de-remember-recall-act-2", "de-remember-recall-act-3",
            "de-remember-recall-act-4", "de-remember-recall-act-5",
            "de-remember-recall-act-6", "de-remember-recall-act-7",
            "de-remember-recall-act-8", "de-remember-recall-act-9",
        ],
        "de-routine-construction": [
            "de-routine-construction-act-2", "de-routine-construction-act-3",
            "de-routine-construction-act-4", "de-routine-construction-act-5",
            "de-routine-construction-act-6", "de-routine-construction-act-7",
            "de-routine-construction-act-8", "de-routine-construction-act-9",
        ],
        "de-plural-foundation": [
            "de-plural-foundation-build", "de-plural-foundation-act-rb1",
            "de-plural-foundation-meet", "de-plural-foundation-cloze",
            "de-plural-foundation-think", "de-plural-foundation-notice",
            "de-plural-foundation-vary",
        ],
        "de-negation-foundation": [
            "de-negation-foundation-build", "de-negation-foundation-act-rb1",
            "de-negation-foundation-meet", "de-negation-foundation-cloze",
            "de-negation-foundation-think", "de-negation-foundation-notice",
            "de-negation-foundation-vary",
        ],
        "de-requests-foundation": [
            "de-requests-foundation-meet", "de-requests-foundation-cloze",
            "de-requests-foundation-think", "de-requests-foundation-notice",
            "de-requests-foundation-act-rb2", "de-requests-foundation-vary",
        ],
        "de-time-telling-foundation": [
            "de-time-telling-foundation-meet", "de-time-telling-foundation-cloze",
            "de-time-telling-foundation-think", "de-time-telling-foundation-notice",
            "de-time-telling-foundation-act-rb2", "de-time-telling-foundation-vary",
        ],
        "de-a2-perfekt-bildung": [
            "de-a2-perfekt-bildung-build", "de-a2-perfekt-bildung-act-rb1",
            "de-a2-perfekt-bildung-meet", "de-a2-perfekt-bildung-cloze",
            "de-a2-perfekt-bildung-think", "de-a2-perfekt-bildung-notice",
            "de-a2-perfekt-bildung-vary",
        ],
        "de-a2-perfekt-sein-irregular": [
            "de-a2-perfekt-sein-irregular-meet", "de-a2-perfekt-sein-irregular-cloze",
            "de-a2-perfekt-sein-irregular-think", "de-a2-perfekt-sein-irregular-notice",
            "de-a2-perfekt-sein-irregular-act-rb2", "de-a2-perfekt-sein-irregular-vary",
        ],
        "de-a2-praeteritum-modal": [
            "de-a2-praeteritum-modal-meet", "de-a2-praeteritum-modal-cloze",
            "de-a2-praeteritum-modal-think", "de-a2-praeteritum-modal-notice",
            "de-a2-praeteritum-modal-act-rb2", "de-a2-praeteritum-modal-vary",
        ],
        "de-a2-futur-bildung": [
            "de-a2-futur-bildung-build", "de-a2-futur-bildung-act-rb1",
            "de-a2-futur-bildung-meet", "de-a2-futur-bildung-cloze",
            "de-a2-futur-bildung-think", "de-a2-futur-bildung-notice",
            "de-a2-futur-bildung-vary",
        ],
        "de-a2-irreale-wuensche": [
            "de-a2-irreale-wuensche-meet", "de-a2-irreale-wuensche-cloze",
            "de-a2-irreale-wuensche-think", "de-a2-irreale-wuensche-notice",
            "de-a2-irreale-wuensche-act-rb2", "de-a2-irreale-wuensche-vary",
        ],
        "de-a2-relativsaetze": [
            "de-a2-relativsaetze-build", "de-a2-relativsaetze-act-rb1",
            "de-a2-relativsaetze-meet", "de-a2-relativsaetze-cloze",
            "de-a2-relativsaetze-think", "de-a2-relativsaetze-notice",
            "de-a2-relativsaetze-vary",
        ],
        "de-a2-superlativ": [
            "de-a2-superlativ-meet", "de-a2-superlativ-cloze",
            "de-a2-superlativ-think", "de-a2-superlativ-notice",
            "de-a2-superlativ-act-rb2", "de-a2-superlativ-vary",
        ],
    ]

    /// Every graded step in wave-F lessons has a real authored hint
    /// (audit_editorial hint-gap must stay 0 for these lessons).
    func testBatch6GradedStepsHaveAuthoredHints() throws {
        let pack = try germanPack()
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
        let pack = try germanPack()
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

    /// Plausible wrong answers in wave-F lessons hit their authored
    /// category + explanation instead of the generic fallback.
    func testBatch6AuthoredErrorsFireForPlausibleWrongAnswers() throws {
        let pack = try germanPack()

        // de-requests-build-construction-act-6 (einen)
        var result = try gradeClozeBlank(
            "de-requests-build-construction-act-6", in: pack, blank: "b1", "ein")
        XCTAssertEqual(result.category, "wrong article")
        XCTAssertFalse(result.accepted)
        result = try gradeClozeBlank(
            "de-requests-build-construction-act-6", in: pack, blank: "b1", "eine")
        XCTAssertEqual(result.category, "wrong gender")

        // de-requests-build-construction-act-7 (Einen Kaffee, bitte.)
        result = try gradeText("de-requests-build-construction-act-7", in: pack, "Ein Kaffee, bitte.")
        XCTAssertEqual(result.category, "wrong article")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-requests-build-construction-act-7", in: pack, "Kaffee, bitte.")
        XCTAssertEqual(result.category, "missing word")

        // de-requests-build-construction-act-9 (Ich möchte einen Kaffee, bitte.)
        result = try gradeText(
            "de-requests-build-construction-act-9", in: pack, "Ich möchte ein Kaffee, bitte.")
        XCTAssertEqual(result.category, "wrong article")
        XCTAssertFalse(result.accepted)
        result = try gradeText(
            "de-requests-build-construction-act-9", in: pack, "Möchte ich einen Kaffee, bitte.")
        XCTAssertEqual(result.category, "word-order problem")

        // de-remember-recall-act-4 (danke)
        result = try gradeText("de-remember-recall-act-4", in: pack, "danken")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-remember-recall-act-4", in: pack, "danke schön")
        XCTAssertEqual(result.category, "extra word")

        // de-remember-recall-act-7 (der Bruder)
        result = try gradeText("de-remember-recall-act-7", in: pack, "die Bruder")
        XCTAssertEqual(result.category, "wrong article")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-remember-recall-act-7", in: pack, "der Schwester")
        XCTAssertEqual(result.category, "incorrect answer")

        // de-remember-recall-act-9 (gern)
        result = try gradeClozeBlank("de-remember-recall-act-9", in: pack, blank: "b1", "spielen")
        XCTAssertEqual(result.category, "wrong conjugation")
        XCTAssertFalse(result.accepted)
        result = try gradeClozeBlank("de-remember-recall-act-9", in: pack, blank: "b1", "lieber")
        XCTAssertEqual(result.category, "incorrect answer")

        // de-routine-construction-act-7 (Ich wohne in Berlin.)
        result = try gradeText("de-routine-construction-act-7", in: pack, "Ich lebe in Berlin.")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-routine-construction-act-7", in: pack, "Ich wohne Berlin.")
        XCTAssertEqual(result.category, "missing word")
        result = try gradeText("de-routine-construction-act-7", in: pack, "Ich wohnen in Berlin.")
        XCTAssertEqual(result.category, "wrong conjugation")

        // de-routine-construction-act-8 (spielt)
        result = try gradeClozeBlank(
            "de-routine-construction-act-8", in: pack, blank: "b1", "spiele")
        XCTAssertEqual(result.category, "wrong conjugation")
        XCTAssertFalse(result.accepted)
        result = try gradeClozeBlank(
            "de-routine-construction-act-8", in: pack, blank: "b1", "spielen")
        XCTAssertEqual(result.category, "wrong conjugation")

        // de-plural-foundation-think (Die Tische sind groß.)
        result = try gradeText("de-plural-foundation-think", in: pack, "Die Tisch sind groß.")
        XCTAssertEqual(result.category, "wrong number")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-plural-foundation-think", in: pack, "Die Tische ist groß.")
        XCTAssertEqual(result.category, "wrong conjugation")
        result = try gradeText("de-plural-foundation-think", in: pack, "Der Tische sind groß.")
        XCTAssertEqual(result.category, "wrong article")

        // de-plural-foundation-vary (Die Autos sind neu.)
        result = try gradeText("de-plural-foundation-vary", in: pack, "Die Auto sind neu.")
        XCTAssertEqual(result.category, "wrong number")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-plural-foundation-vary", in: pack, "Das Autos sind neu.")
        XCTAssertEqual(result.category, "wrong article")
        result = try gradeText("de-plural-foundation-vary", in: pack, "Die Autos ist neu.")
        XCTAssertEqual(result.category, "wrong conjugation")

        // de-negation-foundation-think (Ich habe kein Auto.)
        result = try gradeText("de-negation-foundation-think", in: pack, "Ich habe keine Auto.")
        XCTAssertEqual(result.category, "wrong article")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-negation-foundation-think", in: pack, "Ich habe nicht Auto.")
        XCTAssertEqual(result.category, "incorrect answer")

        // de-negation-foundation-vary (Ich habe kein Auto.)
        result = try gradeText("de-negation-foundation-vary", in: pack, "Ich habe keine Auto.")
        XCTAssertEqual(result.category, "wrong article")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-negation-foundation-vary", in: pack, "Ich habe kein Autos.")
        XCTAssertEqual(result.category, "wrong number")

        // de-requests-foundation-think (Ich möchte einen Kaffee.)
        result = try gradeText("de-requests-foundation-think", in: pack, "Ich möchte ein Kaffee.")
        XCTAssertEqual(result.category, "wrong article")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-requests-foundation-think", in: pack, "Ich möchte eine Kaffee.")
        XCTAssertEqual(result.category, "wrong gender")
        result = try gradeText("de-requests-foundation-think", in: pack, "Ich möchte einen Tee.")
        XCTAssertEqual(result.category, "incorrect answer")

        // de-requests-foundation-vary (Ich möchte Deutsch sprechen.)
        result = try gradeText("de-requests-foundation-vary", in: pack, "Ich will Deutsch sprechen.")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeText(
            "de-requests-foundation-vary", in: pack, "Ich möchte sprechen Deutsch.")
        XCTAssertEqual(result.category, "word-order problem")
        result = try gradeText(
            "de-requests-foundation-vary", in: pack, "Ich möchte Deutsch spreche.")
        XCTAssertEqual(result.category, "wrong conjugation")

        // de-time-telling-foundation-think (Es ist halb drei.)
        result = try gradeText("de-time-telling-foundation-think", in: pack, "Es ist halb zwei.")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-time-telling-foundation-think", in: pack, "Es ist halb drei Uhr.")
        XCTAssertEqual(result.category, "extra word")
        result = try gradeText("de-time-telling-foundation-think", in: pack, "Es ist drei halb.")
        XCTAssertEqual(result.category, "word-order problem")

        // de-time-telling-foundation-vary (Es ist viertel vor drei.)
        result = try gradeText(
            "de-time-telling-foundation-vary", in: pack, "Es ist viertel nach drei.")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeText(
            "de-time-telling-foundation-vary", in: pack, "Es ist viertel vor drei Uhr.")
        XCTAssertEqual(result.category, "extra word")

        // de-a2-perfekt-bildung-think (Ich habe Fußball gespielt.)
        result = try gradeText("de-a2-perfekt-bildung-think", in: pack, "Ich habe Fußball spielen.")
        XCTAssertEqual(result.category, "wrong conjugation")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-a2-perfekt-bildung-think", in: pack, "Ich spielte Fußball.")
        XCTAssertEqual(result.category, "wrong tense")

        // de-a2-perfekt-bildung-vary (Er hat Tennis gespielt.)
        result = try gradeText("de-a2-perfekt-bildung-vary", in: pack, "Er hat Tennis spielt.")
        XCTAssertEqual(result.category, "wrong conjugation")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-a2-perfekt-bildung-vary", in: pack, "Er habe Tennis gespielt.")
        XCTAssertEqual(result.category, "wrong conjugation")

        // de-a2-perfekt-sein-irregular-cloze (Bist)
        result = try gradeClozeBlank(
            "de-a2-perfekt-sein-irregular-cloze", in: pack, blank: "b1", "Hast")
        XCTAssertEqual(result.category, "wrong auxiliary")
        XCTAssertFalse(result.accepted)
        result = try gradeClozeBlank(
            "de-a2-perfekt-sein-irregular-cloze", in: pack, blank: "b1", "Bin")
        XCTAssertEqual(result.category, "wrong conjugation")

        // de-a2-perfekt-sein-irregular-think (Sie ist spät gekommen.)
        result = try gradeText(
            "de-a2-perfekt-sein-irregular-think", in: pack, "Sie hat spät gekommen.")
        XCTAssertEqual(result.category, "wrong auxiliary")
        XCTAssertFalse(result.accepted)
        result = try gradeText(
            "de-a2-perfekt-sein-irregular-think", in: pack, "Sie ist spät gekommt.")
        XCTAssertEqual(result.category, "wrong conjugation")

        // de-a2-perfekt-sein-irregular-vary (Er ist nach Hause gegangen.)
        result = try gradeText(
            "de-a2-perfekt-sein-irregular-vary", in: pack, "Er hat nach Hause gegangen.")
        XCTAssertEqual(result.category, "wrong auxiliary")
        XCTAssertFalse(result.accepted)
        result = try gradeText(
            "de-a2-perfekt-sein-irregular-vary", in: pack, "Er ist gegangen nach Hause.")
        XCTAssertEqual(result.category, "word-order problem")

        // de-a2-praeteritum-modal-think (Sie war müde.)
        result = try gradeText("de-a2-praeteritum-modal-think", in: pack, "Sie ist müde.")
        XCTAssertEqual(result.category, "wrong tense")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-a2-praeteritum-modal-think", in: pack, "Sie hatte müde.")
        XCTAssertEqual(result.category, "incorrect answer")

        // de-a2-praeteritum-modal-vary (Ich musste früh aufstehen.)
        result = try gradeText(
            "de-a2-praeteritum-modal-vary", in: pack, "Ich muss früh aufstehen.")
        XCTAssertEqual(result.category, "wrong tense")
        XCTAssertFalse(result.accepted)
        result = try gradeText(
            "de-a2-praeteritum-modal-vary", in: pack, "Ich müsste früh aufstehen.")
        XCTAssertEqual(result.category, "incorrect answer")

        // de-a2-futur-bildung-think (Ich werde nächstes Jahr reisen.)
        result = try gradeText(
            "de-a2-futur-bildung-think", in: pack, "Ich werde nächstes Jahr reise.")
        XCTAssertEqual(result.category, "wrong conjugation")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-a2-futur-bildung-think", in: pack, "Ich reise nächstes Jahr.")
        XCTAssertEqual(result.category, "wrong tense")
        result = try gradeText(
            "de-a2-futur-bildung-think", in: pack, "Ich werde reisen nächstes Jahr.")
        XCTAssertEqual(result.category, "word-order problem")

        // de-a2-futur-bildung-vary (Sie wird Deutsch lernen.)
        result = try gradeText("de-a2-futur-bildung-vary", in: pack, "Sie wird Deutsch lernt.")
        XCTAssertEqual(result.category, "wrong conjugation")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-a2-futur-bildung-vary", in: pack, "Sie lernt Deutsch.")
        XCTAssertEqual(result.category, "wrong tense")

        // de-a2-irreale-wuensche-think (Wenn ich nur mehr Zeit hätte!)
        result = try gradeText(
            "de-a2-irreale-wuensche-think", in: pack, "Wenn ich nur mehr Zeit habe!")
        XCTAssertEqual(result.category, "wrong tense")
        XCTAssertFalse(result.accepted)
        result = try gradeText(
            "de-a2-irreale-wuensche-think", in: pack, "Wenn ich nur hätte mehr Zeit!")
        XCTAssertEqual(result.category, "word-order problem")

        // de-a2-irreale-wuensche-vary (Ich wünschte, ich wäre in Italien.)
        result = try gradeText(
            "de-a2-irreale-wuensche-vary", in: pack, "Ich wünschte, ich bin in Italien.")
        XCTAssertEqual(result.category, "wrong tense")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-a2-irreale-wuensche-vary", in: pack, "Ich wäre in Italien.")
        XCTAssertEqual(result.category, "missing word")

        // de-a2-relativsaetze-think (Das ist der Mann, der dort wohnt.)
        result = try gradeText(
            "de-a2-relativsaetze-think", in: pack, "Das ist der Mann, den dort wohnt.")
        XCTAssertEqual(result.category, "wrong article")
        XCTAssertFalse(result.accepted)
        result = try gradeText(
            "de-a2-relativsaetze-think", in: pack, "Das ist der Mann, der wohnt dort.")
        XCTAssertEqual(result.category, "word-order problem")

        // de-a2-relativsaetze-vary (Das ist ein Hotel, das sehr schön ist.)
        result = try gradeText(
            "de-a2-relativsaetze-vary", in: pack, "Das ist ein Hotel, der sehr schön ist.")
        XCTAssertEqual(result.category, "wrong article")
        XCTAssertFalse(result.accepted)
        result = try gradeText(
            "de-a2-relativsaetze-vary", in: pack, "Das ist ein Hotel, dass sehr schön ist.")
        XCTAssertEqual(result.category, "incorrect answer")

        // de-a2-superlativ-think (Das ist die schönste Stadt.)
        result = try gradeText("de-a2-superlativ-think", in: pack, "Das ist das schönste Stadt.")
        XCTAssertEqual(result.category, "wrong article")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-a2-superlativ-think", in: pack, "Das ist die schönste Städte.")
        XCTAssertEqual(result.category, "wrong number")

        // de-a2-superlativ-act-rb2 (am schnellsten)
        result = try gradeClozeBlank("de-a2-superlativ-act-rb2", in: pack, blank: "b1", "am schnellste")
        XCTAssertEqual(result.category, "missing word")
        XCTAssertFalse(result.accepted)
        result = try gradeClozeBlank("de-a2-superlativ-act-rb2", in: pack, blank: "b1", "der schnellste")
        XCTAssertEqual(result.category, "wrong article")

        // de-a2-superlativ-vary (Das Hotel ist am besten.)
        result = try gradeText("de-a2-superlativ-vary", in: pack, "Das Hotel ist am gutesten.")
        XCTAssertEqual(result.category, "incorrect answer")
        XCTAssertFalse(result.accepted)
        result = try gradeText("de-a2-superlativ-vary", in: pack, "Das Hotel ist am best.")
        XCTAssertEqual(result.category, "missing word")
    }

    /// Wave-F lessons accept their dictated target lines and cloze answers.
    func testBatch6AcceptsAuthoredAnswers() throws {
        let pack = try germanPack()

        // de-requests-build-construction
        var result = try gradeText(
            "de-requests-build-construction-act-7", in: pack, "Einen Kaffee, bitte.")
        XCTAssertTrue(result.accepted)
        result = try gradeText(
            "de-requests-build-construction-act-9", in: pack, "Ich möchte einen Kaffee, bitte.")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank(
            "de-requests-build-construction-act-6", in: pack, blank: "b1", "einen")
        XCTAssertTrue(result.accepted)

        // de-remember-recall
        result = try gradeText("de-remember-recall-act-4", in: pack, "danke")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-remember-recall-act-7", in: pack, "der Bruder")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank("de-remember-recall-act-3", in: pack, blank: "b1", "Was")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank("de-remember-recall-act-9", in: pack, blank: "b1", "gern")
        XCTAssertTrue(result.accepted)

        // de-routine-construction
        result = try gradeText("de-routine-construction-act-7", in: pack, "Ich wohne in Berlin.")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank(
            "de-routine-construction-act-5", in: pack, blank: "b1", "Morgen")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank(
            "de-routine-construction-act-8", in: pack, blank: "b1", "spielt")
        XCTAssertTrue(result.accepted)

        // de-plural-foundation
        result = try gradeText("de-plural-foundation-think", in: pack, "Die Tische sind groß.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-plural-foundation-vary", in: pack, "Die Autos sind neu.")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank("de-plural-foundation-cloze", in: pack, blank: "b1", "Frauen")
        XCTAssertTrue(result.accepted)

        // de-negation-foundation
        result = try gradeText("de-negation-foundation-think", in: pack, "Ich habe kein Auto.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-negation-foundation-vary", in: pack, "Ich habe kein Auto.")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank(
            "de-negation-foundation-cloze", in: pack, blank: "b1", "keine")
        XCTAssertTrue(result.accepted)

        // de-requests-foundation
        result = try gradeText("de-requests-foundation-think", in: pack, "Ich möchte einen Kaffee.")
        XCTAssertTrue(result.accepted)
        result = try gradeText(
            "de-requests-foundation-vary", in: pack, "Ich möchte Deutsch sprechen.")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank(
            "de-requests-foundation-act-rb2", in: pack, blank: "b1", "kann")
        XCTAssertTrue(result.accepted)

        // de-time-telling-foundation
        result = try gradeText("de-time-telling-foundation-think", in: pack, "Es ist halb drei.")
        XCTAssertTrue(result.accepted)
        result = try gradeText(
            "de-time-telling-foundation-vary", in: pack, "Es ist viertel vor drei.")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank(
            "de-time-telling-foundation-act-rb2", in: pack, blank: "b1", "nach")
        XCTAssertTrue(result.accepted)

        // de-a2-perfekt-bildung
        result = try gradeText("de-a2-perfekt-bildung-think", in: pack, "Ich habe Fußball gespielt.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-a2-perfekt-bildung-vary", in: pack, "Er hat Tennis gespielt.")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank(
            "de-a2-perfekt-bildung-cloze", in: pack, blank: "b1", "hat")
        XCTAssertTrue(result.accepted)

        // de-a2-perfekt-sein-irregular
        result = try gradeText(
            "de-a2-perfekt-sein-irregular-think", in: pack, "Sie ist spät gekommen.")
        XCTAssertTrue(result.accepted)
        result = try gradeText(
            "de-a2-perfekt-sein-irregular-vary", in: pack, "Er ist nach Hause gegangen.")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank(
            "de-a2-perfekt-sein-irregular-cloze", in: pack, blank: "b1", "Bist")
        XCTAssertTrue(result.accepted)

        // de-a2-praeteritum-modal
        result = try gradeText("de-a2-praeteritum-modal-think", in: pack, "Sie war müde.")
        XCTAssertTrue(result.accepted)
        result = try gradeText(
            "de-a2-praeteritum-modal-vary", in: pack, "Ich musste früh aufstehen.")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank(
            "de-a2-praeteritum-modal-cloze", in: pack, blank: "b1", "konnte")
        XCTAssertTrue(result.accepted)

        // de-a2-futur-bildung
        result = try gradeText(
            "de-a2-futur-bildung-think", in: pack, "Ich werde nächstes Jahr reisen.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-a2-futur-bildung-vary", in: pack, "Sie wird Deutsch lernen.")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank("de-a2-futur-bildung-cloze", in: pack, blank: "b1", "werde")
        XCTAssertTrue(result.accepted)

        // de-a2-irreale-wuensche
        result = try gradeText(
            "de-a2-irreale-wuensche-think", in: pack, "Wenn ich nur mehr Zeit hätte!")
        XCTAssertTrue(result.accepted)
        result = try gradeText(
            "de-a2-irreale-wuensche-vary", in: pack, "Ich wünschte, ich wäre in Italien.")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank(
            "de-a2-irreale-wuensche-act-rb2", in: pack, blank: "b1", "wäre")
        XCTAssertTrue(result.accepted)

        // de-a2-relativsaetze
        result = try gradeText(
            "de-a2-relativsaetze-think", in: pack, "Das ist der Mann, der dort wohnt.")
        XCTAssertTrue(result.accepted)
        result = try gradeText(
            "de-a2-relativsaetze-vary", in: pack, "Das ist ein Hotel, das sehr schön ist.")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank("de-a2-relativsaetze-cloze", in: pack, blank: "b1", "den")
        XCTAssertTrue(result.accepted)

        // de-a2-superlativ
        result = try gradeText("de-a2-superlativ-think", in: pack, "Das ist die schönste Stadt.")
        XCTAssertTrue(result.accepted)
        result = try gradeText("de-a2-superlativ-vary", in: pack, "Das Hotel ist am besten.")
        XCTAssertTrue(result.accepted)
        result = try gradeClozeBlank(
            "de-a2-superlativ-act-rb2", in: pack, blank: "b1", "am schnellsten")
        XCTAssertTrue(result.accepted)
    }
}