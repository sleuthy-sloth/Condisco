import Foundation

// MARK: - Widget snapshot
//
// The single Codable payload the app writes and the widget extension
// reads through the shared App Group. Foundation ONLY — this file is a
// member of both the app target and the widget extension target, so it
// must stay extension-safe: no SwiftUI, no WidgetKit, no app modules.

struct WidgetSnapshot: Codable {
    var focusSlug: String
    var focusLanguageName: String
    var dueCount: Int
    var nextLessonTitle: String?
    var nextLessonUnit: String?
    var nextLessonMinutes: Int?
    var nextPackId: String?
    var nextLessonId: String?
    var weekFlags: [Bool]
    var practiceDays: Int
    var updatedAt: Date

    /// Gallery placeholder before the app has written anything.
    static var placeholder: WidgetSnapshot {
        WidgetSnapshot(
            focusSlug: "french",
            focusLanguageName: "French",
            dueCount: 0,
            nextLessonTitle: nil,
            nextLessonUnit: nil,
            nextLessonMinutes: nil,
            nextPackId: nil,
            nextLessonId: nil,
            weekFlags: Array(repeating: false, count: 7),
            practiceDays: 0,
            updatedAt: Date())
    }
}

// MARK: - Shared App Group plumbing

enum WidgetShared {
    /// App Group shared by the app and the widget extension.
    static let appGroupId = "group.com.sleuthysloth.condisco"
    /// WidgetKit kind string; the app uses it when reloading timelines.
    static let widgetKind = "CondiscoWidget"

    private static let snapshotKey = "condisco.widget.snapshot"

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    static func readSnapshot() -> WidgetSnapshot? {
        guard let data = sharedDefaults?.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    static func writeSnapshot(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        sharedDefaults?.set(data, forKey: snapshotKey)
    }

    /// Deep link into the app: resume the learner's path.
    static var continueURL: URL {
        // swiftlint:disable:next force_unwrapping
        URL(string: "condisco://continue")!
    }

    /// Deep link into the app: open the Review tab.
    static var reviewURL: URL {
        // swiftlint:disable:next force_unwrapping
        URL(string: "condisco://review")!
    }

    /// Deep link into the app: open one lesson directly.
    static func lessonURL(packId: String, lessonId: String) -> URL? {
        URL(string: "condisco://lesson/\(packId)/\(lessonId)")
    }
}
