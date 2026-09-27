import Foundation

// Editorial backlog report for the bundled course content. Compile with the
// production pack model (see audit_editorial.sh for the exact swiftc line)
// and run with the Content root as the single argument. Reads the five pack
// JSONs and prints compact, deterministically ordered counts of editorial
// gaps:
//
//   graded answer specs (text answers, cloze blanks) with no authored errors
//   graded steps whose only hint is generic or absent (engine fallback)
//   ungraded activity counts (information / self-compare)
//   mission/story lessons missing an objective or a text final-response step
//   a per-pack total and a one-line summary
//
// Since 1.1 it also prints a dedicated "OPEN-ENDED GRADING CHECK" section
// that measures the plan's P1.1 exit gate: "no open-ended prompt is falsely
// auto-graded". A text activity (free-text input auto-graded by AnswerEngine
// against a fixed answers[] list) is flagged when its prompt invites free
// production without dictating the exact sentence to produce:
//
//   comprehension prompts   "(Reading …)" or "Read …" questions; also
//                           read-step activities (id ends in "-read"),
//                           text-grounded questions ("Secondo il testo" /
//                           "according to the text"), and recall of a single
//                           previously taught item ("You learned this in …",
//                           "… did you hear?") — the answer is dictated by
//                           the passage or the prior lesson
//   free-production copy    "write anything", "in your own words", "write a …",
//                           "say anything", "describe", … (see
//                           freeProductionPhrases)
//   bare questions          any remaining interrogative with no explicit
//                           target (free production — the risky kind)
//
// Prompts that DICTATE the exact sentence are exempt (controlled production,
// where a fixed accepted list is legitimate): "Write in <lang>: …",
// "Give the English meaning: …", "Translate into <lang>: …", "Type: …",
// "Predict …", "Soften …", "Think: …", "Ask …", "from memory", "no help",
// "answer that …", "Listen and write the model" (see isControlledPrompt).
//
// The same section also reports information/self-compare activities that
// carry grading keys in the raw JSON (answer/answers/acceptedIds/options/
// feedback/…), which the typed model silently ignores — they would be
// presented as ungraded but wired for auto-grading.
//
// This tool produces a backlog for humans and CI diffing; it is not a gate.
// It exits 0 whenever every pack loads, and non-zero only if a pack cannot
// be read or decoded. The exit-gate line at the end of the section is
// computed from the real data and is informational (the tool never fails a
// build). Output ordering is deterministic (pack order fixed, ids sorted)
// so the report is stable/diffable across runs.
//
// Since 1.3 the tool has two optional machine-readable modes, both of which
// keep the human report byte-identical:
//
//   --jsonl <path>   write one JSON object per lesson (255 today) to <path>:
//                    packId, unitId, lessonId, family, stepId, activityId,
//                    activityKind (parallel arrays of every flagged element),
//                    missingHint, missingErrorFeedback, missingFinalResponse,
//                    missingObjective, ungradedType, openEndedGradingFlag,
//                    lessonPassable. Deterministic ordering (pack order,
//                    lesson id, then element sort) so diffs are meaningful.
//   --strict         exit 1 when a solo worker can objectively enforce a
//                    violation: open-ended prompts falsely auto-graded
//                    (free-phrase/interrogative, the P1.1 gate, currently 0)
//                    or ungraded activities wired to grading keys (currently
//                    0). Hint/error-feedback gaps stay backlog/report-only —
//                    they are being worked down over batches, not gates yet.
//
// lessonPassable is the rubric rollup: false when any flag is non-zero
// (missingHint, missingErrorFeedback, missingObjective, missingFinalResponse,
// openEndedGradingFlag); ungraded kinds are deliberate design, not flags.
//
// Since 1.2 the exit-gate line is calibrated to genuine violations only:
// counting every flagged text prompt over-claims, because comprehension
// questions and dictated-answer interrogatives (see openEndedReason) are
// legitimately auto-graded against a fixed list. The gate FAIL count is
// free-phrase prompts plus interrogatives with no dictated answer;
// comprehension and answer-dictated interrogatives are reported as
// informational on the same line.
@main
struct AuditEditorial {
    /// Pack basenames in the fixed Courses-tab order — the registry's
    /// order (this tool compiles CoursePack.swift standalone, so it can
    /// consume `CourseRegistry` directly; no duplicated list lives here).
    private static let packFilenames = CourseRegistry.slugs

