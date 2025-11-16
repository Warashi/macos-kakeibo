import Foundation
import SwiftData

@DatabaseActor
internal final class SwiftDataTransactionRepository: TransactionRepository {
    private let modelContext: ModelContext

    internal init(modelContainer: ModelContainer) {
        self.modelContext = ModelContext(modelContainer)
    }

    internal func fetchTransactions(query: TransactionQuery) throws -> [TransactionDTO] {
        let transactions = try modelContext.fetch(TransactionQueries.list(query: query))
        return transactions.map { TransactionDTO(from: $0) }
    }

    internal func fetchAllTransactions() throws -> [TransactionDTO] {
        let transactions = try modelContext.fetch(TransactionQueries.allSorted())
        return transactions.map { TransactionDTO(from: $0) }
    }

    internal func fetchInstitutions() throws -> [FinancialInstitutionDTO] {
        let institutions = try modelContext.fetch(FinancialInstitutionQueries.sortedByDisplayOrder())
        return institutions.map { FinancialInstitutionDTO(from: $0) }
    }

    internal func fetchCategories() throws -> [CategoryDTO] {
        let categories = try modelContext.fetch(CategoryQueries.sortedForDisplay())
        return categories.map { CategoryDTO(from: $0) }
    }

    @discardableResult
    internal func observeTransactions(
        query: TransactionQuery,
        onChange: @escaping @MainActor ([TransactionDTO]) -> Void,
    ) throws -> ObservationToken {
        let descriptor = TransactionQueries.observation(query: query)
        return modelContext.observe(descriptor: descriptor) { transactions in
            let dtos = transactions.map { TransactionDTO(from: $0) }
            onChange(dtos)
        }
    }

    internal func findTransaction(id: UUID) throws -> Transaction? {
        try modelContext.fetch(TransactionQueries.byId(id)).first
    }

    internal func findInstitution(id: UUID) throws -> FinancialInstitution? {
        try modelContext.fetch(FinancialInstitutionQueries.byId(id)).first
    }

    internal func findCategory(id: UUID) throws -> Category? {
        try modelContext.fetch(CategoryQueries.byId(id)).first
    }

    internal func insert(_ transaction: Transaction) {
        modelContext.insert(transaction)
    }

    internal func delete(_ transaction: Transaction) {
        modelContext.delete(transaction)
    }

    internal func saveChanges() throws {
        try modelContext.save()
    }
}
