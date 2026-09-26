import XCTest
@testable import Condisco

// MARK: - AnswerEngine

/// Deterministic text grading: exact match, tolerance, alternatives,
/// authored errors, and the bounded typo forgiveness. Accent-correction
/// feedback paths are covered by PlacementTests; these focus on the
/// grading decisions themselves.
final class AnswerEngineTests: XCTestCase {

    /// The real spec behind `fr-home-foundation-act-rb6`.
    private var spec: AnswerSpec {
        AnswerSpec(
            answers: ["Le chat est sur le livre.", "Le chat est sur le livre !"],
            allowTypo: true,
            errors: [])
    }

    func testExactMatchGivesFullCredit() {
        let result = AnswerEngine.evaluate(
            response: "Le chat est sur le livre.", spec: spec)
        XCTAssertTrue(result.accepted)
        XCTAssertEqual(result.credit, .full)
        XCTAssertEqual(result.category, "correct")
        XCTAssertEqual(result.model, "Le chat est sur le livre.")
    }

    func testCaseAndPunctuationAndWhitespaceTolerance() {
        // Uppercase, stray punctuation, collapsed double spaces: the
        // normalized forms agree, so this is full credit — not a typo.
        let result = AnswerEngine.evaluate(
            response: "  LE CHAT EST SUR LE  LIVRE ! ", spec: spec)
        XCTAssertTrue(result.accepted)
        XCTAssertEqual(result.credit, .full)
        XCTAssertEqual(result.category, "correct")
    }

    func testAcceptedAlternativeTagsSecondForm() {
        // Answers[1] normalizes to the same string as answers[0], so it
        // matches index 0 first — craft a spec whose forms differ to hit
        // the "acceptable alternative" branch.
        let alt = AnswerSpec(
            answers: ["Café, s'il vous plaît.", "Un café, s'il vous plaît."],
            allowTypo: true,
            errors: [])
        let result = AnswerEngine.evaluate(
            response: "Un café, s'il vous plaît.", spec: alt)
        XCTAssertTrue(result.accepted)
        XCTAssertEqual(result.credit, .full)
        XCTAssertEqual(result.category, "acceptable alternative")
        XCTAssertEqual(result.model, "Café, s'il vous plaît.")
    }

    func testAuthoredErrorHitsCategoryAndExplains() {
        let spec = AnswerSpec(
            answers: ["Tu es Marc."],
            allowTypo: true,
            errors: [
                AuthoredError(
                    answer: "Tu est Marc.",
                    category: .wrongConjugation,
                    explanation: "Use es with tu."),
            ])
        let result = AnswerEngine.evaluate(response: "Tu est Marc.", spec: spec)
        XCTAssertFalse(result.accepted)
        XCTAssertEqual(result.credit, .none)
        XCTAssertEqual(result.category, "wrong conjugation")
        XCTAssertTrue(result.explanation.contains("es"))
        XCTAssertEqual(result.correction, nil)
    }

    func testTypoAcceptedAsPartialCreditWhenAllowed() {
        let result = AnswerEngine.evaluate(
            response: "Le chat est sur le livrre.", spec: spec)
        XCTAssertTrue(result.accepted)
        XCTAssertEqual(result.credit, .partial)
        XCTAssertEqual(result.category, "correct with typo")
        XCTAssertEqual(result.correction, "Le chat est sur le livre.")
    }

    func testTypoRejectedWhenStrict() {
        let strict = AnswerSpec(
            answers: ["Le chat est sur le livre."],
            allowTypo: false,
            errors: [])
        let result = AnswerEngine.evaluate(
            response: "Le chat est sur le livrre.", spec: strict)
        XCTAssertFalse(result.accepted)
        XCTAssertEqual(result.credit, .none)
        XCTAssertEqual(result.category, "nearly correct")
    }

    func testWordOrderProblemDetected() {
        let result = AnswerEngine.evaluate(
            response: "Le chat sur le est livre.", spec: spec)
        XCTAssertFalse(result.accepted)
        XCTAssertEqual(result.category, "word-order problem")
    }

    func testMissingWordDetected() {
        let result = AnswerEngine.evaluate(
            response: "chat est sur le livre", spec: spec)
        XCTAssertFalse(result.accepted)
        XCTAssertEqual(result.category, "missing word")
    }

    func testExtraWordDetected() {
        let result = AnswerEngine.evaluate(
            response: "Le gros chat est sur le livre", spec: spec)
        XCTAssertFalse(result.accepted)
        XCTAssertEqual(result.category, "extra word")
    }

    func testWrongAnswerRejected() {
        let result = AnswerEngine.evaluate(
            response: "Bonjour madame.", spec: spec)
        XCTAssertFalse(result.accepted)
        XCTAssertEqual(result.credit, .none)
        XCTAssertEqual(result.category, "incorrect answer")
    }

    func testBlankAndOverlongResponsesRejected() {
        let blank = AnswerEngine.evaluate(response: "   ", spec: spec)
        XCTAssertFalse(blank.accepted)
        XCTAssertEqual(blank.category, "incorrect answer")

        let long = AnswerEngine.evaluate(
            response: String(repeating: "a", count: 1001), spec: spec)
        XCTAssertFalse(long.accepted)
        XCTAssertEqual(long.category, "incorrect answer")
    }

    func testNormalizePrimitives() {
        let n = AnswerEngine.normalize("  Café,  s'il  vous  plaît ! ")
        XCTAssertEqual(n, "café s'il vous plaît")
        XCTAssertEqual(AnswerEngine.unaccent("café"), "cafe")
        XCTAssertEqual(AnswerEngine.unaccent("s'il"), "s'il")
    }

    func testBoundedEditDistance() {
        XCTAssertEqual(AnswerEngine.distance("kitten", "kitten"), 0)
        XCTAssertEqual(AnswerEngine.distance("kitten", "sitten"), 1)
        // Adjacent transposition counts as a single edit.
        XCTAssertEqual(AnswerEngine.distance("abcd", "abdc"), 1)
        XCTAssertEqual(AnswerEngine.distance("livre", "livrre"), 1)
        // Length mismatch beyond the bound saturates at 3.
        XCTAssertEqual(AnswerEngine.distance("ab", "abcde"), 3)
    }
}

// MARK: - ActivityEvaluation

/// Typed evaluation over the different activity kinds, using real bundled
/// activities so the exercised shapes match production data.
final class ActivityEvaluationTests: XCTestCase {

    private func frenchPack() throws -> CoursePack {
        try XCTUnwrap(
            PackLoader.loadPacks().first { $0.language == .french })
    }

    private func activity(_ id: String, in pack: CoursePack) throws -> Activity {
        try XCTUnwrap(pack.activity(id: id), "missing activity \(id)")
    }

    // MARK: Selection

    func testSelectionCorrectAndIncorrect() throws {
        let pack = try frenchPack()
        let activity = try activity("fr-home-foundation-act-rb2", in: pack)

        let good = ActivityEvaluation.evaluate(
            activity: activity, response: .selection(ids: ["o1"]), assistance: [])
        XCTAssertEqual(good.outcome, .correct)
        XCTAssertTrue(good.independent)

        let wrong = ActivityEvaluation.evaluate(
            activity: activity, response: .selection(ids: ["o2"]), assistance: [])
        XCTAssertEqual(wrong.outcome, .incorrect)
        XCTAssertFalse(wrong.independent)
    }

