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
internal protocol TransactionRepository: Sendable {
    func fetchTransactions(query: TransactionQuery) throws -> [TransactionDTO]
    func fetchAllTransactions() throws -> [TransactionDTO]
    func countTransactions() throws -> Int
    func fetchInstitutions() throws -> [FinancialInstitutionDTO]
    func fetchCategories() throws -> [CategoryDTO]
    @discardableResult
    func observeTransactions(
        query: TransactionQuery,
        onChange: @escaping @MainActor ([TransactionDTO]) -> Void,
    ) throws -> ObservationToken
    func findTransaction(id: UUID) throws -> TransactionDTO?
    func findByIdentifier(_ identifier: String) throws -> TransactionDTO?
    @discardableResult
    func insert(_ input: TransactionInput) throws -> UUID
    func update(_ input: TransactionUpdateInput) throws
    func delete(id: UUID) throws
    func saveChanges() throws
}
