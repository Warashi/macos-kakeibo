import Foundation
import SwiftData

/// 金融機関関連のフェッチビルダー
internal enum FinancialInstitutionQueries {
    internal static func sortedByDisplayOrder() -> ModelFetchRequest<FinancialInstitutionEntity> {
        ModelFetchFactory.make(
            sortBy: [
                SortDescriptor(\FinancialInstitutionEntity.displayOrder),
                SortDescriptor(\FinancialInstitutionEntity.name, order: .forward),
            ],
        )
    }

    internal static func byId(_ id: UUID) -> ModelFetchRequest<FinancialInstitutionEntity> {
        ModelFetchFactory.make(
            predicate: #Predicate { $0.id == id },
            fetchLimit: 1,
        )
    }

    internal static func byName(_ name: String) -> ModelFetchRequest<FinancialInstitutionEntity> {
        ModelFetchFactory.make(
            predicate: #Predicate { $0.name == name },
            fetchLimit: 1,
        )
    }
}