    func testSelectionRejectsMalformedSelections() throws {
        let pack = try frenchPack()
        let activity = try activity("fr-home-foundation-act-rb2", in: pack)

        // Single-select must pick exactly one option.
        let tooMany = ActivityEvaluation.evaluate(
            activity: activity,
            response: .selection(ids: ["o1", "o2"]), assistance: [])
        XCTAssertEqual(tooMany.outcome, .incorrect)

        // Unknown option ids are invalid, not just wrong.
        let unknown = ActivityEvaluation.evaluate(
            activity: activity, response: .selection(ids: ["o99"]), assistance: [])
        XCTAssertEqual(unknown.outcome, .incorrect)
    }

    func testAssistanceTaintsOnlyPerActivityKinds() throws {
        let pack = try frenchPack()
        let activity = try activity("fr-home-foundation-act-rb2", in: pack)
        let response = AttemptResponse.selection(ids: ["o1"])

        // `hint` is in this activity's assistanceAffectsEvidence: tainted.
        let hinted = ActivityEvaluation.evaluate(
            activity: activity, response: response, assistance: [.hint])
        XCTAssertEqual(hinted.outcome, .correct)
        XCTAssertFalse(hinted.independent)

        // `translation` is not listed and is not the model reveal: clean.
        let translated = ActivityEvaluation.evaluate(
            activity: activity, response: response, assistance: [.translation])
        XCTAssertEqual(translated.outcome, .correct)
        XCTAssertTrue(translated.independent)

        // The model reveal always taints, everywhere.
        let modeled = ActivityEvaluation.evaluate(
            activity: activity, response: response, assistance: [.model])
        XCTAssertEqual(modeled.outcome, .correct)
        XCTAssertFalse(modeled.independent)
    }

    // MARK: Text

    func testTextActivityGrading() throws {
        let pack = try frenchPack()
        let activity = try activity("fr-home-foundation-act-rb6", in: pack)

        let good = ActivityEvaluation.evaluate(
            activity: activity,
            response: .text("Le chat est sur le livre."), assistance: [])
        XCTAssertEqual(good.outcome, .correct)
        XCTAssertTrue(good.independent)

        let bad = ActivityEvaluation.evaluate(
            activity: activity, response: .text("Bonjour."), assistance: [])
        XCTAssertEqual(bad.outcome, .incorrect)
    }

    // MARK: Cloze

    func testClozeAllOrNothingGrading() throws {
        let pack = try frenchPack()
        let activity = try activity("fr-home-foundation-cloze", in: pack)

        let good = ActivityEvaluation.evaluate(
            activity: activity,
            response: .cloze(values: ["b1": "Le"]), assistance: [])
        XCTAssertEqual(good.outcome, .correct)
        XCTAssertTrue(good.independent)

        // One failing blank fails the whole cloze.
        let bad = ActivityEvaluation.evaluate(
            activity: activity,
            response: .cloze(values: ["b1": "La"]), assistance: [])
        XCTAssertEqual(bad.outcome, .incorrect)
        XCTAssertFalse(bad.independent)
    }

    // MARK: Ordering

    func testOrderingEvaluation() throws {
        let pack = try frenchPack()
        let activity = try activity("fr-cafe-mission-act-4", in: pack)

        let good = ActivityEvaluation.evaluate(
            activity: activity,
            response: .ordering(ids: ["t2", "t3", "t1"]), assistance: [])
        XCTAssertEqual(good.outcome, .correct)

        let wrongOrder = ActivityEvaluation.evaluate(
            activity: activity,
            response: .ordering(ids: ["t1", "t2", "t3"]), assistance: [])
        XCTAssertEqual(wrongOrder.outcome, .incorrect)

        // Dropping a token is structurally invalid, not a near miss.
        let incomplete = ActivityEvaluation.evaluate(
            activity: activity,
            response: .ordering(ids: ["t2", "t3"]), assistance: [])
        XCTAssertEqual(incomplete.outcome, .incorrect)
    }

    // MARK: Matching

    func testMatchingEvaluation() throws {
        let pack = try frenchPack()
        let activity = try activity("fr-cafe-mission-act-8", in: pack)
        guard case .matching(let spec) = activity else {
            return XCTFail("expected a matching activity")
        }

        // Build the correct response from the spec's accepted pairs.
        let correctPairs = spec.acceptedPairs.map {
            ResponsePair(leftId: $0.leftId, rightId: $0.rightId)
        }
        let good = ActivityEvaluation.evaluate(
            activity: activity,
            response: .matching(pairs: correctPairs), assistance: [])
        XCTAssertEqual(good.outcome, .correct)
        XCTAssertTrue(good.independent)

        // A rotated pair set is a valid-but-wrong matching.
        var wrongPairs = correctPairs
        let firstRight = wrongPairs[0].rightId
        wrongPairs[0].rightId = wrongPairs[1].rightId
        wrongPairs[1].rightId = firstRight
        let wrong = ActivityEvaluation.evaluate(
            activity: activity,
            response: .matching(pairs: wrongPairs), assistance: [])
        XCTAssertEqual(wrong.outcome, .incorrect)
    }

    // MARK: Information

    func testInformationActivityRequiresContinue() throws {
        let pack = try frenchPack()
        let activity = try activity("fr-home-foundation-act-rb1", in: pack)

        let ok = ActivityEvaluation.evaluate(
            activity: activity, response: .continue, assistance: [])
        XCTAssertEqual(ok.outcome, .ungraded)

        let wrongKind = ActivityEvaluation.evaluate(
            activity: activity, response: .text("salut"), assistance: [])
        XCTAssertEqual(wrongKind.outcome, .incorrect)
    }

    // MARK: Draft validation

    func testValidDraftHelper() {
        XCTAssertFalse(validDraft(nil))
        XCTAssertFalse(validDraft(.text("   ")))
        XCTAssertTrue(validDraft(.text("oui")))
        XCTAssertFalse(validDraft(.selection(ids: [])))
        XCTAssertTrue(validDraft(.selection(ids: ["o1"])))
        XCTAssertFalse(validDraft(.matching(pairs: [])))
        XCTAssertFalse(validDraft(.cloze(values: ["b1": " ", "b2": ""])))
        XCTAssertTrue(validDraft(.cloze(values: ["b1": "Le", "b2": ""])))
        XCTAssertTrue(validDraft(.continue))
    }

    func testHintTextForClozeUsesFirstAnswerLetter() throws {
        let pack = try frenchPack()
        let cloze = try activity("fr-home-foundation-cloze", in: pack)
        XCTAssertEqual(hintText(for: cloze), "L")
        let selection = try activity("fr-home-foundation-act-rb2", in: pack)
        XCTAssertEqual(hintText(for: selection), "Try it")
    }
}

// MARK: - LessonSession

/// Session state machine over a real linear lesson: start → submit →
/// evaluate → advance, plus the guard-rail errors.
final class LessonSessionTests: XCTestCase {

