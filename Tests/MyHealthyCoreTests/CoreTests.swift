import XCTest
@testable import MyHealthyCore

final class BloodPressureTests: XCTestCase {
    var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()

    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute))!
    }

    func testTargetIsStrictlyBelow() {
        let target = BPTarget.homeDefault
        XCTAssertTrue(target.isWithin(systolic: 134, diastolic: 84))
        XCTAssertFalse(target.isWithin(systolic: 135, diastolic: 80))
        XCTAssertFalse(target.isWithin(systolic: 120, diastolic: 85))
    }

    func testTimeOfDaySlots() {
        XCTAssertEqual(TimeOfDay.from(date(29, 7, 45), calendar: calendar), .morning)
        XCTAssertEqual(TimeOfDay.from(date(29, 13), calendar: calendar), .afternoon)
        XCTAssertEqual(TimeOfDay.from(date(29, 20, 12), calendar: calendar), .evening)
        XCTAssertEqual(TimeOfDay.from(date(29, 23, 30), calendar: calendar), .night)
        XCTAssertEqual(TimeOfDay.from(date(29, 2), calendar: calendar), .night)
    }

    func testValidation() {
        XCTAssertNil(ReadingValidation.problem(systolic: 128, diastolic: 82, pulse: 68))
        XCTAssertNotNil(ReadingValidation.problem(systolic: 82, diastolic: 128, pulse: nil))
        XCTAssertNotNil(ReadingValidation.problem(systolic: 300, diastolic: 80, pulse: nil))
        XCTAssertNotNil(ReadingValidation.problem(systolic: nil, diastolic: 80, pulse: nil))
        XCTAssertNotNil(ReadingValidation.problem(systolic: 120, diastolic: 80, pulse: 10))
        XCTAssertTrue(ReadingValidation.isVeryHigh(BPValue(systolic: 182, diastolic: 100)))
        XCTAssertTrue(ReadingValidation.isVeryHigh(BPValue(systolic: 150, diastolic: 121)))
        XCTAssertFalse(ReadingValidation.isVeryHigh(BPValue(systolic: 179, diastolic: 119)))
    }

    func testAverageRounds() {
        let average = ReadingValidation.average([BPValue(systolic: 131, diastolic: 83), BPValue(systolic: 132, diastolic: 84)])
        XCTAssertEqual(average, BPValue(systolic: 132, diastolic: 84))
    }

    func testSummary() {
        let points = [
            ReadingPoint(date: date(1, 7), systolic: 142, diastolic: 91, pulse: 70, slot: .morning),
            ReadingPoint(date: date(1, 20), systolic: 138, diastolic: 88, pulse: 68, slot: .evening),
            ReadingPoint(date: date(3, 7), systolic: 148, diastolic: 94, pulse: 72, slot: .morning),
            ReadingPoint(date: date(28, 7), systolic: 131, diastolic: 82, pulse: 76, slot: .morning),
            ReadingPoint(date: date(28, 20), systolic: 126, diastolic: 78, pulse: 69, slot: .evening),
            ReadingPoint(date: date(29, 7), systolic: 128, diastolic: 82, pulse: 68, slot: .morning)
        ]
        let summary = BPStats.summarize(points, target: .homeDefault, now: date(29, 12), calendar: calendar)
        XCTAssertEqual(summary.count, 6)
        XCTAssertEqual(summary.morningCount, 4)
        XCTAssertEqual(summary.eveningCount, 2)
        XCTAssertEqual(summary.inTargetCount, 3)
        XCTAssertEqual(summary.highest?.systolic, 148)
        XCTAssertEqual(summary.lastSevenDaysCount, 3)
        XCTAssertEqual(summary.lastSevenDays, BPValue(systolic: 128, diastolic: 81))
        XCTAssertEqual(summary.firstWeek, BPValue(systolic: 143, diastolic: 91))
        XCTAssertEqual(summary.daily.count, 4)

        let insight = BPStats.insight(for: summary, target: .homeDefault)
        XCTAssertEqual(insight?.tone, .good)
        XCTAssertEqual(insight?.isImproving, true)
        XCTAssertEqual(insight?.text, "Down 15/10 since the first week. The last 7 days average 128/81 — within target.")
    }

    func testSummaryWithoutEnoughHistoryHasNoFirstWeek() {
        let points = [
            ReadingPoint(date: date(27, 7), systolic: 140, diastolic: 90, pulse: nil, slot: .morning),
            ReadingPoint(date: date(29, 7), systolic: 136, diastolic: 86, pulse: nil, slot: .morning)
        ]
        let summary = BPStats.summarize(points, target: .homeDefault, now: date(29, 12), calendar: calendar)
        XCTAssertNil(summary.firstWeek)
        XCTAssertEqual(BPStats.insight(for: summary, target: .homeDefault)?.text, "The last 7 days average 138/88 — above target.")
    }
}

