import Foundation

/// ドメイン層で扱う貯蓄目標
internal struct SavingsGoal: Sendable {
    internal let id: UUID
    internal let name: String
    internal let targetAmount: Decimal?
    internal let monthlySavingAmount: Decimal
    internal let categoryId: UUID?
    internal let notes: String?
    internal let startDate: Date
    internal let targetDate: Date?
    internal let isActive: Bool
    internal let createdAt: Date
    internal let updatedAt: Date

    internal init(
        id: UUID,
        name: String,
        targetAmount: Decimal?,
        monthlySavingAmount: Decimal,
        categoryId: UUID?,
        notes: String?,
        startDate: Date,
        targetDate: Date?,
        isActive: Bool,
        createdAt: Date,
        updatedAt: Date,
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
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    internal var hasTargetDate: Bool {
        targetDate != nil
    }

    internal var hasTargetAmount: Bool {
        targetAmount != nil
    }

    internal func validate() -> [String] {
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

    internal var isValid: Bool {
        validate().isEmpty
    }
}
