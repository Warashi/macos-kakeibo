import Foundation
@testable import Kakeibo
import SwiftData
import Testing

@Suite("SwiftDataTransactionRepositoryObservation", .serialized)
@MainActor
internal struct TransactionRepositoryObservationTests {
    @Test("取引の追加・更新・削除で通知される")
    internal func notifiesOnMutations() async throws {
        let (repository, month) = try await makeRepository()
        let query = TransactionQuery(
            month: month,
            filterKind: .all,
            includeOnlyCalculationTarget: true,
            excludeTransfers: true,
            institutionId: nil,
            majorCategoryId: nil,
            minorCategoryId: nil,
            searchText: "",
            sortOption: .dateDescending,
        )

        var snapshots: [[TransactionDTO]] = []
        let token = try await repository.observeTransactions(query: query) { transactions in
            snapshots.append(transactions)
        }
        defer { token.cancel() }

        #expect(snapshots.isEmpty)

        let transaction = Transaction(date: month, title: "ランチ", amount: -1200)
        await repository.insert(transaction)
        try await repository.saveChanges()
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(!snapshots.isEmpty)
        #expect(snapshots.last?.contains(where: { $0.id == transaction.id }) == true)

        transaction.title = "ディナー"
        try await repository.saveChanges()
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(snapshots.last?.first?.title == "ディナー")

        await repository.delete(transaction)
        try await repository.saveChanges()
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(snapshots.last?.isEmpty == true)
    }
}

private extension TransactionRepositoryObservationTests {
    func makeRepository() async throws -> (SwiftDataTransactionRepository, Date) {
        let container = try ModelContainer.createInMemoryContainer()
        let repository = await SwiftDataTransactionRepository(modelContainer: container)
        let month = Date.from(year: 2025, month: 11, day: 1) ?? Date()
        return (repository, month)
    }
}
