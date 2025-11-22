import Foundation
import SwiftData

@Model
internal final class SwiftDataSavingsGoalWithdrawal {
    internal var id: UUID
    internal var goalId: UUID
    internal var amount: Decimal
    internal var withdrawalDate: Date
    internal var purpose: String?

    @Relationship(deleteRule: .nullify)
    internal var transaction: SwiftDataTransaction?

    internal var createdAt: Date
    internal var updatedAt: Date

    // リレーションシップ（逆参照）
    internal var goal: SwiftDataSavingsGoal?

    internal init(
        id: UUID = UUID(),
        goal: SwiftDataSavingsGoal,
        amount: Decimal,
        withdrawalDate: Date,
        purpose: String?,
        transaction: SwiftDataTransaction? = nil,
    ) {
        self.id = id
        self.goalId = goal.id
        self.amount = amount
        self.withdrawalDate = withdrawalDate
        self.purpose = purpose
        self.transaction = transaction
        self.goal = goal

        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }
}

// MARK: - Validation

internal extension SwiftDataSavingsGoalWithdrawal {
    func validate() -> [String] {
        var errors: [String] = []

        if amount <= 0 {
            errors.append("引出額は0より大きい必要があります")
        }

        return errors
    }

    var isValid: Bool {
        validate().isEmpty
    }
}

// MARK: - Domain Conversion

internal extension SwiftDataSavingsGoalWithdrawal {
    func toDomain() -> SavingsGoalWithdrawal {
        SavingsGoalWithdrawal(from: self)
    }
}
