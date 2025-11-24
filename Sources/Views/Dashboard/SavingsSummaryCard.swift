import SwiftUI

/// 貯蓄サマリーカード
internal struct SavingsSummaryCard: View {
    internal let savingsSummary: SavingsSummary

    internal var body: some View {
        Card(title: "貯蓄目標") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("年間合計")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(formatCurrency(savingsSummary.yearToDateMonthlySavings))
                        .font(.headline)
                        .foregroundColor(.info)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                if savingsSummary.goalSummaries.isEmpty {
                    EmptyStatePlaceholder(
                        systemImage: "banknote",
                        title: "貯蓄目標なし",
                        message: "貯蓄目標が設定されていません",
                    )
                    .padding()
                } else {
                    ForEach(savingsSummary.goalSummaries, id: \.goalId) { goalSummary in
                        SavingsGoalSummaryRow(summary: goalSummary)
                            .padding(.horizontal)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(.vertical)
        }
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "JPY"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "¥0"
    }
}

/// 貯蓄目標サマリー行
private struct SavingsGoalSummaryRow: View {
    internal let summary: SavingsGoalSummary

    internal var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(summary.name)
                    .font(.subheadline)

                Spacer()

                Text(formatCurrency(summary.currentBalance))
                    .font(.subheadline)
                    .foregroundColor(summary.currentBalance >= 0 ? .primary : .error)
            }

            if let targetAmount = summary.targetAmount, targetAmount > 0 {
                ProgressBar(
                    progress: summary.progress,
                    style: .custom(.info),
                    showLabel: false,
                )

                HStack {
                    Text(String(format: "%.1f%%", summary.progress * 100))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("目標: \(formatCurrency(targetAmount))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "JPY"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "¥0"
    }
}
