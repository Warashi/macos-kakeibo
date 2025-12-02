import Foundation
import Testing

@testable import Kakeibo

@Suite(.serialized)
internal struct AnnualBudgetProgressCalculatorTests {
    private let calculator: AnnualBudgetProgressCalculator = AnnualBudgetProgressCalculator()

    @Test("大項目のみの予算：中項目を持つ取引の実績も含まれる")
    internal func majorCategoryBudget_includesMinorCategoryTransactions() throws {
        let majorCategory = DomainFixtures.category(name: "食費", displayOrder: 1)
        let minorCategory = DomainFixtures.category(name: "外食", displayOrder: 1, parent: majorCategory)
        let budget = DomainFixtures.budget(
            amount: 50000,
            category: majorCategory,
            startYear: 2025,
            startMonth: 1,
            endYear: 2025,
            endMonth: 12,
        )
        let transactions: [Transaction] = [
            DomainFixtures.transaction(
                date: Date.from(year: 2025, month: 1, day: 15) ?? Date(),
                title: "食材購入",
                amount: -10000,
                majorCategory: majorCategory,
            ),
            DomainFixtures.transaction(
                date: Date.from(year: 2025, month: 1, day: 20) ?? Date(),
                title: "ランチ",
                amount: -5000,
                majorCategory: majorCategory,
                minorCategory: minorCategory,
            ),
            DomainFixtures.transaction(
                date: Date.from(year: 2025, month: 2, day: 10) ?? Date(),
                title: "ディナー",
                amount: -8000,
                majorCategory: majorCategory,
                minorCategory: minorCategory,
            ),
        ]
        let categories = [majorCategory, minorCategory]
        let result = calculator.calculate(
            budgets: [budget],
            transactions: transactions,
            categories: categories,
            year: 2025,
        )
        let foodEntry = result.categoryEntries.first { entry in
            if case let .category(id) = entry.id {
                return id == majorCategory.id
            }
            return false
        }
        #expect(foodEntry != nil)
        if let foodEntry {
            #expect(foodEntry.calculation.actualAmount == 23000)
            #expect(foodEntry.calculation.budgetAmount == 600_000)
        }
    }

    @Test("中項目のみの予算：その中項目の取引のみが含まれる")
    internal func minorCategoryBudget_includesOnlyMinorCategoryTransactions() throws {
        let majorCategory = DomainFixtures.category(name: "食費", displayOrder: 1)
        let minorCategory1 = DomainFixtures.category(name: "外食", displayOrder: 1, parent: majorCategory)
        let minorCategory2 = DomainFixtures.category(name: "食材", displayOrder: 2, parent: majorCategory)
        let budget = DomainFixtures.budget(
            amount: 30000,
            category: minorCategory1,
            startYear: 2025,
            startMonth: 1,
            endYear: 2025,
            endMonth: 12,
        )
        let transactions: [Transaction] = [
            DomainFixtures.transaction(
                date: Date.from(year: 2025, month: 1, day: 20) ?? Date(),
                title: "ランチ",
                amount: -5000,
                majorCategory: majorCategory,
                minorCategory: minorCategory1,
            ),
            DomainFixtures.transaction(
                date: Date.from(year: 2025, month: 1, day: 15) ?? Date(),
                title: "スーパー",
                amount: -10000,
                majorCategory: majorCategory,
                minorCategory: minorCategory2,
            ),
        ]
        let categories = [majorCategory, minorCategory1, minorCategory2]
        let result = calculator.calculate(
            budgets: [budget],
            transactions: transactions,
            categories: categories,
            year: 2025,
        )
        let diningOutEntry = result.categoryEntries.first { entry in
            if case let .category(id) = entry.id {
                return id == minorCategory1.id
            }
            return false
        }
        #expect(diningOutEntry != nil)
        if let diningOutEntry {
            #expect(diningOutEntry.calculation.actualAmount == 5000)
        }
    }

    @Test("複数カテゴリの予算：それぞれ正しく実績が計算される")
    internal func multipleCategoryBudgets_calculatesCorrectly() throws {
        let testData = createMultipleCategoryTestData()
        let categories = [testData.foodCategory, testData.diningOutCategory, testData.transportCategory]
        let result = calculator.calculate(
            budgets: testData.budgets,
            transactions: testData.transactions,
            categories: categories,
            year: 2025,
        )
        let foodEntry = findCategoryEntry(in: result.categoryEntries, categoryId: testData.foodCategory.id)
        let transportEntry = findCategoryEntry(in: result.categoryEntries, categoryId: testData.transportCategory.id)
        #expect(foodEntry != nil)
        #expect(transportEntry != nil)
        if let foodEntry {
            #expect(foodEntry.calculation.actualAmount == 15000)
        }
        if let transportEntry {
            #expect(transportEntry.calculation.actualAmount == 3000)
        }
    }

