import Foundation
import SwiftData

/// 貯蓄残高
///
/// 各SavingsGoalごとの積立状況を記録し、
/// 月次積立額の累計と引出額を管理します。
@Model
internal final class SwiftDataSavingsGoalBalance {
    internal var id: UUID

    /// 対応する貯蓄目標
    internal var goal: SwiftDataSavingsGoal

    /// 累計積立額
    internal var totalSavedAmount: Decimal

    /// 累計引出額
    internal var totalWithdrawnAmount: Decimal

    /// 最終更新年月（年）
    internal var lastUpdatedYear: Int

    /// 最終更新年月（月）
    internal var lastUpdatedMonth: Int

    /// 作成・更新日時
    internal var createdAt: Date
    internal var updatedAt: Date

    internal init(
        id: UUID = UUID(),
        goal: SwiftDataSavingsGoal,
        totalSavedAmount: Decimal = 0,
        totalWithdrawnAmount: Decimal = 0,
        lastUpdatedYear: Int,
        lastUpdatedMonth: Int,
    ) {
        self.id = id
        self.goal = goal
        self.totalSavedAmount = totalSavedAmount
        self.totalWithdrawnAmount = totalWithdrawnAmount
        self.lastUpdatedYear = lastUpdatedYear
        self.lastUpdatedMonth = lastUpdatedMonth

        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }
}

// MARK: - Computed Properties

internal extension SwiftDataSavingsGoalBalance {
    /// 残高（積立額 - 引出額）
    var balance: Decimal {
        totalSavedAmount.safeSubtract(totalWithdrawnAmount)
    }

    /// 残高が不足しているか（マイナス残高）
    var isBalanceInsufficient: Bool {
        balance < 0
    }

    /// 最終更新年月の文字列表現（例: "2025-11"）
    var lastUpdatedYearMonthString: String {
        String(format: "%04d-%02d", lastUpdatedYear, lastUpdatedMonth)
    }
}

// MARK: - Validation

internal extension SwiftDataSavingsGoalBalance {
    func validate() -> [String] {
        var errors: [String] = []

        if totalSavedAmount < 0 {
            errors.append("累計積立額は0以上を設定してください")
        }

        if totalWithdrawnAmount < 0 {
            errors.append("累計引出額は0以上を設定してください")
        }

        if lastUpdatedYear < 2000 || lastUpdatedYear > 2100 {
            errors.append("最終更新年が不正です")
        }

        if lastUpdatedMonth < 1 || lastUpdatedMonth > 12 {
            errors.append("最終更新月が不正です（1-12の範囲で設定してください）")
        }

        return errors
    }

    var isValid: Bool {
        validate().isEmpty
    }
}

// MARK: - Domain Conversion

internal extension SwiftDataSavingsGoalBalance {
    func toDomain() -> SavingsGoalBalance {
        SavingsGoalBalance(from: self)
    }
}
