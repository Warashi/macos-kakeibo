import Foundation
import SwiftData

/// 金融機関関連のフェッチビルダー
internal enum FinancialInstitutionQueries {
    internal static func sortedByDisplayOrder() -> ModelFetchRequest<FinancialInstitution> {
        ModelFetchFactory.make(
            sortBy: [
                SortDescriptor(\FinancialInstitution.displayOrder),
                SortDescriptor(\FinancialInstitution.name, order: .forward),
            ],
        )
    }

    internal static func byName(_ name: String) -> ModelFetchRequest<FinancialInstitution> {
        ModelFetchFactory.make(
            predicate: #Predicate { $0.name == name },
            fetchLimit: 1,
        )
    }
}
