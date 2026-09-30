import SwiftUI

/// One US Letter page (612 × 792 pt) of the doctor report. Always rendered light, like paper.
struct ReportPageView: View {
    let data: ReportData
    let page: ReportPage
    let pageCount: Int

    private let ink = Color(white: 0.11)
    private let muted = Color(white: 0.30)
    private let rule = Color(white: 0.82)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if page.isFirst {
                if data.options.summary {
                    summaryBlock
                }
                if data.options.medications {
                    medicationsBlock
                }
            }
            if data.options.readings {
                readingsBlock
            }
            Spacer(minLength: 0)
            footer
        }
        .padding(.horizontal, 44)
        .padding(.vertical, 40)
        .frame(width: 612, height: 792, alignment: .topLeading)
        .background(Color.white)
        .foregroundStyle(ink)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(page.isFirst ? "Home Blood Pressure Report" : "Home Blood Pressure Report (continued)")
                    .font(.system(size: page.isFirst ? 20 : 13, weight: .bold))
                Text(data.subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(muted)
                if page.isFirst && !data.doctorName.isEmpty {
                    Text("Prepared for \(data.doctorName)")
                        .font(.system(size: 10))
                        .foregroundStyle(muted)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Target")
                    .font(.system(size: 9))
                    .foregroundStyle(muted)
                Text("<\(data.target.text)")
                    .font(.system(size: 13, weight: .bold))
            }
        }
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            Rectangle().fill(ink).frame(height: 1.5)
        }
    }

    private var summaryBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                stat("Average", data.summary.average?.text ?? "—")
                stat("Morning", data.summary.morning?.text ?? "—")
                stat("Evening", data.summary.evening?.text ?? "—")
                stat("Last 7 days", data.summary.lastSevenDays?.text ?? "—")
                stat("In target", data.summary.inTargetPercent.map { "\($0)%" } ?? "—")
            }
            if !data.summary.daily.isEmpty {
                BPTrendChart(daily: data.summary.daily, target: data.target, start: data.start, end: data.end)
                    .frame(height: 150)
                HStack(spacing: 14) {
                    legend(Palette.systolic, "Systolic (daily avg)")
                    legend(Palette.diastolic, "Diastolic (daily avg)")
                    Text("Dashed lines: target \(data.target.text)")
                        .font(.system(size: 9))
                        .foregroundStyle(muted)
                }
            }
            if let highest = data.summary.highest {
                Text(highestLine(highest))
                    .font(.system(size: 10))
                    .foregroundStyle(muted)
            }
        }
    }

    private var medicationsBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                sectionTitle("Medications")
                Spacer()
                if let percent = data.adherence.percent {
                    Text("\(percent)% of doses taken (\(data.adherence.taken) of \(data.adherence.due))")
                        .font(.system(size: 10, weight: .semibold))
                }
            }
            if data.medications.isEmpty {
                Text("No medications recorded.")
                    .font(.system(size: 10))
                    .foregroundStyle(muted)
            }
            ForEach(data.medications) { medication in
                HStack {
                    Text(medication.name)
                        .frame(width: 220, alignment: .leading)
                    Text(medication.frequency)
                        .frame(width: 110, alignment: .leading)
                    Text(medication.times)
                    Spacer()
                }
                .font(.system(size: 10))
            }
            if let insight = data.adherence.insight, !data.adherence.missed.isEmpty {
                Text(insight)
                    .font(.system(size: 9))
                    .foregroundStyle(muted)
            }
        }
    }

    private var readingsBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("Readings")
                .padding(.bottom, 5)
            HStack(spacing: 0) {
                column("Date", width: 90, header: true)
                column("Time", width: 70, header: true)
                column("BP (mmHg)", width: 80, header: true)
                column("Pulse", width: 50, header: true)
                if data.options.notes {
                    column("Notes", width: nil, header: true)
                }
            }
            .padding(.vertical, 3)
            .overlay(alignment: .bottom) { Rectangle().fill(rule).frame(height: 1) }

            if page.rows.isEmpty {
                Text(page.isFirst ? "No readings in this period." : "")
                    .font(.system(size: 10))
                    .foregroundStyle(muted)
                    .padding(.top, 6)
            }
            ForEach(page.rows) { row in
                HStack(spacing: 0) {
                    column(Fmt.monthDay(row.date), width: 90)
                    column(Fmt.time(row.date), width: 70)
                    column(row.value.text, width: 80, bold: !data.target.isWithin(row.value))
                    column(row.pulse.map { "\($0)" } ?? "—", width: 50)
                    if data.options.notes {
                        column(row.note, width: nil)
                    }
                }
                .padding(.vertical, 2.5)
                .overlay(alignment: .bottom) { Rectangle().fill(rule.opacity(0.6)).frame(height: 0.5) }
            }
            if data.options.readings && data.rows.count > 0 {
                Text("Bold values are at or above the target.")
                    .font(.system(size: 8))
                    .foregroundStyle(muted)
                    .padding(.top, 5)
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("Generated by MyHealthy on \(Fmt.monthDayYear(Date())). Home readings; not a diagnosis.")
            Spacer()
            Text("Page \(page.id + 1) of \(pageCount)")
        }
        .font(.system(size: 8))
        .foregroundStyle(muted)
    }

    // MARK: Pieces

    private func highestLine(_ highest: ReadingPoint) -> String {
        let pulse = data.summary.averagePulse.map { String($0) } ?? "—"
        return "Highest: \(highest.value.text) on \(Fmt.monthDay(highest.date)), \(Fmt.time(highest.date)). Average pulse: \(pulse)."
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .kerning(0.4)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label.uppercased())
                .font(.system(size: 8))
                .foregroundStyle(muted)
            Text(value)
                .font(.system(size: 15, weight: .bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legend(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
        }
        .font(.system(size: 9))
        .foregroundStyle(muted)
    }

    @ViewBuilder
    private func column(_ text: String, width: CGFloat?, header: Bool = false, bold: Bool = false) -> some View {
        let label = Text(text)
            .font(.system(size: header ? 9 : 10, weight: header || bold ? .semibold : .regular))
            .foregroundStyle(header ? muted : ink)
            .lineLimit(1)
        if let width {
            label.frame(width: width, alignment: .leading)
        } else {
            label.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
