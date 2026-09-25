import Foundation

/// Compile with the production models, loader and evaluation engine (see check_packs.sh).
@main
struct CheckPacks {
    static func main() throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments[1])
        var loaded: [String] = []
        var failures: [String] = []
        var sharedFeedbackChecks = 0
        for name in PackLoader.packFilenames {
            do {
                let data = try Data(contentsOf: directory.appendingPathComponent("\(name).json"))
                let pack = try JSONDecoder().decode(CoursePack.self, from: data)
                try PackValidator.validate(pack)
                precondition(pack.language.slug == name)
                for activity in pack.activities {
                    guard case .dialogueChoice(let spec) = activity else { continue }
                    for option in spec.options {
                        let evaluation = ActivityEvaluation.evaluate(
                            activity: activity, response: .selection(ids: [option.id]), assistance: [])
                        precondition(evaluation.feedback == (option.feedback ?? spec.base.feedback))
                        if option.feedback == nil { sharedFeedbackChecks += 1 }
                    }
                }
                // Historical IDs may survive rewritten lessons, but an active
                // legacy-success policy must reject nonexistent exercises.
                if name == "spanish" {
                    var raw = try JSONSerialization.jsonObject(with: data) as! [String: Any]
                    var lessons = raw["lessons"] as! [[String: Any]]
                    let index = lessons.firstIndex { $0["id"] as? String == "es-directions-foundation" }!
                    lessons[index]["completionPolicy"] = [
                        "kind": "legacy-success",
                        "exerciseIds": lessons[index]["legacyCompletionExerciseIds"]!
                    ]
                    raw["lessons"] = lessons
                    let invalid = try JSONDecoder().decode(CoursePack.self, from: JSONSerialization.data(withJSONObject: raw))
                    var rejected = false
                    do { try PackValidator.validate(invalid) } catch { rejected = true }
                    precondition(rejected, "Active legacy policy accepted missing exercises")
                }
                loaded.append(name)
                print("PASS \(name): \(pack.lessons.count) lessons")
            } catch {
                failures.append("\(name): \(error)")
            }
        }
        for failure in failures { print("FAIL \(failure)") }
        precondition(failures.isEmpty, "Bundled languages failed to load")
        precondition(Set(loaded) == Set(["french", "italian", "german", "portuguese", "spanish"]))
        let pickerPacks = try PackLoader.loadPacks()
        precondition(pickerPacks.map { $0.language.slug } == loaded,
                     "The onboarding loader must return all five languages")
        precondition(sharedFeedbackChecks > 0)
        print("PASS all five languages; \(sharedFeedbackChecks) shared-feedback replies; invalid legacy policy rejected")
    }
}
