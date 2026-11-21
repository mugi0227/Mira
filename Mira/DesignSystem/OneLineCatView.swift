import SwiftUI

/// Thick, rounded one-line cat cut out of the concept artwork, with a
/// white-line variant in the asset catalog for dark mode.
struct OneLineCatView: View {
    let mood: CatMood
    var size: CGFloat = 72

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var pose: OneLineCatPose { OneLineCatPose(mood: mood) }

    var body: some View {
        animatedArtwork
            .frame(width: size, height: size)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(pose.accessibilityLabel)
            .accessibilityIdentifier("oneLineCat")
    }

    /// Breathing is driven by the timeline rather than a repeating implicit
    /// animation, which would also animate the cat's position and leave it
    /// behind when a scroll view moves.
    @ViewBuilder
    private var animatedArtwork: some View {
        if reduceMotion {
            artwork
        } else {
            TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                let seconds = timeline.date.timeIntervalSinceReferenceDate
                let breath = (1 - cos(seconds * .pi / 2.2)) / 2
                artwork.scaleEffect(x: 1, y: 0.985 + 0.04 * breath, anchor: .bottom)
            }
        }
    }

    private var artwork: some View {
        Image(pose.assetName)
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .scaledToFit()
    }
}

/// The three poses of the concept artwork: sitting, curled up, and stretching.
enum OneLineCatPose: CaseIterable {
    case sitting
    case curled
    case stretching

    init(mood: CatMood) {
        switch mood {
        case .relaxed, .sleeping: self = .curled
        case .inviting, .celebrating: self = .stretching
        case .idle, .happy, .thinking, .tired, .warning: self = .sitting
        }
    }

    var assetName: String {
        switch self {
        case .sitting: "OneLineCatSitting"
        case .curled: "OneLineCatCurled"
        case .stretching: "OneLineCatStretching"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .sitting: "目を細めて座る猫"
        case .curled: "丸くなってくつろぐ猫"
        case .stretching: "のびをしている猫"
        }
    }
}
