import Foundation

/// A medication's daily schedule, as plain values.
struct DoseSchedule: Equatable {
    var medicationID: String
    var name: String
    /// Minutes after midnight, e.g. 480 = 8:00 AM.
    var minutesOfDay: [Int]
    /// Doses scheduled before this moment are not expected.
    var start: Date
    /// Doses scheduled at or after this moment are not expected (medication stopped).
    var end: Date?
}

struct ExpectedDose: Hashable {
    var medicationID: String
    var name: String
    var scheduledAt: Date

    var key: String { DoseKey.make(medicationID: medicationID, scheduledAt: scheduledAt) }
}

enum DoseKey {
    static func make(medicationID: String, scheduledAt: Date) -> String {
        "\(medicationID)|\(Int(scheduledAt.timeIntervalSince1970.rounded()))"
    }
}

enum DoseClock {
    /// The moment a dose is scheduled on a given day. Uses the calendar's hour/minute
    /// setter so daylight-saving changes don't shift doses.
    static func date(minutesOfDay: Int, on day: Date, calendar: Calendar = .current) -> Date? {
        let start = calendar.startOfDay(for: day)
        return calendar.date(bySettingHour: minutesOfDay / 60, minute: minutesOfDay % 60, second: 0, of: start)
    }
}

enum DayDoseStatus: Equatable {
    case noDoses   // nothing was scheduled
    case complete  // every scheduled dose was taken
    case missed    // at least one dose was not taken (past days only)
    case pending   // today, not all taken yet
}

struct DayAdherence: Identifiable, Equatable {
    var day: Date
    var expected: Int
    var taken: Int
    var status: DayDoseStatus

    var id: Date { day }
}

struct AdherenceSummary: Equatable {
    var due: Int
    var taken: Int
    var days: [DayAdherence]
    var missed: [ExpectedDose]
    var insight: String?

    var percent: Int? {
        guard due > 0 else { return nil }
        return Int((Double(taken) / Double(due) * 100).rounded())
    }

    static let empty = AdherenceSummary(due: 0, taken: 0, days: [], missed: [], insight: nil)
}

enum Adherence {
    static func expectedDoses(
        _ schedules: [DoseSchedule],
        from: Date,
        to: Date,
        calendar: Calendar = .current
    ) -> [ExpectedDose] {
        var result: [ExpectedDose] = []
        var day = calendar.startOfDay(for: from)
        let lastDay = calendar.startOfDay(for: to)
        while day <= lastDay {
            for schedule in schedules {
                for minutes in schedule.minutesOfDay.sorted() {
                    guard let at = DoseClock.date(minutesOfDay: minutes, on: day, calendar: calendar) else { continue }
                    if at < schedule.start { continue }
                    if let end = schedule.end, at >= end { continue }
                    result.append(ExpectedDose(medicationID: schedule.medicationID, name: schedule.name, scheduledAt: at))
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result.sorted { $0.scheduledAt < $1.scheduledAt }
    }

    /// Summarises adherence for a set of expected doses.
    /// - Parameters:
    ///   - days: every calendar day that should appear in `days`, even with no doses.
    ///   - takenKeys: `DoseKey`s of doses marked taken.
    static func summarize(
        expected: [ExpectedDose],
        takenKeys: Set<String>,
        days: [Date],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> AdherenceSummary {
        let today = calendar.startOfDay(for: now)
        // A dose counts once it's due, or earlier if it was already taken.
        let counted = expected.filter { $0.scheduledAt <= now || takenKeys.contains($0.key) }
        let taken = counted.filter { takenKeys.contains($0.key) }
        let missed = expected.filter {
            calendar.startOfDay(for: $0.scheduledAt) < today && !takenKeys.contains($0.key)
        }

        let byDay = Dictionary(grouping: expected) { calendar.startOfDay(for: $0.scheduledAt) }
        let dayRows: [DayAdherence] = days.map { rawDay in
            let day = calendar.startOfDay(for: rawDay)
            let doses = byDay[day] ?? []
            let takenCount = doses.filter { takenKeys.contains($0.key) }.count
            let status: DayDoseStatus
            if doses.isEmpty {
                status = .noDoses
            } else if takenCount == doses.count {
                status = .complete
            } else if day >= today {
                status = .pending
            } else {
                status = .missed
            }
            return DayAdherence(day: day, expected: doses.count, taken: takenCount, status: status)
        }

        return AdherenceSummary(
            due: counted.count,
            taken: taken.count,
            days: dayRows,
            missed: missed,
            insight: insight(missed: missed, due: counted.count, calendar: calendar)
        )
    }

    static func insight(missed: [ExpectedDose], due: Int, calendar: Calendar = .current) -> String? {
        guard due > 0 else { return nil }
        if missed.isEmpty { return "No missed doses in this period." }
        if missed.count == 1, let dose = missed.first {
            let weekday = weekdayName(dose.scheduledAt, calendar: calendar)
            let part = partOfDay(dose.scheduledAt, calendar: calendar)
            return "Missed \(weekday)’s \(part) \(dose.name)."
        }
        let byWeekday = Dictionary(grouping: missed) { calendar.component(.weekday, from: $0.scheduledAt) }
        if let top = byWeekday.max(by: { $0.value.count < $1.value.count }) {
            let name = calendar.weekdaySymbols[(top.key - 1) % 7]
            let count = top.value.count
            if count == missed.count {
                return "All \(missed.count) missed doses were on \(name)s. An extra \(name) reminder may help."
            }
            if Double(count) / Double(missed.count) > 0.5 {
                return "Most missed doses were on \(name)s."
            }
        }
        let eveningMissed = missed.filter { calendar.component(.hour, from: $0.scheduledAt) >= 17 }.count
        if Double(eveningMissed) / Double(missed.count) > 0.6 {
            return "Most missed doses were evening doses."
        }
        return "\(missed.count) missed doses in this period."
    }

    static func weekdayName(_ date: Date, calendar: Calendar = .current) -> String {
        let weekday = calendar.component(.weekday, from: date)
        return calendar.weekdaySymbols[(weekday - 1) % 7]
    }

    static func partOfDay(_ date: Date, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 4..<12: return "morning"
        case 12..<17: return "afternoon"
        default: return "evening"
        }
    }
}
