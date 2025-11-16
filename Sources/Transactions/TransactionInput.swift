import Foundation

/// 取引の永続化入力
internal struct TransactionInput: Sendable {
    internal let date: Date
    internal let title: String
    internal let memo: String
    internal let amount: Decimal
    internal let isIncludedInCalculation: Bool
    internal let isTransfer: Bool
    internal let financialInstitutionId: UUID?
    internal let majorCategoryId: UUID?
    internal let minorCategoryId: UUID?
    internal let importIdentifier: String?

    internal init(
        date: Date,
        title: String,
        memo: String,
        amount: Decimal,
        isIncludedInCalculation: Bool,
        isTransfer: Bool,
        financialInstitutionId: UUID?,
        majorCategoryId: UUID?,
        minorCategoryId: UUID?,
        importIdentifier: String? = nil
    ) {
        self.date = date
        self.title = title
        self.memo = memo
        self.amount = amount
        self.isIncludedInCalculation = isIncludedInCalculation
        self.isTransfer = isTransfer
        self.financialInstitutionId = financialInstitutionId
        self.majorCategoryId = majorCategoryId
        self.minorCategoryId = minorCategoryId
        self.importIdentifier = importIdentifier
    }
}

/// 取引更新の入力
internal struct TransactionUpdateInput: Sendable {
    internal let id: UUID
    internal let input: TransactionInput

    internal init(id: UUID, input: TransactionInput) {
        self.id = id
        self.input = input
    }
}
