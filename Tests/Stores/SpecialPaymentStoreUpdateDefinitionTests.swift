import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite(.serialized)
@MainActor
internal struct SpecialPaymentStoreUpdateDefinitionTests {
    @Test("定義更新：正常系で定義が更新される")
    internal func updateDefinition_success() throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let (store, context) = try makeStore(referenceDate: referenceDate)

        let firstOccurrence = try #require(Date.from(year: 2025, month: 6, day: 1))
        let definition = SpecialPaymentDefinition(
            name: "自動車税",
            amount: 50000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: firstOccurrence,
        )
        context.insert(definition)
        try context.save()

        let input = SpecialPaymentDefinitionInput(
            name: "自動車税（更新）",
            notes: "メモを追加",
            amount: 55000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: firstOccurrence,
            leadTimeMonths: 3,
            categoryId: nil,
            savingStrategy: .customMonthly,
            customMonthlySavingAmount: 5000,
            dateAdjustmentPolicy: .none,
            recurrenceDayPattern: nil,
        )
        try store.updateDefinition(definition, input: input)

        #expect(definition.name == "自動車税（更新）")
        #expect(definition.notes == "メモを追加")
        #expect(definition.amount == 55000)
        #expect(definition.leadTimeMonths == 3)
        #expect(definition.savingStrategy == .customMonthly)
        #expect(definition.customMonthlySavingAmount == 5000)
    }

    @Test("定義更新：バリデーションエラー")
    internal func updateDefinition_validationError() throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let (store, context) = try makeStore(referenceDate: referenceDate)

        let firstOccurrence = try #require(Date.from(year: 2025, month: 6, day: 1))
        let definition = SpecialPaymentDefinition(
            name: "テスト",
            amount: 50000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: firstOccurrence,
        )
        context.insert(definition)
        try context.save()

        #expect(throws: SpecialPaymentDomainError.self) {
            let input = SpecialPaymentDefinitionInput(
                name: "",
                notes: "",
                amount: -1000,
                recurrenceIntervalMonths: 12,
                firstOccurrenceDate: firstOccurrence,
                leadTimeMonths: 0,
                categoryId: nil,
                savingStrategy: .evenlyDistributed,
                customMonthlySavingAmount: nil,
                dateAdjustmentPolicy: .none,
                recurrenceDayPattern: nil,
            )
            try store.updateDefinition(definition, input: input)
        }
    }

    // MARK: - Helpers

    private func makeStore(referenceDate: Date) throws -> (SpecialPaymentStore, ModelContext) {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let store = SpecialPaymentStore(
            modelContext: context,
            currentDateProvider: { referenceDate },
        )
        return (store, context)
    }
}
