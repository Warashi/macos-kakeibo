import SwiftUI

/// 貯蓄目標一覧の行
internal struct SavingsGoalRow: View {
    internal let goal: SavingsGoal
    internal let balance: SavingsGoalBalance?
    internal let onToggleActive: () -> Void
    internal let onEdit: () -> Void
    internal let onDelete: () -> Void

    internal var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(goal.name)
                    .font(.headline)

                Spacer()

                if !goal.isActive {
                    Text("無効")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
            }

            HStack {
                Text("月次積立")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(formatCurrency(goal.monthlySavingAmount))
                    .font(.subheadline)

                Spacer()

                if let balance {
                    VStack(alignment: .trailing) {
                        Text("残高")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(formatCurrency(balance.balance))
                            .font(.subheadline)
                            .foregroundColor(balance.balance >= 0 ? .primary : .red)
                    }
                }
            }

            if let targetAmount = goal.targetAmount {
                ProgressView(value: progressValue) {
                    HStack {
                        Text("目標")
                        Spacer()
                        Text(formatCurrency(targetAmount))
                    }
                    .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("削除", systemImage: "trash")
            }

            Button {
                onEdit()
            } label: {
                Label("編集", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .contextMenu {
            Button {
                onToggleActive()
            } label: {
                Label(
                    goal.isActive ? "無効化" : "有効化",
                    systemImage: goal.isActive ? "pause.circle" : "play.circle",
                )
            }

            Button {
                onEdit()
            } label: {
                Label("編集", systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
    }

    private var progressValue: Double {
        guard let targetAmount = goal.targetAmount,
              let balance,
              targetAmount > 0 else {
            return 0
        }

        let current = NSDecimalNumber(decimal: balance.balance).doubleValue
        let target = NSDecimalNumber(decimal: targetAmount).doubleValue

        return min(1.0, current / target)
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "JPY"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "¥0"
    }
}
