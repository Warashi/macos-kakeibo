import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite(.serialized)
@MainActor
internal struct SpecialPaymentStoreCreateDefinitionTests {
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
