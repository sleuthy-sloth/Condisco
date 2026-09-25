import XCTest

final class FirstRunUITests: XCTestCase {
    func testFreshFrenchLearnerCanFinishFirstMissionAfterAccentAndWrongAnswer() {
        let app = XCUIApplication()
        app.launchArguments.append("--condisco-ui-test-reset")
        app.launch()

        let getStarted = app.buttons["Choose a language"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 30), app.debugDescription)
        getStarted.tap()

        XCTAssertTrue(app.staticTexts["Which language are you learning?"].waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(app.staticTexts["French foundations"].exists, app.debugDescription)
        app.buttons["Continue"].tap()

        let freshStart = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "I'm starting fresh")).firstMatch
        XCTAssertTrue(freshStart.waitForExistence(timeout: 10), app.debugDescription)
        freshStart.tap()

        XCTAssertTrue(app.buttons["Start lesson"].waitForExistence(timeout: 20), app.debugDescription)
        app.buttons["Back to lessons"].tap()

        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 30), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Continue learning"].waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Steven")).firstMatch.exists)

        app.tabBars.buttons["You"].tap()
        XCTAssertTrue(app.staticTexts["Your learning"].waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(app.staticTexts["At a glance"].exists)
        XCTAssertTrue(app.buttons["Preferences"].exists)
        XCTAssertTrue(app.buttons["Account and data"].exists)
        app.tabBars.buttons["Home"].tap()

        let firstLesson = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Mission : un café à Paris")).firstMatch
        if !firstLesson.isHittable { app.swipeUp() }
        XCTAssertTrue(firstLesson.waitForExistence(timeout: 10))
        firstLesson.tap()
        XCTAssertTrue(app.buttons["Start lesson"].waitForExistence(timeout: 20))

        app.buttons["Start lesson"].tap()
        let guideDone = app.buttons["Got it"]
        XCTAssertTrue(guideDone.waitForExistence(timeout: 10))
        guideDone.tap()
        app.buttons["Continue"].tap()
        let greetingQuestion = app.staticTexts["You step inside. The server looks up. What leaves your mouth first?"]
        XCTAssertTrue(greetingQuestion.waitForExistence(timeout: 10))

        app.buttons["Lessons"].tap()
        let resume = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Mission : un café à Paris")).firstMatch
        XCTAssertTrue(resume.waitForExistence(timeout: 15))
        resume.tap()
        XCTAssertTrue(greetingQuestion.waitForExistence(timeout: 15))

        app.buttons["Bonjour."].tap()
        checkThenAdvance(app)

        XCTAssertTrue(app.staticTexts["Build your order. Say: A coffee, please."].waitForExistence(timeout: 10))

        app.buttons["Add Un"].tap()
        app.buttons["Add café,"].tap()
        app.buttons["Add s’il vous plaît."].tap()
        checkThenAdvance(app)

        XCTAssertTrue(app.staticTexts["Your coffee arrives, with a smile. What do you say?"].waitForExistence(timeout: 10))
        app.buttons["Merci."].tap()
        checkThenAdvance(app)

        let think = app.buttons["I've thought about it — let me answer"]
        XCTAssertTrue(think.waitForExistence(timeout: 10))
        think.tap()
        let orderAnswer = app.textViews.firstMatch
        XCTAssertTrue(orderAnswer.waitForExistence(timeout: 10))
        orderAnswer.tap()
        orderAnswer.typeText("Un cafe, s’il vous plaît.")
        app.buttons["Check"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Add the accent")).firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Model answer: Un café")).firstMatch.exists)
        app.buttons["Next step"].tap()

        XCTAssertTrue(app.staticTexts["Quick check — match each line to its meaning."].waitForExistence(timeout: 10))
        app.buttons["Bonjour."].tap()
        app.buttons["Hello."].tap()
        app.buttons["Un café, s’il vous plaît."].tap()
        app.buttons["A coffee, please."].tap()
        app.buttons["Merci."].tap()
        app.buttons["Thank you."].tap()
        checkThenAdvance(app)

        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Bring the café visit together")).firstMatch.waitForExistence(timeout: 10))
        let finalAnswer = app.textViews.firstMatch
        XCTAssertTrue(finalAnswer.waitForExistence(timeout: 10))
        finalAnswer.tap()
        finalAnswer.typeText("No idea yet")
        app.buttons["Check"].tap()
        let useModel = app.buttons["Continue with model answer"]
        XCTAssertTrue(useModel.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Model answer: Bonjour")).firstMatch.exists)
        useModel.tap()
        XCTAssertTrue(app.buttons["Back to lessons"].waitForExistence(timeout: 15))
        app.buttons["Back to lessons"].tap()

        XCTAssertTrue(app.tabBars.buttons["Review"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Review"].tap()
        XCTAssertTrue(app.navigationBars["Review"].waitForExistence(timeout: 15))
    }

    private func checkThenAdvance(_ app: XCUIApplication) {
        let check = app.buttons["Check"]
        XCTAssertTrue(check.waitForExistence(timeout: 10))
        XCTAssertTrue(check.isEnabled)
        check.tap()
        let next = app.buttons["Next step"]
        XCTAssertTrue(next.waitForExistence(timeout: 15))
        next.tap()
    }
}