    private func frenchPack() throws -> CoursePack {
        try XCTUnwrap(
            PackLoader.loadPacks().first { $0.language == .french })
    }

    /// The lesson PlacementTests and the store tests also lean on —
    /// linear, no branches, one of every constructible kind.
    private let lessonId = "fr-home-foundation"

    /// A response the activity accepts, used to drive a clean run.
    private func correctResponse(for activity: Activity) -> AttemptResponse {
        switch activity {
        case .information:
            return .continue
        case .selection(let spec):
            return .selection(ids: spec.acceptedIds)
        case .cloze(let spec):
            return .cloze(values: Dictionary(
                uniqueKeysWithValues: spec.blanks.map { ($0.key, $0.value.answers.first ?? "") }))
        case .text(let spec):
            return .text(spec.answer.answers.first ?? "")
        default:
            XCTFail("unexpected activity kind in lesson: \(activity.id)")
            return .continue
        }
    }

    func testStartLessonHappyPathRunsToCompletion() throws {
        let pack = try frenchPack()
        let lesson = try XCTUnwrap(pack.lesson(id: lessonId))

        var session = try startLesson(pack: pack, lessonId: lesson.id)
        XCTAssertEqual(session.status, .active)
        XCTAssertEqual(session.activeStepId, lesson.entryStepId)
        XCTAssertEqual(session.visitedStepIds, [lesson.entryStepId])
        XCTAssertTrue(session.completedStepIds.isEmpty)

        var iterations = 0
        while session.status == .active {
            iterations += 1
            XCTAssertLessThan(iterations, 50, "lesson did not terminate")
            let step = try XCTUnwrap(
                lesson.steps.first { $0.id == session.activeStepId })
            let activity = try XCTUnwrap(pack.activity(id: step.activityId))
            let expectedOutcome: AttemptEvaluation.Outcome =
                activity.base == nil ? .ungraded : .correct

            let stepBefore = session.activeStepId
            let completedBefore = session.completedStepIds
            session = try submitResponse(
                pack: pack, session: session,
                response: correctResponse(for: activity), assistance: [])
            XCTAssertEqual(session.currentEvaluation?.outcome, expectedOutcome)
            XCTAssertTrue(
                session.completedStepIds.contains(stepBefore),
                "completedStepIds must gain \(stepBefore)")
            XCTAssertNotEqual(session.completedStepIds, completedBefore)

            session = try advanceLesson(pack: pack, session: session)
            if session.status == .active {
                XCTAssertNotEqual(
                    session.activeStepId, stepBefore,
                    "advance must move to a new step")
                XCTAssertTrue(session.visitedStepIds.contains(session.activeStepId))
            }
        }

        XCTAssertEqual(session.status, .complete)
        XCTAssertEqual(
            Set(session.completedStepIds), Set(lesson.steps.map(\.id)),
            "every step in the lesson must be completed")
    }

    func testAdvanceWithoutEvaluationThrows() throws {
        let pack = try frenchPack()
        let session = try startLesson(pack: pack, lessonId: lessonId)
        XCTAssertThrowsError(try advanceLesson(pack: pack, session: session)) { error in
            guard case LessonSessionError.noEvaluation = error else {
                return XCTFail("expected noEvaluation, got \(error)")
            }
        }
    }

    func testAdvanceOnIncompleteStepThrows() throws {
        let pack = try frenchPack()
        var session = try startLesson(pack: pack, lessonId: lessonId)
        // Move to the first practice step (rb2, a selection).
        session = try submitResponse(
            pack: pack, session: session, response: .continue, assistance: [])
        session = try advanceLesson(pack: pack, session: session)

        // Now submit a wrong answer: the step completes only on acceptance.
        session = try submitResponse(
            pack: pack, session: session,
            response: .selection(ids: ["o2"]), assistance: [])
        XCTAssertEqual(session.currentEvaluation?.outcome, .incorrect)
        XCTAssertThrowsError(try advanceLesson(pack: pack, session: session)) { error in
            guard case LessonSessionError.stepIncomplete = error else {
                return XCTFail("expected stepIncomplete, got \(error)")
            }
        }

        // A corrected answer then lets the lesson advance.
        session = try submitResponse(
            pack: pack, session: session,
            response: .selection(ids: ["o1"]), assistance: [])
        XCTAssertEqual(session.currentEvaluation?.outcome, .correct)
        let stepBefore = session.activeStepId
        session = try advanceLesson(pack: pack, session: session)
        XCTAssertNotEqual(session.activeStepId, stepBefore)
    }

    func testUnknownLessonThrows() throws {
        let pack = try frenchPack()
        XCTAssertThrowsError(try startLesson(pack: pack, lessonId: "no-such-lesson")) { error in
            guard case LessonSessionError.unknownLesson = error else {
                return XCTFail("expected unknownLesson, got \(error)")
            }
        }
    }

    func testOpenSupportThrowsWhenStepHasNoSupportActivity() throws {
        let pack = try frenchPack()
        // None of the bundled steps ship a support activity, so the
        // guaranteed outcome of opening support on the active step is the
        // `.noSupportActivity` guard error.
        let session = try startLesson(pack: pack, lessonId: lessonId)
        XCTAssertThrowsError(try openSupport(pack: pack, session: session)) { error in
            guard case LessonSessionError.noSupportActivity = error else {
                return XCTFail("expected noSupportActivity, got \(error)")
            }
        }
    }

    func testWalkTrailCoversLinearLesson() throws {
        let pack = try frenchPack()
        let lesson = try XCTUnwrap(pack.lesson(id: lessonId))
        // The home-foundation lesson is branch-free: the trail from the
        // entry step visits every step in authored order.
        let trail = walkTrail(lesson: lesson, selectedBranches: [:])
        XCTAssertEqual(trail, lesson.steps.map(\.id))
    }

    // MARK: Resume

    func testResumeRestartsOnRevisionMismatch() throws {
        let pack = try frenchPack()
        let lesson = try XCTUnwrap(pack.lesson(id: lessonId))
        let checkpoint = LessonCheckpoint(
            packId: pack.id, lessonId: lesson.id,
            revision: lesson.revision + 1, stepId: lesson.entryStepId,
            selectedBranches: [:], assistance: [], draft: nil, at: Date())
        let result = resumeSession(pack: pack, checkpoint: checkpoint, events: [])
        guard case .restart(let explanation) = result else {
            return XCTFail("expected restart on revision mismatch")
        }
        XCTAssertTrue(explanation.contains("revision"))
    }

    func testResumeRestartsOnMissingLesson() throws {
        let pack = try frenchPack()
        let checkpoint = LessonCheckpoint(
            packId: pack.id, lessonId: "no-such-lesson", revision: 1,
            stepId: "x", selectedBranches: [:], assistance: [], draft: nil,
            at: Date())
        let result = resumeSession(pack: pack, checkpoint: checkpoint, events: [])
        guard case .restart = result else {
            return XCTFail("expected restart for a missing lesson")
        }
    }
}

// MARK: - Next lesson: the shared path helper and its consumer surfaces

