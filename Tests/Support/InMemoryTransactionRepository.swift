import Foundation
@testable import Kakeibo

internal final class InMemoryTransactionRepository: TransactionRepository {
    internal var transactions: [Transaction]
    internal var institutions: [FinancialInstitution]
    internal var categories: [Kakeibo.Category]
    internal private(set) var saveCallCount: Int = 0

    internal init(
        transactions: [Transaction] = [],
        institutions: [FinancialInstitution] = [],
        categories: [Kakeibo.Category] = [],
    ) {
        self.transactions = transactions
        self.institutions = institutions
        self.categories = categories
    }

    internal func fetchTransactions(query: TransactionQuery) throws -> [Transaction] {
        transactions.filter { transaction in
            matches(transaction: transaction, query: query)
        }
    }

    internal func fetchAllTransactions() throws -> [Transaction] {
        transactions
    }

    internal func fetchInstitutions() throws -> [FinancialInstitution] {
        institutions
    }

    internal func fetchCategories() throws -> [Kakeibo.Category] {
        categories
    }

    @discardableResult
    internal func observeTransactions(
        query: TransactionQuery,
        onChange: @escaping @MainActor ([Transaction]) -> Void,
    ) throws -> ObservationToken {
        let snapshot = try fetchTransactions(query: query)
        MainActor.assumeIsolated {
            onChange(snapshot)
        }
        return ObservationToken {}
    }

    internal func insert(_ transaction: Transaction) {
        transactions.append(transaction)
    }

    internal func delete(_ transaction: Transaction) {
        transactions.removeAll { $0.id == transaction.id }
    }

    internal func saveChanges() throws {
        saveCallCount += 1
    }
}

private extension InMemoryTransactionRepository {
    func matches(transaction: Transaction, query: TransactionQuery) -> Bool {
        matchMonth(transaction: transaction, month: query.month) &&
            matchCalculation(transaction: transaction, includeOnlyTarget: query.includeOnlyCalculationTarget) &&
            matchTransfer(transaction: transaction, excludeTransfers: query.excludeTransfers) &&
            matchKind(transaction: transaction, filterKind: query.filterKind) &&
            matchInstitution(transaction: transaction, institutionId: query.institutionId) &&
            matchCategory(transaction: transaction, majorId: query.majorCategoryId, minorId: query.minorCategoryId)
    }

    func matchMonth(transaction: Transaction, month: Date) -> Bool {
        transaction.date.year == month.year && transaction.date.month == month.month
    }

    func matchCalculation(transaction: Transaction, includeOnlyTarget: Bool) -> Bool {
        !includeOnlyTarget || transaction.isIncludedInCalculation
    }

    func matchTransfer(transaction: Transaction, excludeTransfers: Bool) -> Bool {
        !excludeTransfers || !transaction.isTransfer
    }

    func matchKind(transaction: Transaction, filterKind: TransactionFilterKind) -> Bool {
        switch filterKind {
        case .all:
            true
        case .income:
            transaction.isIncome
        case .expense:
            transaction.isExpense
        }
    }

    func matchInstitution(transaction: Transaction, institutionId: UUID?) -> Bool {
        guard let institutionId else { return true }
        return transaction.financialInstitution?.id == institutionId
    }

    func matchCategory(transaction: Transaction, majorId: UUID?, minorId: UUID?) -> Bool {
        if let minorId {
            return transaction.minorCategory?.id == minorId
        }

        guard let majorId else { return true }

        if transaction.majorCategory?.id == majorId {
            return true
        }

        return transaction.minorCategory?.parent?.id == majorId
    }
}
