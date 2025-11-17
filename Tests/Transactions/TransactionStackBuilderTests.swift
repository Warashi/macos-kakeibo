import Foundation
import SwiftData
@testable import Kakeibo
import Testing

@Suite(.serialized)
internal struct TransactionStackBuilderTests {
    @Test("TransactionStore を構築して初期データを読み込める")
    func makeStoreLoadsTransactions() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let dependencies = await TransactionStackBuilder.makeDependencies(modelContainer: container)

        try await Task { @DatabaseActor in
            let input = TransactionInput(
                date: Date(),
                title: "昼食",
                memo: "テストデータ",
                amount: Decimal(-1200),
                isIncludedInCalculation: true,
                isTransfer: false,
                financialInstitutionId: nil,
                majorCategoryId: nil,
                minorCategoryId: nil
            )
            _ = try dependencies.repository.insert(input)
            try dependencies.repository.saveChanges()
        }.value

        let store = await TransactionStackBuilder.makeStore(modelContainer: container)
        await store.refresh()

        let transactions = await MainActor.run { store.transactions }
        #expect(transactions.count == 1)
        #expect(transactions.first?.title == "昼食")
    }
}
