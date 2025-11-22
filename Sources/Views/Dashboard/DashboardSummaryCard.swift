import SwiftUI

/// ダッシュボード共通の総括カード
internal struct DashboardSummaryCard: View {
    internal let displayMode: DashboardStore.DisplayMode
    internal let monthlySummary: MonthlySummary
    internal let annualSummary: AnnualSummary
    internal let monthlyBudgetCalculation: MonthlyBudgetCalculation
    internal let annualBudgetProgress: BudgetCalculation?

    private var title: String {
        displayMode == .monthly ? "今月の総括" : "今年の総括"
    }

    internal var body: some View {
        Card(title: title) {
            VStack(spacing: 20) {
                summaryMetrics
                Divider()
                budgetProgressSection
            }
            .padding()
        }
    }

    @ViewBuilder
    private var summaryMetrics: some View {
        HStack(spacing: 32) {
            ForEach(Array(summaryMetricData.enumerated()), id: \.offset) { item in
                if let amount = item.element.amount {
                    summaryItem(
                        title: item.element.title,
                        amount: amount,
                        color: item.element.color,
                    )
                } else if let text = item.element.text {
                    summaryItem(
                        title: item.element.title,
                        text: text,
                        color: item.element.color,
                    )
                }
            }
        }
    }

    private var summaryMetricData: [SummaryMetric] {
        var items: [SummaryMetric] = [
            SummaryMetric(
                title: "収入",
                amount: displayMode == .monthly ? monthlySummary.totalIncome : annualSummary.totalIncome,
                color: .income,
            ),
            SummaryMetric(
                title: "支出",
                amount: displayMode == .monthly ? monthlySummary.totalExpense : annualSummary.totalExpense,
                color: .expense,
            ),
            SummaryMetric(
                title: "貯蓄",
                amount: displayMode == .monthly ? monthlySummary.totalSavings : annualSummary.totalSavings,
                color: .info,
            ),
            SummaryMetric(
                title: "差引",
                amount: displayMode == .monthly ? monthlySummary.net : annualSummary.net,
                color: (displayMode == .monthly ? monthlySummary.net : annualSummary.net) >= 0 ? .positive : .negative,
            ),
        ]

        if displayMode == .annual {
            items.append(
                SummaryMetric(
                    title: "取引件数",
                    text: "\(annualSummary.transactionCount)件",
                    color: .neutral,
                ),
            )
        }

        return items
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
        text: String,
        color: Color,
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(text)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
    }

    @ViewBuilder
    private var budgetProgressSection: some View {
        if displayMode == .monthly,
           let overall = monthlyBudgetCalculation.overallCalculation {
            BudgetProgressView(
                title: "月次予算の進捗",
                calculation: overall,
            )
        } else if displayMode == .annual,
                  let annualBudgetProgress {
            BudgetProgressView(
                title: "年間予算の進捗",
                calculation: annualBudgetProgress,
            )
        } else {
            ContentUnavailableView(
                "予算は未設定です",
                systemImage: "exclamationmark.triangle",
            )
            .font(.subheadline)
        }
    }
}

private struct BudgetProgressView: View {
    internal let title: String
    internal let calculation: BudgetCalculation

    private var usagePercentage: String {
        "\(Int(calculation.usageRate * 100))%"
    }

    internal var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text("予算 \(calculation.budgetAmount.currencyFormatted)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ProgressBar(
                progress: calculation.usageRate,
                style: calculation.isOverBudget ? .danger : .custom(.info),
                showLabel: false,
            )

            HStack {
                VStack(alignment: .leading) {
                    Text("実績")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(calculation.actualAmount.currencyFormatted)
                        .fontWeight(.semibold)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text(calculation.isOverBudget ? "超過額" : "残額")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(abs(calculation.remainingAmount).currencyFormatted)
                        .fontWeight(.semibold)
                        .foregroundColor(calculation.isOverBudget ? .error : .success)
                }
            }

            Text("使用率 \(usagePercentage)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(calculation.isOverBudget ? .error : .primary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

private struct SummaryMetric {
    internal let title: String
    internal let amount: Decimal?
    internal let text: String?
    internal let color: Color

    internal init(
        title: String,
        amount: Decimal,
        color: Color,
    ) {
        self.title = title
        self.amount = amount
        self.text = nil
        self.color = color
    }

    internal init(
        title: String,
        text: String,
        color: Color,
    ) {
        self.title = title
        self.amount = nil
        self.text = text
        self.color = color
    }
}