    /// Course-slug alternation for the controlled-prompt regexes below,
    /// derived from the registry: adding a language needs no regex edit.
    private static let courseSlugsAlternation = CourseRegistry.slugs.joined(separator: "|")

    /// Hint strings that only restate the engine's generic fallbacks
    /// (hintText "Try it", and the retry strings in ActivityEvaluation) add
    /// no editorial value and read as authoring by default.
    private static let genericHints: Set<String> = [
        "Try it", "Try again", "Not quite — try again.",
        "That selection is not valid. Try again.",
        "The order is not right yet. Try again.",
        "Some pairs are off. Try again.",
        "Place every token exactly once.",
        "Each pairing must use listed items exactly once.",
        "Each region counts once. Try again.",
    ]

    /// Lines shown per list before collapsing into "… and N more".
    private static let listCap = 20

    // MARK: - Open-ended grading check (P1.1 exit-gate measurement)

    /// Copy phrases that invite free production (tuned against the real
    /// packs). Matched on the lowercased prompt, so each entry is lowercase.
    private static let freeProductionPhrases: [String] = [
        "write anything", "write freely", "say anything",
        "your own words", "in your own words",
        "free text", "free response",
        "write a ", "describe", "explain",
        "what do you think", "your opinion", "invent ",
    ]

    /// One flagged instance: an auto-graded prompt that invites free
    /// production, or an ungraded-kind activity wired to grading keys.
    private struct OpenEndedInstance {
        let packID: String
        let activityID: String
        /// "lesson=<lesson> step=<step>" pairs joined by "; ".
        let locations: String
        let kindLabel: String
        let acceptedCount: Int
        let reason: String
        let copy: String
    }

    private static var openEndedInstances: [OpenEndedInstance] = []
    private static var wiredInstances: [OpenEndedInstance] = []

    /// Grading keys that belong on graded activities only; on an
    /// information/self-compare activity they mean the raw JSON is wired for
    /// auto-grading despite being presented as ungraded/self-assessed.
    private static let gradingKeys: Set<String> = [
        "answer", "answers", "errors", "allowTypo",
        "acceptedIds", "acceptedOrders", "acceptedPairs", "acceptedRegionIds",
        "options", "hints", "feedback", "evidenceKey",
    ]