final class AdherenceTests: XCTestCase {
    var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()

    func date(_ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute))!
    }

    func testMissedSundayEveningDose() {
        // Sep 19 2026 is a Saturday.
        let schedules = [
            DoseSchedule(medicationID: "a", name: "Amlodipine", minutesOfDay: [480], start: date(19), end: nil),
            DoseSchedule(medicationID: "b", name: "Rosuvastatin", minutesOfDay: [1260], start: date(19), end: nil)
        ]
        let now = date(21, 12)
        let expected = Adherence.expectedDoses(schedules, from: date(19), to: now, calendar: calendar)
        XCTAssertEqual(expected.count, 6)

        let taken: Set<String> = [
            DoseKey.make(medicationID: "a", scheduledAt: date(19, 8)),
            DoseKey.make(medicationID: "b", scheduledAt: date(19, 21)),
            DoseKey.make(medicationID: "a", scheduledAt: date(20, 8)),
            DoseKey.make(medicationID: "a", scheduledAt: date(21, 8))
        ]
        let summary = Adherence.summarize(
            expected: expected,
            takenKeys: taken,
            days: [date(19), date(20), date(21)],
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(summary.due, 5)
        XCTAssertEqual(summary.taken, 4)
        XCTAssertEqual(summary.percent, 80)
        XCTAssertEqual(summary.missed.count, 1)
        XCTAssertEqual(summary.days.map(\.status), [.complete, .missed, .pending])
        XCTAssertEqual(summary.insight, "Missed Sunday’s evening Rosuvastatin.")
    }

    func testStartAndStopBoundaries() {
        let schedule = DoseSchedule(medicationID: "a", name: "A", minutesOfDay: [480, 1200], start: date(19, 12), end: date(21, 9))
        let expected = Adherence.expectedDoses([schedule], from: date(19), to: date(22), calendar: calendar)
        // Sep 19: 20:00 only (8:00 is before start). Sep 20: both. Sep 21: 8:00 only (20:00 is after stop).
        XCTAssertEqual(expected.map(\.scheduledAt), [date(19, 20), date(20, 8), date(20, 20), date(21, 8)])
    }

    func testAllMissedOnSameWeekday() {
        let missed = [date(6, 21), date(13, 21), date(20, 21)].map {
            ExpectedDose(medicationID: "b", name: "Rosuvastatin", scheduledAt: $0)
        }
        let text = Adherence.insight(missed: missed, due: 80, calendar: calendar)
        XCTAssertEqual(text, "All 3 missed doses were on Sundays. An extra Sunday reminder may help.")
    }
}

final class DrugTextTests: XCTestCase {
    func testCleansLabelSection() {
        let raw = "2 DOSAGE AND ADMINISTRATION •Adult recommended starting dose: 5 mg once daily with maximum dose 10 mg once daily. ( 2.1 ) о Small, fragile, or elderly patients may be started on 2.5 mg once daily. ( 2.1 )"
        let cleaned = DrugText.cleanLabelSection(raw)
        XCTAssertTrue(cleaned.hasPrefix("Adult recommended starting dose: 5 mg once daily"), cleaned)
        XCTAssertFalse(cleaned.contains("( 2.1 )"))
        XCTAssertEqual(
            DrugText.firstSentences(cleaned, count: 1),
            "Adult recommended starting dose: 5 mg once daily with maximum dose 10 mg once daily."
        )
    }

