import SwiftUI

struct CalendarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            CalendarHeader()
            CalendarGrid()
        }
        .background(Theme.Colors.background)
    }
}

// MARK: - Header

private struct CalendarHeader: View {
    @EnvironmentObject private var appState: AppState
    @State private var isCloseHovering = false
    @State private var isPrevHovering = false
    @State private var isNextHovering = false
    @State private var isTodayHovering = false

    private var monthYearLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: appState.calendarDate)
    }

    private var isCurrentMonth: Bool {
        let cal = Calendar.current
        return cal.isDate(appState.calendarDate, equalTo: Date(), toGranularity: .month)
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Text("Daily")
                .font(Theme.Fonts.sidebarHeader)
                .foregroundStyle(Theme.Colors.textSecondary)
                .lineLimit(1)

            Spacer()

            // Previous month
            Button {
                navigateMonth(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(Theme.Fonts.disclosure)
                    .foregroundStyle(isPrevHovering ? Theme.Colors.textSecondary : Theme.Colors.textMuted)
                    .frame(width: 22, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.small)
                            .fill(isPrevHovering ? Theme.Colors.hover : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .onHover { isPrevHovering = $0 }

            // Today
            Button {
                appState.calendarDate = Date()
                appState.openDailyNote(for: Date())
            } label: {
                Text("Today")
                    .font(Theme.Fonts.statusBar)
                    .foregroundStyle(isTodayHovering ? Theme.Colors.textSecondary : Theme.Colors.textMuted)
                    .padding(.horizontal, Theme.Spacing.xs)
                    .padding(.vertical, Theme.Spacing.xxs)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.small)
                            .fill(isTodayHovering ? Theme.Colors.hover : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .onHover { isTodayHovering = $0 }

            // Next month
            Button {
                navigateMonth(1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(Theme.Fonts.disclosure)
                    .foregroundStyle(isNextHovering ? Theme.Colors.textSecondary : Theme.Colors.textMuted)
                    .frame(width: 22, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.small)
                            .fill(isNextHovering ? Theme.Colors.hover : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .onHover { isNextHovering = $0 }

            // Close
            Button {
                appState.toggleCalendar()
            } label: {
                Image(systemName: "xmark")
                    .font(Theme.Fonts.icon)
                    .foregroundStyle(isCloseHovering ? Theme.Colors.textSecondary : Theme.Colors.textMuted)
                    .frame(width: 22, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.small)
                            .fill(isCloseHovering ? Theme.Colors.hover : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .onHover { isCloseHovering = $0 }
            .help("Close calendar")
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.top, 38)
        .padding(.bottom, Theme.Spacing.xs)

        // Month/year row
        HStack {
            Text(monthYearLabel)
                .font(Theme.Fonts.statusBar)
                .foregroundStyle(Theme.Colors.textMuted)
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.bottom, Theme.Spacing.s)
    }

    private func navigateMonth(_ delta: Int) {
        let cal = Calendar.current
        if let newDate = cal.date(byAdding: .month, value: delta, to: appState.calendarDate) {
            appState.calendarDate = newDate
        }
    }
}

// MARK: - Grid

private struct CalendarGrid: View {
    @EnvironmentObject private var appState: AppState

    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    private var cal: Calendar { Calendar.current }

    private var year: Int {
        cal.component(.year, from: appState.calendarDate)
    }

    private var month: Int {
        cal.component(.month, from: appState.calendarDate)
    }

    private var daysInMonth: Int {
        cal.range(of: .day, in: .month, for: appState.calendarDate)?.count ?? 30
    }

    private var firstWeekday: Int {
        // 1 = Sunday in Calendar.current
        let comps = DateComponents(year: year, month: month, day: 1)
        guard let date = cal.date(from: comps) else { return 1 }
        return cal.component(.weekday, from: date) // 1=Sun, 2=Mon, ...
    }

    private var noteDays: Set<Int> {
        appState.dailyNoteDates(for: year, month: month)
    }

    private var todayDay: Int? {
        let today = Date()
        let ty = cal.component(.year, from: today)
        let tm = cal.component(.month, from: today)
        guard ty == year && tm == month else { return nil }
        return cal.component(.day, from: today)
    }

    private var activeDay: Int? {
        guard let activeURL = appState.activeFileURL else { return nil }
        let name = activeURL.deletingPathExtension().lastPathComponent
        let prefix = String(format: "%04d-%02d-", year, month)
        guard name.hasPrefix(prefix) else { return nil }
        return Int(name.dropFirst(prefix.count))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Day-of-week headers
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(dayLabels, id: \.self) { label in
                    Text(label)
                        .font(Theme.Fonts.statusBar)
                        .foregroundStyle(Theme.Colors.textDisabled)
                        .frame(height: 20)
                }
            }
            .padding(.horizontal, Theme.Spacing.m)

            // Day cells
            LazyVGrid(columns: columns, spacing: 2) {
                // Empty cells before first day
                ForEach(0..<(firstWeekday - 1), id: \.self) { _ in
                    Color.clear
                        .frame(height: 24)
                }

                // Actual days
                ForEach(1...daysInMonth, id: \.self) { day in
                    CalendarDayCell(
                        day: day,
                        isToday: day == todayDay,
                        hasNote: noteDays.contains(day),
                        isActive: day == activeDay
                    )
                }
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.bottom, Theme.Spacing.m)
        }
    }
}

// MARK: - Day Cell

private struct CalendarDayCell: View {
    @EnvironmentObject private var appState: AppState
    let day: Int
    let isToday: Bool
    let hasNote: Bool
    let isActive: Bool

    @State private var isHovering = false

    var body: some View {
        Button {
            openNote()
        } label: {
            VStack(spacing: 1) {
                Text("\(day)")
                    .font(Theme.Fonts.statusBar)
                    .foregroundStyle(textColor)

                // Dot indicator for existing notes
                Circle()
                    .fill(hasNote ? Theme.Colors.textMuted : Color.clear)
                    .frame(width: 3, height: 3)
            }
            .frame(height: 24)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.small)
                    .fill(backgroundColor)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }

    private var textColor: Color {
        if isActive { return Theme.Colors.text }
        if isToday { return Theme.Colors.textSecondary }
        if hasNote { return Theme.Colors.textSecondary }
        return Theme.Colors.textMuted
    }

    private var backgroundColor: Color {
        if isActive { return Theme.Colors.selection }
        if isToday { return Theme.Colors.hover }
        if isHovering { return Theme.Colors.hover }
        return Color.clear
    }

    private func openNote() {
        let cal = Calendar.current
        let year = cal.component(.year, from: appState.calendarDate)
        let month = cal.component(.month, from: appState.calendarDate)
        let comps = DateComponents(year: year, month: month, day: day)
        guard let date = cal.date(from: comps) else { return }
        appState.openDailyNote(for: date)
    }
}
