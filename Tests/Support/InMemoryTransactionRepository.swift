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

    internal func fetchTransactions(query: TransactionQuery) throws -> [TransactionDTO] {
        transactions.filter { transaction in
            matches(transaction: transaction, query: query)
        }.map { TransactionDTO(from: $0) }
    }

    internal func fetchAllTransactions() throws -> [TransactionDTO] {
        transactions.map { TransactionDTO(from: $0) }
    }

    internal func fetchInstitutions() throws -> [FinancialInstitutionDTO] {
        institutions.map { FinancialInstitutionDTO(from: $0) }
    }

    internal func fetchCategories() throws -> [CategoryDTO] {
        categories.map { CategoryDTO(from: $0) }
    }

    @discardableResult
    internal func observeTransactions(
        query: TransactionQuery,
        onChange: @escaping @MainActor ([TransactionDTO]) -> Void,
    ) throws -> ObservationToken {
        let snapshot = try fetchTransactions(query: query)
        MainActor.assumeIsolated {
            onChange(snapshot)
        }
        return ObservationToken {}
    }

    internal func findTransaction(id: UUID) throws -> TransactionDTO? {
        transactions.first { $0.id == id }.map { TransactionDTO(from: $0) }
    }

    internal func findByIdentifier(_ identifier: String) throws -> TransactionDTO? {
        transactions.first { $0.importIdentifier == identifier }.map { TransactionDTO(from: $0) }
    }

    @discardableResult
    internal func insert(_ input: TransactionInput) throws -> UUID {
        let transaction = Transaction(
            date: input.date,
            title: input.title,
            amount: input.amount,
            memo: input.memo,
            isIncludedInCalculation: input.isIncludedInCalculation,
            isTransfer: input.isTransfer,
            importIdentifier: input.importIdentifier,
            financialInstitution: institution(id: input.financialInstitutionId),
            majorCategory: category(id: input.majorCategoryId),
            minorCategory: category(id: input.minorCategoryId)
        )
        transactions.append(transaction)
        return transaction.id
    }

    internal func update(_ input: TransactionUpdateInput) throws {
        guard let transaction = transactions.first(where: { $0.id == input.id }) else {
            throw RepositoryError.notFound
        }
        transaction.date = input.input.date
        transaction.title = input.input.title
        transaction.memo = input.input.memo
        transaction.amount = input.input.amount
        transaction.isIncludedInCalculation = input.input.isIncludedInCalculation
        transaction.isTransfer = input.input.isTransfer
        transaction.financialInstitution = institution(id: input.input.financialInstitutionId)
        transaction.majorCategory = category(id: input.input.majorCategoryId)
        transaction.minorCategory = category(id: input.input.minorCategoryId)
        transaction.updatedAt = Date()
    }

    internal func delete(id: UUID) throws {
        guard let index = transactions.firstIndex(where: { $0.id == id }) else {
            throw RepositoryError.notFound
        }
        transactions.remove(at: index)
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

    func institution(id: UUID?) -> FinancialInstitution? {
        guard let id else { return nil }
        return institutions.first { $0.id == id }
    }

    func category(id: UUID?) -> Kakeibo.Category? {
        guard let id else { return nil }
        return categories.first { $0.id == id }
    }
}
