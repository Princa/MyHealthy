import Foundation
import SwiftData

enum Sex: String, CaseIterable, Identifiable, Codable {
    case female, male, other, unspecified

    var id: String { rawValue }

    var label: String {
        switch self {
        case .female: return "Female"
        case .male: return "Male"
        case .other: return "Other"
        case .unspecified: return "Prefer not to say"
        }
    }
}

/// One person being tracked. Each profile keeps its own readings, medications and reports.
@Model
final class Profile {
    var id: UUID = UUID()
    var name: String = ""
    var birthDate: Date?
    var sexRaw: String = Sex.unspecified.rawValue
    var heightCm: Double?
    var weightKg: Double?
    var conditions: String = ""
    var targetSystolic: Int = 135
    var targetDiastolic: Int = 85
    var doctorName: String = ""
    var colorIndex: Int = 0
    var morningCheckEnabled: Bool = true
    /// Minutes after midnight (450 = 7:30 AM).
    var morningCheckMinutes: Int = 450
    var eveningCheckEnabled: Bool = true
    /// Minutes after midnight (1200 = 8:00 PM).
    var eveningCheckMinutes: Int = 1200
    var bedtimeReminderEnabled: Bool = false
    /// Minutes after midnight (1350 = 10:30 PM).
    var bedtimeMinutes: Int = 1350
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \BPReading.profile)
    var readings: [BPReading]? = []

    @Relationship(deleteRule: .cascade, inverse: \Medication.profile)
    var medications: [Medication]? = []

    @Relationship(deleteRule: .cascade, inverse: \SleepLog.profile)
    var sleepLogs: [SleepLog]? = []

    init(name: String, colorIndex: Int = 0) {
        self.name = name
        self.colorIndex = colorIndex
    }

    var sex: Sex {
        get { Sex(rawValue: sexRaw) ?? .unspecified }
        set { sexRaw = newValue.rawValue }
    }

    var target: BPTarget {
        BPTarget(systolic: targetSystolic, diastolic: targetDiastolic)
    }

    var age: Int? {
        guard let birthDate else { return nil }
        return Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year
    }

    var initial: String {
        String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased()
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Unnamed" : trimmed
    }

    /// Newest first.
    var sortedReadings: [BPReading] {
        (readings ?? []).sorted { $0.timestamp > $1.timestamp }
    }

    var latestReading: BPReading? {
        (readings ?? []).max { $0.timestamp < $1.timestamp }
    }

    var activeMedications: [Medication] {
        (medications ?? [])
            .filter { $0.isActive }
            .sorted { ($0.firstDoseMinutes, $0.name) < ($1.firstDoseMinutes, $1.name) }
    }

    var pastMedications: [Medication] {
        (medications ?? [])
            .filter { !$0.isActive }
            .sorted { ($0.stoppedAt ?? .distantPast) > ($1.stoppedAt ?? .distantPast) }
    }

    /// Finished sleeps, newest first.
    var sortedSleepLogs: [SleepLog] {
        (sleepLogs ?? []).filter { !$0.isInProgress }.sorted { $0.bedtime > $1.bedtime }
    }

    /// The sleep started with "Going to Sleep" that hasn't ended yet.
    var activeSleep: SleepLog? {
        (sleepLogs ?? []).filter(\.isInProgress).max { $0.bedtime < $1.bedtime }
    }

    var lastSleep: SleepLog? { sortedSleepLogs.first }

    /// Finished sleeps whose night is on or after `start`.
    func sleepPoints(since start: Date? = nil) -> [SleepPoint] {
        (sleepLogs ?? []).compactMap { log in
            if let start, log.night < start { return nil }
            return log.point
        }
    }

    /// Readings as plain values for statistics, optionally limited to those on or after `start`.
    func readingPoints(since start: Date? = nil) -> [ReadingPoint] {
        (readings ?? [])
            .filter { reading in
                guard let start else { return true }
                return reading.timestamp >= start
            }
            .map(\.point)
    }

    /// Short summary line, e.g. "Age 48 · 3 medications".
    var summaryLine: String {
        var parts: [String] = []
        if let age { parts.append("Age \(age)") }
        let count = activeMedications.count
        parts.append(count == 1 ? "1 medication" : "\(count) medications")
        return parts.joined(separator: " · ")
    }
}
