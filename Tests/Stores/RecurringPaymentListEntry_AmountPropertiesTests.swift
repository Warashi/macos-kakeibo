import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite("Entry Amount Properties Tests")
internal struct EntryAmountPropertiesTests {
    @Test("discrepancyAmount: ぴったり支払いの場合")
    internal func discrepancyAmount_exact() {
        let definition = RecurringPaymentDefinitionEntity(
            name: "テスト",
            amount: 100_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2025, month: 1) ?? Date(),
        )

        let occurrence = RecurringPaymentOccurrenceEntity(
            definition: definition,
            scheduledDate: Date.from(year: 2025, month: 1) ?? Date(),
            expectedAmount: 100_000,
            status: .completed,
            actualDate: Date.from(year: 2025, month: 1, day: 10),
            actualAmount: 100_000,
        )

        let presenter = RecurringPaymentListPresenter()
        let entry = presenter.entry(
            input: RecurringPaymentListPresenter.EntryInput(
                occurrence: RecurringPaymentOccurrence(from: occurrence),
                definition: RecurringPaymentDefinition(from: definition),
                categoryName: definition.category?.name,
                balance: nil,
                now: Date(),
            ),
        )

        #expect(entry.discrepancyAmount == nil)
    }

    @Test("discrepancyAmount: 超過払いの場合")
    internal func discrepancyAmount_overpaid() {
        let definition = RecurringPaymentDefinitionEntity(
            name: "テスト",
            amount: 100_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2025, month: 1) ?? Date(),
        )

        let occurrence = RecurringPaymentOccurrenceEntity(
            definition: definition,
            scheduledDate: Date.from(year: 2025, month: 1) ?? Date(),
            expectedAmount: 100_000,
            status: .completed,
            actualDate: Date.from(year: 2025, month: 1, day: 10),
            actualAmount: 110_000,
        )

        let presenter = RecurringPaymentListPresenter()
        let entry = presenter.entry(
            input: RecurringPaymentListPresenter.EntryInput(
                occurrence: RecurringPaymentOccurrence(from: occurrence),
                definition: RecurringPaymentDefinition(from: definition),
                categoryName: definition.category?.name,
                balance: nil,
                now: Date(),
            ),
        )

        #expect(entry.discrepancyAmount == 10000)
    }

    @Test("discrepancyAmount: 過少払いの場合")
    internal func discrepancyAmount_underpaid() {
        let definition = RecurringPaymentDefinitionEntity(
            name: "テスト",
            amount: 100_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2025, month: 1) ?? Date(),
        )

        let occurrence = RecurringPaymentOccurrenceEntity(
            definition: definition,
            scheduledDate: Date.from(year: 2025, month: 1) ?? Date(),
            expectedAmount: 100_000,
            status: .completed,
            actualDate: Date.from(year: 2025, month: 1, day: 10),
            actualAmount: 90000,
        )

        let presenter = RecurringPaymentListPresenter()
        let entry = presenter.entry(
            input: RecurringPaymentListPresenter.EntryInput(
                occurrence: RecurringPaymentOccurrence(from: occurrence),
                definition: RecurringPaymentDefinition(from: definition),
                categoryName: definition.category?.name,
                balance: nil,
                now: Date(),
            ),
        )

        #expect(entry.discrepancyAmount == -10000)
    }

    @Test("discrepancyAmount: 実績なしの場合")
    internal func discrepancyAmount_notCompleted() {
        let definition = RecurringPaymentDefinitionEntity(
            name: "テスト",
            amount: 100_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2025, month: 1) ?? Date(),
        )

        let occurrence = RecurringPaymentOccurrenceEntity(
            definition: definition,
            scheduledDate: Date.from(year: 2025, month: 1) ?? Date(),
            expectedAmount: 100_000,
            status: .saving,
        )

        let presenter = RecurringPaymentListPresenter()
        let entry = presenter.entry(
            input: RecurringPaymentListPresenter.EntryInput(
                occurrence: RecurringPaymentOccurrence(from: occurrence),
                definition: RecurringPaymentDefinition(from: definition),
                categoryName: definition.category?.name,
                balance: nil,
                now: Date(),
            ),
        )

        #expect(entry.discrepancyAmount == nil)
    }

    @Test("savingsProgress: 0%の場合")
    internal func savingsProgress_zero() {
        let definition = RecurringPaymentDefinitionEntity(
            name: "テスト",
            amount: 100_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2026, month: 1) ?? Date(),
        )

        let occurrence = RecurringPaymentOccurrenceEntity(
            definition: definition,
            scheduledDate: Date.from(year: 2026, month: 1) ?? Date(),
            expectedAmount: 100_000,
            status: .saving,
        )

        let balance = RecurringPaymentSavingBalanceEntity(
            definition: definition,
            totalSavedAmount: 0,
            totalPaidAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 1,
        )

        let presenter = RecurringPaymentListPresenter()
        let entry = presenter.entry(
            input: RecurringPaymentListPresenter.EntryInput(
                occurrence: RecurringPaymentOccurrence(from: occurrence),
                definition: RecurringPaymentDefinition(from: definition),
                categoryName: definition.category?.name,
                balance: RecurringPaymentSavingBalance(from: balance),
                now: Date(),
            ),
        )

        #expect(entry.savingsProgress == 0.0)
    }

    @Test("savingsProgress: 50%の場合")
    internal func savingsProgress_half() {
        let definition = RecurringPaymentDefinitionEntity(
            name: "テスト",
            amount: 100_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2026, month: 1) ?? Date(),
        )

        let occurrence = RecurringPaymentOccurrenceEntity(
            definition: definition,
            scheduledDate: Date.from(year: 2026, month: 1) ?? Date(),
            expectedAmount: 100_000,
            status: .saving,
        )

        let balance = RecurringPaymentSavingBalanceEntity(
            definition: definition,
            totalSavedAmount: 50000,
            totalPaidAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 6,
        )

        let presenter = RecurringPaymentListPresenter()
        let entry = presenter.entry(
            input: RecurringPaymentListPresenter.EntryInput(
                occurrence: RecurringPaymentOccurrence(from: occurrence),
                definition: RecurringPaymentDefinition(from: definition),
                categoryName: definition.category?.name,
                balance: RecurringPaymentSavingBalance(from: balance),
                now: Date(),
            ),
        )

        #expect(entry.savingsProgress == 0.5)
    }

    @Test("savingsProgress: 100%の場合")
    internal func savingsProgress_full() {
        let definition = RecurringPaymentDefinitionEntity(
            name: "テスト",
            amount: 100_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2026, month: 1) ?? Date(),
        )

        let occurrence = RecurringPaymentOccurrenceEntity(
            definition: definition,
            scheduledDate: Date.from(year: 2026, month: 1) ?? Date(),
            expectedAmount: 100_000,
            status: .saving,
        )

        let balance = RecurringPaymentSavingBalanceEntity(
            definition: definition,
            totalSavedAmount: 100_000,
            totalPaidAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 12,
        )

        let presenter = RecurringPaymentListPresenter()
        let entry = presenter.entry(
            input: RecurringPaymentListPresenter.EntryInput(
                occurrence: RecurringPaymentOccurrence(from: occurrence),
                definition: RecurringPaymentDefinition(from: definition),
                categoryName: definition.category?.name,
                balance: RecurringPaymentSavingBalance(from: balance),
                now: Date(),
            ),
        )

        #expect(entry.savingsProgress == 1.0)
    }

    @Test("savingsProgress: 100%超過の場合は1.0にクランプ")
    internal func savingsProgress_overflow() {
        let definition = RecurringPaymentDefinitionEntity(
            name: "テスト",
            amount: 100_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2026, month: 1) ?? Date(),
        )

        let occurrence = RecurringPaymentOccurrenceEntity(
            definition: definition,
            scheduledDate: Date.from(year: 2026, month: 1) ?? Date(),
            expectedAmount: 100_000,
            status: .saving,
        )

        let balance = RecurringPaymentSavingBalanceEntity(
            definition: definition,
            totalSavedAmount: 120_000,
            totalPaidAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 12,
        )

        let presenter = RecurringPaymentListPresenter()
        let entry = presenter.entry(
            input: RecurringPaymentListPresenter.EntryInput(
                occurrence: RecurringPaymentOccurrence(from: occurrence),
                definition: RecurringPaymentDefinition(from: definition),
                categoryName: definition.category?.name,
                balance: RecurringPaymentSavingBalance(from: balance),
                now: Date(),
            ),
        )

        #expect(entry.savingsProgress == 1.0)
    }
}
