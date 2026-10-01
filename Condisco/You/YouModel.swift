import Foundation

// MARK: - You tab model
//
// Everything the profile screen shows, derived from the local event log:
// phrases the learner has worked with (grouped by what the evidence
// proves), practice stats, per-course progress, and comfort preferences.
// Signing in does not change what is shown — it only marks the progress as
// belonging to the learner's account so sync can carry it to their other
// devices.

// MARK: - Per-skill practice profile (5.2A)

extension Skill {
    /// Profile display order: reading, writing, listening, speaking,
    /// vocabulary, grammar — the skill tokens the packs actually use.
    static var profileOrder: [Skill] {
        [.reading, .writing, .listening, .speaking, .vocabulary, .grammar]
    }

    /// User-facing skill name for the practice profile.
    var profileLabel: String { rawValue.capitalized }
}

@MainActor
final class YouModel: ObservableObject {
    struct CourseStat: Identifiable {
        let id: String
        let title: String
        let languageName: String
        let done: Int
        let total: Int

        var percent: Int {
            guard total > 0 else { return 0 }
            return Int(
                (Double(done) / Double(total) * 100).rounded())
        }
    }

    struct EvidencePhrase: Identifiable {
        let id: String
        let text: String
        let context: String
    }

    /// How the learner worked with a phrase, derived from the event log.
    /// Labels are driven by this enum — the view never invents its own
    /// wording. `.practiced` is the plan's conservative fallback: the
    /// landing spot for evidence that cannot be classified honestly.
    /// No case ever claims the learner "can say" anything.
    enum PhraseEvidence: String, CaseIterable, Identifiable {
        /// Target-language production typed or cloze-filled with no help.
        case built
        /// Production that only ever happened with help (a hint or model).
        case practicedWithHints
        /// Recognition successes: picked, ordered, matched, or chosen.
        case recognized
        /// Self-assessed compare-and-repeat practice. Never speech proof.
        case speakingPractice
        /// Conservative fallback label for unclassifiable evidence.
        case practiced

        var id: String { rawValue }

        /// User-facing label. Wording is grounded in the events; the
        /// developer reviews it before shipping.
        var label: String {
            switch self {
            case .built: return "Phrases you built or typed"
            case .practicedWithHints: return "Phrases you practised (with hints)"
            case .recognized: return "Phrases you recognised"
            case .speakingPractice: return "Speaking practice (self-assessed)"
            case .practiced: return "Phrases you practised"
            }
        }
    }

    /// A non-empty evidence group with its pre-published label.
    struct PhraseGroup: Identifiable {
        let kind: PhraseEvidence
        let phrases: [EvidencePhrase]
        var id: String { kind.rawValue }
        var label: String { kind.label }
    }

    /// Phrase lists, grouped and labelled by what the events prove.
    @Published var groups: [PhraseGroup] = []
    @Published var daysPractised = 0
    @Published var dueCount = 0
    @Published var courses: [CourseStat] = []

    /// One skill's row in the focus-language practice profile. Counts are
    /// "times practised" — correct attempts on that skill's activities, help
    /// included — never ability. There is deliberately no overall score: a
    /// learner can be further along in reading than listening, and the
    /// profile shows that divergence row by row.
    struct SkillPractice: Identifiable {
        let skill: Skill
        /// Valid graded or self-assessed practice, including help.
        var practisedTimes: Int
        /// Most recent valid practice on this skill, for the staleness row.
        var lastPractisedAt: Date?
        /// Due review cards whose activity carries this skill.
        var dueCount: Int

        var id: Skill { skill }
        var label: String { skill.profileLabel }
    }

