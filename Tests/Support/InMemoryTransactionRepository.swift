import Foundation
@testable import Kakeibo

internal final class InMemoryTransactionRepository: @preconcurrency TransactionRepository {
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

    internal func fetchTransactions(query: TransactionQuery) async throws -> [Transaction] {
        transactions.filter { transaction in
            matches(transaction: transaction, query: query)
        }
    }

    internal func fetchAllTransactions() async throws -> [Transaction] {
        transactions
    }

    internal func fetchCSVExportSnapshot() async throws -> TransactionCSVExportSnapshot {
        try await TransactionCSVExportSnapshot(
            transactions: fetchAllTransactions(),
            categories: fetchCategories(),
            institutions: fetchInstitutions(),
        )
    }

    internal func countTransactions() async throws -> Int {
        transactions.count
    }

    internal func fetchInstitutions() async throws -> [FinancialInstitution] {
        institutions
    }

    internal func fetchCategories() async throws -> [Kakeibo.Category] {
        categories
    }

    @discardableResult
    internal func observeTransactions(
        query: TransactionQuery,
        onChange: @escaping @Sendable ([Transaction]) -> Void,
    ) async throws -> ObservationHandle {
        let snapshot = try await fetchTransactions(query: query)
        onChange(snapshot)
        return ObservationHandle(token: ObservationToken {})
    }

    internal func findTransaction(id: UUID) async throws -> Transaction? {
        transactions.first { $0.id == id }
    }

    internal func findByIdentifier(_ identifier: String) async throws -> Transaction? {
        transactions.first { $0.importIdentifier == identifier }
    }

    @discardableResult
    internal func insert(_ input: TransactionInput) async throws -> UUID {
        let now = Date()
        let transaction = Transaction(
            id: UUID(),
            date: input.date,
            title: input.title,
            amount: input.amount,
            memo: input.memo,
            isIncludedInCalculation: input.isIncludedInCalculation,
            isTransfer: input.isTransfer,
            importIdentifier: input.importIdentifier,
            financialInstitutionId: input.financialInstitutionId,
            majorCategoryId: input.majorCategoryId,
            minorCategoryId: input.minorCategoryId,
            createdAt: now,
            updatedAt: now,
        )
        transactions.append(transaction)
        return transaction.id
    }

    internal func update(_ input: TransactionUpdateInput) async throws {
        guard let index = transactions.firstIndex(where: { $0.id == input.id }) else {
            throw RepositoryError.notFound
        }
        let existing = transactions[index]
        transactions[index] = Transaction(
            id: existing.id,
            date: input.input.date,
            title: input.input.title,
            amount: input.input.amount,
            memo: input.input.memo,
            isIncludedInCalculation: input.input.isIncludedInCalculation,
            isTransfer: input.input.isTransfer,
            importIdentifier: input.input.importIdentifier,
            financialInstitutionId: input.input.financialInstitutionId,
            majorCategoryId: input.input.majorCategoryId,
            minorCategoryId: input.input.minorCategoryId,
            createdAt: existing.createdAt,
            updatedAt: Date(),
        )
    }

    internal func delete(id: UUID) async throws {
        guard let index = transactions.firstIndex(where: { $0.id == id }) else {
            throw RepositoryError.notFound
        }
        transactions.remove(at: index)
    }

    internal func deleteAllTransactions() async throws {
        transactions.removeAll()
    }

    internal func saveChanges() async throws {
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
        return transaction.financialInstitutionId == institutionId
    }

    func matchCategory(transaction: Transaction, majorId: UUID?, minorId: UUID?) -> Bool {
        if let minorId {
            return transaction.minorCategoryId == minorId
        }

        guard let majorId else { return true }

        if transaction.majorCategoryId == majorId {
            return true
        }

        guard let minorId = transaction.minorCategoryId else {
            return false
        }
        return categories.first { $0.id == minorId }?.parentId == majorId
    }
}
