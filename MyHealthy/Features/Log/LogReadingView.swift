import SwiftData
import SwiftUI

enum ReadingField: Hashable {
    case systolic1, diastolic1, pulse1, systolic2, diastolic2, pulse2

    var next: ReadingField? {
        switch self {
        case .systolic1: return .diastolic1
        case .diastolic1: return .pulse1
        case .pulse1: return nil
        case .systolic2: return .diastolic2
        case .diastolic2: return .pulse2
        case .pulse2: return nil
        }
    }
}

struct MeasurementInput: Equatable {
    var systolic = ""
    var diastolic = ""
    var pulse = ""

    var systolicValue: Int? { Int(systolic) }
    var diastolicValue: Int? { Int(diastolic) }
    var pulseValue: Int? { Int(pulse) }

    var isEmpty: Bool { systolic.isEmpty && diastolic.isEmpty && pulse.isEmpty }

    var problem: String? {
        ReadingValidation.problem(systolic: systolicValue, diastolic: diastolicValue, pulse: pulseValue)
    }

    var value: BPValue? {
        guard problem == nil, let s = systolicValue, let d = diastolicValue else { return nil }
        return BPValue(systolic: s, diastolic: d)
    }
}

struct LogReadingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let profile: Profile

    @State private var first = MeasurementInput()
    @State private var second = MeasurementInput()
    @State private var showsSecond = false
    @State private var date = Date()
    @State private var slot: TimeOfDay = .from(Date())
    @State private var slotEdited = false
    @State private var arm: Arm = .left
    @State private var position: BodyPosition = .sitting
    @State private var tags: Set<ReadingTag> = []
    @State private var note = ""
    @FocusState private var focus: ReadingField?

    private var measurements: [MeasurementInput] {
        showsSecond && !second.isEmpty ? [first, second] : [first]
    }

    private var problem: String? {
        measurements.compactMap(\.problem).first
    }

    private var result: BPValue? {
        guard problem == nil else { return nil }
        return ReadingValidation.average(measurements.compactMap(\.value))
    }

    private var resultPulse: Int? {
        ReadingValidation.averagePulse(measurements.compactMap(\.pulseValue))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    entryCard(input: $first, fields: (.systolic1, .diastolic1, .pulse1), title: nil)
                    feedback
                    secondReading
                    whenSection
                    detailsSection
                    Text("Before measuring: sit quietly for 5 minutes, feet flat, arm supported at heart level.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(Metrics.screenPadding)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("New Reading").font(.headline)
                        Text(profile.displayName).font(.caption).foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(result == nil)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(focus?.next == nil ? "Done" : "Next") {
                        focus = focus?.next
                    }
                }
            }
            .onAppear {
                focus = .systolic1
            }
            .onChange(of: date) { _, newValue in
                if !slotEdited { slot = .from(newValue) }
            }
        }
    }

    // MARK: Sections

    private func entryCard(
        input: Binding<MeasurementInput>,
        fields: (ReadingField, ReadingField, ReadingField),
        title: String?
    ) -> some View {
        Card(spacing: 12) {
            if let title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            HStack(spacing: 10) {
                BigNumberField(
                    title: "Systolic",
                    caption: "top · mmHg",
                    color: Palette.systolic,
                    text: input.systolic,
                    field: fields.0,
                    focus: $focus
                )
                BigNumberField(
                    title: "Diastolic",
                    caption: "bottom · mmHg",
                    color: Palette.diastolicText,
                    text: input.diastolic,
                    field: fields.1,
                    focus: $focus
                )
                BigNumberField(
                    title: "Pulse",
                    caption: "beats / min",
                    color: .secondary,
                    text: input.pulse,
                    field: fields.2,
                    focus: $focus
                )
            }
        }
    }

    @ViewBuilder
    private var feedback: some View {
        if let result {
            VStack(spacing: 10) {
                StatusChip.forReading(result, target: profile.target, suffix: " of \(profile.target.text)")
                if measurements.count > 1 {
                    Text("Saving the average: \(result.text)" + (resultPulse.map { ", pulse \($0)" } ?? ""))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if ReadingValidation.isVeryHigh(result) {
                    VeryHighNotice()
                }
            }
            .frame(maxWidth: .infinity)
        } else if let problem, !first.systolic.isEmpty, !first.diastolic.isEmpty {
            Text(problem)
                .font(.footnote)
                .foregroundStyle(Palette.warn)
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var secondReading: some View {
        if showsSecond {
            entryCard(input: $second, fields: (.systolic2, .diastolic2, .pulse2), title: "Second reading")
            Button("Remove second reading", role: .destructive) {
                second = MeasurementInput()
                showsSecond = false
            }
            .font(.subheadline)
        } else {
            Button {
                showsSecond = true
                focus = .systolic2
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Palette.tint)
                        .frame(width: 30, height: 30)
                        .background(Palette.tintSoft, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add a second reading")
                            .font(.body.weight(.medium))
                            .foregroundStyle(Palette.tint)
                        Text("Take 2 readings a minute apart — the app saves the average.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var whenSection: some View {
        VStack(spacing: 6) {
            SectionHeader(title: "When")
            VStack(spacing: 12) {
                DatePicker("Date & Time", selection: $date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                Picker("Time of day", selection: Binding(
                    get: { slot },
                    set: { newValue in
                        slot = newValue
                        slotEdited = true
                    }
                )) {
                    ForEach(TimeOfDay.allCases) { item in
                        Text(item.label).tag(item)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(16)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text("Picked from the time. Trends compares morning and evening averages.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var detailsSection: some View {
        VStack(spacing: 6) {
            SectionHeader(title: "Details")
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Arm")
                    Spacer()
                    Picker("Arm", selection: $arm) {
                        ForEach(Arm.allCases) { item in
                            Text(item.label).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                }
                .frame(minHeight: 50)
                Divider()
                HStack {
                    Text("Position")
                    Spacer()
                    Picker("Position", selection: $position) {
                        ForEach(BodyPosition.allCases) { item in
                            Text(item.label).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .frame(minHeight: 50)
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    Text("Tags")
                    FlowLayout(spacing: 8) {
                        ForEach(ReadingTag.allCases) { tag in
                            ToggleChip(title: tag.label, isOn: Binding(
                                get: { tags.contains(tag) },
                                set: { isOn in
                                    if isOn { tags.insert(tag) } else { tags.remove(tag) }
                                }
                            ))
                        }
                    }
                }
                .padding(.vertical, 12)
                Divider()
                TextField("Add a note", text: $note, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.vertical, 14)
            }
            .padding(.horizontal, 16)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    // MARK: Save

    private func save() {
        guard let value = result else { return }
        let reading = BPReading(
            timestamp: date,
            systolic: value.systolic,
            diastolic: value.diastolic,
            pulse: resultPulse,
            timeOfDay: slot,
            arm: arm,
            position: position,
            tags: ReadingTag.allCases.filter { tags.contains($0) },
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            measurementCount: measurements.count
        )
        context.insert(reading)
        reading.profile = profile
        try? context.save()
        dismiss()
    }
}

/// Large rounded number entry used for systolic, diastolic and pulse.
struct BigNumberField: View {
    let title: String
    let caption: String
    let color: Color
    @Binding var text: String
    let field: ReadingField
    var focus: FocusState<ReadingField?>.Binding

    private var isFocused: Bool { focus.wrappedValue == field }

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.footnote.weight(.bold))
                .foregroundStyle(color)
            TextField("–", text: $text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.bpNumber(38))
                .focused(focus, equals: field)
                .frame(height: 72)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isFocused ? Palette.tintSoft : Palette.fieldBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(isFocused ? Palette.tint : Color.clear, lineWidth: 2)
                )
                .onChange(of: text) { _, newValue in
                    let digits = String(newValue.filter(\.isNumber).prefix(3))
                    if digits != newValue { text = digits }
                }
                .accessibilityLabel("\(title), \(caption)")
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}
