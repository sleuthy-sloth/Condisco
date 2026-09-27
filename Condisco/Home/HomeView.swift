import SwiftUI

// MARK: - Home tab
//
// Central dashboard: focus-language picker, one Today card (a single
// headline action — resume, next lesson, review, or listen — with the
// review and listen rows alongside when they aren't the headline), and
// the week's activity. The Courses tab stays the complete browsing
// library; Home is the daily starting point.
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
            completed: progress[pack.id]?.finishedLessons ?? [])
    }

    /// The focus language's continuation lesson through `continueLessonResolution`
    /// — the same pure path Home's Today card, the widget snapshot, and the
    /// deep-link router all share, fed the same `finishedLessons` set.
    func continuationLesson(focusSlug: String) -> (pack: CoursePack, lesson: Lesson, unit: CourseUnit)? {
        continueLessonResolution(
            packs: packs,
            focusSlug: focusSlug,
            completedByPack: progress.mapValues { $0.finishedLessons })
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

// MARK: - Today plan
//
// One headline action for the day, chosen by pure precedence:
// resume > next lesson > review > listen > rest. The plan also carries
// the due count and the listen track so the card can render them as
// secondary rows whenever they are not the headline.

/// The single headline action on the Today card.
enum TodayPrimary {
    case resume(ResumeInfo)
    case lesson(Lesson, CourseUnit)
    case review(Int)
    case listen(ListenTrack)
    case rest
}

extension TodayPrimary {
    var isReview: Bool {
        if case .review = self { return true }
        return false
    }

    var isListen: Bool {
        if case .listen = self { return true }
        return false
    }
}

/// One day's plan: a headline action plus the secondary review/listen
/// rows, which render whenever they are not the headline.
struct TodayPlan {
    let primary: TodayPrimary
    let dueCount: Int
    let nextDueAt: Date?
    let listen: ListenTrack?

    /// Pure precedence: resume > next lesson > review > listen > rest.
    /// Review wins only when nothing is outstanding on the path; rest
    /// only when nothing at all is available.
    static func make(
        resume: ResumeInfo?,
        nextLesson: (lesson: Lesson, unit: CourseUnit)?,
        dueCount: Int,
        nextDueAt: Date?,
        listen: ListenTrack?
    ) -> TodayPlan {
        let primary: TodayPrimary
        if let resume {
            primary = .resume(resume)
        } else if let nextLesson {
            primary = .lesson(nextLesson.lesson, nextLesson.unit)
        } else if dueCount > 0 {
            primary = .review(dueCount)
        } else if let listen {
            primary = .listen(listen)
        } else {
            primary = .rest
        }
        return TodayPlan(
            primary: primary,
            dueCount: dueCount,
            nextDueAt: nextDueAt,
            listen: listen)
    }
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
        .onAppear { model.refresh() }
        .onReceive(
            NotificationCenter.default.publisher(for: .condiscoProgressChanged)
        ) { _ in
            // A deep-linked lesson closed or a known mark changed; re-project
            // progress and the widget snapshot.
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
                todaySection
                weekSection
                journeySection
                DisclosureGroup {
                    monthSection
                        .padding(.top, 14)
                } label: {
                    Text("Monthly activity")
                        .accessibilityAddTraits(.isHeader)
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
                            .accessibilityHidden(true)
                    }
                    .font(DesignTokens.text(15, weight: .medium))
                    .foregroundStyle(DesignTokens.primaryStrong)
                    .padding(.vertical, 8)
                    .frame(minHeight: 44)
                }
                .accessibilityLabel("Focus language")
                .accessibilityHint("Opens a menu to choose your focus language")
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

    // MARK: Today

    /// The single daily plan, derived from the model. The pure precedence
    /// lives in `TodayPlan.make` so the tests exercise it directly.
    private var todayPlan: TodayPlan {
        let next = model.continuationLesson(focusSlug: focusSlug)
        return TodayPlan.make(
            resume: model.resume,
            nextLesson: next.map { (lesson: $0.lesson, unit: $0.unit) },
            dueCount: model.dueCount,
            nextDueAt: model.nextDueAt,
            listen: model.gentleListenTrack(focusSlug: focusSlug))
    }

    /// One card: a single headline action plus the review and listen rows
    /// whenever they are not already the headline.
    private var todaySection: some View {
        let plan = todayPlan
        return VStack(alignment: .leading, spacing: 10) {
            Text("Today")
                .font(DesignTokens.text(18, weight: .semibold))
                .foregroundStyle(DesignTokens.inkDeep)
                .padding(.horizontal, 4)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("home.today.header")
            QuietSurface {
                VStack(alignment: .leading, spacing: 0) {
                    todayPrimaryRow(plan)
                    if plan.dueCount > 0 && !plan.primary.isReview {
                        todayRowDivider
                        reviewRow(dueCount: plan.dueCount, headline: false)
                    }
                    if let listen = plan.listen, !plan.primary.isListen {
                        todayRowDivider
                        listenRow(track: listen, headline: false)
                    }
                }
            }
        }
    }

    private var todayRowDivider: some View {
        Divider()
            .overlay(DesignTokens.edgeSoft)
            .padding(.vertical, 12)
    }

    @ViewBuilder
    private func todayPrimaryRow(_ plan: TodayPlan) -> some View {
        switch plan.primary {
        case .resume(let resume):
            resumeRow(resume)
        case .lesson(let lesson, let unit):
            lessonRow(lesson, unit: unit)
        case .review(let due):
            reviewRow(dueCount: due, headline: true)
        case .listen(let track):
            listenRow(track: track, headline: true)
        case .rest:
            restRow(plan)
        }
    }

    /// The checkpoint headline: the exact lesson and step the learner
    /// left off on, across any language. Opening it resumes mid-lesson.
    @ViewBuilder
    private func resumeRow(_ resume: ResumeInfo) -> some View {
        if let store = model.makeStore() {
            Button {
                playerRequest = HomePlayerRequest(
                    id: resume.lesson.id, pack: resume.pack,
                    lesson: resume.lesson, store: store)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(resume.pack.language.displayName)
                        .font(DesignTokens.text(13, weight: .medium))
                        .foregroundStyle(DesignTokens.muted)
                    Text(resume.lesson.title)
                        .font(DesignTokens.display(20))
                        .foregroundStyle(DesignTokens.inkDeep)
                    HStack {
                        Text("Step \(resume.stepIndex + 1) of \(resume.stepCount)")
                            .font(DesignTokens.text(14))
                            .foregroundStyle(DesignTokens.muted)
                        Spacer()
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(DesignTokens.primary)
                            .accessibilityHidden(true)
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the lesson where you left off")
            .accessibilityIdentifier("home.today.primary")
        }
    }

    /// The next-lesson headline: the focus language's next step on the
    /// path, in unit order.
    @ViewBuilder
    private func lessonRow(_ lesson: Lesson, unit: CourseUnit) -> some View {
        if let pack = model.focusPack(slug: focusSlug),
           let store = model.makeStore() {
            Button {
                playerRequest = HomePlayerRequest(
                    id: lesson.id, pack: pack, lesson: lesson, store: store)
            } label: {
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
                            .accessibilityHidden(true)
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the next lesson in this course")
            .accessibilityIdentifier("home.today.primary")
        }
    }

    /// The review row: a short-sitting invitation that reuses the
    /// five-item session option — "a few minutes", no streak demanded.
    private func reviewRow(dueCount: Int, headline: Bool) -> some View {
        Button(action: onOpenReview) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(dueCount) review\(dueCount == 1 ? "" : "s") due")
                        .font(headline
                            ? DesignTokens.display(20)
                            : DesignTokens.text(16, weight: .semibold))
                        .foregroundStyle(DesignTokens.inkDeep)
                    Text("Up to 5 reviews — a few minutes")
                        .font(DesignTokens.text(13))
                        .foregroundStyle(DesignTokens.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(DesignTokens.muted)
                    .font(.system(size: 16, weight: .semibold))
                    .accessibilityHidden(true)
            }
            .padding(.vertical, headline ? 8 : 6)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the Review tab")
        .accessibilityIdentifier("home.today.review")
    }

    /// The listen row: the focus language's audio track. Reuses the
    /// Listen duration formatting so the card and the Listen tab agree.
    private func listenRow(track: ListenTrack, headline: Bool) -> some View {
        Button {
            listenRequest = HomeListenRequest(id: track.id, track: track)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    if headline {
                        Text(ListenCourse.displayName(for: track.courseSlug))
                            .font(DesignTokens.text(13, weight: .medium))
                            .foregroundStyle(DesignTokens.muted)
                        Text(track.lessonTitle)
                            .font(DesignTokens.display(20))
                            .foregroundStyle(DesignTokens.inkDeep)
                        HStack {
                            Text(formatListenDuration(track.durationS))
                                .font(DesignTokens.text(14))
                                .foregroundStyle(DesignTokens.muted)
                            Spacer()
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(DesignTokens.primary)
                                .accessibilityHidden(true)
                        }
                        .padding(.top, 4)
                    } else {
                        Text(track.lessonTitle)
                            .font(DesignTokens.text(16, weight: .semibold))
                            .foregroundStyle(DesignTokens.inkDeep)
                        Text("\(formatListenDuration(track.durationS)) · \(ListenCourse.displayName(for: track.courseSlug))")
                            .font(DesignTokens.text(13))
                            .foregroundStyle(DesignTokens.muted)
                    }
                }
                if !headline {
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(DesignTokens.muted)
                        .font(.system(size: 16, weight: .semibold))
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, headline ? 4 : 6)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the listening track")
        .accessibilityIdentifier("home.today.listen")
    }

    /// The rest state: nothing on the path, nothing due, nothing to
    /// listen to. Grounded, with the next review date when there is one.
    private func restRow(_ plan: TodayPlan) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("All caught up")
                .font(DesignTokens.display(20))
                .foregroundStyle(DesignTokens.inkDeep)
            if let next = plan.nextDueAt {
                Text("Come back \(next.formatted(date: .abbreviated, time: .omitted)) for the next review.")
                    .font(DesignTokens.text(14))
                    .foregroundStyle(DesignTokens.muted)
            } else {
                Text("Reviews appear after your first lesson.")
                    .font(DesignTokens.text(14))
                    .foregroundStyle(DesignTokens.muted)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: Week

    private var weekSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This week")
                .font(DesignTokens.text(18, weight: .semibold))
                .foregroundStyle(DesignTokens.inkDeep)
                .padding(.horizontal, 4)
                .accessibilityAddTraits(.isHeader)
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
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        active
                            ? "\(day.formatted(.dateTime.weekday(.wide))), practiced"
                            : day.formatted(.dateTime.weekday(.wide)))
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
                .accessibilityAddTraits(.isHeader)
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
                    .accessibilityAddTraits(.isHeader)
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
                        .accessibilityHidden(true)
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
            .frame(minHeight: 44)
        }
    }
}
