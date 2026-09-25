import XCTest
@testable import Condisco

/// Placement math: every answer counts, weighted by course position.
/// The required regression case — [wrong, correct × 7] — must place
/// sensibly, never at lesson zero. These tests exercise only the pure
/// scoring helpers, so they need no pack fixture.
final class PlacementTests: XCTestCase {

    /// Eight questions evenly spread over a 50-lesson course, matching
    /// how `PlacementBuilder.build` samples. Returns the questions and
    /// the ids of the correct answers for a first-question miss.
    private func firstMissQuestions() -> ([PlacementQuestion], Set<UUID>) {
        var questions: [PlacementQuestion] = []
        for i in 0..<8 {
            questions.append(PlacementQuestion(
                target: "q\(i)",
                options: ["a", "b", "c"],
                correctIndex: 0,
                lessonIndex: i * 50 / 8))
        }
        let correctIds = Set(questions.dropFirst().map(\.id))
        return (questions, correctIds)
    }

    func testFirstMissThenSevenCorrectNeverPlacesAtStart() {
        let (questions, correctIds) = firstMissQuestions()
        let score = PlacementBuilder.score(
            questions: questions, correctIds: correctIds)
        // Seven correct answers, weighted toward the later lessons: the
        // score must stay high, not collapse on the opening miss.
        XCTAssertGreaterThan(score, 0.9)
        // Over a 50-lesson course with the victory lap at lesson 40, the
        // miss must not strand the learner at the beginning.
        let index = PlacementBuilder.lessonIndex(
            forScore: score, lessonCount: 50, victoryIndex: 40)
        XCTAssertGreaterThan(index, 30)
        XCTAssertLessThanOrEqual(index, 40)
    }

    func testPerfectScoreMapsToVictoryIndex() {
        let (questions, _) = firstMissQuestions()
        let allCorrect = Set(questions.map(\.id))
        let score = PlacementBuilder.score(
            questions: questions, correctIds: allCorrect)
        XCTAssertEqual(score, 1, accuracy: 0.0001)
        XCTAssertEqual(
            PlacementBuilder.lessonIndex(
                forScore: score, lessonCount: 50, victoryIndex: 40),
            40)
    }

    func testBlankScoreMapsToStart() {
        let (questions, _) = firstMissQuestions()
        let score = PlacementBuilder.score(
            questions: questions, correctIds: [])
        XCTAssertEqual(score, 0, accuracy: 0.0001)
        XCTAssertEqual(
            PlacementBuilder.lessonIndex(
                forScore: score, lessonCount: 50, victoryIndex: 40),
            0)
    }

    func testScoreNeverOutranksVictoryIndex() {
        let (questions, _) = firstMissQuestions()
        let allCorrect = Set(questions.map(\.id))
        let score = PlacementBuilder.score(
            questions: questions, correctIds: allCorrect)
        // A short course: even a perfect score caps at the victory lap.
        XCTAssertEqual(
            PlacementBuilder.lessonIndex(
                forScore: score, lessonCount: 5, victoryIndex: 3),
            3)
    }

    func testScoreClampsOutOfRange() {
        XCTAssertEqual(
            PlacementBuilder.lessonIndex(
                forScore: 2.5, lessonCount: 50, victoryIndex: 40),
            40)
        XCTAssertEqual(
            PlacementBuilder.lessonIndex(
                forScore: -0.5, lessonCount: 50, victoryIndex: 40),
            0)
    }

    func testBandJoining() {
        XCTAssertEqual(PlacementBand.joining([]), "")
        XCTAssertEqual(
            PlacementBand.joining([.early]), "the early lessons")
        XCTAssertEqual(
            PlacementBand.joining([.early, .late]),
            "the early lessons and the later lessons")
        XCTAssertEqual(
            PlacementBand.joining([.early, .middle, .late]),
            "the early lessons, the middle of the course, and the later lessons")
    }

    func testMissingAccentExplainsExactCorrectionAndAllowsProgress() {
        let spec = AnswerSpec(answers: ["café"], allowTypo: true, errors: [])
        let result = AnswerEngine.evaluate(response: "cafe", spec: spec)
        XCTAssertTrue(result.accepted)
        XCTAssertEqual(result.credit, .partial)
        XCTAssertEqual(result.correction, "café")
        XCTAssertTrue(result.explanation.contains("café"))
    }

    func testShortMeaningChangingAccentStillNeedsExplanation() {
        let spec = AnswerSpec(answers: ["à"], allowTypo: true, errors: [])
        let result = AnswerEngine.evaluate(response: "a", spec: spec)
        XCTAssertFalse(result.accepted)
        XCTAssertEqual(result.correction, "à")
        XCTAssertTrue(result.explanation.contains("à"))
    }

    func testBeginnerCanOmitAccentAndApostropheInSamePhrase() {
        let spec = AnswerSpec(
            answers: ["Un café, s’il vous plaît."], allowTypo: true, errors: [])
        let result = AnswerEngine.evaluate(
            response: "Un cafe sil vous plait", spec: spec)
        XCTAssertTrue(result.accepted)
        XCTAssertEqual(result.credit, .partial)
        XCTAssertEqual(result.correction, "Un café, s’il vous plaît.")
    }
}

final class LessonContextTests: XCTestCase {
    func testStoryQuestionShowsMostRecentStoryBeat() throws {
        let pack = try XCTUnwrap(PackLoader.loadPacks().first { $0.language == .french })
        let lesson = try XCTUnwrap(pack.lesson(id: "fr-home-foundation"))
        let visited = Array(lesson.steps.prefix(4).map(\.id))
        let stimulus = currentContextStimulus(
            pack: pack, lesson: lesson, visitedStepIds: visited,
            activeStepId: lesson.steps[3].id)
        XCTAssertEqual(stimulus?.id, "fr-home-foundation-stim-rb3")
    }

    func testRevisitedStoryQuestionDoesNotShowLaterSpoiler() throws {
        let pack = try XCTUnwrap(PackLoader.loadPacks().first { $0.language == .french })
        let lesson = try XCTUnwrap(pack.lesson(id: "fr-home-foundation"))
        let stimulus = currentContextStimulus(
            pack: pack, lesson: lesson,
            visitedStepIds: lesson.steps.map(\.id),
            activeStepId: lesson.steps[3].id)
        XCTAssertEqual(stimulus?.id, "fr-home-foundation-stim-rb3")
    }
}
