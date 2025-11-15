import SwiftUI

/// 月次予算グリッド
///
/// 対象月の全体予算とカテゴリ別予算をテーブル表示します。
internal struct MonthlyBudgetGrid: View {
    internal let title: String
    internal let overallEntry: MonthlyBudgetEntry?
    internal let categoryEntries: [MonthlyBudgetEntry]
    internal let onAdd: () -> Void
    internal let onEdit: (BudgetDTO) -> Void
    internal let onDuplicate: (BudgetDTO) -> Void
    internal let onDelete: (BudgetDTO) -> Void

    private var rows: [MonthlyBudgetEntry] {
        var items: [MonthlyBudgetEntry] = []
        if let overallEntry {
            items.append(overallEntry)
        }
        items.append(contentsOf: categoryEntries)
        return items
    }

    internal var body: some View {
        Card(title: "月次予算") {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Button {
                        onAdd()
                    } label: {
                        Label("予算を追加", systemImage: "plus")
                    }
                }

                if rows.isEmpty {
                    ContentUnavailableView {
                        Label("予算が未設定です", systemImage: "square.grid.2x2")
                            .font(.title2)
                    } description: {
                        Text("「予算を追加」ボタンから月次予算を登録できます。")
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Table(rows) {
                        TableColumn("カテゴリ") { entry in
                            Text(entry.title)
                                .fontWeight(entry.isOverallBudget ? .semibold : .regular)
                                .foregroundColor(entry.isOverallBudget ? .primary : .secondary)
                        }
                        TableColumn("期間") { entry in
                            Text(entry.periodDescription)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        TableColumn("予算額") { entry in
                            Text(entry.calculation.budgetAmount.currencyFormatted)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        TableColumn("実績") { entry in
                            Text(entry.calculation.actualAmount.currencyFormatted)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        TableColumn("残額") { entry in
                            Text(entry.calculation.remainingAmount.currencyFormatted)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .foregroundColor(entry.calculation.isOverBudget ? .error : .success)
                        }
                        TableColumn("使用率") { entry in
                            Text(String(format: "%.0f%%", entry.calculation.usageRate * 100))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .foregroundColor(entry.calculation.isOverBudget ? .error : .primary)
                        }
                        TableColumn("操作") { entry in
                            HStack {
                                Button {
                                    onEdit(entry.budget)
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(.borderless)

                                Button {
                                    onDuplicate(entry.budget)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                }
                                .buttonStyle(.borderless)

                                Button(role: .destructive) {
                                    onDelete(entry.budget)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .frame(minHeight: 200)
                }
            }
        }
    }
}
