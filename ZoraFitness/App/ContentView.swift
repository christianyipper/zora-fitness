import SwiftUI

struct ContentView: View {
    @Environment(HealthKitManager.self) private var healthKit

    var body: some View {
        Group {
            switch healthKit.authorizationStatus {
            case .notDetermined:
                ProgressView("Requesting HealthKit access…")
                    .foregroundStyle(.white)
            case .unavailable, .denied:
                HealthKitDeniedView()
            case .authorized:
                MainTabView()
            }
        }
    }
}

private struct HealthKitDeniedView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.slash")
                .font(.system(size: 52))
                .foregroundStyle(.red)
            Text("Health Access Required")
                .font(.title2.bold())
            Text("Open Settings > Privacy & Security > Health > Zora and enable all categories.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

private struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Today", systemImage: "bolt.fill") }

            WorkoutHistoryView()
                .tabItem { Label("Workouts", systemImage: "figure.run") }

            AnalyticsView()
                .tabItem { Label("Analytics", systemImage: "chart.xyaxis.line") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(.white)
    }
}
