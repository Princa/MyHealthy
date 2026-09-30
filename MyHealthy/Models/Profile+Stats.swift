import Foundation
import SwiftData

/// Time windows used by Trends and reports.
enum TrendRange: String, CaseIterable, Identifiable, Hashable {
    case week, month, quarter, year

    var id: String { rawValue }

    var label: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .quarter: return "3 Months"
        case .year: return "Year"
        }
    }

    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .year: return 365
        }
    }

    var averageTitle: String {
        switch self {
        case .week: return "7-day average"
        case .month: return "30-day average"
        case .quarter: return "90-day average"
        case .year: return "12-month average"
        }
    }

    /// First day included in the window (start of day), counting today as day one.
    func startDate(now: Date = Date(), calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today
    }
}

/// One scheduled dose for today, with its log if already taken.
struct TodayDose: Identifiable {
    let medication: Medication
    let scheduledAt: Date
    let log: DoseLog?

    var id: String { "\(medication.id.uuidString)-\(Int(scheduledAt.timeIntervalSince1970))" }
    var isTaken: Bool { log != nil }
}

extension Profile {
    func summary(for range: TrendRange, now: Date = Date()) -> BPSummary {
        BPStats.summarize(readingPoints(since: range.startDate(now: now)), target: target, now: now)
    }

    func adherence(from start: Date, to end: Date = Date(), now: Date = Date(), calendar: Calendar = .current) -> AdherenceSummary {
        let meds = medications ?? []
        guard !meds.isEmpty else { return .empty }
        let expected = Adherence.expectedDoses(meds.map(\.schedule), from: start, to: end, calendar: calendar)
        let taken = meds.reduce(into: Set<String>()) { result, medication in
            result.formUnion(medication.takenKeys)
        }
        var days: [Date] = []
        var day = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)
        while day <= last {
            days.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return Adherence.summarize(expected: expected, takenKeys: taken, days: days, now: now, calendar: calendar)
    }

    func todaysDoses(now: Date = Date(), calendar: Calendar = .current) -> [TodayDose] {
        activeMedications
            .flatMap { medication in
                medication.scheduleMinutes.compactMap { minutes -> TodayDose? in
                    guard let at = DoseClock.date(minutesOfDay: minutes, on: now, calendar: calendar) else { return nil }
                    return TodayDose(medication: medication, scheduledAt: at, log: medication.log(for: at))
                }
            }
            .sorted { ($0.scheduledAt, $0.medication.name) < ($1.scheduledAt, $1.medication.name) }
    }

    func dayReadings(_ day: Date, calendar: Calendar = .current) -> [BPReading] {
        (readings ?? []).filter { calendar.isDate($0.timestamp, inSameDayAs: day) }
    }
}

@MainActor
enum DoseActions {
    static func markTaken(_ medication: Medication, scheduledAt: Date, context: ModelContext) {
        guard medication.log(for: scheduledAt) == nil else { return }
        let log = DoseLog(scheduledAt: scheduledAt, takenAt: Date())
        context.insert(log)
        log.medication = medication
        if let pills = medication.pillsLeft {
            medication.pillsLeft = max(0, pills - 1)
        }
        try? context.save()
    }

    static func undo(_ medication: Medication, scheduledAt: Date, context: ModelContext) {
        guard let log = medication.log(for: scheduledAt) else { return }
        context.delete(log)
        if let pills = medication.pillsLeft {
            medication.pillsLeft = pills + 1
        }
        try? context.save()
    }
}
