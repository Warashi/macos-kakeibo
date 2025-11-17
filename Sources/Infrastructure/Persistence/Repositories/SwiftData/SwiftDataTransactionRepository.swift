import Foundation
import SwiftData

@DatabaseActor
internal final class SwiftDataTransactionRepository: TransactionRepository {
    private let modelContext: ModelContext

    internal init(modelContainer: ModelContainer) {
        self.modelContext = ModelContext(modelContainer)
    }

    internal func fetchTransactions(query: TransactionQuery) throws -> [Transaction] {
        let transactions = try modelContext.fetch(TransactionQueries.list(query: query))
        return transactions.map { Transaction(from: $0) }
    }

    internal func fetchAllTransactions() throws -> [Transaction] {
        let transactions = try modelContext.fetch(TransactionQueries.allSorted())
        return transactions.map { Transaction(from: $0) }
    }

    internal func fetchCSVExportSnapshot() throws -> TransactionCSVExportSnapshot {
        try TransactionCSVExportSnapshot(
            transactions: fetchAllTransactions(),
            categories: fetchCategories(),
            institutions: fetchInstitutions(),
        )
    }

    internal func countTransactions() throws -> Int {
        try modelContext.count(SwiftDataTransaction.self)
    }

    internal func fetchInstitutions() throws -> [FinancialInstitution] {
        let institutions = try modelContext.fetch(FinancialInstitutionQueries.sortedByDisplayOrder())
        return institutions.map { FinancialInstitution(from: $0) }
    }

    internal func fetchCategories() throws -> [Category] {
        let categories = try modelContext.fetch(CategoryQueries.sortedForDisplay())
        return categories.map { Category(from: $0) }
    }

    @discardableResult
    internal func observeTransactions(
        query: TransactionQuery,
        onChange: @escaping @MainActor ([Transaction]) -> Void,
    ) throws -> ObservationToken {
        let descriptor = TransactionQueries.observation(query: query)
        return modelContext.observe(descriptor: descriptor) { transactions in
            let dtos = transactions.map { Transaction(from: $0) }
            onChange(dtos)
        }
    }

    internal func findTransaction(id: UUID) throws -> Transaction? {
        try modelContext.fetch(TransactionQueries.byId(id)).first.map { Transaction(from: $0) }
    }

    internal func findByIdentifier(_ identifier: String) throws -> Transaction? {
        try modelContext.fetch(TransactionQueries.byImportIdentifier(identifier)).first.map { Transaction(from: $0) }
    }

    @discardableResult
    internal func insert(_ input: TransactionInput) throws -> UUID {
        let transaction = try SwiftDataTransaction(
            date: input.date,
            title: input.title,
            amount: input.amount,
            memo: input.memo,
            isIncludedInCalculation: input.isIncludedInCalculation,
            isTransfer: input.isTransfer,
            importIdentifier: input.importIdentifier,
            financialInstitution: resolveInstitution(id: input.financialInstitutionId),
            majorCategory: resolveCategory(id: input.majorCategoryId),
            minorCategory: resolveCategory(id: input.minorCategoryId),
        )
        modelContext.insert(transaction)
        return transaction.id
    }

    internal func update(_ input: TransactionUpdateInput) throws {
        guard let transaction = try modelContext.fetch(TransactionQueries.byId(input.id)).first else {
            throw RepositoryError.notFound
        }

        transaction.date = input.input.date
        transaction.title = input.input.title
        transaction.memo = input.input.memo
        transaction.amount = input.input.amount
        transaction.isIncludedInCalculation = input.input.isIncludedInCalculation
        transaction.isTransfer = input.input.isTransfer
        transaction.financialInstitution = try resolveInstitution(id: input.input.financialInstitutionId)
        transaction.majorCategory = try resolveCategory(id: input.input.majorCategoryId)
        transaction.minorCategory = try resolveCategory(id: input.input.minorCategoryId)
        transaction.updatedAt = Date()
    }

    internal func deleteAllTransactions() throws {
        let descriptor: ModelFetchRequest<SwiftDataTransaction> = ModelFetchFactory.make()
        let transactions = try modelContext.fetch(descriptor)
        for transaction in transactions {
            modelContext.delete(transaction)
        }
        try saveChanges()
    }

    internal func delete(id: UUID) throws {
        guard let transaction = try modelContext.fetch(TransactionQueries.byId(id)).first else {
            throw RepositoryError.notFound
        }
        modelContext.delete(transaction)
    }

    internal func saveChanges() throws {
        try modelContext.save()
    }
}

private extension SwiftDataTransactionRepository {
    func resolveInstitution(id: UUID?) throws -> SwiftDataFinancialInstitution? {
        guard let id else { return nil }
        guard let institution = try modelContext.fetch(FinancialInstitutionQueries.byId(id)).first else {
            throw RepositoryError.notFound
        }
        return institution
    }

    func resolveCategory(id: UUID?) throws -> SwiftDataCategory? {
        guard let id else { return nil }
        guard let category = try modelContext.fetch(CategoryQueries.byId(id)).first else {
            throw RepositoryError.notFound
        }
        return category
    }
}
