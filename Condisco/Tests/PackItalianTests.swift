import XCTest
@testable import Condisco

/// Per-pack editorial regression tests for the Italian pack.
///
/// Owned by the Italian editorial lane: add targeted answer/evaluation
/// tests here for content fixes (resolved high-confidence errors,
/// narrowed accepted-answer sets, authored error feedback). Do not put
/// other packs' tests in this file.
final class PackItalianTests: XCTestCase {
    func testItalianPackLoadsAndValidates() throws {
        let packs = try PackLoader.loadPacks()
        let pack = try XCTUnwrap(packs.first { $0.language.slug == "italian" })
        XCTAssertFalse(pack.lessons.isEmpty, "Italian pack must ship lessons")
        XCTAssertNoThrow(try PackValidator.validate(pack), pack.id)
    }

    // MARK: - Helpers

    private func italianPack() throws -> CoursePack {
        let packs = try PackLoader.loadPacks()
        return try XCTUnwrap(packs.first { $0.language.slug == "italian" })
    }

    private func textSpec(_ pack: CoursePack, _ id: String, line: UInt = #line) throws -> AnswerSpec {
        let activity = try XCTUnwrap(pack.activity(id: id), line: line)
        guard case .text(let spec) = activity else {
            throw XCTSkip("expected a text activity: \(id)")
        }
        return spec.answer
    }

    private func clozeBlank(_ pack: CoursePack, _ id: String, _ blank: String,
                            line: UInt = #line) throws -> AnswerSpec {
        let activity = try XCTUnwrap(pack.activity(id: id), line: line)
        guard case .cloze(let spec) = activity else {
            throw XCTSkip("expected a cloze activity: \(id)")
        }
        return try XCTUnwrap(spec.blanks[blank], line: line)
    }

    // MARK: - Unit 1 (it-unit-1)

    /// it-cafe-mission-act-7: the reversed polite order is accepted; a missing
    /// accent on caffè is an authored accent/diacritic error, not a pass.
    func testCafeMissionOrderWordingAndAccent() throws {
        let pack = try italianPack()
        let spec = try textSpec(pack, "it-cafe-mission-act-7")
        XCTAssertTrue(AnswerEngine.evaluate(response: "Un caffè, per favore.", spec: spec).accepted)
        XCTAssertTrue(AnswerEngine.evaluate(response: "Per favore, un caffè.", spec: spec).accepted)
        let missingAccent = AnswerEngine.evaluate(response: "Un cafe, per favore.", spec: spec)
        XCTAssertFalse(missingAccent.accepted)
        XCTAssertEqual(missingAccent.category, "accent/diacritic issue")
    }

    /// it-routine-foundation-act-rb4: only forms that encode "every evening"
    /// are accepted; the loose "La sera studia." variant was removed, and the
    /// infinitive form is an authored wrong-conjugation error.
    func testRoutineEveryEveningAcceptedSet() throws {
        let pack = try italianPack()
        let spec = try textSpec(pack, "it-routine-foundation-act-rb4")
        XCTAssertTrue(AnswerEngine.evaluate(response: "Studia ogni sera.", spec: spec).accepted)
        XCTAssertTrue(AnswerEngine.evaluate(response: "Ogni sera studia.", spec: spec).accepted)
        XCTAssertFalse(AnswerEngine.evaluate(response: "La sera studia.", spec: spec).accepted,
                       "drops 'every' and should not pass a dictated 'every evening' prompt")
        let infinitive = AnswerEngine.evaluate(response: "Studiare ogni sera.", spec: spec)
        XCTAssertFalse(infinitive.accepted)
        XCTAssertEqual(infinitive.category, "wrong conjugation")
    }

    /// it-numbers-foundation-produce: digit forms match the same lesson's
    /// dictation step, so "Ho 20 anni." is accepted for "I am twenty years old."
    func testNumbersProduceAcceptsDigitForms() throws {
        let pack = try italianPack()
        let spec = try textSpec(pack, "it-numbers-foundation-produce")
        XCTAssertTrue(AnswerEngine.evaluate(response: "Ho venti anni.", spec: spec).accepted)
        XCTAssertTrue(AnswerEngine.evaluate(response: "Ho 20 anni.", spec: spec).accepted)
        XCTAssertTrue(AnswerEngine.evaluate(response: "Io ho 20 anni.", spec: spec).accepted)
        XCTAssertFalse(AnswerEngine.evaluate(response: "Sono venti anni.", spec: spec).accepted)
    }

