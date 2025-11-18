import Foundation
@testable import Kakeibo
import SwiftData
import Testing

@Suite("SwiftDataTransactionRepositoryStatistics", .serialized)
internal struct SwiftDataTransactionRepositoryStatisticsTests {
    @Test("取引件数をカウントできる")
    internal func countsTransactions() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let repository = SwiftDataTransactionRepository(modelContainer: container)

        #expect(try await repository.countTransactions() == 0)

        let input = TransactionInput(
            date: Date.from(year: 2025, month: 1, day: 1) ?? Date(),
            title: "テスト",
            memo: "",
            amount: Decimal(1000),
            isIncludedInCalculation: true,
            isTransfer: false,
            financialInstitutionId: nil,
            majorCategoryId: nil,
            minorCategoryId: nil,
        )
        _ = try await repository.insert(input)
        try await repository.saveChanges()

        #expect(try await repository.countTransactions() == 1)
    }
}
