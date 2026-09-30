import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case today, trends, meds, profiles
}

enum AppKeys {
    static let activeProfileID = "activeProfileID"
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var lock: AppLock
    @Query(sort: \Profile.createdAt) private var profiles: [Profile]
    @AppStorage(AppKeys.activeProfileID) private var activeProfileID = ""
    @State private var tab: AppTab = .today

    private var activeProfile: Profile? {
        profiles.first { $0.id.uuidString == activeProfileID } ?? profiles.first
    }

    var body: some View {
        ZStack {
            if let profile = activeProfile {
                TabView(selection: $tab) {
                    TodayView(profile: profile, profiles: profiles, tab: $tab)
                        .id(profile.id)
                        .tabItem { Label("Today", systemImage: "heart.text.square") }
                        .tag(AppTab.today)

                    TrendsView(profile: profile)
                        .id(profile.id)
                        .tabItem { Label("Trends", systemImage: "chart.xyaxis.line") }
                        .tag(AppTab.trends)

                    MedicationsView(profile: profile)
                        .id(profile.id)
                        .tabItem { Label("Meds", systemImage: "pills") }
                        .tag(AppTab.meds)

                    ProfilesView(profiles: profiles, activeProfile: profile, tab: $tab)
                        .tabItem { Label("Profiles", systemImage: "person.2") }
                        .tag(AppTab.profiles)
                }
            } else {
                WelcomeView()
            }

            if lock.isLocked {
                LockView()
                    .transition(.opacity)
            }
        }
        .tint(Palette.tint)
        .animation(.easeInOut(duration: 0.2), value: lock.isLocked)
        .onAppear {
            ensureActiveProfile()
            ReminderScheduler.sync(context)
            if lock.isLocked { lock.unlock() }
        }
        .onChange(of: profiles.map(\.id)) {
            ensureActiveProfile()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                lock.lockIfEnabled()
            } else if phase == .active, lock.isLocked {
                lock.unlock()
            }
        }
    }

    private func ensureActiveProfile() {
        guard !profiles.contains(where: { $0.id.uuidString == activeProfileID }) else { return }
        activeProfileID = profiles.first?.id.uuidString ?? ""
    }
}

struct WelcomeView: View {
    @Environment(\.modelContext) private var context
    @AppStorage(AppKeys.activeProfileID) private var activeProfileID = ""
    @State private var showingEditor = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 64))
                .foregroundStyle(Palette.tint)
                .accessibilityHidden(true)
            Text("MyHealthy")
                .font(.largeTitle.bold())
            Text("Track blood pressure and medications for yourself and your family. Each person gets their own profile, trends and doctor reports.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Create a Profile") {
                showingEditor = true
            }
            .buttonStyle(PrimaryButtonStyle())
            Button("Explore with Sample Data") {
                let profile = SampleData.insertSampleProfile(into: context)
                activeProfileID = profile.id.uuidString
            }
            .buttonStyle(SoftButtonStyle())
            Label("Health data stays on this iPhone.", systemImage: "lock")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background)
        .sheet(isPresented: $showingEditor) {
            ProfileEditorView(profile: nil)
        }
    }
}

struct LockView: View {
    @EnvironmentObject private var lock: AppLock

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 44))
                .foregroundStyle(Palette.tint)
                .accessibilityHidden(true)
            Text("MyHealthy is locked")
                .font(.title2.bold())
            if let message = lock.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button("Unlock with \(AppLock.biometryName)") {
                lock.unlock()
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(maxWidth: 280)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background.ignoresSafeArea())
    }
}
