import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite(.serialized)
@MainActor
internal struct DashboardStoreTests {
    @Test("初期化：現在の年月が設定される")
    internal func initialization_setsCurrentYearMonth() async throws {
        // Given
        let container = try createInMemoryContainer()
        let context = ModelContext(container)

        // When
        let store = await makeStore(container: container)

        // Then
        let now = Date()
        #expect(store.currentYear == now.year)
        #expect(store.currentMonth == now.month)
        #expect(store.displayMode == .monthly)
    }

    @Test("月次集計：データがある場合")
    internal func monthlySummary_withData() async throws {
        // Given
        let container = try createInMemoryContainer()
        let context = ModelContext(container)
        let category = SwiftDataCategory(name: "食費")
        context.insert(category)

        let transaction = SwiftDataTransaction(
            date: Date.from(year: 2025, month: 11) ?? Date(),
            title: "スーパー",
            amount: -5000,
            majorCategory: category,
        )
        context.insert(transaction)
        try context.save()

        let store = await makeStore(container: container)
        store.currentYear = 2025
        store.currentMonth = 11
        await store.refresh()

        // When
        let summary = store.monthlySummary

        // Then
        #expect(summary.year == 2025)
        #expect(summary.month == 11)
        #expect(summary.totalExpense == 5000)
        #expect(summary.transactionCount == 1)
    }

    @Test("月次集計：年跨ぎ境界でも正しく集計する")
    internal func monthlySummary_handlesYearBoundary() async throws {
        let container = try createInMemoryContainer()
        let context = ModelContext(container)
        let category = SwiftDataCategory(name: "雑費")
        context.insert(category)

        let decemberDate = try #require(Date.from(year: 2025, month: 12, day: 15))
        let januaryDate = try #require(Date.from(year: 2026, month: 1, day: 5))
        context.insert(
            SwiftDataTransaction(
                date: decemberDate,
                title: "年末出費",
                amount: -8000,
                majorCategory: category,
            ),
        )
        context.insert(
            SwiftDataTransaction(
                date: januaryDate,
                title: "年始出費",
                amount: -4000,
                majorCategory: category,
            ),
        )
        try context.save()

        let store = await makeStore(container: container)
        store.currentYear = 2025
        store.currentMonth = 12
        await store.refresh()

        let summary = store.monthlySummary
        #expect(summary.transactionCount == 1)
        #expect(summary.totalExpense == 8000)
    }

    @Test("表示モード切り替え")
    internal func displayModeSwitch() async throws {
        // Given
        let container = try createInMemoryContainer()
        let context = ModelContext(container)
        let store = await makeStore(container: container)

        // When & Then
        #expect(store.displayMode == .monthly)

        store.displayMode = .annual
        #expect(store.displayMode == .annual)
    }

    @Test("年次集計：対象年の全期間を集計する")
    internal func annualSummary_includesWholeYear() async throws {
        let container = try createInMemoryContainer()
        let context = ModelContext(container)

        let january = try #require(Date.from(year: 2025, month: 1, day: 10))
        let august = try #require(Date.from(year: 2025, month: 8, day: 3))
        context.insert(SwiftDataTransaction(date: january, title: "初売り", amount: -5000))
        context.insert(SwiftDataTransaction(date: august, title: "旅行", amount: -15000))
        context.insert(SwiftDataTransaction(
            date: Date.from(year: 2024, month: 12, day: 25) ?? Date(),
            title: "前年",
            amount: -7000,
        ))
        try context.save()

        let store = await makeStore(container: container)
        store.currentYear = 2025
        store.currentMonth = 8
        await store.refresh()

        let summary = store.annualSummary
        #expect(summary.transactionCount == 2)
        #expect(summary.totalExpense == 20000)
    }

    @Test("月移動：前月")
    internal func moveToPreviousMonth_normalCase() async throws {
        // Given
        let container = try createInMemoryContainer()
        let context = ModelContext(container)
        let store = await makeStore(container: container)
        store.currentYear = 2025
        store.currentMonth = 3

        // When
        store.moveToPreviousMonth()

        // Then
        #expect(store.currentYear == 2025)
        #expect(store.currentMonth == 2)
    }

    @Test("月移動：前月（年跨ぎ）")
    internal func moveToPreviousMonth_normalCase_年跨ぎ() async throws {
        // Given
        let container = try createInMemoryContainer()
        let context = ModelContext(container)
        let store = await makeStore(container: container)
        store.currentYear = 2025
        store.currentMonth = 1

        // When
        store.moveToPreviousMonth()

        // Then
        #expect(store.currentYear == 2024)
        #expect(store.currentMonth == 12)
    }

    @Test("月移動：次月")
    internal func moveToNextMonth_normalCase() async throws {
        // Given
        let container = try createInMemoryContainer()
        let context = ModelContext(container)
        let store = await makeStore(container: container)
        store.currentYear = 2025
        store.currentMonth = 3

        // When
        store.moveToNextMonth()

        // Then
        #expect(store.currentYear == 2025)
        #expect(store.currentMonth == 4)
    }

