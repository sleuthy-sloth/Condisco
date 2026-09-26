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
}