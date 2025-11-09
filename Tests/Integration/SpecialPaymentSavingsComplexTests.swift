import Foundation
@testable import Kakeibo
import SwiftData
import Testing

/// 特別支払い積立・充当ロジックの統合テスト（複雑なシナリオ）
///
/// 複数回支払いや月次予算統合など、複雑なエンドツーエンドシナリオを検証します。
@Suite("SpecialPaymentSavings Complex Integration Tests")
internal struct SpecialPaymentSavingsComplexTests {
    private let balanceService: SpecialPaymentBalanceService = SpecialPaymentBalanceService()
    private let calculator: BudgetCalculator = BudgetCalculator()

    // MARK: - 複数回支払いケース

    @Test("複数回支払い：2回目、3回目の支払い")
    internal func multiplePaymentsScenario() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        // Given: 年次支払い
        let definition = SpecialPaymentDefinition(
            name: "固定資産税",
            amount: 150_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2025, month: 4) ?? Date(),
            savingStrategy: .evenlyDistributed,
        )
        context.insert(definition)

        var balance: SpecialPaymentSavingBalance?

        // 1回目のサイクル: 12ヶ月積立 + 支払い
        balance = performSavingCycle(
            definition: definition,
            balance: balance,
            startMonth: 1,
            endMonth: 12,
            context: context,
        )

        let occurrence1 = createOccurrence(
            definition: definition,
            year: 2025,
            month: 4,
            expectedAmount: 150_000,
            actualAmount: 150_000,
            context: context,
        )

        let finalBalance = try #require(balance)
        balanceService.processPayment(occurrence: occurrence1, balance: finalBalance, context: context)

        #expect(finalBalance.totalSavedAmount == 150_000)
        #expect(finalBalance.totalPaidAmount == 150_000)
        #expect(finalBalance.balance == 0)

        // 2回目のサイクル: 12ヶ月積立 + 支払い
        balance = performSavingCycle(
            definition: definition,
            balance: balance,
            startMonth: 13,
            endMonth: 24,
            context: context,
        )

        let occurrence2 = createOccurrence(
            definition: definition,
            year: 2026,
            month: 4,
            expectedAmount: 150_000,
            actualAmount: 155_000, // 少し超過
            context: context,
        )

        balanceService.processPayment(occurrence: occurrence2, balance: finalBalance, context: context)

        #expect(finalBalance.totalSavedAmount == 300_000)
        #expect(finalBalance.totalPaidAmount == 305_000)
        #expect(finalBalance.balance == -5000)

        // 3回目のサイクル: 12ヶ月積立 + 支払い
        balance = performSavingCycle(
            definition: definition,
            balance: balance,
            startMonth: 25,
            endMonth: 36,
            context: context,
        )

        let occurrence3 = createOccurrence(
            definition: definition,
            year: 2027,
            month: 4,
            expectedAmount: 150_000,
            actualAmount: 145_000, // 安く済んだ
            context: context,
        )

        balanceService.processPayment(occurrence: occurrence3, balance: finalBalance, context: context)

        // Then: 累計が正しく計算されている
        #expect(finalBalance.totalSavedAmount == 450_000) // 150000 × 3
        #expect(finalBalance.totalPaidAmount == 450_000) // 150000 + 155000 + 145000
        #expect(finalBalance.balance == 0) // ちょうどゼロ
    }

    // MARK: - 月次予算への組み込み

    @Test("月次予算への組み込み：複数の特別支払いを集計")
    internal func monthlyBudgetIntegration() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        // Given: 複数の特別支払い定義
        let categoryTax = Category(name: "保険・税金")
        let categoryEducation = Category(name: "教育費")
        context.insert(categoryTax)
        context.insert(categoryEducation)

        let definitions = createMultipleDefinitions(
            categoryTax: categoryTax,
            categoryEducation: categoryEducation,
            context: context,
        )

        try context.save()

        // When: 月次積立金額を計算
        let totalAllocation = calculator.calculateMonthlySavingsAllocation(
            definitions: definitions,
            year: 2025,
            month: 11,
        )

        // Then: 積立有効な定義のみの合計
        // 自動車税: 3750, 固定資産税: 12500, 学資保険: 12000
        let expected = Decimal(3750) + Decimal(12500) + Decimal(12000)
        #expect(totalAllocation == expected)

        // カテゴリ別積立金額を計算
        let categoryAllocations = calculator.calculateCategorySavingsAllocation(
            definitions: definitions,
            year: 2025,
            month: 11,
        )

        // Then: カテゴリ別に正しく配分されている
        let taxAllocation = try #require(categoryAllocations[categoryTax.id])
        #expect(taxAllocation == 16250) // 3750 + 12500

        let educationAllocation = try #require(categoryAllocations[categoryEducation.id])
        #expect(educationAllocation == 12000)

        // 積立状況を計算（残高データを作成）
        let balances = createBalancesForDefinitions(
            definitions: Array(definitions.prefix(3)),
            months: 6,
            year: 2025,
            context: context,
        )

        let savingsCalculations = calculator.calculateSpecialPaymentSavings(
            definitions: definitions,
            balances: balances,
            year: 2025,
            month: 6,
        )

        // Then: 各定義の積立状況が正しい
        #expect(savingsCalculations.count == 4)

        let carTaxCalc = try #require(savingsCalculations.first { $0.name == "自動車税" })
        #expect(carTaxCalc.monthlySaving == 3750)
        #expect(carTaxCalc.totalSaved == 22500) // 3750 × 6

        let propertyTaxCalc = try #require(savingsCalculations.first { $0.name == "固定資産税" })
        #expect(propertyTaxCalc.totalSaved == 75000) // 12500 × 6

        let educationCalc = try #require(savingsCalculations.first { $0.name == "学資保険" })
        #expect(educationCalc.totalSaved == 72000) // 12000 × 6
    }

    // MARK: - Private Helpers

    /// 指定範囲の月次積立を実行するヘルパー関数
    private func performSavingCycle(
        definition: SpecialPaymentDefinition,
        balance: SpecialPaymentSavingBalance?,
        startMonth: Int,
        endMonth: Int,
        context: ModelContext,
    ) -> SpecialPaymentSavingBalance? {
        var currentBalance = balance
        for month in startMonth ... endMonth {
            currentBalance = balanceService.recordMonthlySavings(
                for: definition,
                balance: currentBalance,
                year: 2024 + (month - 1) / 12,
                month: ((month - 1) % 12) + 1,
                context: context,
            )
        }
        return currentBalance
    }

    /// 支払い実績を作成するヘルパー関数
    private func createOccurrence(
        definition: SpecialPaymentDefinition,
        year: Int,
        month: Int,
        expectedAmount: Decimal,
        actualAmount: Decimal,
        context: ModelContext,
    ) -> SpecialPaymentOccurrence {
        let occurrence = SpecialPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: year, month: month) ?? Date(),
            expectedAmount: expectedAmount,
            status: .completed,
            actualDate: Date(),
            actualAmount: actualAmount,
        )
        context.insert(occurrence)
        return occurrence
    }

    /// 複数の特別支払い定義を作成するヘルパー関数
    private func createMultipleDefinitions(
        categoryTax: Category,
        categoryEducation: Category,
        context: ModelContext,
    ) -> [SpecialPaymentDefinition] {
        let definition1 = SpecialPaymentDefinition(
            name: "自動車税",
            amount: 45000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2026, month: 5) ?? Date(),
            category: categoryTax,
            savingStrategy: .evenlyDistributed,
        )

        let definition2 = SpecialPaymentDefinition(
            name: "固定資産税",
            amount: 150_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2026, month: 4) ?? Date(),
            category: categoryTax,
            savingStrategy: .evenlyDistributed,
        )

        let definition3 = SpecialPaymentDefinition(
            name: "学資保険",
            amount: 120_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2026, month: 3) ?? Date(),
            category: categoryEducation,
            savingStrategy: .customMonthly,
            customMonthlySavingAmount: 12000,
        )

        let definition4 = SpecialPaymentDefinition(
            name: "積立なし",
            amount: 50000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2026, month: 6) ?? Date(),
            savingStrategy: .disabled,
        )

        context.insert(definition1)
        context.insert(definition2)
        context.insert(definition3)
        context.insert(definition4)

        return [definition1, definition2, definition3, definition4]
    }

    /// 複数定義の積立残高を作成するヘルパー関数
    private func createBalancesForDefinitions(
        definitions: [SpecialPaymentDefinition],
        months: Int,
        year: Int,
        context: ModelContext,
    ) -> [SpecialPaymentSavingBalance] {
        var balances: [SpecialPaymentSavingBalance] = []
        for definition in definitions {
            var balance: SpecialPaymentSavingBalance?
            for month in 1 ... months {
                balance = balanceService.recordMonthlySavings(
                    for: definition,
                    balance: balance,
                    year: year,
                    month: month,
                    context: context,
                )
            }
            if let balance {
                balances.append(balance)
            }
        }
        return balances
    }
}
