import Foundation

/// 貯蓄目標の入力パラメータ
internal struct SavingsGoalInput: Sendable {
    internal let name: String
    internal let targetAmount: Decimal?
    internal let monthlySavingAmount: Decimal
    internal let categoryId: UUID?
    internal let notes: String?
    internal let startDate: Date
    internal let targetDate: Date?

    internal init(
        name: String,
        targetAmount: Decimal? = nil,
        monthlySavingAmount: Decimal,
        categoryId: UUID? = nil,
        notes: String? = nil,
        startDate: Date,
        targetDate: Date? = nil,
    ) {
        self.name = name
        self.targetAmount = targetAmount
        self.monthlySavingAmount = monthlySavingAmount
        self.categoryId = categoryId
        self.notes = notes
        self.startDate = startDate
        self.targetDate = targetDate
    }
}

/// 貯蓄目標の更新パラメータ
internal struct SavingsGoalUpdateInput: Sendable {
    internal let id: UUID
    internal let input: SavingsGoalInput
}

/// 貯蓄目標引出の入力パラメータ
internal struct SavingsGoalWithdrawalInput: Sendable {
    internal let goalId: UUID
    internal let amount: Decimal
    internal let withdrawalDate: Date
    internal let purpose: String?
    internal let transactionId: UUID?

    internal init(
        goalId: UUID,
        amount: Decimal,
        withdrawalDate: Date,
        purpose: String? = nil,
        transactionId: UUID? = nil,
    ) {
        self.goalId = goalId
        self.amount = amount
        self.withdrawalDate = withdrawalDate
        self.purpose = purpose
        self.transactionId = transactionId
    }
}
