import SwiftUI

/// 月次総括カード
///
/// 今月の収入・支出・差引・予算使用率を表示します。
internal struct MonthlySummaryCard: View {
    internal let summary: MonthlySummary
    internal let budgetCalculation: MonthlyBudgetCalculation

    internal var body: some View {
        Card(title: "今月の総括") {
            VStack(spacing: 16) {
                // 収入・支出・差引
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
                }

                Divider()

                // 予算情報
                if let overallCalc = budgetCalculation.overallCalculation {
                    budgetSection(calculation: overallCalc)
                }
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
    private func budgetSection(calculation: BudgetCalculation) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("予算")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(calculation.budgetAmount.currencyFormatted)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ProgressBar(
                progress: calculation.usageRate,
                style: calculation.isOverBudget ? .danger : .custom(.blue),
                showLabel: false,
            )

            HStack {
                Text("使用率")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(Int(calculation.usageRate * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(calculation.isOverBudget ? .red : .primary)
            }

            HStack {
                Text(calculation.isOverBudget ? "超過" : "残額")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(abs(calculation.remainingAmount).currencyFormatted)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(calculation.isOverBudget ? .red : .green)
            }
        }
    }
}
