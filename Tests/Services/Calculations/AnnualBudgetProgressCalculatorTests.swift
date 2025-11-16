import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite(.serialized)
internal struct AnnualBudgetProgressCalculatorTests {
    private let calculator: AnnualBudgetProgressCalculator = AnnualBudgetProgressCalculator()

    @Test("大項目のみの予算：中項目を持つ取引の実績も含まれる")
    internal func majorCategoryBudget_includesMinorCategoryTransactions() throws {
        // Given: 大項目「食費」と中項目「食費 / 外食」を作成
        let majorCategory = CategoryEntity(name: "食費", displayOrder: 1)
        let minorCategory = CategoryEntity(name: "外食", parent: majorCategory, displayOrder: 1)
        majorCategory.addChild(minorCategory)

        // 大項目「食費」に対して年次予算を設定（12ヶ月 × 50,000円 = 600,000円）
        let budget = BudgetEntity(
            amount: 50000,
            category: majorCategory,
            startYear: 2025,
            startMonth: 1,
            endYear: 2025,
            endMonth: 12,
        )

        // 取引データを作成
        let transactions: [TransactionEntity] = [
            // 大項目のみの取引: 10,000円
            TransactionEntity(
                date: Date.from(year: 2025, month: 1, day: 15) ?? Date(),
                title: "食材購入",
                amount: -10000,
                majorCategory: majorCategory,
                minorCategory: nil,
            ),
            // 中項目も設定された取引: 5,000円
            TransactionEntity(
                date: Date.from(year: 2025, month: 1, day: 20) ?? Date(),
                title: "ランチ",
                amount: -5000,
                majorCategory: majorCategory,
                minorCategory: minorCategory,
            ),
            // 中項目も設定された取引: 8,000円
            TransactionEntity(
                date: Date.from(year: 2025, month: 2, day: 10) ?? Date(),
                title: "ディナー",
                amount: -8000,
                majorCategory: majorCategory,
                minorCategory: minorCategory,
            ),
        ]

        // When: 年次予算進捗を計算
        let categories = [Category(from: majorCategory), Category(from: minorCategory)]
        let result = calculator.calculate(
            budgets: [Budget(from: budget)],
            transactions: transactions.map { Transaction(from: $0) },
            categories: categories,
            year: 2025,
        )

        // Then: 大項目「食費」の実績が全取引の合計になっていることを確認
        let foodEntry = result.categoryEntries.first { entry in
            if case let .category(id) = entry.id {
                return id == majorCategory.id
            }
            return false
        }

        #expect(foodEntry != nil, "大項目「食費」のエントリが存在する")

        if let foodEntry {
            // 実績合計: 10,000 + 5,000 + 8,000 = 23,000円
            let expectedActual: Decimal = 23000
            #expect(
                foodEntry.calculation.actualAmount == expectedActual,
                "実績が全取引の合計（\(expectedActual)円）になっている。実際: \(foodEntry.calculation.actualAmount)円",
            )

            // 予算額: 50,000 × 12 = 600,000円
            let expectedBudget: Decimal = 600_000
            #expect(
                foodEntry.calculation.budgetAmount == expectedBudget,
                "予算額が正しい（\(expectedBudget)円）",
            )
        }
    }

    @Test("中項目のみの予算：その中項目の取引のみが含まれる")
    internal func minorCategoryBudget_includesOnlyMinorCategoryTransactions() throws {
        // Given: 大項目「食費」と中項目「食費 / 外食」を作成
        let majorCategory = CategoryEntity(name: "食費", displayOrder: 1)
        let minorCategory1 = CategoryEntity(name: "外食", parent: majorCategory, displayOrder: 1)
        let minorCategory2 = CategoryEntity(name: "食材", parent: majorCategory, displayOrder: 2)
        majorCategory.addChild(minorCategory1)
        majorCategory.addChild(minorCategory2)

        // 中項目「外食」に対して年次予算を設定
        let budget = BudgetEntity(
            amount: 30000,
            category: minorCategory1,
            startYear: 2025,
            startMonth: 1,
            endYear: 2025,
            endMonth: 12,
        )

        // 取引データを作成
        let transactions: [TransactionEntity] = [
            // 外食の取引: 5,000円
            TransactionEntity(
                date: Date.from(year: 2025, month: 1, day: 20) ?? Date(),
                title: "ランチ",
                amount: -5000,
                majorCategory: majorCategory,
                minorCategory: minorCategory1,
            ),
            // 食材の取引: 10,000円（これは含まれない）
            TransactionEntity(
                date: Date.from(year: 2025, month: 1, day: 15) ?? Date(),
                title: "スーパー",
                amount: -10000,
                majorCategory: majorCategory,
                minorCategory: minorCategory2,
            ),
        ]

        // When: 年次予算進捗を計算
        let categories = [
            Category(from: majorCategory),
            Category(from: minorCategory1),
            Category(from: minorCategory2),
        ]
        let result = calculator.calculate(
            budgets: [Budget(from: budget)],
            transactions: transactions.map { Transaction(from: $0) },
            categories: categories,
            year: 2025,
        )

        // Then: 中項目「外食」の実績が外食取引のみになっていることを確認
        let diningOutEntry = result.categoryEntries.first { entry in
            if case let .category(id) = entry.id {
                return id == minorCategory1.id
            }
            return false
        }

        #expect(diningOutEntry != nil, "中項目「外食」のエントリが存在する")

        if let diningOutEntry {
            // 実績合計: 5,000円のみ（食材の10,000円は含まれない）
            let expectedActual: Decimal = 5000
            #expect(
                diningOutEntry.calculation.actualAmount == expectedActual,
                "実績が外食取引のみの合計（\(expectedActual)円）になっている",
            )
        }
    }

    @Test("複数カテゴリの予算：それぞれ正しく実績が計算される")
    internal func multipleCategoryBudgets_calculatesCorrectly() throws {
        // Given: 複数のカテゴリと取引を作成
        let testData = createMultipleCategoryTestData()

        // When: 年次予算進捗を計算
        let categories = [
            Category(from: testData.foodCategory),
            Category(from: testData.diningOutCategory),
            Category(from: testData.transportCategory),
        ]
        let result = calculator.calculate(
            budgets: testData.budgets.map { Budget(from: $0) },
            transactions: testData.transactions.map { Transaction(from: $0) },
            categories: categories,
            year: 2025,
        )

        // Then: 各カテゴリの実績が正しいことを確認
        let foodEntry = findCategoryEntry(in: result.categoryEntries, categoryId: testData.foodCategory.id)
        let transportEntry = findCategoryEntry(in: result.categoryEntries, categoryId: testData.transportCategory.id)

        #expect(foodEntry != nil, "「食費」のエントリが存在する")
        #expect(transportEntry != nil, "「交通費」のエントリが存在する")

        if let foodEntry {
            #expect(
                foodEntry.calculation.actualAmount == 15000,
                "食費の実績が正しい（15,000円）",
            )
        }

        if let transportEntry {
            #expect(
                transportEntry.calculation.actualAmount == 3000,
                "交通費の実績が正しい（3,000円）",
            )
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
        let budgets: [BudgetEntity]
        let transactions: [TransactionEntity]
        let foodCategory: Kakeibo.CategoryEntity
        let diningOutCategory: Kakeibo.CategoryEntity
        let transportCategory: Kakeibo.CategoryEntity
    }

    private func createMultipleCategoryTestData() -> MultipleCategoryTestData {
        let foodCategory = CategoryEntity(name: "食費", displayOrder: 1)
        let diningOut = CategoryEntity(name: "外食", parent: foodCategory, displayOrder: 1)
        foodCategory.addChild(diningOut)

        let transportCategory = CategoryEntity(name: "交通費", displayOrder: 2)

        let budgets = [
            BudgetEntity(
                amount: 50000,
                category: foodCategory,
                startYear: 2025,
                startMonth: 1,
                endYear: 2025,
                endMonth: 12,
            ),
            BudgetEntity(
                amount: 20000,
                category: transportCategory,
                startYear: 2025,
                startMonth: 1,
                endYear: 2025,
                endMonth: 12,
            ),
        ]

        let transactions: [TransactionEntity] = [
            TransactionEntity(
                date: Date.from(year: 2025, month: 1, day: 15) ?? Date(),
                title: "食材",
                amount: -10000,
                majorCategory: foodCategory,
            ),
            TransactionEntity(
                date: Date.from(year: 2025, month: 1, day: 20) ?? Date(),
                title: "ランチ",
                amount: -5000,
                majorCategory: foodCategory,
                minorCategory: diningOut,
            ),
            TransactionEntity(
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
        let foodCategory = CategoryEntity(name: "食費", displayOrder: 1)
        let transportCategory = CategoryEntity(name: "交通費", displayOrder: 2)

        // 全体予算: 600,000円/年（50,000円/月 × 12ヶ月）
        let overallBudget = BudgetEntity(
            amount: 50000,
            category: nil,
            startYear: 2025,
            startMonth: 1,
            endYear: 2025,
            endMonth: 12,
        )

        // カテゴリ別予算
        let foodBudget = BudgetEntity(
            amount: 30000,
            category: foodCategory,
            startYear: 2025,
            startMonth: 1,
            endYear: 2025,
            endMonth: 12,
        )

        // 取引データを作成
        let transactions: [TransactionEntity] = [
            // 食費: 10,000円
            TransactionEntity(
                date: Date.from(year: 2025, month: 1, day: 15) ?? Date(),
                title: "食材",
                amount: -10000,
                majorCategory: foodCategory,
            ),
            // 交通費: 5,000円
            TransactionEntity(
                date: Date.from(year: 2025, month: 1, day: 20) ?? Date(),
                title: "電車",
                amount: -5000,
                majorCategory: transportCategory,
            ),
        ]

        // When: 食費カテゴリを除外して年次予算進捗を計算
        let excludedCategoryIds: Set<UUID> = [foodCategory.id]
        let categories = [Category(from: foodCategory), Category(from: transportCategory)]
        let result = calculator.calculate(
            budgets: [Budget(from: overallBudget), Budget(from: foodBudget)],
            transactions: transactions.map { Transaction(from: $0) },
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
        let foodCategory = CategoryEntity(name: "食費", displayOrder: 1)
        let transportCategory = CategoryEntity(name: "交通費", displayOrder: 2)
        let entertainmentCategory = CategoryEntity(name: "娯楽費", displayOrder: 3)

        // 全体予算: 600,000円/年
        let overallBudget = BudgetEntity(
            amount: 50000,
            category: nil,
            startYear: 2025,
            startMonth: 1,
            endYear: 2025,
            endMonth: 12,
        )

        // 取引データを作成
        let transactions: [TransactionEntity] = [
            // 食費: 10,000円
            TransactionEntity(
                date: Date.from(year: 2025, month: 1, day: 15) ?? Date(),
                title: "食材",
                amount: -10000,
                majorCategory: foodCategory,
            ),
            // 交通費: 5,000円
            TransactionEntity(
                date: Date.from(year: 2025, month: 1, day: 20) ?? Date(),
                title: "電車",
                amount: -5000,
                majorCategory: transportCategory,
            ),
            // 娯楽費: 8,000円
            TransactionEntity(
                date: Date.from(year: 2025, month: 1, day: 25) ?? Date(),
                title: "映画",
                amount: -8000,
                majorCategory: entertainmentCategory,
            ),
        ]

        // When: 食費と娯楽費を除外して年次予算進捗を計算
        let excludedCategoryIds: Set<UUID> = [foodCategory.id, entertainmentCategory.id]
        let categories = [
            Category(from: foodCategory),
            Category(from: transportCategory),
            Category(from: entertainmentCategory),
        ]
        let result = calculator.calculate(
            budgets: [Budget(from: overallBudget)],
            transactions: transactions.map { Transaction(from: $0) },
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
}
