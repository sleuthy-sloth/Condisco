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
    case lessons(packId: String, selectedPath: CoursePath? = nil)
    case vocabulary(packId: String)
    case level(CoursePath)
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
//     anything else → Independent (Spanish B1/B2 today).
//   · a path's task outcomes are the unit objectives of the units that
//     map to it (authored copy, not claims invented by the UI).
//   · a path's prerequisite line reflects the real prerequisite edges
//     between lessons: each Developing path opens with a lesson whose
//     prerequisites include a Foundation lesson.
//
// The labels describe content alignment, not ability: no level shown here
// is a test result or a score.
//
// `CoursePath` + `coursePath(of:)` are the single mapping used by the
// level cards, the level pages, scoped lesson lists, search, and the
// tests — the displayed counts always equal the lessons those surfaces
// reach.

/// The three content paths, in progression order. Foundation carries the
/// A1/untagged lessons of every course, Developing the A2 lessons, and
/// Independent the B1/B2 lessons (Spanish today).
enum CoursePath: String, CaseIterable, Identifiable, Hashable {
    case foundation, developing, independent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .foundation: return "Foundation"
        case .developing: return "Developing"
        case .independent: return "Independent"
        }
    }

    /// VoiceOver label for the level card: names the level and its reach.
    var browseLabel: String { "Browse \(title) lessons" }

    /// Stable identifier for UI automation ("courses.level.foundation", …).
    var cardIdentifier: String { "courses.level.\(rawValue)" }

    /// Lessons in a pack at this path, in pack order.
    func lessons(in pack: CoursePack) -> [Lesson] {
        pack.lessons.filter { coursePath(of: $0) == self }
    }

    /// Completed lessons at this path, from the learner's finished set.
    func completedCount(in pack: CoursePack, finished: Set<String>) -> Int {
        lessons(in: pack).filter { finished.contains($0.id) }.count
    }
}

/// A lesson's path from its authored level tag: A2 → Developing,
/// A1 or absent → Foundation, anything else → Independent.
func coursePath(of lesson: Lesson) -> CoursePath {
    switch lesson.cefr {
    case "A2": return .developing
    case "A1", nil: return .foundation
    default: return .independent
    }
}

/// A unit's path is the path of its first lesson; every unit today is
/// uniform within one path.
func coursePath(of unit: CourseUnit, in pack: CoursePack) -> CoursePath {
    guard let first = pack.lessons.first(where: { $0.unitId == unit.id }) else {
        return .foundation
    }
    return coursePath(of: first)
}

