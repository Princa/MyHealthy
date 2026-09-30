import SwiftData
import SwiftUI

/// All sleep entries for a profile, with 7- and 30-day averages.
struct SleepHistoryView: View {
    @Environment(\.modelContext) private var context
    let profile: Profile
    @State private var editing: SleepLog?
    @State private var showingNew = false

    var body: some View {
        let week = SleepStats.summarize(profile.sleepPoints(since: TrendRange.week.startDate()))
        let month = SleepStats.summarize(profile.sleepPoints(since: TrendRange.month.startDate()))
        let logs = profile.sortedSleepLogs

        List {
            if logs.isEmpty {
                EmptyStateView(
                    systemImage: "bed.double",
                    title: "No sleep logged",
                    message: "Tap Going to Sleep at bedtime and I’m Awake in the morning, or add a night by hand."
                )
                .listRowBackground(Color.clear)
            } else {
                Section("Averages") {
                    summaryRow("Last 7 days", week)
                    summaryRow("Last 30 days", month)
                    if let bed = month.usualBedtime, let wake = month.usualWake {
                        LabeledContent("Usual schedule", value: "\(Fmt.time(minutes: bed)) – \(Fmt.time(minutes: wake))")
                    }
                }

                Section("Nights") {
                    ForEach(logs) { log in
                        Button {
                            editing = log
                        } label: {
                            SleepRow(log: log)
                        }
                        .foregroundStyle(.primary)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            SleepActions.delete(logs[index], context: context)
                        }
                    }
                }
            }
        }
        .navigationTitle("Sleep")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingNew = true
                } label: {
                    Label("Log Sleep", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNew) {
            LogSleepView(profile: profile)
        }
        .sheet(item: $editing) { log in
            LogSleepView(profile: profile, log: log)
        }
    }

    private func summaryRow(_ title: String, _ summary: SleepSummary) -> some View {
        LabeledContent(title) {
            if let average = summary.averageDuration {
                Text("\(SleepMath.durationText(average)) avg · \(summary.nights) \(summary.nights == 1 ? "night" : "nights")")
            } else {
                Text("No nights")
            }
        }
    }
}

struct SleepRow: View {
    let log: SleepLog

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Fmt.weekdayMonthDay(log.night))
                    .font(.body.weight(.medium))
                Text(log.note.isEmpty ? log.rangeText : "\(log.rangeText) · \(log.note)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if let duration = log.duration {
                Text(SleepMath.durationText(duration))
                    .font(.bpNumber(20, weight: .semibold))
                    .foregroundStyle(Palette.sleep)
            }
        }
        .frame(minHeight: 44)
    }
}