    /// Focus-language per-skill practice rows (5.2A).
    @Published var skillPractice: [SkillPractice] = []
    /// A reachable practice destination with an explicit replay mode.
    struct PracticeRecommendation: Identifiable {
        let packId: String
        let lessonId: String?
        let skill: Skill
        let title: String
        var startFresh: Bool = false
        var id: String { packId + "|" + (lessonId ?? "review") }
    }
    struct OpenResponseSummary {
        let withoutModelOrHelp: Int
        let withModelOrHelp: Int
    }
    @Published var practiceRecommendation: PracticeRecommendation?
    @Published var openResponses = OpenResponseSummary(withoutModelOrHelp: 0, withModelOrHelp: 0)

    static func openResponseSummary(progress: PackProgress) -> OpenResponseSummary {
        let tasks = progress.openTaskAttempts
        let turns = progress.dialogueTurns.filter(\.isOpen)
        return OpenResponseSummary(
            withoutModelOrHelp: tasks.filter(\.independent).count
                + turns.filter { !$0.modelRevealed }.count,
            withModelOrHelp: tasks.filter { !$0.independent }.count
                + turns.filter(\.modelRevealed).count)
    }

    /// A concrete available task, using existing content and routing.
    /// Due cards win; otherwise a never-practised available skill comes
    /// before the stalest practised skill. Completed lessons remain revisitable.
    static func recommendedPractice(
        pack: CoursePack, practice: [SkillPractice], completedLessons: Set<String>
    ) -> PracticeRecommendation? {
        let order = Dictionary(uniqueKeysWithValues: Skill.profileOrder.enumerated().map { ($1, $0) })
        if let row = practice.filter({ $0.dueCount > 0 }).sorted(by: {
            if $0.dueCount != $1.dueCount { return $0.dueCount > $1.dueCount }
            return (order[$0.skill] ?? 0) < (order[$1.skill] ?? 0)
        }).first {
            return PracticeRecommendation(packId: pack.id, lessonId: nil, skill: row.skill,
                                          title: "Review your due cards")
        }
        let rows = practice.sorted {
            let left = $0.lastPractisedAt ?? .distantPast
            let right = $1.lastPractisedAt ?? .distantPast
            if left != right { return left < right }
            return (order[$0.skill] ?? 0) < (order[$1.skill] ?? 0)
        }
        func skills(_ activity: Activity) -> [Skill] {
            switch activity {
            case .selfCompare(let spec): return spec.skills
            case .openTask(let spec): return spec.skills
            default: return activitySkills(activity)
            }
        }
        let activities = Dictionary(uniqueKeysWithValues: pack.activities.map { ($0.id, $0) })
        for row in rows {
            let available = pack.lessons.filter { lesson in
                lesson.steps.contains { step in
                    activities[step.activityId].map { skills($0).contains(row.skill) } ?? false
                }
            }
            if let lesson = available.first(where: { !completedLessons.contains($0.id) }) ?? available.first {
                return PracticeRecommendation(packId: pack.id, lessonId: lesson.id, skill: row.skill,
                    title: "Practise \(row.skill.rawValue): \(lesson.title)",
                    startFresh: completedLessons.contains(lesson.id))
            }
        }
        return nil
    }

    @Published var isLoading = true
    @Published var loadError: String?

    @Published var largeText = A11ySettings.shared.largeText {
        didSet { A11ySettings.shared.largeText = largeText }
    }
    @Published var reduceMotion = A11ySettings.shared.reduceMotion {
        didSet { A11ySettings.shared.reduceMotion = reduceMotion }
    }

