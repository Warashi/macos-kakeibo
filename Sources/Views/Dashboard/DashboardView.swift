import SwiftData
import SwiftUI

/// ダッシュボードビュー
///
/// アプリケーションのメインダッシュボード画面。
/// 月次/年次の総括、年次特別枠の状況、カテゴリ別ハイライトを表示します。
internal struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext: ModelContext
    @State private var store: DashboardStore

    internal init() {
        // StateはinitではなくbodyのonAppearで初期化する必要がある
        // 一時的にダミー値を設定
        let container = try! ModelContainer(
            for: Transaction.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        _store = State(initialValue: DashboardStore(modelContext: container.mainContext))
    }

    internal var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // ツールバー（月次/年次切り替え、月移動）
                toolbarSection

                // 月次総括カード
                if store.displayMode == .monthly {
                    MonthlySummaryCard(
                        summary: store.monthlySummary,
                        budgetCalculation: store.monthlyBudgetCalculation,
                    )
                } else {
                    // 年次総括カード（簡易版）
                    AnnualSummaryCard(summary: store.annualSummary)
                }

                // 年次特別枠カード
                if let annualBudgetUsage = store.annualBudgetUsage {
                    AnnualBudgetCard(usage: annualBudgetUsage)
                }

                // カテゴリ別ハイライト
                CategoryHighlightTable(
                    categories: store.categoryHighlights,
                    title: store.displayMode == .monthly ? "今月のカテゴリ別支出" : "今年のカテゴリ別支出",
                )
            }
            .padding()
        }
        .navigationTitle("ダッシュボード")
        .onAppear {
            // 正しいModelContextで初期化
            store = DashboardStore(modelContext: modelContext)
        }
    }

    @ViewBuilder
    private var toolbarSection: some View {
        HStack {
            // 表示モード切り替え
            Picker("表示モード", selection: $store.displayMode) {
                ForEach(DashboardStore.DisplayMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 200)

            Spacer()

            // 月次の場合は月移動ボタン
            if store.displayMode == .monthly {
                monthNavigationButtons
            } else {
                yearNavigationButtons
            }

            Button("今日") {
                if store.displayMode == .monthly {
                    store.moveToCurrentMonth()
                } else {
                    store.moveToCurrentYear()
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    @ViewBuilder
    private var monthNavigationButtons: some View {
        HStack {
            Button(action: store.moveToPreviousMonth) {
                Image(systemName: "chevron.left")
            }

            Text("\(store.currentYear)年\(store.currentMonth)月")
                .frame(minWidth: 120)

            Button(action: store.moveToNextMonth) {
                Image(systemName: "chevron.right")
            }
        }
    }

    @ViewBuilder
    private var yearNavigationButtons: some View {
        HStack {
            Button(action: store.moveToPreviousYear) {
                Image(systemName: "chevron.left")
            }

            Text("\(store.currentYear)年")
                .frame(minWidth: 80)

            Button(action: store.moveToNextYear) {
                Image(systemName: "chevron.right")
            }
        }
    }
}
