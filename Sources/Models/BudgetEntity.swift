import Foundation
import SwiftData

/// 予算タイプ
internal enum BudgetType: String, Codable {
    case monthly // 月次予算
    case annual // 年次特別枠
}

/// 年次特別枠の充当ポリシー
internal enum AnnualBudgetPolicy: String, Codable, CaseIterable {
    case automatic // 予算超過分のみ自動充当
    case manual // 手動充当
    case fullCoverage // 特定カテゴリの支出を全額年次特別枠で処理
    case disabled // 無効
}

internal extension AnnualBudgetConfigEntity {
    func fullCoverageCategoryIDs(
        includingChildrenFrom categories: [CategoryEntity] = [],
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

/// 月次予算（期間指定）
@Model
internal final class BudgetEntity {
    internal var id: UUID

    /// 予算額
    internal var amount: Decimal

    /// 対象カテゴリ（nilの場合は全体）
    internal var category: CategoryEntity?

    /// 対象期間（開始年月）
    internal var startYear: Int
    internal var startMonth: Int

    /// 対象期間（終了年月）
    internal var endYear: Int
    internal var endMonth: Int

    /// 作成・更新日時
    internal var createdAt: Date
    internal var updatedAt: Date

    internal init(
        id: UUID = UUID(),
        amount: Decimal,
        category: CategoryEntity? = nil,
        startYear: Int,
        startMonth: Int,
        endYear: Int? = nil,
        endMonth: Int? = nil,
    ) {
        self.id = id
        self.amount = amount
        self.category = category
        self.startYear = startYear
        self.startMonth = startMonth

        let resolvedEndYear = endYear ?? startYear
        let resolvedEndMonth = endMonth ?? startMonth
        self.endYear = resolvedEndYear
        self.endMonth = resolvedEndMonth

        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }

    /// 単月指定のコンビニエンスイニシャライザ
    internal convenience init(
        id: UUID = UUID(),
        amount: Decimal,
        category: CategoryEntity? = nil,
        year: Int,
        month: Int,
    ) {
        self.init(
            id: id,
            amount: amount,
            category: category,
            startYear: year,
            startMonth: month,
            endYear: year,
            endMonth: month,
        )
    }
}

// MARK: - Computed Properties

internal extension BudgetEntity {
    /// 開始年月の文字列表現（例: "2025-11"）
    var yearMonthString: String {
        String(format: "%04d-%02d", startYear, startMonth)
    }

    /// 開始月のDate表現（その月の1日）
    var targetDate: Date {
        Date.from(year: startYear, month: startMonth) ?? Date()
    }

    /// 終了月のDate表現（その月の1日）
    var endDate: Date {
        Date.from(year: endYear, month: endMonth) ?? Date()
    }

    /// 期間の表示（例: "2025年1月〜2025年3月"）
    var periodDescription: String {
        if startYear == endYear, startMonth == endMonth {
            return "\(startYear)年\(startMonth)月"
        }
        return "\(startYear)年\(startMonth)月〜\(endYear)年\(endMonth)月"
    }

    /// 指定年月を含むかどうか
    func contains(year: Int, month: Int) -> Bool {
        let target = yearMonthIndex(year: year, month: month)
        return target >= startIndex && target <= endIndex
    }

    /// 指定年における有効月数
    func monthsActive(in year: Int) -> Int {
        let yearStart = yearMonthIndex(year: year, month: 1)
        let yearEnd = yearMonthIndex(year: year, month: 12)
        let start = max(startIndex, yearStart)
        let end = min(endIndex, yearEnd)
        if start > end {
            return 0
        }
        return end - start + 1
    }

    /// 総月数
    var totalMonthCount: Int {
        max(0, endIndex - startIndex + 1)
    }

    /// 指定年における合計予算額（月次金額 × 有効月数）
    func annualBudgetAmount(for year: Int) -> Decimal {
        Decimal(monthsActive(in: year)) * amount
    }

    /// 指定年と期間が重なるかどうか
    func overlaps(year: Int) -> Bool {
        monthsActive(in: year) > 0
    }

    private var startIndex: Int {
        yearMonthIndex(year: startYear, month: startMonth)
    }

    private var endIndex: Int {
        yearMonthIndex(year: endYear, month: endMonth)
    }

    private func yearMonthIndex(year: Int, month: Int) -> Int {
        (year * 12) + (month - 1)
    }
}

// MARK: - Validation

internal extension BudgetEntity {
    /// データの検証
    func validate() -> [String] {
        var errors: [String] = []

        if amount <= 0 {
            errors.append("予算額は0より大きい値を設定してください")
        }

        if startYear < 2000 || startYear > 2100 {
            errors.append("開始年が不正です")
        }

        if endYear < 2000 || endYear > 2100 {
            errors.append("終了年が不正です")
        }

        if startMonth < 1 || startMonth > 12 {
            errors.append("開始月が不正です（1-12の範囲で設定してください）")
        }

        if endMonth < 1 || endMonth > 12 {
            errors.append("終了月が不正です（1-12の範囲で設定してください）")
        }

        if startIndex > endIndex {
            errors.append("終了月は開始月以降を設定してください")
        }

        return errors
    }

    /// データが有効かどうか
    var isValid: Bool {
        validate().isEmpty
    }
}

// MARK: - 年次特別枠設定

@Model
internal final class AnnualBudgetConfigEntity {
    internal var id: UUID

    /// 対象年
    internal var year: Int

    /// 年次特別枠の総額
    internal var totalAmount: Decimal

    /// 充当ポリシー
    internal var policyRawValue: String

    /// カテゴリ別配分
    @Relationship(deleteRule: .cascade, inverse: \AnnualBudgetAllocation.config)
    internal var allocations: [AnnualBudgetAllocation]

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

// MARK: - Validation

internal extension AnnualBudgetConfigEntity {
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
}

// MARK: - Annual Budget Allocation

@Model
internal final class AnnualBudgetAllocation {
    internal var id: UUID
    internal var amount: Decimal
    internal var category: CategoryEntity
    internal var policyOverrideRawValue: String?

    internal var config: AnnualBudgetConfigEntity?

    internal var createdAt: Date
    internal var updatedAt: Date

    internal init(
        id: UUID = UUID(),
        amount: Decimal,
        category: CategoryEntity,
        policyOverride: AnnualBudgetPolicy? = nil,
    ) {
        self.id = id
        self.amount = amount
        self.category = category
        self.policyOverrideRawValue = policyOverride?.rawValue

        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }

    internal var policyOverride: AnnualBudgetPolicy? {
        get {
            guard let policyOverrideRawValue else { return nil }
            return AnnualBudgetPolicy(rawValue: policyOverrideRawValue)
        }
        set {
            policyOverrideRawValue = newValue?.rawValue
        }
    }
}

internal extension AnnualBudgetConfigEntity {
    /// カテゴリ配分の合計
    var allocationTotalAmount: Decimal {
        allocations.reduce(0) { $0 + $1.amount }
    }
}
