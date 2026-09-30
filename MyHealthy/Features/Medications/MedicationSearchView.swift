import SwiftUI

struct MedicationSearchView: View {
    let profile: Profile
    @State private var query = ""
    @State private var results: [DrugSearchResult] = []
    @State private var isSearchingOnline = false

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        List {
            if trimmedQuery.count < 2 {
                Section {
                    ForEach(MedicationLibrary.all, id: \.name) { info in
                        NavigationLink(value: MedicationRoute.add(.fromLibrary(info))) {
                            SearchResultRow(result: .fromLibrary(info))
                        }
                    }
                } header: {
                    Text("Common medications")
                }
            } else {
                Section {
                    ForEach(results) { result in
                        NavigationLink(value: MedicationRoute.add(result)) {
                            SearchResultRow(result: result)
                        }
                    }
                    if isSearchingOnline {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Searching online…")
                                .foregroundStyle(.secondary)
                        }
                    } else if results.isEmpty {
                        Text("No matches for “\(trimmedQuery)”.")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(results.isEmpty ? "Results" : "\(results.count) results")
                }
            }

            Section {
                NavigationLink(value: MedicationRoute.manual(trimmedQuery)) {
                    Label("Not listed? Add it manually", systemImage: "plus")
                        .foregroundStyle(Palette.tint)
                }
            } footer: {
                Label {
                    Text("Common medications are built in and work offline. Other names come from NLM RxNorm, plain-language descriptions from MedlinePlus, and dosing from U.S. FDA drug labels.")
                } icon: {
                    Image(systemName: "globe")
                }
                .font(.footnote)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Add Medication")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Medication name")
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .task(id: trimmedQuery) {
            await runSearch(trimmedQuery)
        }
    }

    @MainActor
    private func runSearch(_ term: String) async {
        guard term.count >= 2 else {
            results = []
            isSearchingOnline = false
            return
        }
        // Built-in matches appear instantly; online matches follow after a short pause.
        results = DrugInfoService.shared.libraryResults(term)
        isSearchingOnline = true
        do {
            try await Task.sleep(for: .milliseconds(350))
        } catch {
            return
        }
        let found = await DrugInfoService.shared.search(term)
        guard !Task.isCancelled else { return }
        results = found
        isSearchingOnline = false
    }
}

struct SearchResultRow: View {
    let result: DrugSearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(result.name)
                .font(.body)
            if !result.subtitle.isEmpty {
                Text(result.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if !result.tag.isEmpty {
                Text(result.tag)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .foregroundStyle(Palette.tintSoftText)
                    .background(Palette.tintSoft, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
}
