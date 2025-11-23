import Foundation
import SwiftData

/// 定期支払い関連のフェッチビルダー
internal enum RecurringPaymentQueries {
    internal static func definitions(
        predicate: Predicate<SwiftDataRecurringPaymentDefinition>? = nil,
    ) -> ModelFetchRequest<SwiftDataRecurringPaymentDefinition> {
        ModelFetchFactory.make(
            predicate: predicate,
            sortBy: [
                SortDescriptor(\SwiftDataRecurringPaymentDefinition.createdAt, order: .reverse),
            ],
        )
    }

    internal static func occurrences(
        predicate: Predicate<SwiftDataRecurringPaymentOccurrence>? = nil,
    ) -> ModelFetchRequest<SwiftDataRecurringPaymentOccurrence> {
        ModelFetchFactory.make(
            predicate: predicate,
            sortBy: [
                SortDescriptor(\SwiftDataRecurringPaymentOccurrence.scheduledDate),
                SortDescriptor(\SwiftDataRecurringPaymentOccurrence.createdAt),
            ],
        )
    }

    internal static func balances(
        predicate: Predicate<SwiftDataRecurringPaymentSavingBalance>? = nil,
    ) -> ModelFetchRequest<SwiftDataRecurringPaymentSavingBalance> {
        ModelFetchFactory.make(
            predicate: predicate,
            sortBy: [
                SortDescriptor(\SwiftDataRecurringPaymentSavingBalance.updatedAt, order: .reverse),
            ],
        )
    }
}
