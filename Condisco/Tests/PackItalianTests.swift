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

    // MARK: - Wave B missions (units 5–13, family == "mission")

    /// The seven in-scope Wave B missions/stories must ship an authored,
    /// non-generic hint on every graded path step (rubric H4).
    func testWaveBMissionsHaveAuthoredStepHints() throws {
        let pack = try italianPack()
        let lessonIds = ["it-time-foundation", "it-market-run-mission",
                         "it-restaurant-mission", "it-directions-mission",
                         "it-a2-progetti-futuri", "it-a2-lavoro",
                         "it-a2-albergo-mission"]
        let generic: Set<String> = ["Try it", "Try again", "Not quite — try again.",
            "That selection is not valid. Try again.", "The order is not right yet. Try again.",
            "Some pairs are off. Try again.", "Place every token exactly once.",
            "Each pairing must use listed items exactly once.",
            "Each region counts once. Try again."]
        for lessonId in lessonIds {
            let lesson = try XCTUnwrap(pack.lesson(id: lessonId), "missing \(lessonId)")
            for step in lesson.steps {
                guard let activity = pack.activity(id: step.activityId),
                      let base = activity.base else { continue }
                XCTAssertFalse(base.hints.isEmpty,
                               "\(lessonId) step \(step.id) has no authored hint")
                XCTAssertFalse(base.hints.allSatisfy(generic.contains),
                               "\(lessonId) step \(step.id) has only generic hints")
            }
        }
    }

    /// Every text answer and cloze blank in the Wave B set carries authored
    /// errors, so the wrong-answer path never falls back to the generic
    /// string on those surfaces (rubric H3).
    func testWaveBMissionsHaveAuthoredErrors() throws {
        let pack = try italianPack()
        let lessonIds = ["it-time-foundation", "it-market-run-mission",
                         "it-restaurant-mission", "it-directions-mission",
                         "it-a2-progetti-futuri", "it-a2-lavoro",
                         "it-a2-albergo-mission"]
        for lessonId in lessonIds {
            let lesson = try XCTUnwrap(pack.lesson(id: lessonId), "missing \(lessonId)")
            for step in lesson.steps {
                for activityID in [step.activityId, step.supportActivityId].compactMap({ $0 }) {
                    guard let activity = pack.activity(id: activityID) else { continue }
                    switch activity {
                    case .text(let spec):
                        XCTAssertFalse(spec.answer.errors.isEmpty,
                                       "\(lessonId) \(activityID) text has no authored errors")
                    case .cloze(let spec):
                        for (name, blank) in spec.blanks {
                            XCTAssertFalse(blank.errors.isEmpty,
                                           "\(lessonId) \(activityID) blank \(name) has no authored errors")
                        }
                    default:
                        break
                    }
                }
            }
        }
    }

    /// it-time-foundation-cloze b1: one o'clock uses the singular È; sono is
    /// the authored wrong-conjugation error, not an accepted alternative.
    func testTimeClozeOneOclockSingular() throws {
        let pack = try italianPack()
        let spec = try clozeBlank(pack, "it-time-foundation-cloze", "b1")
        XCTAssertTrue(AnswerEngine.evaluate(response: "È", spec: spec).accepted)
        XCTAssertTrue(AnswerEngine.evaluate(response: "è", spec: spec).accepted)
        let sono = AnswerEngine.evaluate(response: "Sono", spec: spec)
        XCTAssertFalse(sono.accepted)
        XCTAssertEqual(sono.category, "wrong conjugation")
    }

    /// it-time-foundation-produce: the half-past sentence needs its verb; a
    /// dropped Sono le returns the authored missing-word error and mezzo is a
    /// wrong-gender error (mezza agrees with ora).
    func testTimeProduceHalfPastForms() throws {
        let pack = try italianPack()
        let spec = try textSpec(pack, "it-time-foundation-produce")
        XCTAssertTrue(AnswerEngine.evaluate(response: "Sono le tre e mezza.", spec: spec).accepted)
        XCTAssertTrue(AnswerEngine.evaluate(response: "Sono le 3 e mezza.", spec: spec).accepted)
        let noVerb = AnswerEngine.evaluate(response: "Le tre e mezza.", spec: spec)
        XCTAssertFalse(noVerb.accepted)
        XCTAssertEqual(noVerb.category, "missing word")
        let mezzo = AnswerEngine.evaluate(response: "Sono le tre e mezzo.", spec: spec)
        XCTAssertFalse(mezzo.accepted)
        XCTAssertEqual(mezzo.category, "wrong gender")
    }

    /// it-time-foundation-act-rb3: quarter to eight is meno un quarto, not the
    /// quarter-past form; the confusion returns an authored error.
    func testTimeTrainQuarterToDirection() throws {
        let pack = try italianPack()
        let spec = try textSpec(pack, "it-time-foundation-act-rb3")
        XCTAssertTrue(AnswerEngine.evaluate(response: "Il treno parte alle otto meno un quarto.", spec: spec).accepted)
        XCTAssertTrue(AnswerEngine.evaluate(response: "Parte alle otto meno un quarto.", spec: spec).accepted)
        let quarterPast = AnswerEngine.evaluate(response: "Il treno parte alle otto e un quarto.", spec: spec)
        XCTAssertFalse(quarterPast.accepted)
        XCTAssertEqual(quarterPast.category, "incorrect answer")
    }

    /// it-market-run-mission-act-3 b1: the verb agrees with the thing weighed
    /// (un chilo → costa), not with the price — the authored wrong-number error
    /// teaches the contrast the lesson now checks.
    func testMarketKiloCostaSingularRule() throws {
        let pack = try italianPack()
        let spec = try clozeBlank(pack, "it-market-run-mission-act-3", "b1")
        XCTAssertTrue(AnswerEngine.evaluate(response: "Costa", spec: spec).accepted)
        XCTAssertTrue(AnswerEngine.evaluate(response: "costa", spec: spec).accepted)
        let plural = AnswerEngine.evaluate(response: "Costano", spec: spec)
        XCTAssertFalse(plural.accepted)
        XCTAssertEqual(plural.category, "wrong number")
    }

    /// it-market-run-mission-act-6: the market question keeps the singular
    /// verb for a kilo; the plural form is an authored wrong-conjugation error.
    func testMarketQuestionKiloAgreement() throws {
        let pack = try italianPack()
        let spec = try textSpec(pack, "it-market-run-mission-act-6")
        XCTAssertTrue(AnswerEngine.evaluate(response: "Quanto costa un chilo di mele?", spec: spec).accepted)
        let plural = AnswerEngine.evaluate(response: "Quanto costano un chilo di mele?", spec: spec)
        XCTAssertFalse(plural.accepted)
        XCTAssertEqual(plural.category, "wrong conjugation")
    }

    /// it-market-run-mission-act-9 (final response, converted to text): the
    /// closing line takes the io form prendo; prendi is an authored error.
    func testMarketFinalTakeResponse() throws {
        let pack = try italianPack()
        let spec = try textSpec(pack, "it-market-run-mission-act-9")
        XCTAssertTrue(AnswerEngine.evaluate(response: "Grazie, prendo un chilo di mele.", spec: spec).accepted)
        XCTAssertTrue(AnswerEngine.evaluate(response: "Prendo un chilo di mele, grazie.", spec: spec).accepted)
        let prendi = AnswerEngine.evaluate(response: "Grazie, prendi un chilo di mele.", spec: spec)
        XCTAssertFalse(prendi.accepted)
        XCTAssertEqual(prendi.category, "wrong conjugation")
    }

    /// it-restaurant-mission-act-8: the polite bill request accepts both word
    /// orders; the feminine la conto is an authored wrong-gender error.
    func testRestaurantBillPoliteRequest() throws {
        let pack = try italianPack()
        let spec = try textSpec(pack, "it-restaurant-mission-act-8")
        XCTAssertTrue(AnswerEngine.evaluate(response: "Il conto, per favore.", spec: spec).accepted)
        XCTAssertTrue(AnswerEngine.evaluate(response: "Per favore, il conto.", spec: spec).accepted)
        let wrongGender = AnswerEngine.evaluate(response: "La conto, per favore.", spec: spec)
        XCTAssertFalse(wrongGender.accepted)
        XCTAssertEqual(wrongGender.category, "wrong gender")
    }

    /// it-restaurant-mission-act-9 (final response, converted to text): the
    /// goodbye is arrivederci, not the informal ciao or a repeat of the bill
    /// request.
    func testRestaurantFinalGoodbye() throws {
        let pack = try italianPack()
        let spec = try textSpec(pack, "it-restaurant-mission-act-9")
        XCTAssertTrue(AnswerEngine.evaluate(response: "Grazie, arrivederci!", spec: spec).accepted)
        let ciao = AnswerEngine.evaluate(response: "Grazie, ciao!", spec: spec)
        XCTAssertFalse(ciao.accepted)
        XCTAssertEqual(ciao.category, "incorrect answer")
        let billRepeat = AnswerEngine.evaluate(response: "Prendo il conto.", spec: spec)
        XCTAssertFalse(billRepeat.accepted)
        XCTAssertEqual(billRepeat.category, "incorrect answer")
    }

    /// it-directions-mission-act-9 (final response, converted to text): the
    /// arrival line states where you are with sono; vai is an authored
    /// wrong-conjugation error.
    func testDirectionsFinalArrivalStatement() throws {
        let pack = try italianPack()
        let spec = try textSpec(pack, "it-directions-mission-act-9")
        XCTAssertTrue(AnswerEngine.evaluate(response: "Ciao! Sono alla piazza!", spec: spec).accepted)
        let vai = AnswerEngine.evaluate(response: "Ciao! Vai alla piazza.", spec: spec)
        XCTAssertFalse(vai.accepted)
        XCTAssertEqual(vai.category, "wrong conjugation")
    }

    /// it-directions-mission-act-3 b1: the place name keeps its article
    /// (la stazione); dropping it returns the authored missing-word error.
    func testDirectionsStationArticleCloze() throws {
        let pack = try italianPack()
        let spec = try clozeBlank(pack, "it-directions-mission-act-3", "b1")
        XCTAssertTrue(AnswerEngine.evaluate(response: "la stazione", spec: spec).accepted)
        let bare = AnswerEngine.evaluate(response: "stazione", spec: spec)
        XCTAssertFalse(bare.accepted)
        XCTAssertEqual(bare.category, "missing word")
        let wrongArticle = AnswerEngine.evaluate(response: "il stazione", spec: spec)
        XCTAssertFalse(wrongArticle.accepted)
        XCTAssertEqual(wrongArticle.category, "wrong article")
    }

    /// it-a2-albergo-mission-act-6: the shower is the subject, so the verb is
    /// third-person singular funziona; funziono is an authored
    /// wrong-conjugation error.
    func testAlbergoShowerSubjectAgreement() throws {
        let pack = try italianPack()
        let spec = try textSpec(pack, "it-a2-albergo-mission-act-6")
        XCTAssertTrue(AnswerEngine.evaluate(response: "La doccia non funziona.", spec: spec).accepted)
        let funziono = AnswerEngine.evaluate(response: "La doccia non funziono.", spec: spec)
        XCTAssertFalse(funziono.accepted)
        XCTAssertEqual(funziono.category, "wrong conjugation")
    }

    /// it-a2-albergo-mission-act-7 b1: the polite request is potrebbe darmi;
    /// the blunt imperative dammi is an authored error, not a pass.
    func testAlbergoPoliteDarmiRequest() throws {
        let pack = try italianPack()
        let spec = try clozeBlank(pack, "it-a2-albergo-mission-act-7", "b1")
        XCTAssertTrue(AnswerEngine.evaluate(response: "darmi", spec: spec).accepted)
        XCTAssertTrue(AnswerEngine.evaluate(response: "Darmi", spec: spec).accepted)
        let dammi = AnswerEngine.evaluate(response: "dammi", spec: spec)
        XCTAssertFalse(dammi.accepted)
        XCTAssertEqual(dammi.category, "incorrect answer")
        let wrongOrder = AnswerEngine.evaluate(response: "mi dare", spec: spec)
        XCTAssertFalse(wrongOrder.accepted)
        XCTAssertEqual(wrongOrder.category, "word-order problem")
    }

    /// it-a2-lavoro-cloze b1 + it-a2-lavoro-vary: the si impersonale keeps the
    /// third-person singular; ci and the plural si mangiano are authored errors.
    func testLavoroImpersonalSiForms() throws {
        let pack = try italianPack()
        let cloze = try clozeBlank(pack, "it-a2-lavoro-cloze", "b1")
        XCTAssertTrue(AnswerEngine.evaluate(response: "Si", spec: cloze).accepted)
        XCTAssertTrue(AnswerEngine.evaluate(response: "si", spec: cloze).accepted)
        let ci = AnswerEngine.evaluate(response: "Ci", spec: cloze)
        XCTAssertFalse(ci.accepted)
        XCTAssertEqual(ci.category, "incorrect answer")

        let vary = try textSpec(pack, "it-a2-lavoro-vary")
        XCTAssertTrue(AnswerEngine.evaluate(response: "Qui si mangia bene.", spec: vary).accepted)
        XCTAssertTrue(AnswerEngine.evaluate(response: "Si mangia bene qui.", spec: vary).accepted)
        let plural = AnswerEngine.evaluate(response: "Si mangiano bene qui.", spec: vary)
        XCTAssertFalse(plural.accepted)
        XCTAssertEqual(plural.category, "wrong number")
    }

    /// it-a2-progetti-futuri-cloze b1 + it-a2-progetti-futuri-think: the near
    /// future needs andare + a + infinitive; dropping the a returns the
    /// authored missing-word error.
    func testProgettiFuturiNearFutureBridge() throws {
        let pack = try italianPack()
        let cloze = try clozeBlank(pack, "it-a2-progetti-futuri-cloze", "b1")
        XCTAssertTrue(AnswerEngine.evaluate(response: "andiamo a", spec: cloze).accepted)
        XCTAssertTrue(AnswerEngine.evaluate(response: "Andiamo a", spec: cloze).accepted)
        let noBridge = AnswerEngine.evaluate(response: "andiamo", spec: cloze)
        XCTAssertFalse(noBridge.accepted)
        XCTAssertEqual(noBridge.category, "missing word")

        let think = try textSpec(pack, "it-a2-progetti-futuri-think")
        XCTAssertTrue(AnswerEngine.evaluate(response: "Andiamo a viaggiare ad agosto.", spec: think).accepted)
        let missingA = AnswerEngine.evaluate(response: "Andiamo viaggiare ad agosto.", spec: think)
        XCTAssertFalse(missingA.accepted)
        XCTAssertEqual(missingA.category, "missing word")
    }
}