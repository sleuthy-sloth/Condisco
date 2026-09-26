import SwiftUI

// MARK: - Review tab
//
// Spaced repetition over lesson evidence: due items across all five
// courses, oldest first. Each card asks for recall, reveals the answer,
// and takes an honest self-rating — heard, not judged. No timers, no
// streaks, no scores.

@MainActor
final class ReviewModel: ObservableObject {
    @Published var isLoading = true
    @Published var loadError: String?
    @Published var due: [ReviewItem] = []
    @Published var nextDueAt: Date?
    /// Evidence keys whose latest rating was "not yet" — the tricky list.
    @Published var tricky: [ReviewItem] = []
    /// Evidence coming due tomorrow, for the quiet forecast line.
    @Published var dueTomorrowCount = 0

    private var store: LearningStore?
    private var packsById: [String: CoursePack] = [:]

    func load() async {
        do {
            let store = try LearningStore.inDocuments()
            self.store = store
            let packs = try PackLoader.loadPacks()
            self.packsById = Dictionary(
                uniqueKeysWithValues: packs.map { ($0.id, $0) })
            let (due, nextDueAt) = try ReviewCatalog.loadDue(packs: packs, store: store)
            self.due = due
            self.nextDueAt = nextDueAt
            self.tricky = try ReviewCatalog.loadTricky(packs: packs, store: store)
            self.dueTomorrowCount = try ReviewCatalog.countDueWithin(
                packs: packs, store: store, days: 1)
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    func refresh() async {
        isLoading = true
        loadError = nil
        await load()
    }

    /// Records a review verdict through the lesson event pipeline so the
    /// SRS reschedules this evidence key exactly like a lesson attempt.
    func recordVerdict(_ verdict: ReviewVerdict, for item: ReviewItem) throws {
        guard let store else { return }
        try store.record(.attempt(item.makeAttempt(verdict: verdict)))
        // A verdict reschedules this evidence key, so the widget's
        // reviews-due count is stale from here on.
        if let packs = try? PackLoader.loadPacks() {
            WidgetSnapshotWriter.refresh(
                packs: packs,
                focusSlug: UserDefaults.standard.string(forKey: "condisco.focusLanguage") ?? "french")
        }
    }

    /// BCP-47 language code for an item's course, for TTS.
    func languageCode(for item: ReviewItem) -> String {
        guard let pack = packsById[item.packId] else { return "en-US" }
        return ShadowVoice.languageCode(for: pack.language.slug)
    }

    var perCourseCounts: [(title: String, count: Int)] {
        var order: [String] = []
        var counts: [String: Int] = [:]
        for item in due {
            if counts[item.courseTitle] == nil {
                order.append(item.courseTitle)
            }
            counts[item.courseTitle, default: 0] += 1
        }
        return order.map { ($0, counts[$0] ?? 0) }
    }
}

struct ReviewView: View {
    @Binding var section: ReviewSection
    @Binding var sessionLength: ReviewSessionLength
    @StateObject private var model = ReviewModel()
    @State private var session: ReviewSessionRoute?

    /// The session queue: the due list capped to the chosen session size,
    /// oldest first either way.
    private var sessionItems: [ReviewItem] {
        guard let limit = sessionLength.limit else { return model.due }
        return Array(model.due.prefix(limit))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.canvas.ignoresSafeArea()
                if model.isLoading {
                    ProgressView()
                        .tint(DesignTokens.primary)
                } else if let error = model.loadError {
                    Text(error)
                        .font(DesignTokens.text(14))
                        .foregroundStyle(DesignTokens.attentionInk)
                        .padding(24)
                } else if model.due.isEmpty {
                    // Scrollable so the resting message never clips at the
                    // largest Dynamic Type on the smallest phone.
                    ScrollView {
                        restedState
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 480)
                    }
                } else {
                    dueList
                }
            }
            .navigationTitle("Review")
            .safeAreaInset(edge: .top, spacing: 0) {
                ReviewSectionPicker(selection: $section)
            }
        }
        .task { await model.load() }
        .fullScreenCover(item: $session) { route in
            ReviewSessionView(items: route.items, mode: route.mode, model: model) {
                session = nil
                // The queue may have emptied: cancel or reschedule the
                // daily nudge right away instead of leaving a stale one.
                ReviewReminders.refreshShared()
                Task { await model.refresh() }
            }
        }
    }

    private var dueList: some View {
        ScrollView {
            VStack(spacing: 16) {
                PaperCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(sessionLength == .all
                             ? "\(model.due.count) to review"
                             : "\(sessionItems.count) of \(model.due.count) to review")
                            .font(DesignTokens.display(24))
                            .foregroundStyle(DesignTokens.inkDeep)
                        Text("Oldest first. Recall each one, reveal the answer, and rate yourself honestly — that's the whole technique.")
                            .font(DesignTokens.text(14))
                            .foregroundStyle(DesignTokens.muted)
                        ForEach(model.perCourseCounts, id: \.title) { row in
                            HStack {
                                Text(row.title)
                                    .font(DesignTokens.text(14))
                                    .foregroundStyle(DesignTokens.ink)
                                Spacer()
                                Text("\(row.count)")
                                    .font(DesignTokens.text(14, weight: .semibold))
                                    .foregroundStyle(DesignTokens.muted)
                                    .monospacedDigit()
                            }
                        }
                        if model.dueTomorrowCount > 0 {
                            Text("\(model.dueTomorrowCount) more due tomorrow.")
                                .font(DesignTokens.text(13))
                                .foregroundStyle(DesignTokens.muted)
                        }
                        if model.due.count > 5 {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("SESSION SIZE")
                                    .font(DesignTokens.text(11, weight: .semibold))
                                    .tracking(1)
                                    .foregroundStyle(DesignTokens.muted)
                                Picker("Session size", selection: $sessionLength) {
                                    ForEach(ReviewSessionLength.allCases, id: \.self) { length in
                                        Text(length.label).tag(length)
                                    }
                                }
                                .pickerStyle(.segmented)
                                Text("Short sittings, same memory. Oldest first.")
                                    .font(DesignTokens.text(13))
                                    .foregroundStyle(DesignTokens.muted)
                            }
                            .padding(.top, 2)
                        }
                        Button {
                            session = ReviewSessionRoute(items: sessionItems, mode: .quiz)
                        } label: {
                            Text("Start review")
                                .font(DesignTokens.text(16, weight: .semibold))
                                .foregroundStyle(DesignTokens.stock)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(DesignTokens.primary)
                                .cornerRadius(10)
                        }
                        .padding(.top, 4)
                        Button {
                            session = ReviewSessionRoute(items: sessionItems, mode: .flashcards)
                        } label: {
                            Label("Study as flashcards", systemImage: "rectangle.on.rectangle")
                                .font(DesignTokens.text(15, weight: .semibold))
                                .foregroundStyle(DesignTokens.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(DesignTokens.primary, lineWidth: 1)
                                )
                                .frame(minHeight: 44)
                        }
                        Button {
                            session = ReviewSessionRoute(items: sessionItems, mode: .handsfree)
                        } label: {
                            Label("Hands-free", systemImage: "headphones")
                                .font(DesignTokens.text(15, weight: .semibold))
                                .foregroundStyle(DesignTokens.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(DesignTokens.primary, lineWidth: 1)
                                )
                                .frame(minHeight: 44)
                        }
                    }
                }
                if !model.tricky.isEmpty {
                    PaperCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Tricky list")
                                    .font(DesignTokens.text(16, weight: .semibold))
                                    .foregroundStyle(DesignTokens.inkDeep)
                                    .accessibilityAddTraits(.isHeader)
                                Spacer()
                                Text("\(model.tricky.count)")
                                    .font(DesignTokens.text(16, weight: .semibold))
                                    .foregroundStyle(DesignTokens.primary)
                                    .monospacedDigit()
                            }
                            Text("The ones you marked “not yet” — a gentle second pass.")
                                .font(DesignTokens.text(14))
                                .foregroundStyle(DesignTokens.muted)
                            Button {
                                session = ReviewSessionRoute(items: model.tricky, mode: .quiz)
                            } label: {
                                Label("Revisit the tricky ones", systemImage: "arrow.counterclockwise")
                                    .font(DesignTokens.text(15, weight: .semibold))
                                    .foregroundStyle(DesignTokens.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(DesignTokens.primary, lineWidth: 1)
                                    )
                                    .frame(minHeight: 44)
                            }
                            .padding(.top, 2)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }

    private var restedState: some View {
        if let next = model.nextDueAt {
            EmptyStateView(
                art: .rested,
                title: "All caught up",
                message: "The next review is \(relativeDue(next)). Learning rests between sessions — that's when it sticks.")
        } else {
            EmptyStateView(
                art: .rested,
                title: "All caught up",
                message: "Nothing scheduled yet. Finish a lesson and its words will return here right on time.")
        }
    }

    private func relativeDue(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// How the due queue is studied: the classic quiz, flashcards, or
// hands-free listening.
enum ReviewSessionMode {
    case quiz
    case flashcards
    case handsfree
}

// MARK: - Session length
//
// A calm session-size picker: five, ten, or everything due. The queue
// stays oldest-first and the verdict pipeline is unchanged — a shorter
// sitting on busy days, same memory either way.

enum ReviewSessionLength: Int, CaseIterable {
    case five = 5
    case ten = 10
    case all = 0

    var label: String {
        switch self {
        case .five: return "5"
        case .ten: return "10"
        case .all: return "All"
        }
    }

    /// Max items to take from the front of the due queue.
    var limit: Int? {
        switch self {
        case .five: return 5
        case .ten: return 10
        case .all: return nil
        }
    }
}

// MARK: - Review entry points
//
// How a learner reaches the Review tab decides the session size:
// Home's Today invitation promises "Up to 5 reviews", an external deep
// link (widget, Siri) asks for everything due, and the tab itself keeps
// whatever the learner last chose.

enum ReviewEntryPoint {
    case homeInvitation
    case tab
    case deepLink
}

/// Resolves the session size a review entry point should apply.
/// Home's invitation always preselects `.five` — the short sitting its
/// copy promises; the tab keeps the learner's current choice (the
/// shared binding is the single source of truth, so picker changes
/// persist across tab switches); a deep link requests everything due.
func resolveReviewSessionLength(
    for entry: ReviewEntryPoint, current: ReviewSessionLength
) -> ReviewSessionLength {
    switch entry {
    case .homeInvitation: return .five
    case .tab: return current
    case .deepLink: return .all
    }
}

// Identifiable wrapper so the session can drive fullScreenCover(item:).
struct ReviewSessionRoute: Identifiable {
    let id = UUID()
    let items: [ReviewItem]
    let mode: ReviewSessionMode
}

// MARK: - Review session

struct ReviewSessionView: View {
    let items: [ReviewItem]
    let mode: ReviewSessionMode
    let model: ReviewModel
    let onDone: () -> Void

    @State private var index = 0
    @State private var counts: [ReviewVerdict: Int] = [
        .exact: 0, .close: 0, .tryAgain: 0, .easy: 0,
    ]
    @State private var saveError: String?
    @State private var finished = false
    /// Verdicts in answer order; the last one can be taken back.
    @State private var history: [ReviewVerdict] = []

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.canvas.ignoresSafeArea()
                if finished {
                    summary
                } else if mode == .flashcards {
                    FlashcardStudyView(
                        item: items[index],
                        position: index + 1,
                        total: items.count,
                        saveError: saveError,
                        onVerdict: submit
                    )
                    .id(items[index].id)
                } else if mode == .handsfree {
                    HandsFreeCardView(
                        item: items[index],
                        position: index + 1,
                        total: items.count,
                        languageCode: model.languageCode(for: items[index]),
                        saveError: saveError,
                        onVerdict: submit
                    )
                    .id(items[index].id)
                } else {
                    ReviewCardView(
                        item: items[index],
                        position: index + 1,
                        total: items.count,
                        saveError: saveError
                    ) { verdict in
                        submit(verdict)
                    }
                    .id(items[index].id)
                }
            }
            .navigationTitle(finished ? "Reviewed" : "Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { onDone() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Undo") { undoLast() }
                        .disabled(history.isEmpty)
                }
            }
        }
    }

    private func submit(_ verdict: ReviewVerdict) {
        do {
            try model.recordVerdict(verdict, for: items[index])
            saveError = nil
            counts[verdict, default: 0] += 1
            history.append(verdict)
            if index + 1 < items.count {
                index += 1
            } else {
                finished = true
            }
        } catch {
            saveError = "Couldn't save that review — tap your rating again to retry."
        }
    }

    /// Takes back the last rating: the card returns as the current one
    /// and the verdict leaves this session's counts. The earlier attempt
    /// stays in the event log (append-only by design); re-rating records
    /// a fresh attempt, which the SRS treats as the card's latest review.
    private func undoLast() {
        guard let last = history.popLast() else { return }
        counts[last, default: 1] -= 1
        finished = false
        index = history.count
    }

    private var summary: some View {
        // Scrollable so the verdict counts and Done action never clip at the
        // largest Dynamic Type on the smallest phone.
        ScrollView {
            VStack(spacing: 14) {
                Text("Session complete")
                    .font(DesignTokens.display(22))
                    .foregroundStyle(DesignTokens.inkDeep)
                    .padding(.top, 24)
                PaperCard {
                    VStack(spacing: 8) {
                        summaryRow("Knew it", counts[.exact] ?? 0)
                        summaryRow("Almost", counts[.close] ?? 0)
                        summaryRow("Not yet", counts[.tryAgain] ?? 0)
                        summaryRow("Easy", counts[.easy] ?? 0)
                    }
                }
                .padding(.horizontal, 20)
                Text("The shaky ones come back tomorrow. The solid ones rest longer.")
                    .font(DesignTokens.text(14))
                    .foregroundStyle(DesignTokens.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                if !history.isEmpty {
                    Button("Undo last rating") { undoLast() }
                        .font(DesignTokens.text(15, weight: .semibold))
                        .foregroundStyle(DesignTokens.primary)
                        .frame(minHeight: 44)
                }
                Button("Done") { onDone() }
                    .font(DesignTokens.text(16, weight: .semibold))
                    .foregroundStyle(DesignTokens.stock)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(DesignTokens.primary)
                    .cornerRadius(10)
                    .frame(minHeight: 44)
                    .padding(.bottom, 24)
            }
        }
    }

    private func summaryRow(_ label: String, _ count: Int) -> some View {
        HStack {
            Text(label)
                .font(DesignTokens.text(15))
                .foregroundStyle(DesignTokens.ink)
            Spacer()
            Text("\(count)")
                .font(DesignTokens.text(15, weight: .semibold))
                .foregroundStyle(DesignTokens.muted)
                .monospacedDigit()
        }
    }
}

