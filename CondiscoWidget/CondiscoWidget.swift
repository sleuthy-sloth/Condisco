import SwiftUI
import WidgetKit

// MARK: - Condisco Home widget
//
// An observational glance at the learner's state: reviews due and the
// next lesson on their path. No streaks, no scores, no judgment — the
// numbers only describe what is there. The app writes a WidgetSnapshot
// into the shared App Group whenever progress changes; the widget
// renders the latest snapshot and refreshes after local midnight.

struct CondiscoProvider: TimelineProvider {
    func placeholder(in context: Context) -> CondiscoEntry {
        CondiscoEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (CondiscoEntry) -> Void) {
        let snapshot = WidgetShared.readSnapshot() ?? .placeholder
        completion(CondiscoEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CondiscoEntry>) -> Void) {
        let snapshot = WidgetShared.readSnapshot() ?? .placeholder
        let entry = CondiscoEntry(date: Date(), snapshot: snapshot)
        // One entry is enough: the app pushes a new timeline on every
        // progress change. The midnight refresh only rolls date-bound
        // numbers (practice days, due counts) while the app is quiet.
        let nextMidnight = Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 0),
            matchingPolicy: .nextTime,
            direction: .forward
        ) ?? Date().addingTimeInterval(24 * 3600)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }
}

struct CondiscoEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

@main
struct CondiscoWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetShared.widgetKind, provider: CondiscoProvider()) { entry in
            CondiscoWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Condisco")
        .description("Reviews due and your next lesson, at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Warm Studio colors
//
// The widget extension cannot link app-target modules, so the palette
// values are duplicated here from the app's DesignTokens.

private enum WidgetColors {
    /// Cream #FFFDF7
    static let cream = Color(red: 1.0, green: 253 / 255, blue: 247 / 255)
    /// Espresso #2F2A24
    static let ink = Color(red: 47 / 255, green: 42 / 255, blue: 36 / 255)
    static let muted = Color(red: 47 / 255, green: 42 / 255, blue: 36 / 255, opacity: 0.62)
    /// Terracotta #A8511F
    static let terracotta = Color(red: 168 / 255, green: 81 / 255, blue: 31 / 255)
    static let line = Color(red: 47 / 255, green: 42 / 255, blue: 36 / 255, opacity: 0.14)
}

// MARK: - Entry view

private struct CondiscoWidgetEntryView: View {
    let entry: CondiscoEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                mediumView
            default:
                smallView
            }
        }
        .containerBackground(for: .widget) {
            WidgetColors.cream
        }
    }

    // MARK: Small — the review count, or a calm empty state.

    private var smallView: some View {
        let snapshot = entry.snapshot
        return VStack(alignment: .leading, spacing: 4) {
            Spacer(minLength: 0)
            if snapshot.dueCount > 0 {
                Text("\(snapshot.dueCount)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(WidgetColors.ink)
                Text(snapshot.dueCount == 1 ? "review due" : "reviews due")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(WidgetColors.terracotta)
            } else {
                Text("All caught up")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(WidgetColors.ink)
                if !snapshot.focusLanguageName.isEmpty {
                    Text(snapshot.focusLanguageName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(WidgetColors.terracotta)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Tapping the count opens the Review tab directly.
        .widgetURL(WidgetShared.reviewURL)
    }

    // MARK: Medium — continue the path, plus the review count.

    private var mediumView: some View {
        let snapshot = entry.snapshot
        return VStack(alignment: .leading, spacing: 6) {
            if let title = snapshot.nextLessonTitle,
               let packId = snapshot.nextPackId,
               let lessonId = snapshot.nextLessonId,
               let lessonURL = WidgetShared.lessonURL(packId: packId, lessonId: lessonId) {
                Link(destination: lessonURL) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Continue in \(snapshot.focusLanguageName)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(WidgetColors.terracotta)
                            .textCase(.uppercase)
                        Text(title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(WidgetColors.ink)
                            .lineLimit(2)
                        if let unit = snapshot.nextLessonUnit,
                           let minutes = snapshot.nextLessonMinutes {
                            Text("\(unit) \u{00B7} \(minutes) min")
                                .font(.system(size: 12))
                                .foregroundStyle(WidgetColors.muted)
                                .lineLimit(1)
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Path complete")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(WidgetColors.ink)
                    Text("Every \(snapshot.focusLanguageName) lesson finished. Reviews keep it fresh.")
                        .font(.system(size: 12))
                        .foregroundStyle(WidgetColors.muted)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            Rectangle()
                .fill(WidgetColors.line)
                .frame(height: 1)
            // The review count deep-links to the Review tab; the rest of
            // the widget still resumes the learner's path.
            Link(destination: WidgetShared.reviewURL) {
                Text(snapshot.dueCount > 0
                     ? "\(snapshot.dueCount) \(snapshot.dueCount == 1 ? "review" : "reviews") due"
                     : "All caught up")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(snapshot.dueCount > 0 ? WidgetColors.terracotta : WidgetColors.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(WidgetShared.continueURL)
    }
}
