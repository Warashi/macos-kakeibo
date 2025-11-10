import Foundation
import Testing

@testable import Kakeibo

@Suite
internal struct BudgetCalculationCacheStorageTests {
    @Test("月次予算キャッシュは保存した値を取得できる")
    internal func storesMonthlyBudgetEntries() {
        let cache = BudgetCalculationCache()
        let filter = FilterSignature(filter: .default)
        let key = MonthlyBudgetCacheKey(
            year: 2025,
            month: 1,
            filter: filter,
            excludedCategoriesSignature: 0,
            transactionsVersion: 1,
            budgetsVersion: 1
        )
        let calculation = MonthlyBudgetCalculation(
            year: 2025,
            month: 1,
            overallCalculation: BudgetCalculation(
                budgetAmount: 50_000,
                actualAmount: 30_000,
                remainingAmount: 20_000,
                usageRate: 0.6,
                isOverBudget: false
            ),
            categoryCalculations: [
                CategoryBudgetCalculation(
                    categoryId: UUID(),
                    categoryName: "食費",
                    calculation: BudgetCalculation(
                        budgetAmount: 30_000,
                        actualAmount: 20_000,
                        remainingAmount: 10_000,
                        usageRate: 0.66,
                        isOverBudget: false
                    )
                ),
            ]
        )

        cache.storeMonthlyBudget(calculation, for: key)

        let cached = cache.cachedMonthlyBudget(for: key)
        #expect(cached?.year == 2025)
        #expect(cached?.overallCalculation?.budgetAmount == Decimal(50_000))
        #expect(cached?.categoryCalculations.count == 1)
    }

    @Test("invalidateで指定したキャッシュだけを削除する")
    internal func invalidatesSelectedTargets() {
        let cache = BudgetCalculationCache()
        let filter = FilterSignature(filter: .default)
        let monthlyKey = MonthlyBudgetCacheKey(
            year: 2025,
            month: 2,
            filter: filter,
            excludedCategoriesSignature: 0,
            transactionsVersion: 1,
            budgetsVersion: 1
        )
        let monthlyValue = MonthlyBudgetCalculation(
            year: 2025,
            month: 2,
            overallCalculation: nil,
            categoryCalculations: []
        )
        cache.storeMonthlyBudget(monthlyValue, for: monthlyKey)

        let specialKey = SpecialPaymentSavingsCacheKey(
            year: 2025,
            month: 2,
            definitionsVersion: 1,
            balancesVersion: 1
        )
        let savingsValue = [
            SpecialPaymentSavingsCalculation(
                definitionId: UUID(),
                name: "車検",
                monthlySaving: 10_000,
                totalSaved: 100_000,
                totalPaid: 0,
                balance: 100_000,
                nextOccurrence: nil
            ),
        ]
        cache.storeSpecialPaymentSavings(savingsValue, for: specialKey)

        let categoryKey = SavingsAllocationCacheKey(
            year: 2025,
            month: 2,
            definitionsVersion: 1
        )
        let categoryValue: [UUID: Decimal] = [UUID(): Decimal(5_000)]
        cache.storeCategorySavingsAllocation(categoryValue, for: categoryKey)

        cache.invalidate(targets: [.monthlyBudget, .categorySavings])

        #expect(cache.cachedMonthlyBudget(for: monthlyKey) == nil)
        #expect(cache.cachedCategorySavingsAllocation(for: categoryKey) == nil)
        #expect(cache.cachedSpecialPaymentSavings(for: specialKey)?.count == 1)
    }

    @Test("キャッシュヒットとミスがメトリクスに反映される")
    internal func recordsMetrics() {
        let cache = BudgetCalculationCache()
        let filter = FilterSignature(filter: .default)
        let monthlyKey = MonthlyBudgetCacheKey(
            year: 2025,
            month: 3,
            filter: filter,
            excludedCategoriesSignature: 0,
            transactionsVersion: 1,
            budgetsVersion: 1
        )

        _ = cache.cachedMonthlyBudget(for: monthlyKey)
        cache.storeMonthlyBudget(
            MonthlyBudgetCalculation(
                year: 2025,
                month: 3,
                overallCalculation: nil,
                categoryCalculations: []
            ),
            for: monthlyKey
        )
        _ = cache.cachedMonthlyBudget(for: monthlyKey)

        let categoryKey = SavingsAllocationCacheKey(
            year: 2025,
            month: 3,
            definitionsVersion: 1
        )
        _ = cache.cachedCategorySavingsAllocation(for: categoryKey)
        cache.storeCategorySavingsAllocation([UUID(): Decimal(3_000)], for: categoryKey)
        _ = cache.cachedCategorySavingsAllocation(for: categoryKey)

        let metrics = cache.metricsSnapshot
        #expect(metrics.monthlyBudgetMisses == 1)
        #expect(metrics.monthlyBudgetHits == 1)
        #expect(metrics.categorySavingsMisses == 1)
        #expect(metrics.categorySavingsHits == 1)
    }
}