    func testSentencesKeepDecimals() {
        let text = "Start at 2.5 mg daily. Increase to 5 mg. Maximum 10 mg."
        XCTAssertEqual(DrugText.firstSentences(text, count: 2), "Start at 2.5 mg daily. Increase to 5 mg.")
    }

    func testStrengths() {
        XCTAssertEqual(
            DrugText.strengths(from: "Tablets: 10 mg, 2.5 mg, 5 mg and 10 mg"),
            ["2.5 mg", "5 mg", "10 mg"]
        )
    }

    func testStripHTML() {
        XCTAssertEqual(
            DrugText.stripHTML("<p>Amlodipine treats high blood pressure &amp; angina.</p>"),
            "Amlodipine treats high blood pressure & angina."
        )
    }

    func testDisplayName() {
        XCTAssertEqual(DrugText.displayName("AMLODIPINE BESYLATE"), "Amlodipine besylate")
        XCTAssertEqual(DrugText.displayName("amlodipine"), "Amlodipine")
        XCTAssertEqual(DrugText.displayName("McNeil Brand"), "McNeil Brand")
    }

    func testLibrarySearch() {
        XCTAssertEqual(MedicationLibrary.search("norv").first?.name, "Amlodipine")
        XCTAssertEqual(MedicationLibrary.search("amlod").first?.name, "Amlodipine")
        XCTAssertEqual(MedicationLibrary.search("statin").map(\.name), ["Atorvastatin", "Rosuvastatin"])
        XCTAssertTrue(MedicationLibrary.search("x").isEmpty)
    }
}

final class SleepTests: XCTestCase {
    var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()

    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute))!
    }

    func testWakeRollsToNextDay() {
        XCTAssertEqual(SleepMath.wake(after: date(28, 22, 30), wakeMinutes: 390, calendar: calendar), date(29, 6, 30))
        XCTAssertEqual(SleepMath.wake(after: date(29, 0, 40), wakeMinutes: 420, calendar: calendar), date(29, 7))
        // A nap: same day.
        XCTAssertEqual(SleepMath.wake(after: date(29, 13), wakeMinutes: 14 * 60, calendar: calendar), date(29, 14))
    }

    func testNightOfAfterMidnightBedtime() {
        XCTAssertEqual(SleepMath.night(of: date(28, 22, 30), calendar: calendar), date(28, 0))
        XCTAssertEqual(SleepMath.night(of: date(29, 0, 40), calendar: calendar), date(28, 0))
    }

    func testProblems() {
        let now = date(29, 9)
        XCTAssertNil(SleepMath.problem(bedtime: date(28, 23), wake: date(29, 7), now: now))
        XCTAssertNotNil(SleepMath.problem(bedtime: date(29, 7), wake: date(29, 7), now: now))
        XCTAssertNotNil(SleepMath.problem(bedtime: date(27, 23), wake: date(29, 7), now: now))
        XCTAssertNotNil(SleepMath.problem(bedtime: date(29, 1), wake: date(29, 10), now: now))
    }

    func testDurationText() {
        XCTAssertEqual(SleepMath.durationText(7 * 3600 + 20 * 60), "7h 20m")
        XCTAssertEqual(SleepMath.durationText(8 * 3600), "8h")
        XCTAssertEqual(SleepMath.durationText(45 * 60), "45m")
    }

    func testSummaryAveragesAcrossMidnight() {
        let points = [
            SleepPoint(bedtime: date(27, 23, 30), wake: date(28, 7)),   // 7h 30m
            SleepPoint(bedtime: date(29, 0, 30), wake: date(29, 7)),    // 6h 30m
        ]
        let summary = SleepStats.summarize(points, calendar: calendar)
        XCTAssertEqual(summary.nights, 2)
        XCTAssertEqual(summary.averageDuration, 7 * 3600)
        XCTAssertEqual(summary.usualBedtime, 0)        // midnight, not noon
        XCTAssertEqual(summary.usualWake, 7 * 60)
    }
}