    // MARK: - Helper Methods

    private func findCategoryEntry(
        in entries: [AnnualBudgetEntry],
        categoryId: UUID,
    ) -> AnnualBudgetEntry? {
        entries.first { entry in
            if case let .category(id) = entry.id {
                return id == categoryId
            }
            return false
        }
    }

    private struct MultipleCategoryTestData {
        let budgets: [Budget]
        let transactions: [Transaction]
        let foodCategory: Kakeibo.Category
        let diningOutCategory: Kakeibo.Category
        let transportCategory: Kakeibo.Category
    }

    private func createMultipleCategoryTestData() -> MultipleCategoryTestData {
        let foodCategory = DomainFixtures.category(name: "食費", displayOrder: 1)
        let diningOut = DomainFixtures.category(name: "外食", displayOrder: 1, parent: foodCategory)
        let transportCategory = DomainFixtures.category(name: "交通費", displayOrder: 2)

        let budgets = [
            DomainFixtures.budget(
                amount: 50000,
                category: foodCategory,
                startYear: 2025,
                startMonth: 1,
                endYear: 2025,
                endMonth: 12,
            ),
            DomainFixtures.budget(
                amount: 20000,
                category: transportCategory,
                startYear: 2025,
                startMonth: 1,
                endYear: 2025,
                endMonth: 12,
            ),
        ]

        let transactions: [Transaction] = [
            DomainFixtures.transaction(
                date: Date.from(year: 2025, month: 1, day: 15) ?? Date(),
                title: "食材",
                amount: -10000,
                majorCategory: foodCategory,
            ),
            DomainFixtures.transaction(
                date: Date.from(year: 2025, month: 1, day: 20) ?? Date(),
                title: "ランチ",
                amount: -5000,
                majorCategory: foodCategory,
                minorCategory: diningOut,
            ),
            DomainFixtures.transaction(
                date: Date.from(year: 2025, month: 1, day: 25) ?? Date(),
                title: "電車",
                amount: -3000,
                majorCategory: transportCategory,
            ),
        ]

        return MultipleCategoryTestData(
            budgets: budgets,
            transactions: transactions,
            foodCategory: foodCategory,
            diningOutCategory: diningOut,
            transportCategory: transportCategory,
        )
    }

