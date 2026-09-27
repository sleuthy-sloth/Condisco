import SwiftUI

// MARK: - Courses tab
//
// Course list → lesson list (grouped by unit) → lesson player.
// Progress comes from LearningStore.project(pack:); the player reports
// completion through onExit so the lists refresh when a lesson ends.

@MainActor
final class CoursesModel: ObservableObject {
    @Published var packs: [CoursePack] = []
    @Published var progress: [String: PackProgress] = [:]
    @Published var loadError: String?
    @Published var isLoading = true
    @AppStorage("condisco.focusLanguage") var focusSlug = "french"

    private var store: LearningStore?

    func load() async {
        do {
            let store = try LearningStore.inDocuments()
            self.store = store
            let packs = try PackLoader.loadPacks()
            var progress: [String: PackProgress] = [:]
            for pack in packs {
                progress[pack.id] = try store.project(pack: pack)
            }
            self.packs = packs
            self.progress = progress
            applyFocusOrder()
            WidgetSnapshotWriter.refresh(packs: packs, focusSlug: focusSlug)
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    /// The focus language sorts first; the rest keep catalog order.
    func applyFocusOrder() {
        packs.sort { a, b in
            let aKey = (a.language.slug == focusSlug ? 0 : 1,
                        PackLoader.packFilenames.firstIndex(of: a.language.slug) ?? 99)
            let bKey = (b.language.slug == focusSlug ? 0 : 1,
                        PackLoader.packFilenames.firstIndex(of: b.language.slug) ?? 99)
            return aKey < bKey
        }
    }

    func refreshProgress() {
        guard let store else { return }
        for pack in packs {
            if let projected = try? store.project(pack: pack) {
                progress[pack.id] = projected
            }
        }
        // Lesson exits land here via onProgressRefresh; the widget's
        // next-lesson card and review count may both have changed.
        WidgetSnapshotWriter.refresh(packs: packs, focusSlug: focusSlug)
    }

    func makeStore() -> LearningStore? { store }
}

private enum CourseRoute: Hashable {
    case lessons(packId: String)
    case vocabulary(packId: String)
}

private struct SelectedLesson: Identifiable {
    let id: String
}

// MARK: - Content paths (Foundation → Developing → Independent)
//
// The course browser organises content into three paths derived from
// metadata already authored in the packs — never from a learner's results:
//
//   · lesson.cefr: "A2" → Developing; "A1" or absent → Foundation;
//     anything else → Independent (none today, shown honestly as empty).
//   · a path's task outcomes are the unit objectives of the units that
//     map to it (authored copy, not claims invented by the UI).
//   · a path's prerequisite line reflects the real prerequisite edges
//     between lessons: each Developing path opens with a lesson whose
//     prerequisites include a Foundation lesson.
//
// The labels describe content alignment, not ability: no level shown here
// is a test result or a score.

/// The three content paths, in progression order. Foundation and
/// Developing both have content today; Independent is an honest empty
/// state until lessons exist at that level.
private enum CoursePath: String, CaseIterable, Identifiable {
    case foundation, developing, independent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .foundation: return "Foundation"
        case .developing: return "Developing"
        case .independent: return "Independent"
        }
    }
}

