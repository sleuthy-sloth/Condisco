import CoreSpotlight
import Foundation
import SwiftUI

// MARK: - Deep links
//
// The custom routes Condisco answers to, shared by Siri Shortcuts, Spotlight,
// and external `condisco://` links.
//
// - `condisco://continue`                   → the focus language's next lesson
// - `condisco://lesson/<packId>/<lessonId>` → one specific lesson
// - `condisco://review`                     → the Review tab
// - `condisco://phrasebook`                 → the Saved (phrasebook) tab

/// A parsed Condisco URL.
enum DeepLink: Equatable {
    /// The focus language's next lesson (Home's continue semantics).
    case `continue`
    /// One specific lesson.
    case lesson(packId: String, lessonId: String)
    /// The Review tab.
    case review
    /// The Saved phrasebook tab.
    case phrasebook

    init?(url: URL) {
        guard url.scheme == "condisco" else { return nil }
        switch url.host {
        case "continue":
            self = .continue
        case "review":
            self = .review
        case "phrasebook":
            self = .phrasebook
        case "lesson":
            let parts = url.pathComponents.filter { $0 != "/" }
            guard parts.count == 2 else { return nil }
            self = .lesson(packId: parts[0], lessonId: parts[1])
        default:
            return nil
        }
    }
}

/// What the router hands to the root view to present.
struct DeepLinkPlayerRequest: Identifiable {
    /// "<packId>/<lessonId>"
    let id: String
    let pack: CoursePack
    let lessonId: String
    let store: LearningStore
}

// MARK: - Lesson completion
//
// Posted when a deep-linked lesson player closes, so Home and Courses can
// refresh their progress (their own player exits refresh directly).
extension Notification.Name {
    static let condiscoLessonCompleted = Notification.Name("condisco.lessonCompleted")
    static let condiscoAudioDidFinish = Notification.Name("condisco.audioDidFinish")
}

// MARK: - Router

/// Parses incoming URLs and Spotlight activities and resolves them against the
/// bundled packs, presenting the existing `LessonPlayerView` through the same
/// `fullScreenCover` shape Home and Courses use. Deep links are best-effort:
/// an unknown route or missing lesson simply does nothing — never an error.
@MainActor
final class DeepLinkRouter: ObservableObject {
    @Published var playerRequest: DeepLinkPlayerRequest?
    /// Set when a link asks for the Review tab; the root view consumes
    /// it by selecting the tab, then clears it.
    @Published var reviewToken: UUID?
    /// Set when a link asks for the Saved phrasebook tab; the root
    /// view consumes it the same way.
    @Published var phrasebookToken: UUID?

    @AppStorage("condisco.focusLanguage") private var focusSlug = "french"

    func handle(url: URL) {
        guard let link = DeepLink(url: url) else { return }
        Task { await resolve(link) }
    }

    /// Spotlight taps arrive as user activities, not as URLs.
    func handle(activity: NSUserActivity) {
        guard activity.activityType == CSSearchableItemActionType,
              let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
              let url = URL(string: identifier) else { return }
        handle(url: url)
    }

    func closePlayer() {
        playerRequest = nil
        NotificationCenter.default.post(name: .condiscoLessonCompleted, object: nil)
    }

    private func resolve(_ link: DeepLink) async {
        if link == .review {
            reviewToken = UUID()
            return
        }
        if link == .phrasebook {
            phrasebookToken = UUID()
            return
        }
        do {
            let store = try LearningStore.inDocuments()
            let packs = try PackLoader.loadPacks()
            switch link {
            case .continue:
                guard let pack = packs.first(where: { $0.language.slug == focusSlug }) ?? packs.first,
                      let lesson = Self.nextLesson(in: pack, store: store) else { return }
                playerRequest = DeepLinkPlayerRequest(
                    id: "\(pack.id)/\(lesson.id)",
                    pack: pack,
                    lessonId: lesson.id,
                    store: store
                )
            case .lesson(let packId, let lessonId):
                guard let pack = packs.first(where: { $0.id == packId }),
                      pack.lesson(id: lessonId) != nil else { return }
                playerRequest = DeepLinkPlayerRequest(
                    id: "\(packId)/\(lessonId)",
                    pack: pack,
                    lessonId: lessonId,
                    store: store
                )
            case .review, .phrasebook:
                // Handled above through reviewToken/phrasebookToken;
                // nothing left to resolve here.
                break
            }
        } catch {
            // Best-effort: a deep link never surfaces an error.
        }
    }

    /// Mirrors HomeModel.nextLesson: the first lesson in unit/lesson order with
    /// no participation yet. Kept here so HomeView.swift stays untouched.
    private static func nextLesson(in pack: CoursePack, store: LearningStore) -> Lesson? {
        let done: Set<String>
        do {
            done = try store.project(pack: pack).participationCompleted
        } catch {
            return nil
        }
        var unitIds: [String] = []
        for lesson in pack.lessons where !unitIds.contains(lesson.unitId) {
            unitIds.append(lesson.unitId)
        }
        for unitId in unitIds {
            guard pack.units.contains(where: { $0.id == unitId }) else { continue }
            for lesson in pack.lessons where lesson.unitId == unitId {
                if !done.contains(lesson.id) { return lesson }
            }
        }
        return nil
    }
}
