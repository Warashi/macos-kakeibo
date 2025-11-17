import Foundation

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
    func fetchTransactions(query: TransactionQuery) throws -> [Transaction]
    func fetchAllTransactions() throws -> [Transaction]
    func fetchCSVExportSnapshot() throws -> TransactionCSVExportSnapshot
    func countTransactions() throws -> Int
    func fetchInstitutions() throws -> [FinancialInstitution]
    func fetchCategories() throws -> [Category]
    @discardableResult
    func observeTransactions(
        query: TransactionQuery,
        onChange: @escaping @MainActor ([Transaction]) -> Void,
    ) throws -> ObservationToken
    func findTransaction(id: UUID) throws -> Transaction?
    func findByIdentifier(_ identifier: String) throws -> Transaction?
    @discardableResult
    func insert(_ input: TransactionInput) throws -> UUID
    func update(_ input: TransactionUpdateInput) throws
    func deleteAllTransactions() throws
    func delete(id: UUID) throws
    func saveChanges() throws
}