struct CoursesView: View {
    @StateObject private var model = CoursesModel()

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.canvas.ignoresSafeArea()
                if model.isLoading {
                    ProgressView()
                        .tint(DesignTokens.primary)
                } else if let error = model.loadError {
                    loadErrorView(error)
                } else {
                    courseList
                }
            }
            .navigationTitle("Courses")
            .navigationDestination(for: CourseRoute.self) { route in
                switch route {
                case .lessons(let packId):
                    if let pack = model.packs.first(where: { $0.id == packId }),
                       let store = model.makeStore() {
                        LessonListView(
                            pack: pack,
                            progress: model.progress[pack.id] ?? PackProgress(),
                            store: store,
                            onProgressRefresh: { model.refreshProgress() }
                        )
                    }
                case .vocabulary(let packId):
                    if let pack = model.packs.first(where: { $0.id == packId }) {
                        VocabularyBrowserView(pack: pack)
                    }
                }
            }
            .onChange(of: model.focusSlug) { _, _ in model.applyFocusOrder() }
        }
        .task { await model.load() }
        .onReceive(
            NotificationCenter.default.publisher(for: .condiscoProgressChanged)
        ) { _ in
            // A deep-linked lesson closed or a known mark changed.
            model.refreshProgress()
        }
    }

    private var courseList: some View {
        ScrollView {
            VStack(spacing: 14) {
                pathSection
                ForEach(model.packs, id: \.id) { pack in
                    NavigationLink(value: CourseRoute.lessons(packId: pack.id)) {
                        courseRow(pack)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }

    private func courseRow(_ pack: CoursePack) -> some View {
        let done = model.progress[pack.id]?.finishedLessons.count ?? 0
        let total = pack.lessons.count
        let finishedSet = model.progress[pack.id]?.finishedLessons ?? []
        let remainingMinutes = pack.lessons
            .filter { !finishedSet.contains($0.id) }
            .reduce(0) { $0 + $1.estimatedMinutes }
        return PaperCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(pack.language.displayName)
                    .font(DesignTokens.text(13, weight: .semibold))
                    .foregroundStyle(DesignTokens.primary)
                    .textCase(.uppercase)
                Text(pack.title)
                    .font(DesignTokens.display(20))
                    .foregroundStyle(DesignTokens.inkDeep)
                Text(pack.description)
                    .font(DesignTokens.text(14))
                    .foregroundStyle(DesignTokens.muted)
                    .lineLimit(2)
                if remainingMinutes > 0 {
                    Text("~\(remainingMinutes) min left")
                        .font(DesignTokens.text(13))
                        .foregroundStyle(DesignTokens.muted)
                }
                HStack {
                    Text("\(done) of \(total) lessons complete")
                        .font(DesignTokens.text(13))
                        .foregroundStyle(DesignTokens.muted)
                    Spacer()
                    lessonProgressBar(done: done, total: total)
                        .accessibilityHidden(true)
                }
                .padding(.top, 4)
            }
        }
    }

    private func lessonProgressBar(done: Int, total: Int) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(DesignTokens.stock3)
                    .frame(height: 6)
                if total > 0 {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(DesignTokens.primary)
                        .frame(
                            width: geometry.size.width * CGFloat(done) / CGFloat(total),
                            height: 6
                        )
                }
            }
        }
        .frame(width: 110, height: 6)
    }

    // MARK: - Content paths (Foundation → Developing → Independent)

    /// The three path cards, in progression order, above the course list.
    /// Each card shows what the path actually contains — lesson counts,
    /// unit objectives as task outcomes, and the path's prerequisite
    /// relationship — with the level labelled as content, never ability.
    private var pathSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Course levels")
                    .font(DesignTokens.text(18, weight: .semibold))
                    .foregroundStyle(DesignTokens.inkDeep)
                    .padding(.horizontal, 4)
                    .accessibilityAddTraits(.isHeader)
                Text("Content structure, not a test result.")
                    .font(DesignTokens.text(13))
                    .foregroundStyle(DesignTokens.muted)
                    .padding(.horizontal, 4)
            }
            ForEach(CoursePath.allCases, id: \.self) { path in
                pathCard(path)
            }
        }
    }

    private func pathCard(_ path: CoursePath) -> some View {
        let stats = pathStats(path)
        return PaperCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(path.title)
                    .font(DesignTokens.display(20))
                    .foregroundStyle(DesignTokens.inkDeep)
                if stats.lessons > 0 {
                    Text("\(stats.lessons) lessons across \(stats.courses) courses")
                        .font(DesignTokens.text(13))
                        .foregroundStyle(DesignTokens.muted)
                    if let outcome = pathOutcomeLine(path) {
                        Text(outcome)
                            .font(DesignTokens.text(13))
                            .foregroundStyle(DesignTokens.muted)
                            .lineLimit(2)
                    }
                } else {
                    Text("No lessons at this level yet.")
                        .font(DesignTokens.text(13))
                        .foregroundStyle(DesignTokens.muted)
                }
                Text(pathPrerequisiteLine(path))
                    .font(DesignTokens.text(13))
                    .foregroundStyle(DesignTokens.muted)
            }
        }
    }

    /// Lesson counts per path, plus how many courses carry that path.
    private func pathStats(_ path: CoursePath) -> (lessons: Int, courses: Int) {
        var lessons = 0
        var courses = 0
        for pack in model.packs {
            let count = pack.lessons.filter { coursePath(of: $0) == path }.count
            if count > 0 { courses += 1 }
            lessons += count
        }
        return (lessons, courses)
    }

    /// A lesson's path from its authored level tag: A2 → Developing,
    /// A1 or absent → Foundation, anything else → Independent.
    private func coursePath(of lesson: Lesson) -> CoursePath {
        switch lesson.cefr {
        case "A2": return .developing
        case "A1", nil: return .foundation
        default: return .independent
        }
    }

    /// A unit's path is the path of its first lesson; every unit today is
    /// uniform within one path.
    private func coursePath(of unit: CourseUnit, in pack: CoursePack) -> CoursePath {
        guard let first = pack.lessons.first(where: { $0.unitId == unit.id }) else {
            return .foundation
        }
        return coursePath(of: first)
    }

    /// The task-outcome line for a path: up to three distinct unit
    /// objectives from the units on that path, focus course first, exactly
    /// as authored — the UI adds no claims of its own.
    private func pathOutcomeLine(_ path: CoursePath) -> String? {
        var seen = Set<String>()
        var lines: [String] = []
        for pack in model.packs {
            for unit in pack.units where coursePath(of: unit, in: pack) == path {
                let objective = unit.objective
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !objective.isEmpty, seen.insert(objective).inserted else { continue }
                lines.append(objective)
                if lines.count == 3 { return lines.joined(separator: " · ") }
            }
        }
        return lines.isEmpty ? nil : lines.joined(separator: " · ")
    }

    /// The path's prerequisite line, grounded in the real prerequisite
    /// edges authored on lessons rather than a claim about the learner.
    private func pathPrerequisiteLine(_ path: CoursePath) -> String {
        switch path {
        case .foundation:
            return "No earlier path — the starting point for every course."
        case .developing:
            return "Builds on Foundation — its opening lesson requires a Foundation lesson."
        case .independent:
            return "Would follow Developing."
        }
    }

    private func loadErrorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text("Couldn't load courses")
                .font(DesignTokens.display(20))
                .foregroundStyle(DesignTokens.inkDeep)
            Text(message)
                .font(DesignTokens.text(14))
                .foregroundStyle(DesignTokens.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Try again") {
                Task { await model.load() }
            }
            .font(DesignTokens.text(15, weight: .semibold))
            .foregroundStyle(DesignTokens.stock)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(DesignTokens.primary)
            .cornerRadius(8)
            .frame(minHeight: 44)
        }
    }
}

