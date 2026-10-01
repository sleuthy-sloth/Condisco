import XCTest
@testable import Condisco

/// The four new first-mission follow-ups must be reachable in the actual
/// lesson graph, playable through the declared audio fallback, and include a
/// distinct response to the situation before the existing closing task.
final class OpeningMissionTests: XCTestCase {
    private struct Scenario {
        let slug: String
        let prefix: String
        let cue: String
        let response: String
        let decisionActivity: String
        let decisionAnswer: String
    }

    private let scenarios: [Scenario] = [
        .init(slug: "french", prefix: "fr", cue: "sans sucre",
              response: "Sans sucre, merci.",
              decisionActivity: "fr-cafe-listen-choice", decisionAnswer: "Sans sucre"),
        .init(slug: "german", prefix: "de", cue: "Zum Mitnehmen",
              response: "Zum Mitnehmen, bitte.",
              decisionActivity: "de-cafe-listen-choice", decisionAnswer: "Zum Mitnehmen"),
        .init(slug: "italian", prefix: "it", cue: "Al banco",
              response: "Al banco, grazie.",
              decisionActivity: "it-cafe-listen-choice", decisionAnswer: "Al banco"),
        .init(slug: "portuguese", prefix: "pt", cue: "pastel de nata",
              response: "Sim, um pastel de nata, por favor.",
              decisionActivity: "pt-cafe-listen-choice", decisionAnswer: "Sim, um pastel de nata"),
    ]

    func testFirstMissionsReachListeningAndFinishAtTheirExistingClosingTask() throws {
        let packs = try PackLoader.loadPacks()
        for scenario in scenarios {
            let pack = try XCTUnwrap(packs.first { $0.language.slug == scenario.slug })
            let lesson = try XCTUnwrap(pack.lesson(id: "\(scenario.prefix)-cafe-mission"))
            let steps = Dictionary(uniqueKeysWithValues: lesson.steps.map { ($0.id, $0) })
            let base = "\(scenario.prefix)-cafe-mission-step-"
            XCTAssertEqual(lesson.steps.count, 12, scenario.slug)
            XCTAssertEqual(steps[base + "8"]?.nextStepId, base + "10", scenario.slug)
            for number in 10...13 {
                XCTAssertEqual(steps[base + "\(number)"]?.nextStepId,
                               base + "\(number + 1)", scenario.slug)
            }
            XCTAssertEqual(steps[base + "14"]?.nextStepId, base + "9", scenario.slug)
            XCTAssertNil(steps[base + "9"]?.nextStepId, scenario.slug)

            let stimulusId = "\(scenario.prefix)-cafe-listen-stim"
            let audioId = "\(scenario.prefix)-cafe-listen-audio"
            guard case .audio(_, let mediaId)? = pack.stimulus(id: stimulusId) else {
                return XCTFail("\(scenario.slug): missing audio stimulus")
            }
            XCTAssertEqual(mediaId, audioId)
            guard case .audio(_, _, _, let attribution, let transcript)? = pack.media(id: audioId) else {
                return XCTFail("\(scenario.slug): missing audio media")
            }
            XCTAssertTrue(transcript.localizedCaseInsensitiveContains(scenario.cue), scenario.slug)
            XCTAssertTrue(attribution.contains("reviewPending: true"), scenario.slug)
            guard case .information(let notice)? = pack.activity(id: "\(scenario.prefix)-cafe-listen-act-1") else {
                return XCTFail("\(scenario.slug): missing listening introduction")
            }
            XCTAssertEqual(notice.stimulusId, stimulusId)
        }
    }

    func testFirstMissionFollowUpsCheckMeaningAndInviteDistinctReply() throws {
        let packs = try PackLoader.loadPacks()
        for scenario in scenarios {
            let pack = try XCTUnwrap(packs.first { $0.language.slug == scenario.slug })
            guard case .selection(let choice)? = pack.activity(id: scenario.decisionActivity) else {
                return XCTFail("\(scenario.slug): missing situation choice")
            }
            XCTAssertEqual(choice.base.stimulusId,
                           "\(scenario.prefix)-cafe-listen-stim", scenario.slug)
            XCTAssertTrue(choice.base.skills.contains(.listening), scenario.slug)
            XCTAssertFalse(choice.multiple, scenario.slug)
            XCTAssertEqual(choice.acceptedIds.count, 1, scenario.slug)
            let accepted = try XCTUnwrap(choice.options.first { $0.id == choice.acceptedIds[0] })
            XCTAssertEqual(accepted.text, scenario.decisionAnswer, scenario.slug)
            XCTAssertTrue(choice.options.contains { $0.id != accepted.id }, scenario.slug)

            guard case .selfCompare(let say)? = pack.activity(id: "\(scenario.prefix)-cafe-listen-say") else {
                return XCTFail("\(scenario.slug): missing learner response")
            }
            XCTAssertEqual(say.modelText, scenario.response, scenario.slug)
            XCTAssertTrue(say.skills.contains(.speaking), scenario.slug)
            XCTAssertEqual(say.modelAudioId, "\(scenario.prefix)-cafe-listen-model", scenario.slug)
            XCTAssertTrue(pack.media(id: say.modelAudioId!)?.isAudio == true, scenario.slug)
        }
    }
}


@MainActor
final class EarlyListeningPracticeTests: XCTestCase {
    func testFirstTwoUnitsHaveReachableListenDecideAndOpenReplySlices() throws {
        let packs = try PackLoader.loadPacks()
        for slug in ["german", "portuguese"] {
            let pack = try XCTUnwrap(packs.first { $0.language.slug == slug })
            let prefix = slug == "german" ? "de" : "pt"
            for topic in ["introductions", "numbers-quantities"] {
                let lesson = try XCTUnwrap(pack.lesson(id: "\(prefix)-\(topic)-foundation"))
                let stem = "\(prefix)-\(topic)-listen"
                let gist = try XCTUnwrap(pack.activity(id: stem + "-gist"))
                let detail = try XCTUnwrap(pack.activity(id: stem + "-detail"))
                for activity in [gist, detail] {
                    guard case .selection(let spec) = activity else {
                        return XCTFail("listening decisions must be choices")
                    }
                    XCTAssertTrue(spec.base.skills.contains(.listening))
                    XCTAssertEqual(spec.acceptedIds.count, 1)
                    XCTAssertGreaterThan(spec.options.count, 1)
                    XCTAssertNotNil(spec.base.stimulusId.flatMap { pack.stimulus(id: $0) })
                }
                guard case .openTask(let reply)? = pack.activity(id: stem + "-reply") else {
                    return XCTFail("spoken reply must remain self-assessed, not fixed-answer graded")
                }
                XCTAssertEqual(reply.mode, .spoken)
                XCTAssertGreaterThanOrEqual(reply.rubric.count, 3)
                XCTAssertTrue(reply.skills.contains(.speaking))
                let steps = Dictionary(uniqueKeysWithValues: lesson.steps.map { ($0.id, $0) })
                var cursor: String? = lesson.entryStepId
                var visited = Set<String>()
                var activities = Set<String>()
                while let id = cursor, visited.insert(id).inserted {
                    let step = try XCTUnwrap(steps[id])
                    activities.insert(step.activityId)
                    cursor = step.nextStepId
                }
                XCTAssertTrue(activities.contains(stem + "-gist"))
                XCTAssertTrue(activities.contains(stem + "-detail"))
                XCTAssertTrue(activities.contains(stem + "-reply"))
            }
        }
    }
}
