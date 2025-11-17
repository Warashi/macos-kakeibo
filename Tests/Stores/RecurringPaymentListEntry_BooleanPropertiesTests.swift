import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite("Entry Boolean Properties Tests")
internal struct EntryBooleanPropertiesTests {
    @Test("isOverdue: 未完了で過去日の場合true")
    internal func isOverdue_pastAndIncomplete() {
        let definition = RecurringPaymentDefinitionEntity(
            name: "テスト",
            amount: 10000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2025, month: 1) ?? Date(),
        )

        let occurrence = RecurringPaymentOccurrenceEntity(
            definition: definition,
            scheduledDate: Date.from(year: 2024, month: 1) ?? Date(),
            expectedAmount: 10000,
            status: .saving,
        )

        let now = Date.from(year: 2025, month: 11, day: 15) ?? Date()
        let presenter = RecurringPaymentListPresenter()
        let entry = presenter.entry(
            input: RecurringPaymentListPresenter.EntryInput(
                occurrence: RecurringPaymentOccurrence(from: occurrence),
                definition: RecurringPaymentDefinition(from: definition),
                categoryName: definition.category?.name,
                balance: nil,
                now: now,
            ),
        )

        #expect(entry.isOverdue == true)
    }

    @Test("isOverdue: 完了済みの場合false")
    internal func isOverdue_completed() {
        let definition = RecurringPaymentDefinitionEntity(
            name: "テスト",
            amount: 10000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2025, month: 1) ?? Date(),
        )

        let occurrence = RecurringPaymentOccurrenceEntity(
            definition: definition,
            scheduledDate: Date.from(year: 2024, month: 1) ?? Date(),
            expectedAmount: 10000,
            status: .completed,
            actualDate: Date.from(year: 2024, month: 1, day: 10),
            actualAmount: 10000,
        )

        let now = Date.from(year: 2025, month: 11, day: 15) ?? Date()
        let presenter = RecurringPaymentListPresenter()
        let entry = presenter.entry(
            input: RecurringPaymentListPresenter.EntryInput(
                occurrence: RecurringPaymentOccurrence(from: occurrence),
                definition: RecurringPaymentDefinition(from: definition),
                categoryName: definition.category?.name,
                balance: nil,
                now: now,
            ),
        )

        #expect(entry.isOverdue == false)
    }

    @Test("isFullySaved: 100%積立完了の場合true")
    internal func isFullySaved_full() {
        let definition = RecurringPaymentDefinitionEntity(
            name: "テスト",
            amount: 50000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2026, month: 1) ?? Date(),
        )

        let occurrence = RecurringPaymentOccurrenceEntity(
            definition: definition,
            scheduledDate: Date.from(year: 2026, month: 1) ?? Date(),
            expectedAmount: 50000,
            status: .saving,
        )

        let balance = RecurringPaymentSavingBalanceEntity(
            definition: definition,
            totalSavedAmount: 50000,
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

        #expect(entry.isFullySaved == true)
    }

    @Test("isFullySaved: 一部積立の場合false")
    internal func isFullySaved_partial() {
        let definition = RecurringPaymentDefinitionEntity(
            name: "テスト",
            amount: 50000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2026, month: 1) ?? Date(),
        )

        let occurrence = RecurringPaymentOccurrenceEntity(
            definition: definition,
            scheduledDate: Date.from(year: 2026, month: 1) ?? Date(),
            expectedAmount: 50000,
            status: .saving,
        )

        let balance = RecurringPaymentSavingBalanceEntity(
            definition: definition,
            totalSavedAmount: 25000,
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

        #expect(entry.isFullySaved == false)
    }
}
