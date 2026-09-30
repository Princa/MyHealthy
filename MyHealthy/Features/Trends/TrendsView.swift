import SwiftData
import SwiftUI

struct TrendsView: View {
    let profile: Profile
    @State private var range: TrendRange = .month

    var body: some View {
        let start = range.startDate()
        let summary = profile.summary(for: range)
        let insight = BPStats.insight(for: summary, target: profile.target)
        let adherence = profile.adherence(from: start)

        return NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Text("\(profile.displayName) · \(Fmt.period(from: start, to: Date()))".uppercased())
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)

                    Picker("Time range", selection: $range) {
                        ForEach(TrendRange.allCases) { item in
                            Text(item.label).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    if summary.count == 0 {
                        Card {
                            EmptyStateView(
                                systemImage: "chart.xyaxis.line",
                                title: "No readings in this period",
                                message: "Log readings from the Today tab. Averages, trends and reports will appear here."
                            )
                        }
                    } else {
                        summaryCard(summary, insight: insight)
                        chartCard(summary, start: start)
                        statsGrid(summary)
                    }

                    if adherence.due > 0 {
                        AdherenceCard(summary: adherence, compact: range.days > 31)
                    }

                    NavigationLink {
                        ReadingsListView(profile: profile)
                    } label: {
                        HStack {
                            Text("All readings")
                            Spacer()
                            Text("\((profile.readings ?? []).count)")
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Palette.chevron)
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 52)
                        .background(Palette.card, in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        ReportView(profile: profile, range: range)
                    } label: {
                        Label("Create Doctor Report", systemImage: "doc.text")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.bottom, 24)
            }
            .background(Palette.background)
            .navigationTitle("Trends")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ReportView(profile: profile, range: range)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share report")
                }
            }
        }
    }

    private func summaryCard(_ summary: BPSummary, insight: TrendInsight?) -> some View {
        Card(spacing: 10) {
            HStack {
                Text(range.averageTitle)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(summary.count == 1 ? "1 reading" : "\(summary.count) readings")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let average = summary.average {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    BPValueText(value: average, size: 48)
                    Text("mmHg")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let pulse = summary.averagePulse {
                        Text("Pulse \(pulse)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if let insight {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: insight.isImproving ? "arrow.down" : (insight.tone == .good ? "checkmark" : "arrow.up.right"))
                        .font(.subheadline.weight(.bold))
                        .accessibilityHidden(true)
                    Text(insight.text)
                        .font(.subheadline)
                }
                .foregroundStyle(insight.tone == .good ? Palette.good : Palette.warn)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    insight.tone == .good ? Palette.goodSoft : Palette.warnSoft,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
            }
        }
    }

    private func chartCard(_ summary: BPSummary, start: Date) -> some View {
        Card(spacing: 12) {
            HStack {
                Text("Blood pressure")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("Daily average")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            BPTrendChart(daily: summary.daily, target: profile.target, compact: range == .week, start: start, end: Date())
                .frame(height: 200)
            BPChartLegend(target: profile.target)
        }
    }

    private func statsGrid(_ summary: BPSummary) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            StatTile(
                icon: "sun.max",
                title: "Morning avg",
                value: summary.morning?.text ?? "—",
                caption: summary.morningCount == 1 ? "1 reading" : "\(summary.morningCount) readings"
            )
            StatTile(
                icon: "moon",
                title: "Evening avg",
                value: summary.evening?.text ?? "—",
                caption: summary.eveningCount == 1 ? "1 reading" : "\(summary.eveningCount) readings"
            )
            StatTile(
                icon: "target",
                title: "In target",
                value: summary.inTargetPercent.map { "\($0)%" } ?? "—",
                caption: inTargetCaption(summary)
            )
            StatTile(
                icon: "arrow.up",
                title: "Highest",
                value: summary.highest.map { $0.value.text } ?? "—",
                caption: summary.highest.map { "\(Fmt.monthDay($0.date)) · \($0.slot.label.lowercased())" } ?? ""
            )
        }
    }

    private func inTargetCaption(_ summary: BPSummary) -> String {
        var caption = "\(summary.inTargetCount) of \(summary.count)"
        if range != .week && summary.lastSevenDaysCount > 0 {
            caption += " · \(summary.lastSevenDaysInTarget) of \(summary.lastSevenDaysCount) this week"
        }
        return caption
    }
}

