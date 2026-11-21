import SwiftUI
import SwiftData
import UIKit
import XCTest
@testable import Mira

@MainActor
final class MiraStyleTests: XCTestCase {
    func testReduceMotionDisablesSelectionSpring() {
        XCTAssertNil(MiraMotion.selection(reduceMotion: true))
        XCTAssertNotNil(MiraMotion.selection(reduceMotion: false))
    }

    func testOneLineCatIsASelectableCatSkin() {
        XCTAssertTrue(AppThemeKind.allCases.contains(.onelineCat))
        XCTAssertEqual(AppThemeKind(rawValue: AppThemeKind.onelineCat.rawValue), .onelineCat)
        XCTAssertTrue(AppThemeKind.onelineCat.isCat)
        XCTAssertFalse(AppThemeKind.softMinimal.isCat)
        for scheme in [ColorScheme.light, .dark] {
            XCTAssertTrue(MiraThemePalette(kind: .onelineCat, colorScheme: scheme).isCatSkin)
        }
    }

    func testOneLineCatHasLightAndDarkArtworkForEveryMood() {
        let moods: [CatMood] = [.idle, .relaxed, .sleeping, .thinking, .tired, .warning, .happy, .celebrating, .inviting]
        XCTAssertEqual(Set(moods.map { OneLineCatPose(mood: $0) }), Set(OneLineCatPose.allCases))
        for pose in OneLineCatPose.allCases {
            for style in [UIUserInterfaceStyle.light, .dark] {
                let image = UIImage(named: pose.assetName, in: .main, compatibleWith: UITraitCollection(userInterfaceStyle: style))
                XCTAssertNotNil(image, "\(pose) \(style.rawValue)")
                XCTAssertGreaterThan(image?.size.width ?? 0, 80, "\(pose) should show the whole body")
            }
        }
    }

    func testAccentLabelsHaveReadableContrastInBothThemes() {
        for theme in AppThemeKind.allCases {
            for scheme in [ColorScheme.light, .dark] {
                for style in AppColorStyle.allCases {
                    let palette = MiraThemePalette(kind: theme, colorScheme: scheme, colorStyle: style)
                    let foreground = luminance(palette.onAccent)
                    let background = luminance(palette.accent)
                    let contrast = (max(foreground, background) + 0.05) / (min(foreground, background) + 0.05)
                    XCTAssertGreaterThanOrEqual(contrast, 4.5, "\(theme) \(scheme) \(style)")
                }
            }
        }
    }

    func testAssistantSkinDoesNotForceCatVoice() {
        for theme in AppThemeKind.allCases {
            let message = AssistantEngine().message(theme: theme, month: .now, goals: [], items: [])
            XCTAssertFalse(message.title.contains("にゃ"))
            XCTAssertFalse(message.body.contains("にゃ"))
        }
    }

    func testColorChoiceSurvivesRelaunchAndSkinChanges() async throws {
        let container = try makeContainer()
        let store = makeStore(container)
        await store.bootstrap()
        XCTAssertEqual(store.colorStyle, .blue)

        store.setColorStyle(.sage)
        for theme in AppThemeKind.allCases {
            store.setTheme(theme)
            XCTAssertEqual(store.colorStyle, .sage)
        }

        let relaunched = makeStore(container)
        await relaunched.bootstrap()
        XCTAssertEqual(relaunched.colorStyle, .sage)
    }

    func testMissingOrUnknownColorChoiceDefaultsToBlue() async throws {
        let store = makeStore(try makeContainer())
        await store.bootstrap()
        for raw in [nil, "unknown-color"] as [String?] {
            store.settingsEntity?.colorStyleRaw = raw
            store.applySettings()
            XCTAssertEqual(store.colorStyle, .blue)
        }
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            AppSettingsEntity.self, CalendarItemEntity.self, MarginGoalEntity.self,
            BaseRuleEntity.self, AdjustmentEntity.self, PendingInvitationEntity.self,
            LoadRuleEntity.self, ImportantPersonEntity.self, ConversationCaseEntity.self,
            RebalanceProposalEntity.self
        ])
        return try ModelContainer(for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
    }

    private func makeStore(_ container: ModelContainer) -> MiraStore {
        MiraStore(container: container, classifier: RuleBasedSemanticClassifier(),
            conversationInterpreter: RuleBasedConversationInterpreter(), draftStorage: DraftStorage())
    }

    private func luminance(_ color: Color) -> Double {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let channels = [red, green, blue].map { value -> Double in
            let value = Double(value)
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722
    }
}
