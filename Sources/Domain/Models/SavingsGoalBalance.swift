import Foundation

/// ドメイン層で扱う貯蓄残高
internal struct SavingsGoalBalance: Sendable {
    internal let id: UUID
    internal let goalId: UUID
    internal let totalSavedAmount: Decimal
    internal let totalWithdrawnAmount: Decimal
    internal let lastUpdatedYear: Int
    internal let lastUpdatedMonth: Int
    internal let createdAt: Date
    internal let updatedAt: Date

    internal init(
        id: UUID,
        goalId: UUID,
        totalSavedAmount: Decimal,
        totalWithdrawnAmount: Decimal,
        lastUpdatedYear: Int,
        lastUpdatedMonth: Int,
        createdAt: Date,
        updatedAt: Date,
    ) {
        self.id = id
        self.goalId = goalId
        self.totalSavedAmount = totalSavedAmount
        self.totalWithdrawnAmount = totalWithdrawnAmount
        self.lastUpdatedYear = lastUpdatedYear
        self.lastUpdatedMonth = lastUpdatedMonth
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    internal var balance: Decimal {
        totalSavedAmount.safeSubtract(totalWithdrawnAmount)
    }

    internal var isBalanceInsufficient: Bool {
        balance < 0
    }

    internal var lastUpdatedYearMonthString: String {
        String(format: "%04d-%02d", lastUpdatedYear, lastUpdatedMonth)
    }
}
