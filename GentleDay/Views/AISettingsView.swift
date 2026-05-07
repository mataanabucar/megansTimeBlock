import SwiftUI

struct AISettingsView: View {
    @Bindable var preferences: UserPlanningPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI capture and planning")
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

                TextField("https://your-domain.com/parse-task", text: $preferences.aiProxyEndpointURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(AppColors.field)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                            .stroke(AppColors.softBorder.opacity(0.65), lineWidth: 0.8)
                    }

                Text("Paste your hosted backend endpoint here for normal personal use. Local Mac URLs like http://<mac-wifi-ip>:8787/parse-task are only for development testing.")
                    .font(.footnote)
                    .foregroundStyle(GentleTheme.mutedInk)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Default planning style")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(GentleTheme.ink)

                Picker("Default planning style", selection: defaultPlanningStyleBinding) {
                    ForEach(PlanningStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.menu)

                Text("Default schedule range")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(GentleTheme.ink)

                Picker("Default schedule range", selection: defaultScheduleRangeBinding) {
                    ForEach(ScheduleRange.allCases) { range in
                        Text(range.title).tag(range)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(serviceNote)
                    .font(.footnote)
                    .foregroundStyle(GentleTheme.mutedInk)

                Text("Mock AI is local and offline. OpenAI via Proxy sends task text to your backend, where the OpenAI API key stays private.")
                    .font(.footnote)
                    .foregroundStyle(GentleTheme.mutedInk)
            }
        }
        .gentleCardStyle()
    }

    private var defaultPlanningStyleBinding: Binding<PlanningStyle> {
        Binding(
            get: { preferences.defaultPlanningStyle },
            set: { preferences.defaultPlanningStyle = $0 }
        )
    }

    private var aiModeBinding: Binding<AIParsingMode> {
        Binding(
            get: { preferences.aiMode },
            set: { preferences.aiMode = $0 }
        )
    }

    private var defaultScheduleRangeBinding: Binding<ScheduleRange> {
        Binding(
            get: { preferences.defaultScheduleRange },
            set: { preferences.defaultScheduleRange = $0 }
        )
    }

    private var serviceNote: String {
        if preferences.aiMode == .mockAI {
            return "Mock AI is for local testing and fallback use. It does not need internet."
        }

        if preferences.aiProxyEndpointURL.trimmedForStorage.isEmpty {
            return "Add your hosted AI proxy endpoint before using OpenAI parsing."
        }

        return "Hosted proxy is the recommended real mode. The local Mac proxy is optional and only for development."
    }
}
