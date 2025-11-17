import Foundation
@testable import Kakeibo
import SwiftData
import Testing

@Suite("RecurringPaymentDefinitionEntity Tests")
internal struct RecurringPaymentDefinitionTests {
    @Test("定期支払い定義を初期化できる")
    internal func initializeDefinition() {
        let startDate = Date()
        let category = CategoryEntity(name: "教育費")

        let definition = RecurringPaymentDefinitionEntity(
            name: "学資保険",
            notes: "毎年春に支払い",
            amount: 120_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: startDate,
            leadTimeMonths: 3,
            category: category,
            savingStrategy: .evenlyDistributed,
        )

        #expect(definition.name == "学資保険")
        #expect(definition.amount == 120_000)
        #expect(definition.recurrenceIntervalMonths == 12)
        #expect(definition.firstOccurrenceDate == startDate)
        #expect(definition.leadTimeMonths == 3)
        #expect(definition.category === category)
        #expect(definition.savingStrategy == .evenlyDistributed)
        #expect(definition.monthlySavingAmount == 10000)
    }

    @Test("カスタム積立金額を設定できる")
    internal func customMonthlySavingAmount() {
        let definition = RecurringPaymentDefinitionEntity(
            name: "自動車税",
            amount: 45000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date(),
            savingStrategy: .customMonthly,
            customMonthlySavingAmount: 5000,
        )

        #expect(definition.monthlySavingAmount == 5000)
        #expect(definition.validate().isEmpty)
    }

    @Test("カスタム積立金額未設定の場合バリデーションエラーになる")
    internal func customSavingValidationFailsWithoutAmount() {
        let definition = RecurringPaymentDefinitionEntity(
            name: "車検",
            amount: 120_000,
            recurrenceIntervalMonths: 24,
            firstOccurrenceDate: Date(),
            savingStrategy: .customMonthly,
        )

        let errors = definition.validate()
        #expect(errors.contains { $0.contains("カスタム積立金額を入力してください") })
        #expect(!definition.isValid)
    }

    @Test("無効な入力はすべて検知できる")
    internal func validateInvalidDefinition() {
        let definition = RecurringPaymentDefinitionEntity(
            name: " ",
            amount: 0,
            recurrenceIntervalMonths: 0,
            firstOccurrenceDate: Date(),
            leadTimeMonths: -1,
            savingStrategy: .customMonthly,
            customMonthlySavingAmount: -1000,
        )

        let errors = definition.validate()
        #expect(errors.contains { $0.contains("名称") })
        #expect(errors.contains { $0.contains("金額") })
        #expect(errors.contains { $0.contains("周期") })
        #expect(errors.contains { $0.contains("リードタイム") })
        #expect(errors.contains { $0.contains("カスタム積立金額は1以上") })
        #expect(!definition.isValid)
    }

    @Test("次回発生日は発生リストから算出される")
    internal func nextOccurrenceDateUsesUpcomingOccurrence() {
        let startDate = Date()
        let definition = RecurringPaymentDefinitionEntity(
            name: "固定資産税",
            amount: 150_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: startDate,
        )

        let pastDate = Calendar.current.date(byAdding: .month, value: -2, to: Date()) ?? Date()
        let futureDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        let occurrencePast = RecurringPaymentOccurrenceEntity(
            definition: definition,
            scheduledDate: pastDate,
            expectedAmount: 150_000,
        )
        let occurrenceFuture = RecurringPaymentOccurrenceEntity(
            definition: definition,
            scheduledDate: futureDate,
            expectedAmount: 150_000,
        )

        definition.occurrences = [occurrencePast, occurrenceFuture]

        #expect(definition.nextOccurrenceDate == futureDate)
    }
}

@Suite("RecurringPaymentOccurrenceEntity Tests")
internal struct RecurringPaymentOccurrenceTests {
    private func sampleDefinition() -> RecurringPaymentDefinitionEntity {
        RecurringPaymentDefinitionEntity(
            name: "家電買い替え",
            amount: 200_000,
            recurrenceIntervalMonths: 24,
            firstOccurrenceDate: Date(),
        )
    }

    @Test("定期支払い発生を初期化できる")
    internal func initializeOccurrence() {
        let definition = sampleDefinition()
        let scheduledDate = Date()

        let occurrence = RecurringPaymentOccurrenceEntity(
            definition: definition,
            scheduledDate: scheduledDate,
            expectedAmount: 200_000,
            status: .saving,
        )

        #expect(occurrence.definition === definition)
        #expect(occurrence.scheduledDate == scheduledDate)
        #expect(occurrence.expectedAmount == 200_000)
        #expect(occurrence.status == .saving)
        #expect(!occurrence.isCompleted)
    }

    @Test("remainingAmountは実績金額を差し引いて計算する")
    internal func remainingAmountCalculation() {
        let definition = sampleDefinition()
        let occurrence = RecurringPaymentOccurrenceEntity(
            definition: definition,
            scheduledDate: Date(),
            expectedAmount: 200_000,
            status: .saving,
            actualAmount: 50000,
        )

        #expect(occurrence.remainingAmount == 150_000)
    }

    @Test("完了ステータスでは実績日と実績金額が必須")
    internal func completedStatusValidation() {
        let definition = sampleDefinition()
        let occurrence = RecurringPaymentOccurrenceEntity(
            definition: definition,
            scheduledDate: Date(),
            expectedAmount: 200_000,
            status: .completed,
        )

        let errors = occurrence.validate()
        #expect(errors.contains { $0.contains("実績金額") })
        #expect(errors.contains { $0.contains("実績日") })
        #expect(!occurrence.isValid)
    }

    @Test("インメモリModelContainerに保存して取得できる")
    internal func persistUsingInMemoryContainer() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let definition = sampleDefinition()
        let occurrence = RecurringPaymentOccurrenceEntity(
            definition: definition,
            scheduledDate: Date(),
            expectedAmount: 200_000,
        )

        context.insert(definition)
        context.insert(occurrence)

        try context.save()

        let descriptor: ModelFetchRequest<RecurringPaymentDefinitionEntity> = ModelFetchFactory.make()
        let storedDefinitions = try context.fetch(descriptor)

        #expect(storedDefinitions.count == 1)
        let storedDefinition = try #require(storedDefinitions.first)
        #expect(storedDefinition.occurrences.count == 1)
        #expect(storedDefinition.occurrences.first?.expectedAmount == 200_000)
    }
}
