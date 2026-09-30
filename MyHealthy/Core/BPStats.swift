import Foundation

/// A plain-value copy of one reading, used by the statistics code so it stays
/// independent of SwiftData.
struct ReadingPoint: Equatable {
    var date: Date
    var systolic: Int
    var diastolic: Int
    var pulse: Int?
    var slot: TimeOfDay

    var value: BPValue { BPValue(systolic: systolic, diastolic: diastolic) }
}

struct DailyAverage: Identifiable, Equatable {
    var day: Date
    var systolic: Double
    var diastolic: Double
    var count: Int

    var id: Date { day }
}

struct BPSummary: Equatable {
    var count: Int
    var average: BPValue?
    var averagePulse: Int?
    var morning: BPValue?
    var morningCount: Int
    var evening: BPValue?
    var eveningCount: Int
    var inTargetCount: Int
    var highest: ReadingPoint?
    var daily: [DailyAverage]
    /// Average of the first 7 days in the period (only when it does not overlap the last 7 days).
    var firstWeek: BPValue?
    var lastSevenDays: BPValue?
    var lastSevenDaysCount: Int
    var lastSevenDaysInTarget: Int

    var inTargetPercent: Int? {
        guard count > 0 else { return nil }
        return Int((Double(inTargetCount) / Double(count) * 100).rounded())
    }

    static let empty = BPSummary(
        count: 0, average: nil, averagePulse: nil, morning: nil, morningCount: 0,
        evening: nil, eveningCount: 0, inTargetCount: 0, highest: nil, daily: [],
        firstWeek: nil, lastSevenDays: nil, lastSevenDaysCount: 0, lastSevenDaysInTarget: 0
    )
}

struct TrendInsight: Equatable {
    enum Tone: Equatable { case good, warn, neutral }
    var text: String
    var tone: Tone
    var isImproving: Bool
}

enum BPStats {
    static func average(_ points: [ReadingPoint]) -> BPValue? {
        ReadingValidation.average(points.map(\.value))
    }

    static func dailyAverages(_ points: [ReadingPoint], calendar: Calendar = .current) -> [DailyAverage] {
        let groups = Dictionary(grouping: points) { calendar.startOfDay(for: $0.date) }
        return groups.map { day, items in
            let n = Double(items.count)
            return DailyAverage(
                day: day,
                systolic: Double(items.reduce(0) { $0 + $1.systolic }) / n,
                diastolic: Double(items.reduce(0) { $0 + $1.diastolic }) / n,
                count: items.count
            )
        }
        .sorted { $0.day < $1.day }
    }

    static func summarize(
        _ readings: [ReadingPoint],
        target: BPTarget,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> BPSummary {
        guard !readings.isEmpty else { return .empty }
        let sorted = readings.sorted { $0.date < $1.date }

        let morning = sorted.filter { $0.slot == .morning }
        let evening = sorted.filter { $0.slot.isEveningGroup }
        let inTarget = sorted.filter { target.isWithin(systolic: $0.systolic, diastolic: $0.diastolic) }
        let highest = sorted.max { lhs, rhs in
            if lhs.systolic != rhs.systolic { return lhs.systolic < rhs.systolic }
            return lhs.diastolic < rhs.diastolic
        }

        let startOfToday = calendar.startOfDay(for: now)
        let lastWeekStart = calendar.date(byAdding: .day, value: -6, to: startOfToday) ?? startOfToday
        let lastWeek = sorted.filter { $0.date >= lastWeekStart }

        var firstWeek: BPValue?
        if let first = sorted.first {
            let firstStart = calendar.startOfDay(for: first.date)
            if let firstEnd = calendar.date(byAdding: .day, value: 7, to: firstStart), firstEnd <= lastWeekStart {
                firstWeek = average(sorted.filter { $0.date < firstEnd })
            }
        }

        return BPSummary(
            count: sorted.count,
            average: average(sorted),
            averagePulse: ReadingValidation.averagePulse(sorted.compactMap(\.pulse)),
            morning: average(morning),
            morningCount: morning.count,
            evening: average(evening),
            eveningCount: evening.count,
            inTargetCount: inTarget.count,
            highest: highest,
            daily: dailyAverages(sorted, calendar: calendar),
            firstWeek: firstWeek,
            lastSevenDays: average(lastWeek),
            lastSevenDaysCount: lastWeek.count,
            lastSevenDaysInTarget: lastWeek.filter { target.isWithin(systolic: $0.systolic, diastolic: $0.diastolic) }.count
        )
    }

    /// A one-line, plain-language summary of how the last 7 days compare with the first week.
    static func insight(for summary: BPSummary, target: BPTarget) -> TrendInsight? {
        guard let last = summary.lastSevenDays else { return nil }
        let within = target.isWithin(last)
        let status = within ? "within target" : "above target"
        guard let first = summary.firstWeek else {
            return TrendInsight(
                text: "The last 7 days average \(last.text) — \(status).",
                tone: within ? .good : .warn,
                isImproving: false
            )
        }
        let ds = last.systolic - first.systolic
        let dd = last.diastolic - first.diastolic
        let change: String
        let improving: Bool
        if abs(ds) <= 2 && abs(dd) <= 2 {
            change = "About the same as the first week."
            improving = false
        } else if ds <= 0 && dd <= 0 {
            change = "Down \(abs(ds))/\(abs(dd)) since the first week."
            improving = true
        } else if ds >= 0 && dd >= 0 {
            change = "Up \(ds)/\(dd) since the first week."
            improving = false
        } else {
            let top = ds < 0 ? "down \(abs(ds))" : "up \(ds)"
            let bottom = dd < 0 ? "down \(abs(dd))" : "up \(dd)"
            change = "Top number \(top), bottom number \(bottom) since the first week."
            improving = ds < 0
        }
        return TrendInsight(
            text: "\(change) The last 7 days average \(last.text) — \(status).",
            tone: within ? .good : .warn,
            isImproving: improving
        )
    }
}
