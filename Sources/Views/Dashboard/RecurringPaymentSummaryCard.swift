import SwiftUI

/// 定期支払いサマリーカード
internal struct RecurringPaymentSummaryCard: View {
    internal let recurringPaymentSummary: RecurringPaymentSummary

    internal var body: some View {
        Card(title: "定期支払い") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("年間合計")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(formatCurrency(recurringPaymentSummary.yearToDateMonthlyAmount))
                        .font(.headline)
                        .foregroundColor(.info)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    SummaryRow(
                        label: "当月予定",
                        amount: recurringPaymentSummary.currentMonthExpected,
                        color: .secondary,
                    )

                    SummaryRow(
                        label: "当月実績",
                        amount: recurringPaymentSummary.currentMonthActual,
                        color: .primary,
                    )

                    SummaryRow(
                        label: "未払い分",
                        amount: recurringPaymentSummary.currentMonthRemaining,
                        color: recurringPaymentSummary.currentMonthRemaining > 0 ? .warning : .success,
                    )
                }
                .padding(.horizontal)

                if !recurringPaymentSummary.definitions.isEmpty {
                    Divider()
                        .padding(.horizontal)

                    ForEach(recurringPaymentSummary.definitions, id: \.definitionId) { definition in
                        RecurringPaymentDefinitionRow(summary: definition)
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

/// サマリー行
private struct SummaryRow: View {
    internal let label: String
    internal let amount: Decimal
    internal let color: Color

    internal var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(formatCurrency(amount))
                .font(.subheadline)
                .foregroundColor(color)
        }
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "JPY"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "¥0"
    }
}

/// 定期支払い定義行
private struct RecurringPaymentDefinitionRow: View {
    internal let summary: RecurringPaymentDefinitionSummary

    internal var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(summary.name)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if let occurrence = summary.currentMonthOccurrence {
                    if occurrence.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.success)
                            .font(.caption)
                    } else {
                        Text(formatCurrency(occurrence.expectedAmount))
                            .font(.caption)
                            .foregroundColor(.warning)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "JPY"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "¥0"
    }
}
