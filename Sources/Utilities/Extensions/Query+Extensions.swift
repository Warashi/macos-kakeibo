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
        let worker = ModelObservationWorker(
            context: self,
            descriptor: descriptor,
            transform: transform,
            delivery: delivery
        )
        Task(priority: .userInitiated) {
            await worker.start()
        }

        return ObservationToken {
            Task(priority: .userInitiated) {
                await worker.stop()
            }
        }
    }
}

// MARK: - Observation Worker

private actor ModelObservationWorker<Model: PersistentModel, Output: Sendable> {
    private let context: ModelContext
    private let descriptor: ModelFetchRequest<Model>
    private let transform: ([Model]) -> Output
    private let delivery: @Sendable (Output) -> Void
    private var observationTask: Task<Void, Never>?

    init(
        context: ModelContext,
        descriptor: ModelFetchRequest<Model>,
        transform: @escaping ([Model]) -> Output,
        delivery: @escaping @Sendable (Output) -> Void
    ) {
        self.context = context
        self.descriptor = descriptor
        self.transform = transform
        self.delivery = delivery
    }

    func start() {
        guard observationTask == nil else { return }
        observationTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            await self.runObservationLoop()
        }
    }

    func stop() {
        observationTask?.cancel()
        observationTask = nil
    }

    private func runObservationLoop() async {
        let notifications = NotificationCenter.default.notifications(
            named: .NSManagedObjectContextDidSave,
            object: nil
        )

        for await _ in notifications {
            if Task.isCancelled { break }
            deliverSnapshot()
        }
    }

    private func deliverSnapshot() {
        do {
            let models = try context.fetch(descriptor)
            let output = transform(models)
            delivery(output)
        } catch {
            assertionFailure("Failed to fetch observed descriptor: \(error)")
        }
    }
}
