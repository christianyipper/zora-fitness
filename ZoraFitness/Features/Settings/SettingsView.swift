import SwiftUI

struct SettingsView: View {
    @Environment(SettingsStore.self)    private var settings
    @Environment(HealthKitManager.self) private var healthKit

    var body: some View {
        // @Bindable lets us derive $settings.age / $settings.sleepTargetHours
        // from an @Observable object accessed via @Environment.
        @Bindable var settings = settings

        NavigationStack {
            Form {
                personalSection(settings: $settings)
                trainingSection(settings: $settings)
                healthSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Personal

    @ViewBuilder
    private func personalSection(settings: Bindable<SettingsStore>) -> some View {
        Section {
            // Age stepper
            HStack {
                Text("Age")
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
                Stepper(
                    "\(settings.wrappedValue.age) yrs",
                    value: settings.age,
                    in: 15...80
                )
                .fixedSize()
                .foregroundStyle(AppTheme.primaryText)
            }

            // Derived max HR (read-only)
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Max Heart Rate")
                        .foregroundStyle(AppTheme.primaryText)
                    Text("220 − age formula")
                        .font(AppTheme.micro)
                        .foregroundStyle(AppTheme.tertiaryText)
                }
                Spacer()
                HStack(spacing: 6) {
                    Text("\(Int(settings.wrappedValue.computedMaxHR)) bpm")
                        .foregroundStyle(AppTheme.secondaryText)
                        .monospacedDigit()
                    Text("auto")
                        .font(AppTheme.micro)
                        .foregroundStyle(AppTheme.tertiaryText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(white: 0.22), in: Capsule())
                }
            }
        } header: {
            sectionHeader("Personal")
        }
        .listRowBackground(AppTheme.cardBackground)
    }

    // MARK: - Training

    @ViewBuilder
    private func trainingSection(settings: Bindable<SettingsStore>) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Sleep Target")
                        .foregroundStyle(AppTheme.primaryText)
                    Spacer()
                    Text(settings.wrappedValue.sleepTargetFormatted)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.sleepPurple)
                        .monospacedDigit()
                }

                Slider(value: settings.sleepTargetHours, in: 6...10, step: 0.5)
                    .tint(AppTheme.sleepPurple)

                HStack {
                    Text("6h")
                    Spacer()
                    Text("8h")
                    Spacer()
                    Text("10h")
                }
                .font(AppTheme.micro)
                .foregroundStyle(AppTheme.tertiaryText)
            }
            .padding(.vertical, 4)
        } header: {
            sectionHeader("Training")
        } footer: {
            Text("Used as the nightly reference line in the Analytics sleep chart.")
                .font(AppTheme.micro)
                .foregroundStyle(AppTheme.tertiaryText)
        }
        .listRowBackground(AppTheme.cardBackground)
    }

    // MARK: - Health

    private var healthSection: some View {
        Section {
            HStack {
                Text("HealthKit Access")
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
                Label(
                    healthKit.isAuthorized ? "Authorized" : "Denied",
                    systemImage: healthKit.isAuthorized ? "checkmark.circle.fill" : "xmark.circle.fill"
                )
                .font(AppTheme.caption)
                .foregroundStyle(healthKit.isAuthorized ? AppTheme.recoveryGreen : AppTheme.recoveryRed)
                .labelStyle(.titleAndIcon)
            }

            if !healthKit.isAuthorized {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Open Health Settings", systemImage: "arrow.up.right")
                        .foregroundStyle(AppTheme.strainBlue)
                }
            }
        } header: {
            sectionHeader("Health")
        } footer: {
            Text("Enable all Health categories for accurate recovery and strain scores.")
                .font(AppTheme.micro)
                .foregroundStyle(AppTheme.tertiaryText)
        }
        .listRowBackground(AppTheme.cardBackground)
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
                Text(Bundle.main.appVersion)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        } header: {
            sectionHeader("About")
        }
        .listRowBackground(AppTheme.cardBackground)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(AppTheme.label)
            .foregroundStyle(AppTheme.secondaryText)
            .tracking(1.3)
    }
}

// MARK: - Bundle version helper

private extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build   = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
