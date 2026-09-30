import SwiftData
import SwiftUI

struct ProfileDraft {
    var name = ""
    var hasBirthDate = false
    var birthDate = Calendar.current.date(from: DateComponents(year: 1970, month: 1, day: 1)) ?? Date()
    var sex: Sex = .unspecified
    var height = ""
    var weight = ""
    var conditions = ""
    var targetSystolic = BPTarget.homeDefault.systolic
    var targetDiastolic = BPTarget.homeDefault.diastolic
    var morningOn = true
    var morningTime = Fmt.date(fromMinutes: 450)
    var eveningOn = true
    var eveningTime = Fmt.date(fromMinutes: 1200)
    var bedtimeOn = false
    var bedtime = Fmt.date(fromMinutes: 1350)
    var doctorName = ""
    var colorIndex = 0

    init() {}

    init(profile: Profile) {
        name = profile.name
        if let date = profile.birthDate {
            hasBirthDate = true
            birthDate = date
        }
        sex = profile.sex
        height = profile.heightCm.map(Self.format) ?? ""
        weight = profile.weightKg.map(Self.format) ?? ""
        conditions = profile.conditions
        targetSystolic = profile.targetSystolic
        targetDiastolic = profile.targetDiastolic
        morningOn = profile.morningCheckEnabled
        morningTime = Fmt.date(fromMinutes: profile.morningCheckMinutes)
        eveningOn = profile.eveningCheckEnabled
        eveningTime = Fmt.date(fromMinutes: profile.eveningCheckMinutes)
        bedtimeOn = profile.bedtimeReminderEnabled
        bedtime = Fmt.date(fromMinutes: profile.bedtimeMinutes)
        doctorName = profile.doctorName
        colorIndex = profile.colorIndex
    }

    static func format(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }

    static func parse(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces))
    }

    var age: Int? {
        guard hasBirthDate else { return nil }
        return Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year
    }

    func apply(to profile: Profile) {
        profile.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.birthDate = hasBirthDate ? birthDate : nil
        profile.sex = sex
        profile.heightCm = Self.parse(height)
        profile.weightKg = Self.parse(weight)
        profile.conditions = conditions.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.targetSystolic = targetSystolic
        profile.targetDiastolic = targetDiastolic
        profile.morningCheckEnabled = morningOn
        profile.morningCheckMinutes = Fmt.minutes(from: morningTime)
        profile.eveningCheckEnabled = eveningOn
        profile.eveningCheckMinutes = Fmt.minutes(from: eveningTime)
        profile.bedtimeReminderEnabled = bedtimeOn
        profile.bedtimeMinutes = Fmt.minutes(from: bedtime)
        profile.doctorName = doctorName.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.colorIndex = colorIndex
    }
}