// MARK: - Lesson list

struct LessonListView: View {
    let pack: CoursePack
    let progress: PackProgress
    let store: LearningStore
    let onProgressRefresh: () -> Void

    @State private var selectedLesson: SelectedLesson?
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    private var unitsInOrder: [CourseUnit] {
        let order = pack.lessons.map(\.unitId)
        var seen: [String] = []
        for id in order where !seen.contains(id) { seen.append(id) }
        return seen.compactMap { id in pack.units.first(where: { $0.id == id }) }
    }

    private func lessons(in unit: CourseUnit) -> [Lesson] {
        pack.lessons.filter { $0.unitId == unit.id }
    }

    /// A unit's checkpoint stage is its first lesson's stage (every unit
    /// today is uniform within one path, the same rule CoursesView's path
    /// cards use).
    private func stageOf(_ unit: CourseUnit) -> CheckpointStage {
        guard let first = lessons(in: unit).first else { return .foundation }
        return checkpointStage(of: first)
    }

    /// The stage-end task card belongs only at the very end of a stage:
    /// after its last unit, and only when the pack actually ships a task
    /// for that stage (an honest absent state otherwise).
    private func checkpointAfterLastUnitOfStage(_ unit: CourseUnit,
                                                index: Int) -> CheckpointTask? {
        let stage = stageOf(unit)
        let laterSameStage = unitsInOrder.dropFirst(index + 1).contains { stageOf($0) == stage }
        guard !laterSameStage else { return nil }
        return pack.checkpoints.first { $0.stage == stage }
    }

    /// "You'll be able to …" line for a unit, grounded in authored copy:
    /// the unit objective when present, otherwise the first lesson
    /// objective in the unit. Only the leading letter is adjusted to fit
    /// the phrasing — no content is fabricated.
    private func unitAbilityLine(_ unit: CourseUnit) -> String? {
        let objective = unit.objective.trimmingCharacters(in: .whitespacesAndNewlines)
        let sentence: String
        if !objective.isEmpty {
            sentence = objective
        } else if let first = lessons(in: unit)
            .map({ $0.objective.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty }) {
            sentence = first
        } else {
            return nil
        }
        guard let head = sentence.first else { return nil }
        return "You'll be able to " + String(head).lowercased() + sentence.dropFirst()
    }

