import Foundation
import SwiftData

@Model
internal final class SwiftDataSavingsGoal {
    internal var id: UUID
    internal var name: String
    internal var targetAmount: Decimal?
    internal var monthlySavingAmount: Decimal
    internal var categoryId: UUID?
    internal var notes: String?
    internal var startDate: Date
    internal var targetDate: Date?
    internal var isActive: Bool
    internal var createdAt: Date
    internal var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \SwiftDataSavingsGoalBalance.goal)
    internal var balance: SwiftDataSavingsGoalBalance?

    @Relationship(deleteRule: .cascade, inverse: \SwiftDataSavingsGoalWithdrawal.goal)
    internal var withdrawals: [SwiftDataSavingsGoalWithdrawal]

    internal init(
        id: UUID = UUID(),
        name: String,
        targetAmount: Decimal?,
        monthlySavingAmount: Decimal,
        categoryId: UUID?,
        notes: String?,
        startDate: Date,
        targetDate: Date?,
        isActive: Bool,
    ) {
        self.id = id
        self.name = name
        self.targetAmount = targetAmount
        self.monthlySavingAmount = monthlySavingAmount
        self.categoryId = categoryId
        self.notes = notes
        self.startDate = startDate
        self.targetDate = targetDate
        self.isActive = isActive
        self.withdrawals = []

        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }
}

// MARK: - Computed Properties

internal extension SwiftDataSavingsGoal {
    var hasTargetDate: Bool {
        targetDate != nil
    }

    var hasTargetAmount: Bool {
        targetAmount != nil
    }
}

// MARK: - Validation

internal extension SwiftDataSavingsGoal {
    func validate() -> [String] {
        var errors: [String] = []

        if name.isEmpty {
            errors.append("名称は必須です")
        }
        if monthlySavingAmount < 0 {
            errors.append("月次積立額は0以上である必要があります")
        }
        if let targetAmount, targetAmount < 0 {
            errors.append("目標金額は0以上である必要があります")
        }
        if let targetDate, targetDate < startDate {
            errors.append("目標達成日は開始日以降である必要があります")
        }

        return errors
    }

    var isValid: Bool {
        validate().isEmpty
    }
}
