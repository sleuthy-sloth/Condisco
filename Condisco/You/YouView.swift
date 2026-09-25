import AuthenticationServices
import SwiftUI

// MARK: - You tab
//
// The learner's profile: what they can say, where they are, comfort
// settings, and the account section. Practice never requires an account;
// signing in with Apple marks this device's progress as theirs so sync can
// carry it to their other devices.

/// Identifiable wrapper so a placement retake can drive fullScreenCover(item:).
private struct RetakeTarget: Identifiable {
    let id: String
    let pack: CoursePack
}

struct YouView: View {
    @StateObject private var model = YouModel()
    @EnvironmentObject private var auth: AuthState
    @EnvironmentObject private var sync: CloudKitSync
    @State private var signInErrorMessage: String?
    @State private var exportURL: URL?
    @StateObject private var support = SupportStore()
    @State private var showingSupport = false
    @StateObject private var reminders = ReviewReminders()
    @State private var packs: [CoursePack] = []
    @State private var retakeTarget: RetakeTarget?
    @State private var placementEpoch = 0
    @AppStorage("condisco.focusLanguage") private var focusSlug = "french"

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

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
                    profile
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            await model.load()
            await support.load()
            packs = (try? PackLoader.loadPacks()) ?? []
            await reminders.refresh()
            await runSync()
        }
    }

    // MARK: - Sections

    private var profile: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header
                statsSection
                sayableSection
                coursesSection
                profileGroup("Preferences", icon: "slider.horizontal.3") {
                    comfortSection
                    VoiceSettingsSection()
                    remindersSection
                }
                profileGroup("Account and data", icon: "person.crop.circle") {
                    accountSection
                    placementSection
                    dataSection
                    supportSection
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 36)
        }
    }

    private func profileGroup<Content: View>(
        _ title: String, icon: String, @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        DisclosureGroup {
            VStack(spacing: 14, content: content)
                .padding(.top, 16)
        } label: {
            Label(title, systemImage: icon)
                .font(DesignTokens.text(17, weight: .semibold))
                .foregroundStyle(DesignTokens.inkDeep)
        }
        .tint(DesignTokens.primary)
        .padding(.horizontal, 4)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your learning")
                .font(DesignTokens.display(34))
                .foregroundStyle(DesignTokens.inkDeep)
            Text(auth.isSignedIn
                 ? "Your progress is saved to your account."
                 : "Your progress is saved on this device.")
                .font(DesignTokens.text(14))
                .foregroundStyle(DesignTokens.muted)
        }
    }

    private var sayableSection: some View {
        QuietSurface {
            VStack(alignment: .leading, spacing: 10) {
                Text("What you can say")
                    .font(DesignTokens.text(18, weight: .semibold))
                    .foregroundStyle(DesignTokens.inkDeep)
                if model.phrases.isEmpty {
                    Text("Nothing yet. Finish a lesson and the pattern you learn shows up here.")
                        .font(DesignTokens.text(15))
                        .foregroundStyle(DesignTokens.muted)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(model.phrases.prefix(3))) { phrase in
                            phraseRow(phrase)
                        }
                        if model.phrases.count > 3 {
                            DisclosureGroup("Show all \(model.phrases.count) phrases") {
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(Array(model.phrases.dropFirst(3))) { phrase in
                                        phraseRow(phrase)
                                    }
                                }
                                .padding(.top, 12)
                            }
                            .font(DesignTokens.text(14, weight: .medium))
                            .tint(DesignTokens.primary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func phraseRow(_ phrase: YouModel.SayablePhrase) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(phrase.text)
                .font(DesignTokens.text(16, weight: .medium))
                .foregroundStyle(DesignTokens.inkDeep)
            Text(phrase.context)
                .font(DesignTokens.text(13))
                .foregroundStyle(DesignTokens.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statsSection: some View {
        QuietSurface {
            VStack(alignment: .leading, spacing: 10) {
                Text("At a glance")
                    .font(DesignTokens.text(18, weight: .semibold))
                    .foregroundStyle(DesignTokens.inkDeep)
                HStack(alignment: .firstTextBaseline, spacing: 28) {
                    statRow(label: "Days practised", value: "\(model.daysPractised)")
                    statRow(label: "Reviews due", value: "\(model.dueCount)")
                }
                .padding(.vertical, 4)
                if let shareable = shareableProgress {
                    ProgressShareButton(progress: shareable)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func statRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(DesignTokens.display(30))
                .foregroundStyle(DesignTokens.inkDeep)
            Text(label)
                .font(DesignTokens.text(13))
                .foregroundStyle(DesignTokens.muted)
        }
    }

    /// The focus language's numbers for the shareable progress card.
    /// Observational counts only.
    private var shareableProgress: ShareableProgress? {
        guard let pack = packs.first(where: { $0.language.slug == focusSlug }) ?? packs.first,
              let store = try? LearningStore.inDocuments()
        else { return nil }
        let kept = ((try? store.savedPhrases()) ?? [])
            .filter { $0.languageSlug == focusSlug }.count
        let done = (try? store.project(pack: pack))?.finishedLessons.count ?? 0
        return ShareableProgress(
            languageName: pack.language.displayName,
            phrasesKept: kept,
            practiceDays: model.daysPractised,
            lessonsFinished: done)
    }

    private var coursesSection: some View {
        QuietSurface {
            VStack(alignment: .leading, spacing: 10) {
                Text("Courses")
                    .font(DesignTokens.text(18, weight: .semibold))
                    .foregroundStyle(DesignTokens.inkDeep)
                if let featured = featuredCourse {
                    courseRow(featured)
                }
                if model.courses.count > 1 {
                    DisclosureGroup("Other courses") {
                        VStack(spacing: 12) {
                            ForEach(model.courses.filter { $0.id != featuredCourse?.id }) { course in
                                courseRow(course)
                            }
                        }
                        .padding(.top, 12)
                    }
                    .font(DesignTokens.text(14, weight: .medium))
                    .tint(DesignTokens.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var featuredCourse: YouModel.CourseStat? {
        let name = packs.first(where: { $0.language.slug == focusSlug })?.language.displayName
        return model.courses.first(where: { $0.languageName == name })
            ?? model.courses.first
    }

    private func courseRow(_ course: YouModel.CourseStat) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(course.languageName)
                    .font(DesignTokens.text(16, weight: .medium))
                    .foregroundStyle(DesignTokens.inkDeep)
                Text("\(course.done) of \(course.total) lessons")
                    .font(DesignTokens.text(13))
                    .foregroundStyle(DesignTokens.muted)
            }
            Spacer()
            Text("\(course.percent)%")
                .font(DesignTokens.text(15, weight: .medium))
                .foregroundStyle(DesignTokens.primaryStrong)
        }
    }

    private var comfortSection: some View {
        QuietSurface {
            VStack(alignment: .leading, spacing: 10) {
                Text("Comfort")
                    .font(DesignTokens.display(20))
                    .foregroundStyle(DesignTokens.inkDeep)
                Text("Saved only on this device. Larger text scales the app's type; Reduce motion turns off animations.")
                    .font(DesignTokens.text(13))
                    .foregroundStyle(DesignTokens.muted)
                Toggle("Larger text", isOn: $model.largeText)
                    .font(DesignTokens.text(15))
                    .foregroundStyle(DesignTokens.inkDeep)
                    .tint(DesignTokens.primary)
                Toggle("Reduce motion", isOn: $model.reduceMotion)
                    .font(DesignTokens.text(15))
                    .foregroundStyle(DesignTokens.inkDeep)
                    .tint(DesignTokens.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Reminders

    private var remindersSection: some View {
        QuietSurface {
            VStack(alignment: .leading, spacing: 10) {
                Text("Reminders")
                    .font(DesignTokens.display(20))
                    .foregroundStyle(DesignTokens.inkDeep)
                Text("One gentle nudge a day, only when reviews are waiting. Never a streak, never a scolding.")
                    .font(DesignTokens.text(13))
                    .foregroundStyle(DesignTokens.muted)
                Toggle("Review reminders", isOn: $reminders.isEnabled)
                    .font(DesignTokens.text(15))
                    .foregroundStyle(DesignTokens.inkDeep)
                    .tint(DesignTokens.primary)
                if reminders.isEnabled {
                    DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
                        .font(DesignTokens.text(15))
                        .foregroundStyle(DesignTokens.inkDeep)
                        .tint(DesignTokens.primary)
                    if reminders.permissionDenied {
                        Text("Notifications are turned off for Condisco — enable them in Settings to receive reminders.")
                            .font(DesignTokens.text(13))
                            .foregroundStyle(DesignTokens.attentionInk)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = reminders.minutes / 60
                components.minute = reminders.minutes % 60
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                reminders.minutes = (parts.hour ?? 8) * 60 + (parts.minute ?? 0)
            }
        )
    }

    // MARK: - Placement

    private var placementSection: some View {
        QuietSurface {
            VStack(alignment: .leading, spacing: 10) {
                Text("Placement")
                    .font(DesignTokens.display(20))
                    .foregroundStyle(DesignTokens.inkDeep)
                Text("Retake the level check for any course. Your suggestion updates; nothing is ever marked complete.")
                    .font(DesignTokens.text(13))
                    .foregroundStyle(DesignTokens.muted)
                ForEach(packs, id: \.id) { pack in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pack.language.displayName)
                                .font(DesignTokens.text(12, weight: .semibold))
                                .foregroundStyle(DesignTokens.primary)
                                .textCase(.uppercase)
                            if let title = suggestedLessonTitle(for: pack) {
                                Text("Suggested: \(title)")
                                    .font(DesignTokens.text(14))
                                    .foregroundStyle(DesignTokens.muted)
                            } else {
                                Text("No suggestion yet")
                                    .font(DesignTokens.text(14))
                                    .foregroundStyle(DesignTokens.muted)
                            }
                        }
                        Spacer()
                        Button("Retake") {
                            retakeTarget = RetakeTarget(id: pack.id, pack: pack)
                        }
                        .font(DesignTokens.text(15, weight: .semibold))
                        .foregroundStyle(DesignTokens.primary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fullScreenCover(item: $retakeTarget, onDismiss: { placementEpoch += 1 }) { target in
            PlacementTestView(
                pack: target.pack,
                onDone: { _ in retakeTarget = nil },
                onSkip: { retakeTarget = nil }
            )
        }
    }

    /// Reads the live recommendation; placementEpoch nudges the view to
    /// re-read after a retake.
    private func suggestedLessonTitle(for pack: CoursePack) -> String? {
        _ = placementEpoch
        guard let lessonId = PlacementStore.recommendedLessonId(packId: pack.id) else {
            return nil
        }
        return pack.lessons.first(where: { $0.id == lessonId })?.title
    }

    // MARK: - Data

    private var dataSection: some View {
        QuietSurface {
            VStack(alignment: .leading, spacing: 10) {
                Text("Your data")
                    .font(DesignTokens.display(20))
                    .foregroundStyle(DesignTokens.inkDeep)
                Text("Your learning events, lesson checkpoints, and listen history as JSON. Your data, to keep.")
                    .font(DesignTokens.text(13))
                    .foregroundStyle(DesignTokens.muted)
                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("Share export", systemImage: "square.and.arrow.up")
                            .font(DesignTokens.text(15, weight: .semibold))
                            .foregroundStyle(DesignTokens.primary)
                    }
                } else {
                    Button {
                        exportURL = model.exportData()
                    } label: {
                        Label("Export my data", systemImage: "square.and.arrow.down")
                            .font(DesignTokens.text(15, weight: .semibold))
                            .foregroundStyle(DesignTokens.primary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Support

    private var supportSection: some View {
        QuietSurface {
            VStack(alignment: .leading, spacing: 10) {
                Text("Support")
                    .font(DesignTokens.display(20))
                    .foregroundStyle(DesignTokens.inkDeep)
                if support.isSupporter {
                    Label(
                        "You're a supporter — thank you.",
                        systemImage: "heart.fill")
                        .font(DesignTokens.text(15, weight: .medium))
                        .foregroundStyle(DesignTokens.primary)
                } else {
                    Text("Condisco is free with everything unlocked. If it has helped you, a one-time thank-you keeps it that way.")
                        .font(DesignTokens.text(14))
                        .foregroundStyle(DesignTokens.muted)
                }
                Button {
                    showingSupport = true
                } label: {
                    Label(
                        support.isSupporter ? "View" : "Support Condisco",
                        systemImage: "chevron.right")
                        .font(DesignTokens.text(15, weight: .semibold))
                        .foregroundStyle(DesignTokens.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $showingSupport) {
            SupportView(store: support)
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        QuietSurface {
            VStack(alignment: .leading, spacing: 10) {
                Text("Account")
                    .font(DesignTokens.display(20))
                    .foregroundStyle(DesignTokens.inkDeep)
                if auth.isSignedIn {
                    signedInView
                } else {
                    signedOutView
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var signedOutView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What you practise here stays on this device. Sign in to keep it on your account, so it follows you to another device.")
                .font(DesignTokens.text(14))
                .foregroundStyle(DesignTokens.muted)
            SignInWithAppleButton(
                onCredential: { credential in
                    Task { await handleCredential(credential) }
                },
                onError: { error in
                    if (error as? ASAuthorizationError)?.code == .canceled {
                        signInErrorMessage = nil
                    } else {
                        signInErrorMessage = "Sign in with Apple isn't available in this build — it needs Apple's paid Developer Program. Your progress stays safe on this device."
                    }
                })
                .frame(height: 48)
            if let signInErrorMessage {
                Text(signInErrorMessage)
                    .font(DesignTokens.text(13))
                    .foregroundStyle(DesignTokens.attentionInk)
            }
        }
    }

    private var signedInView: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let name = auth.displayName {
                Text("Signed in as \(name)")
                    .font(DesignTokens.text(15, weight: .medium))
                    .foregroundStyle(DesignTokens.inkDeep)
            }
            Text("Your progress is saved to your account and follows you across devices.")
                .font(DesignTokens.text(14))
                .foregroundStyle(DesignTokens.muted)
            syncStatusRow
            Button("Sync now") {
                Task { await runSync() }
            }
            .font(DesignTokens.text(15, weight: .semibold))
            .foregroundStyle(DesignTokens.primary)
            .disabled(sync.isSyncing)
            Button("Sign out") {
                auth.signOut()
            }
            .font(DesignTokens.text(15, weight: .semibold))
            .foregroundStyle(DesignTokens.attentionInk)
        }
    }

    private var syncStatusRow: some View {
        Group {
            if sync.isSyncing {
                Label("Syncing…", systemImage: "arrow.triangle.2.circlepath")
            } else if let error = sync.lastErrorMessage {
                Label(error, systemImage: "exclamationmark.icloud")
                    .foregroundStyle(DesignTokens.attentionInk)
            } else if let date = sync.lastSyncedAt {
                Label(
                    "Last synced \(Self.relativeFormatter.localizedString(for: date, relativeTo: Date()))",
                    systemImage: "checkmark.icloud")
            } else {
                Label("Not synced yet", systemImage: "icloud")
            }
        }
        .font(DesignTokens.text(13))
        .foregroundStyle(DesignTokens.muted)
    }

    private func loadErrorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Text("Unable to load your profile. Try again.")
                .font(DesignTokens.text(15))
                .foregroundStyle(DesignTokens.muted)
            Button("Try again") {
                Task { await model.refresh() }
            }
            .font(DesignTokens.text(15, weight: .semibold))
            .foregroundStyle(DesignTokens.stock)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(DesignTokens.primary)
            .cornerRadius(10)
        }
        .padding()
    }

    // MARK: - Actions

    @MainActor
    private func handleCredential(
        _ credential: ASAuthorizationAppleIDCredential
    ) async {
        signInErrorMessage = nil
        auth.didSignIn(credential: credential)
        await runSync()
    }

    @MainActor
    private func runSync() async {
        guard auth.isSignedIn else { return }
        do {
            let store = try LearningStore.inDocuments()
            await sync.sync(store: store, signedIn: auth.isSignedIn)
        } catch {
            // The store failing to open is a profile-load problem, not a
            // sync problem; model.load() already surfaces it.
        }
    }
}
