import SwiftUI

/// 表示設定パネル
internal struct DisplaySettingsPanel: View {
    @Binding internal var showCategoryFullPath: Bool
    @Binding internal var useThousandSeparator: Bool

    internal var body: some View {
        SettingsSectionCard(
            title: "表示設定",
            iconName: "display",
            description: "金額やカテゴリの表示方法を調整します。",
            content: {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("カテゴリはフルパス（大項目/中項目）で表示する", isOn: $showCategoryFullPath)
                    Toggle("金額に3桁区切りを挿入する", isOn: $useThousandSeparator)
                }
            }
        )
    }
}
