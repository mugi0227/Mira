import SwiftUI

struct AppRootView: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = MiraThemePalette(kind: store.theme, colorScheme: colorScheme)

        ZStack {
            MiraScreenBackground(palette: palette)

            if !store.isReady {
                VStack(spacing: MiraSpacing.md) {
                    PixelCatView(mood: .thinking, size: 84)
                    ProgressView("余白を準備中…")
                        .tint(palette.accent)
                        .foregroundStyle(palette.primaryText)
                }
            } else if !store.onboardingCompleted {
                OnboardingView(palette: palette)
            } else {
                MainTabView(palette: palette)
            }
        }
        .task {
            if !store.isReady { await store.bootstrap() }
        }
        .overlay(alignment: .top) {
            if let toast = store.toast {
                Text(toast)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.primaryText)
                    .padding(.horizontal, MiraSpacing.md)
                    .padding(.vertical, MiraSpacing.sm)
                    .background(.ultraThinMaterial, in: Capsule())
                    .shadow(color: palette.shadow, radius: 12, y: 5)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: toast) {
                        try? await Task.sleep(for: .seconds(2.6))
                        withAnimation(MiraMotion.standard) { store.toast = nil }
                    }
            }
        }
        .animation(MiraMotion.standard, value: store.onboardingCompleted)
        .preferredColorScheme(nil)
    }
}
