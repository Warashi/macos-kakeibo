import Foundation
@testable import Kakeibo
import SwiftData
import Testing

/// 特別支払い積立・充当ロジックの統合テスト
///
/// エンドツーエンドのシナリオで、モデル・サービス・計算ロジックが
/// 連携して正しく動作することを検証します。
@Suite("SpecialPaymentSavings Integration Tests")
internal struct SpecialPaymentSavingsIntegrationTests {
    private let balanceService = SpecialPaymentBalanceService()
    private let calculator = BudgetCalculator()

    // MARK: - 基本シナリオ

    @Test("基本シナリオ：3年周期の積立と支払い")
    internal func basicScenario_threeYearCycle() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        // Given: 3年周期（36ヶ月）の特別支払い定義
        let category = Category(name: "保険・税金")
        let definition = SpecialPaymentDefinition(
            name: "車検",
            amount: 120_000,
            recurrenceIntervalMonths: 36,
            firstOccurrenceDate: Date.from(year: 2028, month: 1) ?? Date(),
            category: category,
            savingStrategy: .evenlyDistributed,
        )

        context.insert(category)
        context.insert(definition)
        try context.save()

        // 月次積立額は 120,000 / 36 = 3,333.33... ≈ 3333円（Decimalの精度）
        #expect(definition.monthlySavingAmount == Decimal(string: "3333.333333333333333333333333333333"))

        // When: 36ヶ月分の積立を記録
        var balance: SpecialPaymentSavingBalance?
        for month in 1 ... 36 {
            balance = balanceService.recordMonthlySavings(
                for: definition,
                balance: balance,
                year: 2025 + (month - 1) / 12,
                month: ((month - 1) % 12) + 1,
                context: context,
            )
        }

        let finalBalance = try #require(balance)

        // Then: 累計積立額が目標金額に近いこと
        // 3333.33... × 36 = 120,000
        #expect(finalBalance.totalSavedAmount >= 119_999)
        #expect(finalBalance.totalSavedAmount <= 120_001)
        #expect(finalBalance.totalPaidAmount == 0)
        #expect(finalBalance.balance >= 119_999)

