import CoreData
import Foundation
import SwiftData

// MARK: - Internal Helpers

private final class ModelContextObservationBox: @unchecked Sendable {
    weak var context: ModelContext?

    init(context: ModelContext) {
        self.context = context
    }
}

// MARK: - ModelContext Extensions

/// ModelContext の拡張
public extension ModelContext {
    /// すべてのデータを取得
    /// - Parameter type: モデルの型
    /// - Returns: 取得したデータの配列
    func fetchAll<T: PersistentModel>(_ type: T.Type) throws -> [T] {
        let descriptor: ModelFetchRequest<T> = ModelFetchFactory.make()
        return try fetch(descriptor)
    }

    /// データ数を取得
    /// - Parameter type: モデルの型
    /// - Returns: データ数
    func count<T: PersistentModel>(_ type: T.Type) throws -> Int {
        let descriptor: ModelFetchRequest<T> = ModelFetchFactory.make()
        return try fetchCount(descriptor)
    }

    /// Predicateでフィルタしたデータ数を取得
    /// - Parameters:
    ///   - type: モデルの型
    ///   - predicate: フィルタ条件
    /// - Returns: データ数
    func count<T: PersistentModel>(_ type: T.Type, predicate: Predicate<T>) throws -> Int {
        let descriptor: ModelFetchRequest<T> = ModelFetchFactory.make(predicate: predicate)
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
        descriptor: ModelFetchRequest<T>,
        onChange: @escaping @MainActor ([T]) -> Void,
    ) -> ObservationToken {
        let center = NotificationCenter.default
        let contextBox = ModelContextObservationBox(context: self)
        let observer = center.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: nil,
        ) { [descriptor] _ in
            Task { @MainActor in
                guard let context = contextBox.context else { return }
                do {
                    let updated = try context.fetch(descriptor)
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

    /// Observes changes and transforms models to Sendable data before invoking the handler off-MainActor.
    /// - Parameters:
    ///   - descriptor: Descriptor describing the target model set.
    ///   - transform: Transformation from models to Sendable data (runs on MainActor).
    ///   - onChange: Handler invoked with transformed data (can run on any actor).
    /// - Returns: A token that must be retained while observation is needed.
    @discardableResult
    func observe<T: PersistentModel, U: Sendable>(
        descriptor: ModelFetchRequest<T>,
        transform: @escaping @MainActor ([T]) -> U,
        onChange: @escaping @Sendable (U) -> Void,
    ) -> ObservationToken {
        let center = NotificationCenter.default
        let contextBox = ModelContextObservationBox(context: self)
        let observer = center.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: nil,
        ) { [descriptor] _ in
            Task {
                let transformed: U = await MainActor.run {
                    guard let context = contextBox.context else {
                        assertionFailure("ModelContext released during observation")
                        return transform([])
                    }
                    do {
                        let updated = try context.fetch(descriptor)
                        return transform(updated)
                    } catch {
                        assertionFailure("Failed to fetch observed descriptor: \(error)")
                        return transform([])
                    }
                }
                onChange(transformed)
            }
        }

        return ObservationToken {
            center.removeObserver(observer)
        }
    }
}
