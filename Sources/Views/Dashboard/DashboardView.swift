import SwiftData
import SwiftUI

/// ダッシュボードビュー
///
/// アプリケーションのメインダッシュボード画面。
/// 月次/年次の総括、年次特別枠の状況、カテゴリ別ハイライトを表示します。
internal struct DashboardView: View {
    @Environment(\.appModelContainer) private var modelContainer: ModelContainer?
    @State private var store: DashboardStore?

    internal var body: some View {
        Group {
            if let store {
                ScrollView {
                    VStack(spacing: 20) {
                        toolbarSection(store: store)

                        DashboardSummaryCard(
                            displayMode: store.displayMode,
                            monthlySummary: store.monthlySummary,
                            annualSummary: store.annualSummary,
                            monthlyBudgetCalculation: store.monthlyBudgetCalculation,
                            annualBudgetProgress: store.annualBudgetProgressCalculation,
                        )

                        ViewThatFits {
                            HStack(alignment: .top, spacing: 20) {
                                detailLeftColumn(store: store)
                                detailRightColumn(store: store)
                            }
                            VStack(spacing: 20) {
                                detailLeftColumn(store: store)
                                detailRightColumn(store: store)
                            }
                        }
                    }
                    .padding()
                }
            } else {
                ProgressView("データを読み込み中…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("ダッシュボード")
        .onAppear {
            prepareStoreIfNeeded()
        }
    }

    @ViewBuilder
    private func toolbarSection(store: DashboardStore) -> some View {
        HStack {
            Picker(
                "表示モード",
                selection: Binding(
                    get: { store.displayMode },
                    set: { store.displayMode = $0 },
                ),
            ) {
                ForEach(DashboardStore.DisplayMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 200)

            Spacer()

            if store.displayMode == .monthly {
                monthNavigationButtons(store: store)
            } else {
                yearNavigationButtons(store: store)
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
        .background(Color.backgroundTertiary)
        .cornerRadius(8)
    }

    @ViewBuilder
    private func monthNavigationButtons(store: DashboardStore) -> some View {
        HStack {
            Button(action: store.moveToPreviousMonth) {
                Image(systemName: "chevron.left")
            }

            Text("\(store.currentYear.yearDisplayString)年\(store.currentMonth)月")
                .frame(minWidth: 120)

            Button(action: store.moveToNextMonth) {
                Image(systemName: "chevron.right")
            }
        }
    }

    @ViewBuilder
    private func yearNavigationButtons(store: DashboardStore) -> some View {
        HStack {
            Button(action: store.moveToPreviousYear) {
                Image(systemName: "chevron.left")
            }

            Text("\(store.currentYear.yearDisplayString)年")
                .frame(minWidth: 80)

            Button(action: store.moveToNextYear) {
                Image(systemName: "chevron.right")
            }
        }
    }

    @ViewBuilder
    private func detailLeftColumn(store: DashboardStore) -> some View {
        VStack(spacing: 20) {
            BudgetDistributionCard(
                displayMode: store.displayMode,
                monthlyCategoryCalculations: store.monthlyBudgetCalculation.categoryCalculations,
                annualCategoryEntries: store.annualBudgetCategoryEntries,
            )

            if let annualBudgetUsage = store.annualBudgetUsage {
                AnnualBudgetCard(
                    usage: annualBudgetUsage,
                    categoryAllocations: annualBudgetUsage.categoryAllocations,
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func detailRightColumn(store: DashboardStore) -> some View {
        CategoryHighlightTable(
            categories: store.categoryHighlights,
            title: store.displayMode == .monthly ? "今月のカテゴリ別支出" : "今年のカテゴリ別支出",
        )
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

private extension DashboardView {
    func prepareStoreIfNeeded() {
        guard store == nil else { return }
        Task { @DatabaseActor in
            guard await MainActor.run(body: { store == nil }) else { return }
            guard let container = await MainActor.run(body: { modelContainer }) else {
                assertionFailure("ModelContainer is unavailable")
                return
            }
            let dashboardStore = await DashboardStackBuilder.makeStore(modelContainer: container)
            await MainActor.run {
                guard store == nil else { return }
                store = dashboardStore
            }
        }
    }
}