    /// it-numbers-foundation-meaning: age is expressed as an English question;
    /// the literal "have years" rendering is an authored error.
    func testNumbersMeaningAgeQuestion() throws {
        let pack = try italianPack()
        let spec = try textSpec(pack, "it-numbers-foundation-meaning")
        XCTAssertTrue(AnswerEngine.evaluate(response: "Are you thirty years old?", spec: spec).accepted)
        XCTAssertTrue(AnswerEngine.evaluate(response: "Are you 30 years old?", spec: spec).accepted)
        XCTAssertFalse(AnswerEngine.evaluate(response: "You have thirty years.", spec: spec).accepted)
    }

    /// it-people-foundation-meaning: Lei è italiana also reads as the formal
    /// "you" in standard Italian, so the formal-English translation is accepted.
    func testPeopleMeaningAcceptsFormalLeiReading() throws {
        let pack = try italianPack()
        let spec = try textSpec(pack, "it-people-foundation-meaning")
        XCTAssertTrue(AnswerEngine.evaluate(response: "She is Italian.", spec: spec).accepted)
        XCTAssertTrue(AnswerEngine.evaluate(response: "You are Italian.", spec: spec).accepted)
        let wrongGender = AnswerEngine.evaluate(response: "He is Italian.", spec: spec)
        XCTAssertFalse(wrongGender.accepted)
        XCTAssertEqual(wrongGender.category, "wrong gender")
    }

    // MARK: - Unit 2 (it-unit-2)

    /// it-home-foundation-cloze b1: only the masculine singular article il is
    /// accepted; la is an authored wrong-article error.
    func testHomeClozeArticleGrading() throws {
        let pack = try italianPack()
        let spec = try clozeBlank(pack, "it-home-foundation-cloze", "b1")
        XCTAssertTrue(AnswerEngine.evaluate(response: "Il", spec: spec).accepted)
        XCTAssertTrue(AnswerEngine.evaluate(response: "il", spec: spec).accepted)
        let wrongArticle = AnswerEngine.evaluate(response: "La", spec: spec)
        XCTAssertFalse(wrongArticle.accepted)
        XCTAssertEqual(wrongArticle.category, "wrong article")
    }

    /// it-home-foundation-act-rb4: è (is) must keep its accent; "e" means "and"
    /// and is an authored accent/diacritic error with allowTypo still true.
    func testHomeBookSentenceAccentError() throws {
        let pack = try italianPack()
        let spec = try textSpec(pack, "it-home-foundation-act-rb4")
        XCTAssertTrue(AnswerEngine.evaluate(response: "Il libro è in casa.", spec: spec).accepted)
        XCTAssertTrue(AnswerEngine.evaluate(response: "Il libro è nella casa.", spec: spec).accepted)
        let accent = AnswerEngine.evaluate(response: "Il libro e in casa.", spec: spec)
        XCTAssertFalse(accent.accepted)
        XCTAssertEqual(accent.category, "accent/diacritic issue")
    }

    /// it-plural-foundation-cloze b1: plural masculine adjective ends in -i;
    /// singular or feminine forms return the authored wrong-number/gender errors.
    func testPluralClozeAgreementErrors() throws {
        let pack = try italianPack()
        let spec = try clozeBlank(pack, "it-plural-foundation-cloze", "b1")
        XCTAssertTrue(AnswerEngine.evaluate(response: "bianchi", spec: spec).accepted)
        let singular = AnswerEngine.evaluate(response: "bianco", spec: spec)
        XCTAssertFalse(singular.accepted)
        XCTAssertEqual(singular.category, "wrong number")
        let feminine = AnswerEngine.evaluate(response: "bianca", spec: spec)
        XCTAssertFalse(feminine.accepted)
        XCTAssertEqual(feminine.category, "wrong gender")
    }
}