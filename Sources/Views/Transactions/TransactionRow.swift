import SwiftUI

internal struct TransactionRow: View {
    internal let transaction: TransactionDTO
    internal let categoryFullName: String
    internal let institutionName: String?
    internal let onEdit: (TransactionDTO) -> Void
    internal let onDelete: (UUID) -> Void

    private var accentColor: Color {
        transaction.isExpense ? .expense : .income
    }

    internal var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(transaction.date.longDateFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(transaction.title)
                    .font(.headline)

                if !transaction.memo.isEmpty {
                    Text(transaction.memo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Label(categoryFullName, systemImage: "folder")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let institutionName {
                        Label(institutionName, systemImage: "building.columns")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !transaction.isIncludedInCalculation {
                        TagView(text: "集計対象外")
                    }

                    if transaction.isTransfer {
                        TagView(text: "振替")
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(transaction.amount.currencyFormatted)
                    .font(.title3.bold())
                    .foregroundStyle(accentColor)

                Text(transaction.isExpense ? "支出" : "収入")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Menu {
                Button {
                    onEdit(transaction)
                } label: {
                    Label("編集", systemImage: "square.and.pencil")
                }

                Button(role: .destructive) {
                    onDelete(transaction.id)
                } label: {
                    Label("削除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .imageScale(.large)
                    .accessibilityLabel("操作")
            }
        }
        .padding(.vertical, 6)
    }
}

private struct TagView: View {
    internal let text: String

    internal var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.badgeBackgroundDefault))
    }
}