    @Test("全体予算の計算で除外カテゴリの支出が含まれない")
    internal func overallBudget_excludesExcludedCategoryExpense() throws {
        // Given: カテゴリと予算を作成
        let foodCategory = DomainFixtures.category(name: "食費", displayOrder: 1)
        let transportCategory = DomainFixtures.category(name: "交通費", displayOrder: 2)

        // 全体予算: 600,000円/年（50,000円/月 × 12ヶ月）
        let overallBudget = DomainFixtures.budget(
            amount: 50000,
            categoryId: nil,
            startYear: 2025,
            startMonth: 1,
            endYear: 2025,
            endMonth: 12,
        )

        // カテゴリ別予算
        let foodBudget = DomainFixtures.budget(
            amount: 30000,
            category: foodCategory,
            startYear: 2025,
            startMonth: 1,
            endYear: 2025,
            endMonth: 12,
        )

        // 取引データを作成
        let transactions: [Transaction] = [
            // 食費: 10,000円
            DomainFixtures.transaction(
                date: Date.from(year: 2025, month: 1, day: 15) ?? Date(),
                title: "食材",
                amount: -10000,
                majorCategory: foodCategory,
            ),
            // 交通費: 5,000円
            DomainFixtures.transaction(
                date: Date.from(year: 2025, month: 1, day: 20) ?? Date(),
                title: "電車",
                amount: -5000,
                majorCategory: transportCategory,
            ),
        ]

        // When: 食費カテゴリを除外して年次予算進捗を計算
        let excludedCategoryIds: Set<UUID> = [foodCategory.id]
        let categories = [foodCategory, transportCategory]
        let result = calculator.calculate(
            budgets: [overallBudget, foodBudget],
            transactions: transactions,
            categories: categories,
            year: 2025,
            excludedCategoryIds: excludedCategoryIds,
        )

        // Then: 全体予算の実績が交通費のみ（5,000円）になっていることを確認
        #expect(result.overallEntry != nil, "全体予算エントリが存在する")

        if let overallEntry = result.overallEntry {
            // 食費(10,000円)は除外され、交通費(5,000円)のみが実績に含まれる
            let expectedActual: Decimal = 5000
            #expect(
                overallEntry.calculation.actualAmount == expectedActual,
                "全体予算の実績が除外カテゴリ以外の支出のみになっている（\(expectedActual)円）。実際: \(overallEntry.calculation.actualAmount)円",
            )

            // 予算額: 50,000 × 12 = 600,000円
            let expectedBudget: Decimal = 600_000
            #expect(
                overallEntry.calculation.budgetAmount == expectedBudget,
                "全体予算額が正しい（\(expectedBudget)円）",
            )
        }
    }

    @Test("除外カテゴリが複数ある場合も正しく計算される")
    internal func overallBudget_excludesMultipleCategories() throws {
        // Given: 複数のカテゴリと予算を作成
        let foodCategory = DomainFixtures.category(name: "食費", displayOrder: 1)
        let transportCategory = DomainFixtures.category(name: "交通費", displayOrder: 2)
        let entertainmentCategory = DomainFixtures.category(name: "娯楽費", displayOrder: 3)

        // 全体予算: 600,000円/年
        let overallBudget = DomainFixtures.budget(
            amount: 50000,
            categoryId: nil,
            startYear: 2025,
            startMonth: 1,
            endYear: 2025,
            endMonth: 12,
        )

        // 取引データを作成
        let transactions: [Transaction] = [
            // 食費: 10,000円
            DomainFixtures.transaction(
                date: Date.from(year: 2025, month: 1, day: 15) ?? Date(),
                title: "食材",
                amount: -10000,
                majorCategory: foodCategory,
            ),
            // 交通費: 5,000円
            DomainFixtures.transaction(
                date: Date.from(year: 2025, month: 1, day: 20) ?? Date(),
                title: "電車",
                amount: -5000,
                majorCategory: transportCategory,
            ),
            // 娯楽費: 8,000円
            DomainFixtures.transaction(
                date: Date.from(year: 2025, month: 1, day: 25) ?? Date(),
                title: "映画",
                amount: -8000,
                majorCategory: entertainmentCategory,
            ),
        ]

        // When: 食費と娯楽費を除外して年次予算進捗を計算
        let excludedCategoryIds: Set<UUID> = [foodCategory.id, entertainmentCategory.id]
        let categories = [
            foodCategory,
            transportCategory,
            entertainmentCategory,
        ]
        let result = calculator.calculate(
            budgets: [overallBudget],
            transactions: transactions,
            categories: categories,
            year: 2025,
            excludedCategoryIds: excludedCategoryIds,
        )

        // Then: 全体予算の実績が交通費のみ（5,000円）になっていることを確認
        #expect(result.overallEntry != nil, "全体予算エントリが存在する")

        if let overallEntry = result.overallEntry {
            // 食費(10,000円)と娯楽費(8,000円)は除外され、交通費(5,000円)のみが実績に含まれる
            let expectedActual: Decimal = 5000
            #expect(
                overallEntry.calculation.actualAmount == expectedActual,
                "全体予算の実績が除外カテゴリ以外の支出のみになっている（\(expectedActual)円）。実際: \(overallEntry.calculation.actualAmount)円",
            )
        }
    }

    @Test("upToMonthを指定した場合、その月までの実績のみが計算される")
    internal func calculate_withUpToMonth() throws {
        // Given: カテゴリと予算を作成
        let foodCategory = DomainFixtures.category(name: "食費", displayOrder: 1)

        // 年次予算: 600,000円/年（50,000円/月 × 12ヶ月）
        let budget = DomainFixtures.budget(
            amount: 50000,
            category: foodCategory,
            startYear: 2025,
            startMonth: 1,
            endYear: 2025,
            endMonth: 12,
        )

        // 取引データを作成（1月〜6月）
        let transactions: [Transaction] = (1 ... 6).map { month in
            DomainFixtures.transaction(
                date: Date.from(year: 2025, month: month, day: 15) ?? Date(),
                title: "食材\(month)月",
                amount: -10000,
                majorCategory: foodCategory,
            )
        }

        // When: 3月までの年次予算進捗を計算
        let result = calculator.calculate(
            budgets: [budget],
            transactions: transactions,
            categories: [foodCategory],
            year: 2025,
            upToMonth: 3,
        )

        // Then: 実績が1月〜3月の合計（30,000円）になっていることを確認
        let foodEntry = findCategoryEntry(in: result.categoryEntries, categoryId: foodCategory.id)
        #expect(foodEntry != nil, "食費のエントリが存在する")

        if let foodEntry {
            let expectedActual: Decimal = 30000 // 10,000円 × 3ヶ月
            #expect(
                foodEntry.calculation.actualAmount == expectedActual,
                "実績が1月〜3月の合計（\(expectedActual)円）になっている。実際: \(foodEntry.calculation.actualAmount)円",
            )

            // 予算額も対象月数分（50,000円 × 3ヶ月）
            let expectedBudget: Decimal = 150_000
            #expect(
                foodEntry.calculation.budgetAmount == expectedBudget,
                "予算額が対象月数分（\(expectedBudget)円）",
            )
        }
    }
}
