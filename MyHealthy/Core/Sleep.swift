import Foundation

/// One night of sleep, as plain values.
struct SleepPoint: Equatable {
    var bedtime: Date
    var wake: Date

    var duration: TimeInterval { wake.timeIntervalSince(bedtime) }
}

enum SleepMath {
    /// Longer entries are almost certainly a wrong date.
    static let maximumDuration: TimeInterval = 20 * 3600

    /// The first moment after `bedtime` whose clock reads `wakeMinutes`
    /// (minutes after midnight). 11:00 PM → 6:30 AM lands on the next day.
    static func wake(after bedtime: Date, wakeMinutes: Int, calendar: Calendar = .current) -> Date {
        guard let sameDay = DoseClock.date(minutesOfDay: wakeMinutes, on: bedtime, calendar: calendar) else { return bedtime }
        if sameDay > bedtime { return sameDay }
        return calendar.date(byAdding: .day, value: 1, to: sameDay) ?? sameDay
    }

    /// The evening a sleep belongs to. Going to bed at 12:40 AM on the 29th
    /// still counts as the night of the 28th.
    static func night(of bedtime: Date, calendar: Calendar = .current) -> Date {
        let day = calendar.startOfDay(for: bedtime)
        guard calendar.component(.hour, from: bedtime) < 12 else { return day }
        return calendar.date(byAdding: .day, value: -1, to: day) ?? day
    }

    static func problem(bedtime: Date, wake: Date, now: Date = Date()) -> String? {
        let duration = wake.timeIntervalSince(bedtime)
        if duration <= 0 { return "Wake-up must be after bedtime." }
        if duration > maximumDuration { return "That’s more than 20 hours. Check the dates." }
        if wake > now.addingTimeInterval(5 * 60) { return "Wake-up time can’t be in the future." }
        return nil
    }

    /// "7h 20m", "45m"
    static func durationText(_ duration: TimeInterval) -> String {
        let minutes = max(0, Int((duration / 60).rounded()))
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return "\(rest)m" }
        return rest == 0 ? "\(hours)h" : "\(hours)h \(rest)m"
    }
}

struct SleepSummary: Equatable {
    var nights: Int
    var averageDuration: TimeInterval?
    /// Minutes after midnight.
    var usualBedtime: Int?
    var usualWake: Int?

    static let empty = SleepSummary(nights: 0, averageDuration: nil, usualBedtime: nil, usualWake: nil)
}

enum SleepStats {
    static func summarize(_ points: [SleepPoint], calendar: Calendar = .current) -> SleepSummary {
        guard !points.isEmpty else { return .empty }
        let total = points.reduce(0) { $0 + $1.duration }
        return SleepSummary(
            nights: points.count,
            averageDuration: total / Double(points.count),
            usualBedtime: averageClock(points.map { minutes(of: $0.bedtime, calendar: calendar) }, pivot: 12 * 60),
            usualWake: averageClock(points.map { minutes(of: $0.wake, calendar: calendar) }, pivot: 0)
        )
    }

    /// Averages clock times that may wrap past midnight. Times are measured from
    /// `pivot` so 11:30 PM and 12:30 AM average to midnight, not noon.
    static func averageClock(_ minutes: [Int], pivot: Int) -> Int? {
        guard !minutes.isEmpty else { return nil }
        let day = 24 * 60
        let offsets = minutes.map { (($0 - pivot) % day + day) % day }
        let mean = Double(offsets.reduce(0, +)) / Double(offsets.count)
        return ((Int(mean.rounded()) + pivot) % day + day) % day
    }

    private static func minutes(of date: Date, calendar: Calendar) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}
