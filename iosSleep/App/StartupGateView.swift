import SwiftUI

struct StartupGateView: View {
    @EnvironmentObject private var soundLibrary: SoundLibrary
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var sdkManager: AppSDKManager

    @State private var isReadyForHome = false
    @State private var didStartFlow = false

    var body: some View {
        ZStack {
            if isReadyForHome {
                MainTabView()
            } else {
                launchBackgroundView
            }
        }
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
            startSplashFlowIfNeeded()
        }
        .onChange(of: settings.agreementAccepted) { accepted in
            guard accepted else { return }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000)
                startSplashFlowIfNeeded()
            }
        }
    }

    private var launchBackgroundView: some View {
        Color(.systemBackground)
            .ignoresSafeArea()
    }

    private func startSplashFlowIfNeeded() {
        guard settings.agreementAccepted else { return }
        guard !didStartFlow else { return }
        didStartFlow = true

        sdkManager.startIfAllowed(showSplash: true) {
            Task { @MainActor in
                isReadyForHome = true
            }
        }
    }
}