/// "What comes next on the learner's path" has one source of truth —
/// `CoursePack.firstUncompletedLesson(completed:)` — surfaced through the
/// shared `continueLessonResolution` function (focus-pack selection +
/// next-lesson), with three consumer surfaces: the Home continue card,
/// `condisco://continue`, and the widget snapshot. Every surface must
/// feed the helper the same completed set
/// (`PackProgress.participationCompleted`) so all three agree on the next
/// lesson. These tests pin the helper's ordering and orphan handling,
/// then prove Home, the widget, and the deep-link resolution agree on the
/// same completed set through the shared function.
@MainActor
final class NextLessonTests: XCTestCase {

    // MARK: Fixtures

    /// `u1`/`u2` are real units in the fixture; `ghost` deliberately has
    /// no matching `CourseUnit` — exactly the orphaned-lesson shape the
    /// helper is documented to skip.
    private let u1 = "u1"
    private let u2 = "u2"
    private let orphanUnit = "ghost"

    private func frenchPack() throws -> CoursePack {
        try XCTUnwrap(PackLoader.loadPacks().first { $0.language == .french })
    }

    /// Deterministic local pack, built in-test and decoded — never
    /// touches the bundled Content. Unit order comes from first
    /// appearance in `lessons` (the helper's documented rule), so the
    /// spec order controls the path.
    private func fixturePack(
        lessons: [(id: String, unitId: String)],
        language: String = "fr",
        id: String = "fixture-pack"
    ) throws -> CoursePack {
        let step: [String: Any] = [
            "id": "fixture-step", "purpose": "practice",
            "activityId": "fixture-activity", "required": true,
        ]
        let lessonDicts: [[String: Any]] = lessons.map { spec in
            [
                "id": spec.id,
                "unitId": spec.unitId,
                "title": spec.id,
                "objective": "objective",
                "family": "discovery",
                "revision": 1,
                "estimatedMinutes": 5,
                "entryStepId": "fixture-step",
                "steps": [step],
                "completionPolicy": ["kind": "participation"],
                "conceptIds": [],
                "vocabulary": [],
            ]
        }
        let packDict: [String: Any] = [
            "schemaVersion": 2,
            "id": id,
            "version": "1.0.0",
            "language": language,
            "status": "active",
            "title": "Fixture Pack",
            "sourceLanguage": "en",
            "description": "Next-lesson test fixture",
            "attribution": "",
            "units": [
                ["id": u1, "title": "Unit One", "objective": "objective"],
                ["id": u2, "title": "Unit Two", "objective": "objective"],
            ],
            "concepts": [],
            "vocabulary": [],
            "media": [],
            "stimuli": [],
            "activities": [],
            "lessons": lessonDicts,
            "dialogues": [],
        ]
        let data = try JSONSerialization.data(withJSONObject: packDict)
        return try JSONDecoder().decode(CoursePack.self, from: data)
    }

    /// Two lessons per real unit with an orphan interleaved mid-path:
    /// ties u2's order to u1 positionally via first appearance.
    private func fixturePackWithOrphan() throws -> CoursePack {
        try fixturePack(lessons: [
            (id: "l1", unitId: u1),
            (id: "l2", unitId: u1),
            (id: "orphan", unitId: orphanUnit), // no CourseUnit "ghost"
            (id: "l3", unitId: u2),
            (id: "l4", unitId: u2),
        ])
    }

    // MARK: The shared helper

    func testHelperReturnsFirstUncompletedInUnitOrder() throws {
        // Completed lessons are skipped, unit order follows first
        // appearance in `lessons` (u1 before u2), and the orphaned
        // lesson never surfaces.
        let pack = try fixturePackWithOrphan()

        let next = try XCTUnwrap(
            pack.firstUncompletedLesson(completed: ["l1", "l3"]),
            "l1 and l3 are done; l2 must be next")
        XCTAssertEqual(next.lesson.id, "l2")
        XCTAssertEqual(next.unit.id, u1)

        // Finish the first unit entirely: the path crosses into u2.
        let nextUnitTwo = try XCTUnwrap(
            pack.firstUncompletedLesson(completed: ["l1", "l2", "l3"]))
        XCTAssertEqual(nextUnitTwo.lesson.id, "l4")
        XCTAssertEqual(nextUnitTwo.unit.id, u2)
    }

    func testHelperReturnsNilWhenEveryLessonIsComplete() throws {
        let pack = try fixturePackWithOrphan()
        XCTAssertNil(pack.firstUncompletedLesson(
            completed: ["l1", "l2", "l3", "l4"]))

        // Real content too: the bundled French path fully walked.
        let real = try frenchPack()
        XCTAssertNil(real.firstUncompletedLesson(
            completed: Set(real.lessons.map(\.id))))
    }

    func testHelperSkipsOrphanedLessonAndStillFindsThePath() throws {
        // Orphan mid-path: skipped, next valid lesson returned.
        let pack = try fixturePack(lessons: [
            (id: "l1", unitId: u1),
            (id: "orphan", unitId: orphanUnit),
            (id: "l2", unitId: u2),
        ])
        let next = try XCTUnwrap(
            pack.firstUncompletedLesson(completed: ["l1"]))
        XCTAssertEqual(next.lesson.id, "l2", "orphan must be skipped, not returned")
        XCTAssertEqual(next.unit.id, u2)
    }

    func testHelperSkipsOrphanedLessonEvenWhenOnlyItRemains() throws {
        // The orphan is not part of the learner's path: with every real
        // lesson complete the helper is nil — the orphan must not
        // resurrect as "next".
        let mixed = try fixturePack(lessons: [
            (id: "orphan", unitId: orphanUnit),
            (id: "l1", unitId: u1),
        ])
        XCTAssertNil(mixed.firstUncompletedLesson(completed: ["l1"]))

        // An orphan-only pack has no path at all.
        let orphanOnly = try fixturePack(lessons: [
            (id: "orphan", unitId: orphanUnit),
        ])
        XCTAssertNil(orphanOnly.firstUncompletedLesson(completed: []))
    }

    func testRealFrenchPathOrderMatchesAuthoredOrder() throws {
        let pack = try frenchPack()
        let first = try XCTUnwrap(pack.lessons.first)
        // Sanity: the bundled pack is itself orphan-free, so the helper's
        // unit walk is the flat authored order.
        let unitIds = Set(pack.units.map(\.id))
        XCTAssertTrue(pack.lessons.allSatisfy { unitIds.contains($0.unitId) })

        let next = try XCTUnwrap(
            pack.firstUncompletedLesson(completed: [first.id]))
        XCTAssertEqual(next.lesson.id, pack.lessons[1].id)
        XCTAssertEqual(next.unit.id, first.unitId)
    }

    // MARK: Surfaces pass only participationCompleted

