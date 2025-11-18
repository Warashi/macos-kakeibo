import CoreData
import Dispatch
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
    /// Observes changes, transforms models to Sendable data, and invokes the handler off-MainActor.
    /// - Parameters:
    ///   - descriptor: Descriptor describing the target model set.
    ///   - transform: Transformation from models to Sendable data (runs off MainActor).
    ///   - onChange: Handler invoked with transformed data (can run on any actor).
    /// - Returns: A token that must be retained while observation is needed.
    @discardableResult
    func observe<T: PersistentModel, U: Sendable>(
        descriptor: ModelFetchRequest<T>,
        transform: @escaping ([T]) -> U,
        onChange: @escaping @Sendable (U) -> Void
    ) -> ObservationToken {
        observeInternal(
            descriptor: descriptor,
            transform: transform,
            delivery: onChange
        )
    }

    /// Observes changes, transforms models to Sendable data, and forwards the result to MainActor.
    /// - Parameters:
    ///   - descriptor: Descriptor describing the target model set.
    ///   - transform: Transformation from models to Sendable data (runs off MainActor).
    ///   - onChange: Handler invoked on MainActor with transformed data.
    /// - Returns: A token that must be retained while observation is needed.
    @discardableResult
    func observeOnMainActor<T: PersistentModel, U: Sendable>(
        descriptor: ModelFetchRequest<T>,
        transform: @escaping ([T]) -> U,
        onChange: @escaping @MainActor (U) -> Void
    ) -> ObservationToken {
        observeInternal(descriptor: descriptor, transform: transform) { transformed in
            Task { @MainActor in
                onChange(transformed)
            }
        }
    }
}

// MARK: - Private helpers

private extension ModelContext {
    @discardableResult
    func observeInternal<T: PersistentModel, U: Sendable>(
        descriptor: ModelFetchRequest<T>,
        transform: @escaping ([T]) -> U,
        delivery: @escaping @Sendable (U) -> Void
    ) -> ObservationToken {
        let center = NotificationCenter.default
        let contextBox = ModelContextObservationBox(context: self)
        let transformBox = ObservationTransformBox(
            transform: transform,
            delivery: delivery
        )
        let observer = center.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: nil
        ) { [descriptor, transformBox] _ in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let context = contextBox.context else { return }
                do {
                    let updated = try context.fetch(descriptor)
                    transformBox.deliver(models: updated)
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

private final class ObservationTransformBox<Model, Output: Sendable>: @unchecked Sendable {
    private let transform: ([Model]) -> Output
    private let delivery: @Sendable (Output) -> Void

    init(
        transform: @escaping ([Model]) -> Output,
        delivery: @escaping @Sendable (Output) -> Void
    ) {
        self.transform = transform
        self.delivery = delivery
    }

    func deliver(models: [Model]) {
        let output = transform(models)
        delivery(output)
    }
}
