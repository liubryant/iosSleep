import SwiftUI

@main
struct iosSleepApp: App {
    @StateObject private var soundLibrary = SoundLibrary()
    @StateObject private var player = AudioPlayerService()
    @StateObject private var sleepMonitor = SleepMonitorService()
    @StateObject private var healthKit = HealthKitService()
    @StateObject private var settings = AppSettings()
    @StateObject private var sdkManager = AppSDKManager.shared

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(soundLibrary)
                .environmentObject(player)
                .environmentObject(sleepMonitor)
                .environmentObject(healthKit)
                .environmentObject(settings)
                .environmentObject(sdkManager)
                .fullScreenCover(isPresented: Binding(
                    get: { !settings.agreementAccepted },
                    set: { _ in }
                )) {
                    PrivacyAgreementView()
                        .environmentObject(settings)
                        .interactiveDismissDisabled(true)
                }
                .task {
                    await soundLibrary.load()
                    sdkManager.startIfAllowed()
                }
                .onChange(of: settings.agreementAccepted) { accepted in
                    if accepted {
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            sdkManager.startIfAllowed()
                        }
                    }
                }
        }
    }
}
