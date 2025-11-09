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
        let majorCategory = Category(name: "食費", displayOrder: 1)
        let minorCategory = Category(name: "外食", parent: majorCategory, displayOrder: 1)
        majorCategory.addChild(minorCategory)

        // 大項目「食費」に対して年次予算を設定（12ヶ月 × 50,000円 = 600,000円）
        let budget = Budget(
            amount: 50000,
            category: majorCategory,
            startYear: 2025,
            startMonth: 1,
            endYear: 2025,
            endMonth: 12,
        )

        // 取引データを作成
        let transactions: [Transaction] = [
            // 大項目のみの取引: 10,000円
            Transaction(
                date: Date.from(year: 2025, month: 1, day: 15) ?? Date(),
                title: "食材購入",
                amount: -10000,
                majorCategory: majorCategory,
                minorCategory: nil,
            ),
            // 中項目も設定された取引: 5,000円
            Transaction(
                date: Date.from(year: 2025, month: 1, day: 20) ?? Date(),
                title: "ランチ",
                amount: -5000,
                majorCategory: majorCategory,
                minorCategory: minorCategory,
            ),
            // 中項目も設定された取引: 8,000円
            Transaction(
                date: Date.from(year: 2025, month: 2, day: 10) ?? Date(),
                title: "ディナー",
                amount: -8000,
                majorCategory: majorCategory,
                minorCategory: minorCategory,
            ),
        ]

        // When: 年次予算進捗を計算
        let result = calculator.calculate(
            budgets: [budget],
            transactions: transactions,
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
        let majorCategory = Category(name: "食費", displayOrder: 1)
        let minorCategory1 = Category(name: "外食", parent: majorCategory, displayOrder: 1)
        let minorCategory2 = Category(name: "食材", parent: majorCategory, displayOrder: 2)
        majorCategory.addChild(minorCategory1)
        majorCategory.addChild(minorCategory2)

        // 中項目「外食」に対して年次予算を設定
        let budget = Budget(
            amount: 30000,
            category: minorCategory1,
            startYear: 2025,
            startMonth: 1,
            endYear: 2025,
            endMonth: 12,
        )

        // 取引データを作成
        let transactions: [Transaction] = [
            // 外食の取引: 5,000円
            Transaction(
                date: Date.from(year: 2025, month: 1, day: 20) ?? Date(),
                title: "ランチ",
                amount: -5000,
                majorCategory: majorCategory,
                minorCategory: minorCategory1,
            ),
            // 食材の取引: 10,000円（これは含まれない）
            Transaction(
                date: Date.from(year: 2025, month: 1, day: 15) ?? Date(),
                title: "スーパー",
                amount: -10000,
                majorCategory: majorCategory,
                minorCategory: minorCategory2,
            ),
        ]

        // When: 年次予算進捗を計算
        let result = calculator.calculate(
            budgets: [budget],
            transactions: transactions,
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
        let result = calculator.calculate(
            budgets: testData.budgets,
            transactions: testData.transactions,
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
        let budgets: [Budget]
        let transactions: [Transaction]
        let foodCategory: Category
        let transportCategory: Category
    }

    private func createMultipleCategoryTestData() -> MultipleCategoryTestData {
        let foodCategory = Category(name: "食費", displayOrder: 1)
        let diningOut = Category(name: "外食", parent: foodCategory, displayOrder: 1)
        foodCategory.addChild(diningOut)

        let transportCategory = Category(name: "交通費", displayOrder: 2)

        let budgets = [
            Budget(
                amount: 50000,
                category: foodCategory,
                startYear: 2025,
                startMonth: 1,
                endYear: 2025,
                endMonth: 12,
            ),
            Budget(
                amount: 20000,
                category: transportCategory,
                startYear: 2025,
                startMonth: 1,
                endYear: 2025,
                endMonth: 12,
            ),
        ]

        let transactions: [Transaction] = [
            Transaction(
                date: Date.from(year: 2025, month: 1, day: 15) ?? Date(),
                title: "食材",
                amount: -10000,
                majorCategory: foodCategory,
            ),
            Transaction(
                date: Date.from(year: 2025, month: 1, day: 20) ?? Date(),
                title: "ランチ",
                amount: -5000,
                majorCategory: foodCategory,
                minorCategory: diningOut,
            ),
            Transaction(
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
            transportCategory: transportCategory,
        )
    }
}
