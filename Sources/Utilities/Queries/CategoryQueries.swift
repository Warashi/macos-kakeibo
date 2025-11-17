import Foundation
import SwiftData

/// カテゴリ関連のフェッチビルダー
internal enum CategoryQueries {
    internal static func sortedForDisplay() -> ModelFetchRequest<SwiftDataCategory> {
        ModelFetchFactory.make(
            sortBy: [
                SortDescriptor(\SwiftDataCategory.displayOrder),
                SortDescriptor(\SwiftDataCategory.name, order: .forward),
            ],
        )
    }

    internal static func byId(_ id: UUID) -> ModelFetchRequest<SwiftDataCategory> {
        ModelFetchFactory.make(
            predicate: #Predicate { $0.id == id },
            fetchLimit: 1,
        )
    }

    internal static func firstMatching(
        predicate: Predicate<SwiftDataCategory>,
    ) -> ModelFetchRequest<SwiftDataCategory> {
        ModelFetchFactory.make(
            predicate: predicate,
            fetchLimit: 1,
        )
    }
}
