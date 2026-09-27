import CryptoKit
import Foundation

/// Compile with the production models, loader and evaluation engine (see check_packs.sh).
///
/// Beyond structural validation, this checker now verifies the *media
/// inventory*: every `url` declared in a pack's `media` array and every Listen
/// track `audioUrl` must resolve to an actual file under the Content root,
/// with an extension matching the declared kind and (when declared) a matching
/// SHA-256. Missing assets listed in `tools/device-speech-media.txt` are
/// intentional — the step is delivered by on-device speech instead of a
/// recording — and report as "device-speech (intentional)" rather than ERROR.
///
/// Additional integrity gates (all fail with exit 1):
///   - Attribution citation check: every `docs/...` path referenced from an
///     attribution string must exist under the repo root (docs/audio-provenance).
///   - Listen track duration: `durationS` must match the real audio duration
///     (measured via `afinfo`, `ffprobe` fallback) within 1.0 s.
///   - Listen track section boundaries: `sections[].startS` must be strictly
///     increasing, >= 0, and <= `durationS`, and a track must not be empty.
///   - Device-speech allowlist audit: every allowlisted asset must be
///     referenced by a lesson step that shows nonempty learner-visible text
///     (prompt/transcript); a silent step fails the gate.
///
/// Phase 5.4 adds a structural integrity pass (all fail with exit 1):
///   - Reference integrity: legacy-exercise `reviewOf` targets must name a
///     lesson in the pack; legacy-exercise `conceptId`/`vocabulary` must
///     resolve; per-example `mediaId` (examples stimuli and concept examples)
///     must name a declared audio item; standalone dialogue `prerequisite`
///     must name a lesson. (Lesson prerequisites, activity conceptIds/
///     vocabulary, stimulus/activity/step links and the primary media refs —
///     stimulus audio/scene, dialogue-turn media, self-compare model audio,
///     legacy dictation — are already enforced inside PackValidator, so the
///     pass only covers the gaps.)
///   - Lesson reachability: every lesson must be transitively reachable from
///     an entry lesson (a lesson with no prerequisites), with no prerequisite
///     cycles.
///   - Unsupported activity kinds: rejected at decode time by Codable
///     (Activity/Stimulus/CheckpointItem inits throw on an unknown `kind`);
///     a minimal-pack decode probe re-verifies the rejection so a future
///     forgiving decode cannot smuggle an unknown kind past the gate.
///   - Checkpoint unseen wording (plan 5.3): a checkpoint item's writing/
///     speaking prompt or reading question must not exactly repeat — after a
///     trivial normalization (casefold, strip whitespace/punctuation, keep
///     diacritics) — any lesson activity prompt in the same pack.
@main
struct CheckPacks {
    /// File extensions accepted per media kind. The app plays these natively;
    /// anything else is a packaging mistake (see MediaResolver / AVPlayer).
    private static let audioExtensions: Set<String> =
        ["mp3", "m4a", "wav", "caf", "aiff", "aif"]
    private static let imageExtensions: Set<String> =
        ["png", "jpg", "jpeg", "heic"]

