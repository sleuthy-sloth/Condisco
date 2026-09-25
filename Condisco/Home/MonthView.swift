import SwiftUI

// MARK: - Month view
//
// A calm calendar grid for the current calendar month: weekday headers
// Monday through Sunday, day numbers, a terracotta dot under days with
// practice, muted future days. Dots only — no counts, no streaks, no
// judgment.

struct MonthView: View {
    let days: [Date]
    let flags: [Bool]

    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    private enum GridCell: Identifiable {
        case weekday(Int, String)
        case blank(Int)
        case day(Int, Date)

        var id: String {
            switch self {
            case .weekday(let index, _): return "weekday-\(index)"
            case .blank(let index): return "blank-\(index)"
            case .day(let index, _): return "day-\(index)"
            }
        }
    }

    /// Single-letter weekday symbols, Monday first.
    private static var weekdayHeader: [String] {
        let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
        guard symbols.count == 7 else { return symbols }
        return Array(symbols[1...]) + [symbols[0]]
    }

    private var monthTitle: String {
        guard let first = days.first else { return "" }
        return first.formatted(.dateTime.month(.wide).year())
    }

    /// Leading blanks so the 1st lands under its real weekday column.
    private var leadingBlanks: Int {
        guard let first = days.first else { return 0 }
        let weekday = Calendar.current.component(.weekday, from: first) // 1 = Sunday
        return (weekday + 5) % 7 // Monday = 0 … Sunday = 6
    }

    private var gridCells: [GridCell] {
        let weekdays = Self.weekdayHeader.enumerated().map {
            GridCell.weekday($0.offset, $0.element)
        }
        let blanks = (0..<leadingBlanks).map { GridCell.blank($0) }
        let dates = days.enumerated().map { GridCell.day($0.offset, $0.element) }
        return weekdays + blanks + dates
    }

    var body: some View {
        if !days.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(monthTitle)
                    .font(DesignTokens.display(18))
                    .foregroundStyle(DesignTokens.inkDeep)
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(gridCells) { cell in
                        switch cell {
                        case .weekday(_, let label):
                            Text(label)
                                .font(DesignTokens.text(11, weight: .medium))
                                .foregroundStyle(DesignTokens.muted)
                        case .blank:
                            Color.clear.frame(height: 40)
                        case .day(let index, let day):
                            dayCell(
                                day: day,
                                active: index < flags.count && flags[index])
                        }
                    }
                }
            }
        }
    }

    private func dayCell(day: Date, active: Bool) -> some View {
        let calendar = Calendar.current
        let isFuture =
            calendar.startOfDay(for: day) > calendar.startOfDay(for: Date())
        return VStack(spacing: 5) {
            Text("\(calendar.component(.day, from: day))")
                .font(DesignTokens.text(
                    14, weight: active ? .semibold : .regular))
                .foregroundStyle(isFuture
                                 ? DesignTokens.stock3
                                 : (active ? DesignTokens.inkDeep : DesignTokens.muted))
            Circle()
                .fill(active ? DesignTokens.primary : Color.clear)
                .frame(width: 6, height: 6)
        }
        .frame(minHeight: 40)
        .accessibilityLabel(
            active
                ? "\(day.formatted(date: .abbreviated, time: .omitted)), practised"
                : day.formatted(date: .abbreviated, time: .omitted))
    }
}