    /// The documented contract: every surface passes
    /// `PackProgress.participationCompleted`, NOT the wider
    /// `finishedLessons` view (walked + legacy credits + manual "I know
    /// this"). A lesson that is only legacy-known is finished for
    /// display but is not a walked path step, so it must still be
    /// offered as next. This pins the contract so a future switch to
    /// `finishedLessons` becomes a visible, deliberate change.
    func testHelperAndHomeOnlyCountParticipationCompleted() throws {
        let pack = try fixturePack(lessons: [
            (id: "l1", unitId: u1),
            (id: "l2", unitId: u1),
        ])
        // l1 is "finished" by the display view (manual know + legacy
        // credit) yet has NO participation completion.
        var progress = PackProgress()
        progress.knownLessons = ["l1"]
        progress.legacyCredits = ["l1"]
        XCTAssertTrue(progress.finishedLessons.contains("l1"))
        XCTAssertTrue(progress.participationCompleted.isEmpty)

        // The helper sees only participationCompleted: l1 is still next.
        XCTAssertEqual(
            pack.firstUncompletedLesson(completed: progress.participationCompleted)?.lesson.id,
            "l1")

        // Home delegates identically, so the continue card agrees.
        let home = HomeModel()
        home.progress = [pack.id: progress]
        XCTAssertEqual(
            home.nextLesson(in: pack)?.lesson.id, "l1",
            "a known/legacy lesson must still be offered as next")
    }

    // MARK: Cross-surface agreement — Home vs the shared helper

    func testHomeAndHelperAgreeAcrossProgressLevels() throws {
        let pack = try frenchPack()
        let ids = pack.lessons.map(\.id)
        let completedSets: [Set<String>] = [
            [],
            [ids[0]],
            Set(ids.prefix(ids.count - 1)),
            Set(ids),
        ]
        for completed in completedSets {
            let expected = pack.firstUncompletedLesson(completed: completed)
            let home = HomeModel()
            home.progress = [
                pack.id: PackProgress(participationCompleted: completed),
            ]
            let homeNext = home.nextLesson(in: pack)
            XCTAssertEqual(
                homeNext?.lesson.id, expected?.lesson.id,
                "Home must agree with the shared helper "
                + "(completed \(completed.count) of \(ids.count))")
        }
    }

    // MARK: Widget surface (pure snapshot assembly)

    func testWidgetSnapshotNextLessonMatchesHelper() throws {
        let pack = try fixturePackWithOrphan()
        let completed: Set<String> = ["l1", "l3"]
        let expected = try XCTUnwrap(
            pack.firstUncompletedLesson(completed: completed))

        let snapshot = WidgetSnapshotWriter.makeSnapshot(
            packs: [pack], focusSlug: "french",
            progress: [pack.id: PackProgress(participationCompleted: completed)],
            dueCount: 2, weekFlags: [], practiceDays: 3)

        XCTAssertEqual(snapshot.nextLessonId, expected.lesson.id)
        XCTAssertEqual(snapshot.nextLessonTitle, expected.lesson.title)
        XCTAssertEqual(snapshot.nextLessonUnit, expected.unit.title)
        XCTAssertEqual(snapshot.nextLessonMinutes, expected.lesson.estimatedMinutes)
        XCTAssertEqual(snapshot.nextPackId, pack.id)
        // The medium widget links the card into the matching lesson.
        XCTAssertEqual(
            WidgetShared.lessonURL(packId: pack.id, lessonId: expected.lesson.id),
            URL(string: "condisco://lesson/\(pack.id)/\(expected.lesson.id)"))
    }

    func testWidgetSnapshotPathCompleteWhenFullyCompleted() throws {
        let pack = try fixturePackWithOrphan()
        let snapshot = WidgetSnapshotWriter.makeSnapshot(
            packs: [pack], focusSlug: "french",
            progress: [pack.id: PackProgress(
                participationCompleted: ["l1", "l2", "l3", "l4"])],
            dueCount: 0, weekFlags: [], practiceDays: 0)
        // Nil next-lesson fields are exactly what drives the widget's
        // "Path complete" branch (CondiscoWidget medium view).
        XCTAssertNil(snapshot.nextLessonId)
        XCTAssertNil(snapshot.nextLessonTitle)
        XCTAssertNil(snapshot.nextPackId)
    }

    func testWidgetSnapshotSkipsOrphanedLessons() throws {
        // Orphan mid-path: the snapshot's next lesson is the helper's —
        // the orphaned unit is never offered.
        let mixed = try fixturePack(lessons: [
            (id: "l1", unitId: u1),
            (id: "orphan", unitId: orphanUnit),
            (id: "l2", unitId: u2),
        ])
        let mixedSnapshot = WidgetSnapshotWriter.makeSnapshot(
            packs: [mixed], focusSlug: "french",
            progress: [mixed.id: PackProgress(participationCompleted: ["l1"])],
            dueCount: 0, weekFlags: [], practiceDays: 0)
        XCTAssertEqual(mixedSnapshot.nextLessonId, "l2")

        // Orphan-only: no path, so the widget shows "Path complete".
        let orphanOnly = try fixturePack(lessons: [
            (id: "orphan", unitId: orphanUnit),
        ])
        let orphanSnapshot = WidgetSnapshotWriter.makeSnapshot(
            packs: [orphanOnly], focusSlug: "french",
            progress: [orphanOnly.id: PackProgress()],
            dueCount: 0, weekFlags: [], practiceDays: 0)
        XCTAssertNil(orphanSnapshot.nextLessonId)
        XCTAssertNil(orphanSnapshot.nextLessonTitle)
    }

    func testWidgetSnapshotUsesFocusPackSelectionLikeRefresh() throws {
        let packA = try fixturePack(lessons: [
            (id: "a1", unitId: u1), (id: "a2", unitId: u1),
        ], language: "it", id: "pack-a")
        let packB = try fixturePack(lessons: [
            (id: "b1", unitId: u1), (id: "b2", unitId: u1),
        ], language: "fr", id: "pack-b")
        var progress: [String: PackProgress] = [:]
        progress[packA.id] = PackProgress()
        progress[packB.id] = PackProgress()

        // Focus matches the second pack's slug → its path is next.
        let focused = WidgetSnapshotWriter.makeSnapshot(
            packs: [packA, packB], focusSlug: "french",
            progress: progress, dueCount: 0, weekFlags: [], practiceDays: 0)
        XCTAssertEqual(focused.nextLessonId, "b1")
        XCTAssertEqual(focused.focusLanguageName, "French")

        // No pack matches the slug → first pack wins (refresh semantics).
        let fallback = WidgetSnapshotWriter.makeSnapshot(
            packs: [packA, packB], focusSlug: "klingon",
            progress: progress, dueCount: 0, weekFlags: [], practiceDays: 0)
        XCTAssertEqual(fallback.nextLessonId, "a1")
        XCTAssertEqual(fallback.focusLanguageName, "Italian")
    }

    // MARK: Deep link surface

    func testContinueDeepLinkParsesToContinueRoute() {
        XCTAssertEqual(
            DeepLink(url: URL(string: "condisco://continue")!), .continue)
        XCTAssertEqual(
            DeepLink(url: URL(string: "condisco://lesson/\(u1)/l1")!),
            .lesson(packId: u1, lessonId: "l1"))
    }

