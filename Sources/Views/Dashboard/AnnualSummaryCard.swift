import SwiftUI

/// 年次総括カード
///
/// 今年の収入・支出・差引を表示します。
internal struct AnnualSummaryCard: View {
    internal let summary: AnnualSummary

    internal var body: some View {
        Card(title: "今年の総括") {
            HStack(spacing: 32) {
                summaryItem(
                    title: "収入",
                    amount: summary.totalIncome,
                    color: .blue,
                )

                summaryItem(
                    title: "支出",
                    amount: summary.totalExpense,
                    color: .red,
                )

                summaryItem(
                    title: "差引",
                    amount: summary.net,
                    color: summary.net >= 0 ? .green : .orange,
                )

                summaryItem(
                    title: "取引件数",
                    count: summary.transactionCount,
                    color: .gray,
                )
            }
            .padding()
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

    @ViewBuilder
    private func summaryItem(
        title: String,
        count: Int,
        color: Color,
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text("\(count)件")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
    }
}
