import Foundation
@testable import Kakeibo
import SwiftData
import Testing

/// 特別支払い積立・充当ロジックの統合テスト（月次予算統合シナリオ）
///
/// 月次予算への組み込みや複雑なエンドツーエンドシナリオを検証します。
@Suite("SpecialPaymentSavings Budget Integration Tests")
internal struct SpecialPaymentSavingsComplexTests {
    private let balanceService: SpecialPaymentBalanceService = SpecialPaymentBalanceService()
    private let calculator: BudgetCalculator = BudgetCalculator()

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
        let definitionDTOs = definitions.map { SpecialPaymentDefinitionDTO(from: $0) }
        let totalAllocation = calculator.calculateMonthlySavingsAllocation(
            definitions: definitionDTOs,
            year: 2025,
            month: 11,
        )

        // Then: 積立有効な定義のみの合計
        // 自動車税: 3750, 固定資産税: 12500, 学資保険: 12000
        let expected = Decimal(3750) + Decimal(12500) + Decimal(12000)
        #expect(totalAllocation == expected)

        // カテゴリ別積立金額を計算
        let categoryAllocations = calculator.calculateCategorySavingsAllocation(
            definitions: definitionDTOs,
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

        let balanceDTOs = balances.map { SpecialPaymentSavingBalanceDTO(from: $0) }
        let savingsInput = SpecialPaymentSavingsCalculationInput(
            definitions: definitionDTOs,
            balances: balanceDTOs,
            occurrences: [],
            year: 2025,
            month: 6,
        )
        let savingsCalculations = calculator.calculateSpecialPaymentSavings(savingsInput)

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

    /// 特別支払い定義のパラメータ
    private struct DefinitionParams {
        internal let name: String
        internal let amount: Decimal
        internal let year: Int
        internal let month: Int
        internal let category: Kakeibo.Category?
        internal let strategy: SpecialPaymentSavingStrategy
        internal let customAmount: Decimal?

        internal init(
            name: String,
            amount: Decimal,
            year: Int,
            month: Int,
            category: Kakeibo.Category? = nil,
            strategy: SpecialPaymentSavingStrategy,
            customAmount: Decimal? = nil,
        ) {
            self.name = name
            self.amount = amount
            self.year = year
            self.month = month
            self.category = category
            self.strategy = strategy
            self.customAmount = customAmount
        }
    }

    /// 特別支払い定義を作成するヘルパー
    private func makeDefinition(params: DefinitionParams) -> SpecialPaymentDefinition {
        SpecialPaymentDefinition(
            name: params.name,
            amount: params.amount,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: params.year, month: params.month) ?? Date(),
            category: params.category,
            savingStrategy: params.strategy,
            customMonthlySavingAmount: params.customAmount,
        )
    }

    /// 複数の特別支払い定義を作成するヘルパー関数
    private func createMultipleDefinitions(
        categoryTax: Kakeibo.Category,
        categoryEducation: Kakeibo.Category,
        context: ModelContext,
    ) -> [SpecialPaymentDefinition] {
        let definitions: [SpecialPaymentDefinition] = [
            makeDefinition(params: DefinitionParams(
                name: "自動車税",
                amount: 45000,
                year: 2026,
                month: 5,
                category: categoryTax,
                strategy: .evenlyDistributed,
            )),
            makeDefinition(params: DefinitionParams(
                name: "固定資産税",
                amount: 150_000,
                year: 2026,
                month: 4,
                category: categoryTax,
                strategy: .evenlyDistributed,
            )),
            makeDefinition(params: DefinitionParams(
                name: "学資保険",
                amount: 120_000,
                year: 2026,
                month: 3,
                category: categoryEducation,
                strategy: .customMonthly,
                customAmount: 12000,
            )),
            makeDefinition(params: DefinitionParams(
                name: "積立なし",
                amount: 50000,
                year: 2026,
                month: 6,
                strategy: .disabled,
            )),
        ]

        definitions.forEach(context.insert)
        return definitions
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
                    params: SpecialPaymentBalanceService.MonthlySavingsParameters(
                        definition: definition,
                        balance: balance,
                        year: year,
                        month: month,
                        context: context,
                    ),
                )
            }
            if let balance {
                balances.append(balance)
            }
        }
        return balances
    }
}
