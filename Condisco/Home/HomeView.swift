import SwiftUI

// MARK: - Home tab
//
// Central dashboard: focus-language picker, continue-your-path card,
// reviews due, and the week's activity. The Courses tab stays the
// complete browsing library; Home is the daily starting point.
// The focus language also re-aims Courses and Listen ordering.

@MainActor
final class HomeModel: ObservableObject {
    @Published var packs: [CoursePack] = []
    @Published var progress: [String: PackProgress] = [:]
    @Published var dueCount = 0
    @Published var nextDueAt: Date?
    @Published var weekDays: [Date] = currentWeekDays()
    @Published var weekFlags: [Bool] = Array(repeating: false, count: 7)
    @Published var totalPracticeDays = 0
    @Published var monthDays: [Date] = currentMonthDays()
    @Published var monthFlags: [Bool] = []
    @Published var listenTracks: [ListenTrack] = []
    @Published var loadError: String?
    @Published var isLoading = true
    /// The most recent mid-lesson checkpoint, if it points at a lesson
    /// the learner hasn't finished yet.
    @Published var resume: ResumeInfo?

    private var store: LearningStore?

    func load() async {
        do {
            let store = try LearningStore.inDocuments()
            self.store = store
            let packs = try PackLoader.loadPacks()
            var progress: [String: PackProgress] = [:]
            for pack in packs { progress[pack.id] = try store.project(pack: pack) }
            let (due, next) = try ReviewCatalog.loadDue(packs: packs, store: store)
            self.packs = packs
            self.progress = progress
            self.dueCount = due.count
            self.nextDueAt = next
            let weekDays = currentWeekDays()
            self.weekDays = weekDays
            self.weekFlags = (try? store.practiceDayFlags(for: weekDays))
                ?? Array(repeating: false, count: 7)
            self.totalPracticeDays = (try? store.practiceDays()) ?? 0
            let monthDays = currentMonthDays()
            self.monthDays = monthDays
            self.monthFlags = (try? store.practiceDayFlags(for: monthDays))
                ?? Array(repeating: false, count: monthDays.count)
            self.listenTracks = ListenCatalog.loadTracks()
            self.resume = Self.findResume(
                packs: packs, progress: progress, store: store)
            WidgetSnapshotWriter.refresh(
                packs: packs,
                focusSlug: UserDefaults.standard.string(forKey: "condisco.focusLanguage") ?? "french")
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    func refresh() {
        guard let store else { return }
        for pack in packs {
            if let projected = try? store.project(pack: pack) {
                progress[pack.id] = projected
            }
        }
        if let (due, next) = try? ReviewCatalog.loadDue(packs: packs, store: store) {
            dueCount = due.count
            nextDueAt = next
        }
        let days = currentWeekDays()
        weekDays = days
        weekFlags = (try? store.practiceDayFlags(for: days)) ?? weekFlags
        totalPracticeDays = (try? store.practiceDays()) ?? totalPracticeDays
        let month = currentMonthDays()
        monthDays = month
        monthFlags = (try? store.practiceDayFlags(for: month)) ?? monthFlags
        listenTracks = ListenCatalog.loadTracks()
        resume = Self.findResume(packs: packs, progress: progress, store: store)
        WidgetSnapshotWriter.refresh(
            packs: packs,
            focusSlug: UserDefaults.standard.string(forKey: "condisco.focusLanguage") ?? "french")
    }

    /// Observational recap for the focus language: finished lessons,
    /// all-time practice days, active days this week. Counts only — never
    /// a streak, never a judgment.
    func journey(focusSlug: String) -> (
        done: Int, total: Int, practiceDays: Int, weekActive: Int,
        languageName: String
    ) {
        guard let pack = focusPack(slug: focusSlug) else {
            return (0, 0, totalPracticeDays, 0, "")
        }
        let done = progress[pack.id].map {
            $0.finishedLessons.count
        } ?? 0
        let weekActive = weekFlags.filter { $0 }.count
        return (
            done, pack.lessons.count, totalPracticeDays, weekActive,
            pack.language.displayName)
    }

    /// The gentle plan: one suggestion, chosen as an invitation. Reviews
    /// waiting come first, then the lesson left mid-way, then a listen
    /// track. Never a demand.
    func gentlePlan(focusSlug: String) -> GentlePlan? {
        if dueCount > 0 { return .review(due: dueCount) }
        if let resume { return .resume(resume) }
        if let track = gentleListenTrack(focusSlug: focusSlug) {
            return .listen(track)
        }
        return nil
    }

    /// The focus language's listen track, or any track when the focus
    /// language has none.
    func gentleListenTrack(focusSlug: String) -> ListenTrack? {
        listenTracks.first(where: { $0.courseSlug == focusSlug })
            ?? listenTracks.first
    }

    /// The focus pack's numbers for the shareable progress card.
    /// Observational counts only.
    func shareableProgress(focusSlug: String) -> ShareableProgress? {
        guard let pack = focusPack(slug: focusSlug),
              let store else { return nil }
        let kept = ((try? store.savedPhrases()) ?? [])
            .filter { $0.languageSlug == focusSlug }.count
        let done = progress[pack.id]?.finishedLessons.count ?? 0
        return ShareableProgress(
            languageName: pack.language.displayName,
            phrasesKept: kept,
            practiceDays: totalPracticeDays,
            lessonsFinished: done)
    }

    func makeStore() -> LearningStore? { store }

    func focusPack(slug: String) -> CoursePack? {
        packs.first(where: { $0.language.slug == slug }) ?? packs.first
    }

    /// First incomplete lesson in unit/lesson order — the learner's path.
    /// Delegates to the shared `CoursePack.firstUncompletedLesson(completed:)`
    /// so the Home card and `condisco://continue` always agree on the next
    /// lesson. Runs on the cached projection; call `refresh()` after deep
    /// links change progress.
    func nextLesson(in pack: CoursePack) -> (lesson: Lesson, unit: CourseUnit)? {
        pack.firstUncompletedLesson(
            completed: progress[pack.id]?.participationCompleted ?? [])
    }

    /// The most recently written checkpoint across every pack, resolved
    /// to its lesson and step. Skips checkpoints for finished lessons
    /// (normally cleared on completion) and ones whose step no longer
    /// exists. Checkpoint payloads decode with a plain JSONDecoder —
    /// the store writes them with default coding strategies.
    private static func findResume(
        packs: [CoursePack],
        progress: [String: PackProgress],
        store: LearningStore
    ) -> ResumeInfo? {
        guard let rows = try? store.allCheckpoints() else { return nil }
        let decoder = JSONDecoder()
        for row in rows.sorted(by: { $0.updatedAtMs > $1.updatedAtMs }) {
            guard let data = row.payload.data(using: .utf8),
                  let checkpoint = try? decoder.decode(
                    LessonCheckpoint.self, from: data),
                  let pack = packs.first(where: { $0.id == row.packId }),
                  let lesson = pack.lessons.first(where: { $0.id == row.lessonId }),
                  let stepIndex = lesson.steps.firstIndex(where: {
                    $0.id == checkpoint.stepId
                  }),
                  !(progress[pack.id]?.finishedLessons.contains(lesson.id)
                    ?? false)
            else { continue }
            return ResumeInfo(pack: pack, lesson: lesson, stepIndex: stepIndex)
        }
        return nil
    }
}

// MARK: - Calendar week
//
// The activity strip always shows the current calendar week,
// Monday through Sunday, instead of a rolling 7-day window.

/// The seven dates of the current calendar week (Monday first, oldest first).
func currentWeekDays(calendar: Calendar = .current) -> [Date] {
    var calendar = calendar
    calendar.firstWeekday = 2 // Monday
    if let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start {
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }
    let today = calendar.startOfDay(for: Date())
    return (0..<7).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
}

/// Every date of the current calendar month, oldest first.
func currentMonthDays(calendar: Calendar = .current) -> [Date] {
    let calendar = calendar
    guard let interval = calendar.dateInterval(of: .month, for: Date()) else {
        return [calendar.startOfDay(for: Date())]
    }
    var days: [Date] = []
    var day = interval.start
    while day < interval.end {
        days.append(day)
        guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
        day = next
    }
    return days
}

private struct HomePlayerRequest: Identifiable {
    let id: String
    let pack: CoursePack
    let lesson: Lesson
    let store: LearningStore
}

/// A mid-lesson checkpoint resolved to its lesson and step position.
struct ResumeInfo {
    let pack: CoursePack
    let lesson: Lesson
    let stepIndex: Int
    var stepCount: Int { lesson.steps.count }
}

/// One quiet suggestion for the gentle-plan card: reviews waiting take
/// priority, then the lesson left mid-way, then a listen track.
enum GentlePlan {
    case review(due: Int)
    case resume(ResumeInfo)
    case listen(ListenTrack)
}

private struct HomeListenRequest: Identifiable {
    let id: String
    let track: ListenTrack
}

struct HomeView: View {
    @StateObject private var model = HomeModel()
    @AppStorage("condisco.focusLanguage") private var focusSlug = "french"
    @State private var playerRequest: HomePlayerRequest?
    @State private var listenRequest: HomeListenRequest?

    let onOpenReview: () -> Void

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
                    dashboard
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .task { await model.load() }
        .onReceive(
            NotificationCenter.default.publisher(for: .condiscoLessonCompleted)
        ) { _ in
            // A deep-linked lesson closed over the tabs; re-project progress
            // (and with it the widget snapshot).
            model.refresh()
        }
        .fullScreenCover(item: $playerRequest) { request in
            LessonPlayerView(
                pack: request.pack,
                lessonId: request.lesson.id,
                store: request.store,
                onExit: {
                    playerRequest = nil
                    model.refresh()
                }
            )
        }
        .fullScreenCover(item: $listenRequest) { request in
            NavigationStack {
                ListenPlayerView(
                    track: request.track,
                    courseTitle: ListenCourse.displayName(
                        for: request.track.courseSlug))
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") {
                                listenRequest = nil
                                model.refresh()
                            }
                        }
                    }
            }
        }
    }

    private var dashboard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                editorialHeader
                if model.resume != nil {
                    resumeSection
                } else if let pack = model.focusPack(slug: focusSlug) {
                    pathSection(pack: pack)
                }
                reviewSection
                weekSection
                journeySection
                DisclosureGroup("Monthly activity") {
                    monthSection
                        .padding(.top, 14)
                }
                .font(DesignTokens.text(15, weight: .medium))
                .foregroundStyle(DesignTokens.inkDeep)
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 36)
        }
        .refreshable { model.refresh() }
    }

    // MARK: Editorial header

    /// A single greeting and a compact course switcher lead the page.
    private var editorialHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(DesignTokens.text(13, weight: .medium))
                .foregroundStyle(DesignTokens.muted)
            HStack(alignment: .center, spacing: 8) {
                Text("\(greeting).")
                    .font(DesignTokens.display(34))
                    .foregroundStyle(DesignTokens.inkDeep)
                Spacer(minLength: 0)
                Image("CondiscoBeeCompanion")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 68, height: 68)
                    .accessibilityHidden(true)
            }
            if !model.packs.isEmpty {
                Menu {
                    ForEach(model.packs, id: \.id) { pack in
                        Button(pack.language.displayName) {
                            focusSlug = pack.language.slug
                        }
                    }
                } label: {
                    HStack(spacing: 7) {
                        Text(model.focusPack(slug: focusSlug)?.language.displayName ?? "Choose a language")
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .font(DesignTokens.text(15, weight: .medium))
                    .foregroundStyle(DesignTokens.primaryStrong)
                    .padding(.vertical, 8)
                }
                .accessibilityLabel("Focus language")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 0..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    // MARK: Resume

    /// A checkpoint-aware card: the exact lesson and step the learner
    /// left off on, across any language. Opening it resumes mid-lesson.
    @ViewBuilder
    private var resumeSection: some View {
        if let resume = model.resume, let store = model.makeStore() {
            VStack(alignment: .leading, spacing: 10) {
                Text("Continue learning")
                    .font(DesignTokens.text(18, weight: .semibold))
                    .foregroundStyle(DesignTokens.inkDeep)
                    .padding(.horizontal, 4)
                Button {
                    playerRequest = HomePlayerRequest(
                        id: resume.lesson.id, pack: resume.pack,
                        lesson: resume.lesson, store: store)
                } label: {
                    QuietSurface {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(resume.pack.language.displayName)
                                .font(DesignTokens.text(13, weight: .medium))
                                .foregroundStyle(DesignTokens.muted)
                            Text(resume.lesson.title)
                                .font(DesignTokens.display(20))
                                .foregroundStyle(DesignTokens.inkDeep)
                            Text("Step \(resume.stepIndex + 1) of \(resume.stepCount)")
                                .font(DesignTokens.text(14))
                                .foregroundStyle(DesignTokens.muted)
                            HStack {
                                Spacer()
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundStyle(DesignTokens.primary)
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Path

    private func pathSection(pack: CoursePack) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Continue learning")
                .font(DesignTokens.text(18, weight: .semibold))
                .foregroundStyle(DesignTokens.inkDeep)
                .padding(.horizontal, 4)
            if let (lesson, unit) = model.nextLesson(in: pack),
               let store = model.makeStore() {
                Button {
                    playerRequest = HomePlayerRequest(
                        id: lesson.id, pack: pack, lesson: lesson, store: store)
                } label: {
                    QuietSurface {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(pack.language.displayName)
                                .font(DesignTokens.text(13, weight: .medium))
                                .foregroundStyle(DesignTokens.muted)
                            Text(lesson.title)
                                .font(DesignTokens.display(20))
                                .foregroundStyle(DesignTokens.inkDeep)
                            Text(unit.title)
                                .font(DesignTokens.text(14))
                                .foregroundStyle(DesignTokens.muted)
                            HStack(spacing: 8) {
                                Text("\(lesson.estimatedMinutes) min")
                                    .font(DesignTokens.text(12))
                                    .foregroundStyle(DesignTokens.muted)
                                Spacer()
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundStyle(DesignTokens.primary)
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                .buttonStyle(.plain)
            } else {
                QuietSurface {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Path complete")
                            .font(DesignTokens.display(20))
                            .foregroundStyle(DesignTokens.inkDeep)
                        Text("You've finished every \(pack.language.displayName) lesson. Reviews keep it fresh.")
                            .font(DesignTokens.text(14))
                            .foregroundStyle(DesignTokens.muted)
                    }
                }
            }
        }
    }

    // MARK: Reviews

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Review")
                .font(DesignTokens.text(18, weight: .semibold))
                .foregroundStyle(DesignTokens.inkDeep)
                .padding(.horizontal, 4)
            Button(action: onOpenReview) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        if model.dueCount > 0 {
                            Text("\(model.dueCount) review\(model.dueCount == 1 ? "" : "s") due")
                                .font(DesignTokens.text(16, weight: .semibold))
                                .foregroundStyle(DesignTokens.inkDeep)
                            Text("Short recall rounds, oldest first.")
                                .font(DesignTokens.text(13))
                                .foregroundStyle(DesignTokens.muted)
                        } else {
                            Text("All caught up")
                                .font(DesignTokens.text(16, weight: .semibold))
                                .foregroundStyle(DesignTokens.inkDeep)
                            if let next = model.nextDueAt {
                                Text("Next review \(next.formatted(date: .abbreviated, time: .omitted)).")
                                    .font(DesignTokens.text(13))
                                    .foregroundStyle(DesignTokens.muted)
                            } else {
                                Text("Reviews appear after your first lesson.")
                                    .font(DesignTokens.text(13))
                                    .foregroundStyle(DesignTokens.muted)
                            }
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(DesignTokens.muted)
                        .font(.system(size: 16, weight: .semibold))
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Week

    private var weekSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This week")
                .font(DesignTokens.text(18, weight: .semibold))
                .foregroundStyle(DesignTokens.inkDeep)
                .padding(.horizontal, 4)
            HStack(spacing: 0) {
                ForEach(Array(model.weekDays.enumerated()), id: \.offset) { index, day in
                    let active = index < model.weekFlags.count && model.weekFlags[index]
                    VStack(spacing: 8) {
                        Text(day.formatted(.dateTime.weekday(.narrow)))
                            .font(DesignTokens.text(11, weight: .medium))
                            .foregroundStyle(DesignTokens.muted)
                        Circle()
                            .fill(active ? DesignTokens.primary : DesignTokens.stock3)
                            .frame(width: 26, height: 26)
                            .overlay {
                                if active {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(DesignTokens.stock)
                                }
                            }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 10)
        }
    }

    // MARK: Month

    private var monthSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This month")
                .font(DesignTokens.text(18, weight: .semibold))
                .foregroundStyle(DesignTokens.inkDeep)
                .padding(.horizontal, 4)
            QuietSurface {
                MonthView(days: model.monthDays, flags: model.monthFlags)
            }
        }
    }

    // MARK: Journey

    @ViewBuilder
    private var journeySection: some View {
        let journey = model.journey(focusSlug: focusSlug)
        if journey.total > 0 {
            let fraction = Double(journey.done) / Double(journey.total)
            VStack(alignment: .leading, spacing: 10) {
                Text("Your progress")
                    .font(DesignTokens.text(18, weight: .semibold))
                    .foregroundStyle(DesignTokens.inkDeep)
                    .padding(.horizontal, 4)
                QuietSurface {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(journey.done) of \(journey.total) \(journey.languageName) lessons finished")
                            .font(DesignTokens.text(16, weight: .semibold))
                            .foregroundStyle(DesignTokens.inkDeep)
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(DesignTokens.stock3)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(DesignTokens.primary)
                                    .frame(width: geometry.size.width * min(1, max(0, fraction)))
                            }
                            .frame(height: 6)
                        }
                        .frame(height: 6)
                        HStack(spacing: 28) {
                            journeyStat(
                                value: "\(journey.practiceDays)",
                                label: journey.practiceDays == 1 ? "practice day" : "practice days")
                            journeyStat(
                                value: "\(journey.weekActive)",
                                label: "active this week")
                        }
                        if let shareable = model.shareableProgress(
                            focusSlug: focusSlug) {
                            HStack {
                                Spacer()
                                ProgressShareButton(progress: shareable)
                            }
                            .padding(.top, 2)
                        }
                    }
                }
            }
        }
    }

    private func journeyStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(DesignTokens.display(22))
                .foregroundStyle(DesignTokens.inkDeep)
            Text(label)
                .font(DesignTokens.text(12))
                .foregroundStyle(DesignTokens.muted)
        }
    }

    private func loadErrorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text("Couldn't load your dashboard")
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
