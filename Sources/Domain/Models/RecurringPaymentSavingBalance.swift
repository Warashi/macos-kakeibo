import Foundation

/// ドメイン層で扱う定期支払い積立残高
internal struct RecurringPaymentSavingBalance: Sendable {
    internal let id: UUID
    internal let definitionId: UUID
    internal let totalSavedAmount: Decimal
    internal let totalPaidAmount: Decimal
    internal let lastUpdatedYear: Int
    internal let lastUpdatedMonth: Int
    internal let createdAt: Date
    internal let updatedAt: Date

    internal init(
        id: UUID,
        definitionId: UUID,
        totalSavedAmount: Decimal,
        totalPaidAmount: Decimal,
        lastUpdatedYear: Int,
        lastUpdatedMonth: Int,
        createdAt: Date,
        updatedAt: Date,
    ) {
        self.id = id
        self.definitionId = definitionId
        self.totalSavedAmount = totalSavedAmount
        self.totalPaidAmount = totalPaidAmount
        self.lastUpdatedYear = lastUpdatedYear
        self.lastUpdatedMonth = lastUpdatedMonth
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    internal var balance: Decimal {
        totalSavedAmount.safeSubtract(totalPaidAmount)
    }

    internal var isBalanceInsufficient: Bool {
        balance < 0
    }

    internal var lastUpdatedYearMonthString: String {
        String(format: "%04d-%02d", lastUpdatedYear, lastUpdatedMonth)
    }
}
