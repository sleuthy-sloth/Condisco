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
}