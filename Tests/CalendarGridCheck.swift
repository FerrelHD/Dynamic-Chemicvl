import Foundation

// Self-contained runnable check for CalendarDaySlot generation & calendar date selection logic.

@main
struct CalendarGridCheck {
    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        precondition(condition(), "FAIL: \(message)")
    }

    static func main() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!

        // November 2026: Nov 1, 2026 is a Sunday -> Monday-first offset should be 6 leading Oct days (Oct 26..31).
        let novComponents = DateComponents(year: 2026, month: 11, day: 15)
        let novDate = cal.date(from: novComponents)!
        let grid = IslandState.calendarDays(for: novDate, calendar: cal)

        expect(grid.count == 42, "Grid must always have 42 cells, got \(grid.count)")
        expect(cal.component(.day, from: grid[0].date) == 26 && !grid[0].isCurrentMonth,
               "First cell for Nov 2026 should be Oct 26 (adjacent month)")
        expect(cal.component(.day, from: grid[5].date) == 31 && !grid[5].isCurrentMonth,
               "Sixth cell for Nov 2026 should be Oct 31 (adjacent month)")
        expect(cal.component(.day, from: grid[6].date) == 1 && grid[6].isCurrentMonth,
               "Seventh cell for Nov 2026 should be Nov 1 (current month)")
        expect(cal.component(.day, from: grid[35].date) == 30 && grid[35].isCurrentMonth,
               "Nov 30 should be at index 35 (current month)")
        expect(cal.component(.day, from: grid[36].date) == 1 && !grid[36].isCurrentMonth,
               "Trailing cells should start Dec 1 (adjacent month)")
        expect(cal.component(.day, from: grid[41].date) == 6 && !grid[41].isCurrentMonth,
               "Last cell for Nov 2026 should be Dec 6 (adjacent month)")

        // Check month count in grid
        let currentMonthCount = grid.filter { $0.isCurrentMonth }.count
        expect(currentMonthCount == 30, "Nov 2026 should have 30 current-month cells, got \(currentMonthCount)")

        print("CalendarGridCheck: all assertions passed!")
    }
}
