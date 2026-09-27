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

// MARK: - Shared continue resolution
//
// `condisco://continue`, Home's Today card, and the widget snapshot all
// answer the same question — "what's next on the learner's path?" — and
// must answer identically. This pure function is that single source of
// truth: it selects the focus pack (the first pack whose `language.slug`
// matches, falling back to the first pack) and asks the shared
// `CoursePack.firstUncompletedLesson(completed:)` helper for the next
// uncompleted lesson, fed the SAME completed set every surface uses:
// `PackProgress.finishedLessons`. Pure — no store, no I/O — so the
// deep-link router (which resolves against the Documents store) and the
// unit tests can both exercise exactly the choice a learner's deep link
// makes, and Home and the widget can never drift from it.

/// The learner's next lesson for `focusSlug`, or nil when every lesson on
/// the path is complete (or the focus pack has no projected progress).
///
/// - Parameters:
///   - packs: the bundled course packs, in catalog order.
///   - focusSlug: the learner's focus language slug (`condisco.focusLanguage`).
///   - completedByPack: each pack's `PackProgress.finishedLessons`.
/// - Returns: the resolved pack with its next lesson and unit.
func continueLessonResolution(
    packs: [CoursePack],
    focusSlug: String,
    completedByPack: [String: Set<String>]
) -> (pack: CoursePack, lesson: Lesson, unit: CourseUnit)? {
    let pack = packs.first(where: { $0.language.slug == focusSlug }) ?? packs.first
    guard let pack,
          let completed = completedByPack[pack.id],
          let next = pack.firstUncompletedLesson(completed: completed)
    else { return nil }
    return (pack, next.lesson, next.unit)
}

// MARK: - Progress changes
//
// Posted when a deep-linked lesson player closes or a known mark changes,
// so Home and Courses can refresh their progress.
extension Notification.Name {
    static let condiscoProgressChanged = Notification.Name("condisco.progressChanged")
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
        NotificationCenter.default.post(name: .condiscoProgressChanged, object: nil)
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
                guard let pack = packs.first(where: { $0.language.slug == focusSlug }) ?? packs.first else { return }
                let completed: Set<String>
                do {
                    completed = try store.project(pack: pack).finishedLessons
                } catch {
                    return
                }
                // Same shared resolution Home's Today card and the widget
                // snapshot use, fed the same finishedLessons set.
                guard let (pack, lesson, _) = continueLessonResolution(
                    packs: packs,
                    focusSlug: focusSlug,
                    completedByPack: [pack.id: completed]
                ) else { return }
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
}
