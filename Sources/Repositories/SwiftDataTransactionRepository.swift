import Foundation
import SwiftData

internal final class SwiftDataTransactionRepository: TransactionRepository {
    private let modelContext: ModelContext

    internal init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    internal func fetchTransactions(query: TransactionQuery) throws -> [Transaction] {
        let predicate = Self.predicate(from: query)

        let descriptor = FetchDescriptor<Transaction>(
            predicate: predicate,
            sortBy: Self.sortDescriptors(for: query.sortOption),
        )
        return try modelContext.fetch(descriptor)
    }

    internal func fetchAllTransactions() throws -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [
                SortDescriptor(\Transaction.date, order: .reverse),
                SortDescriptor(\Transaction.createdAt, order: .reverse),
            ]
        )
        return try modelContext.fetch(descriptor)
    }

    internal func fetchInstitutions() throws -> [FinancialInstitution] {
        let descriptor = FetchDescriptor<FinancialInstitution>(
            sortBy: [SortDescriptor(\.displayOrder), SortDescriptor(\.name)],
        )
        return try modelContext.fetch(descriptor)
    }

    internal func fetchCategories() throws -> [Category] {
        let descriptor = FetchDescriptor<Category>(
            sortBy: [SortDescriptor(\.displayOrder), SortDescriptor(\.name)],
        )
        return try modelContext.fetch(descriptor)
    }

    @discardableResult
    internal func observeTransactions(
        query: TransactionQuery,
        onChange: @escaping @MainActor ([Transaction]) -> Void
    ) throws -> ObservationToken {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: Self.predicate(from: query),
            sortBy: Self.sortDescriptors(for: query.sortOption),
        )
        let initialSnapshot = try modelContext.fetch(descriptor)
        Task { @MainActor [initialSnapshot] in
            onChange(initialSnapshot)
        }
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

private extension SwiftDataTransactionRepository {
    static func predicate(from query: TransactionQuery) -> Predicate<Transaction> {
        let start = query.month.startOfMonth
        let end = Calendar.current.date(byAdding: .month, value: 1, to: start) ?? start

        return #Predicate<Transaction> { transaction in
            transaction.date >= start && transaction.date < end
        }
    }

    static func sortDescriptors(for option: TransactionSortOption) -> [SortDescriptor<Transaction>] {
        switch option {
        case .dateDescending, .amountDescending:
            return [
                SortDescriptor(\Transaction.date, order: .reverse),
                SortDescriptor(\Transaction.createdAt, order: .reverse),
            ]
        case .dateAscending, .amountAscending:
            return [
                SortDescriptor(\Transaction.date, order: .forward),
                SortDescriptor(\Transaction.createdAt, order: .forward),
            ]
        }
    }
}