    static func main() throws {
        guard CommandLine.arguments.count >= 2 else {
            print("usage: check-packs <ContentRoot> [allowlist-file]")
            exit(2)
        }
        let contentRoot = URL(fileURLWithPath: CommandLine.arguments[1])
        let packsDir = contentRoot.appendingPathComponent("packs", isDirectory: true)
        let allowlistURL: URL? = CommandLine.arguments.count > 2
            ? URL(fileURLWithPath: CommandLine.arguments[2]) : nil

        var loaded: [String] = []
        var failures: [String] = []
        var sharedFeedbackChecks = 0
        var decodedPacks: [CoursePack] = []
        for name in PackLoader.packFilenames {
            do {
                let data = try Data(contentsOf: packsDir.appendingPathComponent("\(name).json"))
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
                decodedPacks.append(pack)
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

        // Checkpoint task bank (5.3A) summary. The structural checks — task
        // ids unique/stable, items never referenced by lesson steps, modality
        // coverage ⊆ declaration, reading/rubric well-formedness — run inside
        // PackValidator.validate above; this line just makes the bank visible
        // in the tool output.
        for pack in decodedPacks where !pack.checkpoints.isEmpty {
            print("PASS \(pack.id) checkpoints: "
                + pack.checkpoints.map {
                    "\($0.id)[\($0.stage.rawValue), \($0.items.count) items]"
                }.joined(separator: ", "))
        }

        // Phase 6.1A sustained-material summary. The shape checks — ordered
        // unique markers, question kinds/answers, glossary, provenance,
        // transcript, voice tags + fallback rule, host-step references,
        // orphan discipline — run inside PackValidator.validate above; this
        // line just makes the authored inventory visible in the tool output.
        for pack in decodedPacks where !pack.sustainedTexts.isEmpty || !pack.sustainedListenings.isEmpty {
            let genres = pack.sustainedTexts.map(\.genre.rawValue).joined(separator: ", ")
            let listeningSummary = pack.sustainedListenings.map { passage in
                "\(passage.id)[\(passage.sections.count) sections, \(Set(passage.sections.map(\.voiceId)).count) voices]"
            }.joined(separator: ", ")
            print("PASS \(pack.id) sustained: \(pack.sustainedTexts.count) text(s) [\(genres)], \(pack.sustainedListenings.count) listening passage(s) — \(listeningSummary)")
        }

        // Phase 6.3 branching-exchange summary. The graph checks —
        // reachability, no dead ends, explicit end states, >= 3 turns per
        // path, clarification/misunderstanding recovery routes, open-turn
        // rubric well-formedness, host binding — run inside
        // PackValidator.validate above; this line just makes the authored
        // exchange inventory visible in the tool output. Pre-6.3 dialogues
        // (French/Italian) show as validated-only entries without a host.
        for pack in decodedPacks where !pack.dialogues.isEmpty {
            let summary = pack.dialogues.map { dialogue in
                let host = dialogue.hostLessonId.map { "host \($0)" } ?? "validated-only"
                return "\(dialogue.id)[\(host), \(dialogue.nodes.count) nodes]"
            }.joined(separator: ", ")
            print("PASS \(pack.id) dialogues: \(summary)")
        }

        // Phase 5.4 structural pass: reference integrity, lesson
        // reachability, unknown-kind decode rejection, and checkpoint
        // unseen-wording. Each verify* function prints its own result line
        // with counts so the gate log shows the check ran.
        print("== structural integrity (5.4) ==")
        var structureErrors: [String] = []
        structureErrors.append(contentsOf: verifyReferenceIntegrity(decodedPacks))
        structureErrors.append(contentsOf: verifyReachability(decodedPacks))
        structureErrors.append(contentsOf: verifyUnknownKindsRejected())
        structureErrors.append(contentsOf: verifyCheckpointWording(decodedPacks))
        structureErrors.append(contentsOf: verifySustainedWording(decodedPacks))
        structureErrors.append(contentsOf: verifyOpenTaskWording(decodedPacks))
        structureErrors.append(contentsOf: verifyDialogueWording(decodedPacks))
        if !structureErrors.isEmpty {
            print("FAIL structural integrity: \(structureErrors.count) violation(s)")
            for error in structureErrors { print("ERROR \(error)") }
            exit(1)
        }
        print("PASS structural integrity: references resolve; every lesson reachable from a fresh start; checkpoints use unseen wording; sustained questions use unseen wording; open tasks use unseen wording; exchanges use unseen wording; unknown kinds rejected by decode")

        let allowlist = loadAllowlist(url: allowlistURL)
        var errors: [String] = []

        let mediaErrors = verifyMedia(decodedPacks, contentRoot: contentRoot, allowlist: allowlist)
        errors.append(contentsOf: mediaErrors)
        if !errors.isEmpty {
            print("FAIL: \(errors.count) media asset error(s)")
            for error in errors { print("ERROR \(error)") }
            exit(1)
        }
        print("PASS Content media inventory: every declared asset resolves with matching type/hash, or is allowlisted for device speech")

        // Attribution citation check: every `docs/...` reference in an
        // attribution string must resolve to a real file under the repo root.
        print("== attribution citations ==")
        let repoRoot = contentRoot.deletingLastPathComponent().deletingLastPathComponent()
        errors.append(contentsOf: checkAttributionCitations(decodedPacks, repoRoot: repoRoot))
        if !errors.isEmpty {
            print("FAIL: \(errors.count) attribution citation error(s)")
            for error in errors { print("ERROR \(error)") }
            exit(1)
        }
        print("PASS attribution citations: every docs/… reference resolves to a file in the repo")

        // Listen track integrity: real duration vs durationS, section
        // boundaries, and the device-speech allowlist text audit.
        print("== listen-tracks integrity ==")
        errors.append(contentsOf: verifyListenTracks(decodedPacks, contentRoot: contentRoot))
        errors.append(contentsOf: auditAllowlistText(decodedPacks, allowlist: allowlist))
        if !errors.isEmpty {
            print("FAIL: \(errors.count) listen/allowlist integrity error(s)")
            for error in errors { print("ERROR \(error)") }
            exit(1)
        }
        print("PASS listen tracks: declared durations match the audio; sections are ordered and in range; every device-speech step has visible text")
    }

    // MARK: - Structural integrity (Phase 5.4)

    /// Trivially-normalized comparable form for the checkpoint unseen-wording
    /// check (plan 5.3): casefold, then drop everything that is not a letter
    /// or digit. Diacritics survive on purpose — the rubric's R1 keeps
    /// distinguishing accents meaningful (café ≠ cafe). Exact-normalized match
    /// only; fuzzy/similarity scoring stays in audit_editorial.
    private static func normalizedComparable(_ text: String) -> String {
        var out = String.UnicodeScalarView()
        for scalar in text.folding(options: .caseInsensitive, locale: nil).unicodeScalars {
            if CharacterSet.letters.contains(scalar) || CharacterSet.decimalDigits.contains(scalar) {
                out.append(scalar)
            }
        }
        return String(out)
    }

    /// Rotate a detected cycle so it starts at its lexicographically smallest
    /// element, keeping the reported chain stable across runs.
    private static func canonicalCycle(_ cycle: [String]) -> [String] {
        var body = Array(cycle.dropLast())
        guard !body.isEmpty else { return cycle }
        var best = body
        var cursor = body
        for _ in 0..<body.count {
            if cursor.lexicographicallyPrecedes(best) { best = cursor }
            cursor.append(cursor.removeFirst())
        }
        return best + [best[0]]
    }

    /// Reference integrity over the gaps PackValidator does not cover:
    /// legacy-exercise `reviewOf` targets, legacy-exercise `conceptId` and
    /// `vocabulary`, per-example `mediaId` (examples stimuli, concept
    /// examples), and standalone-dialogue `prerequisite` gates. Every
    /// reference must resolve to a defined entity in the same pack.
    private static func verifyReferenceIntegrity(_ packs: [CoursePack]) -> [String] {
        var errors: [String] = []
        var totalReview = 0
        var totalLegacy = 0
        var totalExample = 0
        var totalDialogue = 0
        for pack in packs {
            let lessonIds = Set(pack.lessons.map { $0.id })
            let conceptIds = Set(pack.concepts.map { $0.id })
            let vocabIds = Set(pack.vocabulary.map { $0.id })
            let mediaById = Dictionary(uniqueKeysWithValues: pack.media.map { ($0.id, $0) })
            var packErrors = 0
            func fail(_ message: String) {
                packErrors += 1
                print("  FAIL \(message)")
                errors.append(message)
            }

            var reviewRefs = 0
            var legacyRefs = 0
            var exampleRefs = 0
            var dialogueRefs = 0

            // Legacy v1 exercises: reviewOf targets are lesson ids; conceptId
            // and vocabulary must resolve like their v2 counterparts.
            for lesson in pack.lessons {
                for exercise in lesson.legacyExercises {
                    let base = exercise.base
                    legacyRefs += 1
                    if !conceptIds.contains(base.conceptId) {
                        fail("\(pack.id) legacy \(exercise.id) (lesson \(lesson.id)): conceptId \(base.conceptId) is not a concept in this pack")
                    }
                    for vocab in base.vocabulary where !vocabIds.contains(vocab) {
                        fail("\(pack.id) legacy \(exercise.id) (lesson \(lesson.id)): vocabulary \(vocab) is not a vocabulary item in this pack")
                    }
                    for target in base.reviewOf {
                        reviewRefs += 1
                        if !lessonIds.contains(target) {
                            fail("\(pack.id) legacy \(exercise.id) (lesson \(lesson.id)): reviewOf target \(target) is not a lesson in this pack")
                        }
                    }
                }
            }

            // Per-example pronunciation audio: a mediaId on an examples pair
            // or a concept example must name a declared audio item (the
            // runtime plays exactly this media; a dangling id silently falls
            // back to on-device TTS — StimulusViews.audioURL).
            for stimulus in pack.stimuli {
                guard case .examples(_, let pairs) = stimulus else { continue }
                for pair in pairs {
                    guard let mediaId = pair.mediaId else { continue }
                    exampleRefs += 1
                    guard let media = mediaById[mediaId], media.isAudio else {
                        fail("\(pack.id) stimulus \(stimulus.id): per-example mediaId \(mediaId) does not resolve to a declared audio item")
                        continue
                    }
                }
            }
            for concept in pack.concepts {
                for example in concept.examples {
                    guard let mediaId = example.mediaId else { continue }
                    exampleRefs += 1
                    guard let media = mediaById[mediaId], media.isAudio else {
                        fail("\(pack.id) concept \(concept.id): per-example mediaId \(mediaId) does not resolve to a declared audio item")
                        continue
                    }
                }
            }

            // Standalone dialogue graphs name the lesson they gate.
            for dialogue in pack.dialogues {
                dialogueRefs += 1
                if !lessonIds.contains(dialogue.prerequisite) {
                    fail("\(pack.id) dialogue \(dialogue.id): prerequisite \(dialogue.prerequisite) is not a lesson in this pack")
                }
            }

            totalReview += reviewRefs
            totalLegacy += legacyRefs
            totalExample += exampleRefs
            totalDialogue += dialogueRefs
            print("  \(packErrors == 0 ? "ok" : "FAIL") \(pack.id): \(reviewRefs) reviewOf, \(legacyRefs) legacy concept/vocab, \(exampleRefs) example-media, \(dialogueRefs) dialogue refs checked")
        }
        print("\(errors.isEmpty ? "PASS" : "FAIL") reference integrity: \(totalReview) reviewOf refs, \(totalLegacy) legacy concept/vocabulary sets, \(totalExample) example-level media refs, \(totalDialogue) dialogue gates — every reference resolves (lesson prerequisites and activity-level refs are PackValidator territory)")
        return errors
    }

    /// Lesson reachability: every lesson must be transitively reachable from
    /// an entry lesson (a lesson with no prerequisites), and the prerequisite
    /// graph must be cycle-free. Parallel/optional lessons are entries
    /// themselves, so stand-alone construction/recall/mission islands never
    /// trip the gate; a lesson whose only route runs through a dangling
    /// prerequisite is reported as unreachable (PackValidator already fails
    /// on the dangling prerequisite itself). Current packs: all 255 lessons
    /// are reachable from 7 entry lessons per pack with zero cycles, so this
    /// is a hard gate, not a warning.
    private static func verifyReachability(_ packs: [CoursePack]) -> [String] {
        var errors: [String] = []
        var totalLessons = 0
        var totalUnreachable = 0
        for pack in packs {
            let lessonsById = Dictionary(uniqueKeysWithValues: pack.lessons.map { ($0.id, $0) })
            let prerequisitesOf = Dictionary(uniqueKeysWithValues: pack.lessons.map { lesson in
                (lesson.id, lesson.prerequisites.map { $0.lessonId })
            })

            // Cycle detection (three-color DFS), reported in canonical form.
            var cycles: [[String]] = []
            var cycleKeys = Set<String>()
            var visiting = Set<String>()
            var finished = Set<String>()
            func dfs(_ id: String, _ stack: inout [String]) {
                if finished.contains(id) { return }
                if visiting.contains(id) {
                    if let from = stack.firstIndex(of: id) {
                        let canon = canonicalCycle(Array(stack.suffix(from: from)) + [id])
                        let key = canon.joined(separator: "→")
                        if cycleKeys.insert(key).inserted { cycles.append(canon) }
                    }
                    return
                }
                visiting.insert(id)
                stack.append(id)
                for prereq in prerequisitesOf[id] ?? [] where lessonsById[prereq] != nil {
                    dfs(prereq, &stack)
                }
                stack.removeLast()
                visiting.remove(id)
                finished.insert(id)
            }
            for id in pack.lessons.map({ $0.id }).sorted() {
                var stack: [String] = []
                dfs(id, &stack)
            }
            cycles.sort { $0.joined(separator: "→") < $1.joined(separator: "→") }
            for cycle in cycles {
                let msg = "\(pack.id): prerequisite cycle \(cycle.joined(separator: " → "))"
                print("  FAIL \(msg)")
                errors.append(msg)
            }

            // Fixed-point reachability from entry lessons (no prerequisites).
            var reachable = Set<String>()
            var changed = true
            while changed {
                changed = false
                for lesson in pack.lessons where !reachable.contains(lesson.id) {
                    let prereqs = prerequisitesOf[lesson.id] ?? []
                    if prereqs.allSatisfy({ reachable.contains($0) }) {
                        reachable.insert(lesson.id)
                        changed = true
                    }
                }
            }
            let unreachable = pack.lessons.map { $0.id }.filter { !reachable.contains($0) }.sorted()
            totalLessons += pack.lessons.count
            totalUnreachable += unreachable.count
            if !unreachable.isEmpty {
                let msg = "\(pack.id): \(unreachable.count) lesson(s) unreachable from any entry lesson (a lesson with no prerequisites): \(unreachable.joined(separator: ", "))"
                print("  FAIL \(msg)")
                errors.append(msg)
            }
            let roots = pack.lessons.filter { $0.prerequisites.isEmpty }.count
            print("  \(unreachable.isEmpty && cycles.isEmpty ? "ok" : "FAIL") \(pack.id): \(pack.lessons.count) lessons, \(roots) entry lessons, \(unreachable.count) unreachable, \(cycles.count) cycles")
        }
        let reachabilitySummary = totalUnreachable == 0
            ? "every lesson is transitively reachable from a fresh start"
            : "\(totalUnreachable) unreachable lesson(s)"
        print("\(errors.isEmpty ? "PASS" : "FAIL") lesson reachability: \(totalLessons) lessons across \(packs.count) packs — \(reachabilitySummary), no prerequisite cycles")
        return errors
    }

    /// Unsupported activity kinds cannot be smuggled past decode: the
    /// Activity/Stimulus/CheckpointItem inits throw on an unknown `kind`, so
    /// an offending pack fails to load with an "unknown … kind" error in the
    /// per-pack line above. This probe re-verifies the rejection on a minimal
    /// synthetic pack so a future forgiving decode stays caught.
    private static func verifyUnknownKindsRejected() -> [String] {
        func decodes(_ activities: [[String: Any]], _ stimuli: [[String: Any]],
                     _ checkpoints: [[String: Any]]) -> Bool {
            let probe: [String: Any] = [
                "schemaVersion": 2, "id": "probe", "version": "0", "language": "fr",
                "status": "active", "title": "probe", "sourceLanguage": "en",
                "description": "probe", "attribution": "probe",
                "units": [], "concepts": [], "vocabulary": [], "media": [],
                "stimuli": stimuli, "activities": activities, "lessons": [],
                "checkpoints": checkpoints, "dialogues": [],
            ]
            guard let data = try? JSONSerialization.data(withJSONObject: probe) else { return true }
            return (try? JSONDecoder().decode(CoursePack.self, from: data)) != nil
        }
        let badActivity: [[String: Any]] = [["kind": "hologram", "id": "x"]]
        let badStimulus: [[String: Any]] = [["kind": "hologram", "id": "x"]]
        let badCheckpoint: [[String: Any]] = [[
            "id": "probe-cp", "stage": "foundation", "modalities": ["reading"],
            "title": "t", "introduction": "i",
            "items": [["kind": "hologram", "id": "probe-item"]],
        ]]
        var errors: [String] = []
        if decodes(badActivity, [], []) {
            errors.append("probe: a pack with an unknown activity kind decoded successfully")
        }
        if decodes([], badStimulus, []) {
            errors.append("probe: a pack with an unknown stimulus kind decoded successfully")
        }
        if decodes([], [], badCheckpoint) {
            errors.append("probe: a pack with an unknown checkpoint item kind decoded successfully")
        }
        if errors.isEmpty {
            print("PASS unsupported kinds are rejected by decode: activity/stimulus/checkpoint-item probes with an unknown kind all throw (covered by decode, re-verified by probe)")
        } else {
            for error in errors { print("  FAIL \(error)") }
        }
        return errors
    }

    /// Checkpoint unseen wording (plan 5.3): checkpoint items must use wording
    /// unseen in the pack's lesson activities. Every reading question and
    /// writing/speaking prompt is compared — after trivial normalization
    /// (casefold, strip whitespace/punctuation) — against every lesson
    /// activity prompt (graded `prompt`, self-compare `prompt`,
    /// information `body`). Exact-normalized match only; editorial judgment
    /// about near-misses stays in audit_editorial.
    private static func verifyCheckpointWording(_ packs: [CoursePack]) -> [String] {
        var errors: [String] = []
        var totalItems = 0
        var checkpointPacks = 0
        for pack in packs where !pack.checkpoints.isEmpty {
            checkpointPacks += 1
            var activityTexts: [String: [String]] = [:]
            for activity in pack.activities {
                let text: String
                switch activity {
                case .information(let info): text = info.body
                case .selfCompare(let sc): text = sc.prompt
                case .openTask(let ot): text = validateWordingText(for: ot)
                default: text = activity.base?.prompt ?? ""
                }
                if !text.isEmpty {
                    activityTexts[normalizedComparable(text), default: []].append(activity.id)
                }
            }
            var itemCount = 0
            var duplicates = 0
            func check(_ text: String, _ context: String) {
                guard let matches = activityTexts[normalizedComparable(text)], !matches.isEmpty else { return }
                duplicates += 1
                let msg = "\(pack.id) checkpoint \(context): wording exactly duplicates lesson activity prompt(s) \(matches.sorted().joined(separator: ", "))"
                print("  FAIL \(msg)")
                errors.append(msg)
            }
            for checkpoint in pack.checkpoints {
                for item in checkpoint.items {
                    switch item {
                    case .reading(let reading):
                        for question in reading.questions {
                            itemCount += 1
                            check(question.question, "\(checkpoint.id) \(item.id) question \(question.id)")
                        }
                    case .writing(let writing):
                        itemCount += 1
                        check(writing.prompt, "\(checkpoint.id) \(item.id)")
                    case .speaking(let speaking):
                        itemCount += 1
                        check(speaking.prompt, "\(checkpoint.id) \(item.id)")
                    }
                }
            }
            totalItems += itemCount
            print("  \(duplicates == 0 ? "ok" : "NOTE") \(pack.id) checkpoints: \(itemCount) item prompt/question texts vs \(activityTexts.count) distinct lesson-activity texts — \(duplicates) exact-normalized duplicate(s)")
        }
        if checkpointPacks > 0 {
            print("\(errors.isEmpty ? "PASS" : "FAIL") checkpoint unseen-wording: \(totalItems) item texts across \(checkpointPacks) pack(s) — every checkpoint prompt/question uses wording unseen in lesson activity prompts (plan 5.3)")
        } else {
            print("PASS checkpoint unseen-wording: no pack declares a checkpoint task bank")
        }
        return errors
    }

    /// The learner-facing open-task wording (6.2): the goal plus the model
    /// response, joined — the texts that must stay unseen everywhere else.
    private static func validateWordingText(for ot: OpenTaskActivity) -> String {
        [ot.goal, ot.modelResponse].joined(separator: " ")
    }

    /// Open-task unseen wording (plan 6.2): an open task's goal and model
    /// response are *lesson* material, so they must not exactly repeat —
    /// after the same trivial normalization — a lesson activity prompt
    /// (including another open task's goal), a checkpoint item's
    /// question/prompt, or a sustained question in the same pack.
    /// Exact-normalized match only; editorial judgment about near-misses
    /// stays in audit_editorial.
    private static func verifyOpenTaskWording(_ packs: [CoursePack]) -> [String] {
        var errors: [String] = []
        var totalTasks = 0
        var openTaskPacks = 0
        for pack in packs where pack.activities.contains(where: {
            if case .openTask = $0 { return true }
            return false
        }) {
            openTaskPacks += 1
            var activityTexts: [String: [String]] = [:]
            for activity in pack.activities {
                let text: String
                switch activity {
                case .information(let info): text = info.body
                case .selfCompare(let sc): text = sc.prompt
                default: text = activity.base?.prompt ?? ""
                }
                if !text.isEmpty {
                    activityTexts[normalizedComparable(text), default: []].append(activity.id)
                }
            }
            var checkpointTexts: [String: [String]] = [:]
            for checkpoint in pack.checkpoints {
                for item in checkpoint.items {
                    switch item {
                    case .reading(let reading):
                        for question in reading.questions {
                            checkpointTexts[normalizedComparable(question.question), default: []]
                                .append("\(checkpoint.id) \(item.id) question \(question.id)")
                        }
                    case .writing(let writing):
                        checkpointTexts[normalizedComparable(writing.prompt), default: []]
                            .append("\(checkpoint.id) \(item.id)")
                    case .speaking(let speaking):
                        checkpointTexts[normalizedComparable(speaking.prompt), default: []]
                            .append("\(checkpoint.id) \(item.id)")
                    }
                }
            }
            var sustainedQuestionTexts: [String: [String]] = [:]
            for text in pack.sustainedTexts {
                for question in text.questions {
                    sustainedQuestionTexts[normalizedComparable(question.question), default: []]
                        .append("text \(text.id) question \(question.id)")
                }
            }
            for passage in pack.sustainedListenings {
                for question in passage.questions {
                    sustainedQuestionTexts[normalizedComparable(question.question), default: []]
                        .append("listening \(passage.id) question \(question.id)")
                }
            }
            var duplicates = 0
            var seenOpenTask: [String: String] = [:]
            for activity in pack.activities {
                guard case .openTask(let ot) = activity else { continue }
                totalTasks += 1
                let source = "open task \(ot.id)"
                func check(_ text: String, _ context: String) {
                    let norm = normalizedComparable(text)
                    if let matches = activityTexts[norm], !matches.isEmpty {
                        duplicates += 1
                        let msg = "\(pack.id) \(source) \(context): wording exactly duplicates lesson activity text(s) \(matches.sorted().joined(separator: ", "))"
                        print("  FAIL \(msg)")
                        errors.append(msg)
                    }
                    if let matches = checkpointTexts[norm], !matches.isEmpty {
                        duplicates += 1
                        let msg = "\(pack.id) \(source) \(context): wording exactly duplicates checkpoint item text(s) \(matches.sorted().joined(separator: ", "))"
                        print("  FAIL \(msg)")
                        errors.append(msg)
                    }
                    if let matches = sustainedQuestionTexts[norm], !matches.isEmpty {
                        duplicates += 1
                        let msg = "\(pack.id) \(source) \(context): wording exactly duplicates sustained question text(s) \(matches.sorted().joined(separator: ", "))"
                        print("  FAIL \(msg)")
                        errors.append(msg)
                    }
                    if let earlier = seenOpenTask[norm] {
                        duplicates += 1
                        let msg = "\(pack.id) \(source) \(context): wording exactly duplicates \(earlier)"
                        print("  FAIL \(msg)")
                        errors.append(msg)
                    } else {
                        seenOpenTask[norm] = "\(source) \(context)"
                    }
                }
                check(ot.goal, "goal")
                check(ot.modelResponse, "model")
            }
            print("  \(duplicates == 0 ? "ok" : "NOTE") \(pack.id) open tasks: goal/model wording vs lesson activities, checkpoint items, sustained questions and other open tasks — \(duplicates) exact-normalized duplicate(s)")
        }
        if openTaskPacks > 0 {
            print("\(errors.isEmpty ? "PASS" : "FAIL") open-task unseen-wording: \(totalTasks) task texts across \(openTaskPacks) pack(s) — every open-task goal and model uses wording unseen in lesson activities, checkpoint items, sustained questions, and other open tasks (plan 6.2)")
        } else {
            print("PASS open-task unseen-wording: no pack ships an open task")
        }
        return errors
    }

    /// Dialogue unseen wording (plan 6.3): every learner-facing string of a
    /// branching exchange — line, meaning gloss, choice text, choice
    /// feedback, open-turn prompt, model response, rubric criterion — must
    /// not exactly repeat — after the same trivial normalization as
    /// verifyCheckpointWording — a lesson activity prompt (including an
    /// open task's goal/model), a checkpoint item's question/prompt, or a
    /// sustained question in the same pack. Exact-normalized match only;
    /// editorial judgment about near-misses stays in audit_editorial.
    ///
    /// Deliberately NOT compared against other dialogue strings: a learner
    /// may legitimately repeat a sentence inside one threaded exchange
    /// (e.g. re-saying a suggestion after the partner asks for
    /// clarification), which is authored script, not a leak of unseen
    /// material.
    private static func verifyDialogueWording(_ packs: [CoursePack]) -> [String] {
        var errors: [String] = []
        var totalStrings = 0
        var dialoguePacks = 0
        for pack in packs where !pack.dialogues.isEmpty {
            dialoguePacks += 1
            var activityTexts: [String: [String]] = [:]
            for activity in pack.activities {
                let text: String
                switch activity {
                case .information(let info): text = info.body
                case .selfCompare(let sc): text = sc.prompt
                case .openTask(let ot): text = validateWordingText(for: ot)
                default: text = activity.base?.prompt ?? ""
                }
                if !text.isEmpty {
                    activityTexts[normalizedComparable(text), default: []].append(activity.id)
                }
            }
            var checkpointTexts: [String: [String]] = [:]
            for checkpoint in pack.checkpoints {
                for item in checkpoint.items {
                    switch item {
                    case .reading(let reading):
                        for question in reading.questions {
                            checkpointTexts[normalizedComparable(question.question), default: []]
                                .append("\(checkpoint.id) \(item.id) question \(question.id)")
                        }
                    case .writing(let writing):
                        checkpointTexts[normalizedComparable(writing.prompt), default: []]
                            .append("\(checkpoint.id) \(item.id)")
                    case .speaking(let speaking):
                        checkpointTexts[normalizedComparable(speaking.prompt), default: []]
                            .append("\(checkpoint.id) \(item.id)")
                    }
                }
            }
            var sustainedQuestionTexts: [String: [String]] = [:]
            for text in pack.sustainedTexts {
                for question in text.questions {
                    sustainedQuestionTexts[normalizedComparable(question.question), default: []]
                        .append("text \(text.id) question \(question.id)")
                }
            }
            for passage in pack.sustainedListenings {
                for question in passage.questions {
                    sustainedQuestionTexts[normalizedComparable(question.question), default: []]
                        .append("listening \(passage.id) question \(question.id)")
                }
            }
            var duplicates = 0
            func check(_ string: String, _ context: String) {
                let norm = normalizedComparable(string)
                if let matches = activityTexts[norm], !matches.isEmpty {
                    duplicates += 1
                    let msg = "\(pack.id) \(context): wording exactly duplicates lesson activity text(s) \(matches.sorted().joined(separator: ", "))"
                    print("  FAIL \(msg)")
                    errors.append(msg)
                }
                if let matches = checkpointTexts[norm], !matches.isEmpty {
                    duplicates += 1
                    let msg = "\(pack.id) \(context): wording exactly duplicates checkpoint item text(s) \(matches.sorted().joined(separator: ", "))"
                    print("  FAIL \(msg)")
                    errors.append(msg)
                }
                if let matches = sustainedQuestionTexts[norm], !matches.isEmpty {
                    duplicates += 1
                    let msg = "\(pack.id) \(context): wording exactly duplicates sustained question text(s) \(matches.sorted().joined(separator: ", "))"
                    print("  FAIL \(msg)")
                    errors.append(msg)
                }
            }
            for dialogue in pack.dialogues {
                for node in dialogue.nodes {
                    func context(_ field: String) -> String {
                        "dialogue \(dialogue.id) node \(node.id) \(field)"
                    }
                    check(node.line, context("line"))
                    check(node.meaning, context("meaning"))
                    if let prompt = node.prompt {
                        check(prompt, context("prompt"))
                        totalStrings += 1
                    }
                    if let model = node.modelResponse {
                        check(model, context("model"))
                        totalStrings += 1
                    }
                    for criterion in node.rubric ?? [] {
                        check(criterion.text, context("rubric \(criterion.id)"))
                        totalStrings += 1
                    }
                    for choice in node.choices {
                        check(choice.text, context("choice text"))
                        check(choice.feedback, context("choice feedback"))
                        totalStrings += 2
                    }
                }
            }
            print("  \(duplicates == 0 ? "ok" : "NOTE") \(pack.id) dialogues: \(totalStrings) learner-facing strings vs lesson activities, checkpoint items, sustained questions and open tasks — \(duplicates) exact-normalized duplicate(s)")
        }
        if dialoguePacks > 0 {
            print("\(errors.isEmpty ? "PASS" : "FAIL") dialogue unseen-wording: \(totalStrings) strings across \(dialoguePacks) pack(s) — every exchange line/meaning/choice/prompt/model/rubric uses wording unseen in lesson activity texts, checkpoint items, sustained questions, and open-task goal/model texts (plan 6.3)")
        } else {
            print("PASS dialogue unseen-wording: no pack ships an exchange")
        }
        return errors
    }

    /// Sustained-material unseen wording (plan 6.1): a sustained reading or
    /// listening question is *lesson* material, so it must not exactly
    /// repeat — after the same trivial normalization as verifyCheckpointWording
    /// — a lesson activity prompt (graded prompt, self-compare prompt,
    /// information body), a checkpoint item's question/prompt, or another
    /// sustained question in the same pack. Exact-normalized match only;
    /// editorial judgment about near-misses stays in audit_editorial.
    private static func verifySustainedWording(_ packs: [CoursePack]) -> [String] {
        var errors: [String] = []
        var totalQuestions = 0
        var sustainedPacks = 0
        for pack in packs where !pack.sustainedTexts.isEmpty || !pack.sustainedListenings.isEmpty {
            sustainedPacks += 1
            var activityTexts: [String: [String]] = [:]
            for activity in pack.activities {
                let text: String
                switch activity {
                case .information(let info): text = info.body
                case .selfCompare(let sc): text = sc.prompt
                case .openTask(let ot): text = validateWordingText(for: ot)
                default: text = activity.base?.prompt ?? ""
                }
                if !text.isEmpty {
                    activityTexts[normalizedComparable(text), default: []].append(activity.id)
                }
            }
            var checkpointTexts: [String: [String]] = [:]
            for checkpoint in pack.checkpoints {
                for item in checkpoint.items {
                    switch item {
                    case .reading(let reading):
                        for question in reading.questions {
                            checkpointTexts[normalizedComparable(question.question), default: []]
                                .append("\(checkpoint.id) \(item.id) question \(question.id)")
                        }
                    case .writing(let writing):
                        checkpointTexts[normalizedComparable(writing.prompt), default: []]
                            .append("\(checkpoint.id) \(item.id)")
                    case .speaking(let speaking):
                        checkpointTexts[normalizedComparable(speaking.prompt), default: []]
                            .append("\(checkpoint.id) \(item.id)")
                    }
                }
            }
            var packQuestionCount = 0
            var duplicates = 0
            var seenSustained: [String: String] = [:]
            func check(_ question: SustainedQuestion, _ owner: String) {
                packQuestionCount += 1
                let norm = normalizedComparable(question.question)
                if let earlier = seenSustained[norm] {
                    duplicates += 1
                    let msg = "\(pack.id) sustained \(owner): wording exactly duplicates sustained question in \(earlier)"
                    print("  FAIL \(msg)")
                    errors.append(msg)
                } else {
                    seenSustained[norm] = owner
                }
                if let matches = activityTexts[norm], !matches.isEmpty {
                    duplicates += 1
                    let msg = "\(pack.id) sustained \(owner): wording exactly duplicates lesson activity prompt(s) \(matches.sorted().joined(separator: ", "))"
                    print("  FAIL \(msg)")
                    errors.append(msg)
                }
                if let matches = checkpointTexts[norm], !matches.isEmpty {
                    duplicates += 1
                    let msg = "\(pack.id) sustained \(owner): wording exactly duplicates checkpoint item text(s) \(matches.sorted().joined(separator: ", "))"
                    print("  FAIL \(msg)")
                    errors.append(msg)
                }
            }
            for text in pack.sustainedTexts {
                for question in text.questions {
                    check(question, "text \(text.id) question \(question.id)")
                }
            }
            for passage in pack.sustainedListenings {
                for question in passage.questions {
                    check(question, "listening \(passage.id) question \(question.id)")
                }
            }
            totalQuestions += packQuestionCount
            print("  \(duplicates == 0 ? "ok" : "NOTE") \(pack.id) sustained: \(packQuestionCount) question texts vs \(activityTexts.count) distinct lesson-activity texts and \(checkpointTexts.count) distinct checkpoint texts — \(duplicates) exact-normalized duplicate(s)")
        }
        if sustainedPacks > 0 {
            print("PASS sustained-material unseen-wording: \(totalQuestions) question texts across \(sustainedPacks) pack(s) — every sustained question uses wording unseen in lesson activity prompts, checkpoint item texts, and other sustained questions (plan 6.1)")
        } else {
            print("PASS sustained-material unseen-wording: no pack declares sustained material")
        }
        return errors
    }

    // MARK: - Asset resolution

    /// `/audio/french/foo.wav` → `<contentRoot>/audio/french/foo.wav`
    private static func resolve(_ webURL: String, contentRoot: URL) -> URL {
        let trimmed = webURL.hasPrefix("/") ? String(webURL.dropFirst()) : webURL
        return contentRoot.appendingPathComponent(trimmed)
    }

    private static func url(of item: MediaItem) -> String {
        switch item {
        case .audio(_, let url, _, _, _): return url
        case .image(_, let url, _, _): return url
        }
    }

    private static func attribution(of item: MediaItem) -> String {
        switch item {
        case .audio(_, _, _, let attribution, _): return attribution
        case .image(_, _, _, let attribution): return attribution
        }
    }

    private static func transcript(of item: MediaItem) -> String {
        switch item {
        case .audio(_, _, _, _, let transcript): return transcript
        case .image: return ""
        }
    }

    private static func declaredSHA256(of item: MediaItem) -> String {
        switch item {
        case .audio(_, _, let sha, _, _): return sha
        case .image(_, _, let sha, _): return sha
        }
    }

    private static func fileSHA256(_ url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Attribution citation check

    private static let docCitationPattern = try! NSRegularExpression(
        pattern: "docs/[A-Za-z0-9_./-]+")

    /// For every `attribution` string, extract any `docs/...` path and assert
    /// that it exists under the repo root. Handles trailing sentence
    /// punctuation ("docs/audio-provenance." → "docs/audio-provenance").
    private static func checkAttributionCitations(_ packs: [CoursePack],
                                                  repoRoot: URL) -> [String] {
        var errors: [String] = []
        for pack in packs {
            let entries: [(owner: String, text: String)] =
                [("pack", pack.attribution)] + pack.media.map { ($0.id, attribution(of: $0)) }
            for entry in entries {
                let ns = entry.text as NSString
                var cursor = 0
                var cited = Set<String>()
                while cursor < ns.length {
                    guard let match = docCitationPattern.firstMatch(
                        in: entry.text, range: NSRange(location: cursor, length: ns.length - cursor))
                    else { break }
                    let raw = ns.substring(with: match.range)
                    cursor = NSMaxRange(match.range)
                    let cleaned = raw.trimmingCharacters(in: CharacterSet(charactersIn: ".,:;)\"'"))
                    if !cleaned.isEmpty { cited.insert(cleaned) }
                }
                for path in cited.sorted() {
                    let resolved = repoRoot.appendingPathComponent(path)
                    if FileManager.default.fileExists(atPath: resolved.path) {
                        print("  ok  \(pack.id) \(entry.owner): cites \(path) — exists")
                    } else {
                        let msg = "\(pack.id) attribution (\(entry.owner)) cites missing file \(path)"
                        print("  FAIL \(msg)")
                        errors.append(msg)
                    }
                }
            }
        }
        return errors
    }

    // MARK: - Allowlist (tools/device-speech-media.txt)

    private static func loadAllowlist(url: URL?) -> Set<String> {
        guard let url,
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        var entries = Set<String>()
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            let entry = line.split(separator: "#", maxSplits: 1)[0]
                .trimmingCharacters(in: .whitespaces)
            if !entry.isEmpty { entries.insert(entry) }
        }
        return entries
    }

    /// Tracks which allowlist entries matched a real declared asset, so stale
    /// or typo'd entries can be warned about.
    private static func match(_ id: String, _ url: String,
                              allowlist: Set<String>, matched: inout Set<String>) -> Bool {
        let trimmed = url.hasPrefix("/") ? String(url.dropFirst()) : url
        guard allowlist.contains(id) || allowlist.contains(url) || allowlist.contains(trimmed) else {
            return false
        }
        matched.insert(id)
        matched.insert(url)
        matched.insert(trimmed)
        return true
    }

    // MARK: - Where a media item is referenced (for the report)

    /// A lesson step (or retained legacy dictation) whose presentation shows
    /// this media — via a `Stimulus.audio` (or examples/dialogue pair) on the
    /// step's activity, a self-compare model reading of it, or a legacy
    /// dictation.
    private struct StepRef {
        let lesson: String
        let step: String               // "step <id>" or "legacy dictation <id>"
        let activityIds: [String]      // activities on the step that present the media
        let stimulusIds: [String]      // stimuli on those activities that reference the media
        let legacyDictationId: String?
    }

    private static func stepRefs(_ pack: CoursePack, for mediaId: String) -> [StepRef] {
        var referencingStimuli = Set<String>()
        for stimulus in pack.stimuli {
            var mediaRefs: [String] = []
            switch stimulus {
            case .audio(_, let m): mediaRefs = [m]
            case .examples(_, let pairs): mediaRefs = pairs.compactMap(\.mediaId)
            case .dialogue(_, let turns): mediaRefs = turns.compactMap(\.mediaId)
            case .text, .scene: break
            }
            if mediaRefs.contains(mediaId) { referencingStimuli.insert(stimulus.id) }
        }

        var activityStimulus = [String: String]()
        var activityIds = Set<String>()
        for activity in pack.activities {
            if let sid = activity.stimulusId, referencingStimuli.contains(sid) {
                activityIds.insert(activity.id)
                activityStimulus[activity.id] = sid
            }
            if case .selfCompare(let sc) = activity, sc.modelAudioId == mediaId {
                activityIds.insert(activity.id)
            }
        }

        var out: [StepRef] = []
        for lesson in pack.lessons {
            for step in lesson.steps {
                var linked: [String] = []
                if activityIds.contains(step.activityId) { linked.append(step.activityId) }
                if let supportId = step.supportActivityId, activityIds.contains(supportId) {
                    linked.append(supportId)
                }
                if !linked.isEmpty {
                    out.append(StepRef(lesson: lesson.id, step: "step \(step.id)",
                                       activityIds: linked,
                                       stimulusIds: linked.compactMap { activityStimulus[$0] },
                                       legacyDictationId: nil))
                }
            }
            for exercise in lesson.legacyExercises {
                if case .dictation(_, let audioId) = exercise, audioId == mediaId {
                    out.append(StepRef(lesson: lesson.id, step: "legacy dictation \(exercise.id)",
                                       activityIds: [], stimulusIds: [],
                                       legacyDictationId: exercise.id))
                }
            }
        }
        return out
    }

    private static func references(_ pack: CoursePack, for mediaId: String) -> [String] {
        stepRefs(pack, for: mediaId).map { "lesson \($0.lesson) \($0.step)" }
    }

    // MARK: - Learner-visible text (for the allowlist audit)

    private static func visibleActivityText(_ pack: CoursePack, activityId: String) -> String {
        guard let activity = pack.activities.first(where: { $0.id == activityId }) else {
            return ""
        }
        switch activity {
        case .information(let info): return info.body
        case .selfCompare(let sc): return "\(sc.prompt) \(sc.modelText)"
        case .openTask(let ot): return "\(ot.goal) \(ot.modelResponse)"
        default: return activity.base?.prompt ?? ""
        }
    }

    private static func visibleStimulusText(_ pack: CoursePack, stimulusId: String) -> String {
        guard let stimulus = pack.stimuli.first(where: { $0.id == stimulusId }) else {
            return ""
        }
        switch stimulus {
        case .text(_, let body, let translation):
            return body + " " + (translation ?? "")
        case .examples(_, let pairs):
            return pairs.map { "\($0.target) \($0.meaning)" }.joined(separator: " ")
        case .dialogue(_, let turns):
            return turns.map(\.text).joined(separator: " ")
        case .audio, .scene:
            return "" // audio/scene carry no learner-readable prose of their own
        }
    }

    // MARK: - Media inventory verification

    private static func verifyMedia(_ packs: [CoursePack],
                                    contentRoot: URL,
                                    allowlist: Set<String>) -> [String] {
        var errors: [String] = []
        var missingAssets: [String] = []
        var matchedAllowlist = Set<String>()

        for pack in packs {
            var declared = 0
            var onDisk = 0
            var missingCount = 0
            var allowlistedCount = 0
            print("== \(pack.id).json media ==")
            for item in pack.media {
                declared += 1
                let itemURL = url(of: item)
                let resolved = resolve(itemURL, contentRoot: contentRoot)
                let ext = resolved.pathExtension.lowercased()
                let allowed = item.isAudio ? audioExtensions : imageExtensions
                let kindLabel = item.isAudio ? "audio" : "image"
                let refs = references(pack, for: item.id)
                let refText = refs.isEmpty ? "" : " — referenced by " + refs.joined(separator: ", ")
                let allowlisted = match(item.id, itemURL, allowlist: allowlist,
                                        matched: &matchedAllowlist)

                if FileManager.default.fileExists(atPath: resolved.path) {
                    onDisk += 1
                    if !allowed.contains(ext) {
                        let msg = "\(pack.id) \(item.id) \(itemURL): expected \(kindLabel), found .\(ext)"
                        print("  TYPE MISMATCH \(msg)")
                        errors.append(msg)
                        continue
                    }
                    let declaredSHA = declaredSHA256(of: item)
                    if !declaredSHA.isEmpty,
                       let computed = fileSHA256(resolved),
                       declaredSHA.lowercased() != computed {
                        let msg = "\(pack.id) \(item.id) \(itemURL): sha256 mismatch (declared \(declaredSHA), computed \(computed))"
                        print("  HASH MISMATCH \(msg)")
                        errors.append(msg)
                        continue
                    }
                    if allowlisted {
                        print("  NOTE stale allowlist entry: \(itemURL) now exists on disk — remove \(item.id) from tools/device-speech-media.txt")
                    } else {
                        print("  ok  \(item.id)  \(itemURL)")
                    }
                } else {
                    missingCount += 1
                    if allowlisted {
                        allowlistedCount += 1
                        print("  device-speech (intentional)  \(item.id)  \(itemURL)")
                        missingAssets.append("\(pack.id) \(item.id) \(itemURL) — device-speech (intentional)\(refText)")
                    } else {
                        let msg = "\(pack.id) \(item.id) \(itemURL)\(refText)"
                        print("  MISSING \(msg)")
                        missingAssets.append(msg)
                        errors.append("missing \(msg)")
                    }
                }
            }
            print("  summary: \(declared) declared, \(onDisk) on disk, \(missingCount) missing (\(allowlistedCount) allowlisted for device speech)")
        }

        // Listen tracks: Content/listen-tracks/<slug>.json → audioUrl.
        let listenDir = contentRoot.appendingPathComponent("listen-tracks", isDirectory: true)
        print("== listen-tracks ==")
        for slug in PackLoader.packFilenames {
            let url = listenDir.appendingPathComponent(slug).appendingPathExtension("json")
            guard let data = try? Data(contentsOf: url),
                  let track = try? JSONDecoder().decode(ListenTrackProbe.self, from: data) else {
                let msg = "listen-track \(slug): missing or undecodable transcript"
                print("  MISSING \(msg)")
                errors.append(msg)
                continue
            }
            let resolved = resolve(track.audioUrl, contentRoot: contentRoot)
            let ext = resolved.pathExtension.lowercased()
            if !FileManager.default.fileExists(atPath: resolved.path) {
                let msg = "listen-track \(track.lessonId) (\(slug)): audio missing \(track.audioUrl)"
                print("  MISSING \(msg)")
                errors.append(msg)
            } else if !audioExtensions.contains(ext) {
                let msg = "listen-track \(track.lessonId) (\(slug)): type mismatch \(track.audioUrl) (.\(ext))"
                print("  TYPE MISMATCH \(msg)")
                errors.append(msg)
            } else {
                print("  ok  \(slug)  \(track.lessonId)  \(track.audioUrl)")
            }
        }

        print("== MISSING ASSETS ==")
        if missingAssets.isEmpty {
            print("  none")
        } else {
            for entry in missingAssets { print("  MISSING \(entry)") }
        }

        let unmatched = allowlist.subtracting(matchedAllowlist)
        for entry in unmatched.sorted() {
            print("  NOTE allowlist entry matches no declared media: \(entry)")
        }

        return errors
    }

    // MARK: - Listen track integrity (duration + section boundaries)

    private static func verifyListenTracks(_ packs: [CoursePack],
                                           contentRoot: URL) -> [String] {
        var errors: [String] = []
        let listenDir = contentRoot.appendingPathComponent("listen-tracks", isDirectory: true)
        for slug in PackLoader.packFilenames {
            let url = listenDir.appendingPathComponent(slug).appendingPathExtension("json")
            guard let data = try? Data(contentsOf: url),
                  let track = try? JSONDecoder().decode(ListenTrackProbe.self, from: data) else {
                let msg = "listen-track \(slug): undecodable for integrity checks"
                print("  FAIL \(msg)")
                errors.append(msg)
                continue
            }
            let audio = resolve(track.audioUrl, contentRoot: contentRoot)

            // Duration: compare declared durationS to the real audio duration.
            if let actual = measuredDuration(audio) {
                let delta = abs(track.durationS - actual)
                let flag = delta > 1.0 ? "FAIL" : "ok"
                print("  \(flag) duration \(slug): declared \(String(format: "%.2f", track.durationS))s, actual \(String(format: "%.3f", actual))s (delta \(String(format: "%.3f", delta))s)")
                if delta > 1.0 {
                    errors.append("listen-track \(slug): durationS \(track.durationS) deviates from measured audio duration \(actual) by \(delta)s (> 1.0)")
                }
            } else {
                print("  FAIL duration \(slug): could not measure audio duration (afinfo/ffprobe unavailable?)")
                errors.append("listen-track \(slug): audio duration unmeasurable — cannot verify durationS")
            }

            // Section boundaries: non-empty, strictly increasing, within range.
            if track.sections.isEmpty {
                print("  FAIL sections \(slug): track declares 0 sections")
                errors.append("listen-track \(slug): has 0 sections")
                continue
            }
            var lastStart: Double?
            for (index, section) in track.sections.enumerated() {
                guard let start = section.startS else {
                    print("  NOTE sections \(slug) [#\(index) '\(section.heading)']: no startS (older transcripts omit it) — boundary unchecked")
                    continue
                }
                var ok = true
                var why = ""
                if start < 0 {
                    ok = false; why = "startS \(start) < 0"
                } else if start > track.durationS {
                    ok = false; why = "startS \(start) > durationS \(track.durationS)"
                } else if let last = lastStart, start <= last {
                    ok = false; why = "startS \(start) <= previous \(last) (non-monotonic)"
                }
                let marker = ok ? "ok" : "FAIL"
                print("  \(marker) sections \(slug) [#\(index) '\(section.heading)']: startS \(start)s" + (ok ? "" : " — \(why)"))
                if !ok {
                    errors.append("listen-track \(slug): section \(index) '\(section.heading)': \(why)")
                }
                lastStart = start
            }
        }
        return errors
    }

    /// Real duration of an audio file in seconds via `afinfo`, falling back to
    /// `ffprobe` only when afinfo is unavailable.
    private static func measuredDuration(_ url: URL) -> Double? {
        let afinfoCandidates = ["/usr/bin/afinfo", "/opt/homebrew/bin/afinfo", "/usr/local/bin/afinfo"]
        if let afinfo = afinfoCandidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }),
           let duration = durationViaAfinfo(afinfo, url) {
            return duration
        }
        if let ffprobe = executableInPath("ffprobe"),
           let duration = durationViaFFprobe(ffprobe, url) {
            return duration
        }
        return nil
    }

