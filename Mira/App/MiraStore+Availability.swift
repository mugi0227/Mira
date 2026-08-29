import Foundation
import SwiftData

@MainActor
extension MiraStore {
    func finishOnboarding(
        targets: [MarginKind: Int],
        baseRules: [BaseAvailabilityRule],
        marginComfort: MarginComfortLevel = .standard,
        useRecommendedTargets: Bool = true,
        weekStartDay: WeekStartDay = .monday,
        useDeviceHolidays: Bool = false
    ) {
        do {
            onboardingCompleted = true
            marginComfortLevel = marginComfort
            self.weekStartDay = weekStartDay
            settingsEntity?.onboardingCompleted = true
            settingsEntity?.marginComfortRaw = marginComfort.rawValue
            settingsEntity?.weekStartRaw = weekStartDay.rawValue
            settingsEntity?.updatedAt = .now

            try replaceBaseRules(with: baseRules)

            let recommendation = marginRecommendationEngine.recommend(
                month: selectedMonth,
                items: items,
                comfort: marginComfort
            )
            let canonicalTargets = Dictionary(
                targets.map { ($0.key.canonicalKind, $0.value) },
                uniquingKeysWith: { current, _ in current }
            )
            let selectedKinds = Set(canonicalTargets.keys)
            var resolvedTargets: [MarginKind: Int]
            if useRecommendedTargets {
                resolvedTargets = recommendation.targets.filter { selectedKinds.contains($0.key) }
            } else {
                resolvedTargets = canonicalTargets
            }

            for offset in 0...2 {
                let month = selectedMonth.addingMonths(offset)
                try DemoSeeder.seedDefaultGoals(
                    in: context,
                    month: month,
                    targets: resolvedTargets,
                    calendar: .mira
                )
            }

            try context.save()
            try refresh()
            currentMarginRecommendation = recommendation
            autoPlaceMargins(for: selectedMonth)
            if useDeviceHolidays {
                Task { await setDeviceHolidaysEnabled(true) }
            }
        } catch {
            toast = "初期設定を保存できませんでした"
        }
    }

    func updateBaseRules(_ rules: [BaseAvailabilityRule]) {
        do {
            try replaceBaseRules(with: rules)
            try context.save()
            recalculateBalance(for: selectedMonth)
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
