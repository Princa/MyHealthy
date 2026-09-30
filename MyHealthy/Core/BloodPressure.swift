import Foundation

/// A systolic/diastolic pair in mmHg.
struct BPValue: Equatable, Hashable, Codable {
    var systolic: Int
    var diastolic: Int

    var text: String { "\(systolic)/\(diastolic)" }
}

/// A per-profile home blood pressure target. Readings are "within target" when
/// both numbers are below the target values.
struct BPTarget: Equatable, Hashable, Codable {
    var systolic: Int
    var diastolic: Int

    /// Common threshold for home readings (Hypertension Canada uses 135/85).
    static let homeDefault = BPTarget(systolic: 135, diastolic: 85)

    func isWithin(systolic s: Int, diastolic d: Int) -> Bool {
        s < systolic && d < diastolic
    }

    func isWithin(_ value: BPValue) -> Bool {
        isWithin(systolic: value.systolic, diastolic: value.diastolic)
    }

    var text: String { "\(systolic)/\(diastolic)" }
}

/// When during the day a reading was taken.
enum TimeOfDay: String, CaseIterable, Codable, Identifiable {
    case morning, afternoon, evening, night

    var id: String { rawValue }

    var label: String {
        switch self {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .night: return "Night"
        }
    }

    /// Picks the slot from the clock time: 4–11 morning, 12–16 afternoon,
    /// 17–21 evening, otherwise night.
    static func from(_ date: Date, calendar: Calendar = .current) -> TimeOfDay {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 4..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<22: return .evening
        default: return .night
        }
    }

    /// Evening and night readings are grouped together when comparing
    /// morning against evening averages.
    var isEveningGroup: Bool { self == .evening || self == .night }
}

enum ReadingValidation {
    static let systolicRange = 60...260
    static let diastolicRange = 30...160
    static let pulseRange = 30...220

    /// Returns a short, user-facing problem description, or nil when the values are plausible.
    static func problem(systolic: Int?, diastolic: Int?, pulse: Int?) -> String? {
        guard let s = systolic, let d = diastolic else { return "Enter both blood pressure numbers." }
        if !systolicRange.contains(s) { return "Systolic (top) should be between 60 and 260." }
        if !diastolicRange.contains(d) { return "Diastolic (bottom) should be between 30 and 160." }
        if d >= s { return "The top number should be higher than the bottom number." }
        if let p = pulse, !pulseRange.contains(p) { return "Pulse should be between 30 and 220." }
        return nil
    }

    /// Readings at or above 180 systolic or 120 diastolic need prompt attention.
    static func isVeryHigh(_ value: BPValue) -> Bool {
        value.systolic >= 180 || value.diastolic >= 120
    }

    /// Averages several measurements taken in one sitting, rounding to whole numbers.
    static func average(_ values: [BPValue]) -> BPValue? {
        guard !values.isEmpty else { return nil }
        let n = Double(values.count)
        let s = Double(values.reduce(0) { $0 + $1.systolic }) / n
        let d = Double(values.reduce(0) { $0 + $1.diastolic }) / n
        return BPValue(systolic: Int(s.rounded()), diastolic: Int(d.rounded()))
    }

    static func averagePulse(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        return Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
    }
}
