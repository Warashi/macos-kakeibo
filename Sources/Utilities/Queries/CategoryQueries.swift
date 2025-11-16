import Foundation
import SwiftData

/// カテゴリ関連のフェッチビルダー
internal enum CategoryQueries {
    internal static func sortedForDisplay() -> ModelFetchRequest<CategoryEntity> {
        ModelFetchFactory.make(
            sortBy: [
                SortDescriptor(\CategoryEntity.displayOrder),
                SortDescriptor(\CategoryEntity.name, order: .forward),
            ],
        )
    }

    internal static func byId(_ id: UUID) -> ModelFetchRequest<CategoryEntity> {
        ModelFetchFactory.make(
            predicate: #Predicate { $0.id == id },
            fetchLimit: 1,
        )
    }

    internal static func firstMatching(
        predicate: Predicate<CategoryEntity>,
    ) -> ModelFetchRequest<CategoryEntity> {
        ModelFetchFactory.make(
            predicate: predicate,
            fetchLimit: 1,
        )
    }
}
