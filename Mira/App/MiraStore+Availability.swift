import Foundation
import SwiftData

@MainActor
extension MiraStore {
    func finishOnboarding(
        targets: [MarginKind: Int],
        baseRules: [BaseAvailabilityRule]
    ) {
        do {
            onboardingCompleted = true
            settingsEntity?.onboardingCompleted = true
            settingsEntity?.updatedAt = .now

            try replaceBaseRules(with: baseRules)

            for offset in 0...2 {
                let month = selectedMonth.addingMonths(offset)
                try DemoSeeder.seedDefaultGoals(
                    in: context,
                    month: month,
                    targets: targets,
                    calendar: .mira
                )
            }

            try context.save()
            try refresh()
            autoPlaceMargins(for: selectedMonth)
        } catch {
            toast = "初期設定を保存できませんでした"
        }
    }

    func updateBaseRules(_ rules: [BaseAvailabilityRule]) {
        do {
            try replaceBaseRules(with: rules)
            try context.save()
            toast = rules.isEmpty
                ? "基本時間の設定を外したにゃ"
                : "基本時間を更新したにゃ。おすすめ配置にも反映できるよ"
        } catch {
            toast = "基本時間を変更できませんでした"
        }
    }

    private func replaceBaseRules(with rules: [BaseAvailabilityRule]) throws {
        try context.delete(model: BaseRuleEntity.self)
        for rule in rules {
            context.insert(BaseRuleEntity(
                weekday: rule.weekday,
                startMinute: rule.startMinute,
                endMinute: rule.endMinute
            ))
        }
    }
}
