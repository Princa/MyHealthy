import Foundation
import SwiftData

enum Arm: String, CaseIterable, Identifiable, Codable {
    case left, right

    var id: String { rawValue }
    var label: String { self == .left ? "Left" : "Right" }
}

enum BodyPosition: String, CaseIterable, Identifiable, Codable {
    case sitting, standing, lying

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sitting: return "Sitting"
        case .standing: return "Standing"
        case .lying: return "Lying down"
        }
    }
}

enum ReadingTag: String, CaseIterable, Identifiable, Codable {
    case afterCoffee, afterExercise, stressed, feltDizzy, missedDose

    var id: String { rawValue }

    var label: String {
        switch self {
        case .afterCoffee: return "After coffee"
        case .afterExercise: return "After exercise"
        case .stressed: return "Stressed"
        case .feltDizzy: return "Felt dizzy"
        case .missedDose: return "Missed a dose"
        }
    }
}

/// One saved blood pressure reading. When two measurements are taken in one
/// sitting, the saved values are their average and `measurementCount` is 2.
@Model
final class BPReading {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var systolic: Int = 0
    var diastolic: Int = 0
    var pulse: Int?
    var timeOfDayRaw: String = TimeOfDay.morning.rawValue
    var armRaw: String = Arm.left.rawValue
    var positionRaw: String = BodyPosition.sitting.rawValue
    var tags: [String] = []
    var note: String = ""
    var measurementCount: Int = 1
    var profile: Profile?

    init(
        timestamp: Date,
        systolic: Int,
        diastolic: Int,
        pulse: Int?,
        timeOfDay: TimeOfDay,
        arm: Arm = .left,
        position: BodyPosition = .sitting,
        tags: [ReadingTag] = [],
        note: String = "",
        measurementCount: Int = 1
    ) {
        self.timestamp = timestamp
        self.systolic = systolic
        self.diastolic = diastolic
        self.pulse = pulse
        self.timeOfDayRaw = timeOfDay.rawValue
        self.armRaw = arm.rawValue
        self.positionRaw = position.rawValue
        self.tags = tags.map(\.rawValue)
        self.note = note
        self.measurementCount = measurementCount
    }

    var timeOfDay: TimeOfDay {
        get { TimeOfDay(rawValue: timeOfDayRaw) ?? .from(timestamp) }
        set { timeOfDayRaw = newValue.rawValue }
    }

    var arm: Arm { Arm(rawValue: armRaw) ?? .left }
    var position: BodyPosition { BodyPosition(rawValue: positionRaw) ?? .sitting }

    var value: BPValue { BPValue(systolic: systolic, diastolic: diastolic) }

    var point: ReadingPoint {
        ReadingPoint(date: timestamp, systolic: systolic, diastolic: diastolic, pulse: pulse, slot: timeOfDay)
    }

    var tagLabels: [String] {
        tags.compactMap { ReadingTag(rawValue: $0)?.label }
    }

    /// Tags and note in one line, for lists and reports.
    var noteLine: String {
        var parts = tagLabels
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { parts.append(trimmed) }
        return parts.joined(separator: " · ")
    }
}