    @Test("月移動：次月（年跨ぎ）")
    internal func moveToNextMonth_normalCase_年跨ぎ() async throws {
        // Given
        let container = try createInMemoryContainer()
        let context = ModelContext(container)
        let store = await makeStore(container: container)
        store.currentYear = 2025
        store.currentMonth = 12

        // When
        store.moveToNextMonth()

        // Then
        #expect(store.currentYear == 2026)
        #expect(store.currentMonth == 1)
    }

    @Test("年移動：前年")
    internal func moveToPreviousYear() async throws {
        // Given
        let container = try createInMemoryContainer()
        let context = ModelContext(container)
        let store = await makeStore(container: container)
        store.currentYear = 2025

        // When
        store.moveToPreviousYear()

        // Then
        #expect(store.currentYear == 2024)
    }

    @Test("年移動：次年")
    internal func moveToNextYear() async throws {
        // Given
        let container = try createInMemoryContainer()
        let context = ModelContext(container)
        let store = await makeStore(container: container)
        store.currentYear = 2025

        // When
        store.moveToNextYear()

        // Then
        #expect(store.currentYear == 2026)
    }

    @Test("カテゴリ別ハイライト：上位10件")
    internal func categoryHighlights_top10() async throws {
        // Given
        let container = try createInMemoryContainer()
        let context = ModelContext(container)

        // 15カテゴリ作成
        for index in 1 ... 15 {
            let category = SwiftDataCategory(name: "カテゴリ\(index)")
            context.insert(category)

            let transaction = SwiftDataTransaction(
                date: Date.from(year: 2025, month: 11) ?? Date(),
                title: "取引\(index)",
                amount: Decimal(-1000 * index),
                majorCategory: category,
            )
            context.insert(transaction)
        }
        try context.save()

        let store = await makeStore(container: container)
        store.currentYear = 2025
        store.currentMonth = 11
        await store.refresh()
        store.displayMode = .monthly
        await store.refresh()

        // When
        let highlights = store.categoryHighlights

        // Then
        #expect(highlights.count == 10) // 上位10件のみ
    }

    @Test("年次予算進捗：全体予算を集計する")
    internal func annualBudgetProgress_overallBudget() async throws {
        let container = try createInMemoryContainer()
        let context = ModelContext(container)

        let budget = SwiftDataBudget(amount: 120_000, year: 2025, month: 1)
        context.insert(budget)

        let transaction = SwiftDataTransaction(
            date: Date.from(year: 2025, month: 1) ?? Date(),
            title: "光熱費",
            amount: -50000,
        )
        context.insert(transaction)
        try context.save()

        let store = await makeStore(container: container)
        store.currentYear = 2025
        await store.refresh()

        let progress = try #require(store.annualBudgetProgressCalculation)
        #expect(progress.budgetAmount == 120_000)
        #expect(progress.actualAmount == 50000)
    }

    @Test("年次予算進捗：カテゴリ予算のみでも集計される")
    internal func annualBudgetProgress_categoryOnly() async throws {
        let container = try createInMemoryContainer()
        let context = ModelContext(container)

        let food = SwiftDataCategory(name: "食費")
        context.insert(food)

        let budget = SwiftDataBudget(amount: 10000, category: food, year: 2025, month: 1)
        context.insert(budget)

        let transaction = SwiftDataTransaction(
            date: Date.from(year: 2025, month: 1) ?? Date(),
            title: "ランチ",
            amount: -4000,
            majorCategory: food,
        )
        context.insert(transaction)
        try context.save()

        let store = await makeStore(container: container)
        store.currentYear = 2025
        await store.refresh()

        let progress = try #require(store.annualBudgetProgressCalculation)
        #expect(progress.budgetAmount == 10000)
        #expect(progress.actualAmount == 4000)
    }

    @Test("年次予算進捗：予算がなければnil")
    internal func annualBudgetProgress_nilWhenNoBudget() async throws {
        let container = try createInMemoryContainer()
        let context = ModelContext(container)
        let store = await makeStore(container: container)
        #expect(store.annualBudgetProgressCalculation == nil)
    }

    @Test("初期化：年次特別枠設定のある年にフォールバックする")
    internal func initialization_fallsBackToExistingAnnualBudgetYear() async throws {
        let container = try createInMemoryContainer()
        let context = ModelContext(container)

        let fallbackYear = Date().year - 1
        let config = SwiftDataAnnualBudgetConfig(year: fallbackYear, totalAmount: 100_000, policy: .automatic)
        context.insert(config)
        try context.save()

        let store = await makeStore(container: container)
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(store.currentYear == fallbackYear)
    }

