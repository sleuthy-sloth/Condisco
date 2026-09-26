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
        // Home's Today section (header via its stable identifier) is the
        // first-run dashboard headline; a fresh learner has no account
        // data on this device.
        XCTAssertTrue(app.staticTexts["home.today.header"].waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Steven")).firstMatch.exists)

        app.tabBars.buttons["You"].tap()
        XCTAssertTrue(app.staticTexts["Your learning"].waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(app.staticTexts["At a glance"].exists)
        XCTAssertTrue(app.buttons["Preferences"].exists)
        XCTAssertTrue(app.buttons["Account and data"].exists)
        app.tabBars.buttons["Home"].tap()

        // The Today card's primary row (next-lesson headline for a fresh
        // learner) is the first mission — opened through its stable
        // identifier, with the mission title still asserted by copy.
        let todayPrimary = app.buttons["home.today.primary"]
        XCTAssertTrue(todayPrimary.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(todayPrimary.label.contains("Mission : un café à Paris"), app.debugDescription)
        if !todayPrimary.isHittable { app.swipeUp() }
        todayPrimary.tap()
        XCTAssertTrue(app.buttons["Start lesson"].waitForExistence(timeout: 20))

        app.buttons["Start lesson"].tap()
        let guideDone = app.buttons["Got it"]
        XCTAssertTrue(guideDone.waitForExistence(timeout: 10))
        guideDone.tap()
        app.buttons["Continue"].tap()
        let greetingQuestion = app.staticTexts["The server looks up from the counter. How do you greet them?"]
        XCTAssertTrue(greetingQuestion.waitForExistence(timeout: 10))

        app.buttons["Lessons"].tap()
        // Leaving mid-lesson lands back on Home, whose Today card now
        // headlines the resume — the same primary row, reopened by its
        // stable identifier.
        let resume = app.buttons["home.today.primary"]
        XCTAssertTrue(resume.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(resume.label.contains("Mission : un café à Paris"), app.debugDescription)
        resume.tap()
        XCTAssertTrue(greetingQuestion.waitForExistence(timeout: 15))

        app.buttons["Bonjour."].tap()
        checkThenAdvance(app)

        XCTAssertTrue(app.staticTexts["Build the order: A coffee, please."].waitForExistence(timeout: 10))

        app.buttons["Add Un"].tap()
        app.buttons["Add café,"].tap()
        app.buttons["Add s’il vous plaît."].tap()
        checkThenAdvance(app)

        XCTAssertTrue(app.staticTexts["The cup reaches the counter. What do you say?"].waitForExistence(timeout: 10))
        app.buttons["Merci."].tap()
        checkThenAdvance(app)

        let think = app.buttons["I've thought about it — let me answer"]
        XCTAssertTrue(think.waitForExistence(timeout: 10))
        think.tap()
        let orderAnswer = app.textViews.firstMatch
        XCTAssertTrue(orderAnswer.waitForExistence(timeout: 10))
        orderAnswer.tap()
        orderAnswer.typeText("Un cafe, s’il vous plaît.")
        submitTypedAnswer(app)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Add the accent")).firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Model answer: Un café")).firstMatch.exists)
        app.buttons["Next step"].tap()

        XCTAssertTrue(app.staticTexts["Match the three lines you used to their meanings."].waitForExistence(timeout: 10))
        app.buttons["Bonjour."].tap()
        app.buttons["Hello."].tap()
        app.buttons["Un café, s’il vous plaît."].tap()
        app.buttons["A coffee, please."].tap()
        app.buttons["Merci."].tap()
        app.buttons["Thank you."].tap()
        checkThenAdvance(app)

        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Write the café exchange in order")).firstMatch.waitForExistence(timeout: 10))
        let finalAnswer = app.textViews.firstMatch
        XCTAssertTrue(finalAnswer.waitForExistence(timeout: 10))
        finalAnswer.tap()
        finalAnswer.typeText("No idea yet")
        submitTypedAnswer(app)
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

    /// Submits a typed answer through the pinned "Check" button. The
    /// pinned bar's accessibility frame can lag the keyboard's appearance
    /// (reporting the pre-keyboard position at the bottom of the screen),
    /// so a tap made too early lands on the keyboard itself instead of
    /// the button. Wait until the frame reflects the inset — above the
    /// keyboard when one is up — before tapping.
    private func submitTypedAnswer(_ app: XCUIApplication) {
        let check = app.buttons["Check"]
        XCTAssertTrue(check.waitForExistence(timeout: 10))
        let keyboard = app.keyboards.element
        let settled = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                if keyboard.exists {
                    return check.frame.midY < keyboard.frame.minY
                }
                return check.isHittable
            },
            object: nil)
        XCTAssertEqual(
            XCTWaiter().wait(for: [settled], timeout: 10),
            .completed,
            app.debugDescription)
        check.tap()
    }
}