        // 実績支払いを記録
        let occurrence = SpecialPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2028, month: 1) ?? Date(),
            expectedAmount: 120_000,
            status: .completed,
            actualDate: Date(),
            actualAmount: 120_000,
        )
        context.insert(occurrence)
        definition.occurrences = [occurrence]

        let difference = balanceService.processPayment(
            occurrence: occurrence,
            balance: finalBalance,
            context: context,
        )

        // Then: ぴったり支払えたことを確認
        #expect(difference.type == .exact)
        #expect(finalBalance.totalPaidAmount == 120_000)
        #expect(finalBalance.balance >= -1)
        #expect(finalBalance.balance <= 1)
    }

    // MARK: - 繰上げ払いケース

    @Test("繰上げ払い：実績 < 予定")
    internal func underpaidScenario() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        // Given
        let definition = SpecialPaymentDefinition(
            name: "自動車税",
            amount: 45000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2026, month: 5) ?? Date(),
            savingStrategy: .evenlyDistributed,
        )
        context.insert(definition)

        // 12ヶ月積立
        var balance: SpecialPaymentSavingBalance?
        for month in 1 ... 12 {
            balance = balanceService.recordMonthlySavings(
                for: definition,
                balance: balance,
                year: 2025,
                month: month,
                context: context,
            )
        }

        let finalBalance = try #require(balance)
        #expect(finalBalance.totalSavedAmount == 45000)

        // When: 実績が予定より少ない（値引きがあった）
        let occurrence = SpecialPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2026, month: 5) ?? Date(),
            expectedAmount: 45000,
            status: .completed,
            actualDate: Date(),
            actualAmount: 40000, // 5000円安く済んだ
        )
        context.insert(occurrence)
        definition.occurrences = [occurrence]

        let difference = balanceService.processPayment(
            occurrence: occurrence,
            balance: finalBalance,
            context: context,
        )

        // Then: 差額が残高に残る
        #expect(difference.type == .underpaid)
        #expect(difference.difference == -5000)
        #expect(finalBalance.totalPaidAmount == 40000)
        #expect(finalBalance.balance == 5000) // 余りが残る
    }

    // MARK: - 繰下げ払いケース

    @Test("繰下げ払い：実績 > 予定")
    internal func overpaidScenario() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        // Given
        let definition = SpecialPaymentDefinition(
            name: "車検",
            amount: 120_000,
            recurrenceIntervalMonths: 24,
            firstOccurrenceDate: Date.from(year: 2026, month: 3) ?? Date(),
            savingStrategy: .evenlyDistributed,
        )
        context.insert(definition)

        // 24ヶ月積立
        var balance: SpecialPaymentSavingBalance?
        for month in 1 ... 24 {
            balance = balanceService.recordMonthlySavings(
                for: definition,
                balance: balance,
                year: 2024 + (month - 1) / 12,
                month: ((month - 1) % 12) + 1,
                context: context,
            )
        }

        let finalBalance = try #require(balance)
        #expect(finalBalance.totalSavedAmount == 120_000)

        // When: 実績が予定より多い（追加整備が必要だった）
        let occurrence = SpecialPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2026, month: 3) ?? Date(),
            expectedAmount: 120_000,
            status: .completed,
            actualDate: Date(),
            actualAmount: 135_000, // 15000円超過
        )
        context.insert(occurrence)
        definition.occurrences = [occurrence]

        let difference = balanceService.processPayment(
            occurrence: occurrence,
            balance: finalBalance,
            context: context,
        )

        // Then: 残高がマイナスになる（次回以降の積立で補填）
        #expect(difference.type == .overpaid)
        #expect(difference.difference == 15000)
        #expect(finalBalance.totalPaidAmount == 135_000)
        #expect(finalBalance.balance == -15000) // マイナス残高
        #expect(finalBalance.isBalanceInsufficient) // 不足フラグ
    }

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
        for month in 1 ... 12 {
            balance = balanceService.recordMonthlySavings(
                for: definition,
                balance: balance,
                year: 2024 + (month - 1) / 12,
                month: ((month - 1) % 12) + 1,
                context: context,
            )
        }

        let occurrence1 = SpecialPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2025, month: 4) ?? Date(),
            expectedAmount: 150_000,
            status: .completed,
            actualDate: Date(),
            actualAmount: 150_000,
        )
        context.insert(occurrence1)

        let finalBalance = try #require(balance)
        balanceService.processPayment(occurrence: occurrence1, balance: finalBalance, context: context)

        #expect(finalBalance.totalSavedAmount == 150_000)
        #expect(finalBalance.totalPaidAmount == 150_000)
        #expect(finalBalance.balance == 0)

        // 2回目のサイクル: 12ヶ月積立 + 支払い
        for month in 13 ... 24 {
            balance = balanceService.recordMonthlySavings(
                for: definition,
                balance: balance,
                year: 2024 + (month - 1) / 12,
                month: ((month - 1) % 12) + 1,
                context: context,
            )
        }

        let occurrence2 = SpecialPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2026, month: 4) ?? Date(),
            expectedAmount: 150_000,
            status: .completed,
            actualDate: Date(),
            actualAmount: 155_000, // 少し超過
        )
        context.insert(occurrence2)

        balanceService.processPayment(occurrence: occurrence2, balance: finalBalance, context: context)

        #expect(finalBalance.totalSavedAmount == 300_000)
        #expect(finalBalance.totalPaidAmount == 305_000)
        #expect(finalBalance.balance == -5000)

        // 3回目のサイクル: 12ヶ月積立 + 支払い
        for month in 25 ... 36 {
            balance = balanceService.recordMonthlySavings(
                for: definition,
                balance: balance,
                year: 2024 + (month - 1) / 12,
                month: ((month - 1) % 12) + 1,
                context: context,
            )
        }

        let occurrence3 = SpecialPaymentOccurrence(
            definition: definition,
            scheduledDate: Date.from(year: 2027, month: 4) ?? Date(),
            expectedAmount: 150_000,
            status: .completed,
            actualDate: Date(),
            actualAmount: 145_000, // 安く済んだ
        )
        context.insert(occurrence3)

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

        context.insert(categoryTax)
        context.insert(categoryEducation)
        context.insert(definition1)
        context.insert(definition2)
        context.insert(definition3)
        context.insert(definition4)
        try context.save()

        // When: 月次積立金額を計算
        let definitions = [definition1, definition2, definition3, definition4]
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
        var balances: [SpecialPaymentSavingBalance] = []
        for definition in [definition1, definition2, definition3] {
            var balance: SpecialPaymentSavingBalance?
            for month in 1 ... 6 {
                balance = balanceService.recordMonthlySavings(
                    for: definition,
                    balance: balance,
                    year: 2025,
                    month: month,
                    context: context,
                )
            }
            if let balance {
                balances.append(balance)
            }
        }

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
}
