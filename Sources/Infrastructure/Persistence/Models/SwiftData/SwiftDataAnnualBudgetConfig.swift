import Foundation
import SwiftData

// MARK: - 年次特別枠設定

@Model
internal final class SwiftDataAnnualBudgetConfig {
    internal var id: UUID

    /// 対象年
    internal var year: Int

    /// 年次特別枠の総額
    internal var totalAmount: Decimal

    /// 充当ポリシー
    internal var policyRawValue: String

    /// カテゴリ別配分
    @Relationship(deleteRule: .cascade, inverse: \SwiftDataAnnualBudgetAllocation.config)
    internal var allocations: [SwiftDataAnnualBudgetAllocation]

    /// 作成・更新日時
    internal var createdAt: Date
    internal var updatedAt: Date

    internal init(
        id: UUID = UUID(),
        year: Int,
        totalAmount: Decimal,
        policy: AnnualBudgetPolicy = .automatic,
    ) {
        self.id = id
        self.year = year
        self.totalAmount = totalAmount
        self.policyRawValue = policy.rawValue
        self.allocations = []

        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }

    /// 充当ポリシー（computed property）
    internal var policy: AnnualBudgetPolicy {
        get {
            AnnualBudgetPolicy(rawValue: policyRawValue) ?? .automatic
        }
        set {
            policyRawValue = newValue.rawValue
        }
    }
}

internal extension SwiftDataAnnualBudgetConfig {
    /// データの検証
    func validate() -> [String] {
        var errors: [String] = []

        if totalAmount <= 0 {
            errors.append("年次特別枠の総額は0より大きい値を設定してください")
        }

        if year < 2000 || year > 2100 {
            errors.append("年が不正です")
        }

        return errors
    }

    /// データが有効かどうか
    var isValid: Bool {
        validate().isEmpty
    }

    /// カテゴリ配分の合計
    var allocationTotalAmount: Decimal {
        allocations.reduce(0) { $0 + $1.amount }
    }

    func fullCoverageCategoryIDs(
        includingChildrenFrom categories: [SwiftDataCategory] = []
    ) -> Set<UUID> {
        guard !allocations.isEmpty else { return [] }

        let fallbackChildren = Dictionary(grouping: categories, by: { $0.parent?.id })
        var identifiers: Set<UUID> = []

        for allocation in allocations {
            let effectivePolicy = allocation.policyOverride ?? policy
            guard effectivePolicy == .fullCoverage else { continue }
            let category = allocation.category
            identifiers.insert(category.id)

            guard category.isMajor else { continue }
            let directChildren = category.children
            if !directChildren.isEmpty {
                identifiers.formUnion(directChildren.map(\.id))
            } else if let fallback = fallbackChildren[category.id] {
                identifiers.formUnion(fallback.map(\.id))
            }
        }

        return identifiers
    }
}
