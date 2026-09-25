import Foundation
import SwiftUI
import UIKit
import UserNotifications

// MARK: - Review reminders
//
// One gentle local notification a day, only when reviews are actually
// waiting. Opt-in, at a chosen time. No streaks, no scolding — the copy
// never claims more than "waiting". The schedule recomputes from the
// live due queue whenever it can change — review session ends and
// lesson completions call `refreshShared()` — so a cleared queue
// cancels the nudge right away; the foreground refresh is the backstop.
// Fully offline: everything is scheduled on-device.

@MainActor
final class ReviewReminders: ObservableObject {
    private static let enabledKey = "condisco.reminders.enabled"
    private static let minutesKey = "condisco.reminders.minutes"
    private static let requestId = "condisco.review-reminder"

    @Published var isEnabled: Bool = UserDefaults.standard.bool(
        forKey: "condisco.reminders.enabled"
    ) {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey)
            if isEnabled {
                Task { await requestAndSchedule() }
            } else {
                Self.cancelShared()
            }
        }
    }

    /// Minutes after midnight for the daily nudge. Defaults to 8:00.
    @Published var minutes: Int = {
        let stored = UserDefaults.standard.integer(forKey: "condisco.reminders.minutes")
        return stored == 0 ? 8 * 60 : stored
    }() {
        didSet {
            UserDefaults.standard.set(minutes, forKey: Self.minutesKey)
            Task { await refresh() }
        }
    }

    @Published var permissionDenied = false

    private var foregroundObserver: NSObjectProtocol?

    init() {
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    deinit {
        if let foregroundObserver {
            NotificationCenter.default.removeObserver(foregroundObserver)
        }
    }

    func requestAndSchedule() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
            permissionDenied = !granted
        } catch {
            permissionDenied = true
        }
        await refresh()
    }

    /// Recomputes the reminder from the live due queue, callable from
    /// anywhere. The `ReviewReminders` instance lives in the You tab,
    /// so review-session and lesson code can't reach it — this static
    /// reads the same UserDefaults keys and shares the scheduling path
    /// below. A cleared queue cancels the nudge right away instead of
    /// leaving a stale notification until the next foreground; a
    /// refilled queue reschedules it. A no-op when reminders are off.
    static func refreshShared() {
        Task { @MainActor in
            guard UserDefaults.standard.bool(forKey: Self.enabledKey) else {
                Self.cancelShared()
                return
            }
            let settings = await UNUserNotificationCenter.current()
                .notificationSettings()
            guard settings.authorizationStatus == .authorized
                    || settings.authorizationStatus == .provisional else {
                Self.cancelShared()
                return
            }
            let stored = UserDefaults.standard.integer(forKey: Self.minutesKey)
            let minutes = stored == 0 ? 8 * 60 : stored
            await Self.scheduleShared(minutes: minutes)
        }
    }

    /// Schedules (or cancels) the daily nudge from the live due queue.
    /// Shared by the instance refresh and the static refresh path.
    private static func scheduleShared(minutes: Int) async {
        do {
            let packs = try PackLoader.loadPacks()
            let store = try LearningStore.inDocuments()
            let (due, _) = try ReviewCatalog.loadDue(packs: packs, store: store)
            guard !due.isEmpty else { cancelShared(); return }
            let focusSlug = UserDefaults.standard.string(
                forKey: "condisco.focusLanguage") ?? "french"
            let focusName = packs.first(where: { $0.language.slug == focusSlug })?
                .language.displayName ?? "your course"
            let content = UNMutableNotificationContent()
            content.title = "A calm minute of review"
            content.body = "\(due.count) review\(due.count == 1 ? " is" : "s are")"
                + " waiting in \(focusName) — whenever you're ready."
            content.sound = .default
            var components = DateComponents()
            components.hour = minutes / 60
            components.minute = minutes % 60
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: Self.requestId, content: content, trigger: trigger)
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            cancelShared()
        }
    }

    private static func cancelShared() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.requestId])
    }

    /// Recomputes the schedule from the live due queue. Called when the
    /// toggle flips, when the time changes, and on every foreground.
    /// Also updates the permission flag the You tab reads.
    func refresh() async {
        guard isEnabled else { Self.cancelShared(); return }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional else {
            permissionDenied = true
            Self.cancelShared()
            return
        }
        permissionDenied = false
        await Self.scheduleShared(minutes: minutes)
    }
}
