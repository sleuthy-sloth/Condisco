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

// MARK: - Dialogue sessions (Phase 6.3)

/// The branching-exchange engine over the real Spanish hosted exchanges:
/// start → answer (choice or open) → partner's next line, position as
/// checkpointable state, force-quit resume preserving branch position and
/// recorded turn order, and replay-as-new-attempt semantics.
final class DialogueSessionTests: XCTestCase {

    private func spanishPack() throws -> CoursePack {
        try XCTUnwrap(
            PackLoader.loadPacks().first { $0.language == .spanish })
    }

    /// The café exchange: order coffee, the waiter mishears it as tea, the
    /// learner repairs the misunderstanding, then answers the open turn.
    private func cafeExchange(in pack: CoursePack)
        throws -> (lesson: Lesson, dialogue: Dialogue) {
        let lesson = try XCTUnwrap(pack.lesson(id: "es-cafe-requests-foundation"))
        let dialogue = try XCTUnwrap(pack.dialogue(id: "es-cafe-turno"))
        return (lesson, dialogue)
    }

    func testStartDialogueRequiresHostedExchange() throws {
        let pack = try spanishPack()
        let lesson = try XCTUnwrap(pack.lesson(id: "es-cafe-requests-foundation"))
        // The plans exchange belongs to a different host lesson.
        let plans = try XCTUnwrap(pack.dialogue(id: "es-a2-planes-sabado"))
        XCTAssertThrowsError(try startDialogue(pack: pack, lesson: lesson, dialogue: plans)) { error in
            guard case DialogueSessionError.unhosted = error else {
                return XCTFail("expected unhosted, got \(error)")
            }
        }
    }

    /// The full main path: greet → mishear → repair → open turn → end.
    /// The partner's reply CHANGES per choice (the misread), the learner
    /// recovers, and the open turn is never auto-graded.
    func testDialogueMainPathRunsToCompletion() throws {
        let pack = try spanishPack()
        let (lesson, dialogue) = try cafeExchange(in: pack)
        var session = try startDialogue(pack: pack, lesson: lesson, dialogue: dialogue)
        XCTAssertEqual(session.status, .active)
        XCTAssertEqual(session.currentNodeId, "greet")
        XCTAssertEqual(session.visitedNodeIds, ["greet"])
        XCTAssertTrue(session.turns.isEmpty)

        // Turn 1: the learner orders a coffee (choice).
        session = try submitDialogueChoice(
            pack: pack, session: session, choiceId: "order-coffee")
        XCTAssertEqual(session.currentNodeId, "mishear")
        XCTAssertEqual(session.turns.count, 1)
        XCTAssertEqual(session.turns[0].nodeId, "greet")
        XCTAssertEqual(session.turns[0].choiceId, "order-coffee")

        // Turn 2: the waiter misread the order — the learner repairs it.
        session = try submitDialogueChoice(
            pack: pack, session: session, choiceId: "correct-coffee")
        XCTAssertEqual(session.currentNodeId, "recover")
        XCTAssertEqual(session.turns.map(\.choiceId), ["order-coffee", "correct-coffee"])

        // Turn 3: accept the apology.
        session = try submitDialogueChoice(
            pack: pack, session: session, choiceId: "thanks")
        XCTAssertEqual(session.currentNodeId, "algo-mas")
        XCTAssertTrue(pack.dialogue(id: "es-cafe-turno")?.node(id: "algo-mas")?.prompt != nil)

        // Turn 4: the open turn — composed reply + self-assessment.
        XCTAssertThrowsError(try submitDialogueOpenTurn(
            pack: pack, session: session, draft: "   ", criteriaMet: [],
            rating: nil, modelRevealed: false)) { error in
            guard case DialogueSessionError.emptyDraft = error else {
                return XCTFail("expected emptyDraft, got \(error)")
            }
        }
        session = try submitDialogueOpenTurn(
            pack: pack, session: session,
            draft: "No, nada más, gracias.",
            criteriaMet: ["meaning", "useful-language"],
            rating: .good,
            modelRevealed: false)
        XCTAssertEqual(session.status, .complete)
        XCTAssertEqual(session.currentNodeId, "done")
        XCTAssertEqual(session.turns.count, 4)
        let open = session.turns[3]
        XCTAssertEqual(open.nodeId, "algo-mas")
        XCTAssertEqual(open.draft, "No, nada más, gracias.")
        XCTAssertEqual(open.criteriaMet, ["meaning", "useful-language"])
        XCTAssertEqual(open.rating, .good)
        XCTAssertFalse(open.modelRevealed)

        // A complete exchange rejects further turns.
        XCTAssertThrowsError(try submitDialogueChoice(
            pack: pack, session: session, choiceId: "order-coffee")) { error in
            guard case DialogueSessionError.dialogueComplete = error else {
                return XCTFail("expected dialogueComplete, got \(error)")
            }
        }
    }

    /// The clarification branch: asking for a repeat routes through the
    /// authored clarification node and back onto the same misunderstanding
    /// repair thread.
    func testClarificationRouteRejoinsMainThread() throws {
        let pack = try spanishPack()
        let (lesson, dialogue) = try cafeExchange(in: pack)
        var session = try startDialogue(pack: pack, lesson: lesson, dialogue: dialogue)
        session = try submitDialogueChoice(pack: pack, session: session, choiceId: "ask-repeat")
        XCTAssertEqual(session.currentNodeId, "clarify-greet")
        XCTAssertEqual(
            pack.dialogue(id: "es-cafe-turno")?.node(id: "clarify-greet")?.kind,
            .clarification)
        session = try submitDialogueChoice(pack: pack, session: session, choiceId: "order-coffee-again")
        XCTAssertEqual(session.currentNodeId, "mishear",
                       "after the clarification the thread rejoins the misunderstanding")
        XCTAssertEqual(session.turns.map(\.nodeId), ["greet", "clarify-greet"])
    }