/// Lessons whose title or objective contains the trimmed, case-insensitive
/// query, in the given order. The lesson list's search — scoped or whole
/// course — uses exactly this predicate, so a level-scoped search can
/// never surface another level's lessons.
func lessonSearchResults(_ lessons: [Lesson], query: String) -> [Lesson] {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !trimmed.isEmpty else { return [] }
    return lessons.filter {
        $0.title.lowercased().contains(trimmed)
            || $0.objective.lowercased().contains(trimmed)
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
                case .lessons(let packId, let selectedPath):
                    if let pack = model.packs.first(where: { $0.id == packId }),
                       let store = model.makeStore() {
                        LessonListView(
                            pack: pack,
                            progress: model.progress[pack.id] ?? PackProgress(),
                            store: store,
                            selectedPath: selectedPath,
                            onProgressRefresh: { model.refreshProgress() }
                        )
                    }
                case .vocabulary(let packId):
                    if let pack = model.packs.first(where: { $0.id == packId }) {
                        VocabularyBrowserView(pack: pack)
                    }
                case .level(let path):
                    LevelBrowseView(
                        path: path,
                        packs: model.packs,
                        progress: model.progress,
                        onProgressRefresh: { model.refreshProgress() }
                    )
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
        let finishedSet = model.progress[pack.id]?.finishedLessons ?? []
        let done = finishedSet.count
        let total = pack.lessons.count
        let remainingMinutes = pack.lessons
            .filter { !finishedSet.contains($0.id) }
            .reduce(0) { $0 + $1.estimatedMinutes }
        return CourseCardRow(
            languageName: pack.language.displayName,
            courseTitle: pack.title,
            description: pack.description,
            done: done,
            total: total,
            remainingMinutes: remainingMinutes)
    }

    // MARK: - Content paths (Foundation → Developing → Independent)

    /// The three path cards, in progression order, above the course list.
    /// Each populated card is a real control leading to that level's
    /// courses and lessons; an empty level renders as plain text instead.
    private var pathSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Browse by level")
                    .font(DesignTokens.text(18, weight: .semibold))
                    .foregroundStyle(DesignTokens.inkDeep)
                    .padding(.horizontal, 4)
                    .accessibilityAddTraits(.isHeader)
                Text("Choose a level to explore its lessons. Levels describe the content, not your ability.")
                    .font(DesignTokens.text(13))
                    .foregroundStyle(DesignTokens.muted)
                    .padding(.horizontal, 4)
            }
            ForEach(CoursePath.allCases, id: \.self) { path in
                pathCard(path)
            }
        }
    }

    @ViewBuilder
    private func pathCard(_ path: CoursePath) -> some View {
        let stats = pathStats(path)
        if stats.lessons > 0 {
            NavigationLink(value: CourseRoute.level(path)) {
                pathCardContent(path, stats: stats, isLink: true)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(path.cardIdentifier)
            .accessibilityLabel(
                "\(path.browseLabel). \(stats.lessons) lessons across \(stats.courses) courses.")
            .accessibilityHint("Opens the courses with lessons at this level")
        } else {
            // Empty level: informational text, deliberately not a link —
            // nothing tappable should ever promise lessons that do not exist.
            pathCardContent(path, stats: stats, isLink: false)
        }
    }

    private func pathCardContent(
        _ path: CoursePath, stats: (lessons: Int, courses: Int), isLink: Bool
    ) -> some View {
        PaperCard {
            HStack(spacing: 12) {
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
                Spacer()
                if isLink {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(DesignTokens.muted)
                        .font(.system(size: 16, weight: .semibold))
                        .accessibilityHidden(true)
                }
            }
        }
    }

    /// Lesson counts per path, plus how many courses carry that path.
    private func pathStats(_ path: CoursePath) -> (lessons: Int, courses: Int) {
        var lessons = 0
        var courses = 0
        for pack in model.packs {
            let count = path.lessons(in: pack).count
            if count > 0 { courses += 1 }
            lessons += count
        }
        return (lessons, courses)
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
            return "More advanced lessons, after Developing."
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

// MARK: - Shared course cards

/// The course-card row shared by the language list and the level pages:
/// language eyebrow, course title, description, remaining time, and the
/// completion bar over the card's lesson scope (the whole pack, or one
/// level's matching lessons).
private struct CourseCardRow: View {
    let languageName: String
    let courseTitle: String
    let description: String
    let done: Int
    let total: Int
    let remainingMinutes: Int

    var body: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(languageName)
                    .font(DesignTokens.text(13, weight: .semibold))
                    .foregroundStyle(DesignTokens.primary)
                    .textCase(.uppercase)
                Text(courseTitle)
                    .font(DesignTokens.display(20))
                    .foregroundStyle(DesignTokens.inkDeep)
                Text(description)
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
}

/// The compact completion bar shared by course cards: filled fraction =
/// done/total over the card's lesson scope.
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

// MARK: - Level page

/// One level's courses: every course with at least one lesson at the
/// level, in pack order, showing lessons completed within that level.
/// Tapping a course opens its lesson list scoped to the level.
private struct LevelBrowseView: View {
    let path: CoursePath
    let packs: [CoursePack]
    let progress: [String: PackProgress]
    let onProgressRefresh: () -> Void

    private var matchingPacks: [CoursePack] {
        packs.filter { !path.lessons(in: $0).isEmpty }
    }

    var body: some View {
        ZStack {
            DesignTokens.canvas.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    if matchingPacks.isEmpty {
                        // Defensive: a populated level card only links here,
                        // but keep the screen honest if pack data ever
                        // leaves a level empty across every course.
                        Text("No lessons at this level yet.")
                            .font(DesignTokens.text(13))
                            .foregroundStyle(DesignTokens.muted)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 48)
                    } else {
                        ForEach(matchingPacks, id: \.id) { pack in
                            NavigationLink(
                                value: CourseRoute.lessons(
                                    packId: pack.id, selectedPath: path)
                            ) {
                                levelCourseRow(pack)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle(path.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func levelCourseRow(_ pack: CoursePack) -> some View {
        let matching = path.lessons(in: pack)
        let finishedSet = progress[pack.id]?.finishedLessons ?? []
        let done = matching.filter { finishedSet.contains($0.id) }.count
        let remainingMinutes = matching
            .filter { !finishedSet.contains($0.id) }
            .reduce(0) { $0 + $1.estimatedMinutes }
        return CourseCardRow(
            languageName: pack.language.displayName,
            courseTitle: pack.title,
            description: pack.description,
            done: done,
            total: matching.count,
            remainingMinutes: remainingMinutes)
    }
}

// MARK: - Lesson list

struct LessonListView: View {
    let pack: CoursePack
    let progress: PackProgress
    let store: LearningStore
    /// When set, the list shows only this level's units and lessons (a
    /// level-page entry point). nil keeps the ordinary whole-course list.
    var selectedPath: CoursePath?
    let onProgressRefresh: () -> Void

    @State private var selectedLesson: SelectedLesson?
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    /// Every lesson this list can show: the whole pack by default, or
    /// only the lessons at the chosen level. One mapping (coursePath(of:))
    /// drives the level cards, level pages, this list, and search, so the
    /// counts always equal the reachable lessons.
    private var visibleLessons: [Lesson] {
        guard let selectedPath else { return pack.lessons }
        return pack.lessons.filter { coursePath(of: $0) == selectedPath }
    }

    private var unitsInOrder: [CourseUnit] {
        let order = visibleLessons.map(\.unitId)
        var seen: [String] = []
        for id in order where !seen.contains(id) { seen.append(id) }
        return seen.compactMap { id in pack.units.first(where: { $0.id == id }) }
    }

    private func lessons(in unit: CourseUnit) -> [Lesson] {
        visibleLessons.filter { $0.unitId == unit.id }
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
                        if selectedPath == nil {
                            vocabularyRow
                        }
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
        .navigationTitle(scopedTitle)
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

    /// "Spanish" for the ordinary course; "Spanish · Independent" when a
    /// level scopes the list. The vocabulary browser is not level-scoped,
    /// so the scoped title names the level outright.
    private var scopedTitle: String {
        guard let selectedPath else { return pack.language.displayName }
        return "\(pack.language.displayName) · \(selectedPath.title)"
    }

    /// Entry point to the course vocabulary browser, shown at the top
    /// of the lesson list (hidden while searching lessons, and hidden
    /// from a level-scoped list because vocabulary is not level-scoped).
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
        lessonSearchResults(visibleLessons, query: searchText)
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