struct StatTile: View {
    let icon: String
    let title: String
    let value: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.bpNumber(26))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Calendar strip of days: blue = all doses taken, orange = a dose was missed, outline = today.
struct AdherenceCard: View {
    let summary: AdherenceSummary
    var compact = false

    var body: some View {
        Card(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Doses taken")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let percent = summary.percent {
                    Text("\(percent)%")
                        .font(.bpNumber(20))
                    Text("· \(summary.taken) of \(summary.due)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: compact ? 3 : 4), count: compact ? 30 : 15),
                spacing: compact ? 3 : 4
            ) {
                ForEach(summary.days) { day in
                    cell(day)
                        .frame(height: compact ? 8 : 18)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText)

            HStack(spacing: 14) {
                legend(color: Palette.fill, label: "All taken")
                legend(color: Palette.warnFill, stroke: Palette.diastolic, label: "Missed a dose")
                legend(color: .clear, stroke: Color(uiColor: .tertiaryLabel), label: "Today")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let insight = summary.insight {
                Text(insight)
                    .font(.subheadline)
            }
        }
    }

    @ViewBuilder
    private func cell(_ day: DayAdherence) -> some View {
        let shape = RoundedRectangle(cornerRadius: compact ? 2 : 4, style: .continuous)
        switch day.status {
        case .complete:
            shape.fill(Palette.fill)
        case .missed:
            shape.fill(Palette.warnFill).overlay(shape.strokeBorder(Palette.diastolic, lineWidth: compact ? 1 : 2))
        case .pending:
            shape.strokeBorder(Color(uiColor: .tertiaryLabel), lineWidth: 1.5)
        case .noDoses:
            shape.fill(Palette.chipBackground)
        }
    }

    private func legend(color: Color, stroke: Color? = nil, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(stroke ?? .clear, lineWidth: 1.5)
                )
                .frame(width: 12, height: 12)
            Text(label)
        }
    }

    private var accessibilityText: String {
        let missedDays = summary.days.filter { $0.status == .missed }.count
        return "\(summary.taken) of \(summary.due) doses taken. \(missedDays) days with a missed dose."
    }
}

struct ReadingsListView: View {
    @Environment(\.modelContext) private var context
    let profile: Profile

    private var groups: [(day: Date, readings: [BPReading])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: profile.sortedReadings) { calendar.startOfDay(for: $0.timestamp) }
        return grouped
            .map { (day: $0.key, readings: $0.value.sorted { $0.timestamp > $1.timestamp }) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        List {
            if groups.isEmpty {
                Text("No readings yet.")
                    .foregroundStyle(.secondary)
            }
            ForEach(groups, id: \.day) { group in
                Section(Fmt.weekdayMonthDay(group.day)) {
                    ForEach(group.readings) { reading in
                        ReadingRow(reading: reading, target: profile.target)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            context.delete(group.readings[index])
                        }
                        try? context.save()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("All Readings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ReadingRow: View {
    let reading: BPReading
    let target: BPTarget

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Fmt.time(reading.timestamp))
                    .font(.subheadline.weight(.medium))
                Text(reading.timeOfDay.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 76, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                BPValueText(value: reading.value, size: 22)
                let details = detailLine
                if !details.isEmpty {
                    Text(details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            Image(systemName: target.isWithin(reading.value) ? "checkmark.circle" : "arrow.up.circle")
                .foregroundStyle(target.isWithin(reading.value) ? Palette.good : Palette.warn)
                .accessibilityLabel(target.isWithin(reading.value) ? "Within target" : "Above target")
        }
        .padding(.vertical, 2)
    }

    private var detailLine: String {
        var parts: [String] = []
        if let pulse = reading.pulse { parts.append("Pulse \(pulse)") }
        if reading.measurementCount > 1 { parts.append("Avg of \(reading.measurementCount)") }
        let note = reading.noteLine
        if !note.isEmpty { parts.append(note) }
        return parts.joined(separator: " · ")
    }
}