    /// Force-quit resume: mid-exchange state (position + answered turns)
    /// round-trips through the checkpoint slice, and continuing appends
    /// the next turn in order without reordering or duplicating earlier
    /// turns.
    func testForceQuitResumeKeepsPositionAndTurnOrder() throws {
        let pack = try spanishPack()
        let (lesson, dialogue) = try cafeExchange(in: pack)
        var session = try startDialogue(pack: pack, lesson: lesson, dialogue: dialogue)
        session = try submitDialogueChoice(pack: pack, session: session, choiceId: "order-coffee")
        session = try submitDialogueChoice(pack: pack, session: session, choiceId: "correct-coffee")

        // Force quit: persist the checkpoint slice.
        let saved = session.checkpointState()

        // Rebuild from the slice and continue.
        let resumed = try XCTUnwrap(
            resumeDialogueSession(pack: pack, state: saved))
        XCTAssertEqual(resumed.currentNodeId, "recover")
        XCTAssertEqual(resumed.visitedNodeIds, session.visitedNodeIds)
        XCTAssertEqual(resumed.turns, session.turns,
                       "resume must restore exactly the turns recorded before the quit")

        // Continue from the restored position: the remaining turns append in
        // authored order — nothing prior is reordered or duplicated.
        var next = resumed
        next = try submitDialogueChoice(pack: pack, session: next, choiceId: "thanks")
        XCTAssertEqual(next.currentNodeId, "algo-mas")
        next = try submitDialogueOpenTurn(
            pack: pack, session: next, draft: "No, nada más, gracias.",
            criteriaMet: [], rating: nil, modelRevealed: false)
        XCTAssertEqual(next.status, .complete)
        XCTAssertEqual(next.turns.map(\.nodeId),
                       ["greet", "mishear", "recover", "algo-mas"],
                       "resumed turns keep the authored order, none duplicated")
        XCTAssertEqual(next.turns.count, 4)
        XCTAssertEqual(
            Array(next.turns.prefix(resumed.turns.count)), resumed.turns,
            "the turns recorded before the quit appear first, unchanged")
    }

    /// A checkpoint thread that no longer replays along real edges resumes
    /// as nil — the player then presents the exchange fresh rather than
    /// dead-ending the learner.
    func testResumeReturnsNilForBrokenThread() throws {
        let pack = try spanishPack()
        let (lesson, dialogue) = try cafeExchange(in: pack)
        var session = try startDialogue(pack: pack, lesson: lesson, dialogue: dialogue)
        session = try submitDialogueChoice(pack: pack, session: session, choiceId: "order-coffee")
        var corrupt = session.checkpointState()
        corrupt.visitedNodeIds = ["greet", "nowhere", "also-nowhere"]
        corrupt.currentNodeId = "also-nowhere"
        XCTAssertNil(resumeDialogueSession(pack: pack, state: corrupt))
    }

    /// The learner's replies are exactly what they supplied — a picked
    /// choice text and their own draft. No model text, no un-chosen
    /// options leak into the session (the recap renders this verbatim).
    func testRecapDataContainsOnlyLearnerSuppliedResponses() throws {
        let pack = try spanishPack()
        let (lesson, dialogue) = try cafeExchange(in: pack)
        var session = try startDialogue(pack: pack, lesson: lesson, dialogue: dialogue)
        session = try submitDialogueChoice(pack: pack, session: session, choiceId: "order-coffee")
        session = try submitDialogueChoice(pack: pack, session: session, choiceId: "correct-coffee")
        session = try submitDialogueChoice(pack: pack, session: session, choiceId: "thanks")
        let draft = "No, solo esto, gracias."
        session = try submitDialogueOpenTurn(
            pack: pack, session: session, draft: draft,
            criteriaMet: ["meaning"], rating: nil, modelRevealed: false)

        // Resolve the learner's replies from the pack (choice id → text).
        var replies: [String] = []
        for turn in session.turns {
            if let choiceId = turn.choiceId {
                let node = try XCTUnwrap(dialogue.node(id: turn.nodeId))
                let choice = try XCTUnwrap(node.choices.first { $0.id == choiceId })
                replies.append(choice.text)
            } else {
                replies.append(try XCTUnwrap(turn.draft))
            }
        }
        XCTAssertEqual(replies, [
            "Hola. Quisiera un café, por favor.",
            "No, perdón — un café, por favor.",
            "No pasa nada. Gracias.",
            draft,
        ])
        // The open turn's model response is authored, NOT a learner reply.
        let openNode = try XCTUnwrap(dialogue.node(id: "algo-mas"))
        XCTAssertFalse(replies.contains(openNode.modelResponse ?? ""))
        // Turn records carry no invented content beyond choice id + draft.
        for turn in session.turns {
            XCTAssertTrue(turn.choiceId != nil || turn.draft != nil)
        }
    }

    /// Replay semantics: starting the exchange again is a fresh attempt —
    /// clean slate position and turns (events for the new attempt get fresh
    /// ids; the store tests pin the recording side).
    func testPractiseAgainStartsFreshAttempt() throws {
        let pack = try spanishPack()
        let (lesson, dialogue) = try cafeExchange(in: pack)
        var session = try startDialogue(pack: pack, lesson: lesson, dialogue: dialogue)
        session = try submitDialogueChoice(pack: pack, session: session, choiceId: "order-coffee")
        XCTAssertEqual(session.turns.count, 1)

        let fresh = try startDialogue(pack: pack, lesson: lesson, dialogue: dialogue)
        XCTAssertEqual(fresh.status, .active)
        XCTAssertEqual(fresh.currentNodeId, "greet")
        XCTAssertTrue(fresh.turns.isEmpty,
                      "a replay must re-present the exchange cleanly, not re-answer prior turns")
    }

