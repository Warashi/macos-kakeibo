import Foundation
import SwiftUI

/// 年次特別枠パネル
///
/// 対象年の設定と使用状況を表示します。
internal struct AnnualBudgetPanel: View {
    internal let year: Int
    internal let config: AnnualBudgetConfigDTO?
    internal let usage: AnnualBudgetUsage?
    internal let categories: [Category]
    internal let onEdit: () -> Void

    internal var body: some View {
        Card(title: "年次特別枠") {
            VStack(alignment: .leading, spacing: 16) {
                header

                if let content {
                    summarySection(summary: content.summary)
                    Table(content.rows) {
                        TableColumn("カテゴリ") { row in
                            Text(row.title)
                                .fontWeight(row.isOverall ? .semibold : .regular)
                                .foregroundColor(row.isOverall ? .primary : .secondary)
                        }
                        TableColumn("ポリシー") { row in
                            Text(row.policyDisplayName)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        TableColumn("設定額") { row in
                            Text(row.budgetAmount.currencyFormatted)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        TableColumn("使用済み") { row in
                            Text(row.actualAmount.currencyFormatted)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        TableColumn("残額") { row in
                            Text(row.remainingAmount.currencyFormatted)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .foregroundColor(row.isOverBudget ? .error : .success)
                        }
                        TableColumn("使用率") { row in
                            Text(percentageText(row.usageRate))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .foregroundColor(row.isOverBudget ? .error : .primary)
                        }
                    }
                    .frame(minHeight: 200)
                } else {
                    ContentUnavailableView {
                        Label("年次特別枠が未設定です", systemImage: "calendar")
                            .font(.title2)
                    } description: {
                        Text("\(year.yearDisplayString)年の年次特別枠を作成すると配分一覧が表示されます。")
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("\(year.yearDisplayString)年の設定")
                .font(.headline)

            Spacer()

            Button {
                onEdit()
            } label: {
                Label(
                    config == nil ? "設定を作成" : "設定を編集",
                    systemImage: config == nil ? "plus" : "slider.horizontal.3",
                )
            }
        }
    }

    @ViewBuilder
    private func summarySection(summary: AnnualBudgetPanelSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ProgressBar(
                progress: summary.usageRate,
                style: summary.usageRate >= 1.0 ? .danger : .custom(.info),
                showLabel: false,
            )

            HStack(alignment: .top, spacing: 24) {
                summaryItem(title: "総額", value: summary.totalAmount.currencyFormatted)
                summaryItem(title: "使用済み", value: summary.usedAmount.currencyFormatted)
                summaryItem(
                    title: "残額",
                    value: summary.remainingAmount.currencyFormatted,
                    isDanger: summary.remainingAmount < 0,
                )
                summaryItem(title: "使用率", value: percentageText(summary.usageRate))
                summaryItem(title: "充当ポリシー", value: summary.policyName)
            }
        }
    }

    @ViewBuilder
    private func summaryItem(title: String, value: String, isDanger: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
                .foregroundColor(isDanger ? .error : .primary)
        }
    }

    private func percentageText(_ rate: Double) -> String {
        String(format: "%.0f%%", rate * 100)
    }

    private var content: AnnualBudgetPanelContent? {
        guard let config else { return nil }
        return AnnualBudgetPanelContentBuilder.build(
            config: config,
            usage: usage,
            categories: categories,
        )
    }
}

// MARK: - Content Builder

internal struct AnnualBudgetPanelContent {
    internal let summary: AnnualBudgetPanelSummary
    internal let rows: [AnnualBudgetPanelRow]
}

internal struct AnnualBudgetPanelSummary {
    internal let totalAmount: Decimal
    internal let usedAmount: Decimal
    internal let remainingAmount: Decimal
    internal let usageRate: Double
    internal let policyName: String
}

internal struct AnnualBudgetPanelRow: Identifiable {
    internal let id: UUID
    internal let title: String
    internal let policyDisplayName: String
    internal let budgetAmount: Decimal
    internal let actualAmount: Decimal
    internal let remainingAmount: Decimal
    internal let usageRate: Double
    internal let isOverall: Bool

    internal var isOverBudget: Bool {
        remainingAmount < 0
    }
}

internal enum AnnualBudgetPanelContentBuilder {
    internal static func build(
        config: AnnualBudgetConfigDTO,
        usage: AnnualBudgetUsage?,
        categories: [Category],
    ) -> AnnualBudgetPanelContent {
        let categoryLookup = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        let usedAmount = usage?.usedAmount ?? 0
        let remainingAmount = usage?.remainingAmount ?? (config.totalAmount - usedAmount)
        let summary = AnnualBudgetPanelSummary(
            totalAmount: config.totalAmount,
            usedAmount: usedAmount,
            remainingAmount: remainingAmount,
            usageRate: decimalUsageRate(
                actualAmount: usedAmount,
                budgetAmount: config.totalAmount,
            ),
            policyName: config.policy.displayName,
        )

        let overallRow = AnnualBudgetPanelRow(
            id: config.id,
            title: "年次特別枠全体",
            policyDisplayName: config.policy.displayName,
            budgetAmount: config.totalAmount,
            actualAmount: usedAmount,
            remainingAmount: remainingAmount,
            usageRate: summary.usageRate,
            isOverall: true,
        )

        let allocationRows = sortedAllocations(config.allocations, categoryLookup: categoryLookup).map { allocation in
            let allocationUsage = usage?.categoryAllocations.first { $0.categoryId == allocation.categoryId }
            let actualAmount = allocationUsage?.allocatableAmount ?? 0
            let remainingAmount = allocationUsage?.annualBudgetRemainingAmount ?? (allocation.amount - actualAmount)
            let category = categoryLookup[allocation.categoryId]
            let categoryName = fullName(for: category, categoryLookup: categoryLookup)
            return AnnualBudgetPanelRow(
                id: allocation.id,
                title: categoryName,
                policyDisplayName: (allocation.policyOverride ?? config.policy).displayName,
                budgetAmount: allocation.amount,
                actualAmount: actualAmount,
                remainingAmount: remainingAmount,
                usageRate: allocationUsage?.annualBudgetUsageRate
                    ?? decimalUsageRate(actualAmount: actualAmount, budgetAmount: allocation.amount),
                isOverall: false,
            )
        }

        return AnnualBudgetPanelContent(
            summary: summary,
            rows: [overallRow] + allocationRows,
        )
    }

    private static func sortedAllocations(
        _ allocations: [AnnualBudgetAllocationDTO],
        categoryLookup: [UUID: Category],
    ) -> [AnnualBudgetAllocationDTO] {
        allocations.sorted { lhs, rhs in
            guard let lhsCategory = categoryLookup[lhs.categoryId],
                  let rhsCategory = categoryLookup[rhs.categoryId] else {
                return false
            }
            let lhsOrder = (
                lhsCategory.parentId.flatMap { categoryLookup[$0]?.displayOrder } ?? lhsCategory.displayOrder,
                lhsCategory.displayOrder,
                fullName(for: lhsCategory, categoryLookup: categoryLookup),
            )
            let rhsOrder = (
                rhsCategory.parentId.flatMap { categoryLookup[$0]?.displayOrder } ?? rhsCategory.displayOrder,
                rhsCategory.displayOrder,
                fullName(for: rhsCategory, categoryLookup: categoryLookup),
            )
            return lhsOrder < rhsOrder
        }
    }

    private static func fullName(for category: Category?, categoryLookup: [UUID: Category]) -> String {
        guard let category else { return "不明なカテゴリ" }
        if let parentId = category.parentId, let parent = categoryLookup[parentId] {
            return "\(parent.name) > \(category.name)"
        }
        return category.name
    }

    private static func decimalUsageRate(
        actualAmount: Decimal,
        budgetAmount: Decimal,
    ) -> Double {
        guard budgetAmount > 0 else { return 0 }
        return NSDecimalNumber(decimal: actualAmount)
            .dividing(by: NSDecimalNumber(decimal: budgetAmount))
            .doubleValue
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
