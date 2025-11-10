import CoreData
import Foundation
import SwiftData

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

// MARK: - Observation Helpers

internal extension ModelContext {
    /// Observes changes for a given fetch descriptor and invokes the handler with the latest snapshot.
    /// - Parameters:
    ///   - descriptor: Descriptor describing the target model set.
    ///   - onChange: Handler invoked on the main actor whenever the result set changes.
    /// - Returns: A token that must be retained while observation is needed.
    @discardableResult
    func observe<T: PersistentModel>(
        descriptor: FetchDescriptor<T>,
        onChange: @escaping @MainActor ([T]) -> Void
    ) -> ObservationToken {
        let center = NotificationCenter.default
        let observer = center.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: self,
            queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                do {
                    let updated = try self.fetch(descriptor)
                    onChange(updated)
                } catch {
                    assertionFailure("Failed to fetch observed descriptor: \(error)")
                }
            }
        }

        return ObservationToken {
            center.removeObserver(observer)
        }
    }
}
