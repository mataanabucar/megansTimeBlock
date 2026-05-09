import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var preferences: [UserPlanningPreferences]
    @Query private var tasks: [TaskItem]
    @Query private var blocks: [ScheduleBlock]
    @Query private var reviews: [ReviewEntry]
    @State private var isShowingWipeOptions = false
    @State private var wipeMessage: String?

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

                DangerZoneView(
                    taskCount: tasks.count,
                    blockCount: blocks.count,
                    reviewCount: reviews.count,
                    preferenceCount: preferences.count,
                    message: wipeMessage,
                    onWipeTapped: { isShowingWipeOptions = true }
                )
            }
            .padding(20)
        }
        .gentleBackground()
        .navigationTitle("Settings")
        .confirmationDialog(
            "Wipe Gentle Day data?",
            isPresented: $isShowingWipeOptions,
            titleVisibility: .visible
        ) {
            Button("Wipe Tasks, Schedule, and Reviews", role: .destructive) {
                wipeContent(keepsPreferences: true)
            }
            Button("Wipe Everything", role: .destructive) {
                wipeContent(keepsPreferences: false)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone. Keeping settings preserves your day rhythm and planning defaults.")
        }
        .task {
            SeedDataService.ensurePreferences(in: modelContext, existing: preferences)
        }
    }

    private func wipeContent(keepsPreferences: Bool) {
        blocks.forEach { block in
            ReminderService.shared.cancelReminder(for: block)
            modelContext.delete(block)
        }
        tasks.forEach(modelContext.delete)
        reviews.forEach(modelContext.delete)

        if !keepsPreferences {
            preferences.forEach(modelContext.delete)
        }

        try? modelContext.save()
        if !keepsPreferences {
            SeedDataService.ensurePreferences(in: modelContext, existing: [])
        }

        wipeMessage = keepsPreferences
            ? "Tasks, schedule blocks, and review history were wiped. Settings were kept."
            : "All app data was wiped. Default settings were recreated."
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
                Text("AI parsing")
                    .font(.headline)
                    .foregroundStyle(GentleTheme.ink)

                Toggle("Enable AI parsing", isOn: $preferences.enableAIParsing)

                VStack(alignment: .leading, spacing: 8) {
                    Text("AI mode")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(GentleTheme.ink)

                    Picker("AI mode", selection: aiModeBinding) {
                        ForEach(AIParsingMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)

                    Text(preferences.aiMode.friendlyDescription)
                        .font(.footnote)
                        .foregroundStyle(GentleTheme.mutedInk)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("AI Proxy Endpoint URL")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(GentleTheme.ink)

                    TextField(UserPlanningPreferences.defaultAIProxyEndpointURL, text: $preferences.aiProxyEndpointURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(GentleTheme.field)
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(GentleTheme.outline)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Text("OpenAI via Proxy uses your hosted Vercel backend endpoint for normal personal use. Mock AI is local and offline. A local Mac proxy such as http://<mac-wifi-ip>:8787/api/parse-task is only for development testing.")
                        .font(.footnote)
                        .foregroundStyle(GentleTheme.mutedInk)
                }

                Text("The OpenAI API key belongs on the hosted proxy, never in the iPhone app.")
                    .font(.footnote)
                    .foregroundStyle(GentleTheme.mutedInk)
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

    private var aiModeBinding: Binding<AIParsingMode> {
        Binding(
            get: { preferences.aiMode },
            set: { preferences.aiMode = $0 }
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

private struct DangerZoneView: View {
    var taskCount: Int
    var blockCount: Int
    var reviewCount: Int
    var preferenceCount: Int
    var message: String?
    var onWipeTapped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(GentleTheme.peach)
                Text("Data")
                    .font(.headline)
                    .foregroundStyle(GentleTheme.ink)
            }

            Text(summary)
                .font(.subheadline)
                .foregroundStyle(GentleTheme.mutedInk)

            Button(role: .destructive, action: onWipeTapped) {
                Label("Wipe Data", systemImage: "trash.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(GentleTheme.peach)

            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(GentleTheme.mutedInk)
            }
        }
        .gentleCardStyle()
    }

    private var summary: String {
        [
            "\(taskCount) tasks",
            "\(blockCount) scheduled blocks",
            "\(reviewCount) review entries",
            "\(preferenceCount) settings profiles"
        ].joined(separator: " · ")
    }
}
