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

@DatabaseActor
internal protocol TransactionRepository {
    func fetchTransactions(query: TransactionQuery) throws -> [TransactionDTO]
    func fetchAllTransactions() throws -> [TransactionDTO]
    func fetchInstitutions() throws -> [FinancialInstitutionDTO]
    func fetchCategories() throws -> [CategoryDTO]
    @discardableResult
    func observeTransactions(
        query: TransactionQuery,
        onChange: @escaping @MainActor ([TransactionDTO]) -> Void,
    ) throws -> ObservationToken
    func findTransaction(id: UUID) throws -> Transaction?
    func findInstitution(id: UUID) throws -> FinancialInstitution?
    func findCategory(id: UUID) throws -> Category?
    func insert(_ transaction: Transaction)
    func delete(_ transaction: Transaction)
    func saveChanges() throws
}