    /// The deep-link surface runs through the extracted pure resolver:
    /// `continueLessonResolution` selects the focus pack and the next
    /// uncompleted lesson from `participationCompleted` — the exact
    /// function `DeepLinkRouter.resolve` calls after projecting the
    /// Documents store. Partial progress: each step of the path resolves
    /// in order, and a fresh pack (nothing completed) starts at the first
    /// lesson.
    func testContinueResolutionPartialPackProgress() throws {
        let pack = try fixturePack(lessons: [
            (id: "l1", unitId: u1),
            (id: "l2", unitId: u1),
            (id: "l3", unitId: u2),
        ])

        // Nothing completed: the very first lesson is next.
        let fresh = try XCTUnwrap(
            continueLessonResolution(
                packs: [pack], focusSlug: "french",
                completedByPack: [pack.id: []]))
        XCTAssertEqual(fresh.pack.id, pack.id)
        XCTAssertEqual(fresh.lesson.id, "l1")
        XCTAssertEqual(fresh.unit.id, u1)

        // One lesson done: the second of the first unit is next.
        let partial = try XCTUnwrap(
            continueLessonResolution(
                packs: [pack], focusSlug: "french",
                completedByPack: [pack.id: ["l1"]]))
        XCTAssertEqual(partial.lesson.id, "l2")

        // First unit done: the path crosses into u2.
        let nextUnit = try XCTUnwrap(
            continueLessonResolution(
                packs: [pack], focusSlug: "french",
                completedByPack: [pack.id: ["l1", "l2"]]))
        XCTAssertEqual(nextUnit.lesson.id, "l3")
        XCTAssertEqual(nextUnit.unit.id, u2)
    }

    /// Fully complete pack: nothing left on the path, so the resolution
    /// is nil — a deep link does nothing (best-effort), Home shows no
    /// lesson headline, and the widget renders "Path complete".
    func testContinueResolutionFullyCompletePackReturnsNil() throws {
        let pack = try fixturePackWithOrphan()
        XCTAssertNil(continueLessonResolution(
            packs: [pack], focusSlug: "french",
            completedByPack: [pack.id: ["l1", "l2", "l3", "l4"]]))

        // Real content too: the bundled French path fully walked.
        let real = try frenchPack()
        XCTAssertNil(continueLessonResolution(
            packs: [real], focusSlug: "french",
            completedByPack: [real.id: Set(real.lessons.map(\.id))]))
    }

    /// Orphaned progress: completed ids that don't exist in the pack mark
    /// no lesson (the learner's first lesson is still next), and a pack
    /// whose only lesson is orphaned has no path at all — nil either way,
    /// never a crash and never a bogus lesson.
    func testContinueResolutionOrphanedCompletedIdsAndOrphanOnlyPack() throws {
        let pack = try fixturePack(lessons: [
            (id: "l1", unitId: u1),
            (id: "l2", unitId: u1),
        ])
        XCTAssertEqual(
            continueLessonResolution(
                packs: [pack], focusSlug: "french",
                completedByPack: [pack.id: ["ghost-lesson"]])?.lesson.id,
            "l1",
            "completed ids outside the pack must not count as progress")

        let orphanOnly = try fixturePack(lessons: [
            (id: "orphan", unitId: orphanUnit),
        ])
        XCTAssertNil(continueLessonResolution(
            packs: [orphanOnly], focusSlug: "french",
            completedByPack: [orphanOnly.id: []]))
        // Even with the orphan's own id "completed": no valid path remains.
        XCTAssertNil(continueLessonResolution(
            packs: [orphanOnly], focusSlug: "french",
            completedByPack: [orphanOnly.id: ["orphan"]]))
    }

    /// Home, the widget, and the deep-link resolution must agree on the
    /// same completed set (`participationCompleted`) across every path
    /// shape: fresh, partial, fully complete, and orphaned completed ids.
    /// The deep link's choice is the shared function itself — this pins
    /// that Home and the widget derive from exactly the same call, so no
    /// surface can drift.
    func testHomeWidgetAndDeepLinkResolutionAgreeOnSameCompletedSet() throws {
        let pack = try fixturePackWithOrphan()
        let completedSets: [Set<String>] = [
            [],
            ["l1"],
            ["l1", "l3"],
            ["l1", "l2", "l3", "l4"], // path complete
            ["ghost"],                // completed id with no lesson
        ]
        for completed in completedSets {
            // Deep link surface: the shared resolver DeepLinkRouter calls.
            let deepLink = continueLessonResolution(
                packs: [pack], focusSlug: "french",
                completedByPack: [pack.id: completed])

            // Home surface: the Today card derives from the same function.
            let home = HomeModel()
            home.packs = [pack]
            home.progress = [pack.id: PackProgress(
                participationCompleted: completed)]
            let homeNext = home.continuationLesson(focusSlug: "french")

            // Widget surface: the snapshot's next-lesson fields.
            let snapshot = WidgetSnapshotWriter.makeSnapshot(
                packs: [pack], focusSlug: "french",
                progress: [pack.id: PackProgress(
                    participationCompleted: completed)],
                dueCount: 0, weekFlags: [], practiceDays: 0)

            XCTAssertEqual(
                homeNext?.lesson.id, deepLink?.lesson.id,
                "Home must agree with the deep-link resolution "
                + "(completed \(completed.sorted()))")
            XCTAssertEqual(
                snapshot.nextLessonId, deepLink?.lesson.id,
                "The widget must agree with the deep-link resolution "
                + "(completed \(completed.sorted()))")
        }
    }
}

// MARK: - Today plan

/// The Home "Today" card's precedence is a pure function:
/// resume > next lesson > review > listen > rest. These tests build
/// `TodayPlan.make` inputs directly — no view, no store — and pin every
/// branch, including that the plan still carries the due count and the
/// listen track when they are not the headline.
final class TodayPlanTests: XCTestCase {

    private func frenchPack() throws -> CoursePack {
        try XCTUnwrap(
            PackLoader.loadPacks().first { $0.language == .french })
    }

    private func listenTrack(lessonId: String = "fr-foundations") -> ListenTrack {
        ListenTrack(
            lessonId: lessonId,
            courseSlug: "french",
            lessonTitle: "Foundations track",
            audioUrl: "audio/fr-foundations.mp3",
            durationS: 617,
            reviewPending: nil,
            sections: [])
    }

    func testResumeWinsOverLessonAndReviewsStillCarriesDueCount() throws {
        let pack = try frenchPack()
        let lesson = try XCTUnwrap(pack.lessons.first)
        let resume = ResumeInfo(pack: pack, lesson: lesson, stepIndex: 1)
        let next = try XCTUnwrap(pack.firstUncompletedLesson(completed: []))

        let plan = TodayPlan.make(
            resume: resume,
            nextLesson: next,
            dueCount: 3,
            nextDueAt: Date().addingTimeInterval(3600),
            listen: listenTrack())

        guard case .resume(let chosen) = plan.primary else {
            return XCTFail("expected .resume, got \(plan.primary)")
        }
        XCTAssertEqual(chosen.lesson.id, lesson.id)
        XCTAssertEqual(chosen.stepIndex, 1)
        // The plan still carries the review load for the secondary row.
        XCTAssertEqual(plan.dueCount, 3)
        XCTAssertNotNil(plan.nextDueAt)
    }

