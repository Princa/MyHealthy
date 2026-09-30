import SwiftData
import SwiftUI

/// The editable schedule part of a medication.
struct MedicationDraft: Equatable {
    var name = ""
    var strength = ""
    var dose = "1 tablet"
    var purpose = ""
    var times: [Date] = [Fmt.date(fromMinutes: 480)]
    var reminders = true
    var tracksPills = false
    var pillsLeft = 30
    var refillThreshold = 7

    static let defaultTimes: [Int: [Int]] = [1: [480], 2: [480, 1200], 3: [480, 840, 1200]]

    init() {}

    init(info: DrugInfo) {
        name = info.name
        purpose = info.purpose
        let strengths = info.strengths
        strength = strengths.count > 1 ? strengths[1] : (strengths.first ?? "")
        dose = info.form == "capsule" ? "1 capsule" : (info.form == "liquid" ? "1 dose" : "1 tablet")
    }

    init(medication: Medication) {
        name = medication.name
        strength = medication.strength
        dose = medication.doseDescription
        purpose = medication.purpose
        times = medication.scheduleMinutes.sorted().map(Fmt.date(fromMinutes:))
        reminders = medication.remindersEnabled
        tracksPills = medication.pillsLeft != nil
        pillsLeft = medication.pillsLeft ?? 30
        refillThreshold = medication.refillThreshold
    }

    var timesPerDay: Int {
        get { times.count }
        set {
            let minutes = Self.defaultTimes[newValue] ?? [480]
            times = minutes.map(Fmt.date(fromMinutes:))
        }
    }

    var scheduleMinutes: [Int] {
        Array(Set(times.map { Fmt.minutes(from: $0) })).sorted()
    }

    func apply(to medication: Medication) {
        medication.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        medication.strength = strength.trimmingCharacters(in: .whitespacesAndNewlines)
        medication.doseDescription = dose.trimmingCharacters(in: .whitespacesAndNewlines)
        medication.purpose = purpose.trimmingCharacters(in: .whitespacesAndNewlines)
        medication.scheduleMinutes = scheduleMinutes
        medication.remindersEnabled = reminders
        medication.pillsLeft = tracksPills ? pillsLeft : nil
        medication.refillThreshold = refillThreshold
    }
}

struct MedicationInfoView: View {
    enum Mode {
        case add(DrugSearchResult)
        case manual(String)
        case existing(Medication)
    }

    @Environment(\.modelContext) private var context
    let mode: Mode
    let profile: Profile
    var onDone: () -> Void

    @State private var info: DrugInfo? = nil
    @State private var draft = MedicationDraft()
    @State private var isLoading = false
    @State private var loadError: String? = nil
    @State private var didSetUp = false
    @State private var confirmingDelete = false

    private var isExisting: Bool {
        if case .existing = mode { return true }
        return false
    }

    private var existingMedication: Medication? {
        if case let .existing(medication) = mode { return medication }
        return nil
    }