    private static func runTool(_ path: String, _ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
        } catch {
            return nil
        }
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }

    private static let durationPattern = try! NSRegularExpression(
        pattern: "estimated duration:\\s*([0-9]+\\.?[0-9]*)")

    private static func durationViaAfinfo(_ afinfo: String, _ url: URL) -> Double? {
        guard let output = runTool(afinfo, [url.path]) else { return nil }
        let ns = output as NSString
        guard let match = durationPattern.firstMatch(
            in: output, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return Double(ns.substring(with: match.range(at: 1)))
    }

    private static func durationViaFFprobe(_ ffprobe: String, _ url: URL) -> Double? {
        guard let output = runTool(ffprobe, [
            "-v", "error", "-show_entries", "format=duration",
            "-of", "default=noprint_wrappers=1:nokey=1", url.path
        ]) else { return nil }
        return Double(output.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func executableInPath(_ name: String) -> String? {
        let pathDirectories = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":").map(String.init)
        for directory in pathDirectories {
            let candidate = URL(fileURLWithPath: directory).appendingPathComponent(name).path
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    // MARK: - Device-speech allowlist text audit

    /// For each allowlisted (intentionally-missing) asset, resolve the
    /// referencing lesson step and confirm that step presents nonempty
    /// learner-visible text (an activity prompt/body and/or the media
    /// transcript, plus stimulus prose where the stimulus references the
    /// asset). A step with no visible text fails: the device-speech fallback
    /// would present only silence.
    private static func auditAllowlistText(_ packs: [CoursePack],
                                           allowlist: Set<String>) -> [String] {
        var errors: [String] = []
        print("== device-speech allowlist text audit ==")
        for entry in allowlist.sorted() {
            guard let pack = packs.first(where: { pack in
                pack.media.contains { item in
                    let trimmed = url(of: item).hasPrefix("/") ? String(url(of: item).dropFirst()) : url(of: item)
                    return item.id == entry || url(of: item) == entry || trimmed == entry
                }
            }) else {
                print("  SKIP \(entry): matches no declared media (stale allowlist entry — see NOTE above)")
                continue
            }
            guard let media = pack.media.first(where: { item in
                let trimmed = url(of: item).hasPrefix("/") ? String(url(of: item).dropFirst()) : url(of: item)
                return item.id == entry || url(of: item) == entry || trimmed == entry
            }) else { continue }

            let refs = stepRefs(pack, for: media.id)
            if refs.isEmpty {
                print("  NO-REF \(entry): allowlisted asset is not referenced by any lesson step — device-speech fallback never presents it")
                errors.append("allowlisted \(entry): no referencing lesson step/activity")
                continue
            }
            let mediaText = transcript(of: media)
            var silentSteps: [String] = []
            for ref in refs {
                var candidateText: [String] = []
                if let dictationId = ref.legacyDictationId,
                   let lesson = pack.lessons.first(where: { $0.id == ref.lesson }),
                   let exercise = lesson.legacyExercises.first(where: { $0.id == dictationId }) {
                    candidateText.append(exercise.base.prompt)
                }
                for activityId in ref.activityIds {
                    candidateText.append(visibleActivityText(pack, activityId: activityId))
                }
                for stimulusId in ref.stimulusIds {
                    candidateText.append(visibleStimulusText(pack, stimulusId: stimulusId))
                }
                candidateText.append(mediaText)
                let hasText = candidateText.contains {
                    !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
                let whereLabel = "lesson \(ref.lesson) \(ref.step)"
                if hasText {
                    print("  PASS \(entry): \(whereLabel) — visible prompt/transcript")
                } else {
                    print("  NO-TEXT \(entry): \(whereLabel) — no learner-visible text (no prompt, no transcript)")
                    silentSteps.append(whereLabel)
                }
            }
            if !silentSteps.isEmpty {
                errors.append("allowlisted \(entry): NO learner-visible text at \(silentSteps.joined(separator: ", "))")
            }
        }
        return errors
    }
}

/// Minimal decode of a Listen track transcript — only the fields this checker
/// needs (the full model lives in Condisco/Listen/ListenModels.swift and is
/// not part of this compile).
private struct ListenTrackProbe: Decodable {
    let lessonId: String
    let courseSlug: String
    let audioUrl: String
    let durationS: Double
    let reviewPending: Bool?
    let sections: [SectionProbe]

    struct SectionProbe: Decodable {
        let heading: String
        let teacher: String
        let startS: Double?
    }
}