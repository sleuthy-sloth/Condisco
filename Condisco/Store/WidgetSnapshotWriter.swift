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
    static func refresh(packs: [CoursePack], focusSlug: String) {
        guard let store = try? LearningStore.inDocuments() else { return }
        let dueCount = (try? ReviewCatalog.loadDue(packs: packs, store: store))?.due.count ?? 0
        let focusPack = packs.first(where: { $0.language.slug == focusSlug }) ?? packs.first
        var title: String?
        var unit: String?
        var minutes: Int?
        var packId: String?
        var lessonId: String?
        if let pack = focusPack,
           let projected = try? store.project(pack: pack),
           let next = firstIncompleteLesson(pack: pack, progress: projected) {
            title = next.lesson.title
            unit = next.unit.title
            minutes = next.lesson.estimatedMinutes
            packId = pack.id
            lessonId = next.lesson.id
        }
        let weekDays = currentWeekDays()
        let flags = (try? store.practiceDayFlags(for: weekDays))
            ?? Array(repeating: false, count: 7)
        let days = (try? store.practiceDays()) ?? 0
        WidgetShared.writeSnapshot(WidgetSnapshot(
            focusSlug: focusSlug,
            focusLanguageName: focusPack?.language.displayName ?? "",
            dueCount: dueCount,
            nextLessonTitle: title,
            nextLessonUnit: unit,
            nextLessonMinutes: minutes,
            nextPackId: packId,
            nextLessonId: lessonId,
            weekFlags: flags,
            practiceDays: days,
            updatedAt: Date()))
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.widgetKind)
    }

    /// Unit/lesson-order scan mirroring HomeModel.nextLesson.
    private static func firstIncompleteLesson(
        pack: CoursePack, progress: PackProgress
    ) -> (lesson: Lesson, unit: CourseUnit)? {
        let done = progress.participationCompleted
        var unitIds: [String] = []
        for lesson in pack.lessons where !unitIds.contains(lesson.unitId) {
            unitIds.append(lesson.unitId)
        }
        for unitId in unitIds {
            guard let unit = pack.units.first(where: { $0.id == unitId }) else { continue }
            for lesson in pack.lessons where lesson.unitId == unitId {
                if !done.contains(lesson.id) { return (lesson, unit) }
            }
        }
        return nil
    }
}
