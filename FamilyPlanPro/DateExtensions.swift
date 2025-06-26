import Foundation

extension Calendar {
    /// Returns the start of the week for the given date, forcing Sunday as the first day.
    func startOfWeek(for date: Date) -> Date {
        var calendar = self
        calendar.firstWeekday = 1 // Sunday
        if let interval = calendar.dateInterval(of: .weekOfYear, for: date) {
            return interval.start
        }
        return calendar.startOfDay(for: date)
    }
}
