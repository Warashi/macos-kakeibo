import SwiftUI

/// 年次予算グリッド
///
/// 対象年の全体予算とカテゴリ別予算を実績とともに表示します。
internal struct AnnualBudgetGrid: View {
    internal let title: String
    internal let overallEntry: AnnualBudgetEntry?
    internal let categoryEntries: [AnnualBudgetEntry]

    private var rows: [AnnualBudgetEntry] {
        var items: [AnnualBudgetEntry] = []
        if let overallEntry {
            items.append(overallEntry)
        }
        items.append(contentsOf: categoryEntries)
        return items
    }

    internal var body: some View {
        Card(title: "年次予算") {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.headline)

                if rows.isEmpty {
                    ContentUnavailableView {
                        Label("年次予算が未設定です", systemImage: "calendar")
                            .font(.title2)
                    } description: {
                        Text("月次予算を登録すると年次集計が自動で表示されます。")
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Table(rows) {
                        TableColumn("カテゴリ") { entry in
                            Text(entry.title)
                                .fontWeight(entry.isOverallBudget ? .semibold : .regular)
                                .foregroundColor(entry.isOverallBudget ? .primary : .secondary)
                        }
                        TableColumn("年間予算") { entry in
                            Text(entry.calculation.budgetAmount.currencyFormatted)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        TableColumn("年間実績") { entry in
                            Text(entry.calculation.actualAmount.currencyFormatted)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        TableColumn("残額") { entry in
                            Text(entry.calculation.remainingAmount.currencyFormatted)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .foregroundColor(entry.calculation.isOverBudget ? .red : .green)
                        }
                        TableColumn("使用率") { entry in
                            Text(String(format: "%.0f%%", entry.calculation.usageRate * 100))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .foregroundColor(entry.calculation.isOverBudget ? .red : .primary)
                        }
                    }
                    .frame(minHeight: 200)
                }
            }
        }
    }
}
