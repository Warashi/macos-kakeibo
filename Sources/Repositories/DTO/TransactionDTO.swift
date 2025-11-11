import Foundation

/// 取引のDTO（Sendable）
internal struct TransactionDTO: Sendable {
    internal let id: UUID
    internal let date: Date
    internal let title: String
    internal let amount: Decimal
    internal let memo: String
    internal let isIncludedInCalculation: Bool
    internal let isTransfer: Bool
    internal let financialInstitutionId: UUID?
    internal let majorCategoryId: UUID?
    internal let minorCategoryId: UUID?
    internal let createdAt: Date
    internal let updatedAt: Date

    internal init(
        id: UUID,
        date: Date,
        title: String,
        amount: Decimal,
        memo: String,
        isIncludedInCalculation: Bool,
        isTransfer: Bool,
        financialInstitutionId: UUID?,
        majorCategoryId: UUID?,
        minorCategoryId: UUID?,
        createdAt: Date,
        updatedAt: Date,
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.amount = amount
        self.memo = memo
        self.isIncludedInCalculation = isIncludedInCalculation
        self.isTransfer = isTransfer
        self.financialInstitutionId = financialInstitutionId
        self.majorCategoryId = majorCategoryId
        self.minorCategoryId = minorCategoryId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    internal init(from transaction: Transaction) {
        self.id = transaction.id
        self.date = transaction.date
        self.title = transaction.title
        self.amount = transaction.amount
        self.memo = transaction.memo
        self.isIncludedInCalculation = transaction.isIncludedInCalculation
        self.isTransfer = transaction.isTransfer
        self.financialInstitutionId = transaction.financialInstitution?.id
        self.majorCategoryId = transaction.majorCategory?.id
        self.minorCategoryId = transaction.minorCategory?.id
        self.createdAt = transaction.createdAt
        self.updatedAt = transaction.updatedAt
    }

    internal var isIncome: Bool {
        amount > 0
    }

    internal var isExpense: Bool {
        amount < 0
    }

    internal var absoluteAmount: Decimal {
        abs(amount)
    }
}
