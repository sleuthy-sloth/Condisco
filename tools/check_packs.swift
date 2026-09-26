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