    /// The plans exchange: misunderstanding about the DAY, repair, and a
    /// open turn composed with `voy a`.
    func testPlansExchangeMisunderstandingAboutDay() throws {
        let pack = try spanishPack()
        let lesson = try XCTUnwrap(pack.lesson(id: "es-a2-planes-intenciones"))
        let dialogue = try XCTUnwrap(pack.dialogue(id: "es-a2-planes-sabado"))
        var session = try startDialogue(pack: pack, lesson: lesson, dialogue: dialogue)
        session = try submitDialogueChoice(pack: pack, session: session, choiceId: "suggest-cine")
        XCTAssertEqual(session.currentNodeId, "mishear-day")
        XCTAssertEqual(
            pack.dialogue(id: "es-a2-planes-sabado")?.node(id: "mishear-day")?.kind,
            .misunderstanding)
        session = try submitDialogueChoice(pack: pack, session: session, choiceId: "fix-saturday")
        XCTAssertEqual(session.currentNodeId, "recover-day")
        XCTAssertEqual(
            pack.dialogue(id: "es-a2-planes-sabado")?.node(id: "recover-day")?.kind,
            .recovery)
        session = try submitDialogueChoice(pack: pack, session: session, choiceId: "lets-go")
        XCTAssertEqual(session.currentNodeId, "plan-open")
        session = try submitDialogueOpenTurn(
            pack: pack, session: session,
            draft: "Voy a ir al cine contigo.",
            criteriaMet: ["meaning"], rating: .good, modelRevealed: true)
        XCTAssertEqual(session.status, .complete)
        XCTAssertTrue(session.turns[3].modelRevealed,
                      "a revealed model marks the open turn non-independent")
    }
}

// MARK: - Next lesson: the shared path helper and its consumer surfaces

