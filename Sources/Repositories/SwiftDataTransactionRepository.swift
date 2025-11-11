import Foundation
import SwiftData

@DatabaseActor
internal final class SwiftDataTransactionRepository: TransactionRepository {
    private let modelContext: ModelContext

    internal init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    internal func fetchTransactions(query: TransactionQuery) throws -> [Transaction] {
        try modelContext.fetch(TransactionQueries.list(query: query))
    }

    internal func fetchAllTransactions() throws -> [Transaction] {
        try modelContext.fetch(TransactionQueries.allSorted())
    }

    internal func fetchInstitutions() throws -> [FinancialInstitution] {
        try modelContext.fetch(FinancialInstitutionQueries.sortedByDisplayOrder())
    }

    internal func fetchCategories() throws -> [Category] {
        try modelContext.fetch(CategoryQueries.sortedForDisplay())
    }

    @discardableResult
    internal func observeTransactions(
        query: TransactionQuery,
        onChange: @escaping @MainActor ([Transaction]) -> Void,
    ) throws -> ObservationToken {
        let descriptor = TransactionQueries.observation(query: query)
        return modelContext.observe(descriptor: descriptor, onChange: onChange)
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
