import Foundation
@testable import Kakeibo
import SwiftData
import Testing

@Suite("SwiftDataTransactionRepositoryStatistics", .serialized)
@DatabaseActor
internal struct SwiftDataTransactionRepositoryStatisticsTests {
    @Test("取引件数をカウントできる")
    internal func countsTransactions() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let repository = SwiftDataTransactionRepository(modelContainer: container)

        #expect(try repository.countTransactions() == 0)

        let input = TransactionInput(
            date: Date.from(year: 2025, month: 1, day: 1) ?? Date(),
            title: "テスト",
            memo: "",
            amount: Decimal(1_000),
            isIncludedInCalculation: true,
            isTransfer: false,
            financialInstitutionId: nil,
            majorCategoryId: nil,
            minorCategoryId: nil
        )
        _ = try repository.insert(input)
        try repository.saveChanges()

        #expect(try repository.countTransactions() == 1)
    }
}
