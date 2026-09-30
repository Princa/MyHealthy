import Foundation

/// Shared date and number formatting.
enum Fmt {
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    /// "7:45 AM"
    static func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    /// Minutes after midnight as a time, e.g. 480 -> "8:00 AM".
    static func time(minutes: Int) -> String {
        guard let date = DoseClock.date(minutesOfDay: minutes, on: Date()) else { return "" }
        return time(date)
    }

    /// "Sep 29"
    static func monthDay(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }

    /// "Sep 29, 2026"
    static func monthDayYear(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day().year())
    }

    /// "Tuesday, Sep 29"
    static func weekdayMonthDay(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    /// "Today, 7:45 AM", "Yesterday, 8:10 PM" or "Sep 27, 8:20 PM"
    static func dayAndTime(_ date: Date, calendar: Calendar = .current) -> String {
        let day: String
        if calendar.isDateInToday(date) {
            day = "Today"
        } else if calendar.isDateInYesterday(date) {
            day = "Yesterday"
        } else {
            day = monthDay(date)
        }
        return "\(day), \(time(date))"
    }

    /// "Sep 1 – 29, 2026" or "Aug 31 – Sep 29, 2026"
    static func period(from start: Date, to end: Date, calendar: Calendar = .current) -> String {
        let sameMonth = calendar.isDate(start, equalTo: end, toGranularity: .month)
        let sameYear = calendar.isDate(start, equalTo: end, toGranularity: .year)
        let endDay = calendar.component(.day, from: end)
        let year = calendar.component(.year, from: end)
        if sameMonth {
            return "\(monthDay(start)) – \(endDay), \(year)"
        }
        if sameYear {
            return "\(monthDay(start)) – \(monthDay(end)), \(year)"
        }
        return "\(monthDayYear(start)) – \(monthDayYear(end))"
    }

    /// Minutes after midnight <-> Date on today's date, for DatePicker bindings.
    static func date(fromMinutes minutes: Int) -> Date {
        DoseClock.date(minutesOfDay: minutes, on: Date()) ?? Date()
    }

    static func minutes(from date: Date, calendar: Calendar = .current) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}