    var body: some View {
        ZStack {
            DesignTokens.canvas.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    if isSearching {
                        searchResults
                    } else {
                        vocabularyRow
                        ForEach(Array(unitsInOrder.enumerated()), id: \.element.id) { index, unit in
                            unitSection(unit)
                            if let checkpoint = checkpointAfterLastUnitOfStage(unit, index: index) {
                                CheckpointEntryCard(
                                    pack: pack,
                                    store: store,
                                    checkpoint: checkpoint,
                                    attempts: progress.checkpointAttempts.filter {
                                        $0.checkpointId == checkpoint.id
                                    },
                                    onProgressRefresh: onProgressRefresh)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle(pack.language.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search lessons")
        .fullScreenCover(item: $selectedLesson) { selected in
            LessonPlayerView(
                pack: pack,
                lessonId: selected.id,
                store: store,
                onExit: {
                    selectedLesson = nil
                    onProgressRefresh()
                }
            )
        }
    }

    private func unitSection(_ unit: CourseUnit) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(unit.title)
                    .font(DesignTokens.display(17))
                    .foregroundStyle(DesignTokens.inkDeep)
                    .accessibilityAddTraits(.isHeader)
                if let ability = unitAbilityLine(unit) {
                    Text(ability)
                        .font(DesignTokens.text(13))
                        .foregroundStyle(DesignTokens.muted)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 4)
            ForEach(lessons(in: unit), id: \.id) { lesson in
                lessonButton(lesson)
            }
        }
    }

    private func lessonButton(_ lesson: Lesson) -> some View {
        Button {
            selectedLesson = SelectedLesson(id: lesson.id)
        } label: {
            lessonRow(lesson)
        }
        .buttonStyle(.plain)
        .contextMenu {
            let known = progress.knownLessons.contains(lesson.id)
            if known {
                Button("Remove known mark") {
                    setKnown(lesson, known: false)
                }
            } else if !progress.finishedLessons.contains(lesson.id) {
                Button("I know this") {
                    setKnown(lesson, known: true)
                }
            }
        }
    }

    /// Entry point to the course vocabulary browser, shown at the top
    /// of the lesson list (hidden while searching lessons).
    private var vocabularyRow: some View {
        NavigationLink(value: CourseRoute.vocabulary(packId: pack.id)) {
            PaperCard {
                HStack(spacing: 12) {
                    Image(systemName: "book.closed")
                        .foregroundStyle(DesignTokens.primary)
                        .font(.system(size: 18))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Vocabulary")
                            .font(DesignTokens.text(16, weight: .semibold))
                            .foregroundStyle(DesignTokens.inkDeep)
                        Text("\(pack.vocabulary.count) words with examples")
                            .font(DesignTokens.text(13))
                            .foregroundStyle(DesignTokens.muted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(DesignTokens.muted)
                        .font(.system(size: 16, weight: .semibold))
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var filteredLessons: [Lesson] {
        let query = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !query.isEmpty else { return [] }
        return pack.lessons.filter {
            $0.title.lowercased().contains(query)
                || $0.objective.lowercased().contains(query)
        }
    }

    private var searchResults: some View {
        VStack(alignment: .leading, spacing: 10) {
            if filteredLessons.isEmpty {
                EmptyStateView(
                    art: .search,
                    title: "No lessons match",
                    message: "Try a different word, or browse the units instead.")
            } else {
                ForEach(filteredLessons, id: \.id) { lesson in
                    lessonButton(lesson)
                }
            }
        }
    }

    private func lessonRow(_ lesson: Lesson) -> some View {
        let finished = progress.finishedLessons.contains(lesson.id)
        let knownOnly = progress.knownLessons.contains(lesson.id)
            && !progress.participationCompleted.contains(lesson.id)
            && !progress.legacyCredits.contains(lesson.id)
        let recommended = pack.firstUncompletedLesson(
            completed: progress.finishedLessons)?.lesson.id == lesson.id
        let skills = CourseSkillMapper.skills(for: lesson, in: pack)
        return PaperCard {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(lesson.title)
                        .font(DesignTokens.text(16, weight: .semibold))
                        .foregroundStyle(DesignTokens.inkDeep)
                    Text(lesson.objective)
                        .font(DesignTokens.text(13))
                        .foregroundStyle(DesignTokens.muted)
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        Text("\(lesson.estimatedMinutes) min")
                            .font(DesignTokens.text(12))
                            .foregroundStyle(DesignTokens.muted)
                        if knownOnly {
                            Text("· Known")
                                .font(DesignTokens.text(12, weight: .medium))
                                .foregroundStyle(DesignTokens.primary)
                        }
                        if lesson.family != .discovery {
                            FamilyBadge(family: lesson.family)
                        }
                        if recommended {
                            Text("Up next")
                                .font(DesignTokens.text(11, weight: .semibold))
                                .foregroundStyle(DesignTokens.primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(DesignTokens.primarySoft)
                                .cornerRadius(6)
                        }
                        if PlacementStore.recommendedLessonId(packId: pack.id) == lesson.id {
                            Text("Suggested start")
                                .font(DesignTokens.text(11, weight: .semibold))
                                .foregroundStyle(DesignTokens.stock)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(DesignTokens.primary)
                                .cornerRadius(6)
                        }
                    }
                    if !skills.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(skills, id: \.self) { skill in
                                Text(skill.label)
                                    .font(DesignTokens.text(11, weight: .medium))
                                    .foregroundStyle(DesignTokens.primary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(DesignTokens.primarySoft)
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
                Spacer()
                if finished {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DesignTokens.primary)
                        .font(.system(size: 22))
                        .accessibilityHidden(true)
                } else if recommended {
                    Text("Continue")
                        .font(DesignTokens.text(14, weight: .semibold))
                        .foregroundStyle(DesignTokens.stock)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(DesignTokens.primary)
                        .cornerRadius(8)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(DesignTokens.muted)
                        .font(.system(size: 16, weight: .semibold))
                        .accessibilityHidden(true)
                }
            }
        }
    }

    /// Records or removes an "I know this" mark, then refreshes progress.
    private func setKnown(_ lesson: Lesson, known: Bool) {
        Task { @MainActor in
            do {
                try store.setLessonKnown(pack: pack, lessonId: lesson.id, known: known)
                onProgressRefresh()
                NotificationCenter.default.post(name: .condiscoProgressChanged, object: nil)
            } catch {
                // Keep the displayed path unchanged if the mark could not be saved.
            }
        }
    }
}

// MARK: - Practiced-skill derivation
//
// Each lesson's practiced skills are derived from the v2 steps the player
// actually runs (lesson.steps → pack.activities), never from the lesson
// family label. The mapping is deliberately conservative — it claims no
// more than each activity kind demonstrably exercises:
//
//   · self-compare (record yourself, compare with the model)  → speaking
//   · text / cloze (type an answer)                           → writing
//   · selection / matching / ordering / information /
//     dialogue-choice / scene-selection (choose an option)    → reading
//   · any activity whose stimulus is audio                    → listening
//
// Audio detection reads the stimulus kind on the pack ("audio"), which
// also covers the listening-family lesson. Legacy v1 exercises are excluded
// on purpose: they are retained for progress migration only and are not
// part of the v2 sequence the learner plays.

/// The four core skills, in display order.
private enum CourseSkill: String, CaseIterable {
    case reading, listening, speaking, writing

    var label: String { rawValue.capitalized }
}

private enum CourseSkillMapper {
    /// Practiced skills for a lesson, in `CourseSkill` display order.
    static func skills(for lesson: Lesson, in pack: CoursePack) -> [CourseSkill] {
        let activitiesById = Dictionary(
            uniqueKeysWithValues: pack.activities.map { ($0.id, $0) })
        var found = Set<CourseSkill>()
        for step in lesson.steps {
            guard let activity = activitiesById[step.activityId] else { continue }
            switch activity {
            case .selfCompare: found.insert(.speaking)
            case .openTask(let spec):
                // Connected production practises the task's own modality.
                found.insert(spec.mode == .spoken ? .speaking : .writing)
            case .text, .cloze: found.insert(.writing)
            case .selection, .matching, .ordering, .information,
                 .dialogueChoice, .sceneSelection: found.insert(.reading)
            case .legacy: continue
            }
            if let stimulusId = activity.stimulusId,
               pack.stimuli.contains(where: { $0.id == stimulusId && isAudio($0) }) {
                found.insert(.listening)
            }
        }
        return CourseSkill.allCases.filter(found.contains)
    }

    private static func isAudio(_ stimulus: Stimulus) -> Bool {
        if case .audio = stimulus { return true }
        return false
    }
}
