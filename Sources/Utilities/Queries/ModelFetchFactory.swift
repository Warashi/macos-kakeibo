import Foundation
import SwiftData

/// 共通のモデルフェッチ生成ユーティリティ
internal enum ModelFetchFactory {
    internal static func make<T: PersistentModel>(
        predicate: Predicate<T>? = nil,
        sortBy: [SortDescriptor<T>] = [],
        fetchLimit: Int? = nil
    ) -> ModelFetchRequest<T> {
        var descriptor = ModelFetchRequest<T>(
            predicate: predicate,
            sortBy: sortBy
        )
        if let fetchLimit {
            descriptor.fetchLimit = fetchLimit
        }
        return descriptor
    }
}
