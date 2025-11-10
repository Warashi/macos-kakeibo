import Foundation
import SwiftData

internal struct TransactionQuery {
    internal let month: Date
    internal let filterKind: TransactionFilterKind
    internal let includeOnlyCalculationTarget: Bool
    internal let excludeTransfers: Bool
    internal let institutionId: UUID?
    internal let majorCategoryId: UUID?
    internal let minorCategoryId: UUID?
    internal let searchText: String
    internal let sortOption: TransactionSortOption
}

internal protocol TransactionRepository {
    func fetchTransactions(query: TransactionQuery) throws -> [Transaction]
    func fetchAllTransactions() throws -> [Transaction]
    func fetchInstitutions() throws -> [FinancialInstitution]
    func fetchCategories() throws -> [Category]
    @discardableResult
    func observeTransactions(
        query: TransactionQuery,
        onChange: @escaping @MainActor ([Transaction]) -> Void
    ) throws -> ObservationToken
    func insert(_ transaction: Transaction)
    func delete(_ transaction: Transaction)
    func saveChanges() throws
}
