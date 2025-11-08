import Foundation
import SwiftData

// MARK: - SpecialPaymentListEntry

/// 特別支払い一覧の表示用エントリ
internal struct SpecialPaymentListEntry: Identifiable, Sendable {
    // MARK: - Properties

    /// OccurrenceのID
    internal let id: UUID

    /// DefinitionのID
    internal let definitionId: UUID

    /// 名称
    internal let name: String

    /// カテゴリ
    internal let category: Category?

    /// 予定日
    internal let scheduledDate: Date

    /// 予定額
    internal let expectedAmount: Decimal

    /// 実績額
    internal let actualAmount: Decimal?

    /// ステータス
    internal let status: SpecialPaymentStatus

    /// 積立残高
    internal let savingsBalance: Decimal

    /// 進捗率（0.0〜1.0）
    internal let savingsProgress: Double

    /// 残日数
    internal let daysUntilDue: Int

    /// 紐付けられた取引
    internal let transaction: Transaction?

    /// 差異アラート
    internal let hasDiscrepancy: Bool

    // MARK: - Computed Properties

    /// 期限超過フラグ
    internal var isOverdue: Bool {
        daysUntilDue < 0 && status != .completed
    }

    /// 積立完了フラグ
    internal var isFullySaved: Bool {
        savingsProgress >= 1.0
    }

    /// 差異金額（実績額が予定額と異なる場合）
    internal var discrepancyAmount: Decimal? {
        guard let actualAmount else { return nil }
        let diff = actualAmount.safeSubtract(expectedAmount)
        return diff != 0 ? diff : nil
    }

    // MARK: - Initialization

    internal init(
        id: UUID,
        definitionId: UUID,
        name: String,
        category: Category?,
        scheduledDate: Date,
        expectedAmount: Decimal,
        actualAmount: Decimal?,
        status: SpecialPaymentStatus,
        savingsBalance: Decimal,
        savingsProgress: Double,
        daysUntilDue: Int,
        transaction: Transaction?,
        hasDiscrepancy: Bool,
    ) {
        self.id = id
        self.definitionId = definitionId
        self.name = name
        self.category = category
        self.scheduledDate = scheduledDate
        self.expectedAmount = expectedAmount
        self.actualAmount = actualAmount
        self.status = status
        self.savingsBalance = savingsBalance
        self.savingsProgress = savingsProgress
        self.daysUntilDue = daysUntilDue
        self.transaction = transaction
        self.hasDiscrepancy = hasDiscrepancy
    }
}

// MARK: - Factory

internal extension SpecialPaymentListEntry {
    /// OccurrenceからEntryを生成
    /// - Parameters:
    ///   - occurrence: SpecialPaymentOccurrence
    ///   - balance: SpecialPaymentSavingBalance（積立残高）
    ///   - now: 基準日（残日数計算用）
    /// - Returns: SpecialPaymentListEntry
    static func from(
        occurrence: SpecialPaymentOccurrence,
        balance: SpecialPaymentSavingBalance?,
        now: Date = Date(),
    ) -> SpecialPaymentListEntry {
        let definition = occurrence.definition

        // 積立残高
        let savingsBalance = balance?.balance ?? 0

        // 進捗率
        let savingsProgress: Double
        if occurrence.expectedAmount > 0 {
            let progress = NSDecimalNumber(decimal: savingsBalance).doubleValue /
                NSDecimalNumber(decimal: occurrence.expectedAmount).doubleValue
            savingsProgress = min(1.0, max(0.0, progress))
        } else {
            savingsProgress = 0.0
        }

        // 残日数
        let daysUntilDue = Calendar.current.dateComponents(
            [.day],
            from: now,
            to: occurrence.scheduledDate,
        ).day ?? 0

        // 差異アラート
        let hasDiscrepancy: Bool = if let actualAmount = occurrence.actualAmount {
            actualAmount != occurrence.expectedAmount
        } else {
            false
        }

        return SpecialPaymentListEntry(
            id: occurrence.id,
            definitionId: definition.id,
            name: definition.name,
            category: definition.category,
            scheduledDate: occurrence.scheduledDate,
            expectedAmount: occurrence.expectedAmount,
            actualAmount: occurrence.actualAmount,
            status: occurrence.status,
            savingsBalance: savingsBalance,
            savingsProgress: savingsProgress,
            daysUntilDue: daysUntilDue,
            transaction: occurrence.transaction,
            hasDiscrepancy: hasDiscrepancy,
        )
    }
}
