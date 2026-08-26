import SwiftUI

struct PixelCatView: View {
    let mood: CatMood
    var size: CGFloat = 72

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floating = false

    var body: some View {
        Canvas { context, canvasSize in
            let pattern = Self.pattern(for: mood)
            let gridSize = CGFloat(pattern.count)
            let pixel = floor(min(canvasSize.width, canvasSize.height) / gridSize)
            let origin = CGPoint(
                x: (canvasSize.width - pixel * gridSize) / 2,
                y: (canvasSize.height - pixel * gridSize) / 2
            )

            for (rowIndex, row) in pattern.enumerated() {
                for (columnIndex, character) in row.enumerated() where character != "." {
                    let rect = CGRect(
                        x: origin.x + CGFloat(columnIndex) * pixel,
                        y: origin.y + CGFloat(rowIndex) * pixel,
                        width: pixel + 0.25,
                        height: pixel + 0.25
                    )
                    let color: Color
                    switch character {
                    case "#": color = Color(hex: 0x5A4650)
                    case "f": color = Color(hex: 0xF4C7A8)
                    case "e": color = Color(hex: 0x2B2428)
                    case "p": color = Color(hex: 0xE58A9C)
                    case "z": color = Color(hex: 0xA68BC1)
                    default: color = Color(hex: 0x5A4650)
                    }
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(width: size, height: size)
        .offset(y: reduceMotion ? 0 : (floating ? -2 : 2))
        .animation(reduceMotion ? nil : .easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: floating)
        .onAppear { floating = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        switch mood {
        case .relaxed, .sleeping: "くつろいでいる猫"
        case .tired: "少し疲れている猫"
        case .warning: "注意を知らせる猫"
        case .happy, .celebrating: "喜んでいる猫"
        case .thinking: "考えている猫"
        case .idle: "座っている猫"
        }
    }

    private static func pattern(for mood: CatMood) -> [String] {
        switch mood {
        case .sleeping, .relaxed:
            return [
                "................",
                "................",
                "....##....##....",
                "...#ff####ff#...",
                "..#ffffffffff#..",
                ".#ffffeffeffff#.",
                ".#ffffffffffp#.",
                "..#ffffffffff#..",
                "...##ffffff##...",
                ".....######.....",
                "...##########...",
                "..#ffffffffff#..",
                "..############..",
                "....zz......zz..",
                "...zz........zz.",
                "................"
            ]
        case .tired, .warning:
            return [
                "................",
                "....##....##....",
                "...#ff####ff#...",
                "..#ffffffffff#..",
                ".#ffff#ffff#fff#.",
                ".#ffffeffeffff#.",
                ".#fffff##fffff#.",
                "..#ffffffffff#..",
                "...##ffffff##...",
                ".....######.....",
                "....########....",
                "...#ffffffff#...",
                "...##########...",
                "....##....##....",
                "...##......##...",
                "................"
            ]
        case .happy, .celebrating:
            return [
                "................",
                "....##....##....",
                "...#ff####ff#...",
                "..#ffffffffff#..",
                ".#ffffepppeffff#.",
                ".#fffff##fffff#.",
                ".#ffff####ffff#.",
                "..#ffffffffff#..",
                "...##ffffff##...",
                ".....######.....",
                "...##########...",
                "..#ffffffffff#..",
                "..############..",
                "....##....##....",
                "...##......##...",
                "................"
            ]
        case .thinking, .idle:
            return [
                "................",
                "....##....##....",
                "...#ff####ff#...",
                "..#ffffffffff#..",
                ".#ffffeffeffff#.",
                ".#ffffffpfffff#.",
                ".#fffff##fffff#.",
                "..#ffffffffff#..",
                "...##ffffff##...",
                ".....######.....",
                "...##########...",
                "..#ffffffffff#..",
                "..############..",
                "....##....##....",
                "...##......##...",
                "................"
            ]
        }
    }
}
