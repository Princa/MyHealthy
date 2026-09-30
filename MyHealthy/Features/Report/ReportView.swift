import SwiftUI

struct ReportView: View {
    let profile: Profile
    @State private var range: TrendRange
    @State private var options = ReportOptions()
    @State private var pdfURL: URL? = nil

    init(profile: Profile, range: TrendRange) {
        self.profile = profile
        _range = State(initialValue: range)
    }

    private struct RenderKey: Hashable {
        var range: TrendRange
        var options: ReportOptions
    }

    var body: some View {
        let data = ReportData.make(profile: profile, range: range, options: options)
        let pages = data.pages()

        return ScrollView {
            VStack(spacing: 14) {
                Card(spacing: 0) {
                    HStack {
                        Text("Period")
                        Spacer()
                        Picker("Period", selection: $range) {
                            ForEach(TrendRange.allCases) { item in
                                Text(item.label).tag(item)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .frame(minHeight: 44)
                    Text(Fmt.period(from: data.start, to: data.end))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 10)
                    Divider()
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Include")
                        FlowLayout(spacing: 8) {
                            ToggleChip(title: "Summary & chart", isOn: $options.summary)
                            ToggleChip(title: "Medications", isOn: $options.medications)
                            ToggleChip(title: "All readings", isOn: $options.readings)
                            ToggleChip(title: "Notes & tags", isOn: $options.notes)
                        }
                    }
                    .padding(.top, 12)
                }

                SectionHeader(title: pages.count == 1 ? "Preview · 1 page" : "Preview · \(pages.count) pages")

                GeometryReader { proxy in
                    let scale = proxy.size.width / ReportRenderer.pageSize.width
                    ReportPageView(data: data, page: pages[0], pageCount: pages.count)
                        .environment(\.colorScheme, .light)
                        .scaleEffect(scale, anchor: .topLeading)
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                }
                .aspectRatio(ReportRenderer.pageSize.width / ReportRenderer.pageSize.height, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Report preview, page 1 of \(pages.count)")

                HStack(spacing: 12) {
                    Button {
                        if let pdfURL { ReportRenderer.print(pdfURL) }
                    } label: {
                        Label("Print", systemImage: "printer")
                    }
                    .buttonStyle(SoftButtonStyle())
                    .disabled(pdfURL == nil)

                    if let pdfURL {
                        ShareLink(item: pdfURL, preview: SharePreview(data.fileName)) {
                            Label("Share PDF", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    } else {
                        Button {} label: {
                            ProgressView().tint(.white)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(true)
                    }
                }
            }
            .padding(Metrics.screenPadding)
        }
        .background(Palette.background)
        .navigationTitle("Doctor Report")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: RenderKey(range: range, options: options)) {
            await renderPDF()
        }
    }

    @MainActor
    private func renderPDF() async {
        pdfURL = nil
        // Let the preview update before the heavier PDF render.
        await Task.yield()
        pdfURL = ReportRenderer.render(ReportData.make(profile: profile, range: range, options: options))
    }
}
