import SwiftUI

/// 年次特別枠パネル
///
/// 対象年の設定と使用状況を表示します。
internal struct AnnualBudgetPanel: View {
    internal let year: Int
    internal let config: AnnualBudgetConfig?
    internal let usage: AnnualBudgetUsage?
    internal let onEdit: () -> Void

    internal var body: some View {
        Card(title: "年次特別枠") {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("\(year.yearDisplayString)年の設定")
                        .font(.headline)

                    Spacer()

                    Button {
                        onEdit()
                    } label: {
                        Label(config == nil ? "設定を作成" : "設定を編集", systemImage: "slider.horizontal.3")
                    }
                }

                if let config {
                    configSection(config: config)
                } else {
                    Text("年次特別枠はまだ設定されていません。")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func configSection(config: AnnualBudgetConfig) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            infoRow(title: "総額", value: config.totalAmount.currencyFormatted)
            infoRow(title: "充当ポリシー", value: config.policy.displayName)

            if config.allocations.isEmpty {
                Text("カテゴリ別の配分は設定されていません。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Divider()
                categoryTable(config.allocations)
            }

            if let usage {
                Divider()
                usageSection(usage: usage)
            }
        }
    }

    @ViewBuilder
    private func categoryTable(_ allocations: [AnnualBudgetAllocation]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("カテゴリ別配分")
                .font(.subheadline)
                .bold()

            Table(sortedAllocations(allocations)) {
                TableColumn("カテゴリ") { allocation in
                    Text(allocation.category.fullName)
                }

                TableColumn("金額") { allocation in
                    Text(allocation.amount.currencyFormatted)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .frame(minHeight: 120)
        }
    }

    private func sortedAllocations(
        _ allocations: [AnnualBudgetAllocation],
    ) -> [AnnualBudgetAllocation] {
        allocations.sorted { lhs, rhs in
            let lhsOrder = (
                lhs.category.parent?.displayOrder ?? lhs.category.displayOrder,
                lhs.category.displayOrder,
                lhs.category.fullName,
            )
            let rhsOrder = (
                rhs.category.parent?.displayOrder ?? rhs.category.displayOrder,
                rhs.category.displayOrder,
                rhs.category.fullName,
            )
            return lhsOrder < rhsOrder
        }
    }

    @ViewBuilder
    private func usageSection(usage: AnnualBudgetUsage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("使用状況")
                .font(.subheadline)
                .bold()

            ProgressBar(
                progress: usage.usageRate,
                style: usage.usageRate >= 1.0 ? .danger : .custom(.info),
                showLabel: false,
            )

            infoRow(title: "使用済み", value: usage.usedAmount.currencyFormatted)
            infoRow(title: "残額", value: usage.remainingAmount.currencyFormatted)

            if !usage.categoryAllocations.isEmpty {
                Divider()
                AnnualBudgetCategoryUsageTable(allocations: usage.categoryAllocations)
            }
        }
    }

    @ViewBuilder
    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.body)
        }
    }
}

// MARK: - Display Name

internal extension AnnualBudgetPolicy {
    var displayName: String {
        switch self {
        case .automatic:
            "自動充当"
        case .manual:
            "手動充当"
        case .fullCoverage:
            "全額年次特別枠"
        case .disabled:
            "使用しない"
        }
    }
}
