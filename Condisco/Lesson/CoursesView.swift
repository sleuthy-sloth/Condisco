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
            NotificationCenter.default.publisher(for: .condiscoLessonCompleted)
        ) { _ in
            // A deep-linked lesson closed over the tabs; re-project progress.
            model.refreshProgress()
        }
    }

    private var courseList: some View {
        ScrollView {
            VStack(spacing: 14) {
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
                HStack {
                    Text("\(done) of \(total) lessons complete")
                        .font(DesignTokens.text(13))
                        .foregroundStyle(DesignTokens.muted)
                    Spacer()
                    lessonProgressBar(done: done, total: total)
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

    var body: some View {
        ZStack {
            DesignTokens.canvas.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    if isSearching {
                        searchResults
                    } else {
                        vocabularyRow
                        ForEach(unitsInOrder, id: \.id) { unit in
                            unitSection(unit)
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
                Text(unit.objective)
                    .font(DesignTokens.text(13))
                    .foregroundStyle(DesignTokens.muted)
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
                }
                Spacer()
                if finished {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DesignTokens.primary)
                        .font(.system(size: 22))
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(DesignTokens.muted)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
        }
    }

    /// Records or removes an "I know this" mark, then refreshes progress.
    private func setKnown(_ lesson: Lesson, known: Bool) {
        Task { @MainActor in
            try? store.setLessonKnown(pack: pack, lessonId: lesson.id, known: known)
            onProgressRefresh()
        }
    }
}