// MARK: - Session position dots

/// Quiet position dots for a review session: where this card sits in
/// the queue. Long queues collapse to a 15-dot window around the
/// current card so the row never overflows.
struct SessionDots: View {
    /// 1-based position of the current card.
    let position: Int
    let total: Int

    private let maxDots = 15

    private var window: Range<Int> {
        guard total > maxDots else { return 0..<total }
        let half = maxDots / 2
        let start = min(max(position - 1 - half, 0), total - maxDots)
        return start..<(start + maxDots)
    }

    var body: some View {
        if total > 1 {
            HStack(spacing: 7) {
                ForEach(Array(window), id: \.self) { i in
                    Circle()
                        .fill(dotColor(i))
                        .frame(
                            width: i == position - 1 ? 9 : 6,
                            height: i == position - 1 ? 9 : 6)
                }
            }
            .frame(height: 12)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Card \(position) of \(total)")
        }
    }

    private func dotColor(_ i: Int) -> Color {
        if i == position - 1 { return DesignTokens.primary }
        if i < position - 1 { return DesignTokens.primary.opacity(0.4) }
        return DesignTokens.stock3
    }
}

// MARK: - Review card

struct ReviewCardView: View {
    let item: ReviewItem
    let position: Int
    let total: Int
    let saveError: String?
    let onVerdict: (ReviewVerdict) -> Void

