import Charts
import SwiftUI

/// Daily average systolic (blue) and diastolic (orange) lines with dashed target lines.
struct BPTrendChart: View {
    let daily: [DailyAverage]
    let target: BPTarget
    /// Compact charts label every day with a weekday letter (for 7-day views).
    var compact = false
    var start: Date?
    var end: Date?

    var body: some View {
        Chart {
            RuleMark(y: .value("Target systolic", target.systolic))
                .foregroundStyle(Palette.systolic.opacity(0.45))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            RuleMark(y: .value("Target diastolic", target.diastolic))
                .foregroundStyle(Palette.diastolic.opacity(0.55))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

            ForEach(daily) { day in
                LineMark(
                    x: .value("Day", day.day, unit: .day),
                    y: .value("Systolic", day.systolic),
                    series: .value("Series", "Systolic")
                )
                .foregroundStyle(Palette.systolic)
                .lineStyle(StrokeStyle(lineWidth: compact ? 2.5 : 2.2, lineCap: .round, lineJoin: .round))

                LineMark(
                    x: .value("Day", day.day, unit: .day),
                    y: .value("Diastolic", day.diastolic),
                    series: .value("Series", "Diastolic")
                )
                .foregroundStyle(Palette.diastolic)
                .lineStyle(StrokeStyle(lineWidth: compact ? 2.5 : 2.2, lineCap: .round, lineJoin: .round))

                if showsPoint(day) {
                    PointMark(x: .value("Day", day.day, unit: .day), y: .value("Systolic", day.systolic))
                        .foregroundStyle(Palette.systolic)
                        .symbolSize(compact ? 30 : 36)
                    PointMark(x: .value("Day", day.day, unit: .day), y: .value("Diastolic", day.diastolic))
                        .foregroundStyle(Palette.diastolic)
                        .symbolSize(compact ? 30 : 36)
                }
            }
        }
        .chartYScale(domain: yDomain)
        .chartXScale(domain: xDomain)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: xStride)) { _ in
                AxisGridLine()
                AxisValueLabel(format: xFormat)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: yTicks) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartLegend(.hidden)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private func showsPoint(_ day: DailyAverage) -> Bool {
        compact || daily.count <= 10 || day.id == daily.last?.id
    }

    private var xDomain: ClosedRange<Date> {
        let calendar = Calendar.current
        let first = start ?? daily.first?.day ?? Date()
        let lastDay = end ?? daily.last?.day ?? Date()
        let low = calendar.startOfDay(for: first)
        let high = calendar.startOfDay(for: lastDay)
        return low...max(high, low.addingTimeInterval(86_400))
    }

    private var dayCount: Int {
        let days = Calendar.current.dateComponents([.day], from: xDomain.lowerBound, to: xDomain.upperBound).day ?? 0
        return max(days + 1, 1)
    }

    private var xStride: Int {
        switch dayCount {
        case ...8: return 1
        case ...31: return 7
        case ...95: return 21
        default: return 60
        }
    }

    private var xFormat: Date.FormatStyle {
        dayCount <= 8
            ? Date.FormatStyle().weekday(.narrow)
            : Date.FormatStyle().month(.abbreviated).day()
    }

    private var yDomain: ClosedRange<Int> {
        let low = min(daily.map { Int($0.diastolic.rounded(.down)) }.min() ?? target.diastolic, target.diastolic) - 10
        let high = max(daily.map { Int($0.systolic.rounded(.up)) }.max() ?? target.systolic, target.systolic) + 10
        let lower = (low / 10) * 10
        let upper = ((high + 9) / 10) * 10
        return lower...max(upper, lower + 20)
    }

    private var yTicks: [Int] {
        let range = yDomain
        let span = range.upperBound - range.lowerBound
        let step = span > 80 ? 40 : 20
        var ticks = Array(stride(from: range.lowerBound, through: range.upperBound, by: step))
        ticks.append(contentsOf: [target.systolic, target.diastolic])
        return Array(Set(ticks)).sorted()
    }

    private var accessibilitySummary: String {
        guard let first = daily.first, let last = daily.last else { return "No readings" }
        return "Blood pressure chart. Daily average went from \(Int(first.systolic.rounded())) over \(Int(first.diastolic.rounded())) to \(Int(last.systolic.rounded())) over \(Int(last.diastolic.rounded())). Target is below \(target.systolic) over \(target.diastolic)."
    }
}

struct BPChartLegend: View {
    let target: BPTarget

    var body: some View {
        HStack(spacing: 16) {
            LegendItem(color: Palette.systolic, label: "Systolic")
            LegendItem(color: Palette.diastolic, label: "Diastolic")
            LegendItem(color: .secondary, label: "Target \(target.text)", dashed: true)
        }
    }
}
