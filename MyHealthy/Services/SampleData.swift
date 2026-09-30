import Foundation
import SwiftData

/// Deterministic random numbers so the sample profile looks the same every time.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Creates a clearly labelled sample profile with four weeks of readings and doses,
/// so the dashboards can be explored before real data exists.
@MainActor
enum SampleData {
    @discardableResult
    static func insertSampleProfile(into context: ModelContext, now: Date = Date()) -> Profile {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let firstDay = calendar.date(byAdding: .day, value: -28, to: today) ?? today

        let profile = Profile(name: "Sample", colorIndex: 0)
        profile.birthDate = calendar.date(byAdding: .year, value: -48, to: today)
        profile.conditions = "High blood pressure"
        context.insert(profile)

        var rng = SeededGenerator(seed: 7)
        func noise(_ scale: Double) -> Double {
            // Sum of three uniforms ≈ normal distribution.
            let sum = (0..<3).reduce(0.0) { partial, _ in partial + Double.random(in: -1...1, using: &rng) }
            return sum * scale / 1.7
        }

        let slots: [(minutes: Int, slot: TimeOfDay, sys: Double, dia: Double)] = [
            (minutes: 465, slot: .morning, sys: 3, dia: 2),
            (minutes: 1205, slot: .evening, sys: -3, dia: -2)
        ]

        for offset in 0...28 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: firstDay) else { continue }
            let progress = Double(offset) / 28
            let baseSystolic = 142 - 15 * progress
            let baseDiastolic = 91 - 10 * progress
            for slot in slots {
                if slot.slot == .evening && offset % 7 == 4 { continue }
                let jitter = Int(rng.next() % 20)
                guard let time = DoseClock.date(minutesOfDay: slot.minutes + jitter, on: day, calendar: calendar),
                      time <= now else { continue }
                let systolic = Int((baseSystolic + slot.sys + noise(3.2)).rounded())
                let diastolic = Int((baseDiastolic + slot.dia + noise(2.2)).rounded())
                let pulse = Int((69 + noise(3)).rounded())
                let reading = BPReading(
                    timestamp: time,
                    systolic: systolic,
                    diastolic: diastolic,
                    pulse: pulse,
                    timeOfDay: slot.slot
                )
                context.insert(reading)
                reading.profile = profile
            }
        }

        let plan: [(name: String, strength: String, dose: String, minutes: Int)] = [
            (name: "Amlodipine", strength: "5 mg", dose: "1 tablet", minutes: 480),
            (name: "Ramipril", strength: "5 mg", dose: "1 capsule", minutes: 480),
            (name: "Rosuvastatin", strength: "10 mg", dose: "1 tablet", minutes: 1260)
        ]
        for item in plan {
            let info = MedicationLibrary.lookup(name: item.name)
            let medication = Medication(
                name: item.name,
                strength: item.strength,
                doseDescription: item.dose,
                purpose: info?.purpose ?? "",
                scheduleMinutes: [item.minutes]
            )
            medication.info = info
            medication.startDate = firstDay
            medication.pillsLeft = item.name == "Ramipril" ? 6 : 30
            context.insert(medication)
            medication.profile = profile

            for offset in 0...28 {
                guard let day = calendar.date(byAdding: .day, value: offset, to: firstDay),
                      let scheduled = DoseClock.date(minutesOfDay: item.minutes, on: day, calendar: calendar),
                      scheduled <= now else { continue }
                let isSunday = calendar.component(.weekday, from: day) == 1
                if isSunday && item.minutes >= 17 * 60 { continue }
                let log = DoseLog(scheduledAt: scheduled, takenAt: scheduled.addingTimeInterval(4 * 60))
                context.insert(log)
                log.medication = medication
            }
        }

        try? context.save()
        return profile
    }
}
