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
            let transaction = TransactionEntity(
                date: Date(),
                title: "テスト取引",
                amount: -1_000
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
            try context.count(TransactionEntity.self)
        }

        #expect(count == 0)
    }
}
