import Foundation
import SwiftData

// MARK: - FetchDescriptor Extensions

/// FetchDescriptor の拡張
public extension FetchDescriptor {
    /// 作成日時の降順でソート
    static func sortedByCreatedAtDesc() -> Self where T: PersistentModel {
        var descriptor = FetchDescriptor<T>()
        descriptor.sortBy = [SortDescriptor(\.createdAt, order: .reverse)]
        return descriptor
    }

    /// 作成日時の昇順でソート
    static func sortedByCreatedAtAsc() -> Self where T: PersistentModel {
        var descriptor = FetchDescriptor<T>()
        descriptor.sortBy = [SortDescriptor(\.createdAt, order: .forward)]
        return descriptor
    }

    /// 更新日時の降順でソート
    static func sortedByUpdatedAtDesc() -> Self where T: PersistentModel {
        var descriptor = FetchDescriptor<T>()
        descriptor.sortBy = [SortDescriptor(\.updatedAt, order: .reverse)]
        return descriptor
    }

    /// 更新日時の昇順でソート
    static func sortedByUpdatedAtAsc() -> Self where T: PersistentModel {
        var descriptor = FetchDescriptor<T>()
        descriptor.sortBy = [SortDescriptor(\.updatedAt, order: .forward)]
        return descriptor
    }
}

// MARK: - Predicate Helpers

/// Predicate のヘルパー拡張
public extension Predicate {
    /// 常にtrueを返すPredicate
    static var all: Predicate<T> {
        #Predicate { _ in true }
    }

    /// 常にfalseを返すPredicate
    static var none: Predicate<T> {
        #Predicate { _ in false }
    }
}

// MARK: - ModelContext Extensions

/// ModelContext の拡張
public extension ModelContext {
    /// すべてのデータを取得
    /// - Parameter type: モデルの型
    /// - Returns: 取得したデータの配列
    func fetchAll<T: PersistentModel>(_ type: T.Type) throws -> [T] {
        let descriptor = FetchDescriptor<T>()
        return try fetch(descriptor)
    }

    /// 作成日時の降順でデータを取得
    /// - Parameter type: モデルの型
    /// - Returns: 取得したデータの配列
    func fetchSortedByCreatedAt<T: PersistentModel>(_ type: T.Type) throws -> [T] {
        var descriptor = FetchDescriptor<T>()
        descriptor.sortBy = [SortDescriptor(\.createdAt, order: .reverse)]
        return try fetch(descriptor)
    }

    /// 更新日時の降順でデータを取得
    /// - Parameter type: モデルの型
    /// - Returns: 取得したデータの配列
    func fetchSortedByUpdatedAt<T: PersistentModel>(_ type: T.Type) throws -> [T] {
        var descriptor = FetchDescriptor<T>()
        descriptor.sortBy = [SortDescriptor(\.updatedAt, order: .reverse)]
        return try fetch(descriptor)
    }

    /// IDでデータを取得
    /// - Parameters:
    ///   - type: モデルの型
    ///   - id: データのID
    /// - Returns: 取得したデータ（存在しない場合はnil）
    func fetch<T: PersistentModel>(_ type: T.Type, id: UUID) throws -> T? {
        let descriptor = FetchDescriptor<T>(
            predicate: #Predicate { model in
                model.id == id
            },
        )
        return try fetch(descriptor).first
    }

    /// 複数のIDでデータを取得
    /// - Parameters:
    ///   - type: モデルの型
    ///   - ids: データのID配列
    /// - Returns: 取得したデータの配列
    func fetch<T: PersistentModel>(_ type: T.Type, ids: [UUID]) throws -> [T] {
        let descriptor = FetchDescriptor<T>(
            predicate: #Predicate { model in
                ids.contains(model.id)
            },
        )
        return try fetch(descriptor)
    }

    /// データ数を取得
    /// - Parameter type: モデルの型
    /// - Returns: データ数
    func count<T: PersistentModel>(_ type: T.Type) throws -> Int {
        let descriptor = FetchDescriptor<T>()
        return try fetchCount(descriptor)
    }

    /// Predicateでフィルタしたデータ数を取得
    /// - Parameters:
    ///   - type: モデルの型
    ///   - predicate: フィルタ条件
    /// - Returns: データ数
    func count<T: PersistentModel>(_ type: T.Type, predicate: Predicate<T>) throws -> Int {
        let descriptor = FetchDescriptor<T>(predicate: predicate)
        return try fetchCount(descriptor)
    }

    /// すべてのデータを削除
    /// - Parameter type: モデルの型
    func deleteAll(_ type: (some PersistentModel).Type) throws {
        let items = try fetchAll(type)
        for item in items {
            delete(item)
        }
    }
}
