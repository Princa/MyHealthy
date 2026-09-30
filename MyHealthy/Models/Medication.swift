import Foundation
import SwiftData

/// A medication one profile takes, with its daily schedule and reference info.
@Model
final class Medication {
    var id: UUID = UUID()
    var name: String = ""
    var strength: String = ""
    var doseDescription: String = "1 tablet"
    var purpose: String = ""
    /// Minutes after midnight for each daily dose (480 = 8:00 AM).
    var scheduleMinutes: [Int] = [480]
    var remindersEnabled: Bool = true
    var pillsLeft: Int?
    var refillThreshold: Int = 7
    /// Doses are expected from this moment on (start of the day it was added).
    var startDate: Date = Date()
    var stoppedAt: Date?
    /// JSON-encoded `DrugInfo`.
    var infoData: Data?
    var createdAt: Date = Date()
    var profile: Profile?

    @Relationship(deleteRule: .cascade, inverse: \DoseLog.medication)
    var doses: [DoseLog]? = []

    init(name: String, strength: String, doseDescription: String, purpose: String, scheduleMinutes: [Int]) {
        self.name = name
        self.strength = strength
        self.doseDescription = doseDescription
        self.purpose = purpose
        self.scheduleMinutes = scheduleMinutes.sorted()
        self.startDate = Calendar.current.startOfDay(for: Date())
    }

    var isActive: Bool { stoppedAt == nil }

    var info: DrugInfo? {
        get {
            guard let infoData else { return nil }
            return try? JSONDecoder().decode(DrugInfo.self, from: infoData)
        }
        set {
            infoData = newValue.flatMap { try? JSONEncoder().encode($0) }
        }
    }

    /// "Amlodipine 5 mg"
    var displayName: String {
        strength.isEmpty ? name : "\(name) \(strength)"
    }

    var firstDoseMinutes: Int { scheduleMinutes.min() ?? 0 }

    var frequencyText: String {
        switch scheduleMinutes.count {
        case 0: return "As needed"
        case 1: return "Once daily"
        case 2: return "Twice daily"
        case 3: return "3 times daily"
        default: return "\(scheduleMinutes.count) times daily"
        }
    }

    /// "1 tablet daily · 8:00 AM"
    var scheduleText: String {
        let times = scheduleMinutes.sorted().map { Fmt.time(minutes: $0) }.joined(separator: ", ")
        let cadence = scheduleMinutes.count <= 1 ? "daily" : "\(scheduleMinutes.count)× daily"
        return times.isEmpty ? doseDescription : "\(doseDescription) \(cadence) · \(times)"
    }

    var needsRefill: Bool {
        guard let pillsLeft else { return false }
        return pillsLeft <= refillThreshold
    }

    var schedule: DoseSchedule {
        DoseSchedule(
            medicationID: id.uuidString,
            name: name,
            minutesOfDay: scheduleMinutes,
            start: startDate,
            end: stoppedAt
        )
    }

    var takenKeys: Set<String> {
        Set((doses ?? []).map { DoseKey.make(medicationID: id.uuidString, scheduledAt: $0.scheduledAt) })
    }

    func log(for scheduledAt: Date) -> DoseLog? {
        (doses ?? []).first { abs($0.scheduledAt.timeIntervalSince(scheduledAt)) < 1 }
    }
}

/// A dose marked as taken.
@Model
final class DoseLog {
    var id: UUID = UUID()
    var scheduledAt: Date = Date()
    var takenAt: Date = Date()
    var medication: Medication?

    init(scheduledAt: Date, takenAt: Date = Date()) {
        self.scheduledAt = scheduledAt
        self.takenAt = takenAt
    }
}
