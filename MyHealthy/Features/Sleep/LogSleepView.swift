import SwiftData
import SwiftUI

/// Manual entry for one night: when the person fell asleep and when they woke up.
/// Pass `log` to edit an existing entry (including one still in progress).
struct LogSleepView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let profile: Profile
    let log: SleepLog?

    @State private var bedtime: Date
    @State private var wakeClock: Date
    @State private var note: String
    @State private var confirmingDelete = false

    init(profile: Profile, log: SleepLog? = nil) {
        self.profile = profile
        self.log = log
        let now = Date()
        // New entries default to last night at the usual bedtime, waking at 7:00 AM
        // (or now, if that hasn't happened yet).
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        let bedDay = profile.bedtimeMinutes >= 12 * 60 ? yesterday : now
        let start = log?.bedtime ?? DoseClock.date(minutesOfDay: profile.bedtimeMinutes, on: bedDay) ?? now
        let wake = log?.wakeTime ?? min(SleepMath.wake(after: start, wakeMinutes: 7 * 60), now)
        _bedtime = State(initialValue: start)
        _wakeClock = State(initialValue: wake)
        _note = State(initialValue: log?.note ?? "")
    }

    private var wake: Date {
        SleepMath.wake(after: bedtime, wakeMinutes: Fmt.minutes(from: wakeClock))
    }

    private var problem: String? {
        SleepMath.problem(bedtime: bedtime, wake: wake)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 6) {
                        Text(SleepMath.durationText(wake.timeIntervalSince(bedtime)))
                            .font(.bpNumber(52))
                            .foregroundStyle(problem == nil ? Palette.sleep : .secondary)
                        Text("Night of \(Fmt.weekdayMonthDay(SleepMath.night(of: bedtime)))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        if let problem {
                            Text(problem)
                                .font(.footnote)
                                .foregroundStyle(Palette.warn)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .accessibilityElement(children: .combine)
                }

                Section {
                    DatePicker(
                        "Fell asleep",
                        selection: $bedtime,
                        in: ...Date(),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    DatePicker("Woke up", selection: $wakeClock, displayedComponents: .hourAndMinute)
                } footer: {
                    Text("Woke up \(Fmt.dayAndTime(wake)).")
                }

                Section {
                    TextField("Add a note", text: $note, axis: .vertical)
                        .lineLimit(1...4)
                }

                if log != nil {
                    Section {
                        Button("Delete Entry", role: .destructive) {
                            confirmingDelete = true
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text(log == nil ? "Log Sleep" : "Edit Sleep").font(.headline)
                        Text(profile.displayName).font(.caption).foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(problem != nil)
                }
            }
            .confirmationDialog("Delete this sleep entry?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let log { SleepActions.delete(log, context: context) }
                    dismiss()
                }
            }
        }
    }

    private func save() {
        guard problem == nil else { return }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if let log {
            log.bedtime = bedtime
            log.wakeTime = wake
            log.note = trimmed
        } else {
            let entry = SleepLog(bedtime: bedtime, wakeTime: wake, note: trimmed)
            context.insert(entry)
            entry.profile = profile
        }
        try? context.save()
        dismiss()
    }
}
