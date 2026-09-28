import XCTest

/// Courses-tab level navigation (course levels): the Foundation,
/// Developing, and Independent cards on the Courses tab are real controls
/// with stable identifiers and VoiceOver labels naming the level and its
/// lesson count; a populated level opens only the courses that have
/// lessons there; opening one of those courses scopes the lesson list to
/// the level (no vocabulary, no lessons or checkpoints from another
/// level, level-scoped search); the ordinary course card still shows
/// every unit and the vocabulary entry.
final class CourseLevelsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Onboarding → Home with a blank profile, the fastest deterministic
    /// path to the tab bar.
    private func completeOnboardingToHome(_ app: XCUIApplication) {
        app.launchArguments.append("--condisco-ui-test-reset")
        app.launch()

        let getStarted = app.buttons["Choose a language"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 30), app.debugDescription)
        getStarted.tap()
        XCTAssertTrue(app.staticTexts["Which language are you learning?"]
            .waitForExistence(timeout: 10), app.debugDescription)
        app.buttons["Continue"].tap()
        let freshStart = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "I'm starting fresh")).firstMatch
        XCTAssertTrue(freshStart.waitForExistence(timeout: 10), app.debugDescription)
        freshStart.tap()
        let startLesson = app.buttons["Start lesson"]
        XCTAssertTrue(startLesson.waitForExistence(timeout: 20), app.debugDescription)
        let backToLessons = app.buttons["Back to lessons"]
        XCTAssertTrue(backToLessons.waitForExistence(timeout: 10), app.debugDescription)
        backToLessons.tap()
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 30),
                      app.debugDescription)
    }

    private func scrollToIfNeeded(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<4 where !element.isHittable {
            app.swipeUp()
        }
    }

    /// The full level journey: Independent card → Spanish (the only
    /// course with B1/B2 lessons) → a level-scoped Spanish lesson list →
    /// back → the ordinary Spanish course still shows all levels and
    /// vocabulary.
    func testIndependentLevelLeadsToScopedLessonsAndOrdinaryCourseKeepsEverything() {
        let app = XCUIApplication()
        completeOnboardingToHome(app)

        app.tabBars.buttons["Courses"].tap()

        // Every populated level card is a button with a stable identifier
        // and a VoiceOver label naming the level and its lesson count.
        let foundation = app.buttons["courses.level.foundation"]
        let developing = app.buttons["courses.level.developing"]
        let independent = app.buttons["courses.level.independent"]
        XCTAssertTrue(foundation.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(developing.exists, app.debugDescription)
        XCTAssertTrue(independent.exists, app.debugDescription)
        XCTAssertTrue(
            independent.label.contains("Browse Independent"),
            "the level card must announce its purpose, got: \(independent.label)")

        // Independent → only Spanish carries B1/B2 lessons today.
        scrollToIfNeeded(independent, app: app)
        XCTAssertTrue(independent.isHittable, app.debugDescription)
        independent.tap()
        XCTAssertTrue(app.navigationBars["Independent"].waitForExistence(timeout: 10),
                      app.debugDescription)
        let spanish = app.staticTexts["Spanish"]
        XCTAssertTrue(spanish.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertFalse(app.staticTexts["French"].exists, app.debugDescription)
        XCTAssertFalse(app.staticTexts["Italian"].exists, app.debugDescription)
        XCTAssertFalse(app.staticTexts["German"].exists, app.debugDescription)
        XCTAssertFalse(app.staticTexts["Portuguese"].exists, app.debugDescription)

        // Spanish at the Independent level → the lesson list is scoped:
        // only B1/B2 units and lessons, no vocabulary, no other level.
        spanish.tap()
        XCTAssertTrue(app.staticTexts["Spanish · Independent"]
            .waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(app.staticTexts["El tren de las siete"]
            .waitForExistence(timeout: 10),
                      "an Independent (B1) lesson must be reachable: \(app.debugDescription)")
        XCTAssertFalse(app.staticTexts["Misión: un café en Madrid"].exists,
                       "a Foundation lesson must not leak into the scoped list")
        XCTAssertFalse(app.staticTexts["Formar el pretérito"].exists,
                       "a Developing lesson must not leak into the scoped list")
        XCTAssertFalse(app.staticTexts["Vocabulary"].exists,
                       "vocabulary is not level-scoped and must be hidden")

        // Only the Independent stage's checkpoint ends the scoped list —
        // Foundation and Developing checkpoints never appear.
        XCTAssertTrue(app.staticTexts["Plans, reasons and decisions"].exists,
                      "the Independent checkpoint must round off the scoped list")
        XCTAssertFalse(app.staticTexts["First steps in Spanish"].exists,
                       "the Foundation checkpoint must not appear in the scoped list")
        XCTAssertFalse(app.staticTexts["Telling stories and plans"].exists,
                       "the Developing checkpoint must not appear in the scoped list")

        // Back to the level page, then back to the Courses tab.
        app.navigationBars["Spanish · Independent"].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Independent"].waitForExistence(timeout: 10),
                      app.debugDescription)
        app.navigationBars["Independent"].buttons.firstMatch.tap()

        // The ordinary Spanish course keeps everything: the vocabulary
        // entry plus Foundation, Developing, and Independent lessons.
        XCTAssertTrue(app.staticTexts["Browse by level"].waitForExistence(timeout: 10),
                      app.debugDescription)
        let spanishCard = app.staticTexts["Spanish"]
        scrollToIfNeeded(spanishCard, app: app)
        XCTAssertTrue(spanishCard.isHittable, app.debugDescription)
        spanishCard.tap()
        XCTAssertTrue(app.staticTexts["Vocabulary"].waitForExistence(timeout: 10),
                      "the ordinary course keeps its vocabulary entry")
        XCTAssertTrue(app.staticTexts["Misión: un café en Madrid"].exists,
                      "Foundation lessons stay in the ordinary course")
        XCTAssertTrue(app.staticTexts["Formar el pretérito"].exists,
                      "Developing lessons stay in the ordinary course")
        XCTAssertTrue(app.staticTexts["El tren de las siete"].exists,
                      "Independent lessons stay in the ordinary course")
    }

    /// Foundation and Developing cards navigate too, and search inside a
    /// scoped list only matches lessons at that level.
    func testFoundationAndDevelopingLevelsNavigateAndScopeSearch() throws {
        let app = XCUIApplication()
        completeOnboardingToHome(app)

        app.tabBars.buttons["Courses"].tap()

        // Foundation: every course has A1/untagged lessons.
        let foundation = app.buttons["courses.level.foundation"]
        XCTAssertTrue(foundation.waitForExistence(timeout: 15), app.debugDescription)
        scrollToIfNeeded(foundation, app: app)
        foundation.tap()
        XCTAssertTrue(app.navigationBars["Foundation"].waitForExistence(timeout: 10),
                      app.debugDescription)
        let french = app.staticTexts["French"]
        XCTAssertTrue(french.waitForExistence(timeout: 10), app.debugDescription)
        french.tap()
        XCTAssertTrue(app.staticTexts["French · Foundation"]
            .waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Mission : un café à Paris"]
            .waitForExistence(timeout: 10),
                      "a Foundation lesson must show in the scoped list")
        XCTAssertFalse(app.staticTexts["Yesterday, in two beats"].exists,
                       "a Developing lesson must not leak into a Foundation list")
        XCTAssertFalse(app.staticTexts["Vocabulary"].exists, app.debugDescription)

        // Back out to the Courses tab.
        app.navigationBars["French · Foundation"].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Foundation"].waitForExistence(timeout: 10))
        app.navigationBars["Foundation"].buttons.firstMatch.tap()

        // Developing: French's A2 lessons scope out the Foundation ones.
        let developing = app.buttons["courses.level.developing"]
        XCTAssertTrue(developing.waitForExistence(timeout: 10), app.debugDescription)
        developing.tap()
        XCTAssertTrue(app.navigationBars["Developing"].waitForExistence(timeout: 10),
                      app.debugDescription)
        XCTAssertTrue(app.staticTexts["French"].waitForExistence(timeout: 10),
                      app.debugDescription)
        app.staticTexts["French"].tap()
        XCTAssertTrue(app.staticTexts["French · Developing"]
            .waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Yesterday, in two beats"]
            .waitForExistence(timeout: 10),
                      "a Developing lesson must show in the scoped list")
        XCTAssertFalse(app.staticTexts["Mission : un café à Paris"].exists,
                       "a Foundation lesson must not leak into a Developing list")

        // Scoped search: iOS 18+ keeps the inline-title search field in a
        // collapsed drawer that automation cannot reveal reliably on every
        // runtime. When it is exposed, verify the query matches only the
        // Developing lesson; scoped-search correctness is pinned in any
        // case by CoursePathTests.testScopedSearchNeverEscapesTheLevel.
        let search = app.searchFields.firstMatch
        guard search.waitForExistence(timeout: 3) else {
            throw XCTSkip("the inline-title search drawer is not exposed to automation on this runtime")
        }
        search.tap()
        search.typeText("beats")
        XCTAssertTrue(app.staticTexts["Yesterday, in two beats"]
            .waitForExistence(timeout: 10),
                      "scoped search must find the Developing lesson: \(app.debugDescription)")
        XCTAssertFalse(app.staticTexts["Mission : un café à Paris"].exists,
                       "scoped search must not surface Foundation lessons")
    }
}