    func testNoResumeThenNextLessonWinsOverDueReviews() throws {
        let pack = try frenchPack()
        let next = try XCTUnwrap(pack.firstUncompletedLesson(completed: []))

        let plan = TodayPlan.make(
            resume: nil,
            nextLesson: next,
            dueCount: 2,
            nextDueAt: nil,
            listen: nil)

        guard case .lesson(let lesson, let unit) = plan.primary else {
            return XCTFail("expected .lesson, got \(plan.primary)")
        }
        XCTAssertEqual(lesson.id, next.lesson.id)
        XCTAssertEqual(unit.id, next.unit.id)
        // A due>0 learner keeps the review row under a lesson headline.
        XCTAssertEqual(plan.dueCount, 2)
    }

    func testNoResumeNoLessonWithDueReviewsLeadsToReviewPrimary() throws {
        let plan = TodayPlan.make(
            resume: nil,
            nextLesson: nil,
            dueCount: 4,
            nextDueAt: Date.distantFuture,
            listen: nil)

        guard case .review(let due) = plan.primary else {
            return XCTFail("expected .review, got \(plan.primary)")
        }
        XCTAssertEqual(due, 4)
        XCTAssertEqual(plan.dueCount, 4)
    }

    func testFallsBackToListenThenRest() throws {
        // No path, no reviews: a listen track becomes the headline.
        let track = listenTrack(lessonId: "fr-welcome")
        let listenPlan = TodayPlan.make(
            resume: nil, nextLesson: nil, dueCount: 0,
            nextDueAt: nil, listen: track)
        guard case .listen(let chosen) = listenPlan.primary else {
            return XCTFail("expected .listen, got \(listenPlan.primary)")
        }
        XCTAssertEqual(chosen.id, "fr-welcome")

        // Nothing at all: rest, still carrying the next review date.
        let restPlan = TodayPlan.make(
            resume: nil, nextLesson: nil, dueCount: 0,
            nextDueAt: Date.distantFuture, listen: nil)
        guard case .rest = restPlan.primary else {
            return XCTFail("expected .rest, got \(restPlan.primary)")
        }
        XCTAssertEqual(restPlan.dueCount, 0)
        XCTAssertNil(restPlan.listen)
        XCTAssertNotNil(restPlan.nextDueAt)
    }
}

// MARK: - Scenario loop (P3.2 pure core)

/// Pins the listen–respond–compare loop's pure core: section eligibility,
/// per-section timing, and the step machine. No audio, no views, no
/// scoring — the state type is asserted to carry no score baggage.
final class ScenarioLoopTests: XCTestCase {

    // MARK: Fixtures

    private func section(
        _ heading: String, target: Bool = true, startS: Double? = nil
    ) -> ListenSection {
        ListenSection(
            heading: heading,
            teacher: "teacher of \(heading)",
            target: target ? ListenTarget(text: "Texte", meaning: "Text") : nil,
            startS: startS)
    }

    private func makeTrack(
        sections: [ListenSection], durationS: Double = 120
    ) -> ListenTrack {
        ListenTrack(
            lessonId: "scenario-fixture",
            courseSlug: "french",
            lessonTitle: "Scenario fixture",
            audioUrl: "audio/scenario-fixture.mp3",
            durationS: durationS,
            reviewPending: nil,
            sections: sections)
    }

    // MARK: Eligibility

    func testScenarioSectionsEligibilityAndOrder() {
        let track = makeTrack(sections: [
            section("s1", target: true, startS: 0),
            section("s2", target: false, startS: 10),   // no target: ineligible
            section("s3", target: true, startS: nil),   // no start: ineligible
            section("s4", target: true, startS: 30),
        ])
        let eligible = ListenScenario.scenarioSections(track: track)
        XCTAssertEqual(eligible.map(\.heading), ["s1", "s4"])
        XCTAssertTrue(eligible.allSatisfy { $0.target != nil && $0.startS != nil })

        // A track with no eligible sections yields [].
        let none = makeTrack(sections: [
            section("a", target: false, startS: 0),
            section("b", target: true, startS: nil),
        ])
        XCTAssertTrue(ListenScenario.scenarioSections(track: none).isEmpty)
    }

    func testSectionEndUsesNextTranscriptBoundaryOrTrackDuration() {
        let track = makeTrack(sections: [
            section("s1", startS: 0),
            section("s2", startS: 15),
            section("s3", startS: 40),
            section("s4", startS: 70),
        ])
        // Mid-track: the next section's startS.
        XCTAssertEqual(ListenScenario.sectionEnd(for: 0, in: track), 15)
        XCTAssertEqual(ListenScenario.sectionEnd(for: 2, in: track), 70)
        // Last section: the audio's declared duration, not an arbitrary cap.
        let start = try! XCTUnwrap(track.sections[3].startS)
        let last = ListenScenario.sectionEnd(for: 3, in: track)
        XCTAssertEqual(last, 120)
        XCTAssertGreaterThan(last, start)

        let endingWithUntargetedSection = makeTrack(sections: [
            section("practice", startS: 70),
            section("closing", target: false, startS: 90),
        ])
        XCTAssertEqual(
            ListenScenario.sectionEnd(for: 0, in: endingWithUntargetedSection), 90)
    }

    func testSectionEndFinalEligibleSectionRunsToDeclaredDuration() {
        // The last scenario section is followed only by an untimed,
        // untargeted closing segment the learner skips: its window must
        // run to the track's declared duration — end == durationS — and
        // never past it.
        let track = makeTrack(
            sections: [
                section("opening", startS: 0),
                section("practice", startS: 30),
                section("final", startS: 150),
                section("closing", target: false, startS: nil),
            ],
            durationS: 200)
        XCTAssertEqual(ListenScenario.scenarioSections(track: track).count, 3)
        // Mid-track windows still bound at the next timed section.
        XCTAssertEqual(ListenScenario.sectionEnd(for: 0, in: track), 30)
        XCTAssertEqual(ListenScenario.sectionEnd(for: 1, in: track), 150)
        // The final section runs to the declared audio duration.
        let end = ListenScenario.sectionEnd(for: 2, in: track)
        XCTAssertEqual(end, 200)
        XCTAssertEqual(end, track.durationS)
    }

    func testUntargetedSectionsAreSkippedAndStillBoundThePriorWindow() {
        // An untargeted section is never a scenario step the learner is
        // on, but its timing still bounds the section before it; indices
        // past the eligible list are degenerate (0), never a crash.
        let track = makeTrack(sections: [
            section("s1", startS: 0),
            section("bridge", target: false, startS: 15),
            section("s2", startS: 30),
            section("outro", target: false, startS: 60),
        ])
        XCTAssertEqual(
            ListenScenario.scenarioSections(track: track).map(\.heading),
            ["s1", "s2"])
        // s1 runs to the untargeted bridge's start; s2 runs to the outro's.
        XCTAssertEqual(ListenScenario.sectionEnd(for: 0, in: track), 15)
        XCTAssertEqual(ListenScenario.sectionEnd(for: 1, in: track), 60)
        // Indices into the eligible list, not the raw transcript.
        XCTAssertEqual(ListenScenario.sectionEnd(for: 2, in: track), 0)
        XCTAssertEqual(ListenScenario.sectionEnd(for: 99, in: track), 0)
    }

    // MARK: Step machine

