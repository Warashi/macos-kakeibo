import SwiftUI

/// 年次特別枠カード
///
/// 年次特別枠の総額・使用額・残額・使用率を表示します。
internal struct AnnualBudgetCard: View {
    internal let usage: AnnualBudgetUsage
    internal let categoryAllocations: [CategoryAllocation]

    internal var body: some View {
        Card(title: "年次特別枠") {
            VStack(spacing: 16) {
                HStack(spacing: 32) {
                    summaryItem(
                        title: "総額",
                        amount: usage.totalAmount,
                        color: .info,
                    )

                    summaryItem(
                        title: "使用済み",
                        amount: usage.usedAmount,
                        color: .expense,
                    )

                    summaryItem(
                        title: "残額",
                        amount: usage.remainingAmount,
                        color: .success,
                    )
                }

                Divider()

                VStack(spacing: 8) {
                    HStack {
                        Text("使用率")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Text("\(Int(usage.usageRate * 100))%")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }

                    ProgressBar(
                        progress: usage.usageRate,
                        style: usage.usageRate >= 0.9 ? .danger : .custom(.info),
                        showLabel: false,
                    )
                }

                if !categoryAllocations.isEmpty {
                    Divider()

                    categoryAllocationsTable
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private var categoryAllocationsTable: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("カテゴリ別詳細")
                .font(.headline)

            Table(of: CategoryAllocation.self) {
                TableColumn("カテゴリ") { allocation in
                    Text(allocation.categoryName)
                }
                TableColumn("月次予算") { allocation in
                    Text(allocation.monthlyBudgetAmount.currencyFormatted)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                TableColumn("実績") { allocation in
                    Text(allocation.actualAmount.currencyFormatted)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                TableColumn("年次枠充当") { allocation in
                    Text(allocation.allocatableAmount.currencyFormatted)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .foregroundColor(allocation.allocatableAmount > 0 ? .expense : .secondary)
                }
            } rows: {
                ForEach(categoryAllocations) { allocation in
                    TableRow(allocation)
                }
            }
            .frame(minHeight: 150, maxHeight: 300)
        }
    }

    @ViewBuilder
    private func summaryItem(
        title: String,
        amount: Decimal,
        color: Color,
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(amount.currencyFormatted)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
    }
}
