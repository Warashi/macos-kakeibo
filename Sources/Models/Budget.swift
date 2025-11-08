import Foundation
import SwiftData

/// 予算タイプ
internal enum BudgetType: String, Codable {
    case monthly // 月次予算
    case annual // 年次特別枠
}

/// 年次特別枠の充当ポリシー
internal enum AnnualBudgetPolicy: String, Codable {
    case automatic // 自動充当
    case manual // 手動充当
    case disabled // 無効
}

/// 月次予算
@Model
internal final class Budget {
    internal var id: UUID

    /// 予算額
    internal var amount: Decimal

    /// 対象カテゴリ（nilの場合は全体）
    internal var category: Category?

    /// 対象年月
    internal var year: Int
    internal var month: Int

    /// 作成・更新日時
    internal var createdAt: Date
    internal var updatedAt: Date

    internal init(
        id: UUID = UUID(),
        amount: Decimal,
        category: Category? = nil,
        year: Int,
        month: Int,
    ) {
        self.id = id
        self.amount = amount
        self.category = category
        self.year = year
        self.month = month

        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }
}

// MARK: - Computed Properties

internal extension Budget {
    /// 年月の文字列表現（例: "2025-11"）
    var yearMonthString: String {
        String(format: "%04d-%02d", year, month)
    }

    /// 年月のDate表現（その月の1日）
    var targetDate: Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        return Calendar.current.date(from: components) ?? Date()
    }
}

// MARK: - Validation

internal extension Budget {
    /// データの検証
    func validate() -> [String] {
        var errors: [String] = []

        if amount <= 0 {
            errors.append("予算額は0より大きい値を設定してください")
        }

        if year < 2000 || year > 2100 {
            errors.append("年が不正です")
        }

        if month < 1 || month > 12 {
            errors.append("月が不正です（1-12の範囲で設定してください）")
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
internal final class AnnualBudgetConfig {
    internal var id: UUID

    /// 対象年
    internal var year: Int

    /// 年次特別枠の総額
    internal var totalAmount: Decimal

    /// 充当ポリシー
    internal var policyRawValue: String

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

internal extension AnnualBudgetConfig {
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