    func testScenarioLoopTransitionsThroughAllSteps() {
        // Two sections × line→choose→speak→model.
        var state = ScenarioLoopState(total: 2, micUnavailable: false)
        XCTAssertEqual(state.total, 2)
        XCTAssertEqual(state.currentSectionIndex, 0)
        XCTAssertEqual(state.currentStep, .line)
        XCTAssertFalse(state.isDone)

        // First section: line → choose → speak → model.
        for expected in [ScenarioLoopState.Step.choose, .speak, .model] {
            state.advance()
            XCTAssertEqual(state.currentStep, expected)
            XCTAssertEqual(state.currentSectionIndex, 0)
        }

        // Model of section 0 → line of section 1.
        state.advance()
        XCTAssertEqual(state.currentStep, .line)
        XCTAssertEqual(state.currentSectionIndex, 1)

        // Second section: same walk.
        for expected in [ScenarioLoopState.Step.choose, .speak, .model] {
            state.advance()
            XCTAssertEqual(state.currentStep, expected)
            XCTAssertEqual(state.currentSectionIndex, 1)
        }

        // Model of the last section → done; done is terminal.
        state.advance()
        XCTAssertEqual(state.currentStep, .done)
        XCTAssertEqual(state.currentSectionIndex, 1)
        XCTAssertTrue(state.isDone)
        state.advance()
        XCTAssertEqual(state.currentStep, .done)
    }

    func testScenarioLoopSkipsSpeakWhenMicUnavailable() {
        var state = ScenarioLoopState(total: 2, micUnavailable: true)
        XCTAssertEqual(state.currentStep, .line)

        state.advance() // line → choose
        XCTAssertEqual(state.currentStep, .choose)

        state.advance() // choose → model; speak silently skipped
        XCTAssertEqual(state.currentStep, .model)
        XCTAssertNotEqual(state.currentStep, .speak)
        XCTAssertFalse(state.isDone)

        state.advance() // model → next section's line
        XCTAssertEqual(state.currentStep, .line)
        XCTAssertEqual(state.currentSectionIndex, 1)

        state.advance()
        XCTAssertEqual(state.currentStep, .choose)
        state.advance()
        XCTAssertEqual(state.currentStep, .model)
        state.advance()
        XCTAssertEqual(state.currentStep, .done)
        XCTAssertTrue(state.isDone)
    }

    func testScenarioLoopHasNoScoreState() {
        // Shape assertion: the state machine carries zero
        // score/accuracy/grade baggage. Reflect the stored member list and
        // check it is exactly the loop-position fields — nothing else.
        let state = ScenarioLoopState(total: 3, micUnavailable: false)
        let labels = Mirror(reflecting: state).children.compactMap(\.label)
        XCTAssertEqual(
            Set(labels), ["total", "index", "step", "micUnavailable"],
            "ScenarioLoopState must expose exactly the loop fields, got \(labels)")

        let forbidden = ["score", "accuracy", "grade", "credit", "points",
                         "correct", "wrong", "mistake"]
        for label in labels {
            XCTAssertFalse(
                forbidden.contains { label.lowercased().contains($0) },
                "ScenarioLoopState must not carry \(label)")
        }
    }

    // MARK: Step playback rate

    /// Pins the pure rate decision behind the practice sheet's window
    /// playback: the compare (.model) step replays at the slow rate
    /// (0.75), every other step (and done) at normal speed 1.0.
    func testScenarioStepRatePinsModelStepToSlowRate() {
        XCTAssertEqual(scenarioStepRate(for: .model), 0.75,
                       "the compare step must replay at the slow rate")
        for step: ScenarioLoopState.Step in [.line, .choose, .speak, .done] {
            XCTAssertEqual(scenarioStepRate(for: step), 1,
                           "\(step) must play at normal speed")
        }
    }

    /// Drift guard between the helper's slow literal and the transport's
    /// published `slowRate`: the compare step uses the same 0.75 the
    /// player model exposes.
    @MainActor
    func testScenarioStepRateMatchesTransportSlowRate() {
        XCTAssertEqual(ListenPlayerModel.slowRate, 0.75)
        XCTAssertEqual(
            scenarioStepRate(for: .model), ListenPlayerModel.slowRate)
    }
}

// MARK: - Recap split

/// The recap's honest split counts each distinct step once per visit:
/// retrying a trouble spot updates nothing and never inflates the numbers.
final class RecapSplitTests: XCTestCase {

    private func eval(_ outcome: AttemptEvaluation.Outcome,
                      independent: Bool = false) -> AttemptEvaluation {
        AttemptEvaluation(outcome: outcome, independent: independent, feedback: "f")
    }

    /// (a) One step submitted three times (first try wrong, in-pass retry
    /// tainted by the revealed model, retry-pass clean solve) claims exactly
    /// one slot, decided by the first countable check.
    func testOneStepSubmittedThreeTimesCountsOnce() {
        var split = LessonRecapSplit()
        split.record(stepId: "s1", evaluation: eval(.incorrect))
        split.record(stepId: "s1", evaluation: eval(.correct))
        split.record(stepId: "s1", evaluation: eval(.correct, independent: true))
        XCTAssertEqual(split.independentCount, 0)
        XCTAssertEqual(split.practiceCount, 1)
    }

    /// (b) Two steps each submitted once: one recall, one self-compare
    /// (self-compares are always practice-with-help).
    func testTwoStepsEachSubmittedOnce() {
        var split = LessonRecapSplit()
        split.record(stepId: "s1", evaluation: eval(.correct, independent: true))
        split.record(stepId: "s2", evaluation: eval(.selfAssessed))
        XCTAssertEqual(split.independentCount, 1)
        XCTAssertEqual(split.practiceCount, 1)
    }

    /// (c) A retried trouble spot that flips from with-help to independent
    /// keeps its first class: help was used on that step this run, so an
    /// upgrade by the later clean solve would overstate recall.
    func testRetriedTroubleSpotStaysWithHelp() {
        var split = LessonRecapSplit()
        split.record(stepId: "s1", evaluation: eval(.incorrect)) // with help
        split.record(stepId: "s1", evaluation: eval(.correct, independent: true))
        XCTAssertEqual(split.independentCount, 0)
        XCTAssertEqual(split.practiceCount, 1)
    }

    /// Reading steps (ungraded) and failed saves (blocked) claim nothing, and
    /// a later countable check on the same step still gets its slot.
    func testUngradedAndBlockedExcluded() {
        var split = LessonRecapSplit()
        split.record(stepId: "s1", evaluation: eval(.ungraded))
        split.record(stepId: "s2", evaluation: eval(.blocked))
        XCTAssertEqual(split.independentCount, 0)
        XCTAssertEqual(split.practiceCount, 0)
        split.record(stepId: "s2", evaluation: eval(.correct, independent: true))
        XCTAssertEqual(split.independentCount, 1)
        XCTAssertEqual(split.practiceCount, 0)
    }

    /// A fresh split resets to zero (the per-visit `switchLesson` reset).
    func testFreshSplitStartsAtZero() {
        var split = LessonRecapSplit()
        split.record(stepId: "s1", evaluation: eval(.correct, independent: true))
        split = LessonRecapSplit()
        XCTAssertEqual(split.independentCount, 0)
        XCTAssertEqual(split.practiceCount, 0)
    }
}
