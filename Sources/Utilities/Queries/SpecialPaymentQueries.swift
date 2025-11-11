import Foundation
import SwiftData

/// 特別支払い関連のフェッチビルダー
internal enum SpecialPaymentQueries {
    internal static func definitions(
        predicate: Predicate<SpecialPaymentDefinition>? = nil,
    ) -> ModelFetchRequest<SpecialPaymentDefinition> {
        ModelFetchFactory.make(
            predicate: predicate,
            sortBy: [
                SortDescriptor(\SpecialPaymentDefinition.createdAt, order: .reverse),
            ],
        )
    }

    internal static func occurrences(
        predicate: Predicate<SpecialPaymentOccurrence>? = nil,
    ) -> ModelFetchRequest<SpecialPaymentOccurrence> {
        ModelFetchFactory.make(
            predicate: predicate,
            sortBy: [
                SortDescriptor(\SpecialPaymentOccurrence.scheduledDate),
                SortDescriptor(\SpecialPaymentOccurrence.createdAt),
            ],
        )
    }

    internal static func balances(
        predicate: Predicate<SpecialPaymentSavingBalance>? = nil,
    ) -> ModelFetchRequest<SpecialPaymentSavingBalance> {
        ModelFetchFactory.make(
            predicate: predicate,
            sortBy: [
                SortDescriptor(\SpecialPaymentSavingBalance.updatedAt, order: .reverse),
            ],
        )
    }
}
