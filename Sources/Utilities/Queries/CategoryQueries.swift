import SwiftData

/// カテゴリ関連のフェッチビルダー
internal enum CategoryQueries {
    internal static func sortedForDisplay() -> ModelFetchRequest<Category> {
        ModelFetchFactory.make(
            sortBy: [
                SortDescriptor(\Category.displayOrder),
                SortDescriptor(\Category.name, order: .forward),
            ]
        )
    }

    internal static func byId(_ id: UUID) -> ModelFetchRequest<Category> {
        ModelFetchFactory.make(
            predicate: #Predicate { $0.id == id },
            fetchLimit: 1
        )
    }

    internal static func firstMatching(
        predicate: Predicate<Category>
    ) -> ModelFetchRequest<Category> {
        ModelFetchFactory.make(
            predicate: predicate,
            fetchLimit: 1
        )
    }
}
