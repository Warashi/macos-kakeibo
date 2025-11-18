import Foundation
@testable import Kakeibo
import SwiftData
import Testing

@Suite("SwiftDataTransactionRepositoryDeletion", .serialized)
internal struct SwiftDataTransactionRepositoryDeletionTests {
    @Test("全取引を削除できる")
    internal func deletesAllTransactions() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let repository = SwiftDataTransactionRepository(modelContainer: container)

        let input = TransactionInput(
            date: Date.from(year: 2025, month: 1, day: 1) ?? Date(),
            title: "テスト",
            memo: "",
            amount: Decimal(500),
            isIncludedInCalculation: true,
            isTransfer: false,
            financialInstitutionId: nil,
            majorCategoryId: nil,
            minorCategoryId: nil,
        )
        _ = try await repository.insert(input)
        _ = try await repository.insert(input)
        try await repository.saveChanges()
        #expect(try await repository.countTransactions() == 2)

        try await repository.deleteAllTransactions()

        #expect(try await repository.countTransactions() == 0)
    }
}
