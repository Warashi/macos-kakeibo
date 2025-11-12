import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite(.serialized)
@MainActor
internal struct SpecialPaymentStoreDayPatternTests {
    @Test("定義作成：recurrenceDayPatternを指定して作成")
    internal func createDefinition_withRecurrenceDayPattern() throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let (store, context) = try makeStore(referenceDate: referenceDate)

        let firstOccurrence = try #require(Date.from(year: 2025, month: 6, day: 1))
        let input = SpecialPaymentDefinitionInput(
            name: "月末支払い",
            notes: "毎月末に発生する支払い",
            amount: 30000,
            recurrenceIntervalMonths: 1,
            firstOccurrenceDate: firstOccurrence,
            leadTimeMonths: 0,
            categoryId: nil,
            savingStrategy: .disabled,
            customMonthlySavingAmount: nil,
            dateAdjustmentPolicy: .none,
            recurrenceDayPattern: .endOfMonth,
        )
        try store.createDefinition(input, horizonMonths: 6)

        let descriptor: ModelFetchRequest<SpecialPaymentDefinition> = ModelFetchFactory.make()
        let definitions = try context.fetch(descriptor)

        #expect(definitions.count == 1)
        let definition = try #require(definitions.first)
        #expect(definition.name == "月末支払い")
        #expect(definition.recurrenceDayPattern == .endOfMonth)

        // パターンがスケジュール生成に反映されることを確認
        #expect(!definition.occurrences.isEmpty)
    }

    @Test("定義作成：dateAdjustmentPolicyを指定して作成")
    internal func createDefinition_withDateAdjustmentPolicy() throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let (store, context) = try makeStore(referenceDate: referenceDate)

        let firstOccurrence = try #require(Date.from(year: 2025, month: 6, day: 1))
        let input = SpecialPaymentDefinitionInput(
            name: "営業日払い",
            notes: "休日の場合は前営業日に調整",
            amount: 40000,
            recurrenceIntervalMonths: 1,
            firstOccurrenceDate: firstOccurrence,
            leadTimeMonths: 0,
            categoryId: nil,
            savingStrategy: .disabled,
            customMonthlySavingAmount: nil,
            dateAdjustmentPolicy: .moveToPreviousBusinessDay,
            recurrenceDayPattern: nil,
        )
        try store.createDefinition(input, horizonMonths: 6)

        let descriptor: ModelFetchRequest<SpecialPaymentDefinition> = ModelFetchFactory.make()
        let definitions = try context.fetch(descriptor)

        #expect(definitions.count == 1)
        let definition = try #require(definitions.first)
        #expect(definition.name == "営業日払い")
        #expect(definition.dateAdjustmentPolicy == .moveToPreviousBusinessDay)
    }

    @Test("定義更新：recurrenceDayPatternを変更")
    internal func updateDefinition_changesRecurrenceDayPattern() throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let (store, context) = try makeStore(referenceDate: referenceDate)

        let firstOccurrence = try #require(Date.from(year: 2025, month: 6, day: 1))
        let definition = SpecialPaymentDefinition(
            name: "給料日",
            amount: 250_000,
            recurrenceIntervalMonths: 1,
            firstOccurrenceDate: firstOccurrence,
            recurrenceDayPattern: .fixed(25),
        )
        context.insert(definition)
        try context.save()

        try store.synchronizeOccurrences(definitionId: definition.id, horizonMonths: 6)

        // パターンを月末に変更
        let input = SpecialPaymentDefinitionInput(
            name: "給料日",
            notes: "月末払いに変更",
            amount: 250_000,
            recurrenceIntervalMonths: 1,
            firstOccurrenceDate: firstOccurrence,
            leadTimeMonths: 0,
            categoryId: nil,
            savingStrategy: .disabled,
            customMonthlySavingAmount: nil,
            dateAdjustmentPolicy: .none,
            recurrenceDayPattern: .endOfMonth,
        )
        try store.updateDefinition(definition, input: input, horizonMonths: 6)

        #expect(definition.recurrenceDayPattern == .endOfMonth)
        #expect(definition.notes == "月末払いに変更")
        // スケジュールが再生成されることを確認
        #expect(!definition.occurrences.isEmpty)
    }

    @Test("定義更新：dateAdjustmentPolicyを変更")
    internal func updateDefinition_changesDateAdjustmentPolicy() throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let (store, context) = try makeStore(referenceDate: referenceDate)

        let firstOccurrence = try #require(Date.from(year: 2025, month: 6, day: 1))
        let definition = SpecialPaymentDefinition(
            name: "家賃",
            amount: 100_000,
            recurrenceIntervalMonths: 1,
            firstOccurrenceDate: firstOccurrence,
            dateAdjustmentPolicy: .none,
        )
        context.insert(definition)
        try context.save()

        try store.synchronizeOccurrences(definitionId: definition.id, horizonMonths: 6)

        // ポリシーを変更
        let input = SpecialPaymentDefinitionInput(
            name: "家賃",
            notes: "休日の場合は翌営業日払い",
            amount: 100_000,
            recurrenceIntervalMonths: 1,
            firstOccurrenceDate: firstOccurrence,
            leadTimeMonths: 0,
            categoryId: nil,
            savingStrategy: .disabled,
            customMonthlySavingAmount: nil,
            dateAdjustmentPolicy: .moveToNextBusinessDay,
            recurrenceDayPattern: nil,
        )
        try store.updateDefinition(definition, input: input, horizonMonths: 6)

        #expect(definition.dateAdjustmentPolicy == .moveToNextBusinessDay)
        #expect(definition.notes == "休日の場合は翌営業日払い")
    }

    // MARK: - Helpers

    private func makeStore(referenceDate: Date) throws -> (SpecialPaymentStore, ModelContext) {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let repository = SwiftDataSpecialPaymentRepository(modelContext: context)
        let store = SpecialPaymentStore(
            repository: repository,
            currentDateProvider: { referenceDate },
        )
        return (store, context)
    }
}
