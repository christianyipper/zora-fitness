import SwiftUI

@main
struct ZoraFitnessApp: App {

    @State private var healthKit = HealthKitManager()
    @State private var settings  = SettingsStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(healthKit)
                .environment(settings)
                .preferredColorScheme(.dark)
                .task {
                    // Sync max HR from stored settings before requesting permissions
                    healthKit.maxHeartRate = settings.computedMaxHR
                    await healthKit.requestAuthorization()
                }
                // Keep HealthKitManager in sync when age changes in Settings
                .onChange(of: settings.age) { _, _ in
                    healthKit.maxHeartRate = settings.computedMaxHR
                }
        }
    }
}
