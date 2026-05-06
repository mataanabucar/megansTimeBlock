import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var preferences: [UserPlanningPreferences]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GentleSectionHeader(
                    title: "Settings",
                    subtitle: "Defaults help the planner stay realistic."
                )

                if let preference = preferences.first {
                    SettingsContent(preferences: preference)
                } else {
                    GentleEmptyState(
                        title: "Preparing settings",
                        message: "Default preferences will be created automatically.",
                        systemImage: "gearshape"
                    )
                }
            }
            .padding(20)
        }
        .gentleBackground()
        .navigationTitle("Settings")
        .task {
            SeedDataService.ensurePreferences(in: modelContext, existing: preferences)
        }
    }
}

private struct SettingsContent: View {
    @Bindable var preferences: UserPlanningPreferences
    @State private var permissionMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Day rhythm")
                    .font(.headline)
                    .foregroundStyle(GentleTheme.ink)
                DatePicker("Wake time", selection: $preferences.wakeTime, displayedComponents: [.hourAndMinute])
                DatePicker("Sleep time", selection: $preferences.sleepTime, displayedComponents: [.hourAndMinute])
                DatePicker("Planning starts", selection: $preferences.defaultWindowStart, displayedComponents: [.hourAndMinute])
                DatePicker("Planning ends", selection: $preferences.defaultWindowEnd, displayedComponents: [.hourAndMinute])
                DatePicker("Evening starts", selection: $preferences.eveningStartTime, displayedComponents: [.hourAndMinute])
            }
            .gentleCardStyle()

            VStack(alignment: .leading, spacing: 14) {
                Text("Planning defaults")
                    .font(.headline)
                    .foregroundStyle(GentleTheme.ink)
                Stepper("Default task duration: \(preferences.defaultTaskDuration) min", value: $preferences.defaultTaskDuration, in: 5...120, step: 5)
                Stepper("Buffer between tasks: \(preferences.bufferMinutes) min", value: $preferences.bufferMinutes, in: 0...60, step: 5)
            }
            .gentleCardStyle()

            VStack(alignment: .leading, spacing: 14) {
                Text("Reminders")
                    .font(.headline)
                    .foregroundStyle(GentleTheme.ink)

                Picker("Default reminder", selection: reminderStyleBinding) {
                    ForEach(ReminderStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }

                Toggle("Enable Time Sensitive reminders", isOn: $preferences.enableTimeSensitiveReminders)

                Text("Time Sensitive reminders may be useful for important blocks, but they still depend on iOS settings and user permission.")
                    .font(.footnote)
                    .foregroundStyle(GentleTheme.mutedInk)

                Text("Snooze options")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(GentleTheme.ink)
                ForEach([5, 15, 30], id: \.self) { minutes in
                    Toggle("\(minutes) minutes", isOn: snoozeBinding(minutes: minutes))
                }

                Button("Request Notification Permission") {
                    requestPermission()
                }
                .buttonStyle(.borderedProminent)
                .tint(GentleTheme.sage)

                if let permissionMessage {
                    Text(permissionMessage)
                        .font(.footnote)
                        .foregroundStyle(GentleTheme.mutedInk)
                }
            }
            .gentleCardStyle()

            VStack(alignment: .leading, spacing: 12) {
                Text("Siri Announce Notifications")
                    .font(.headline)
                    .foregroundStyle(GentleTheme.ink)
                Text("Gentle Day makes reminder text short and voice-friendly. Siri verbal announcements are controlled by iOS Settings, not forced by the app.")
                    .font(.subheadline)
                    .foregroundStyle(GentleTheme.mutedInk)
                Text("On iPhone, check Settings > Notifications > Announce Notifications, then test with your headphones or CarPlay setup if you use one.")
                    .font(.subheadline)
                    .foregroundStyle(GentleTheme.mutedInk)
            }
            .gentleCardStyle()

            VStack(alignment: .leading, spacing: 12) {
                Text("AlarmKit future support")
                    .font(.headline)
                    .foregroundStyle(GentleTheme.ink)
                Text(AlarmKitReminderService.futureSupportNote)
                    .font(.subheadline)
                    .foregroundStyle(GentleTheme.mutedInk)
                Text("Available in this SDK: \(AlarmKitReminderService.isAvailableInCurrentSDK ? "Yes" : "No")")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GentleTheme.mutedInk)
            }
            .gentleCardStyle()
        }
    }

    private var reminderStyleBinding: Binding<ReminderStyle> {
        Binding(
            get: { preferences.defaultReminderStyle },
            set: { preferences.defaultReminderStyle = $0 }
        )
    }

    private func snoozeBinding(minutes: Int) -> Binding<Bool> {
        Binding(
            get: { preferences.snoozeOptions.contains(minutes) },
            set: { preferences.setSnoozeOption(minutes, enabled: $0) }
        )
    }

    private func requestPermission() {
        Task {
            do {
                let allowed = try await ReminderService.shared.requestAuthorization(
                    enableTimeSensitive: preferences.enableTimeSensitiveReminders
                )
                await MainActor.run {
                    permissionMessage = allowed ? "Notifications are allowed." : "Notifications were not allowed yet."
                }
            } catch {
                await MainActor.run {
                    permissionMessage = error.localizedDescription
                }
            }
        }
    }
}

