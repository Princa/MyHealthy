import Foundation
import SwiftData
import UserNotifications

/// One daily repeating local notification.
struct ReminderSpec: Equatable {
    var id: String
    var title: String
    var body: String
    var minutes: Int
}

/// Keeps local notifications in step with every profile's check times and medication schedules.
enum ReminderScheduler {
    static let prefix = "myhealthy."
    /// iOS keeps at most 64 pending notifications per app.
    static let maximumPending = 60

    @discardableResult
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    @MainActor
    static func specs(for profiles: [Profile]) -> [ReminderSpec] {
        var specs: [ReminderSpec] = []
        for profile in profiles {
            let key = profile.id.uuidString
            if profile.morningCheckEnabled {
                specs.append(ReminderSpec(
                    id: "\(prefix)bp.\(key).morning",
                    title: "Blood pressure check",
                    body: "Time for \(profile.displayName)’s morning reading.",
                    minutes: profile.morningCheckMinutes
                ))
            }
            if profile.eveningCheckEnabled {
                specs.append(ReminderSpec(
                    id: "\(prefix)bp.\(key).evening",
                    title: "Blood pressure check",
                    body: "Time for \(profile.displayName)’s evening reading.",
                    minutes: profile.eveningCheckMinutes
                ))
            }
            for medication in profile.activeMedications where medication.remindersEnabled {
                for minutes in medication.scheduleMinutes {
                    specs.append(ReminderSpec(
                        id: "\(prefix)med.\(medication.id.uuidString).\(minutes)",
                        title: "\(medication.displayName) · \(profile.displayName)",
                        body: "\(medication.doseDescription) at \(Fmt.time(minutes: minutes)).",
                        minutes: minutes
                    ))
                }
            }
        }
        return specs
    }

    /// Replaces all of this app's pending reminders with `specs`.
    static func apply(_ specs: [ReminderSpec]) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)
        guard !specs.isEmpty else { return }

        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            let granted = await requestAuthorization()
            if !granted { return }
        } else if settings.authorizationStatus == .denied {
            return
        }

        for spec in specs.prefix(maximumPending) {
            let content = UNMutableNotificationContent()
            content.title = spec.title
            content.body = spec.body
            content.sound = .default
            var components = DateComponents()
            components.hour = spec.minutes / 60
            components.minute = spec.minutes % 60
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: spec.id, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    /// Rebuilds reminders from everything stored. Call after any change to profiles or medications.
    @MainActor
    static func sync(_ context: ModelContext) {
        let profiles = (try? context.fetch(FetchDescriptor<Profile>())) ?? []
        let specs = specs(for: profiles)
        Task {
            await apply(specs)
        }
    }
}
