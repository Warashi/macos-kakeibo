import Foundation
import SwiftData

@Model
internal final class Transaction {
    internal var id: UUID

    /// 取引の基本情報
    internal var date: Date
    internal var title: String
    internal var amount: Decimal
    internal var memo: String

    /// フラグ
    internal var isIncludedInCalculation: Bool // 計算対象
    internal var isTransfer: Bool // 振替

    /// 外部インポート用識別子
    internal var importIdentifier: String?

    /// リレーション
    internal var financialInstitution: FinancialInstitutionEntity?
    internal var majorCategory: CategoryEntity? // 大項目
    internal var minorCategory: CategoryEntity? // 中項目

    /// 作成・更新日時
    internal var createdAt: Date
    internal var updatedAt: Date

    internal init(
        id: UUID = UUID(),
        date: Date,
        title: String,
        amount: Decimal,
        memo: String = "",
        isIncludedInCalculation: Bool = true,
        isTransfer: Bool = false,
        importIdentifier: String? = nil,
        financialInstitution: FinancialInstitutionEntity? = nil,
        majorCategory: CategoryEntity? = nil,
        minorCategory: CategoryEntity? = nil,
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.amount = amount
        self.memo = memo
        self.isIncludedInCalculation = isIncludedInCalculation
        self.isTransfer = isTransfer
        self.importIdentifier = importIdentifier
        self.financialInstitution = financialInstitution
        self.majorCategory = majorCategory
        self.minorCategory = minorCategory

        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }
}

// MARK: - Computed Properties

internal extension Transaction {
    /// 支出かどうか（金額がマイナス）
    var isExpense: Bool {
        amount < 0
    }

    /// 収入かどうか（金額がプラス）
    var isIncome: Bool {
        amount > 0
    }

    /// 絶対値での金額（表示用）
    var absoluteAmount: Decimal {
        abs(amount)
    }

    /// カテゴリのフルパス（例: "食費 / 外食"）
    var categoryFullName: String {
        if let minor = minorCategory {
            return minor.fullName
        } else if let major = majorCategory {
            return major.name
        }
        return "未分類"
    }
}

// MARK: - Validation

internal extension Transaction {
    /// データの検証
    func validate() -> [String] {
        var errors: [String] = []

        if title.isEmpty {
            errors.append("内容が空です")
        }

        if amount == 0 {
            errors.append("金額が0です")
        }

        // 中項目が設定されている場合、大項目も設定されているべき
        if minorCategory != nil, majorCategory == nil {
            errors.append("中項目が設定されていますが、大項目が未設定です")
        }

        // 中項目が設定されている場合、その親が大項目と一致しているべき
        if let minor = minorCategory, let major = majorCategory {
            if minor.parent != major {
                errors.append("中項目の親カテゴリと大項目が一致しません")
            }
        }

        return errors
    }

    /// データが有効かどうか
    var isValid: Bool {
        validate().isEmpty
    }
}
