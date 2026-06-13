import SwiftUI

@main
struct iosSleepApp: App {
    @StateObject private var soundLibrary = SoundLibrary()
    @StateObject private var player = AudioPlayerService()
    @StateObject private var sleepMonitor = SleepMonitorService()
    @StateObject private var healthKit = HealthKitService()
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(soundLibrary)
                .environmentObject(player)
                .environmentObject(sleepMonitor)
                .environmentObject(healthKit)
                .environmentObject(settings)
                .task {
                    await soundLibrary.load()
                }
        }
    }
}
