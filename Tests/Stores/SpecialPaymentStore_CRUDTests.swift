import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite(.serialized)
@MainActor
internal struct SpecialPaymentStoreCRUDTests {
    @Test("定義作成：正常系で定義とOccurrenceが作成される")
    internal func createDefinition_success() throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let (store, context) = try makeStore(referenceDate: referenceDate)

        let firstOccurrence = try #require(Date.from(year: 2025, month: 6, day: 1))
        try store.createDefinition(
            name: "自動車税",
            notes: "年1回の支払い",
            amount: 50000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: firstOccurrence,
            leadTimeMonths: 2,
            categoryId: nil,
            savingStrategy: .evenlyDistributed,
            customMonthlySavingAmount: nil,
            horizonMonths: 24,
        )

        let descriptor = FetchDescriptor<SpecialPaymentDefinition>()
        let definitions = try context.fetch(descriptor)

        #expect(definitions.count == 1)
        let definition = try #require(definitions.first)
        #expect(definition.name == "自動車税")
        #expect(definition.amount == 50000)
        #expect(definition.recurrenceIntervalMonths == 12)
        #expect(definition.leadTimeMonths == 2)
        #expect(definition.savingStrategy == .evenlyDistributed)

        // Occurrenceも自動生成される
        #expect(!definition.occurrences.isEmpty)
    }

    @Test("定義作成：カテゴリ付きで作成")
    internal func createDefinition_withCategory() throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let (store, context) = try makeStore(referenceDate: referenceDate)

        let category = Category(name: "税金", displayOrder: 0)
        context.insert(category)
        try context.save()

        let firstOccurrence = try #require(Date.from(year: 2025, month: 4, day: 1))
        try store.createDefinition(
            name: "固定資産税",
            amount: 120_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: firstOccurrence,
            categoryId: category.id,
        )

        let descriptor = FetchDescriptor<SpecialPaymentDefinition>()
        let definitions = try context.fetch(descriptor)
        let definition = try #require(definitions.first)

        #expect(definition.category?.id == category.id)
        #expect(definition.category?.name == "税金")
    }

    @Test("定義作成：バリデーションエラー（名前が空）")
    internal func createDefinition_validationError_emptyName() throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let (store, _) = try makeStore(referenceDate: referenceDate)

        let firstOccurrence = try #require(Date.from(year: 2025, month: 6, day: 1))
        #expect(throws: SpecialPaymentStoreError.self) {
            try store.createDefinition(
                name: "",
                amount: 50000,
                recurrenceIntervalMonths: 12,
                firstOccurrenceDate: firstOccurrence,
            )
        }
    }

    @Test("定義作成：バリデーションエラー（金額が0以下）")
    internal func createDefinition_validationError_invalidAmount() throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let (store, _) = try makeStore(referenceDate: referenceDate)

        let firstOccurrence = try #require(Date.from(year: 2025, month: 6, day: 1))
        #expect(throws: SpecialPaymentStoreError.self) {
            try store.createDefinition(
                name: "テスト",
                amount: 0,
                recurrenceIntervalMonths: 12,
                firstOccurrenceDate: firstOccurrence,
            )
        }
    }

    @Test("定義作成：バリデーションエラー（周期が0以下）")
    internal func createDefinition_validationError_invalidRecurrence() throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let (store, _) = try makeStore(referenceDate: referenceDate)

        let firstOccurrence = try #require(Date.from(year: 2025, month: 6, day: 1))
        #expect(throws: SpecialPaymentStoreError.self) {
            try store.createDefinition(
                name: "テスト",
                amount: 50000,
                recurrenceIntervalMonths: 0,
                firstOccurrenceDate: firstOccurrence,
            )
        }
    }

    @Test("定義作成：カテゴリが見つからない")
    internal func createDefinition_categoryNotFound() throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let (store, _) = try makeStore(referenceDate: referenceDate)

        let nonExistentCategoryId = UUID()
        let firstOccurrence = try #require(Date.from(year: 2025, month: 6, day: 1))

        #expect(throws: SpecialPaymentStoreError.categoryNotFound) {
            try store.createDefinition(
                name: "テスト",
                amount: 50000,
                recurrenceIntervalMonths: 12,
                firstOccurrenceDate: firstOccurrence,
                categoryId: nonExistentCategoryId,
            )
        }
    }

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

        try store.updateDefinition(
            definition,
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

        #expect(throws: SpecialPaymentStoreError.self) {
            try store.updateDefinition(
                definition,
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
        }
    }

    @Test("定義削除：正常系で定義が削除される")
    internal func deleteDefinition_success() throws {
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

        // 削除前の確認
        var descriptor = FetchDescriptor<SpecialPaymentDefinition>()
        var definitions = try context.fetch(descriptor)
        #expect(definitions.count == 1)

        try store.deleteDefinition(definition)

        // 削除後の確認
        descriptor = FetchDescriptor<SpecialPaymentDefinition>()
        definitions = try context.fetch(descriptor)
        #expect(definitions.isEmpty)
    }

    @Test("定義削除：Occurrenceもカスケード削除される")
    internal func deleteDefinition_cascadeDeletesOccurrences() throws {
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

        try store.synchronizeOccurrences(for: definition, horizonMonths: 24)
        #expect(!definition.occurrences.isEmpty)

        // Occurrence数を記録
        let occurrenceCountBefore = definition.occurrences.count

        try store.deleteDefinition(definition)

        // Occurrenceも削除されていることを確認
        let descriptor = FetchDescriptor<SpecialPaymentOccurrence>()
        let occurrences = try context.fetch(descriptor)
        #expect(occurrences.isEmpty)
        #expect(occurrenceCountBefore > 0) // 削除前には存在していたことを確認
    }

    // MARK: - Helpers

    private func makeStore(referenceDate: Date) throws -> (SpecialPaymentStore, ModelContext) {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let store = SpecialPaymentStore(
            modelContext: context,
            scheduleService: SpecialPaymentScheduleService(),
            currentDateProvider: { referenceDate },
        )
        return (store, context)
    }
}
