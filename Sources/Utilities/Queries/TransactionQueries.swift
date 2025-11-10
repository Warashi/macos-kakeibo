import Foundation
import SwiftData

/// 取引関連のフェッチビルダー
internal enum TransactionQueries {
    internal static func list(query: TransactionQuery) -> ModelFetchRequest<Transaction> {
        ModelFetchFactory.make(
            predicate: predicate(for: query),
            sortBy: sortDescriptors(for: query.sortOption)
        )
    }

    internal static func observation(query: TransactionQuery) -> ModelFetchRequest<Transaction> {
        list(query: query)
    }

    internal static func all() -> ModelFetchRequest<Transaction> {
        ModelFetchFactory.make()
    }

    internal static func allSorted() -> ModelFetchRequest<Transaction> {
        ModelFetchFactory.make(
            sortBy: [
                SortDescriptor(\Transaction.date, order: .reverse),
                SortDescriptor(\Transaction.createdAt, order: .reverse),
            ]
        )
    }

    internal static func between(startDate: Date, endDate: Date) -> ModelFetchRequest<Transaction> {
        ModelFetchFactory.make(
            predicate: #Predicate {
                $0.date >= startDate && $0.date < endDate
            },
            sortBy: [
                SortDescriptor(\Transaction.date, order: .reverse),
                SortDescriptor(\Transaction.createdAt, order: .reverse),
            ]
        )
    }

    internal static func byId(_ id: UUID) -> ModelFetchRequest<Transaction> {
        ModelFetchFactory.make(
            predicate: #Predicate { $0.id == id },
            fetchLimit: 1
        )
    }

    internal static func byImportIdentifier(_ identifier: String) -> ModelFetchRequest<Transaction> {
        ModelFetchFactory.make(
            predicate: #Predicate { $0.importIdentifier == identifier },
            fetchLimit: 1
        )
    }
}

private extension TransactionQueries {
    static func predicate(for query: TransactionQuery) -> Predicate<Transaction> {
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
