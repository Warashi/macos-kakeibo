import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite(.serialized)
@MainActor
internal struct RecurringPaymentStoreDefUpdateTests {
    @Test("定義更新：正常系で定義が更新される")
    internal func updateDefinition_success() async throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let (store, context) = try await makeStore(referenceDate: referenceDate)

        let firstOccurrence = try #require(Date.from(year: 2025, month: 6, day: 1))
        let definition = SwiftDataRecurringPaymentDefinition(
            name: "自動車税",
            amount: 50000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: firstOccurrence,
        )
        context.insert(definition)
        try context.save()

        let input = RecurringPaymentDefinitionInput(
            name: "自動車税（更新）",
            notes: "メモを追加",
            amount: 55000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: firstOccurrence,
            categoryId: nil,
            savingStrategy: .customMonthly,
            customMonthlySavingAmount: 5000,
            dateAdjustmentPolicy: .none,
            recurrenceDayPattern: nil,
        )
        try await store.updateDefinition(definitionId: definition.id, input: input)

        let definitionId = definition.id
        let refreshed = try #require(
            context.fetch(RecurringPaymentQueries.definitions(
                predicate: #Predicate { $0.id == definitionId },
            )).first,
        )

        #expect(refreshed.name == "自動車税（更新）")
        #expect(refreshed.notes == "メモを追加")
        #expect(refreshed.amount == 55000)
        #expect(refreshed.savingStrategy == .customMonthly)
        #expect(refreshed.customMonthlySavingAmount == 5000)
    }

    @Test("定義更新：バリデーションエラー")
    internal func updateDefinition_validationError() async throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let (store, context) = try await makeStore(referenceDate: referenceDate)

        let firstOccurrence = try #require(Date.from(year: 2025, month: 6, day: 1))
        let definition = SwiftDataRecurringPaymentDefinition(
            name: "テスト",
            amount: 50000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: firstOccurrence,
        )
        context.insert(definition)
        try context.save()

        await #expect(throws: RecurringPaymentDomainError.self) {
            let input = RecurringPaymentDefinitionInput(
                name: "",
                notes: "",
                amount: -1000,
                recurrenceIntervalMonths: 12,
                firstOccurrenceDate: firstOccurrence,
                categoryId: nil,
                savingStrategy: .evenlyDistributed,
                customMonthlySavingAmount: nil,
                dateAdjustmentPolicy: .none,
                recurrenceDayPattern: nil,
            )
            try await store.updateDefinition(definitionId: definition.id, input: input)
        }
    }

    // MARK: - Helpers

    private func makeStore(referenceDate: Date) async throws -> (RecurringPaymentStore, ModelContext) {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let repository = SwiftDataRecurringPaymentRepository(modelContainer: container)
        await repository.useCurrentDateProvider { referenceDate }
        let store = RecurringPaymentStore(
            repository: repository,
            currentDateProvider: { referenceDate },
        )
        return (store, context)
    }
}
