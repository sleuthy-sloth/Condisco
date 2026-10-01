import AuthenticationServices
import SwiftUI
import UniformTypeIdentifiers

// MARK: - You tab
//
// The learner's profile: what they've practised, where they are, comfort
// settings, and the account section. Practice never requires an account;
// when the CloudKit/Sign in with Apple entitlements are present, signing in
// marks this device's progress as theirs so sync can carry it to their
// other devices. This build has those entitlements commented out, so the
// account copy tells the truth: progress is saved on this device and sync
// is not available.

/// Identifiable wrapper so a placement retake can drive fullScreenCover(item:).
private struct RetakeTarget: Identifiable {
    let id: String
    let pack: CoursePack
}

private struct PracticeLessonTarget: Identifiable {
    let pack: CoursePack
    let lessonId: String
    let store: LearningStore
    let startFresh: Bool
    var id: String { pack.id + "|" + lessonId }
}

struct YouView: View {
    let onOpenReview: () -> Void
    @State private var practiceTarget: PracticeLessonTarget?
    @StateObject private var model = YouModel()
    @EnvironmentObject private var auth: AuthState
    @EnvironmentObject private var sync: CloudKitSync
    @State private var signInErrorMessage: String?
    @State private var exportURL: URL?
    @State private var showingImporter = false
    @State private var pendingImport: ImportPreview?
    @State private var importAlertMessage: String?
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
        .task(id: focusSlug) {
            packs = (try? PackLoader.loadPacks()) ?? []
            await model.refresh(focusSlug: focusSlug)
            await support.load()
            await reminders.refresh()
            await runSync()
        }
        .fullScreenCover(item: $practiceTarget) { target in
            LessonPlayerView(pack: target.pack, lessonId: target.lessonId, store: target.store, startFresh: target.startFresh) {
                practiceTarget = nil
                Task { await model.refresh(focusSlug: focusSlug) }
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false,
            onCompletion: handleImportResult
        )
        .sheet(item: $pendingImport) { preview in
            ImportPreviewView(preview: preview) {
                Task { await confirmImport(preview) }
            }
        }
        .alert(
            "Import not applied",
            isPresented: Binding(
                get: { importAlertMessage != nil },
                set: { if !$0 { importAlertMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importAlertMessage ?? "")
        }
    }

    // MARK: - Sections

    private var profile: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header
                statsSection
                phraseSection
                skillSection
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
            Text(headerSubtitle)
                .font(DesignTokens.text(14))
                .foregroundStyle(DesignTokens.muted)
        }
    }

    /// The header's one-line truth about where progress lives. With the
    /// CloudKit/Sign in with Apple entitlements present, signing in marks
    /// progress as the learner's so sync can carry it to their other
    /// devices; this build has those entitlements commented out, so
    /// progress is saved on this device and never leaves it.
    private var headerSubtitle: String {
        guard CloudKitSync.isCloudKitConfigured else {
            return "Your progress is saved on this device."
        }
        return auth.isSignedIn
            ? "Your progress is saved to your account."
            : "Your progress is saved on this device."
    }

