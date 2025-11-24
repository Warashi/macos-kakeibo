import Foundation
import SwiftData

/// 取引関連のフェッチビルダー
internal enum TransactionQueries {
    internal static func list(query: TransactionQuery) -> ModelFetchRequest<SwiftDataTransaction> {
        ModelFetchFactory.make(
            predicate: predicate(for: query),
            sortBy: sortDescriptors(for: query.sortOption),
        )
    }

    internal static func observation(query: TransactionQuery) -> ModelFetchRequest<SwiftDataTransaction> {
        list(query: query)
    }

    internal static func all() -> ModelFetchRequest<SwiftDataTransaction> {
        ModelFetchFactory.make()
    }

    internal static func allSorted() -> ModelFetchRequest<SwiftDataTransaction> {
        ModelFetchFactory.make(
            sortBy: [
                SortDescriptor(\SwiftDataTransaction.date, order: .reverse),
                SortDescriptor(\SwiftDataTransaction.createdAt, order: .reverse),
            ],
        )
    }

    internal static func between(startDate: Date, endDate: Date) -> ModelFetchRequest<SwiftDataTransaction> {
        ModelFetchFactory.make(
            predicate: #Predicate {
                $0.date >= startDate && $0.date < endDate
            },
            sortBy: [
                SortDescriptor(\SwiftDataTransaction.date, order: .reverse),
                SortDescriptor(\SwiftDataTransaction.createdAt, order: .reverse),
            ],
        )
    }

    internal static func byId(_ id: UUID) -> ModelFetchRequest<SwiftDataTransaction> {
        ModelFetchFactory.make(
            predicate: #Predicate { $0.id == id },
            fetchLimit: 1,
        )
    }

    internal static func byImportIdentifier(_ identifier: String) -> ModelFetchRequest<SwiftDataTransaction> {
        ModelFetchFactory.make(
            predicate: #Predicate { $0.importIdentifier == identifier },
            fetchLimit: 1,
        )
    }
}

private extension TransactionQueries {
    static func predicate(for query: TransactionQuery) -> Predicate<SwiftDataTransaction> {
        let monthPeriodCalculator = MonthPeriodCalculatorFactory.make()
        let year = query.month.year
        let month = query.month.month

        let start: Date
        let end: Date

        if let period = monthPeriodCalculator.calculatePeriod(for: year, month: month) {
            start = period.start
            end = period.end
        } else {
            // フォールバック: 従来の月初〜月末
            start = query.month.startOfMonth
            end = Calendar.current.date(byAdding: .month, value: 1, to: start) ?? start
        }

        return #Predicate<SwiftDataTransaction> { transaction in
            transaction.date >= start && transaction.date < end
        }
    }

    static func sortDescriptors(for option: TransactionSortOption) -> [SortDescriptor<SwiftDataTransaction>] {
        switch option {
        case .dateDescending, .amountDescending:
            [
                SortDescriptor(\SwiftDataTransaction.date, order: .reverse),
                SortDescriptor(\SwiftDataTransaction.createdAt, order: .reverse),
            ]
        case .dateAscending, .amountAscending:
            [
                SortDescriptor(\SwiftDataTransaction.date, order: .forward),
                SortDescriptor(\SwiftDataTransaction.createdAt, order: .forward),
            ]
        }
    }
}
