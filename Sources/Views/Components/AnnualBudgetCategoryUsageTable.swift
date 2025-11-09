import SwiftUI

/// 年次特別枠のカテゴリ別使用状況テーブル
internal struct AnnualBudgetCategoryUsageTable: View {
    internal let allocations: [CategoryAllocation]
    internal let title: String

    internal init(
        allocations: [CategoryAllocation],
        title: String = "カテゴリ別年次枠（当月まで）"
    ) {
        self.allocations = allocations
        self.title = title
    }

    internal var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            Table(of: CategoryAllocation.self) {
                TableColumn("カテゴリ") { allocation in
                    Text(allocation.categoryName)
                }
                TableColumn("枠設定額") { allocation in
                    Text(allocation.annualBudgetAmount.currencyFormatted)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .foregroundColor(.secondary)
                }
                TableColumn("利用済み") { allocation in
                    Text(allocation.allocatableAmount.currencyFormatted)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .foregroundColor(.expense)
                }
                TableColumn("残額") { allocation in
                    let remaining = allocation.annualBudgetRemainingAmount
                    Text(remaining.currencyFormatted)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .foregroundColor(remaining < 0 ? .error : .success)
                }
                TableColumn("利用率") { allocation in
                    let percentage = Int(allocation.annualBudgetUsageRate * 100)
                    Text("\(percentage)%")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .foregroundColor(allocation.annualBudgetUsageRate >= 1 ? .error : .primary)
                }
            } rows: {
                ForEach(allocations) { allocation in
                    TableRow(allocation)
                }
            }
            .frame(minHeight: 150, maxHeight: 300)
        }
    }
}
