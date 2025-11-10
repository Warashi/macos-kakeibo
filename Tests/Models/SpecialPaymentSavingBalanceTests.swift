import Foundation
@testable import Kakeibo
import SwiftData
import Testing

@Suite("SpecialPaymentSavingBalance Tests")
internal struct SpecialPaymentSavingBalanceTests {
    private func sampleDefinition() -> SpecialPaymentDefinition {
        SpecialPaymentDefinition(
            name: "車検",
            amount: 120_000,
            recurrenceIntervalMonths: 24,
            firstOccurrenceDate: Date(),
        )
    }

    @Test("積立残高を初期化できる")
    internal func initializeBalance() {
        let definition = sampleDefinition()
        let balance = SpecialPaymentSavingBalance(
            definition: definition,
            totalSavedAmount: 50000,
            totalPaidAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
        )

        #expect(balance.definition === definition)
        #expect(balance.totalSavedAmount == 50000)
        #expect(balance.totalPaidAmount == 0)
        #expect(balance.balance == 50000)
        #expect(balance.lastUpdatedYear == 2025)
        #expect(balance.lastUpdatedMonth == 11)
    }

    @Test("残高は累計積立額から累計支払額を差し引いて計算される")
    internal func balanceCalculation() {
        let definition = sampleDefinition()
        let balance = SpecialPaymentSavingBalance(
            definition: definition,
            totalSavedAmount: 120_000,
            totalPaidAmount: 100_000,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
        )

        #expect(balance.balance == 20000)
    }

    @Test("残高がマイナスの場合、不足フラグが立つ")
    internal func insufficientBalanceDetection() {
        let definition = sampleDefinition()
        let balance = SpecialPaymentSavingBalance(
            definition: definition,
            totalSavedAmount: 50000,
            totalPaidAmount: 80000,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
        )

        #expect(balance.balance == -30000)
        #expect(balance.isBalanceInsufficient)
    }

    @Test("残高がプラスの場合、不足フラグは立たない")
    internal func sufficientBalance() {
        let definition = sampleDefinition()
        let balance = SpecialPaymentSavingBalance(
            definition: definition,
            totalSavedAmount: 100_000,
            totalPaidAmount: 50000,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
        )

        #expect(balance.balance == 50000)
        #expect(!balance.isBalanceInsufficient)
    }

    @Test("最終更新年月の文字列表現が正しい")
    internal func yearMonthStringFormat() {
        let definition = sampleDefinition()
        let balance = SpecialPaymentSavingBalance(
            definition: definition,
            totalSavedAmount: 10000,
            totalPaidAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 3,
        )

        #expect(balance.lastUpdatedYearMonthString == "2025-03")
    }

    @Test("累計積立額がマイナスの場合バリデーションエラーになる")
    internal func validateNegativeSavedAmount() {
        let definition = sampleDefinition()
        let balance = SpecialPaymentSavingBalance(
            definition: definition,
            totalSavedAmount: -1000,
            totalPaidAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
        )

        let errors = balance.validate()
        #expect(errors.contains { $0.contains("累計積立額は0以上") })
        #expect(!balance.isValid)
    }

    @Test("累計支払額がマイナスの場合バリデーションエラーになる")
    internal func validateNegativePaidAmount() {
        let definition = sampleDefinition()
        let balance = SpecialPaymentSavingBalance(
            definition: definition,
            totalSavedAmount: 10000,
            totalPaidAmount: -5000,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
        )

        let errors = balance.validate()
        #expect(errors.contains { $0.contains("累計支払額は0以上") })
        #expect(!balance.isValid)
    }

    @Test("不正な年月はバリデーションエラーになる")
    internal func validateInvalidYearMonth() {
        let definition = sampleDefinition()
        let balance1 = SpecialPaymentSavingBalance(
            definition: definition,
            totalSavedAmount: 10000,
            totalPaidAmount: 0,
            lastUpdatedYear: 1999,
            lastUpdatedMonth: 11,
        )

        let errors1 = balance1.validate()
        #expect(errors1.contains { $0.contains("最終更新年が不正") })
        #expect(!balance1.isValid)

        let balance2 = SpecialPaymentSavingBalance(
            definition: definition,
            totalSavedAmount: 10000,
            totalPaidAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 13,
        )

        let errors2 = balance2.validate()
        #expect(errors2.contains { $0.contains("最終更新月が不正") })
        #expect(!balance2.isValid)
    }

    @Test("有効なデータはバリデーションを通過する")
    internal func validateValidBalance() {
        let definition = sampleDefinition()
        let balance = SpecialPaymentSavingBalance(
            definition: definition,
            totalSavedAmount: 120_000,
            totalPaidAmount: 100_000,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
        )

        #expect(balance.validate().isEmpty)
        #expect(balance.isValid)
    }

    @Test("インメモリModelContainerに保存して取得できる")
    internal func persistUsingInMemoryContainer() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let definition = sampleDefinition()
        let balance = SpecialPaymentSavingBalance(
            definition: definition,
            totalSavedAmount: 60000,
            totalPaidAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
        )

        context.insert(definition)
        context.insert(balance)

        try context.save()

        let descriptor: ModelFetchRequest<SpecialPaymentSavingBalance> = ModelFetchFactory.make()
        let storedBalances = try context.fetch(descriptor)

        #expect(storedBalances.count == 1)
        let storedBalance = try #require(storedBalances.first)
        #expect(storedBalance.totalSavedAmount == 60000)
        #expect(storedBalance.balance == 60000)
        #expect(storedBalance.definition.name == "車検")
    }

    @Test("積立と支払いを繰り返すシナリオ")
    internal func savingsAndPaymentScenario() {
        let definition = sampleDefinition()
        var balance = SpecialPaymentSavingBalance(
            definition: definition,
            totalSavedAmount: 0,
            totalPaidAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 1,
        )

        // 12ヶ月積立（月5000円）
        for _ in 1 ... 12 {
            balance.totalSavedAmount = balance.totalSavedAmount.safeAdd(5000)
        }
        #expect(balance.balance == 60000)

        // 1回目の支払い（50000円）
        balance.totalPaidAmount = balance.totalPaidAmount.safeAdd(50000)
        #expect(balance.balance == 10000)

        // さらに12ヶ月積立
        for _ in 1 ... 12 {
            balance.totalSavedAmount = balance.totalSavedAmount.safeAdd(5000)
        }
        #expect(balance.balance == 70000)

        // 2回目の支払い（予定より多く：70000円）
        balance.totalPaidAmount = balance.totalPaidAmount.safeAdd(70000)
        #expect(balance.balance == 0)

        #expect(balance.totalSavedAmount == 120_000)
        #expect(balance.totalPaidAmount == 120_000)
    }
}
