import Foundation
import SwiftUI
import UIKit

struct ReportOptions: Hashable {
    var summary = true
    var medications = true
    var readings = true
    var notes = false
}

struct ReportRow: Identifiable, Hashable {
    let id: UUID
    let date: Date
    let value: BPValue
    let pulse: Int?
    let note: String
}

struct ReportMedication: Identifiable, Hashable {
    let id: UUID
    let name: String
    let frequency: String
    let times: String
}

struct ReportPage: Identifiable {
    let id: Int
    let rows: [ReportRow]
    var isFirst: Bool { id == 0 }
}

/// Everything a doctor report needs, as plain values.
struct ReportData {
    var profileName: String
    var age: Int?
    var doctorName: String
    var target: BPTarget
    var start: Date
    var end: Date
    var summary: BPSummary
    var adherence: AdherenceSummary
    var medications: [ReportMedication]
    var rows: [ReportRow]
    var options: ReportOptions

    @MainActor
    static func make(profile: Profile, range: TrendRange, options: ReportOptions, now: Date = Date()) -> ReportData {
        let start = range.startDate(now: now)
        let readings = (profile.readings ?? [])
            .filter { $0.timestamp >= start }
            .sorted { $0.timestamp > $1.timestamp }
        let medications = (profile.medications ?? [])
            .filter { medication in
                guard let stopped = medication.stoppedAt else { return true }
                return stopped >= start
            }
            .sorted { $0.name < $1.name }
            .map { medication in
                ReportMedication(
                    id: medication.id,
                    name: medication.displayName + (medication.isActive ? "" : " (stopped)"),
                    frequency: medication.frequencyText,
                    times: medication.scheduleMinutes.sorted().map { Fmt.time(minutes: $0) }.joined(separator: ", ")
                )
            }
        return ReportData(
            profileName: profile.displayName,
            age: profile.age,
            doctorName: profile.doctorName,
            target: profile.target,
            start: start,
            end: now,
            summary: BPStats.summarize(readings.map(\.point), target: profile.target, now: now),
            adherence: profile.adherence(from: start, to: now, now: now),
            medications: medications,
            rows: readings.map { reading in
                ReportRow(
                    id: reading.id,
                    date: reading.timestamp,
                    value: reading.value,
                    pulse: reading.pulse,
                    note: reading.noteLine
                )
            },
            options: options
        )
    }

    var subtitle: String {
        var parts = [profileName]
        if let age { parts.append("Age \(age)") }
        parts.append(Fmt.period(from: start, to: end))
        parts.append(summary.count == 1 ? "1 home reading" : "\(summary.count) home readings")
        return parts.joined(separator: " · ")
    }

    /// Splits readings across US Letter pages.
    func pages() -> [ReportPage] {
        let rows = options.readings ? self.rows : []
        var firstCapacity = 34
        if options.summary { firstCapacity -= 14 }
        if options.medications { firstCapacity -= 3 + max(medications.count, 1) }
        firstCapacity = max(firstCapacity, 6)
        let laterCapacity = 40

        var pages = [ReportPage(id: 0, rows: Array(rows.prefix(firstCapacity)))]
        var index = firstCapacity
        while index < rows.count {
            let end = min(index + laterCapacity, rows.count)
            pages.append(ReportPage(id: pages.count, rows: Array(rows[index..<end])))
            index = end
        }
        return pages
    }

    var fileName: String {
        let safeName = profileName.replacingOccurrences(of: "/", with: "-")
        return "Blood Pressure Report - \(safeName) - \(Fmt.monthDayYear(end)).pdf"
    }
}

@MainActor
enum ReportRenderer {
    static let pageSize = CGSize(width: 612, height: 792)

    /// Renders every page into a PDF in the temporary folder and returns its URL.
    static func render(_ data: ReportData) -> URL? {
        let pages = data.pages()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(data.fileName)
        try? FileManager.default.removeItem(at: url)
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let pdf = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else { return nil }
        for page in pages {
            let content = ReportPageView(data: data, page: page, pageCount: pages.count)
                .environment(\.colorScheme, .light)
            let renderer = ImageRenderer(content: content)
            renderer.proposedSize = ProposedViewSize(pageSize)
            renderer.render { _, draw in
                pdf.beginPDFPage(nil)
                draw(pdf)
                pdf.endPDFPage()
            }
        }
        pdf.closePDF()
        return url
    }

    static func print(_ url: URL) {
        let controller = UIPrintInteractionController.shared
        let info = UIPrintInfo(dictionary: nil)
        info.outputType = .general
        info.jobName = url.deletingPathExtension().lastPathComponent
        controller.printInfo = info
        controller.printingItem = url
        _ = controller.present(animated: true)
    }
}
