import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite("SpecialPaymentListEntry Factory Tests")
internal struct SpecialPaymentListEntryFactoryTests {
    @Test("from: 基本的なEntryの生成")
    internal func from_basicEntry() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let definition = SpecialPaymentDefinition(
            name: "自動車税",
            amount: 45000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2026, month: 5) ?? Date(),
        )

        let occurrence = SpecialPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2026, month: 5) ?? Date(),
            expectedAmount: 45000,
            status: .saving,
        )

        let balance = SpecialPaymentSavingBalance(
            definition: definition,
            totalSavedAmount: 30000,
            totalPaidAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
        )

        context.insert(definition)
        context.insert(occurrence)
        context.insert(balance)

        // When
        let now = Date.from(year: 2025, month: 11, day: 15) ?? Date()
        let presenter = SpecialPaymentListPresenter()
        let entry = presenter.entry(
            input: SpecialPaymentListPresenter.EntryInput(
                occurrence: SpecialPaymentOccurrenceDTO(from: occurrence),
                definition: SpecialPaymentDefinitionDTO(from: definition),
                categoryName: definition.category?.name,
                balance: SpecialPaymentSavingBalanceDTO(from: balance),
                now: now,
            ),
        )

        // Then
        #expect(entry.id == occurrence.id)
        #expect(entry.definitionId == definition.id)
        #expect(entry.name == "自動車税")
        #expect(entry.scheduledDate == occurrence.scheduledDate)
        #expect(entry.expectedAmount == 45000)
        #expect(entry.actualAmount == nil)
        #expect(entry.status == .saving)
        #expect(entry.savingsBalance == 30000)
        #expect(entry.savingsProgress > 0.66)
        #expect(entry.savingsProgress < 0.67)
        #expect(entry.daysUntilDue > 0) // 2025/11/15 -> 2026/5/x
        #expect(entry.hasDiscrepancy == false)
    }

    @Test("from: 残高なしの場合")
    internal func from_noBalance() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let definition = SpecialPaymentDefinition(
            name: "車検",
            amount: 120_000,
            recurrenceIntervalMonths: 24,
            firstOccurrenceDate: Date.from(year: 2027, month: 3) ?? Date(),
        )

        let occurrence = SpecialPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2027, month: 3) ?? Date(),
            expectedAmount: 120_000,
            status: .planned,
        )

        context.insert(definition)
        context.insert(occurrence)

        // When
        let presenter = SpecialPaymentListPresenter()
        let entry = presenter.entry(
            input: SpecialPaymentListPresenter.EntryInput(
                occurrence: SpecialPaymentOccurrenceDTO(from: occurrence),
                definition: SpecialPaymentDefinitionDTO(from: definition),
                categoryName: definition.category?.name,
                balance: nil,
                now: Date(),
            ),
        )

        // Then
        #expect(entry.savingsBalance == 0)
        #expect(entry.savingsProgress == 0.0)
    }

    @Test("from: 完了済みで差異ありの場合")
    internal func from_completedWithDiscrepancy() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let definition = SpecialPaymentDefinition(
            name: "固定資産税",
            amount: 150_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2025, month: 4) ?? Date(),
        )

        let occurrence = SpecialPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2025, month: 4) ?? Date(),
            expectedAmount: 150_000,
            status: .completed,
            actualDate: Date.from(year: 2025, month: 4, day: 10),
            actualAmount: 155_000, // 予定より5000円多い
        )

        context.insert(definition)
        context.insert(occurrence)

        // When
        let presenter = SpecialPaymentListPresenter()
        let entry = presenter.entry(
            input: SpecialPaymentListPresenter.EntryInput(
                occurrence: SpecialPaymentOccurrenceDTO(from: occurrence),
                definition: SpecialPaymentDefinitionDTO(from: definition),
                categoryName: definition.category?.name,
                balance: nil,
                now: Date(),
            ),
        )

        // Then
        #expect(entry.status == .completed)
        #expect(entry.actualAmount == 155_000)
        #expect(entry.hasDiscrepancy == true)
    }
}
