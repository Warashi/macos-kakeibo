import Foundation
import SwiftData

/// 定期支払い関連のフェッチビルダー
internal enum RecurringPaymentQueries {
    internal static func definitions(
        predicate: Predicate<RecurringPaymentDefinition>? = nil,
    ) -> ModelFetchRequest<RecurringPaymentDefinition> {
        ModelFetchFactory.make(
            predicate: predicate,
            sortBy: [
                SortDescriptor(\RecurringPaymentDefinition.createdAt, order: .reverse),
            ],
        )
    }

    internal static func occurrences(
        predicate: Predicate<RecurringPaymentOccurrence>? = nil,
    ) -> ModelFetchRequest<RecurringPaymentOccurrence> {
        ModelFetchFactory.make(
            predicate: predicate,
            sortBy: [
                SortDescriptor(\RecurringPaymentOccurrence.scheduledDate),
                SortDescriptor(\RecurringPaymentOccurrence.createdAt),
            ],
        )
    }

    internal static func balances(
        predicate: Predicate<RecurringPaymentSavingBalance>? = nil,
    ) -> ModelFetchRequest<RecurringPaymentSavingBalance> {
        ModelFetchFactory.make(
            predicate: predicate,
            sortBy: [
                SortDescriptor(\RecurringPaymentSavingBalance.updatedAt, order: .reverse),
            ],
        )
    }
}
