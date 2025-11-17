import Foundation
import SwiftData

/// 定期支払いの積立残高
///
/// 各RecurringPaymentDefinitionごとの積立状況を記録し、
/// 月次積立額の累計と実績支払額を管理します。
@Model
internal final class SwiftDataRecurringPaymentSavingBalance {
    internal var id: UUID

    /// 対応する定期支払い定義
    internal var definition: SwiftDataRecurringPaymentDefinition

    /// 累計積立額
    internal var totalSavedAmount: Decimal

    /// 累計支払額（実績）
    internal var totalPaidAmount: Decimal

    /// 最終更新年月（年）
    internal var lastUpdatedYear: Int

    /// 最終更新年月（月）
    internal var lastUpdatedMonth: Int

    /// 作成・更新日時
    internal var createdAt: Date
    internal var updatedAt: Date

    internal init(
        id: UUID = UUID(),
        definition: SwiftDataRecurringPaymentDefinition,
        totalSavedAmount: Decimal = 0,
        totalPaidAmount: Decimal = 0,
        lastUpdatedYear: Int,
        lastUpdatedMonth: Int,
    ) {
        self.id = id
        self.definition = definition
        self.totalSavedAmount = totalSavedAmount
        self.totalPaidAmount = totalPaidAmount
        self.lastUpdatedYear = lastUpdatedYear
        self.lastUpdatedMonth = lastUpdatedMonth

        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }
}

// MARK: - Computed Properties

internal extension SwiftDataRecurringPaymentSavingBalance {
    /// 残高（積立額 - 支払額）
    var balance: Decimal {
        totalSavedAmount.safeSubtract(totalPaidAmount)
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

internal extension SwiftDataRecurringPaymentSavingBalance {
    func validate() -> [String] {
        var errors: [String] = []

        if totalSavedAmount < 0 {
            errors.append("累計積立額は0以上を設定してください")
        }

        if totalPaidAmount < 0 {
            errors.append("累計支払額は0以上を設定してください")
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
