import Foundation
import WidgetKit

// MARK: - Widget snapshot writer (app target only)
//
// Recomputes the Home widget's snapshot from the learning store and
// nudges WidgetKit to re-render. Fire-and-forget: it never throws and
// never surfaces errors — a missed refresh just leaves the last good
// snapshot in place until the next progress change.

@MainActor
enum WidgetSnapshotWriter {
    /// Pure snapshot assembly — everything except store I/O and the
    /// WidgetKit reload.
    ///
    /// `progress` carries each pack's projected `PackProgress`; only the
    /// focus pack's entry is consulted (the focus pack is the first pack
    /// whose `language.slug` matches `focusSlug`, falling back to the
    /// first pack — the same selection `refresh` and Home make). The next
    /// lesson is picked by the shared `firstUncompletedLesson(completed:)`
    /// helper, fed the same `participationCompleted` set Home and
    /// `condisco://continue` use, so the widget always points at the same
    /// next lesson as the other surfaces. When every lesson is complete
    /// the next-lesson fields are nil and the widget renders
    /// "Path complete".
    ///
    /// Extracted (rather than inlined in `refresh`) so unit tests can pin
    /// the snapshot's next-lesson contract without a store or WidgetKit.
    static func makeSnapshot(
        packs: [CoursePack],
        focusSlug: String,
        progress: [String: PackProgress],
        dueCount: Int,
        weekFlags: [Bool],
        practiceDays: Int,
        updatedAt: Date = Date()
    ) -> WidgetSnapshot {
        let focusPack = packs.first(where: { $0.language.slug == focusSlug }) ?? packs.first
        var title: String?
        var unit: String?
        var minutes: Int?
        var packId: String?
        var lessonId: String?
        if let pack = focusPack,
           let projected = progress[pack.id],
           let next = pack.firstUncompletedLesson(
               completed: projected.participationCompleted) {
            title = next.lesson.title
            unit = next.unit.title
            minutes = next.lesson.estimatedMinutes
            packId = pack.id
            lessonId = next.lesson.id
        }
        return WidgetSnapshot(
            focusSlug: focusSlug,
            focusLanguageName: focusPack?.language.displayName ?? "",
            dueCount: dueCount,
            nextLessonTitle: title,
            nextLessonUnit: unit,
            nextLessonMinutes: minutes,
            nextPackId: packId,
            nextLessonId: lessonId,
            weekFlags: weekFlags,
            practiceDays: practiceDays,
            updatedAt: updatedAt)
    }

    static func refresh(packs: [CoursePack], focusSlug: String) {
        guard let store = try? LearningStore.inDocuments() else { return }
        let dueCount = (try? ReviewCatalog.loadDue(packs: packs, store: store))?.due.count ?? 0
        let focusPack = packs.first(where: { $0.language.slug == focusSlug }) ?? packs.first
        // Only the focus pack is projected — the snapshot never consults
        // the other languages' progress.
        var progress: [String: PackProgress] = [:]
        if let focusPack, let projected = try? store.project(pack: focusPack) {
            progress[focusPack.id] = projected
        }
        let weekDays = currentWeekDays()
        let flags = (try? store.practiceDayFlags(for: weekDays))
            ?? Array(repeating: false, count: 7)
        let days = (try? store.practiceDays()) ?? 0
        let snapshot = makeSnapshot(
            packs: packs,
            focusSlug: focusSlug,
            progress: progress,
            dueCount: dueCount,
            weekFlags: flags,
            practiceDays: days)
        WidgetShared.writeSnapshot(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.widgetKind)
    }
}