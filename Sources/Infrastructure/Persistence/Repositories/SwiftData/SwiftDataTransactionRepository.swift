import Foundation
import SwiftData

@ModelActor
internal actor SwiftDataTransactionRepository: TransactionRepository {
    private var contextOverride: ModelContext?

    private var context: ModelContext {
        contextOverride ?? modelContext
    }

    internal func useSharedContext(_ context: ModelContext?) {
        contextOverride = context
    }

    internal func fetchTransactions(query: TransactionQuery) async throws -> [Transaction] {
        let transactions = try context.fetch(TransactionQueries.list(query: query))
        return transactions.map { Transaction(from: $0) }
    }

    internal func fetchAllTransactions() async throws -> [Transaction] {
        let transactions = try context.fetch(TransactionQueries.allSorted())
        return transactions.map { Transaction(from: $0) }
    }

    internal func fetchCSVExportSnapshot() async throws -> TransactionCSVExportSnapshot {
        try TransactionCSVExportSnapshot(
            transactions: await fetchAllTransactions(),
            categories: await fetchCategories(),
            institutions: await fetchInstitutions(),
        )
    }

    internal func countTransactions() async throws -> Int {
        try context.count(SwiftDataTransaction.self)
    }

    internal func fetchInstitutions() async throws -> [FinancialInstitution] {
        let institutions = try context.fetch(FinancialInstitutionQueries.sortedByDisplayOrder())
        return institutions.map { FinancialInstitution(from: $0) }
    }

    internal func fetchCategories() async throws -> [Category] {
        let categories = try context.fetch(CategoryQueries.sortedForDisplay())
        return categories.map { Category(from: $0) }
    }

    @discardableResult
    internal func observeTransactions(
        query: TransactionQuery,
        onChange: @escaping @Sendable ([Transaction]) -> Void
    ) async throws -> ObservationHandle {
        let descriptor = TransactionQueries.observation(query: query)
        let token = context.observe(
            descriptor: descriptor,
            transform: { transactions in
                transactions.map { Transaction(from: $0) }
            },
            onChange: onChange
        )
        return ObservationHandle(token: token)
    }

    internal func findTransaction(id: UUID) async throws -> Transaction? {
        try context.fetch(TransactionQueries.byId(id)).first.map { Transaction(from: $0) }
    }

    internal func findByIdentifier(_ identifier: String) async throws -> Transaction? {
        try context.fetch(TransactionQueries.byImportIdentifier(identifier)).first.map { Transaction(from: $0) }
    }

    @discardableResult
    internal func insert(_ input: TransactionInput) async throws -> UUID {
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
        context.insert(transaction)
        return transaction.id
    }

    internal func update(_ input: TransactionUpdateInput) async throws {
        guard let transaction = try context.fetch(TransactionQueries.byId(input.id)).first else {
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

    internal func deleteAllTransactions() async throws {
        let descriptor: ModelFetchRequest<SwiftDataTransaction> = ModelFetchFactory.make()
        let transactions = try context.fetch(descriptor)
        for transaction in transactions {
            context.delete(transaction)
        }
        try await saveChanges()
    }

    internal func delete(id: UUID) async throws {
        guard let transaction = try context.fetch(TransactionQueries.byId(id)).first else {
            throw RepositoryError.notFound
        }
        context.delete(transaction)
    }

    internal func saveChanges() async throws {
        try context.save()
    }
}

private extension SwiftDataTransactionRepository {
    func resolveInstitution(id: UUID?) throws -> SwiftDataFinancialInstitution? {
        guard let id else { return nil }
        guard let institution = try context.fetch(FinancialInstitutionQueries.byId(id)).first else {
            throw RepositoryError.notFound
        }
        return institution
    }

    func resolveCategory(id: UUID?) throws -> SwiftDataCategory? {
        guard let id else { return nil }
        guard let category = try context.fetch(CategoryQueries.byId(id)).first else {
            throw RepositoryError.notFound
        }
        return category
    }
}