    @State private var revealed = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("\(item.courseTitle) · \(item.lessonTitle)")
                    .font(DesignTokens.text(13, weight: .semibold))
                    .foregroundStyle(DesignTokens.primary)
                    .textCase(.uppercase)
                    .multilineTextAlignment(.center)
                SessionDots(position: position, total: total)
                PaperCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Recall")
                            .font(DesignTokens.text(13, weight: .semibold))
                            .foregroundStyle(DesignTokens.muted)
                            .textCase(.uppercase)
                        Text(item.prompt)
                            .font(DesignTokens.text(17))
                            .foregroundStyle(DesignTokens.inkDeep)
                            .lineSpacing(4)
                        if !revealed {
                            Text("Say it out loud or think it through, then reveal the answer.")
                                .font(DesignTokens.text(14))
                                .foregroundStyle(DesignTokens.muted)
                            Button("Reveal answer") { revealed = true }
                                .font(DesignTokens.text(15, weight: .semibold))
                                .foregroundStyle(DesignTokens.primary)
                                .padding(.top, 2)
                                .frame(minHeight: 44)
                        }
                    }
                }
                if revealed {
                    PaperCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Answer")
                                .font(DesignTokens.text(13, weight: .semibold))
                                .foregroundStyle(DesignTokens.muted)
                                .textCase(.uppercase)
                            Text(item.answerText)
                                .font(DesignTokens.text(17, weight: .semibold))
                                .foregroundStyle(DesignTokens.primaryStrong)
                                .lineSpacing(4)
                            if item.feedback != item.answerText {
                                Text(item.feedback)
                                    .font(DesignTokens.text(14))
                                    .foregroundStyle(DesignTokens.ink)
                                    .lineSpacing(3)
                            }
                            Divider()
                                .padding(.vertical, 4)
                            Text("How did that go?")
                                .font(DesignTokens.text(14, weight: .semibold))
                                .foregroundStyle(DesignTokens.ink)
                            VerdictButtonRow(
                                saveError: saveError, onVerdict: onVerdict)
                            if let saveError {
                                Text(saveError)
                                    .font(DesignTokens.text(13))
                                    .foregroundStyle(DesignTokens.attentionInk)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }
}
