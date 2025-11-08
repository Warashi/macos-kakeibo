import SwiftUI

/// 年次予算進捗カード
internal struct AnnualBudgetProgressCard: View {
    internal let year: Int
    internal let calculation: BudgetCalculation

    private var usagePercentage: String {
        String(format: "%.0f%%", calculation.usageRate * 100)
    }

    internal var body: some View {
        Card(title: "年次予算進捗") {
            VStack(alignment: .leading, spacing: 16) {
                Text("\(year.yearDisplayString)年の予算進捗")
                    .font(.headline)

                ProgressView(
                    value: min(max(calculation.usageRate, 0), 1)
                )
                .tint(calculation.isOverBudget ? .red : .blue)

                HStack {
                    VStack(alignment: .leading) {
                        Text("予算")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(calculation.budgetAmount.currencyFormatted)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("実績")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(calculation.actualAmount.currencyFormatted)
                    }
                }

                HStack {
                    Text("残額: \(calculation.remainingAmount.currencyFormatted)")
                        .foregroundColor(calculation.isOverBudget ? .red : .green)
                    Spacer()
                    Text("使用率: \(usagePercentage)")
                        .foregroundColor(calculation.isOverBudget ? .red : .primary)
                }
                .font(.subheadline)
            }
            .padding(.vertical, 4)
        }
    }
}
