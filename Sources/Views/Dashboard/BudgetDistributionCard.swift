import SwiftUI

/// 予算配分カード（月次/年次対応）
internal struct BudgetDistributionCard: View {
    internal let displayMode: DashboardStore.DisplayMode
    internal let monthlyCategoryCalculations: [CategoryBudgetCalculation]
    internal let annualCategoryEntries: [AnnualBudgetEntry]

    private var rows: [BudgetDistributionRow] {
        switch displayMode {
        case .monthly:
            return monthlyCategoryCalculations.map {
                BudgetDistributionRow(
                    id: $0.categoryId,
                    title: $0.categoryName,
                    calculation: $0.calculation
                )
            }
        case .annual:
            return annualCategoryEntries.map {
                BudgetDistributionRow(
                    id: $0.id.hashValue,
                    title: $0.title,
                    calculation: $0.calculation
                )
            }
        }
    }

    internal var body: some View {
        Card(title: distributionTitle) {
            if rows.isEmpty {
                ContentUnavailableView {
                    Label("カテゴリ別予算が未設定です", systemImage: "list.bullet.rectangle")
                } description: {
                    Text("カテゴリごとの予算を登録すると進捗が表示されます。")
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                Table(rows) {
                    TableColumn("カテゴリ") { row in
                        Text(row.title)
                    }
                    TableColumn("予算額") { row in
                        Text(row.calculation.budgetAmount.currencyFormatted)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    TableColumn("実績") { row in
                        Text(row.calculation.actualAmount.currencyFormatted)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    TableColumn("残額") { row in
                        Text(row.calculation.remainingAmount.currencyFormatted)
                            .foregroundColor(row.calculation.isOverBudget ? .red : .green)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    TableColumn("使用率") { row in
                        Text(String(format: "%.0f%%", row.calculation.usageRate * 100))
                            .foregroundColor(row.calculation.isOverBudget ? .red : .primary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .frame(minHeight: 220)
            }
        }
    }

    private var distributionTitle: String {
        displayMode == .monthly ? "カテゴリ別月次予算" : "カテゴリ別年次予算"
    }
}

private struct BudgetDistributionRow: Identifiable {
    internal let id: Int
    internal let title: String
    internal let calculation: BudgetCalculation
}
