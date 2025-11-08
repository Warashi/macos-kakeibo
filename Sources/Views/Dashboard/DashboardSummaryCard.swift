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
        let summaries: [(String, Decimal, Color)]

        if displayMode == .monthly {
            summaries = [
                ("収入", monthlySummary.totalIncome, .blue),
                ("支出", monthlySummary.totalExpense, .red),
                ("差引", monthlySummary.net, monthlySummary.net >= 0 ? .green : .orange),
            ]
        } else {
            summaries = [
                ("収入", annualSummary.totalIncome, .blue),
                ("支出", annualSummary.totalExpense, .red),
                ("差引", annualSummary.net, annualSummary.net >= 0 ? .green : .orange),
            ]
        }

        HStack(spacing: 32) {
            ForEach(Array(summaries.enumerated()), id: \.offset) { item in
                summaryItem(
                    title: item.element.0,
                    amount: item.element.1,
                    color: item.element.2
                )
            }

            if displayMode == .annual {
                summaryItem(
                    title: "取引件数",
                    text: "\(annualSummary.transactionCount)件",
                    color: .gray
                )
            }
        }
    }

    @ViewBuilder
    private func summaryItem(
        title: String,
        amount: Decimal,
        color: Color
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
        color: Color
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
                calculation: overall
            )
        } else if displayMode == .annual,
                  let annualBudgetProgress {
            BudgetProgressView(
                title: "年間予算の進捗",
                calculation: annualBudgetProgress
            )
        } else {
            ContentUnavailableView(
                "予算は未設定です",
                systemImage: "exclamationmark.triangle"
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
                style: calculation.isOverBudget ? .danger : .custom(.blue),
                showLabel: false
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
                        .foregroundColor(calculation.isOverBudget ? .red : .green)
                }
            }

            Text("使用率 \(usagePercentage)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(calculation.isOverBudget ? .red : .primary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}