    private var phraseSection: some View {
        QuietSurface {
            VStack(alignment: .leading, spacing: 10) {
                Text("Phrases you practised")
                    .font(DesignTokens.text(18, weight: .semibold))
                    .foregroundStyle(DesignTokens.inkDeep)
                if model.groups.isEmpty {
                    Text("Nothing yet. Finish a lesson and the phrases you practise show up here.")
                        .font(DesignTokens.text(15))
                        .foregroundStyle(DesignTokens.muted)
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(model.groups) { group in
                            phraseGroupView(group)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Practice by skill (5.2A)

    /// The focus language's per-skill practice rows, next to the phrase
    /// evidence groups. Counts are "times practised", never ability, and
    /// there is deliberately no overall score: a learner further along in
    /// reading than listening sees that divergence row by row. British
    /// spelling throughout ("practised").
    private var skillSection: some View {
        QuietSurface {
            VStack(alignment: .leading, spacing: 10) {
                Text("Practice by skill")
                    .font(DesignTokens.text(18, weight: .semibold))
                    .foregroundStyle(DesignTokens.inkDeep)
                if model.skillPractice.allSatisfy({
                    $0.practisedTimes == 0 && $0.dueCount == 0
                }) {
                    Text("Nothing yet. Finish a lesson and your practice shows up here, one row per skill.")
                        .font(DesignTokens.text(15))
                        .foregroundStyle(DesignTokens.muted)
                } else {
                    VStack(spacing: 12) {
                        ForEach(model.skillPractice) { row in
                            skillRow(row)
                        }
                    }
                }
                if let recommendation = model.practiceRecommendation {
                    Button { openPractice(recommendation) } label: {
                        Label(recommendation.title, systemImage: "arrow.right.circle.fill")
                            .font(DesignTokens.text(14, weight: .medium))
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .foregroundStyle(DesignTokens.primary)
                    .accessibilityIdentifier("you.nextPractice")
                }
                if model.openResponses.withoutModelOrHelp + model.openResponses.withModelOrHelp > 0 {
                    Text("Self-assessed open responses: \(model.openResponses.withoutModelOrHelp) without a model or help; \(model.openResponses.withModelOrHelp) with a model or help.")
                        .font(DesignTokens.text(13))
                        .foregroundStyle(DesignTokens.muted)
                    Text("These counts describe practice, not assessed speaking or writing ability.")
                        .font(DesignTokens.text(13))
                        .foregroundStyle(DesignTokens.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func openPractice(_ recommendation: YouModel.PracticeRecommendation) {
        guard let lessonId = recommendation.lessonId else { onOpenReview(); return }
        guard let pack = packs.first(where: { $0.id == recommendation.packId }),
              pack.lesson(id: lessonId) != nil else { return }
        do {
            practiceTarget = PracticeLessonTarget(pack: pack, lessonId: lessonId,
                                                 store: try LearningStore.inDocuments(),
                                                 startFresh: recommendation.startFresh)
        } catch { importAlertMessage = error.localizedDescription }
    }

    /// One skill row: label, last practised relative date, and the due
    /// review count for that skill. "Not practised yet" stands in for a
    /// missing date — an honest divergence from the other skills.
    private func skillRow(_ row: YouModel.SkillPractice) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(row.label)
                    .font(DesignTokens.text(16, weight: .medium))
                    .foregroundStyle(DesignTokens.inkDeep)
                if let last = row.lastPractisedAt {
                    Text("Last practised \(Self.relativeFormatter.localizedString(for: last, relativeTo: Date()))")
                        .font(DesignTokens.text(13))
                        .foregroundStyle(DesignTokens.muted)
                } else {
                    Text("Not practised yet")
                        .font(DesignTokens.text(13))
                        .foregroundStyle(DesignTokens.muted)
                }
            }
            Spacer()
            Text(row.dueCount > 0
                 ? "\(row.dueCount) due"
                 : "No reviews due")
                .font(DesignTokens.text(13, weight: .medium))
                .foregroundStyle(row.dueCount > 0
                                 ? DesignTokens.primaryStrong
                                 : DesignTokens.muted)
        }
    }

    /// One evidence group: its label plus the phrase rows, three visible
    /// with a disclosure for the rest — never "can say" language, because
    /// the model's groups are driven by what the events actually prove.
    private func phraseGroupView(_ group: YouModel.PhraseGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(group.label)
                .font(DesignTokens.text(13, weight: .semibold))
                .foregroundStyle(DesignTokens.muted)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(group.phrases.prefix(3))) { phrase in
                    phraseRow(phrase)
                }
                if group.phrases.count > 3 {
                    DisclosureGroup("Show all \(group.phrases.count) phrases") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(group.phrases.dropFirst(3))) { phrase in
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

    private func phraseRow(_ phrase: YouModel.EvidencePhrase) -> some View {
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
                Text("A JSON file with your learning data: every lesson and review event (your progress and what's due), checkpoints including any you cleared, saved phrases including any you removed, listen positions, placement suggestions, and the documents in your library with the phrases you saved from them. Identifiers and timestamps are kept exactly as stored.")
                    .font(DesignTokens.text(13))
                    .foregroundStyle(DesignTokens.muted)
                Text("Not included: comfort and voice settings, your focus language, reminders, sign-in state, and device-only sync bookkeeping.")
                    .font(DesignTokens.text(13))
                    .foregroundStyle(DesignTokens.muted)
                Text("Documents stay on this device and are never synced — they leave only when you export your data yourself.")
                    .font(DesignTokens.text(12))
                    .foregroundStyle(DesignTokens.muted)
                Text("Built on this device, offline — it only leaves when you share it.")
                    .font(DesignTokens.text(12))
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
                Button {
                    showingImporter = true
                } label: {
                    Label("Restore from export", systemImage: "square.and.arrow.down.on.square")
                        .font(DesignTokens.text(15, weight: .semibold))
                        .foregroundStyle(DesignTokens.primary)
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
            if CloudKitSync.isCloudKitConfigured {
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
            } else {
                // No iCloud/CloudKit or Sign in with Apple entitlements in
                // this build: there is nothing to sign in to, so offer no
                // button and say plainly that sync is unavailable.
                Text("Your progress is saved on this device. Sync isn't available in this build, so nothing leaves this device.")
                    .font(DesignTokens.text(14))
                    .foregroundStyle(DesignTokens.muted)
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
            if CloudKitSync.isCloudKitConfigured {
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
            } else {
                // CloudKit is unavailable in this build, so even a stale
                // signed-in state cannot sync — say so instead of showing a
                // sync row that could never succeed.
                Text("Your progress is saved on this device. Sync isn't available in this build, so nothing leaves this device.")
                    .font(DesignTokens.text(14))
                    .foregroundStyle(DesignTokens.muted)
            }
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
                Task { await model.refresh(focusSlug: focusSlug) }
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

    // MARK: - Restore from export
    //
    // Decode and validate first, show a preview with counts, and only
    // write after explicit confirmation. Validation lives in
    // `ImportValidator` (pure, side-effect-free); `YouModel.restore`
    // applies the merge transactionally.

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importSelectedFile(url)
        case .failure:
            importAlertMessage = "The file could not be opened. Nothing was changed."
        }
    }

    private func importSelectedFile(_ url: URL) {
        // Files picked from the Files app are security-scoped.
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }
        guard let data = try? Data(contentsOf: url) else {
            importAlertMessage = "The file could not be read. Nothing was changed."
            return
        }
        switch ImportValidator.validate(data) {
        case .success(let preview):
            pendingImport = preview
        case .failure(let error):
            importAlertMessage = error.description
        }
    }

    @MainActor
    private func confirmImport(_ preview: ImportPreview) async {
        do {
            try model.restore(preview)
            await model.refresh(focusSlug: focusSlug)
            // The store's existing progress-changed mechanism: Home and
            // Courses observe it and reload their projections.
            NotificationCenter.default.post(
                name: .condiscoProgressChanged, object: nil)
            // The widget snapshot recomputes from the store directly.
            WidgetSnapshotWriter.refresh(packs: packs, focusSlug: focusSlug)
            // The daily nudge reschedules from the new due queue.
            ReviewReminders.refreshShared()
        } catch {
            importAlertMessage =
                "The export could not be applied. Nothing was changed. \(error.localizedDescription)"
        }
    }
}

// MARK: - Restore preview

/// The preview shown before a restore writes anything: what the file
/// contains, when it was exported, and a plain statement that restoring
/// merges rather than replaces. Wording is intentionally simple — the
/// developer reviews it before shipping.
private struct ImportPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let preview: ImportPreview
    /// The confirmed write; the sheet dismisses first.
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if preview.isLegacy {
                        Text("This file was made by an older version of Condisco.")
                            .font(DesignTokens.text(14, weight: .medium))
                            .foregroundStyle(DesignTokens.ink)
                    } else if let exportedAt = preview.exportedAt {
                        Text("From an export made \(exportedAt.formatted(date: .abbreviated, time: .shortened)).")
                            .font(DesignTokens.text(14, weight: .medium))
                            .foregroundStyle(DesignTokens.ink)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(preview.events.count) learning events")
                        Text("\(preview.checkpoints.count) checkpoints")
                        Text("\(preview.savedPhrases.count) saved phrases")
                        Text("\(preview.documents.count) library documents")
                        Text("\(preview.listenState.count) listen positions")
                        Text("\(preview.placement.count) placement entries")
                    }
                    .font(DesignTokens.text(15))
                    .foregroundStyle(DesignTokens.ink)

                    Text("Restoring merges this export into what is already on this device rather than replacing it. Learning events are added; where the same checkpoint, saved phrase, or listen position appears in both, the newer one wins, and entries you removed stay removed. Library documents in the file are added back, and there is no delete marker for documents, so an older export can restore one you removed. Your learning path may change.")
                        .font(DesignTokens.text(13))
                        .foregroundStyle(DesignTokens.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .navigationTitle("Restore an export?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(DesignTokens.text(15, weight: .medium))
                        .foregroundStyle(DesignTokens.primary)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button {
                    dismiss()
                    onConfirm()
                } label: {
                    Text("Merge into my data")
                        .font(DesignTokens.text(15, weight: .semibold))
                        .foregroundStyle(DesignTokens.stock)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(DesignTokens.primary)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 16)
            }
        }
    }
}
