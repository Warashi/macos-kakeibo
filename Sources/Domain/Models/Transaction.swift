import Foundation

/// ドメイン層で扱う取引モデル
internal struct Transaction: Sendable, Hashable, Equatable {
    internal let id: UUID
    internal let date: Date
    internal let title: String
    internal let amount: Decimal
    internal let memo: String
    internal let isIncludedInCalculation: Bool
    internal let isTransfer: Bool
    internal let importIdentifier: String?
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
        importIdentifier: String?,
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
        self.importIdentifier = importIdentifier
        self.financialInstitutionId = financialInstitutionId
        self.majorCategoryId = majorCategoryId
        self.minorCategoryId = minorCategoryId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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
