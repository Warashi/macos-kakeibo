import Foundation
import SwiftData
@testable import Kakeibo
import Testing

@Suite(.serialized)
internal struct RecurringPaymentStackBuilderTests {
    @Test("RecurringPaymentListStore を構築してエントリを読み込める")
    func makeListStoreLoadsEntries() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let repository = await RecurringPaymentRepositoryFactory.make(modelContainer: container)
        let now = Date()

        try await Task { @DatabaseActor in
            let input = RecurringPaymentDefinitionInput(
                name: "家賃",
                amount: Decimal(100_000),
                recurrenceIntervalMonths: 1,
                firstOccurrenceDate: now
            )
            let definitionId = try repository.createDefinition(input)
            _ = try repository.synchronize(
                definitionId: definitionId,
                horizonMonths: 1,
                referenceDate: now
            )
            try repository.saveChanges()
        }.value

        let store = await RecurringPaymentStackBuilder.makeListStore(modelContainer: container)
        await store.refreshEntries()

        let entries = await MainActor.run { store.cachedEntries }
        #expect(entries.isEmpty == false)
    }

    @Test("RecurringPaymentReconciliationStore を構築して行を読み込める")
    func makeReconciliationStoreLoadsRows() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let repository = await RecurringPaymentRepositoryFactory.make(modelContainer: container)
        let transactionRepository = await SwiftDataTransactionRepository(modelContainer: container)
        let now = Date()

        try await Task { @DatabaseActor in
            let input = RecurringPaymentDefinitionInput(
                name: "保険料",
                amount: Decimal(12_000),
                recurrenceIntervalMonths: 1,
                firstOccurrenceDate: now
            )
            let definitionId = try repository.createDefinition(input)
            _ = try repository.synchronize(
                definitionId: definitionId,
                horizonMonths: 1,
                referenceDate: now
            )
            try repository.saveChanges()

            let transactionInput = TransactionInput(
                date: now,
                title: "保険料",
                memo: "",
                amount: Decimal(-12_000),
                isIncludedInCalculation: true,
                isTransfer: false,
                financialInstitutionId: nil,
                majorCategoryId: nil,
                minorCategoryId: nil
            )
            _ = try transactionRepository.insert(transactionInput)
            try transactionRepository.saveChanges()
        }.value

        let store = await RecurringPaymentStackBuilder.makeReconciliationStore(modelContainer: container)
        await store.refresh()

        let rows = await MainActor.run { store.rows }
        #expect(rows.isEmpty == false)
    }
}
