import SwiftData
import SwiftUI

struct ProfilesView: View {
    @Environment(\.modelContext) private var context
    @AppStorage(AppKeys.activeProfileID) private var activeProfileID = ""
    @AppStorage(AppLock.enabledKey) private var requireUnlock = false
    let profiles: [Profile]
    let activeProfile: Profile
    @Binding var tab: AppTab

    @State private var creating = false
    @State private var editing: Profile? = nil

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(profiles) { profile in
                        Button {
                            activeProfileID = profile.id.uuidString
                            tab = .today
                        } label: {
                            ProfileRow(profile: profile, isActive: profile.id == activeProfile.id)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button("Edit") { editing = profile }
                                .tint(.gray)
                        }
                        .contextMenu {
                            Button {
                                editing = profile
                            } label: {
                                Label("Edit Profile", systemImage: "pencil")
                            }
                        }
                    }
                } footer: {
                    Text("Each person keeps their own readings, medications and reports. Swipe left on a profile to edit it.")
                }

                Section {
                    Button {
                        creating = true
                    } label: {
                        Label("Add Profile", systemImage: "plus.circle.fill")
                            .font(.body.weight(.medium))
                    }
                }

                Section {
                    Toggle("Require \(AppLock.biometryName)", isOn: $requireUnlock)
                    Button("Notification Settings") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                } header: {
                    Text("Privacy & reminders")
                } footer: {
                    Label("Health data stays on this iPhone. Nothing is uploaded; medication searches send only the name you type.", systemImage: "lock")
                }

                Section {
                    Button("Add Sample Profile") {
                        let sample = SampleData.insertSampleProfile(into: context)
                        activeProfileID = sample.id.uuidString
                        tab = .today
                    }
                } footer: {
                    Text("Creates a profile named “Sample” with four weeks of example readings and medications. Delete it any time.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Profiles")
            .sheet(isPresented: $creating) {
                ProfileEditorView(profile: nil)
            }
            .sheet(item: $editing) { profile in
                ProfileEditorView(profile: profile)
            }
        }
    }
}

struct ProfileRow: View {
    let profile: Profile
    var isActive = false

    var body: some View {
        HStack(spacing: 14) {
            AvatarView(initial: profile.initial, colorIndex: profile.colorIndex, size: 48)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(profile.displayName)
                        .font(.body.weight(.semibold))
                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(Palette.tint)
                            .accessibilityLabel("Current profile")
                    }
                }
                Text(profile.summaryLine)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if let latest = profile.latestReading {
                VStack(alignment: .trailing, spacing: 3) {
                    Text(latest.value.text)
                        .font(.bpNumber(18))
                    Text(Fmt.dayAndTime(latest.timestamp))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.chevron)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
