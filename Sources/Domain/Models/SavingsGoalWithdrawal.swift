import Foundation

/// ドメイン層で扱う貯蓄引出記録
internal struct SavingsGoalWithdrawal: Sendable {
    internal let id: UUID
    internal let goalId: UUID
    internal let amount: Decimal
    internal let withdrawalDate: Date
    internal let purpose: String?
    internal let transactionId: UUID?
    internal let createdAt: Date
    internal let updatedAt: Date

    internal init(
        id: UUID,
        goalId: UUID,
        amount: Decimal,
        withdrawalDate: Date,
        purpose: String?,
        transactionId: UUID?,
        createdAt: Date,
        updatedAt: Date,
    ) {
        self.id = id
        self.goalId = goalId
        self.amount = amount
        self.withdrawalDate = withdrawalDate
        self.purpose = purpose
        self.transactionId = transactionId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    internal func validate() -> [String] {
        var errors: [String] = []

        if amount <= 0 {
            errors.append("引出額は0より大きい必要があります")
        }

        return errors
    }

    internal var isValid: Bool {
        validate().isEmpty
    }
}
