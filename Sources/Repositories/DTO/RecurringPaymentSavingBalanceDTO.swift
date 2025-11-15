import Foundation

/// RecurringPaymentSavingBalanceのDTO（Sendable）
internal struct RecurringPaymentSavingBalanceDTO: Sendable {
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

    internal init(from balance: RecurringPaymentSavingBalance) {
        self.id = balance.id
        self.definitionId = balance.definition.id
        self.totalSavedAmount = balance.totalSavedAmount
        self.totalPaidAmount = balance.totalPaidAmount
        self.lastUpdatedYear = balance.lastUpdatedYear
        self.lastUpdatedMonth = balance.lastUpdatedMonth
        self.createdAt = balance.createdAt
        self.updatedAt = balance.updatedAt
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
