import SwiftData
import SwiftUI

/// 設定画面のメインビュー
internal struct SettingsView: View {
    @Bindable private var store: SettingsStore

    internal init(modelContext: ModelContext) {
        self.store = SettingsStore(modelContext: modelContext)
    }

    internal var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                CalculationRulesPanel(
                    includeOnlyCalculationTarget: $store.includeOnlyCalculationTarget,
                    excludeTransfers: $store.excludeTransfers,
                )
                DisplaySettingsPanel(
                    showCategoryFullPath: $store.showCategoryFullPath,
                    useThousandSeparator: $store.useThousandSeparator,
                )
                DataManagementPanel(store: store)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("設定")
                .font(.largeTitle)
                .bold()
            Text("アプリケーションの計算ルールやデータ管理を行います。")
                .foregroundStyle(.secondary)
        }
    }
}
