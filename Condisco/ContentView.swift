import CoreSpotlight
import SwiftUI
import UIKit

/// Tabs of the main `TabView`. Typed instead of raw `Int` indices so
/// deep links and onboarding can select by name, not by position.
enum AppTab: Hashable {
    case home, courses, listen, review, you
}

enum ReviewSection: String, CaseIterable {
    case review = "Review"
    case saved = "Saved"
}

struct ReviewSectionPicker: View {
    @Binding var selection: ReviewSection

    var body: some View {
        Picker("Review section", selection: $selection) {
            ForEach(ReviewSection.allCases, id: \.self) { section in
                Text(section.rawValue).tag(section)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(DesignTokens.canvas)
    }
}

/// A lesson the onboarding flow asked to open right away (the learner
/// placed into it via the placement check).
private struct PendingLesson: Identifiable {
    let id = UUID()
    let pack: CoursePack
    let lessonId: String
    let store: LearningStore
}

struct ContentView: View {
    @StateObject private var auth = AuthState()
    @StateObject private var sync = CloudKitSync()
    @StateObject private var deepLink = DeepLinkRouter()
    @ObservedObject private var a11y = A11ySettings.shared
    @State private var selection: AppTab = .home
    @State private var reviewSection: ReviewSection = .review
    @AppStorage("condisco.hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var pendingLesson: PendingLesson?

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                tabs
            } else {
                WelcomeFlow(onComplete: finishOnboarding)
            }
        }
        .tint(DesignTokens.primary)
        .environmentObject(auth)
        .environmentObject(sync)
        .transaction { transaction in
            if a11y.effectiveReduceMotion {
                transaction.disablesAnimations = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(
            for: UIContentSizeCategory.didChangeNotification)
        ) { _ in
            // Re-resolve scaled fonts under the new size category.
            a11y.objectWillChange.send()
        }
        // Siri Shortcuts, Spotlight, and external `condisco://` links resolve
        // through the same router and present the standard lesson player.
        .onOpenURL { url in
            deepLink.handle(url: url)
        }
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            deepLink.handle(activity: activity)
        }
        // A `condisco://review` link (e.g. from the widget) selects the
        // Review tab.
        .onChange(of: deepLink.reviewToken) { _, token in
            if token != nil {
                reviewSection = .review
                selection = .review
                deepLink.reviewToken = nil
            }
        }
        // A `condisco://phrasebook` link (e.g. from a Spotlight phrase tap)
        // selects Saved inside the Review tab.
        .onChange(of: deepLink.phrasebookToken) { _, token in
            if token != nil {
                reviewSection = .saved
                selection = .review
                deepLink.phrasebookToken = nil
            }
        }
        .fullScreenCover(item: $deepLink.playerRequest) { request in
            LessonPlayerView(
                pack: request.pack,
                lessonId: request.lessonId,
                store: request.store,
                onExit: {
                    Task { deepLink.closePlayer() }
                }
            )
        }
        .fullScreenCover(item: $pendingLesson) { pending in
            LessonPlayerView(
                pack: pending.pack,
                lessonId: pending.lessonId,
                store: pending.store,
                onExit: { pendingLesson = nil }
            )
        }
        .task {
            SpotlightIndex.indexIfNeeded()
            SpotlightIndex.indexPhrasesIfNeeded()
        }
    }

    private var tabs: some View {
        TabView(selection: $selection) {
            HomeView(onOpenReview: {
                reviewSection = .review
                selection = .review
            })
                .tabItem { Label("Home", systemImage: "house") }
                .tag(AppTab.home)
            CoursesView()
                .tabItem { Label("Courses", systemImage: "book.closed") }
                .tag(AppTab.courses)
            ListenView()
                .tabItem { Label("Listen", systemImage: "headphones") }
                .tag(AppTab.listen)
            Group {
                switch reviewSection {
                case .review:
                    ReviewView(section: $reviewSection)
                case .saved:
                    SavedView(section: $reviewSection)
                }
            }
                .tabItem { Label("Review", systemImage: "arrow.triangle.2.circlepath") }
                .tag(AppTab.review)
            YouView()
                .tabItem { Label("You", systemImage: "person") }
                .tag(AppTab.you)
        }
        // SavedView's phrase rows open their source lesson through the
        // same router Siri/Spotlight links use.
        .environmentObject(deepLink)
    }

    /// Onboarding finished. When the learner placed into a lesson, open
    /// it straight away once a store is available.
    private func finishOnboarding(pack: CoursePack?, lessonId: String?) {
        hasCompletedOnboarding = true
        guard let pack, let lessonId else { return }
        Task { @MainActor in
            if let store = try? LearningStore.inDocuments() {
                pendingLesson = PendingLesson(
                    pack: pack, lessonId: lessonId, store: store)
            }
        }
    }
}