struct ProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage(AppKeys.activeProfileID) private var activeProfileID = ""
    let profile: Profile?

    @State private var draft: ProfileDraft
    @State private var confirmingDelete = false

    init(profile: Profile?) {
        self.profile = profile
        _draft = State(initialValue: profile.map { ProfileDraft(profile: $0) } ?? ProfileDraft())
    }

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 14) {
                        AvatarView(
                            initial: String(draft.name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased(),
                            colorIndex: draft.colorIndex,
                            size: 84
                        )
                        HStack(spacing: 14) {
                            ForEach(Palette.avatars.indices, id: \.self) { index in
                                Button {
                                    draft.colorIndex = index
                                } label: {
                                    Circle()
                                        .fill(Palette.avatars[index].background)
                                        .overlay(Circle().fill(Palette.avatars[index].foreground).padding(9))
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(Palette.tint, lineWidth: draft.colorIndex == index ? 2.5 : 0)
                                                .padding(-4)
                                        )
                                        .frame(width: 44, height: 44)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Colour \(index + 1)")
                                .accessibilityAddTraits(draft.colorIndex == index ? .isSelected : [])
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .listRowBackground(Color.clear)

                Section("About") {
                    LabeledContent("Name") {
                        TextField("Name", text: $draft.name)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.words)
                    }
                    if draft.hasBirthDate {
                        DatePicker("Date of Birth", selection: $draft.birthDate, in: ...Date(), displayedComponents: .date)
                        if let age = draft.age {
                            LabeledContent("Age", value: "\(age)")
                        }
                    } else {
                        Button("Add Date of Birth") {
                            draft.hasBirthDate = true
                        }
                    }
                    Picker("Sex", selection: $draft.sex) {
                        ForEach(Sex.allCases) { item in
                            Text(item.label).tag(item)
                        }
                    }
                    LabeledContent("Height") {
                        HStack(spacing: 4) {
                            TextField("Optional", text: $draft.height)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                            Text("cm").foregroundStyle(.secondary)
                        }
                    }
                    LabeledContent("Weight") {
                        HStack(spacing: 4) {
                            TextField("Optional", text: $draft.weight)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                            Text("kg").foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    LabeledContent("Conditions") {
                        TextField("e.g. High blood pressure", text: $draft.conditions)
                            .multilineTextAlignment(.trailing)
                    }
                    Stepper(value: $draft.targetSystolic, in: 100...160, step: 5) {
                        LabeledContent("Target top number", value: "below \(draft.targetSystolic)")
                    }
                    Stepper(value: $draft.targetDiastolic, in: 60...100, step: 5) {
                        LabeledContent("Target bottom number", value: "below \(draft.targetDiastolic)")
                    }
                    Toggle("Morning check reminder", isOn: $draft.morningOn)
                    if draft.morningOn {
                        DatePicker("Morning time", selection: $draft.morningTime, displayedComponents: .hourAndMinute)
                    }
                    Toggle("Evening check reminder", isOn: $draft.eveningOn)
                    if draft.eveningOn {
                        DatePicker("Evening time", selection: $draft.eveningTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Blood pressure")
                } footer: {
                    Text("135/85 is the usual threshold for home readings. Ask the doctor for a personal target.")
                }

                Section {
                    Toggle("Bedtime reminder", isOn: $draft.bedtimeOn)
                    if draft.bedtimeOn {
                        DatePicker("Bedtime", selection: $draft.bedtime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Sleep")
                } footer: {
                    Text("A nightly nudge to mark when you go to sleep. Your usual bedtime also pre-fills manual sleep entries.")
                }

                Section {
                    LabeledContent("Doctor") {
                        TextField("Name (optional)", text: $draft.doctorName)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("For reports")
                } footer: {
                    if profile == nil {
                        Text("After saving, add medications from the Meds tab. The app fills in what each one is for and typical doses.")
                    }
                }

                if profile != nil {
                    Section {
                        Button("Delete Profile", role: .destructive) {
                            confirmingDelete = true
                        }
                    }
                }
            }
            .navigationTitle(profile == nil ? "New Profile" : "Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .confirmationDialog(
                "Delete \(draft.name)?",
                isPresented: $confirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete Profile and All Data", role: .destructive, action: deleteProfile)
            } message: {
                Text("This removes every reading, medication and dose record for this person. It can’t be undone.")
            }
            .onAppear {
                if profile == nil {
                    let count = (try? context.fetchCount(FetchDescriptor<Profile>())) ?? 0
                    draft.colorIndex = count % Palette.avatars.count
                }
            }
        }
    }

    private func save() {
        guard canSave else { return }
        let target: Profile
        if let profile {
            target = profile
        } else {
            target = Profile(name: draft.name)
            context.insert(target)
        }
        draft.apply(to: target)
        try? context.save()
        if profile == nil {
            activeProfileID = target.id.uuidString
        }
        ReminderScheduler.sync(context)
        dismiss()
    }

    private func deleteProfile() {
        guard let profile else { return }
        let wasActive = activeProfileID == profile.id.uuidString
        context.delete(profile)
        try? context.save()
        if wasActive { activeProfileID = "" }
        ReminderScheduler.sync(context)
        dismiss()
    }
}