    /// Loads the profile from the local event log. `focusSlug` selects
    /// the pack whose per-skill practice profile the section shows
    /// (data-driven per pack; falls back to the first pack).
    func load(focusSlug: String) async {
        do {
            let store = try LearningStore.inDocuments()
            let packs = try PackLoader.loadPacks()
            let focusPack = packs.first { $0.language.slug == focusSlug }
                ?? packs.first
            var courses: [CourseStat] = []
            // Phrase evidence accumulates per group across packs, in pack
            // order, under the same section-wide cap the flat list used:
            // the first 12 phrases, however they group.
            var budget = 12
            var grouped: [PhraseEvidence: [EvidencePhrase]] = [:]
            self.skillPractice = []
            self.practiceRecommendation = nil
            self.openResponses = OpenResponseSummary(withoutModelOrHelp: 0, withModelOrHelp: 0)
            for pack in packs {
                let progress = try store.project(pack: pack)
                courses.append(CourseStat(
                    id: pack.id,
                    title: pack.title,
                    languageName: pack.language.displayName,
                    done: progress.finishedLessons.count,
                    total: pack.lessons.count))
                if pack.id == focusPack?.id {
                    // Focus-language profile: one row per skill, built from
                    // the pack's due set so the counts reuse the existing
                    // review scheduler (no new scheduler).
                    let dueItems = try ReviewCatalog.loadCourseDue(
                        packs: [pack], store: store).due
                    let events = try store
                        .learningEventsWithQuarantine(packId: pack.id).events
                    self.skillPractice = Self.skillPractice(
                        pack: pack, events: events, dueItems: dueItems)
                    self.practiceRecommendation = Self.recommendedPractice(
                        pack: pack, practice: self.skillPractice, completedLessons: progress.finishedLessons)
                    self.openResponses = Self.openResponseSummary(progress: progress)
                }
                guard budget > 0 else { continue }
                let events = try store
                    .learningEventsWithQuarantine(packId: pack.id).events
                let packGroups = Self.evidenceGroups(
                    pack: pack, events: events)
                for kind in PhraseEvidence.allCases {
                    let phrases = packGroups[kind] ?? []
                    guard budget > 0, !phrases.isEmpty else { continue }
                    let take = min(phrases.count, budget)
                    grouped[kind, default: []]
                        .append(contentsOf: phrases.prefix(take))
                    budget -= take
                }
            }
            self.courses = courses
            self.dueCount = try ReviewCatalog.loadDue(packs: packs, store: store).due.count
            self.groups = PhraseEvidence.allCases.compactMap { kind in
                guard let phrases = grouped[kind], !phrases.isEmpty else {
                    return nil
                }
                return PhraseGroup(kind: kind, phrases: phrases)
            }
            self.daysPractised = try store.practiceDays()
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    func refresh(focusSlug: String) async {
        isLoading = true
        loadError = nil
        await load(focusSlug: focusSlug)
    }

    // MARK: - Per-skill practice projection (5.2A)

    /// Groups current-revision practice: correct graded attempts and
    /// self-assessed speaking/writing tasks, help included, when it was
    /// last practised, and how many due review cards carry that skill.
    /// `dueItems` is the pack's due set already resolved through
    /// `ReviewCatalog.loadCourseDue`, so the due counts reuse the existing
    /// review scheduler's logic — no new scheduler here.
    ///
    /// Attempts are validated exactly like `LearningStore.project` (known
    /// lesson/step/activity, matching revisions, the activity's own
    /// evidence key). Self-assessed tasks contribute practice only; they
    /// do not create SRS evidence.
    /// V1 practice rows carry no activity/skill mapping and never count
    /// here — their old progress stays in legacy completion credit.
    static func skillPractice(
        pack: CoursePack, events: [LearningEvent], dueItems: [ReviewItem]
    ) -> [SkillPractice] {
        let lessonsById = Dictionary(
            uniqueKeysWithValues: pack.lessons.map { ($0.id, $0) })
        let activitiesById = Dictionary(
            uniqueKeysWithValues: pack.activities.map { ($0.id, $0) })
        var practised: [Skill: Int] = [:]
        var lastAt: [Skill: Date] = [:]
        func record(_ skills: [Skill], at: Date) {
            for skill in Set(skills) {
                practised[skill, default: 0] += 1
                if lastAt[skill] == nil || at > lastAt[skill]! { lastAt[skill] = at }
            }
        }
        for event in events {
            switch event {
            case .attempt(let attempt):
                guard attempt.packId == pack.id,
                      let lesson = lessonsById[attempt.lessonId],
                      let activity = activitiesById[attempt.activityId],
                      let step = lesson.steps.first(where: { $0.id == attempt.stepId }),
                      step.activityId == attempt.activityId,
                      lesson.revision == attempt.lessonRevision,
                      activity.revision == attempt.activityRevision,
                      activity.evidenceKey == attempt.evidenceKey else { continue }
                if case .selfCompare(let spec) = activity {
                    guard attempt.evaluation.outcome == .selfAssessed else { continue }
                    record(spec.skills, at: attempt.at)
                } else {
                    guard attempt.evaluation.outcome == .correct else { continue }
                    record(activitySkills(activity), at: attempt.at)
                }
            case .openTaskAttempt(let attempt):
                guard attempt.packId == pack.id,
                      let lesson = lessonsById[attempt.lessonId],
                      lesson.revision == attempt.lessonRevision,
                      lesson.steps.contains(where: {
                          $0.id == attempt.stepId && $0.activityId == attempt.activityId
                      }),
                      let activity = activitiesById[attempt.activityId],
                      case .openTask(let spec) = activity,
                      spec.revision == attempt.activityRevision,
                      spec.mode == attempt.mode else { continue }
                record(spec.skills, at: attempt.at)
            default: break
            }
        }
        var dueCounts: [Skill: Int] = [:]
        for item in dueItems {
            guard let activity = activitiesById[item.activityId] else { continue }
            for skill in activitySkills(activity) {
                dueCounts[skill, default: 0] += 1
            }
        }
        return Skill.profileOrder.map { skill in
            SkillPractice(
                skill: skill,
                practisedTimes: practised[skill] ?? 0,
                lastPractisedAt: lastAt[skill],
                dueCount: dueCounts[skill] ?? 0)
        }
    }

    /// The one-line suggested next task, honest and grounded in the rows:
    /// the skill with the most due cards wins ("Review 3 writing cards");
    /// with nothing due, the stalest practised skill ("Practise reading —
    /// no reviews due"). Ties break to the stalest, then declaration
    /// order, so the pick is deterministic. No proficiency language.
    static func suggestedNextTask(in practice: [SkillPractice]) -> String? {
        let ordered = practice.sorted { lhs, rhs in
            if lhs.dueCount != rhs.dueCount { return lhs.dueCount > rhs.dueCount }
            let l = lhs.lastPractisedAt ?? .distantFuture
            let r = rhs.lastPractisedAt ?? .distantFuture
            if l != r { return l < r }
            return lhs.skill.rawValue < rhs.skill.rawValue
        }
        guard let first = ordered.first else { return nil }
        if first.dueCount > 0 {
            let noun = first.dueCount == 1 ? "card" : "cards"
            return "Review \(first.dueCount) \(first.skill.rawValue) \(noun)"
        }
        guard let stalest = ordered.first(where: { $0.lastPractisedAt != nil })
        else { return nil }
        return "Practise \(stalest.skill.rawValue) — no reviews due"
    }

    /// Builds the data-export file, or nil when it cannot be produced.
    func exportData() -> URL? {
        guard let store = try? LearningStore.inDocuments() else { return nil }
        return try? DataExport.buildFile(store: store)
    }

    /// Applies a validated export to this device's store.
    ///
    /// The caller must have run `ImportValidator.validate` first and shown
    /// the preview; this is the write step after explicit confirmation.
    /// The database merge happens in one transaction inside the store, so
    /// a conflict or failure leaves it unchanged. Placement
    /// recommendations live in UserDefaults and are written only after
    /// that transaction has committed — a failed import changes nothing
    /// anywhere.
    func restore(_ preview: ImportPreview) throws {
        let store = try LearningStore.inDocuments()
        try store.applyImport(preview)
        for entry in preview.placement {
            PlacementStore.save(
                packId: entry.packId,
                lessonId: entry.recommendedLessonId)
        }
    }

    // MARK: - Phrase evidence (was "What you can say")

    /// Target-language phrases grouped by the evidence the events prove.
    ///
    /// Before: any phrase with a recorded success — including recognition
    /// (selection, ordering, matching, dialogue choice) — was presented as
    /// something the learner "can say". That overclaims: picking the right
    /// option is recognition, not production.
    ///
    /// Now the split is evidence-specific and grounded:
    /// - `.built`: text/cloze completed correctly with no help.
    /// - `.practicedWithHints`: text/cloze completed correctly only with
    ///   help — shown as practice, never as independent production.
    /// - `.recognized`: selection/ordering/matching/dialogue-choice
    ///   successes, using the app's definition of success (correct +
    ///   independent) so the group agrees with SRS state.
    /// - `.speakingPractice`: self-compare/self-rating activity. There is
    ///   no audio event; this is self-assessed practice, never speech
    ///   evidence, so it is worded as self-assessment.
    ///
    /// Attempts are validated exactly like `LearningStore.project` (known
    /// lesson/step/activity, matching revisions, the activity's own
    /// evidence key), so the lists can never disagree with SRS. Manual
    /// "I know this" marks are `lesson-known` events, not attempts, and
    /// are ignored here by construction: a manual mark never implies
    /// mastery in these lists.
    static func evidenceGroups(
        pack: CoursePack, events: [LearningEvent]
    ) -> [PhraseEvidence: [EvidencePhrase]] {
        let lessonsById = Dictionary(
            uniqueKeysWithValues: pack.lessons.map { ($0.id, $0) })
        let activitiesById = Dictionary(
            uniqueKeysWithValues: pack.activities.map { ($0.id, $0) })
        var lessonTitleByActivity: [String: String] = [:]
        for lesson in pack.lessons {
            for step in lesson.steps {
                lessonTitleByActivity[step.activityId] = lesson.title
            }
        }

        var attemptsByActivity: [String: [ActivityAttempt]] = [:]
        for case .attempt(let attempt) in events where attempt.packId == pack.id {
            guard let lesson = lessonsById[attempt.lessonId],
                  let activity = activitiesById[attempt.activityId],
                  let step = lesson.steps.first(where: { $0.id == attempt.stepId }),
                  step.activityId == attempt.activityId,
                  lesson.revision == attempt.lessonRevision,
                  activity.revision == attempt.activityRevision,
                  activity.evidenceKey == attempt.evidenceKey
            else { continue }
            attemptsByActivity[attempt.activityId, default: []].append(attempt)
        }

        var groups: [PhraseEvidence: [EvidencePhrase]] = [:]
        func addPhrase(_ phrase: EvidencePhrase, kind: PhraseEvidence) {
            guard !(groups[kind] ?? []).contains(where: { $0.id == phrase.id }) else {
                return
            }
            groups[kind, default: []].append(phrase)
        }

        for activity in pack.activities {
            let attempts = attemptsByActivity[activity.id] ?? []
            guard !attempts.isEmpty,
                  let text = Self.phraseText(for: activity),
                  !text.isEmpty
            else { continue }
            let phrase = EvidencePhrase(
                id: "\(pack.id):\(activity.evidenceKey ?? activity.id)",
                text: text,
                context: lessonTitleByActivity[activity.id]
                    ?? pack.language.displayName)
            switch activity {
            case .text, .cloze:
                if attempts.contains(where: Self.isIndependentCorrect) {
                    // One clean success really is "built or typed"; hints
                    // used on other tries are not hidden, but the label
                    // never claims a no-hint run.
                    addPhrase(phrase, kind: .built)
                } else if attempts.contains(where: Self.isAssistedCorrect) {
                    // Done correctly only with help: identified as such,
                    // never lumped into independent production.
                    addPhrase(phrase, kind: .practicedWithHints)
                }
            case .selection, .ordering, .matching, .dialogueChoice:
                if attempts.contains(where: Self.isIndependentCorrect) {
                    addPhrase(phrase, kind: .recognized)
                }
            case .selfCompare:
                if attempts.contains(where: {
                    $0.evaluation.outcome == .selfAssessed
                }) {
                    addPhrase(phrase, kind: .speakingPractice)
                }
            case .legacy, .information, .sceneSelection, .openTask:
                // No plain-text answer worth quoting; nothing to show.
                // Open tasks carry no automatic judgement at all — their
                // model response is the author's, never the learner's.
                continue
            }
        }
        return groups
    }

    /// True when an attempt is a clean, help-free correct answer — the
    /// same definition of success the SRS evidence projection uses.
    private static func isIndependentCorrect(_ attempt: ActivityAttempt) -> Bool {
        attempt.evaluation.outcome == .correct && attempt.evaluation.independent
    }

    /// True when an attempt is correct but was tainted by assistance.
    private static func isAssistedCorrect(_ attempt: ActivityAttempt) -> Bool {
        attempt.evaluation.outcome == .correct && !attempt.evaluation.independent
    }

    /// The target-language string an activity is about, or nil when the
    /// kind has no plain-text answer worth quoting (reading steps, image
    /// scenes, v1 legacy rows). Self-compare returns the model sentence
    /// the learner compared against — quoted as practice material, never
    /// as the learner's own output.
    private static func phraseText(for activity: Activity) -> String? {
        switch activity {
        case .text(let a):
            return a.answer.answers.joined(separator: " · ")
        case .selection(let a):
            return a.options
                .filter { a.acceptedIds.contains($0.id) }
                .map(\.text).joined(separator: " · ")
        case .ordering(let a):
            let tokensById = Dictionary(
                uniqueKeysWithValues: a.tokens.map { ($0.id, $0.text) })
            guard let order = a.acceptedOrders.first else { return nil }
            let text = order.compactMap { tokensById[$0] }
                .joined(separator: " ")
            return text.isEmpty ? nil : text
        case .matching(let a):
            let leftById = Dictionary(
                uniqueKeysWithValues: a.left.map { ($0.id, $0.text) })
            let rightById = Dictionary(
                uniqueKeysWithValues: a.right.map { ($0.id, $0.text) })
            let text = a.acceptedPairs.map { pair in
                let left = leftById[pair.leftId] ?? pair.leftId
                let right = rightById[pair.rightId] ?? pair.rightId
                return "\(left) → \(right)"
            }.joined(separator: " · ")
            return text.isEmpty ? nil : text
        case .cloze(let a):
            let text = a.segments.map { segment -> String in
                switch segment {
                case .text(let t): return t
                case .blank(let name, _):
                    let answer = a.blanks[name]?.answers.first ?? "…"
                    return "«\(answer)»"
                }
            }.joined()
            return text.isEmpty ? nil : text
        case .dialogueChoice(let a):
            let text = a.options
                .filter { a.acceptedIds.contains($0.id) }
                .map(\.text).joined(separator: " · ")
            return text.isEmpty ? nil : text
        case .selfCompare(let a):
            return a.modelText.isEmpty ? nil : a.modelText
        case .openTask:
            // The model response is the author's example, never a phrase
            // the learner produced — nothing worth quoting as evidence.
            return nil
        case .legacy, .sceneSelection, .information:
            return nil
        }
    }
}

// MARK: - Data export
//
// The learner's data, portable. Events are the source of truth — SRS state,
// completion, and stats all project from them — and checkpoints plus listen
// state ride along so nothing is lost in the move. Tombstones ride along too:
// a checkpoint or saved phrase that was deleted stays deleted on restore
// instead of resurrecting from an older copy. Placement suggestions (stored
// in UserDefaults) are included as portable learner-owned data. Device-only
// preferences — comfort toggles, TTS voices, focus language, reminders,
// sign-in identity, sync bookkeeping, on-device markers — are deliberately
// not exported.

/// Everything the app knows about the learner, as JSON.
///
/// `formatVersion` is the export-format contract: readers (the restore flow
/// in 1.2, or tools) must check it before interpreting the payload. Bump it
/// whenever a field is added, removed, or changes meaning. The event payloads
/// keep their own `eventVersion`/`type` markers and are byte-identity with
/// the store's `payload` column, so an event restored from any export
/// decodes exactly like the original row.
struct ExportedLearningData: Codable {
    /// App identifier marker: which app produced this file.
    var app: String
    /// Export format version. Current: 2 (imported library documents and
    /// their phrase links added; 8.2 §7).
    var formatVersion: Int
    var exportedAt: Date
    var events: [LearningEvent]
    var checkpoints: [StoredCheckpoint]
    var checkpointTombstones: [CheckpointTombstone]
    var listenState: [ListenStateRow]
    var savedPhrases: [StoredSavedPhrase]
    var savedPhraseTombstones: [SavedPhraseTombstone]
    var placement: [ExportedPlacement]
    /// 8.2: the learner's imported library documents and the phrases saved
    /// from them (v2+). Optional so a version-1 file — which never carried
    /// these sections — still decodes unchanged; nil encodes as an omitted
    /// key, so v2 exports always carry the arrays while v1 files stay
    /// byte-compatible with the older reader.
    var importedDocuments: [StoredImportedDocument]? = nil
    var importedPhraseLinks: [StoredImportedPhraseLink]? = nil
}

/// A placement recommendation: the lesson the level check suggested for a
/// pack. Lives in UserDefaults on-device (`condisco.placement.<packId>`);
/// the export carries it so a new device can show the same suggestion.
struct ExportedPlacement: Codable, Equatable {
    var packId: String
    var recommendedLessonId: String
}

enum DataExport {
    /// The current export format version. Bump when the shape of
    /// `ExportedLearningData` changes in a breaking way; readers compare
    /// against this before decoding. Version 2 adds the imported-library
    /// document and phrase-link sections (8.2 §7); version 1 files stay
    /// readable (back-compat is mandatory).
    static let formatVersion = 2

    /// UserDefaults prefix `PlacementStore` uses for its keys.
    private static let placementPrefix = "condisco.placement."

    /// Builds the export file in a temporary directory, ready for a
    /// ShareLink. Throws when the store cannot be read or the file cannot
    /// be written. Fully offline: nothing here touches the network.
    /// The learner's imported documents ride along — the only path that
    /// lets them leave this device (8.2 §7).
    @MainActor
    static func buildFile(store: LearningStore) throws -> URL {
        let payload = ExportedLearningData(
            app: "Condisco",
            formatVersion: Self.formatVersion,
            exportedAt: Date(),
            events: try store.allEvents(),
            checkpoints: try store.allCheckpoints(),
            checkpointTombstones: try store.allCheckpointTombstones(),
            listenState: try store.allListenState(),
            savedPhrases: try store.allSavedPhrases(),
            savedPhraseTombstones: try store.allSavedPhraseTombstones(),
            placement: Self.placementRecommendations(),
            importedDocuments: try store.allImportedDocuments(),
            importedPhraseLinks: try store.allImportedPhraseLinks())
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        let stamp = ISO8601DateFormatter()
            .string(from: payload.exportedAt)
            .replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("condisco-export-\(stamp).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Every placement recommendation on this device, pack id ascending.
    /// Placement persists in UserDefaults (see `PlacementStore`), so the
    /// export reads it directly rather than through the store.
    private static func placementRecommendations() -> [ExportedPlacement] {
        UserDefaults.standard.dictionaryRepresentation()
            .filter { $0.key.hasPrefix(placementPrefix) }
            .sorted { $0.key < $1.key }
            .compactMap { key, value in
                guard let lessonId = value as? String, !lessonId.isEmpty else {
                    return nil
                }
                return ExportedPlacement(
                    packId: String(key.dropFirst(placementPrefix.count)),
                    recommendedLessonId: lessonId)
            }
    }
}
