import Foundation
import SwiftData

/// One night of sleep. `wakeTime` is nil while the person is still asleep
/// (started with "Going to Sleep" and not yet ended with "I'm Awake").
@Model
final class SleepLog {
    var id: UUID = UUID()
    var bedtime: Date = Date()
    var wakeTime: Date?
    var note: String = ""
    var createdAt: Date = Date()
    var profile: Profile?

    init(bedtime: Date, wakeTime: Date? = nil, note: String = "") {
        self.bedtime = bedtime
        self.wakeTime = wakeTime
        self.note = note
    }

    var isInProgress: Bool { wakeTime == nil }

    var duration: TimeInterval? {
        wakeTime.map { $0.timeIntervalSince(bedtime) }
    }

    var point: SleepPoint? {
        wakeTime.map { SleepPoint(bedtime: bedtime, wake: $0) }
    }

    var night: Date { SleepMath.night(of: bedtime) }

    /// "10:40 PM – 6:05 AM"
    var rangeText: String {
        guard let wakeTime else { return "Since \(Fmt.time(bedtime))" }
        return "\(Fmt.time(bedtime)) – \(Fmt.time(wakeTime))"
    }
}

@MainActor
enum SleepActions {
    static func startSleep(for profile: Profile, at date: Date = Date(), context: ModelContext) {
        guard profile.activeSleep == nil else { return }
        let log = SleepLog(bedtime: date)
        context.insert(log)
        log.profile = profile
        try? context.save()
    }

    /// Ends the sleep now. Returns false when "now" doesn't make a sensible
    /// entry (e.g. more than 20 hours later) so the caller can open the editor.
    @discardableResult
    static func wakeUp(_ log: SleepLog, at date: Date = Date(), context: ModelContext) -> Bool {
        guard SleepMath.problem(bedtime: log.bedtime, wake: date, now: date) == nil else { return false }
        log.wakeTime = date
        try? context.save()
        return true
    }

    static func delete(_ log: SleepLog, context: ModelContext) {
        context.delete(log)
        try? context.save()
    }
}
