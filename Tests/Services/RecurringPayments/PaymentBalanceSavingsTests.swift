import Foundation
@testable import Kakeibo
import SwiftData
import Testing

@Suite("SpecialPaymentBalanceService - 月次積立テスト")
internal struct PaymentBalanceSavingsTests {
    private let service: SpecialPaymentBalanceService = SpecialPaymentBalanceService()

    private func sampleDefinition() -> SpecialPaymentDefinition {
        SpecialPaymentDefinition(
            name: "自動車税",
            amount: 45000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2026, month: 5) ?? Date(),
            savingStrategy: .evenlyDistributed,
        )
    }

    @Test("月次積立を記録：新規作成")
    internal func recordMonthlySavings_newBalance() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let definition = sampleDefinition()
        context.insert(definition)

        // When
        let balance = service.recordMonthlySavings(
            params: SpecialPaymentBalanceService.MonthlySavingsParameters(
                definition: definition,
                balance: nil,
                year: 2025,
                month: 11,
                context: context,
            ),
        )

        // Then
        #expect(balance.totalSavedAmount == 3750) // 45000 / 12
        #expect(balance.totalPaidAmount == 0)
        #expect(balance.lastUpdatedYear == 2025)
        #expect(balance.lastUpdatedMonth == 11)
    }

    @Test("月次積立を記録：既存残高に加算")
    internal func recordMonthlySavings_addToExisting() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let definition = sampleDefinition()
        let existingBalance = SpecialPaymentSavingBalance(
            definition: definition,
            totalSavedAmount: 3750,
            totalPaidAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 10,
        )
        context.insert(definition)
        context.insert(existingBalance)

        // When
        let balance = service.recordMonthlySavings(
            params: SpecialPaymentBalanceService.MonthlySavingsParameters(
                definition: definition,
                balance: existingBalance,
                year: 2025,
                month: 11,
                context: context,
            ),
        )

        // Then
        #expect(balance.totalSavedAmount == 7500) // 3750 + 3750
        #expect(balance.lastUpdatedYear == 2025)
        #expect(balance.lastUpdatedMonth == 11)
    }

    @Test("月次積立を記録：同じ年月で重複記録はスキップ")
    internal func recordMonthlySavings_skipDuplicate() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let definition = sampleDefinition()
        let existingBalance = SpecialPaymentSavingBalance(
            definition: definition,
            totalSavedAmount: 3750,
            totalPaidAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
        )
        context.insert(definition)
        context.insert(existingBalance)

        // When
        let balance = service.recordMonthlySavings(
            params: SpecialPaymentBalanceService.MonthlySavingsParameters(
                definition: definition,
                balance: existingBalance,
                year: 2025,
                month: 11, // 同じ年月
                context: context,
            ),
        )

        // Then
        #expect(balance.totalSavedAmount == 3750) // 変わらない
    }

    @Test("月次積立を記録：複数月連続で記録")
    internal func recordMonthlySavings_multipleMonths() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let definition = sampleDefinition()
        context.insert(definition)

        var balance: SpecialPaymentSavingBalance?

        // 6ヶ月分の積立を記録
        for month in 1 ... 6 {
            balance = service.recordMonthlySavings(
                params: SpecialPaymentBalanceService.MonthlySavingsParameters(
                    definition: definition,
                    balance: balance,
                    year: 2025,
                    month: month,
                    context: context,
                ),
            )
        }

        // Then
        let finalBalance = try #require(balance)
        #expect(finalBalance.totalSavedAmount == 22500) // 3750 × 6
        #expect(finalBalance.lastUpdatedYear == 2025)
        #expect(finalBalance.lastUpdatedMonth == 6)
    }
}