    /// True when the prompt dictates the exact text to produce, so grading
    /// against a fixed answers[] list is legitimate (controlled production).
    private static func isControlledPrompt(_ prompt: String) -> Bool {
        let low = prompt.lowercased()
        if low.range(
            of: "\\bwrite in (?:\(courseSlugsAlternation)|english)\\b",
            options: .regularExpression) != nil { return true }
        // "write it in …", "write politely in …", "write the plan in …"
        if low.range(
            of: "write[^:\"“”]{0,24} in (?:\(courseSlugsAlternation))\\b",
            options: .regularExpression) != nil { return true }
        if low.range(of: #"\b(?:type|predict|soften)\b"#, options: .regularExpression) != nil { return true }
        if low.range(of: #"^ask\b"#, options: .regularExpression) != nil { return true }
        if low.range(of: #"\banswer that\b"#, options: .regularExpression) != nil { return true }
        if low.range(
            of: "translate into (?:\(courseSlugsAlternation))\\b",
            options: .regularExpression) != nil { return true }
        return ["give the english meaning", "listen and write the model",
                "no help", "from memory", "think:"].contains { low.contains($0) }
    }

    /// The reason a text prompt invites free production, or nil when it is
    /// controlled (exact target dictated) or not open-ended at all. Version
    /// 1.2 additionally recognizes text-grounded/read-step questions and
    /// taught-item recall as comprehension (fixed, dictated answers — not
    /// free production), so the exit-gate FAIL count reflects only genuine
    /// free-production prompts.
    private static func openEndedReason(_ prompt: String, activityID: String) -> String? {
        let low = prompt.lowercased()
        if isControlledPrompt(low) { return nil }
        if low.range(of: #"\(reading"#, options: .regularExpression) != nil { return "comprehension" }
        if low.range(of: #"^\s*read\b"#, options: .regularExpression) != nil { return "comprehension" }
        // Text-grounded questions ("Secondo il testo" / "according to the
        // text") and read-step questions (id ends in "-read" and is a bare
        // question): the answer is dictated by the passage, so a fixed
        // accepted list is legitimate.
        if low.range(of: #"(?:secondo il testo|according to the text)"#, options: .regularExpression) != nil {
            return "comprehension"
        }
        if activityID.hasSuffix("-read"), low.contains("?") { return "comprehension" }
        // Recall of a single item taught in a prior lesson, phrased as a
        // QUESTION ("You learned this in «First words»: how do you say thank
        // you?", "From «First words»: … did you hear?") — the answer was
        // dictated in the prior lesson, so it is legitimately auto-graded.
        // (The same «lesson» phrasing in imperative form — "From «X»: write
        // “a sentence”" — dictates the exact sentence and is already exempt
        // as controlled production, so a bare "?" is required here.)
        if low.contains("?"),
           low.contains("you learned this in") || low.contains("did you hear") || low.contains("from «") {
            return "comprehension"
        }
        if let phrase = freeProductionPhrases.first(where: { low.contains($0) }) {
            return "free-phrase(\(phrase.trimmingCharacters(in: .whitespaces)))"
        }
        if low.contains("?") { return "interrogative" }
        return nil
    }

    /// Collect the P1.1 instances for one pack. `rawData` is the pack JSON as
    /// decoded, re-parsed here only to see keys the typed model ignores.
    private static func collectOpenEnded(_ pack: CoursePack, packName: String, rawData: Data) {
        var locations: [String: [(String, String)]] = [:]
        for lesson in pack.lessons {
            for step in lesson.steps {
                locations[step.activityId, default: []].append((lesson.id, step.id))
            }
        }
        func place(_ activityID: String) -> String {
            let pairs = locations[activityID] ?? []
            if pairs.isEmpty { return "lesson=? step=?(not in any lesson step)" }
            return pairs.sorted { $0.0 == $1.0 ? $0.1 < $1.1 : $0.0 < $1.0 }
                .map { "lesson=\($0.0) step=\($0.1)" }
                .joined(separator: "; ")
        }

        // 1. Open-ended prompts auto-graded against a fixed answers[] list.
        for activity in pack.activities.sorted(by: { $0.id < $1.id }) {
            guard case .text(let spec) = activity else { continue }
            guard let reason = openEndedReason(spec.base.prompt, activityID: spec.id) else { continue }
            openEndedInstances.append(OpenEndedInstance(
                packID: packName, activityID: spec.id,
                locations: place(spec.id), kindLabel: "text",
                acceptedCount: spec.answer.answers.count,
                reason: reason, copy: spec.base.prompt))
        }

        // 2. Ungraded-kind activities wired to grading keys in the raw JSON.
        guard let raw = try? JSONSerialization.jsonObject(with: rawData) as? [String: Any],
              let rawActivities = raw["activities"] as? [[String: Any]] else { return }
        for rawActivity in rawActivities {
            guard let kind = rawActivity["kind"] as? String,
                  kind == "information" || kind == "self-compare" else { continue }
            let present = gradingKeys.filter { rawActivity[$0] != nil }.sorted()
            guard !present.isEmpty, let id = rawActivity["id"] as? String else { continue }
            let detail = present.joined(separator: ", ")
            let copy: String
            if let prompt = rawActivity["prompt"] as? String {
                copy = "\(prompt) [grading keys in JSON: \(detail)]"
            } else if let body = rawActivity["body"] as? String {
                copy = "\(body) [grading keys in JSON: \(detail)]"
            } else {
                copy = "[grading keys in JSON: \(detail)]"
            }
            wiredInstances.append(OpenEndedInstance(
                packID: packName, activityID: id,
                locations: place(id), kindLabel: kind == "information" ? "information" : "self-compare",
                acceptedCount: 0, reason: "wired-to-answers", copy: copy))
        }
    }

    /// The dedicated P1.1 measurement section, printed after all packs so the
    /// existing per-pack report stays byte-stable.
    private static func printOpenEndedSection() {
        print("== OPEN-ENDED GRADING CHECK ==")
        print("rule: an auto-graded text activity (fixed answers[] list) must not invite free production without dictating the exact sentence (\"write anything\"-style copy, bare questions); comprehension questions and recall of taught items have dictated answers and are legitimately auto-graded (informational only here). Prompts that dictate the exact sentence are exempt. information/self-compare activities must not carry grading keys.")
        let all = openEndedInstances + wiredInstances
        var totalOpen = 0
        var totalWired = 0
        for name in packFilenames {
            let packInstances = all.filter { $0.packID == name }
            let open = packInstances.filter { $0.kindLabel == "text" }.count
            let wired = packInstances.count - open
            totalOpen += open
            totalWired += wired
            print("\(name): \(packInstances.count) instances (\(open) open-ended graded, \(wired) ungraded-with-answers)")
        }
        let total = totalOpen + totalWired
        print("TOTAL: \(total) instances (\(totalOpen) open-ended graded, \(totalWired) ungraded wired to answers[])")

        for name in packFilenames {
            print("\(name):")
            let packInstances = all.filter { $0.packID == name }
                .sorted { $0.locations == $1.locations ? $0.activityID < $1.activityID : $0.locations < $1.locations }
            if packInstances.isEmpty {
                print("  (none)")
            } else {
                printLines(capped: packInstances.map(renderInstance))
            }
        }

        // P1.1 exit-gate measurement, calibrated to genuine violations only:
        // the FAIL count is free-phrase prompts (learner invited to write
        // freely) plus bare interrogatives with no dictated answer (see
        // openEndedReason). Comprehension questions and recalled taught items
        // have dictated answers, are legitimately auto-graded, and are
        // reported as informational only — counting them over-claims.
        let freePhraseCount = openEndedInstances.filter { $0.reason.hasPrefix("free-phrase") }.count
        let interrogativeCount = openEndedInstances.filter { $0.reason == "interrogative" }.count
        let comprehensionCount = openEndedInstances.filter { $0.reason == "comprehension" }.count
        let gateFail = freePhraseCount + interrogativeCount
        if gateFail == 0 {
            print("EXIT-GATE (open-ended free production falsely auto-graded): PASS (0) — free-phrase 0, interrogative 0; informational: comprehension \(comprehensionCount)")
        } else {
            print("EXIT-GATE (open-ended free production falsely auto-graded): FAIL (\(gateFail)) — free-phrase \(freePhraseCount), interrogative \(interrogativeCount); informational: comprehension \(comprehensionCount)")
        }
    }

    /// One stable, greppable instance line:
    /// [pack] activity  lesson=… step=…  kind=… accepted=N reason=… — "copy"
    private static func renderInstance(_ instance: OpenEndedInstance) -> String {
        let copy = instance.copy.count > 120
            ? String(instance.copy.prefix(120)) + "…"
            : instance.copy
        return "  [\(instance.packID)] \(instance.activityID) \(instance.locations) kind=\(instance.kindLabel) accepted=\(instance.acceptedCount) reason=\(instance.reason) — \"\(copy)\""
    }

    // MARK: - Original report

    private struct Counters {
        var textActivities = 0
        var textNoErrors = 0
        var clozeActivities = 0
        var clozeNoErrors = 0
        var clozeBlanks = 0
        var clozeBlankNoErrors = 0
        var gradedStepCount = 0
        var gradedStepHintGap = 0
        var informationCount = 0
        var selfCompareCount = 0
        var openTaskCount = 0
        var missionStoryLessons = 0
        var objectiveGap = 0
        var finalResponseGap = 0
    }

    // MARK: - Machine-readable per-lesson audit (--jsonl)

    /// One flagged element inside a lesson: a parallel-array row for the
    /// `stepId`/`activityId`/`activityKind` JSON fields. Deterministically
    /// sorted by (activityID, stepID, kind).
    private struct FlaggedElement: Comparable {
        let stepID: String
        let activityID: String
        let kind: String

        static func < (lhs: FlaggedElement, rhs: FlaggedElement) -> Bool {
            (lhs.activityID, lhs.stepID, lhs.kind) < (rhs.activityID, rhs.stepID, rhs.kind)
        }
    }

    /// One JSON object per lesson. `packName` is the pack basename (matches
    /// openEndedInstances.packID); `byID` maps activity id -> activity.
    private static func lessonAuditJSON(
        _ pack: CoursePack, packName: String, lesson: Lesson,
        byID: [String: Activity]
    ) -> [String: Any] {
        let steps = lesson.steps.sorted(by: { $0.id < $1.id })

        // First step id (lexicographically) that references each activity,
        // path or support, so activity-level flags can cite a concrete step.
        var firstStepByActivity: [String: String] = [:]
        for step in steps {
            if firstStepByActivity[step.activityId] == nil {
                firstStepByActivity[step.activityId] = step.id
            }
            if let support = step.supportActivityId, firstStepByActivity[support] == nil {
                firstStepByActivity[support] = step.id
            }
        }

        var elements: [FlaggedElement] = []
        var missingHint = 0
        var missingErrorFeedback = 0
        var missingObjective = false
        var missingFinalResponse = false
        var openEndedGradingFlag = 0
        var ungradedKinds: Set<String> = []

        // 1. Hint gaps: graded PATH steps whose hints are all generic/empty
        //    (mirrors the human report's step-level hint-gap count).
        for step in steps {
            guard let activity = byID[step.activityId], let base = activity.base else { continue }
            if base.hints.allSatisfy({ genericHints.contains($0) }) {
                missingHint += 1
                elements.append(FlaggedElement(stepID: step.id, activityID: step.activityId, kind: kindLabel(activity)))
            }
        }

        // 2. Error-feedback gaps: text/cloze surfaces (path or support)
        //    referenced by this lesson with empty errors[]. Cloze blanks are
        //    one surface each, matching the report's "surfaces" total. Also
        //    collect ungraded kinds present in the lesson.
        var seenActivities = Set<String>()
        for step in steps {
            var refs = [step.activityId]
            if let support = step.supportActivityId { refs.append(support) }
            for activityID in refs {
                guard let activity = byID[activityID], seenActivities.insert(activityID).inserted else { continue }
                switch activity {
                case .text(let spec):
                    if spec.answer.errors.isEmpty {
                        missingErrorFeedback += 1
                        elements.append(FlaggedElement(
                            stepID: firstStepByActivity[activityID] ?? "",
                            activityID: activityID, kind: "text"))
                    }
                case .cloze(let spec):
                    let blankGaps = spec.blanks.keys.sorted().filter { spec.blanks[$0]!.errors.isEmpty }
                    missingErrorFeedback += blankGaps.count
                    for blank in blankGaps {
                        elements.append(FlaggedElement(
                            stepID: firstStepByActivity[activityID] ?? "",
                            activityID: "\(activityID)#\(blank)", kind: "cloze"))
                    }
                case .information:
                    ungradedKinds.insert("information")
                case .selfCompare:
                    ungradedKinds.insert("self-compare")
                case .openTask:
                    ungradedKinds.insert("open-task")
                default:
                    break
                }
            }
        }

        // 3. Mission/story: non-empty objective and a text final-response
        //    step at the end of the path (mirrors the report's checks).
        if lesson.family == .mission || lesson.family == .story {
            if lesson.objective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                missingObjective = true
            }
            let terminals = lesson.steps.filter { $0.nextStepId == nil && $0.branches.isEmpty }
            let productionTerminal = terminals.contains { step in
                if case .text? = byID[step.activityId] { return true }
                return false
            }
            if terminals.isEmpty || !productionTerminal {
                missingFinalResponse = true
                let refSteps = terminals.isEmpty
                    ? steps.filter { $0.id == lesson.entryStepId }
                    : terminals
                for step in refSteps {
                    elements.append(FlaggedElement(
                        stepID: step.id, activityID: step.activityId,
                        kind: byID[step.activityId].map(kindLabel) ?? "?"))
                }
            }
        }

        // 4. Open-ended false-auto-grade gate instances in this lesson
        //    (free-phrase / bare interrogative only — the strict-enforceable
        //    subset; comprehension and dictated-answer prompts are
        //    informational in the human report and not flags here).
        for instance in openEndedInstances where instance.packID == packName {
            guard instance.reason.hasPrefix("free-phrase") || instance.reason == "interrogative" else { continue }
            let matching = steps.filter { $0.activityId == instance.activityID }
            guard !matching.isEmpty else { continue }
            openEndedGradingFlag += 1
            for step in matching {
                elements.append(FlaggedElement(
                    stepID: step.id, activityID: instance.activityID, kind: instance.kindLabel))
            }
        }

        elements.sort()
        let lessonPassable = missingHint == 0 && missingErrorFeedback == 0
            && !missingObjective && !missingFinalResponse && openEndedGradingFlag == 0

        return [
            "packId": pack.id,
            "unitId": lesson.unitId,
            "lessonId": lesson.id,
            "family": lesson.family.rawValue,
            "stepId": elements.map { $0.stepID },
            "activityId": elements.map { $0.activityID },
            "activityKind": elements.map { $0.kind },
            "missingHint": missingHint,
            "missingErrorFeedback": missingErrorFeedback,
            "missingFinalResponse": missingFinalResponse,
            "missingObjective": missingObjective,
            "ungradedType": ungradedKinds.sorted(),
            "openEndedGradingFlag": openEndedGradingFlag,
            "lessonPassable": lessonPassable,
        ]
    }

    /// Write one JSON object per lesson (deterministic order: fixed pack
    /// order, then lesson id) to `path`, one line per object.
    private static func writeJSONL(
        _ packs: [(name: String, pack: CoursePack)], to path: String
    ) throws {
        var lines: [String] = []
        for (name, pack) in packs {
            let byID = Dictionary(uniqueKeysWithValues: pack.activities.map { ($0.id, $0) })
            for lesson in pack.lessons.sorted(by: { $0.id < $1.id }) {
                let record = lessonAuditJSON(pack, packName: name, lesson: lesson, byID: byID)
                let data = try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
                lines.append(String(data: data, encoding: .utf8) ?? "")
            }
        }
        try (lines.joined(separator: "\n") + "\n").data(using: .utf8)!
            .write(to: URL(fileURLWithPath: path))
    }

    static func main() {
        guard CommandLine.arguments.count >= 2 else {
            print("usage: audit-editorial <ContentRoot> [--jsonl <path>] [--strict]")
            exit(2)
        }
        let packsDir = URL(fileURLWithPath: CommandLine.arguments[1])
            .appendingPathComponent("packs", isDirectory: true)
        var jsonlPath: String?
        var strict = false
        var args = Array(CommandLine.arguments.dropFirst(2))
        while !args.isEmpty {
            switch args.removeFirst() {
            case "--jsonl":
                guard !args.isEmpty else {
                    print("usage: audit-editorial <ContentRoot> [--jsonl <path>] [--strict]")
                    exit(2)
                }
                jsonlPath = args.removeFirst()
            case "--strict":
                strict = true
            case let unknown:
                print("unknown option: \(unknown)")
                exit(2)
            }
        }

        print("audit-editorial 1.1 — editorial backlog report (not a gate)")

        var allLoaded = true
        var allPacks: [(name: String, pack: CoursePack)] = []
        for name in packFilenames {
            let url = packsDir.appendingPathComponent(name).appendingPathExtension("json")
            do {
                let data = try Data(contentsOf: url)
                let pack = try JSONDecoder().decode(CoursePack.self, from: data)
                report(pack)
                collectOpenEnded(pack, packName: name, rawData: data)
                allPacks.append((name: name, pack: pack))
            } catch {
                allLoaded = false
                print("FAIL audit-editorial \(name).json: \(error)")
            }
        }
        if allLoaded {
            printOpenEndedSection()
            print("SUMMARY all five packs audited; exit 0 means packs loaded — treat counts as a backlog, not a pass/fail")

            if let jsonlPath {
                do {
                    try writeJSONL(allPacks, to: jsonlPath)
                    FileHandle.standardError.write(
                        Data("wrote \(allPacks.reduce(0) { $0 + $1.pack.lessons.count }) lesson records to \(jsonlPath)\n".utf8))
                } catch {
                    FileHandle.standardError.write(Data("FAIL writing --jsonl \(jsonlPath): \(error)\n".utf8))
                    exit(1)
                }
            }

            // Strict mode: fail ONLY on violations a solo worker can
            // objectively enforce — the open-ended false-auto-grade gate
            // (free-phrase + bare interrogative) and ungraded activities
            // wired to grading keys. Both are 0 today and must stay 0.
            // Hint/error-feedback gaps remain backlog/report-only: they are
            // being worked down over batches, not a gate yet.
            if strict {
                let openGraded = openEndedInstances.filter {
                    $0.reason.hasPrefix("free-phrase") || $0.reason == "interrogative"
                }.count
                let gateFail = openGraded + wiredInstances.count
                if gateFail > 0 {
                    print("STRICT-GATE FAIL: \(gateFail) enforceable violation(s) — open-ended falsely auto-graded \(openGraded), ungraded wired to answers \(wiredInstances.count)")
                    exit(1)
                }
            }
        }
        exit(allLoaded ? 0 : 1)
    }

    private static func report(_ pack: CoursePack) {
        let label = "\(pack.id) (\(pack.language.slug))"
        print("== \(label) ==")
        var c = Counters()
        let byID = Dictionary(uniqueKeysWithValues: pack.activities.map { ($0.id, $0) })

        // 1. Graded answer specs without authored error feedback. Text
        //    answers and each cloze blank are covered; legacy activities
        //    keep their error specs inside the retained v1 exercise, out of
        //    scope here (none are shipped in the current packs).
        var errorGapLines: [String] = []
        for activity in pack.activities.sorted(by: { $0.id < $1.id }) {
            switch activity {
            case .text(let spec):
                c.textActivities += 1
                if spec.answer.errors.isEmpty {
                    c.textNoErrors += 1
                    errorGapLines.append("  \(spec.id) — text answer has no authored errors")
                }
            case .cloze(let spec):
                c.clozeActivities += 1
                let names = spec.blanks.keys.sorted()
                let gaps = names.filter { spec.blanks[$0]!.errors.isEmpty }
                c.clozeBlanks += names.count
                c.clozeBlankNoErrors += gaps.count
                if !gaps.isEmpty {
                    c.clozeNoErrors += 1
                    errorGapLines.append("  \(spec.id) — cloze blanks \(gaps.joined(separator: ", ")) have no authored errors")
                }
            case .information:
                c.informationCount += 1
            case .selfCompare:
                c.selfCompareCount += 1
            case .openTask:
                c.openTaskCount += 1
            default:
                break
            }
        }
        print("no-error-feedback: \(c.textNoErrors) of \(c.textActivities) text and \(c.clozeNoErrors) of \(c.clozeActivities) cloze activities (\(c.clozeBlankNoErrors) of \(c.clozeBlanks) blanks) lack authored errors")
        printLines(capped: errorGapLines)

        // 2. Graded steps whose only hint is generic/absent, counted at the
        //    step level (path activity only, not support activities).
        var hintGapLines: [String] = []
        for lesson in pack.lessons.sorted(by: { $0.id < $1.id }) {
            for step in lesson.steps.sorted(by: { $0.id < $1.id }) {
                guard let activity = byID[step.activityId], let base = activity.base else { continue }
                c.gradedStepCount += 1
                if base.hints.allSatisfy({ genericHints.contains($0) }) {
                    c.gradedStepHintGap += 1
                    hintGapLines.append("  \(lesson.id) step \(step.id) — \(kindLabel(activity))")
                }
            }
        }
        print("hint-gap: \(c.gradedStepHintGap) of \(c.gradedStepCount) graded steps have no authored hint (or only a generic/fallback one)")
        printLines(capped: hintGapLines)

        // 3. Ungraded activity counts: deliberate design (they must be
        //    presented as not auto-graded), reported for coverage planning.
        print("ungraded: \(c.informationCount) information, \(c.selfCompareCount) self-compare, \(c.openTaskCount) open-task")

        // 4. Mission/story lessons: a non-empty objective and a free
        //    production (text) step at the end of the path — the final
        //    response. A missing terminal step, or terminals that are only
        //    selection/ordering/information/etc., fail the check.
        var msLines: [String] = []
        for lesson in pack.lessons.sorted(by: { $0.id < $1.id }) {
            guard lesson.family == .mission || lesson.family == .story else { continue }
            c.missionStoryLessons += 1
            if lesson.objective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                c.objectiveGap += 1
                msLines.append("  \(lesson.id) (\(lesson.family.rawValue)) — missing objective")
            }
            let terminals = lesson.steps.filter { $0.nextStepId == nil && $0.branches.isEmpty }
            let productionTerminal = terminals.contains { step in
                if case .text? = byID[step.activityId] { return true }
                return false
            }
            if terminals.isEmpty || !productionTerminal {
                c.finalResponseGap += 1
                let detail = terminals.sorted(by: { $0.id < $1.id })
                    .map { "\($0.id) (\(byID[$0.activityId].map(kindLabel) ?? "?")/\($0.purpose.rawValue))" }
                    .joined(separator: ", ")
                msLines.append("  \(lesson.id) (\(lesson.family.rawValue)) — no text final-response step; terminal: \(detail)")
            }
        }
        print("mission/story: \(c.missionStoryLessons) lessons — \(c.objectiveGap) missing objective, \(c.finalResponseGap) without a text final-response step")
        printLines(capped: msLines)

        let total = c.textNoErrors + c.clozeBlankNoErrors + c.gradedStepHintGap
            + c.informationCount + c.selfCompareCount + c.objectiveGap + c.finalResponseGap
        print("total: \(total) flagged items")
        print("SUMMARY \(label): total \(total) — error-feedback gap \(c.textNoErrors + c.clozeBlankNoErrors) surfaces, hint-gap \(c.gradedStepHintGap)/\(c.gradedStepCount) steps, ungraded \(c.informationCount) information + \(c.selfCompareCount) self-compare, mission/story final-response gap \(c.finalResponseGap)/\(c.missionStoryLessons)")
    }

    /// Print at most `listCap` lines, then a single "… and N more" line.
    private static func printLines(capped lines: [String]) {
        for line in lines.prefix(listCap) { print(line) }
        let remainder = lines.count - listCap
        if remainder > 0 { print("  … and \(remainder) more") }
    }

    private static func kindLabel(_ activity: Activity) -> String {
        switch activity {
        case .legacy: return "legacy"
        case .information: return "information"
        case .text: return "text"
        case .selection: return "selection"
        case .ordering: return "ordering"
        case .matching: return "matching"
        case .cloze: return "cloze"
        case .dialogueChoice: return "dialogue-choice"
        case .sceneSelection: return "scene-selection"
        case .selfCompare: return "self-compare"
        case .openTask: return "open-task"
        }
    }
}
