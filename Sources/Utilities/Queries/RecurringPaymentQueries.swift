import Foundation
import SwiftData

/// 定期支払い関連のフェッチビルダー
internal enum RecurringPaymentQueries {
    internal static func definitions(
        predicate: Predicate<RecurringPaymentDefinitionEntity>? = nil,
    ) -> ModelFetchRequest<RecurringPaymentDefinitionEntity> {
        ModelFetchFactory.make(
            predicate: predicate,
            sortBy: [
                SortDescriptor(\RecurringPaymentDefinitionEntity.createdAt, order: .reverse),
            ],
        )
    }

    internal static func occurrences(
        predicate: Predicate<RecurringPaymentOccurrenceEntity>? = nil,
    ) -> ModelFetchRequest<RecurringPaymentOccurrenceEntity> {
        ModelFetchFactory.make(
            predicate: predicate,
            sortBy: [
                SortDescriptor(\RecurringPaymentOccurrenceEntity.scheduledDate),
                SortDescriptor(\RecurringPaymentOccurrenceEntity.createdAt),
            ],
        )
    }

    internal static func balances(
        predicate: Predicate<RecurringPaymentSavingBalanceEntity>? = nil,
    ) -> ModelFetchRequest<RecurringPaymentSavingBalanceEntity> {
        ModelFetchFactory.make(
            predicate: predicate,
            sortBy: [
                SortDescriptor(\RecurringPaymentSavingBalanceEntity.updatedAt, order: .reverse),
            ],
        )
    }
}