    private var isManual: Bool {
        if case .manual = mode { return true }
        return info?.isCurated == false && info?.hasReferenceText == false
    }

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !draft.times.isEmpty
    }

    var body: some View {
        List {
            headerSection
            if isLoading {
                Section {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Loading reference information…")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if let loadError {
                Section {
                    Text(loadError)
                        .foregroundStyle(.secondary)
                    Button("Try Again") {
                        Task { await loadDetails() }
                    }
                }
            }
            if let info, info.hasReferenceText {
                referenceSections(info)
            }
            scheduleSection
            if let medication = existingMedication {
                manageSection(medication)
            } else {
                Section {
                    Button {
                        add()
                    } label: {
                        Text("Add to \(profile.displayName)’s Medications")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canSave)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(isExisting ? draft.name : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(isExisting ? "Save" : "Add") {
                    if isExisting { saveExisting() } else { add() }
                }
                .fontWeight(.semibold)
                .disabled(!canSave)
            }
        }
        .confirmationDialog(
            "Delete \(draft.name)?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Medication and Dose History", role: .destructive) {
                deleteExisting()
            }
        } message: {
            Text("To keep its history in reports, choose Stop Taking instead.")
        }
        .task {
            guard !didSetUp else { return }
            didSetUp = true
            await setUp()
        }
    }

    // MARK: Sections

    private var headerSection: some View {
        Section {
            HStack(spacing: 14) {
                MedicationTile(purpose: draft.purpose.isEmpty ? (info?.purpose ?? "") : draft.purpose, size: 60)
                VStack(alignment: .leading, spacing: 4) {
                    Text(draft.name.isEmpty ? "New medication" : draft.name)
                        .font(.title2.bold())
                    if let brand = info?.brandLine, !brand.isEmpty {
                        Text(brand)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            let tags = [info?.drugClass ?? "", draft.purpose].filter { !$0.isEmpty }
            if !tags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .foregroundStyle(Palette.tintSoftText)
                            .background(Palette.tintSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
    }

    @ViewBuilder
    private func referenceSections(_ info: DrugInfo) -> some View {
        if !info.whatItsFor.isEmpty || !info.howItWorks.isEmpty {
            Section {
                if !info.whatItsFor.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("What it’s for").font(.subheadline.weight(.semibold))
                        Text(info.whatItsFor).font(.subheadline)
                    }
                    .padding(.vertical, 4)
                }
                if !info.howItWorks.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("How it works").font(.subheadline.weight(.semibold))
                        Text(info.howItWorks).font(.subheadline)
                    }
                    .padding(.vertical, 4)
                }
            }
        }

        if !info.doseLines.isEmpty || !info.doseNote.isEmpty {
            Section {
                ForEach(info.doseLines, id: \.self) { line in
                    LabeledContent(line.label) {
                        Text(line.value)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.trailing)
                    }
                    .font(.subheadline)
                }
                if !info.doseNote.isEmpty {
                    Text(info.doseNote)
                        .font(.subheadline)
                }
            } header: {
                Text("Typical adult dose")
            } footer: {
                Text("General reference, not medical advice. Always take the dose on your prescription label.")
            }
        }

        if !info.howToTake.isEmpty {
            Section("How to take it") {
                ForEach(info.howToTake, id: \.self) { line in
                    Label {
                        Text(line).font(.subheadline)
                    } icon: {
                        Image(systemName: icon(forHowTo: line))
                            .foregroundStyle(Palette.tint)
                    }
                }
            }
        }

        if !info.commonSideEffects.isEmpty || !info.sideEffectsNote.isEmpty || !info.urgentWarning.isEmpty {
            Section("Possible side effects") {
                if !info.commonSideEffects.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(info.commonSideEffects, id: \.self) { effect in
                            Text(effect)
                                .font(.subheadline)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Palette.chipBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                    .padding(.vertical, 4)
                }
                if !info.sideEffectsNote.isEmpty {
                    Text(info.sideEffectsNote)
                        .font(.subheadline)
                }
                if !info.urgentWarning.isEmpty {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Palette.warn)
                            .accessibilityHidden(true)
                        Text(info.urgentWarning)
                            .font(.subheadline)
                    }
                    .listRowBackground(Palette.warnSoft)
                }
            }
        }

        if let link = info.sourceURL, let url = URL(string: link) {
            Section {
                Link(destination: url) {
                    HStack(spacing: 12) {
                        Image(systemName: "globe")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Source: \(info.sourceName)")
                                .foregroundStyle(.primary)
                            Text(sourceCaption(info))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                    }
                }
            }
        }
    }

    private var scheduleSection: some View {
        Section {
            if isManual || isExisting {
                LabeledContent("Name") {
                    TextField("Medication name", text: $draft.name)
                        .multilineTextAlignment(.trailing)
                }
            }
            if let strengths = info?.strengths, !strengths.isEmpty {
                Picker("Strength", selection: $draft.strength) {
                    ForEach(strengthOptions(strengths), id: \.self) { value in
                        Text(value).tag(value)
                    }
                }
            } else {
                LabeledContent("Strength") {
                    TextField("e.g. 5 mg", text: $draft.strength)
                        .multilineTextAlignment(.trailing)
                }
            }
            LabeledContent("Dose") {
                TextField("e.g. 1 tablet", text: $draft.dose)
                    .multilineTextAlignment(.trailing)
            }
            Picker("How often", selection: $draft.timesPerDay) {
                Text("Once daily").tag(1)
                Text("Twice daily").tag(2)
                Text("3 times daily").tag(3)
            }
            ForEach(draft.times.indices, id: \.self) { index in
                DatePicker(
                    draft.times.count == 1 ? "Time" : "Dose \(index + 1)",
                    selection: $draft.times[index],
                    displayedComponents: .hourAndMinute
                )
            }
            Toggle("Reminders", isOn: $draft.reminders)
            Toggle("Track pills left", isOn: $draft.tracksPills)
            if draft.tracksPills {
                Stepper("Pills left: \(draft.pillsLeft)", value: $draft.pillsLeft, in: 0...999)
                Stepper("Refill reminder at \(draft.refillThreshold)", value: $draft.refillThreshold, in: 1...60)
            }
            LabeledContent("Taking it for") {
                TextField("e.g. Blood pressure", text: $draft.purpose)
                    .multilineTextAlignment(.trailing)
            }
        } header: {
            Text("\(profile.displayName)’s schedule")
        }
    }

    private func manageSection(_ medication: Medication) -> some View {
        Section {
            if medication.isActive {
                Button("Stop Taking") {
                    medication.stoppedAt = Date()
                    try? context.save()
                    ReminderScheduler.sync(context)
                    onDone()
                }
            } else {
                Button("Start Taking Again") {
                    medication.stoppedAt = nil
                    medication.startDate = Calendar.current.startOfDay(for: Date())
                    try? context.save()
                    ReminderScheduler.sync(context)
                    onDone()
                }
            }
            Button("Delete Medication", role: .destructive) {
                confirmingDelete = true
            }
        } footer: {
            if let stopped = medication.stoppedAt {
                Text("Stopped \(Fmt.monthDayYear(stopped)). Past doses stay in reports.")
            } else {
                Text("Added \(Fmt.monthDayYear(medication.createdAt)).")
            }
        }
    }

    // MARK: Helpers

    private func strengthOptions(_ strengths: [String]) -> [String] {
        var options = strengths
        if !draft.strength.isEmpty && !options.contains(draft.strength) {
            options.insert(draft.strength, at: 0)
        }
        return options
    }

    private func icon(forHowTo line: String) -> String {
        let lower = line.lowercased()
        if lower.hasPrefix("missed") { return "bell" }
        if lower.contains("food") { return "fork.knife" }
        if lower.contains("potassium") || lower.contains("ask") { return "exclamationmark.circle" }
        return "clock"
    }

    private func sourceCaption(_ info: DrugInfo) -> String {
        if let date = info.retrievedAt {
            return "Retrieved \(Fmt.monthDayYear(date)) · Read full article"
        }
        return info.isCurated ? "Built-in summary · Read full article" : "Read full article"
    }

    // MARK: Loading

    @MainActor
    private func setUp() async {
        switch mode {
        case .existing(let medication):
            draft = MedicationDraft(medication: medication)
            info = medication.info ?? MedicationLibrary.lookup(name: medication.name)
        case .manual(let name):
            var manual = MedicationDraft()
            manual.name = name
            draft = manual
            info = DrugInfo.manual(name: name)
        case .add(let result):
            if let known = result.info {
                info = known
                draft = MedicationDraft(info: known)
            } else {
                var placeholder = MedicationDraft()
                placeholder.name = result.name
                draft = placeholder
                await loadDetails()
            }
        }
    }

    @MainActor
    private func loadDetails() async {
        guard case let .add(result) = mode else { return }
        isLoading = true
        loadError = nil
        do {
            let loaded = try await DrugInfoService.shared.details(for: result)
            info = loaded
            let fresh = MedicationDraft(info: loaded)
            draft.purpose = draft.purpose.isEmpty ? fresh.purpose : draft.purpose
            draft.strength = draft.strength.isEmpty ? fresh.strength : draft.strength
            draft.dose = fresh.dose
        } catch {
            loadError = error.localizedDescription
            info = DrugInfo.manual(name: result.name)
        }
        isLoading = false
    }

    // MARK: Actions

    private func add() {
        guard canSave else { return }
        let medication = Medication(
            name: draft.name,
            strength: draft.strength,
            doseDescription: draft.dose,
            purpose: draft.purpose,
            scheduleMinutes: draft.scheduleMinutes
        )
        draft.apply(to: medication)
        var stored = info ?? DrugInfo.manual(name: draft.name)
        stored.name = medication.name
        medication.info = stored
        context.insert(medication)
        medication.profile = profile
        try? context.save()
        ReminderScheduler.sync(context)
        onDone()
    }

    private func saveExisting() {
        guard let medication = existingMedication, canSave else { return }
        draft.apply(to: medication)
        try? context.save()
        ReminderScheduler.sync(context)
        onDone()
    }

    private func deleteExisting() {
        guard let medication = existingMedication else { return }
        context.delete(medication)
        try? context.save()
        ReminderScheduler.sync(context)
        onDone()
    }
}
