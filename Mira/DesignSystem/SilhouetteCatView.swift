import SwiftUI

struct MiraCatView: View {
    @Environment(MiraStore.self) private var store
    let mood: CatMood
    var size: CGFloat = 72

    var body: some View {
        MiraCatArtwork(theme: store.theme, mood: mood, size: size)
    }
}

struct MiraCatArtwork: View {
    let theme: AppThemeKind
    let mood: CatMood
    var size: CGFloat = 72

    var body: some View {
        if theme == .silhouetteCat {
            SilhouetteCatView(mood: mood, size: size)
        } else {
            PixelCatView(mood: mood, size: size)
        }
    }
}

struct SilhouetteCatView: View {
    enum Pose: Equatable {
        case sitting, loaf, peeking

        var assetName: String {
            switch self {
            case .sitting: "SilhouetteCatSitting"
            case .loaf: "SilhouetteCatLoaf"
            case .peeking: "SilhouetteCatPeeking"
            }
        }
    }

    let mood: CatMood
    var size: CGFloat = 72
    var animates = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static func pose(for mood: CatMood) -> Pose {
        switch mood {
        case .idle, .thinking, .inviting, .happy, .celebrating: .sitting
        case .relaxed, .sleeping: .loaf
        case .tired, .warning: .peeking
        }
    }

    var body: some View {
        Group {
            if reduceMotion || !animates {
                artwork
            } else {
                artwork.phaseAnimator([false, true]) { content, floating in
                    content.offset(y: floating ? -2 : 2)
                } animation: { _ in .easeInOut(duration: 1.8) }
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityIdentifier("silhouetteCat")
    }

    private var artwork: some View {
        Image(Self.pose(for: mood).assetName)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .padding(size * 0.01)
    }

    private var label: String {
        switch mood {
        case .relaxed, .sleeping: "くつろいでいる猫"
        case .tired: "少し疲れている猫"
        case .warning: "注意を知らせる猫"
        case .happy, .celebrating: "喜んでいる猫"
        case .thinking: "考えている猫"
        case .idle: "座っている猫"
        case .inviting: "こちらへ招いている猫"
        }
    }
}