/// "What comes next on the learner's path" has one source of truth —
/// `CoursePack.firstUncompletedLesson(completed:)` — surfaced through the
/// shared `continueLessonResolution` function (focus-pack selection +
/// next-lesson), with three consumer surfaces: the Home continue card,
/// `condisco://continue`, and the widget snapshot. Every surface must
/// feed the helper the same completed set
/// (`PackProgress.finishedLessons`) so all three agree on the next
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

    func testItalianPastUnitComesBeforeFutureOnThePath() throws {
        let pack = try XCTUnwrap(
            PackLoader.loadPacks().first { $0.language == .italian })
        let unitIDs = pack.units.map(\.id)
        let pastIndex = try XCTUnwrap(unitIDs.firstIndex(of: "it-unit-9"))
        let futureIndex = try XCTUnwrap(unitIDs.firstIndex(of: "it-unit-10"))
        XCTAssertEqual(futureIndex, pastIndex + 1)

        let lastFoundation = try XCTUnwrap(
            pack.lessons.last(where: { $0.unitId == "it-unit-8" }))
        let firstPast = try XCTUnwrap(
            pack.lessons.first(where: { $0.unitId == "it-unit-9" }))
        let firstFuture = try XCTUnwrap(
            pack.lessons.first(where: { $0.unitId == "it-unit-10" }))
        let foundationEnd = try XCTUnwrap(
            pack.lessons.firstIndex(where: { $0.id == lastFoundation.id }))
        let next = pack.firstUncompletedLesson(
            completed: Set(pack.lessons.prefix(through: foundationEnd).map(\.id)))
        XCTAssertEqual(next?.lesson.id, firstPast.id)
        XCTAssertLessThan(
            try XCTUnwrap(pack.lessons.firstIndex(where: { $0.id == firstPast.id })),
            try XCTUnwrap(pack.lessons.firstIndex(where: { $0.id == firstFuture.id })))
    }

    // MARK: Skipped lessons advance the path

    /// A manual "I know this" mark and a legacy credit both remove a
    /// lesson from the next-lesson path without creating practice evidence.
    func testKnownAndLegacyCreditsAdvanceHomePath() throws {
        let pack = try fixturePack(lessons: [
            (id: "l1", unitId: u1),
            (id: "l2", unitId: u1),
        ])
        // l1 is marked known and legacy-credited but has no participation.
        var progress = PackProgress()
        progress.knownLessons = ["l1"]
        progress.legacyCredits = ["l1"]
        XCTAssertTrue(progress.finishedLessons.contains("l1"))
        XCTAssertTrue(progress.participationCompleted.isEmpty)

        // The helper receives the full finished set: l2 is next.
        XCTAssertEqual(
            pack.firstUncompletedLesson(completed: progress.finishedLessons)?.lesson.id,
            "l2")

        // Home delegates identically, so the continue card agrees.
        let home = HomeModel()
        home.progress = [pack.id: progress]
        XCTAssertEqual(
            home.nextLesson(in: pack)?.lesson.id, "l2",
            "a known/legacy lesson must be skipped on the path")
        home.packs = [pack]
        XCTAssertEqual(home.continuationLesson(focusSlug: "french")?.lesson.id, "l2")
        let snapshot = WidgetSnapshotWriter.makeSnapshot(
            packs: [pack], focusSlug: "french", progress: [pack.id: progress],
            dueCount: 0, weekFlags: [], practiceDays: 0)
        XCTAssertEqual(snapshot.nextLessonId, "l2")
        XCTAssertEqual(
            pack.nextUncompletedLesson(after: "l1", completed: progress.finishedLessons)?.id,
            "l2")
        let recapPack = try fixturePack(lessons: [
            (id: "l1", unitId: u1),
            (id: "l2", unitId: u1),
            (id: "l3", unitId: u2),
        ])
        XCTAssertEqual(
            recapPack.nextUncompletedLesson(
                after: "l1", completed: ["l1", "l2"])?.id,
            "l3",
            "the recap must skip a lesson marked known")
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
    /// uncompleted lesson from `finishedLessons` — the exact
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
    /// same finished set across every path
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

    func testFreshLearnerWithNoProgressLeadsToLesson() throws {
        // A brand-new learner — no checkpoint, nothing completed, nothing
        // due: the next lesson is the only thing worth offering.
        let pack = try frenchPack()
        let next = try XCTUnwrap(pack.firstUncompletedLesson(completed: []))

        let plan = TodayPlan.make(
            resume: nil, nextLesson: next, dueCount: 0,
            nextDueAt: nil, listen: nil)

        guard case .lesson(let lesson, let unit) = plan.primary else {
            return XCTFail("expected .lesson, got \(plan.primary)")
        }
        XCTAssertEqual(lesson.id, next.lesson.id)
        XCTAssertEqual(unit.id, next.unit.id)
        XCTAssertEqual(plan.dueCount, 0)
    }

    func testPathCompleteWithReviewsDueLeadsToReview() throws {
        // Every lesson on the path is done: with nothing left to start,
        // the non-empty due queue becomes the headline — the "come back
        // and review" day.
        let pack = try frenchPack()
        let allDone = Set(pack.lessons.map(\.id))
        XCTAssertNil(pack.firstUncompletedLesson(completed: allDone))

        let plan = TodayPlan.make(
            resume: nil, nextLesson: nil, dueCount: 3,
            nextDueAt: Date.distantFuture, listen: nil)

        guard case .review(let due) = plan.primary else {
            return XCTFail("expected .review, got \(plan.primary)")
        }
        XCTAssertEqual(due, 3)
        XCTAssertEqual(plan.dueCount, 3)
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

    /// Provenance invariant: the main Listen player's voice descriptor — shown
    /// on the player card and the lock screen — must keep the "(synthesized)"
    /// wording that every other voice surface uses (Shadow, Practice, lesson
    /// record-compare). A future rename that drops the label would silently
    /// break the "any synthesized audio is labelled (synthesized)" rule.
    @MainActor
    func testListenVoiceDescriptorIsLabeledSynthesized() {
        XCTAssertEqual(
            ListenPlayerModel.voiceDescriptor, "Course voice (synthesized)",
            "The Listen player must label its synthesized voice exactly like "
            + "the rest of the app")
        XCTAssertTrue(
            ListenPlayerModel.voiceDescriptor.lowercased().contains("synthesized"),
            "The descriptor must keep the (synthesized) wording")
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

// MARK: - Recap phrase source ids

/// Phrases saved from the lesson recap must carry the pack and lesson
/// they came from, so phrasebook rows can route back to their origin
/// lesson. The save button itself is a view, but the payload both recap
/// call sites hand it is built by the shared pure `recapPhraseSave`
/// helper — the two recap save paths (word rows and the mission card)
/// use it, and these tests pin that the ids always travel with it.
final class RecapPhraseSaveTests: XCTestCase {

    private func frenchPack() throws -> CoursePack {
        try XCTUnwrap(
            PackLoader.loadPacks().first { $0.language == .french })
    }

    func testRecapSaveCarriesPackAndLessonSourceIds() throws {
        let pack = try frenchPack()
        let lesson = try XCTUnwrap(pack.lessons.first)

        let save = recapPhraseSave(
            target: "Bonjour", meaning: "Hello", pack: pack, lesson: lesson)

        XCTAssertEqual(save.sourcePackId, pack.id)
        XCTAssertEqual(save.sourceLessonId, lesson.id)
        // The human-readable source label stays the lesson title, so the
        // Saved list's existing grouping is unchanged.
        XCTAssertEqual(save.source, lesson.title)
        XCTAssertEqual(save.languageSlug, pack.language.slug)
        XCTAssertFalse(save.phrase.target.isEmpty)
        XCTAssertEqual(save.phrase.languageName, pack.language.displayName)
    }

    func testEveryLessonRecapSaveCarriesNonEmptySourceIds() throws {
        let pack = try frenchPack()
        XCTAssertFalse(pack.lessons.isEmpty, "fixture needs at least one lesson")
        for lesson in pack.lessons {
            let save = recapPhraseSave(
                target: "Merci", meaning: "Thanks", pack: pack, lesson: lesson)
            XCTAssertFalse(
                save.sourcePackId.isEmpty,
                "lesson \(lesson.id) must carry its pack id")
            XCTAssertEqual(save.sourceLessonId, lesson.id)
        }
    }

    /// The stored phrase shape the button writes: the deterministic id
    /// plus every field, exactly as `PhraseSaveButton` builds it — the
    /// source ids must land on the persisted row, not just the payload.
    func testStoredPhraseCarriesTheRecapSourceIds() throws {
        let pack = try frenchPack()
        let lesson = try XCTUnwrap(pack.lessons.first)
        let save = recapPhraseSave(
            target: "Merci", meaning: "Thanks", pack: pack, lesson: lesson)

        let stored = SavedPhrase(
            id: LearningStore.savedPhraseId(
                languageSlug: save.languageSlug,
                target: save.phrase.target,
                meaning: save.phrase.meaning),
            languageSlug: save.languageSlug,
            languageName: save.phrase.languageName,
            target: save.phrase.target,
            meaning: save.phrase.meaning,
            source: save.source,
            sourcePackId: save.sourcePackId,
            sourceLessonId: save.sourceLessonId,
            savedAt: Date())

        XCTAssertEqual(stored.sourcePackId, pack.id)
        XCTAssertEqual(stored.sourceLessonId, lesson.id)
        XCTAssertEqual(stored.id, LearningStore.savedPhraseId(
            languageSlug: pack.language.slug,
            target: "Merci",
            meaning: "Thanks"))
    }
}

// MARK: - Listen + stimulus phrase source ids

/// Phrases saved outside the recap must carry source ids too, so phrasebook
/// rows can route back to their origin lesson. The listen player's save is
/// the only one of the three remaining call sites with non-trivial logic —
/// locating the pack from the track's lesson id — which is extracted pure
/// (`ListenTrack.sourcePackId`) and pinned below. The other two call sites
/// (lesson stimulus, vocabulary browser) pass ids that are already in
/// scope: the pack id comes straight off the `CoursePack` the view holds,
/// and a lesson id is passed only where a single lesson genuinely exists
/// (stimulus examples carry `lesson?.id`, which callers of
/// `StimulusContextView` do not yet supply; the vocabulary browser spans
/// the whole pack, so no lesson id exists there at all).
final class PhraseSourceIdsForListenAndBrowserTests: XCTestCase {

    private func frenchPack() throws -> CoursePack {
        try XCTUnwrap(
            PackLoader.loadPacks().first { $0.language == .french })
    }

    /// Every bundled listen track resolves to a real pack by its lesson id
    /// — the exact lookup the listen save button relies on, and the same
    /// one the phrasebook runs to open a saved phrase's lesson.
    func testEveryListenTrackResolvesToItsPack() throws {
        let packs = try PackLoader.loadPacks()
        let tracks = ListenCatalog.loadTracks()
        XCTAssertFalse(tracks.isEmpty, "fixture needs at least one track")
        for track in tracks {
            let packId = track.sourcePackId
            XCTAssertFalse(
                packId.isEmpty,
                "track \(track.lessonId) must resolve to a pack")
            let pack = try XCTUnwrap(
                packs.first { $0.id == packId },
                "resolved pack must exist")
            XCTAssertTrue(
                pack.lessons.contains { $0.id == track.lessonId },
                "resolved pack \(packId) must contain the track's lesson")
        }
    }

    /// The French track's save payload: full ids — pack and lesson — plus
    /// the unchanged human-readable source and language slug.
    func testListenTrackExposesFullPackAndLessonSourceIds() throws {
        let pack = try frenchPack()
        let track = try XCTUnwrap(
            ListenCatalog.loadTracks().first { $0.courseSlug == "french" })

        XCTAssertEqual(track.sourcePackId, pack.id)
        XCTAssertFalse(track.lessonId.isEmpty)
        XCTAssertTrue(
            pack.lessons.contains { $0.id == track.lessonId })

        // The button writes these onto the persisted row.
        let stored = SavedPhrase(
            id: LearningStore.savedPhraseId(
                languageSlug: track.courseSlug,
                target: "Je suis Anna.",
                meaning: "I am Anna."),
            languageSlug: track.courseSlug,
            languageName: ListenCourse.displayName(for: track.courseSlug),
            target: "Je suis Anna.",
            meaning: "I am Anna.",
            source: track.lessonTitle,
            sourcePackId: track.sourcePackId,
            sourceLessonId: track.lessonId,
            savedAt: Date())
        XCTAssertEqual(stored.sourcePackId, pack.id)
        XCTAssertEqual(stored.sourceLessonId, track.lessonId)
    }
}

// MARK: - Review session length entry points

/// Home's Today invitation promises "Up to 5 reviews", so entering
/// Review from there must preselect a five-card session. Direct
/// Review-tab entry keeps the learner's chosen size, and a deep link
/// (widget) asks for everything due. The shared binding in ContentView
/// is the single source of truth, so a picker change persists across
/// tab switches — the `.tab` entry below pins exactly that contract.
final class ReviewSessionLengthTests: XCTestCase {

    func testHomeInvitationAlwaysPreselectsFive() {
        // Even when the learner had chosen a bigger sitting, Home's
        // invitation still opens a five-card session matching its copy.
        XCTAssertEqual(
            resolveReviewSessionLength(for: .homeInvitation, current: .all), .five)
        XCTAssertEqual(
            resolveReviewSessionLength(for: .homeInvitation, current: .ten), .five)
        XCTAssertEqual(
            resolveReviewSessionLength(for: .homeInvitation, current: .five), .five)
    }

    func testTabEntryKeepsCurrentChoice() {
        // A picker change ("picker change persists") survives tab
        // switches: entering the tab re-applies whatever is current.
        XCTAssertEqual(
            resolveReviewSessionLength(for: .tab, current: .ten), .ten)
        XCTAssertEqual(
            resolveReviewSessionLength(for: .tab, current: .five), .five)
        XCTAssertEqual(
            resolveReviewSessionLength(for: .tab, current: .all), .all)
    }

    func testDeepLinkRequestsEverythingDue() {
        XCTAssertEqual(
            resolveReviewSessionLength(for: .deepLink, current: .five), .all)
        XCTAssertEqual(
            resolveReviewSessionLength(for: .deepLink, current: .all), .all)
    }
}

// MARK: - Warm-up recall selection (supplement)

/// The pure selection rules of the lesson warm-up are covered in detail
/// by `LearningStoreTests` (earlier-ideas-only, current-lesson evidence
/// exclusion, evidence-key dedup, the "review" fallback skip). These
/// pin the two branches those tests leave open: the strict cap of two
/// when more than two earlier items are due, and the guard for a
/// current lesson that is not in the pack at all.
final class RecallWarmUpTests: XCTestCase {

    private func frenchPack() throws -> CoursePack {
        try XCTUnwrap(
            PackLoader.loadPacks().first { $0.language == .french })
    }

    /// A minimal due item from `lessonId`; the evidence key is invented
    /// so it can never collide with the current lesson's real evidence.
    private func dueItem(
        pack: CoursePack, lessonId: String, evidenceKey: String, dueAt: Date
    ) -> ReviewItem {
        ReviewItem(
            evidenceKey: evidenceKey,
            packId: pack.id,
            packVersion: pack.version,
            courseTitle: pack.title,
            lessonId: lessonId,
            lessonTitle: lessonId,
            lessonRevision: 1,
            stepId: "warm-up-step",
            activityId: evidenceKey,
            activityRevision: 1,
            prompt: "prompt",
            answerText: "answer",
            feedback: "feedback",
            dueAt: dueAt)
    }

    func testCapOfTwoKeepsOnlyTheTwoOldest() throws {
        let pack = try frenchPack()
        let current = try XCTUnwrap(pack.lesson(id: "fr-home-foundation"))
        let t1 = Date(timeIntervalSince1970: 1_700_000_000)
        // Three eligible earlier-lesson items — strictly more than the
        // cap, so the truncation (not just the filters) is what decides.
        let due = [
            dueItem(pack: pack, lessonId: "fr-identity-foundation",
                    evidenceKey: "warmup-key-a", dueAt: t1),
            dueItem(pack: pack, lessonId: "fr-identity-foundation",
                    evidenceKey: "warmup-key-b", dueAt: t1.addingTimeInterval(100)),
            dueItem(pack: pack, lessonId: "fr-identity-foundation",
                    evidenceKey: "warmup-key-c", dueAt: t1.addingTimeInterval(200)),
        ]

        let selected = RecallWarmUp.select(
            due: due, currentLesson: current, pack: pack, limit: 2)

        XCTAssertEqual(
            selected.map(\.evidenceKey), ["warmup-key-a", "warmup-key-b"])
    }

    func testCurrentLessonMissingFromPackYieldsNothing() throws {
        let pack = try frenchPack()
        let t1 = Date(timeIntervalSince1970: 1_700_000_000)
        // A lesson whose id is not in the pack (stale payload, pack
        // reshuffle): there is no "earlier" anchor, so nothing may be
        // offered rather than guessing wrong.
        let ghost = try decodedGhostLesson(pack: pack)
        let due = [
            dueItem(pack: pack, lessonId: "fr-identity-foundation",
                    evidenceKey: "warmup-key-a", dueAt: t1),
        ]

        XCTAssertTrue(RecallWarmUp.select(
            due: due, currentLesson: ghost, pack: pack).isEmpty)
    }

    /// A minimum valid Lesson not present in the fixture pack.
    private func decodedGhostLesson(pack: CoursePack) throws -> Lesson {
        let dict: [String: Any] = [
            "id": "ghost-lesson",
            "unitId": pack.units.first?.id ?? "u1",
            "title": "Ghost lesson",
            "objective": "objective",
            "family": "discovery",
            "revision": 1,
            "estimatedMinutes": 5,
            "entryStepId": "ghost-step",
            "steps": [
                ["id": "ghost-step", "purpose": "practice",
                 "activityId": "ghost-activity", "required": true],
            ],
            "completionPolicy": ["kind": "participation"],
            "conceptIds": [],
            "vocabulary": [],
        ]
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(Lesson.self, from: data)
    }
}

// MARK: - Review due projection

/// The review queue has a single source of truth — the learning-event
/// projection. `ReviewCatalog.loadDue` and every due count it feeds
/// (Home, Review, You, the widget) must agree exactly with the due
/// records `project(pack:)` derives; there is deliberately no separate
/// persisted review counter (the store schema keeps only events,
/// checkpoints, kv, and phrasebook tables). These tests pin that
/// equivalence directly from a fresh store.
@MainActor
final class ReviewCatalogProjectionTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("condisco-loaddue-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
    }

    private func frenchPack() throws -> CoursePack {
        try XCTUnwrap(
            PackLoader.loadPacks().first { $0.language == .french })
    }

    /// A valid independent-correct attempt on a real step of
    /// fr-home-foundation. `at` controls the FSRS schedule: an old date
    /// puts the card due today, today's date schedules it into the future.
    private func makeAttempt(
        id: String, pack: CoursePack, stepId: String, at: Date
    ) throws -> ActivityAttempt {
        let lesson = try XCTUnwrap(pack.lesson(id: "fr-home-foundation"))
        let step = try XCTUnwrap(lesson.steps.first { $0.id == stepId })
        let activity = try XCTUnwrap(pack.activity(id: step.activityId))
        let response: AttemptResponse
        switch activity {
        case .selection(let spec):
            response = .selection(ids: spec.acceptedIds)
        case .cloze(let spec):
            response = .cloze(values: Dictionary(
                uniqueKeysWithValues: spec.blanks.map {
                    ($0.key, $0.value.answers.first ?? "")
                }))
        default:
            throw XCTSkip("expected a selection or cloze step")
        }
        return ActivityAttempt(
            id: id, packId: pack.id, packVersion: pack.version,
            lessonId: lesson.id, lessonRevision: lesson.revision,
            stepId: step.id, activityId: activity.id,
            activityRevision: activity.revision,
            evidenceKey: activity.evidenceKey,
            response: response,
            assistance: [],
            evaluation: AttemptEvaluation(
                outcome: .correct, independent: true, feedback: "correct"),
            at: at)
    }

    func testLoadDueMatchesProjectionExactly() throws {
        let store = try LearningStore(
            path: tempDir.appendingPathComponent("store.sqlite").path)
        let pack = try frenchPack()
        let now = Date()
        let past = Date(timeIntervalSince1970: 1_700_000_000)

        // Empty store: nothing due, no next date.
        let empty = try ReviewCatalog.loadDue(packs: [pack], store: store, now: now)
        XCTAssertTrue(empty.due.isEmpty)
        XCTAssertNil(empty.nextDueAt)

        // Two past attempts on different evidence keys: both the
        // projection and loadDue must surface the same due set, and the
        // count can only come from the projection — there is nowhere
        // else for loadDue to read.
        try store.record(.attempt(try makeAttempt(
            id: "due-old-1", pack: pack,
            stepId: "fr-home-foundation-step-rb2", at: past)))
        try store.record(.attempt(try makeAttempt(
            id: "due-old-2", pack: pack,
            stepId: "fr-home-foundation-step-rb7", at: past)))

        let due = try ReviewCatalog.loadDue(packs: [pack], store: store, now: now)
        let progress = try store.project(pack: pack)
        XCTAssertEqual(due.due.count, 2)
        XCTAssertEqual(
            due.due.count,
            progress.evidence.values.filter { $0.fsrs.dueAt <= now }.count)
        for item in due.due {
            let record = try XCTUnwrap(progress.evidence[item.evidenceKey])
            XCTAssertLessThanOrEqual(record.fsrs.dueAt, now)
        }
    }

    func testFreshAttemptIsNotDueUntilItsSchedule() throws {
        let store = try LearningStore(
            path: tempDir.appendingPathComponent("store2.sqlite").path)
        let pack = try frenchPack()

        // Recorded now: FSRS schedules at least a day out, so the same
        // projection-driven path must NOT surface it as due.
        try store.record(.attempt(try makeAttempt(
            id: "due-future", pack: pack,
            stepId: "fr-home-foundation-step-rb2", at: Date())))

        let due = try ReviewCatalog.loadDue(packs: [pack], store: store)
        XCTAssertTrue(due.due.isEmpty)
        XCTAssertNotNil(due.nextDueAt, "the fresh schedule is the next due date")
    }
}

// MARK: - You tab phrase evidence (slice 2.1)

/// The profile's phrase lists must never claim things the events do not
/// prove: recognition stays recognition, hints stay hinted, a manual
/// "I know this" mark never implies mastery, independent typing is the
/// only thing that earns "built or typed", and self-comparing is
/// self-assessed practice — never speech evidence. These pin the pure
/// grouping function `YouModel.evidenceGroups` against real bundled
/// activities, so the derivation is exercised exactly as it runs in the
/// app (same lesson/step/activity wiring, same evidence keys).
@MainActor
final class YouPhraseEvidenceTests: XCTestCase {

    private func frenchPack() throws -> CoursePack {
        try XCTUnwrap(
            PackLoader.loadPacks().first { $0.language == .french })
    }

    private func italianPack() throws -> CoursePack {
        try XCTUnwrap(
            PackLoader.loadPacks().first { $0.language == .italian })
    }

    /// A stored-shape attempt on a real step of a real lesson, carrying
    /// the activity's own evidence key and revisions so it passes the
    /// same validation `LearningStore.project` applies.
    private func attempt(
        id: String, pack: CoursePack, lessonId: String, stepId: String,
        response: AttemptResponse,
        outcome: AttemptEvaluation.Outcome,
        independent: Bool,
        assistance: [AssistanceKind] = [],
        at: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) throws -> ActivityAttempt {
        let lesson = try XCTUnwrap(pack.lesson(id: lessonId))
        let step = try XCTUnwrap(lesson.steps.first { $0.id == stepId })
        let activity = try XCTUnwrap(pack.activity(id: step.activityId))
        return ActivityAttempt(
            id: id, packId: pack.id, packVersion: pack.version,
            lessonId: lesson.id, lessonRevision: lesson.revision,
            stepId: step.id, activityId: activity.id,
            activityRevision: activity.revision,
            evidenceKey: activity.evidenceKey,
            response: response, assistance: assistance,
            evaluation: AttemptEvaluation(
                outcome: outcome, independent: independent, feedback: "f"),
            at: at)
    }

    /// The attempt wrapped as a learning event, for the grouping function.
    private func attemptEvent(
        _ id: String, pack: CoursePack, lessonId: String, stepId: String,
        response: AttemptResponse,
        outcome: AttemptEvaluation.Outcome,
        independent: Bool,
        assistance: [AssistanceKind] = []
    ) throws -> LearningEvent {
        .attempt(try attempt(
            id: id, pack: pack, lessonId: lessonId, stepId: stepId,
            response: response, outcome: outcome,
            independent: independent, assistance: assistance))
    }

    private func phrases(
        _ groups: [YouModel.PhraseEvidence: [YouModel.EvidencePhrase]],
        _ kind: YouModel.PhraseEvidence
    ) -> [YouModel.EvidencePhrase] {
        groups[kind] ?? []
    }

    // MARK: Recognition

    /// A recognition success (selection on the real rb2 step) must be
    /// grouped as recognition — never as typed/built production.
    func testRecognitionSuccessLandsInRecognizedNotBuilt() throws {
        let pack = try frenchPack()
        let groups = YouModel.evidenceGroups(
            pack: pack,
            events: [
                try attemptEvent(
                    "sel-1", pack: pack, lessonId: "fr-home-foundation",
                    stepId: "fr-home-foundation-step-rb2",
                    response: .selection(ids: ["o1"]),
                    outcome: .correct, independent: true),
            ])
        XCTAssertTrue(phrases(groups, .built).isEmpty,
                      "recognition must never read as production")
        XCTAssertTrue(phrases(groups, .practicedWithHints).isEmpty)
        XCTAssertEqual(phrases(groups, .recognized).count, 1)
        XCTAssertTrue(phrases(groups, .speakingPractice).isEmpty)
    }

    // MARK: Assisted production

    /// A typed answer that is correct only because of a hint must be
    /// identified as assisted — never presented as independent production.
    func testAssistedOnlyTypedWorkIsWithHintsNotBuilt() throws {
        let pack = try frenchPack()
        let groups = YouModel.evidenceGroups(
            pack: pack,
            events: [
                try attemptEvent(
                    "text-1", pack: pack, lessonId: "fr-home-foundation",
                    stepId: "fr-home-foundation-step-rb8",
                    response: .text("Le chat est sur le livre."),
                    outcome: .correct, independent: false,
                    assistance: [.hint]),
            ])
        XCTAssertTrue(phrases(groups, .built).isEmpty,
                      "a hint-only success must never read as independent production")
        XCTAssertEqual(phrases(groups, .practicedWithHints).count, 1)
    }

    /// Hints used on one try do not erase a later clean solve: the phrase
    /// earns "built or typed" honestly and is not double-listed.
    func testHintsOnOtherTriesStillAllowIndependentProduction() throws {
        let pack = try frenchPack()
        let groups = YouModel.evidenceGroups(
            pack: pack,
            events: [
                try attemptEvent(
                    "text-1", pack: pack, lessonId: "fr-home-foundation",
                    stepId: "fr-home-foundation-step-rb8",
                    response: .text("Le chat est sur le livre."),
                    outcome: .correct, independent: false,
                    assistance: [.hint]),
                try attemptEvent(
                    "text-2", pack: pack, lessonId: "fr-home-foundation",
                    stepId: "fr-home-foundation-step-rb8",
                    response: .text("Le chat est sur le livre."),
                    outcome: .correct, independent: true),
            ])
        XCTAssertEqual(phrases(groups, .built).count, 1)
        XCTAssertTrue(phrases(groups, .practicedWithHints).isEmpty,
                      "one clean solve is enough; the hints row is not duplicated")
    }

    // MARK: Manual "I know this" marks

    /// A manual "I know this" mark is a lesson-known event, never attempt
    /// evidence: it must not add anything to any phrase group.
    func testKnownMarkAloneBuildsNoGroups() throws {
        let pack = try frenchPack()
        let lesson = try XCTUnwrap(pack.lesson(id: "fr-home-foundation"))
        let known = LessonKnownEvent(
            id: "known-1", packId: pack.id, packVersion: pack.version,
            lessonId: lesson.id, lessonRevision: lesson.revision,
            known: true, at: Date(timeIntervalSince1970: 1_700_000_000))
        let groups = YouModel.evidenceGroups(
            pack: pack, events: [.lessonKnown(known)])
        XCTAssertTrue(groups.isEmpty,
                      "a manual mark must never imply mastery in the phrase lists")
    }

    /// Even alongside real attempts, the mark adds no rows: the only
    /// phrases shown are the ones the attempts actually earned.
    func testKnownMarkAddsNothingAlongsideRealAttempts() throws {
        let pack = try frenchPack()
        let lesson = try XCTUnwrap(pack.lesson(id: "fr-home-foundation"))
        let known = LessonKnownEvent(
            id: "known-1", packId: pack.id, packVersion: pack.version,
            lessonId: lesson.id, lessonRevision: lesson.revision,
            known: true, at: Date(timeIntervalSince1970: 1_700_000_000))
        let groups = YouModel.evidenceGroups(
            pack: pack,
            events: [
                try attemptEvent(
                    "text-1", pack: pack, lessonId: "fr-home-foundation",
                    stepId: "fr-home-foundation-step-rb8",
                    response: .text("Le chat est sur le livre."),
                    outcome: .correct, independent: true),
                .lessonKnown(known),
            ])
        XCTAssertEqual(phrases(groups, .built).count, 1)
        XCTAssertTrue(phrases(groups, .recognized).isEmpty)
        XCTAssertEqual(
            groups.values.map(\.count).reduce(0, +), 1,
            "the known mark must not add rows anywhere")
    }

    // MARK: Independent production (positive control)

    /// Positive control: an independent typed success is the one thing
    /// that earns "built or typed".
    func testIndependentTypedSuccessLandsInBuilt() throws {
        let pack = try frenchPack()
        let lesson = try XCTUnwrap(pack.lesson(id: "fr-home-foundation"))
        let groups = YouModel.evidenceGroups(
            pack: pack,
            events: [
                try attemptEvent(
                    "text-1", pack: pack, lessonId: lesson.id,
                    stepId: "fr-home-foundation-step-rb8",
                    response: .text("Le chat est sur le livre."),
                    outcome: .correct, independent: true),
            ])
        let built = phrases(groups, .built)
        XCTAssertEqual(built.count, 1)
        let row = try XCTUnwrap(built.first)
        // phraseText quotes every accepted answer for the activity, joined
        // with " · " — pre-existing sayableText behavior the slice kept
        // unchanged — so derive the expectation from the pack rather than
        // hardcoding one answer.
        let step = try XCTUnwrap(
            lesson.steps.first { $0.id == "fr-home-foundation-step-rb8" })
        let activity = try XCTUnwrap(pack.activity(id: step.activityId))
        guard case .text(let spec) = activity else {
            return XCTFail("rb8 must be a text activity")
        }
        XCTAssertEqual(
            row.text, spec.answer.answers.joined(separator: " · "))
        XCTAssertEqual(row.context, lesson.title)
    }

    /// Cloze fills count as production too: a clean cloze success lands
    /// in "built or typed", never in recognition.
    func testIndependentClozeSuccessLandsInBuilt() throws {
        let pack = try frenchPack()
        let groups = YouModel.evidenceGroups(
            pack: pack,
            events: [
                try attemptEvent(
                    "cloze-1", pack: pack, lessonId: "fr-home-foundation",
                    stepId: "fr-home-foundation-step-rb7",
                    response: .cloze(values: ["b1": "Le"]),
                    outcome: .correct, independent: true),
            ])
        XCTAssertEqual(phrases(groups, .built).count, 1)
        XCTAssertTrue(phrases(groups, .recognized).isEmpty)
    }

    // MARK: Speaking practice

    /// Self-compare/self-rating activity is self-assessed practice: it
    /// lands only in the speaking-practice group (quoting the model line
    /// as practice material), never in any production group.
    func testSelfCompareLandsOnlyInSpeakingPractice() throws {
        let pack = try italianPack()
        let groups = YouModel.evidenceGroups(
            pack: pack,
            events: [
                try attemptEvent(
                    "say-1", pack: pack, lessonId: "it-people-foundation",
                    stepId: "it-people-foundation-step-say",
                    response: .selfRating(.comfortable),
                    outcome: .selfAssessed, independent: false),
            ])
        XCTAssertTrue(phrases(groups, .built).isEmpty)
        XCTAssertTrue(phrases(groups, .practicedWithHints).isEmpty)
        XCTAssertTrue(phrases(groups, .recognized).isEmpty)
        let speaking = phrases(groups, .speakingPractice)
        XCTAssertEqual(speaking.count, 1)
        let row = try XCTUnwrap(speaking.first)
        XCTAssertEqual(
            row.text, "Tu sei Marco.",
            "the model line is quoted as practice material, never as own output")
    }

    // MARK: Validation

    /// A stale-revision attempt (content changed since it was recorded)
    /// must not feed the groups — the same quarantine rule
    /// `LearningStore.project` applies to SRS state.
    func testStaleRevisionAttemptDoesNotFeedGroups() throws {
        let pack = try frenchPack()
        let lesson = try XCTUnwrap(pack.lesson(id: "fr-home-foundation"))
        let step = try XCTUnwrap(
            lesson.steps.first { $0.id == "fr-home-foundation-step-rb8" })
        let activity = try XCTUnwrap(pack.activity(id: step.activityId))
        let stale = ActivityAttempt(
            id: "stale-1", packId: pack.id, packVersion: pack.version,
            lessonId: lesson.id, lessonRevision: lesson.revision + 1,
            stepId: step.id, activityId: activity.id,
            activityRevision: activity.revision,
            evidenceKey: activity.evidenceKey,
            response: .text("Le chat est sur le livre."),
            assistance: [],
            evaluation: AttemptEvaluation(
                outcome: .correct, independent: true, feedback: "f"),
            at: Date(timeIntervalSince1970: 1_700_000_000))
        let groups = YouModel.evidenceGroups(
            pack: pack, events: [.attempt(stale)])
        XCTAssertTrue(groups.isEmpty,
                      "stale attempts must be quarantined, not quoted")
    }

    // MARK: Labels

    /// The labels are data-driven (the enum is the single source) and
    /// plain: nothing claims the learner "can say" anything.
    func testLabelsArePlainAndNeverClaimSpeech() {
        XCTAssertEqual(
            YouModel.PhraseEvidence.built.label, "Phrases you built or typed")
        XCTAssertEqual(
            YouModel.PhraseEvidence.practicedWithHints.label,
            "Phrases you practised (with hints)")
        XCTAssertEqual(
            YouModel.PhraseEvidence.recognized.label, "Phrases you recognised")
        XCTAssertEqual(
            YouModel.PhraseEvidence.speakingPractice.label,
            "Speaking practice (self-assessed)")
        XCTAssertEqual(
            YouModel.PhraseEvidence.practiced.label, "Phrases you practised")
    }
}
