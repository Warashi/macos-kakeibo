import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite(.serialized)
@MainActor
internal struct RecurringPaymentStoreCreateDefinitionTests {
    @Test("定義作成：正常系で定義とOccurrenceが作成される")
    internal func createDefinition_success() async throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let (store, context) = try await makeStore(referenceDate: referenceDate)

        let firstOccurrence = try #require(Date.from(year: 2025, month: 6, day: 1))
        let input = RecurringPaymentDefinitionInput(
            name: "自動車税",
            notes: "年1回の支払い",
            amount: 50000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: firstOccurrence,
            leadTimeMonths: 2,
            categoryId: nil,
            savingStrategy: .evenlyDistributed,
            customMonthlySavingAmount: nil,
            dateAdjustmentPolicy: .none,
            recurrenceDayPattern: nil,
        )
        try await store.createDefinition(input, horizonMonths: 24)

        let descriptor: ModelFetchRequest<SwiftDataRecurringPaymentDefinition> = ModelFetchFactory.make()
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
    internal func createDefinition_withSwiftDataCategory() async throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let (store, context) = try await makeStore(referenceDate: referenceDate)

        let category = SwiftDataCategory(name: "税金", displayOrder: 0)
        context.insert(category)
        try context.save()

        let firstOccurrence = try #require(Date.from(year: 2025, month: 4, day: 1))
        let input = RecurringPaymentDefinitionInput(
            name: "固定資産税",
            amount: 120_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: firstOccurrence,
            categoryId: category.id,
        )
        try await store.createDefinition(input)

        let descriptor: ModelFetchRequest<SwiftDataRecurringPaymentDefinition> = ModelFetchFactory.make()
        let definitions = try context.fetch(descriptor)
        let definition = try #require(definitions.first)

        #expect(definition.category?.id == category.id)
        #expect(definition.category?.name == "税金")
    }

    @Test("定義作成：バリデーションエラー（名前が空）")
    internal func createDefinition_validationError_emptyName() async throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let (store, _) = try await makeStore(referenceDate: referenceDate)

        let firstOccurrence = try #require(Date.from(year: 2025, month: 6, day: 1))
        await #expect(throws: RecurringPaymentDomainError.self) {
            let input = RecurringPaymentDefinitionInput(
                name: "",
                amount: 50000,
                recurrenceIntervalMonths: 12,
                firstOccurrenceDate: firstOccurrence,
            )
            try await store.createDefinition(input)
        }
    }

    @Test("定義作成：バリデーションエラー（金額が0以下）")
    internal func createDefinition_validationError_invalidAmount() async throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let (store, _) = try await makeStore(referenceDate: referenceDate)

        let firstOccurrence = try #require(Date.from(year: 2025, month: 6, day: 1))
        await #expect(throws: RecurringPaymentDomainError.self) {
            let input = RecurringPaymentDefinitionInput(
                name: "テスト",
                amount: 0,
                recurrenceIntervalMonths: 12,
                firstOccurrenceDate: firstOccurrence,
            )
            try await store.createDefinition(input)
        }
    }

    @Test("定義作成：バリデーションエラー（周期が0以下）")
    internal func createDefinition_validationError_invalidRecurrence() async throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let (store, _) = try await makeStore(referenceDate: referenceDate)

        let firstOccurrence = try #require(Date.from(year: 2025, month: 6, day: 1))
        await #expect(throws: RecurringPaymentDomainError.self) {
            let input = RecurringPaymentDefinitionInput(
                name: "テスト",
                amount: 50000,
                recurrenceIntervalMonths: 0,
                firstOccurrenceDate: firstOccurrence,
            )
            try await store.createDefinition(input)
        }
    }

    @Test("定義作成：カテゴリが見つからない")
    internal func createDefinition_categoryNotFound() async throws {
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let (store, _) = try await makeStore(referenceDate: referenceDate)

        let nonExistentCategoryId = UUID()
        let firstOccurrence = try #require(Date.from(year: 2025, month: 6, day: 1))

        await #expect(throws: RecurringPaymentDomainError.categoryNotFound) {
            let input = RecurringPaymentDefinitionInput(
                name: "テスト",
                amount: 50000,
                recurrenceIntervalMonths: 12,
                firstOccurrenceDate: firstOccurrence,
                categoryId: nonExistentCategoryId,
            )
            try await store.createDefinition(input)
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
