import Foundation
import SwiftUI

// MARK: - Common Field Layout

internal struct LabeledField<Content: View>: View {
    internal let title: String
    @ViewBuilder internal let content: () -> Content

    internal var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            content()
        }
    }
}

// MARK: - Special Payment Row

internal struct RecurringPaymentRow: View {
    internal let definition: RecurringPaymentDefinition
    internal let categoryName: String?
    internal let onEdit: () -> Void
    internal let onDelete: () -> Void

    internal var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(definition.name)
                        .font(.headline)
                    if let categoryName {
                        Text(categoryName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.backgroundInfo, in: Capsule())
                    }
                }

                HStack(spacing: 16) {
                    Label(definition.amount.currencyFormatted, systemImage: "yensign.circle")
                    Label(definition.recurrenceDescription, systemImage: "arrow.clockwise")
                    Label(
                        definition.monthlySavingAmount.currencyFormatted + "/月",
                        systemImage: "chart.line.uptrend.xyaxis",
                    )
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if !definition.notes.isEmpty {
                    Text(definition.notes)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    onEdit()
                } label: {
                    Label("編集", systemImage: "pencil")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("削除", systemImage: "trash")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(8)
    }
}
