import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            SoundHomeView()
                .tabItem {
                    Label("声音", systemImage: "waveform")
                }

            SleepHomeView()
                .tabItem {
                    Label("睡眠", systemImage: "moon.zzz.fill")
                }

            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.crop.circle")
                }
        }
        .tint(.indigo)
    }
}
