import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite(.serialized)
@MainActor
internal struct DashboardStoreTests {
    @Test("初期化：現在の年月が設定される")
    internal func initialization_setsCurrentYearMonth() throws {
        // Given
        let container = try createInMemoryContainer()
        let context = ModelContext(container)

        // When
        let store = DashboardStore(modelContext: context)

        // Then
        let now = Date()
        #expect(store.currentYear == now.year)
        #expect(store.currentMonth == now.month)
        #expect(store.displayMode == .monthly)
    }

    @Test("月次集計：データがある場合")
    internal func monthlySummary_withData() throws {
        // Given
        let container = try createInMemoryContainer()
        let context = ModelContext(container)
        let category = Category(name: "食費")
        context.insert(category)

        let transaction = Transaction(
            date: Date.from(year: 2025, month: 11) ?? Date(),
            title: "スーパー",
            amount: -5000,
            majorCategory: category,
        )
        context.insert(transaction)
        try context.save()

        let store = DashboardStore(modelContext: context)
        store.currentYear = 2025
        store.currentMonth = 11

        // When
        let summary = store.monthlySummary

        // Then
        #expect(summary.year == 2025)
        #expect(summary.month == 11)
        #expect(summary.totalExpense == 5000)
        #expect(summary.transactionCount == 1)
    }

    @Test("表示モード切り替え")
    internal func displayModeSwitch() throws {
        // Given
        let container = try createInMemoryContainer()
        let context = ModelContext(container)
        let store = DashboardStore(modelContext: context)

        // When & Then
        #expect(store.displayMode == .monthly)

        store.displayMode = .annual
        #expect(store.displayMode == .annual)
    }

    @Test("月移動：前月")
    internal func moveToPreviousMonth_normalCase() throws {
        // Given
        let container = try createInMemoryContainer()
        let context = ModelContext(container)
        let store = DashboardStore(modelContext: context)
        store.currentYear = 2025
        store.currentMonth = 3

        // When
        store.moveToPreviousMonth()

        // Then
        #expect(store.currentYear == 2025)
        #expect(store.currentMonth == 2)
    }

    @Test("月移動：前月（年跨ぎ）")
    internal func moveToPreviousMonth_normalCase_年跨ぎ() throws {
        // Given
        let container = try createInMemoryContainer()
        let context = ModelContext(container)
        let store = DashboardStore(modelContext: context)
        store.currentYear = 2025
        store.currentMonth = 1

        // When
        store.moveToPreviousMonth()

        // Then
        #expect(store.currentYear == 2024)
        #expect(store.currentMonth == 12)
    }

    @Test("月移動：次月")
    internal func moveToNextMonth_normalCase() throws {
        // Given
        let container = try createInMemoryContainer()
        let context = ModelContext(container)
        let store = DashboardStore(modelContext: context)
        store.currentYear = 2025
        store.currentMonth = 3

        // When
        store.moveToNextMonth()

        // Then
        #expect(store.currentYear == 2025)
        #expect(store.currentMonth == 4)
    }

    @Test("月移動：次月（年跨ぎ）")
    internal func moveToNextMonth_normalCase_年跨ぎ() throws {
        // Given
        let container = try createInMemoryContainer()
        let context = ModelContext(container)
        let store = DashboardStore(modelContext: context)
        store.currentYear = 2025
        store.currentMonth = 12

        // When
        store.moveToNextMonth()

        // Then
        #expect(store.currentYear == 2026)
        #expect(store.currentMonth == 1)
    }

    @Test("年移動：前年")
    internal func moveToPreviousYear() throws {
        // Given
        let container = try createInMemoryContainer()
        let context = ModelContext(container)
        let store = DashboardStore(modelContext: context)
        store.currentYear = 2025

        // When
        store.moveToPreviousYear()

        // Then
        #expect(store.currentYear == 2024)
    }

    @Test("年移動：次年")
    internal func moveToNextYear() throws {
        // Given
        let container = try createInMemoryContainer()
        let context = ModelContext(container)
        let store = DashboardStore(modelContext: context)
        store.currentYear = 2025

        // When
        store.moveToNextYear()

        // Then
        #expect(store.currentYear == 2026)
    }

    @Test("カテゴリ別ハイライト：上位10件")
    internal func categoryHighlights_top10() throws {
        // Given
        let container = try createInMemoryContainer()
        let context = ModelContext(container)

        // 15カテゴリ作成
        for index in 1 ... 15 {
            let category = Category(name: "カテゴリ\(index)")
            context.insert(category)

            let transaction = Transaction(
                date: Date.from(year: 2025, month: 11) ?? Date(),
                title: "取引\(index)",
                amount: Decimal(-1000 * index),
                majorCategory: category,
            )
            context.insert(transaction)
        }
        try context.save()

        let store = DashboardStore(modelContext: context)
        store.currentYear = 2025
        store.currentMonth = 11
        store.displayMode = .monthly

        // When
        let highlights = store.categoryHighlights

        // Then
        #expect(highlights.count == 10) // 上位10件のみ
    }

    @Test("年次予算進捗：全体予算を集計する")
    internal func annualBudgetProgress_overallBudget() throws {
        let container = try createInMemoryContainer()
        let context = ModelContext(container)

        let budget = Budget(amount: 120_000, year: 2025, month: 1)
        context.insert(budget)

        let transaction = Transaction(
            date: Date.from(year: 2025, month: 1) ?? Date(),
            title: "光熱費",
            amount: -50_000
        )
        context.insert(transaction)
        try context.save()

        let store = DashboardStore(modelContext: context)
        store.currentYear = 2025

        let progress = try #require(store.annualBudgetProgressCalculation)
        #expect(progress.budgetAmount == 120_000)
        #expect(progress.actualAmount == 50_000)
    }

    @Test("年次予算進捗：カテゴリ予算のみでも集計される")
    internal func annualBudgetProgress_categoryOnly() throws {
        let container = try createInMemoryContainer()
        let context = ModelContext(container)

        let food = Category(name: "食費")
        context.insert(food)

        let budget = Budget(amount: 10_000, category: food, year: 2025, month: 1)
        context.insert(budget)

        let transaction = Transaction(
            date: Date.from(year: 2025, month: 1) ?? Date(),
            title: "ランチ",
            amount: -4_000,
            majorCategory: food
        )
        context.insert(transaction)
        try context.save()

        let store = DashboardStore(modelContext: context)
        store.currentYear = 2025

        let progress = try #require(store.annualBudgetProgressCalculation)
        #expect(progress.budgetAmount == 10_000)
        #expect(progress.actualAmount == 4_000)
    }

    @Test("年次予算進捗：予算がなければnil")
    internal func annualBudgetProgress_nilWhenNoBudget() throws {
        let container = try createInMemoryContainer()
        let context = ModelContext(container)
        let store = DashboardStore(modelContext: context)
        #expect(store.annualBudgetProgressCalculation == nil)
    }

    // MARK: - Helper Methods

    private func createInMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Transaction.self, Category.self, Budget.self, AnnualBudgetConfig.self,
            FinancialInstitution.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true),
        )
    }
}
