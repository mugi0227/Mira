import SwiftUI

struct MainTabView: View {
    let palette: MiraThemePalette

    var body: some View {
        TabView {
            NavigationStack {
                HomeView(palette: palette)
            }
            .tabItem { Label("ホーム", systemImage: "calendar") }

            NavigationStack {
                AdjustmentsView(palette: palette)
            }
            .tabItem { Label("調整", systemImage: "arrow.trianglehead.2.clockwise.rotate.90") }

            NavigationStack {
                MarginsView(palette: palette)
            }
            .tabItem { Label("マイ余白", systemImage: "leaf") }

            NavigationStack {
                SettingsView(palette: palette)
            }
            .tabItem { Label("設定", systemImage: "gearshape") }
        }
        .tint(palette.accent)
    }
}
