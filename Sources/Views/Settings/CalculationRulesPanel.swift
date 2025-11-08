import SwiftUI

/// 集計ルール設定パネル
internal struct CalculationRulesPanel: View {
    @Binding internal var includeOnlyCalculationTarget: Bool
    @Binding internal var excludeTransfers: Bool

    internal var body: some View {
        SettingsSectionCard(
            title: "集計ルール",
            iconName: "function",
            description: "ダッシュボードやレポートで使用する計算ルールを変更します。",
            content: {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("計算対象フラグがONの取引のみ集計する", isOn: $includeOnlyCalculationTarget)
                    Toggle("振替取引を集計から除外する", isOn: $excludeTransfers)
                }
            }
        )
    }
}
