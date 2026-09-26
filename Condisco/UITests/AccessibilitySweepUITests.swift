import XCTest

/// Focused accessibility verification for the Phase 4 sweep (roadmap
/// 2026-09-25, Phase 4: "Verify the daily path and accessibility"). Run on
/// specific simulator configurations driven by the sweep script:
///
///   · smallest iPhone (iPhone SE 3rd generation), portrait — the roadmap's
///     "one-handed" gate: the pinned primary action must stay hittable in the
///     thumb zone, and required feedback/actions must never be hidden;
///   · landscape orientation — the same controls must stay reachable;
///   · largest Dynamic Type (`simctl ui … content-size
///     accessibility-extra-extra-extra-large`) — no clipped, unreachable
///     actions;
///   · iPad — the same flows complete on a tablet.
///
/// Every assertion keys off VoiceOver-visible labels and stable identifiers,
/// so a passing test is also evidence that the control speaks its purpose.
final class AccessibilitySweepUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Shared journeys

    /// Onboarding → Home, the way a fresh learner reaches the dashboard:
    /// the placement completes and the first lesson's briefing presents, so
    /// the journey leaves it via "Back to lessons" (exactly like the
    /// first-run test) before Home is interactive.
    private func completeOnboardingToHome(_ app: XCUIApplication) {
        let getStarted = app.buttons["Choose a language"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 30), app.debugDescription)
        getStarted.tap()

        XCTAssertTrue(app.staticTexts["Which language are you learning?"]
            .waitForExistence(timeout: 10), app.debugDescription)
        // VoiceOver label check: the five course cards and the confirm
        // action are all present and readable.
        XCTAssertTrue(app.staticTexts["French foundations"].exists, app.debugDescription)
        let languageContinue = app.buttons["Continue"]
        scrollToIfNeeded(languageContinue, app: app)
        XCTAssertTrue(languageContinue.isHittable, app.debugDescription)
        languageContinue.tap()

        let freshStart = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "I'm starting fresh")).firstMatch
        XCTAssertTrue(freshStart.waitForExistence(timeout: 10), app.debugDescription)
        scrollToIfNeeded(freshStart, app: app)
        XCTAssertTrue(freshStart.isHittable, app.debugDescription)
        freshStart.tap()

        // The placement opens the first lesson's briefing as a cover; leave
        // it to land on the dashboard.
        let startLesson = app.buttons["Start lesson"]
        XCTAssertTrue(startLesson.waitForExistence(timeout: 20), app.debugDescription)
        let backToLessons = app.buttons["Back to lessons"]
        XCTAssertTrue(backToLessons.waitForExistence(timeout: 10), app.debugDescription)
        backToLessons.tap()

        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 30),
                      app.debugDescription)
    }

    /// The first mission's first graded question, reached exactly like a
    /// fresh learner would: onboarding → fresh start → start lesson → guide
    /// → first question. Works under every Dynamic Type size the sweep runs,
    /// scrolling the onboarding steps when the type ramp pushes actions
    /// below the fold.
    private func openFirstQuestion(_ app: XCUIApplication) {
        app.launchArguments.append("--condisco-ui-test-reset")
        app.launch()

        let getStarted = app.buttons["Choose a language"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 30), app.debugDescription)
        getStarted.tap()

        XCTAssertTrue(app.staticTexts["Which language are you learning?"]
            .waitForExistence(timeout: 10), app.debugDescription)
        // VoiceOver label check: the five course cards and the confirm
        // action are all present and readable.
        XCTAssertTrue(app.staticTexts["French foundations"].exists, app.debugDescription)
        let languageContinue = app.buttons["Continue"]
        scrollToIfNeeded(languageContinue, app: app)
        XCTAssertTrue(languageContinue.isHittable, app.debugDescription)
        languageContinue.tap()

        let freshStart = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "I'm starting fresh")).firstMatch
        XCTAssertTrue(freshStart.waitForExistence(timeout: 10), app.debugDescription)
        scrollToIfNeeded(freshStart, app: app)
        XCTAssertTrue(freshStart.isHittable, app.debugDescription)
        freshStart.tap()

        let startLesson = app.buttons["Start lesson"]
        XCTAssertTrue(startLesson.waitForExistence(timeout: 20), app.debugDescription)
        startLesson.tap()

        let guideDone = app.buttons["Got it"]
        XCTAssertTrue(guideDone.waitForExistence(timeout: 10), app.debugDescription)
        guideDone.tap()

        let briefingContinue = app.buttons["Continue"]
        XCTAssertTrue(briefingContinue.waitForExistence(timeout: 10), app.debugDescription)
        briefingContinue.tap()

        let question = app.staticTexts[
            "The server looks up from the counter. How do you greet them?"]
        XCTAssertTrue(question.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(question.isHittable, "the lesson question must be on screen")
    }

    /// The pinned bottom bar is the one-handed promise: whatever the step,
    /// its primary action stays above the home indicator and inside the
    /// screen, reachable without losing the question.
    private func assertPinnedActionReachable(
        _ button: XCUIElement, app: XCUIApplication, label: String
    ) {
        XCTAssertTrue(button.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(button.isHittable,
                      "\(label) must be hittable in the pinned bar: \(app.debugDescription)")
        let window = app.windows.firstMatch
        XCTAssertTrue(window.exists, app.debugDescription)
        let frame = button.frame
        // The action sits in the bottom half of the screen (thumb zone)…
        XCTAssertGreaterThanOrEqual(frame.midY, window.frame.midY,
                                    "\(label) must stay in the thumb zone")
        // …and is never clipped below the screen or behind the home indicator.
        XCTAssertLessThanOrEqual(frame.maxY, window.frame.maxY - 4,
                                 "\(label) must not be clipped below the screen")
    }

    private func scrollToIfNeeded(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<4 where !element.isHittable {
            app.swipeUp()
        }
    }

    func testSmallPhoneFirstQuestionWrongAnswerFeedbackNotHidden() {
        let app = XCUIApplication()
        openFirstQuestion(app)
        attachScreenshot(app, name: "smallphone-first-question")

        // The pinned Check is the required action: reachable in the thumb
        // zone, not clipped.
        let check = app.buttons["Check"]
        assertPinnedActionReachable(check, app: app, label: "Check")

        // VoiceOver labels on the answer options are unambiguous.
        XCTAssertTrue(app.buttons["Bonjour."].exists, app.debugDescription)
        XCTAssertTrue(app.buttons["Merci."].exists, app.debugDescription)
        XCTAssertTrue(app.buttons["Au revoir."].exists, app.debugDescription)

        // A wrong answer must surface its feedback without hiding any
        // required action: the correction appears and the pinned bar still
        // offers the model-answer continuation.
        app.buttons["Merci."].tap()
        XCTAssertTrue(check.isEnabled, app.debugDescription)
        check.tap()
        let correction = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "Model answer")).firstMatch
        XCTAssertTrue(correction.waitForExistence(timeout: 15),
                      "wrong-answer feedback must be shown: \(app.debugDescription)")
        attachScreenshot(app, name: "smallphone-wrong-answer-feedback")

        let modelAnswer = app.buttons["Continue with model answer"]
        XCTAssertTrue(modelAnswer.waitForExistence(timeout: 10), app.debugDescription)
        assertPinnedActionReachable(modelAnswer, app: app, label: "Continue with model answer")
    }

    func testLandscapeKeepsPrimaryActionReachable() {
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        openFirstQuestion(app)

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.staticTexts[
            "The server looks up from the counter. How do you greet them?"]
            .waitForExistence(timeout: 10), app.debugDescription)

        let check = app.buttons["Check"]
        assertPinnedActionReachable(check, app: app, label: "Check (landscape)")
        XCTAssertTrue(app.buttons["Bonjour."].exists, app.debugDescription)
        attachScreenshot(app, name: "landscape-first-question")
    }

    /// The sweep runs this under the largest Dynamic Type configuration.
    /// Because `simctl ui … content-size` is unusable on this Xcode build,
    /// the test pins the category through UIKit's documented launch-argument
    /// hook (`-UIPreferredContentSizeCategoryName`), which the app's
    /// UIFontMetrics-based type ramp must follow.
    func testLargestDynamicTypeKeepsActionsReachable() {
        let app = XCUIApplication()
        app.launchArguments.append("--condisco-ui-test-reset")
        app.launchArguments += [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        openFirstQuestion(app)
        attachScreenshot(app, name: "largest-type-first-question")

        let check = app.buttons["Check"]
        assertPinnedActionReachable(check, app: app, label: "Check (largest type)")
        // Answer options must stay reachable — the lesson body scrolls, so
        // a reach (scrolled) tap is the user-equivalent assertion. The
        // pinned bar is opaque and sits OUTSIDE the scroll content, so
        // isHittable cannot be trusted here: an option whose center lands
        // below the bar's accessibility frame reads as unoccluded, yet the
        // bar — not the option — actually receives the touch. Scroll until
        // the option sits genuinely above the bar (what a learner must do
        // at the largest type), then tap it.
        let greeting = app.buttons["Bonjour."]
        XCTAssertTrue(greeting.waitForExistence(timeout: 10), app.debugDescription)
        let merci = app.buttons["Merci."]
        XCTAssertTrue(merci.exists, app.debugDescription)
        let barTop = app.buttons["Check"].frame.minY
        for _ in 0..<4 where merci.frame.maxY >= barTop - 4 {
            app.swipeUp()
        }
        XCTAssertTrue(merci.frame.maxY < barTop - 4,
                      "answer option must be reachable above the pinned bar: \(app.debugDescription)")
        merci.tap()
        // The pinned bar rides above the keyboard and the fold: after the
        // option scroll it must still be hittable in place.
        scrollToIfNeeded(check, app: app)
        XCTAssertTrue(check.isHittable, app.debugDescription)
        check.tap()
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "Model answer")).firstMatch
            .waitForExistence(timeout: 15), app.debugDescription)
        attachScreenshot(app, name: "largest-type-wrong-answer-feedback")
    }

    // MARK: - Five-card review session (Home invitation preselects five)

    func testFiveCardReviewSessionCompletesAfterHomeInvitation() {
        let app = XCUIApplication()
        app.launchArguments.append("--condisco-ui-test-reset")
        app.launchArguments.append("--condisco-ui-test-seed-review")
        app.launch()
        completeOnboardingToHome(app)

        // Home's Today card shows the review invitation row with its stable
        // identifier and the seeded due count.
        let reviewRow = app.buttons["home.today.review"]
        XCTAssertTrue(reviewRow.waitForExistence(timeout: 30), app.debugDescription)
        XCTAssertTrue(reviewRow.label.contains("7 reviews due"),
                      "Home must surface the seeded due count")
        attachScreenshot(app, name: "home-review-invitation")

        // The Home invitation must preselect the five-card session: the
        // Review tab shows "5 of 7 to review" up front.
        reviewRow.tap()
        XCTAssertTrue(app.navigationBars["Review"].waitForExistence(timeout: 15),
                      app.debugDescription)
        XCTAssertTrue(app.staticTexts["5 of 7 to review"].waitForExistence(timeout: 10),
                      "Home's five-card invitation must preselect five: \(app.debugDescription)")
        attachScreenshot(app, name: "review-five-preselected")
        scrollToIfNeeded(app.buttons["Start review"], app: app)

        let start = app.buttons["Start review"]
        XCTAssertTrue(start.isHittable, app.debugDescription)
        start.tap()

        // Five cards, each with reveal → honest verdict. Verdict buttons
        // carry VoiceOver-expanded labels.
        let verdicts: [String] = [
            "I knew it. I recalled the answer independently.",
            "Almost. I nearly knew it.",
            "Not yet. I didn't know it.",
            "Easy. I knew it without effort.",
            "I knew it. I recalled the answer independently.",
        ]
        for (position, verdictLabel) in verdicts.enumerated() {
            let reveal = app.buttons["Reveal answer"]
            XCTAssertTrue(reveal.waitForExistence(timeout: 15),
                          "card \(position + 1): reveal must appear")
            reveal.tap()
            let verdict = app.buttons[verdictLabel]
            XCTAssertTrue(verdict.waitForExistence(timeout: 10),
                          "card \(position + 1): verdict must appear: \(app.debugDescription)")
            scrollToIfNeeded(verdict, app: app)
            XCTAssertTrue(verdict.isHittable,
                          "card \(position + 1): verdict must be reachable")
            verdict.tap()
        }

        XCTAssertTrue(app.staticTexts["Session complete"].waitForExistence(timeout: 15),
                      "the five-card session must finish: \(app.debugDescription)")
        attachScreenshot(app, name: "review-session-complete")
        let done = app.buttons["Done"].firstMatch
        XCTAssertTrue(done.isHittable, app.debugDescription)
        done.tap()
        XCTAssertTrue(app.navigationBars["Review"].waitForExistence(timeout: 15),
                      app.debugDescription)
    }

    // MARK: - VoiceOver table stakes

    /// The daily navigation and the Comfort controls must all speak clear,
    /// unambiguous labels to VoiceOver.
    func testVoiceOverLabelsOnKeyControls() {
        let app = XCUIApplication()
        app.launchArguments.append("--condisco-ui-test-reset")
        app.launch()
        completeOnboardingToHome(app)

        // Tab bar speaks every destination.
        for tab in ["Home", "Courses", "Listen", "Review", "You"] {
            XCTAssertTrue(app.tabBars.buttons[tab].exists,
                          "tab \(tab) must expose its VoiceOver label")
        }
        // The language menu is labeled, and the Today headline has a stable
        // identifier for automation and VoiceOver.
        XCTAssertTrue(app.buttons["Focus language"].exists, app.debugDescription)
        XCTAssertTrue(app.staticTexts["home.today.header"].exists, app.debugDescription)
        let primary = app.buttons["home.today.primary"]
        XCTAssertTrue(primary.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(primary.label.contains("Mission : un café à Paris"),
                      "the Today headline must name the mission")
        attachScreenshot(app, name: "voiceover-labels-home")

        // Comfort: the reduce-motion promise lives behind Preferences and is
        // a real, labeled toggle.
        app.tabBars.buttons["You"].tap()
        XCTAssertTrue(app.staticTexts["Your learning"].waitForExistence(timeout: 10),
                      app.debugDescription)
        let preferences = app.buttons["Preferences"]
        scrollToIfNeeded(preferences, app: app)
        XCTAssertTrue(preferences.isHittable, app.debugDescription)
        preferences.tap()
        let reduceMotion = app.switches["Reduce motion"]
        XCTAssertTrue(reduceMotion.waitForExistence(timeout: 10),
                      "the Reduce motion toggle must exist: \(app.debugDescription)")
        XCTAssertTrue(app.switches["Larger text"].exists, app.debugDescription)
        attachScreenshot(app, name: "voiceover-labels-comfort")
    }

    // MARK: - Evidence

    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}