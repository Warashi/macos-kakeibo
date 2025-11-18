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

internal protocol TransactionRepository: Sendable {
    func fetchTransactions(query: TransactionQuery) async throws -> [Transaction]
    func fetchAllTransactions() async throws -> [Transaction]
    func fetchCSVExportSnapshot() async throws -> TransactionCSVExportSnapshot
    func countTransactions() async throws -> Int
    func fetchInstitutions() async throws -> [FinancialInstitution]
    func fetchCategories() async throws -> [Category]
    @discardableResult
    func observeTransactions(
        query: TransactionQuery,
        onChange: @escaping @MainActor ([Transaction]) -> Void,
    ) async throws -> ObservationToken
    func findTransaction(id: UUID) async throws -> Transaction?
    func findByIdentifier(_ identifier: String) async throws -> Transaction?
    @discardableResult
    func insert(_ input: TransactionInput) async throws -> UUID
    func update(_ input: TransactionUpdateInput) async throws
    func deleteAllTransactions() async throws
    func delete(id: UUID) async throws
    func saveChanges() async throws
}
