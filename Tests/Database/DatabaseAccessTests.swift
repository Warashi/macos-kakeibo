import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite("DatabaseAccess", .serialized)
internal struct DatabaseAccessTests {
    @Test("write と read が別コンテキストでも整合する")
    func writeAndReadRoundTrip() async throws {
        let access = try ModelContainer.makeInMemoryAccess()

        let savedTitle = try await access.write { context -> String in
            let transaction = SwiftDataTransaction(
                date: Date(),
                title: "テスト取引",
                amount: -1000,
            )
            context.insert(transaction)
            try context.save()
            return transaction.title
        }

        let titles = try await access.read { context -> [String] in
            let descriptor = TransactionQueries.allSorted()
            let transactions = try context.fetch(descriptor)
            return transactions.map(\.title)
        }

        #expect(titles.contains(savedTitle))
    }

    @Test("DatabaseActor 経由で access を取得できる")
    func databaseActorProvidesAccess() async throws {
        #if DEBUG
        await DatabaseActor.shared.resetConfigurationForTesting()
        #endif

        let container = try ModelContainer.createInMemoryContainer()
        await DatabaseActor.shared.configure(modelContainer: container)
        let access = await DatabaseActor.shared.databaseAccess()

        let count = try await access.read { context -> Int in
            try context.count(SwiftDataTransaction.self)
        }

        #expect(count == 0)
    }

    @Test("カスタムスケジューラを使用できる")
    func supportsCustomScheduler() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let scheduler = MockScheduler(modelContainer: container)
        let access = DatabaseAccess(container: container, scheduler: scheduler)

        let writtenId = try await access.write { context -> UUID in
            let transaction = SwiftDataTransaction(
                date: Date(),
                title: "Schedulerテスト",
                amount: -500
            )
            context.insert(transaction)
            try context.save()
            return transaction.id
        }

        let ids = try await access.read { context -> [UUID] in
            let descriptor = TransactionQueries.allSorted()
            let transactions = try context.fetch(descriptor)
            return transactions.map(\.id)
        }

        let stats = await scheduler.statistics
        #expect(stats.readCount == 1)
        #expect(stats.writeCount == 1)
        #expect(ids.contains(writtenId))
    }
}

private actor MockScheduler: DatabaseScheduling {
    private let container: ModelContainer
    private(set) var readCount: Int = 0
    private(set) var writeCount: Int = 0

    internal init(modelContainer: ModelContainer) {
        self.container = modelContainer
    }

    internal func executeRead<T>(
        block: @escaping @Sendable (ModelContext) throws -> T
    ) async rethrows -> T where T: Sendable {
        readCount += 1
        let context = ModelContext(container)
        return try block(context)
    }

    internal func executeWrite<T>(
        block: @escaping @Sendable (ModelContext) throws -> T
    ) async rethrows -> T where T: Sendable {
        writeCount += 1
        return try block(ModelContext(container))
    }

    internal var statistics: (readCount: Int, writeCount: Int) {
        (readCount, writeCount)
    }
}
