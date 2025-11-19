import Foundation
@testable import Kakeibo
import SwiftData
import Testing

@Suite(.serialized)
internal struct TransactionStackBuilderTests {
    @Test("TransactionStore を構築して初期データを読み込める")
    internal func makeStoreLoadsTransactions() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let dependencies = await TransactionStackBuilder.makeDependencies(modelContainer: container)

        let input = TransactionInput(
            date: Date(),
            title: "昼食",
            memo: "テストデータ",
            amount: Decimal(-1200),
            isIncludedInCalculation: true,
            isTransfer: false,
            financialInstitutionId: nil,
            majorCategoryId: nil,
            minorCategoryId: nil,
        )
        _ = try await dependencies.repository.insert(input)
        try await dependencies.repository.saveChanges()

        let store = await TransactionStackBuilder.makeStore(modelContainer: container)
        await store.refresh()

        let transactions = await MainActor.run { store.transactions }
        #expect(transactions.count == 1)
        #expect(transactions.first?.title == "昼食")
    }

    @Test("TransactionModelActor 経由でも TransactionStore を構築できる")
    internal func makeStoreViaModelActor() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let modelActor = TransactionModelActor(modelContainer: container)
        let dependencies = await TransactionStackBuilder.makeDependencies(modelActor: modelActor)

        let input = TransactionInput(
            date: Date(),
            title: "夕食",
            memo: "ModelActor 経由",
            amount: Decimal(-1800),
            isIncludedInCalculation: true,
            isTransfer: false,
            financialInstitutionId: nil,
            majorCategoryId: nil,
            minorCategoryId: nil,
        )
        _ = try await dependencies.repository.insert(input)
        try await dependencies.repository.saveChanges()

        let store = await TransactionStackBuilder.makeStore(modelActor: modelActor)
        await store.refresh()

        let transactions = await MainActor.run { store.transactions }
        #expect(transactions.count == 1)
        #expect(transactions.first?.title == "夕食")
    }
}
