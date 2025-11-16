import Foundation

internal struct TransactionFormState: Equatable {
    internal var date: Date
    internal var title: String
    internal var memo: String
    internal var amountText: String
    internal var transactionKind: TransactionKind
    internal var isIncludedInCalculation: Bool
    internal var isTransfer: Bool
    internal var financialInstitutionId: UUID?
    internal var majorCategoryId: UUID?
    internal var minorCategoryId: UUID?

    internal static func empty(defaultDate: Date) -> TransactionFormState {
        TransactionFormState(
            date: defaultDate,
            title: "",
            memo: "",
            amountText: "",
            transactionKind: .expense,
            isIncludedInCalculation: true,
            isTransfer: false,
            financialInstitutionId: nil,
            majorCategoryId: nil,
            minorCategoryId: nil,
        )
    }

    internal static func from(transaction: TransactionEntity) -> TransactionFormState {
        TransactionFormState(
            date: transaction.date,
            title: transaction.title,
            memo: transaction.memo,
            amountText: Self.amountString(from: transaction.absoluteAmount),
            transactionKind: transaction.isExpense ? .expense : .income,
            isIncludedInCalculation: transaction.isIncludedInCalculation,
            isTransfer: transaction.isTransfer,
            financialInstitutionId: transaction.financialInstitution?.id,
            majorCategoryId: transaction.majorCategory?.id,
            minorCategoryId: transaction.minorCategory?.id,
        )
    }

    internal static func from(transaction: Transaction) -> TransactionFormState {
        TransactionFormState(
            date: transaction.date,
            title: transaction.title,
            memo: transaction.memo,
            amountText: Self.amountString(from: transaction.absoluteAmount),
            transactionKind: transaction.isExpense ? .expense : .income,
            isIncludedInCalculation: transaction.isIncludedInCalculation,
            isTransfer: transaction.isTransfer,
            financialInstitutionId: transaction.financialInstitutionId,
            majorCategoryId: transaction.majorCategoryId,
            minorCategoryId: transaction.minorCategoryId,
        )
    }

    private static func amountString(from decimal: Decimal) -> String {
        NSDecimalNumber(decimal: decimal).stringValue
    }
}
