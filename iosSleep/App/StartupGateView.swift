import SwiftUI

struct StartupGateView: View {
    @EnvironmentObject private var soundLibrary: SoundLibrary
    @EnvironmentObject private var storyLibrary: StoryLibrary
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
            if settings.agreementAccepted {
                await storyLibrary.load()
            }
            startSplashFlowIfNeeded()
        }
        .onChange(of: settings.agreementAccepted) { accepted in
            guard accepted else { return }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000)
                await storyLibrary.load()
                startSplashFlowIfNeeded()
            }
        }
    }

    private var launchBackgroundView: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            Image("LaunchBrand")
                .resizable()
                .scaledToFill()
                .frame(width: 112, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func startSplashFlowIfNeeded() {
        guard settings.agreementAccepted else { return }
        guard !didStartFlow else { return }
        didStartFlow = true

        // 暂时关闭开屏广告；SDK 仍会初始化，其他广告位不受影响。
        sdkManager.startIfAllowed(showSplash: false) {
            Task { @MainActor in
                isReadyForHome = true
            }
        }
    }
}