    @Test("年次特別枠：設定があれば使用状況を計算する")
    internal func annualBudgetUsage_availableWhenConfigExists() async throws {
        // Given
        let container = try createInMemoryContainer()
        let context = ModelContext(container)
        let category = SwiftDataCategory(name: "特別費", allowsAnnualBudget: true)
        context.insert(category)

        let transaction = SwiftDataTransaction(
            date: Date.from(year: 2025, month: 1) ?? Date(),
            title: "特別支出",
            amount: -40000,
            majorCategory: category,
        )
        context.insert(transaction)

        let budget = SwiftDataBudget(amount: 30000, category: category, year: 2025, month: 1)
        context.insert(budget)

        let config = SwiftDataAnnualBudgetConfig(year: 2025, totalAmount: 200_000, policy: .automatic)
        let allocation = SwiftDataAnnualBudgetAllocation(amount: 100_000, category: category)
        allocation.config = config
        context.insert(config)
        context.insert(allocation)

        try context.save()

        let store = await makeStore(container: container)
        store.currentYear = 2025
        store.currentMonth = 1
        await store.refresh()

        // When
        let usage = try #require(store.annualBudgetUsage)
        let categoryUsage = try #require(usage.categoryAllocations.first)

        // Then
        #expect(categoryUsage.categoryId == category.id)
        #expect(categoryUsage.allocatableAmount == 10000)
        #expect(usage.usedAmount == 10000)
    }

    @Test("年次予算進捗：年次特別枠のfullCoverageカテゴリは全体予算から除外される")
    internal func annualBudgetProgress_excludesFullCoverageCategories() async throws {
        let container = try createInMemoryContainer()
        let context = ModelContext(container)

        // カテゴリ作成
        let foodCategory = SwiftDataCategory(name: "食費", allowsAnnualBudget: false)
        let specialCategory = SwiftDataCategory(name: "特別費", allowsAnnualBudget: true)
        context.insert(foodCategory)
        context.insert(specialCategory)

        // 全体予算
        let overallBudget = SwiftDataBudget(amount: 100_000, category: nil, year: 2025, month: 1)
        context.insert(overallBudget)

        // 取引作成
        let foodTransaction = SwiftDataTransaction(
            date: Date.from(year: 2025, month: 1) ?? Date(),
            title: "食費",
            amount: -20000,
            majorCategory: foodCategory,
        )
        let specialTransaction = SwiftDataTransaction(
            date: Date.from(year: 2025, month: 1) ?? Date(),
            title: "特別支出",
            amount: -30000,
            majorCategory: specialCategory,
        )
        context.insert(foodTransaction)
        context.insert(specialTransaction)

        // 年次特別枠設定（specialCategoryをfullCoverageに設定）
        let config = SwiftDataAnnualBudgetConfig(year: 2025, totalAmount: 200_000, policy: .automatic)
        let allocation = SwiftDataAnnualBudgetAllocation(
            amount: 100_000,
            category: specialCategory,
            policyOverride: .fullCoverage,
        )
        allocation.config = config
        config.allocations.append(allocation)
        context.insert(config)
        context.insert(allocation)

        try context.save()

        let store = await makeStore(container: container)
        store.currentYear = 2025
        await store.refresh()

        // When
        let progress = try #require(store.annualBudgetProgressCalculation)

        // Then: 全体予算の実績は食費のみ（20,000円）で、特別費（30,000円）は除外される
        #expect(progress.budgetAmount == 100_000)
        #expect(progress.actualAmount == 20000, "全体予算の実績が食費のみになっている（特別費は除外）")
    }

    @Test("refreshはバックグラウンドTaskからでも月次集計を更新する")
    internal func refresh_updatesSummaryFromDetachedTask() async throws {
        let container = try createInMemoryContainer()
        let context = ModelContext(container)

        let category = SwiftDataCategory(name: "生活費")
        context.insert(category)
        let targetDate = try #require(Date.from(year: 2025, month: 11, day: 1))
        context.insert(SwiftDataTransaction(
            date: targetDate,
            title: "生活費テスト",
            amount: -2000,
            majorCategory: category,
        ))
        try context.save()

        let store = await makeStore(container: container)
        store.currentYear = 2025
        store.currentMonth = 11

        let backgroundTask = Task.detached {
            await store.refresh()
        }
        await backgroundTask.value

        let summary = store.monthlySummary
        #expect(summary.year == 2025)
        #expect(summary.month == 11)
        #expect(summary.transactionCount == 1)
        #expect(summary.totalExpense == 2000)
    }

    // MARK: - Helper Methods

    private func createInMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: SwiftDataTransaction.self, SwiftDataCategory.self, SwiftDataBudget.self,
            SwiftDataAnnualBudgetConfig.self,
            SwiftDataFinancialInstitution.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true),
        )
    }
}

private extension DashboardStoreTests {
    func makeStore(container: ModelContainer) async -> DashboardStore {
        let repository = SwiftDataDashboardRepository(modelContainer: container)
        return DashboardStore(repository: repository)
    }
}
