import SwiftUI

@main
struct iosSleepApp: App {
    @StateObject private var soundLibrary = SoundLibrary()
    @StateObject private var player = AudioPlayerService()
    @StateObject private var storyLibrary = StoryLibrary()
    @StateObject private var storyPlayer = StoryPlayerService()
    @StateObject private var sleepMonitor = SleepMonitorService()
    @StateObject private var healthKit = HealthKitService()
    @StateObject private var settings = AppSettings()
    @StateObject private var sdkManager = AppSDKManager.shared

    var body: some Scene {
        WindowGroup {
            StartupGateView()
                .environmentObject(soundLibrary)
                .environmentObject(player)
                .environmentObject(storyLibrary)
                .environmentObject(storyPlayer)
                .environmentObject(sleepMonitor)
                .environmentObject(healthKit)
                .environmentObject(settings)
                .environmentObject(sdkManager)
        }
    }
}
