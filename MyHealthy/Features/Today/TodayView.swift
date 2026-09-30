import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @AppStorage(AppKeys.activeProfileID) private var activeProfileID = ""
    let profile: Profile
    let profiles: [Profile]
    @Binding var tab: AppTab
    @State private var showingLog = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Text(Fmt.weekdayMonthDay(Date()).uppercased())
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)

                    latestCard

                    Button {
                        showingLog = true
                    } label: {
                        Label("Log Reading", systemImage: "plus")
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    medicationsCard
                    weekCard
                }
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.bottom, 24)
            }
            .background(Palette.background)
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    profileMenu
                }
            }
            .sheet(isPresented: $showingLog) {
                LogReadingView(profile: profile)
            }
        }
    }

    // MARK: Profile switcher

    private var profileMenu: some View {
        Menu {
            ForEach(profiles) { item in
                Button {
                    activeProfileID = item.id.uuidString
                } label: {
                    if item.id == profile.id {
                        Label(item.displayName, systemImage: "checkmark")
                    } else {
                        Text(item.displayName)
                    }
                }
            }
            Divider()
            Button {
                tab = .profiles
            } label: {
                Label("Manage Profiles", systemImage: "person.2")
            }
        } label: {
            AvatarView(initial: profile.initial, colorIndex: profile.colorIndex, size: 34)
        }
        .accessibilityLabel("Switch profile. Current profile: \(profile.displayName)")
    }

    // MARK: Latest reading

    private var latestCard: some View {
        Card(spacing: 10) {
            HStack {
                Text("Latest reading")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let reading = profile.latestReading {
                    Text(timeLabel(for: reading))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let reading = profile.latestReading {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    BPValueText(value: reading.value, size: 60)
                    Text("mmHg")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    StatusChip.forReading(reading.value, target: profile.target)
                    if let pulse = reading.pulse {
                        Text("Pulse \(pulse) bpm")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                if ReadingValidation.isVeryHigh(reading.value) {
                    VeryHighNotice()
                }
            } else {
                Text("No readings yet. Log the first one below.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let check = checkStatus {
                Divider()
                HStack(spacing: 10) {
                    Image(systemName: check.icon)
                        .frame(width: 20)
                        .accessibilityHidden(true)
                    Text(check.title)
                    Spacer()
                    Text(check.detail)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func timeLabel(for reading: BPReading) -> String {
        let when = Calendar.current.isDateInToday(reading.timestamp) ? Fmt.time(reading.timestamp) : Fmt.dayAndTime(reading.timestamp)
        return "\(reading.timeOfDay.label) · \(when)"
    }

    private struct CheckStatus {
        var icon: String
        var title: String
        var detail: String
    }

    private var checkStatus: CheckStatus? {
        let today = profile.dayReadings(Date())
        let hasMorning = today.contains { $0.timeOfDay == .morning }
        let hasEvening = today.contains { $0.timeOfDay.isEveningGroup }
        let nowMinutes = Fmt.minutes(from: Date())

        if profile.morningCheckEnabled && !hasMorning && nowMinutes < 12 * 60 {
            let due = nowMinutes >= profile.morningCheckMinutes
            return CheckStatus(
                icon: "sun.max",
                title: "Morning check",
                detail: due ? "Due now" : "Reminder at \(Fmt.time(minutes: profile.morningCheckMinutes))"
            )
        }
        if profile.eveningCheckEnabled {
            if hasEvening {
                return CheckStatus(icon: "checkmark.circle", title: "Evening check", detail: "Done")
            }
            let due = nowMinutes >= profile.eveningCheckMinutes
            return CheckStatus(
                icon: "moon",
                title: "Evening check",
                detail: due ? "Due now" : "Reminder at \(Fmt.time(minutes: profile.eveningCheckMinutes))"
            )
        }
        return nil
    }

    // MARK: Medications

    private var medicationsCard: some View {
        let doses = profile.todaysDoses()
        let takenCount = doses.filter(\.isTaken).count
        return Card(spacing: 0) {
            HStack {
                Text("Medications")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if !doses.isEmpty {
                    Text("\(takenCount) of \(doses.count) taken")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 6)

            if doses.isEmpty {
                Button {
                    tab = .meds
                } label: {
                    Label("Add medications to track doses", systemImage: "plus.circle")
                        .font(.subheadline)
                        .frame(minHeight: 44)
                }
            }

            ForEach(Array(doses.enumerated()), id: \.element.id) { index, dose in
                if index > 0 {
                    Divider().padding(.leading, 40)
                }
                DoseRow(
                    dose: dose,
                    onTake: { DoseActions.markTaken(dose.medication, scheduledAt: dose.scheduledAt, context: context) },
                    onUndo: { DoseActions.undo(dose.medication, scheduledAt: dose.scheduledAt, context: context) }
                )
            }
        }
    }

    // MARK: Last 7 days

    private var weekCard: some View {
        let start = TrendRange.week.startDate()
        let points = profile.readingPoints(since: start)
        let daily = BPStats.dailyAverages(points)
        let average = BPStats.average(points)
        return Card(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Last 7 days")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let average {
                    Button {
                        tab = .trends
                    } label: {
                        HStack(spacing: 3) {
                            Text("Avg")
                            Text(average.text)
                                .font(.bpNumber(15))
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                        }
                        .font(.subheadline)
                        .frame(minHeight: 32)
                    }
                    .accessibilityLabel("7-day average \(average.systolic) over \(average.diastolic). Open Trends.")
                }
            }
            if daily.isEmpty {
                Text("Readings from the last 7 days will show here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                BPTrendChart(daily: daily, target: profile.target, compact: true, start: start, end: Date())
                    .frame(height: 130)
                BPChartLegend(target: profile.target)
            }
        }
    }
}

struct DoseRow: View {
    let dose: TodayDose
    let onTake: () -> Void
    let onUndo: () -> Void

    var body: some View {
        let medication = dose.medication
        HStack(spacing: 12) {
            Button(action: dose.isTaken ? onUndo : onTake) {
                Image(systemName: dose.isTaken ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 28))
                    .foregroundStyle(dose.isTaken ? Palette.fill : Color(uiColor: .tertiaryLabel))
                    .frame(width: 44, height: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.trailing, -16)
            .accessibilityLabel(dose.isTaken ? "Mark \(medication.name) as not taken" : "Mark \(medication.name) as taken")

            VStack(alignment: .leading, spacing: 2) {
                Text(medication.displayName)
                    .font(.body.weight(.medium))
                Text("\(medication.doseDescription) · \(Fmt.time(dose.scheduledAt))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if let log = dose.log {
                Text("Taken \(Fmt.time(log.takenAt))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Button(action: onTake) {
                    Text("Take")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .frame(height: 32)
                        .background(Palette.tintSoft, in: Capsule())
                        .foregroundStyle(Palette.tint)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mark \(medication.name) as taken")
            }
        }
        .frame(minHeight: 64)
    }
}

struct VeryHighNotice: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Palette.warn)
                .accessibilityHidden(true)
            Text("Very high reading. Rest 5 minutes and measure again. If it stays this high, or you have chest pain, shortness of breath, weakness or trouble speaking, call 911.")
                .font(.footnote)
                .foregroundStyle(.primary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.warnSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
