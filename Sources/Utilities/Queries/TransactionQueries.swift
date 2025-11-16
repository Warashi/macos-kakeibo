import Foundation
import SwiftData

/// 取引関連のフェッチビルダー
internal enum TransactionQueries {
    internal static func list(query: TransactionQuery) -> ModelFetchRequest<TransactionEntity> {
        ModelFetchFactory.make(
            predicate: predicate(for: query),
            sortBy: sortDescriptors(for: query.sortOption),
        )
    }

    internal static func observation(query: TransactionQuery) -> ModelFetchRequest<TransactionEntity> {
        list(query: query)
    }

    internal static func all() -> ModelFetchRequest<TransactionEntity> {
        ModelFetchFactory.make()
    }

    internal static func allSorted() -> ModelFetchRequest<TransactionEntity> {
        ModelFetchFactory.make(
            sortBy: [
                SortDescriptor(\TransactionEntity.date, order: .reverse),
                SortDescriptor(\TransactionEntity.createdAt, order: .reverse),
            ],
        )
    }

    internal static func between(startDate: Date, endDate: Date) -> ModelFetchRequest<TransactionEntity> {
        ModelFetchFactory.make(
            predicate: #Predicate {
                $0.date >= startDate && $0.date < endDate
            },
            sortBy: [
                SortDescriptor(\TransactionEntity.date, order: .reverse),
                SortDescriptor(\TransactionEntity.createdAt, order: .reverse),
            ],
        )
    }

    internal static func byId(_ id: UUID) -> ModelFetchRequest<TransactionEntity> {
        ModelFetchFactory.make(
            predicate: #Predicate { $0.id == id },
            fetchLimit: 1,
        )
    }

    internal static func byImportIdentifier(_ identifier: String) -> ModelFetchRequest<TransactionEntity> {
        ModelFetchFactory.make(
            predicate: #Predicate { $0.importIdentifier == identifier },
            fetchLimit: 1,
        )
    }
}

private extension TransactionQueries {
    static func predicate(for query: TransactionQuery) -> Predicate<TransactionEntity> {
        let start = query.month.startOfMonth
        let end = Calendar.current.date(byAdding: .month, value: 1, to: start) ?? start

        return #Predicate<TransactionEntity> { transaction in
            transaction.date >= start && transaction.date < end
        }
    }

    static func sortDescriptors(for option: TransactionSortOption) -> [SortDescriptor<TransactionEntity>] {
        switch option {
        case .dateDescending, .amountDescending:
            [
                SortDescriptor(\TransactionEntity.date, order: .reverse),
                SortDescriptor(\TransactionEntity.createdAt, order: .reverse),
            ]
        case .dateAscending, .amountAscending:
            [
                SortDescriptor(\TransactionEntity.date, order: .forward),
                SortDescriptor(\TransactionEntity.createdAt, order: .forward),
            ]
        }
    }
}
