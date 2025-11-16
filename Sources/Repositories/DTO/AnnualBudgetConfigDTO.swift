import Foundation

/// 年次特別枠設定のDTO（Sendable）
internal struct AnnualBudgetConfigDTO: Sendable, Hashable, Equatable {
    internal let id: UUID
    internal let year: Int
    internal let totalAmount: Decimal
    internal let policy: AnnualBudgetPolicy
    internal let allocations: [AnnualBudgetAllocationDTO]
    internal let createdAt: Date
    internal let updatedAt: Date

    internal init(
        id: UUID,
        year: Int,
        totalAmount: Decimal,
        policy: AnnualBudgetPolicy,
        allocations: [AnnualBudgetAllocationDTO],
        createdAt: Date,
        updatedAt: Date,
    ) {
        self.id = id
        self.year = year
        self.totalAmount = totalAmount
        self.policy = policy
        self.allocations = allocations
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    internal init(from config: AnnualBudgetConfig) {
        self.id = config.id
        self.year = config.year
        self.totalAmount = config.totalAmount
        self.policy = config.policy
        self.allocations = config.allocations.map { AnnualBudgetAllocationDTO(from: $0) }
        self.createdAt = config.createdAt
        self.updatedAt = config.updatedAt
    }

    /// カテゴリ配分の合計
    internal var allocationTotalAmount: Decimal {
        allocations.reduce(0) { $0 + $1.amount }
    }

    internal func fullCoverageCategoryIDs(
        includingChildrenFrom categories: [Category] = [],
    ) -> Set<UUID> {
        guard !allocations.isEmpty else { return [] }

        let fallbackChildren = Dictionary(grouping: categories, by: { $0.parentId })
        var identifiers: Set<UUID> = []

        for allocation in allocations {
            let effectivePolicy = allocation.policyOverride ?? policy
            guard effectivePolicy == .fullCoverage else { continue }
            let categoryId = allocation.categoryId
            identifiers.insert(categoryId)

            // カテゴリが大項目か判定
            guard let category = categories.first(where: { $0.id == categoryId }),
                  category.isMajor else { continue }

            // 子カテゴリを探す
            let directChildren = categories.filter { $0.parentId == categoryId }
            if !directChildren.isEmpty {
                identifiers.formUnion(directChildren.map(\.id))
            } else if let fallback = fallbackChildren[categoryId] {
                identifiers.formUnion(fallback.map(\.id))
            }
        }

        return identifiers
    }
}
