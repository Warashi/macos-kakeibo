import Foundation
import SwiftData

/// 金融機関関連のフェッチビルダー
internal enum FinancialInstitutionQueries {
    internal static func sortedByDisplayOrder() -> ModelFetchRequest<SwiftDataFinancialInstitution> {
        ModelFetchFactory.make(
            sortBy: [
                SortDescriptor(\SwiftDataFinancialInstitution.displayOrder),
                SortDescriptor(\SwiftDataFinancialInstitution.name, order: .forward),
            ],
        )
    }

    internal static func byId(_ id: UUID) -> ModelFetchRequest<SwiftDataFinancialInstitution> {
        ModelFetchFactory.make(
            predicate: #Predicate { $0.id == id },
            fetchLimit: 1,
        )
    }

    internal static func byName(_ name: String) -> ModelFetchRequest<SwiftDataFinancialInstitution> {
        ModelFetchFactory.make(
            predicate: #Predicate { $0.name == name },
            fetchLimit: 1,
        )
    }
}
