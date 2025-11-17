import SwiftData
import SwiftUI

/// 設定画面のメインビュー
internal struct SettingsView: View {
    @Environment(\.appModelContainer) private var modelContainer: ModelContainer?
    @State private var store: SettingsStore?

    internal var body: some View {
        Group {
            if let store {
                SettingsContentView(store: store)
            } else {
                ProgressView("読み込み中…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            guard store == nil else { return }
            guard let modelContainer else {
                assertionFailure("ModelContainer is unavailable")
                return
            }
            let settingsStore = await SettingsStackBuilder.makeSettingsStore(modelContainer: modelContainer)
            await MainActor.run {
                store = settingsStore
            }
        }
    }
}

private struct SettingsContentView: View {
    @Bindable var store: SettingsStore

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
