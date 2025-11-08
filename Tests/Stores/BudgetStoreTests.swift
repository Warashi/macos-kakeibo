import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite(.serialized)
@MainActor
internal struct BudgetStoreTests {
    @Test("初期化：現在の年月で開始する")
    internal func initialization_setsCurrentDate() throws {
        let container = try createInMemoryContainer()
        let context = ModelContext(container)

        let store = BudgetStore(modelContext: context)
        let now = Date()

        #expect(store.currentYear == now.year)
        #expect(store.currentMonth == now.month)
    }

    @Test("予算追加：全体予算を作成できる")
    internal func addBudget_createsOverallBudget() throws {
        let (store, _) = try makeStore()

        try store.addBudget(
            amount: 50000,
            categoryId: nil,
            startYear: store.currentYear,
            startMonth: store.currentMonth,
            endYear: store.currentYear,
            endMonth: store.currentMonth,
        )

        #expect(store.monthlyBudgets.count == 1)
        #expect(store.overallBudgetEntry?.calculation.budgetAmount == 50000)
        #expect(store.overallBudgetEntry?.calculation.actualAmount == 0)
    }

    @Test("予算追加：カテゴリ別予算を集計できる")
    internal func categoryBudgetEntries_calculatesActuals() throws {
        let (store, context) = try makeStore()
        let food = Category(name: "食費", allowsAnnualBudget: true, displayOrder: 1)
        context.insert(food)

        let transaction = Transaction(
            date: Date.from(year: store.currentYear, month: store.currentMonth) ?? Date(),
            title: "ランチ",
            amount: -2000,
            majorCategory: food,
        )

        context.insert(transaction)
        try context.save()

        try store.addBudget(
            amount: 5000,
            categoryId: food.id,
            startYear: store.currentYear,
            startMonth: store.currentMonth,
            endYear: store.currentYear,
            endMonth: store.currentMonth,
        )

        let entries = store.categoryBudgetEntries
        #expect(entries.count == 1)
        let entry = try #require(entries.first)
        #expect(entry.calculation.actualAmount == 2000)
        #expect(entry.calculation.remainingAmount == 3000)
        #expect(entry.calculation.isOverBudget == false)
    }

    @Test("期間予算は複数月で参照できる")
    internal func periodBudget_appliesAcrossMonths() throws {
        let (store, _) = try makeStore()

        try store.addBudget(
            amount: 4000,
            categoryId: nil,
            startYear: store.currentYear,
            startMonth: store.currentMonth,
            endYear: store.currentYear + 1,
            endMonth: 1,
        )

        #expect(store.monthlyBudgets.count == 1)
        store.moveToNextMonth()
        #expect(store.monthlyBudgets.count == 1)
        store.moveToNextMonth()
        #expect(store.monthlyBudgets.count == 1)
    }

    @Test("期間が不正な場合はエラーになる")
    internal func addBudget_invalidPeriodThrows() throws {
        let (store, _) = try makeStore()

        #expect(
            throws: BudgetStoreError.invalidPeriod,
        ) {
            try store.addBudget(
                amount: 1000,
                categoryId: nil,
                startYear: store.currentYear,
                startMonth: store.currentMonth,
                endYear: store.currentYear,
                endMonth: store.currentMonth - 1,
            )
        }
    }

    @Test("年次予算：全体とカテゴリ別の集計を算出する")
    internal func annualBudgetEntries_calculatesYearlyTotals() throws {
        let (store, context) = try makeStore()
        let food = Category(name: "食費", displayOrder: 1)
        let transport = Category(name: "交通", displayOrder: 2)
        context.insert(food)
        context.insert(transport)

        let year = store.currentYear

        let budgets: [Budget] = [
            Budget(amount: 100_000, year: year, month: 1),
            Budget(amount: 120_000, year: year, month: 2),
            Budget(amount: 50000, category: food, year: year, month: 1),
            Budget(amount: 60000, category: food, year: year, month: 2),
            Budget(amount: 40000, category: transport, year: year, month: 1),
        ]
        budgets.forEach(context.insert)

        let transactions: [Transaction] = [
            Transaction(
                date: makeDate(year: year, month: 1, day: 10),
                title: "食費1",
                amount: -20000,
                majorCategory: food,
            ),
            Transaction(
                date: makeDate(year: year, month: 2, day: 5),
                title: "食費2",
                amount: -30000,
                majorCategory: food,
            ),
            Transaction(
                date: makeDate(year: year, month: 1, day: 15),
                title: "交通費",
                amount: -10000,
                majorCategory: transport,
            ),
        ]
        transactions.forEach(context.insert)
        try context.save()

        let overallEntry = try #require(store.annualOverallBudgetEntry)
        #expect(overallEntry.calculation.budgetAmount == 220_000)
        #expect(overallEntry.calculation.actualAmount == 60000)
        #expect(overallEntry.isOverallBudget)

        let categoryEntries = store.annualCategoryBudgetEntries
        #expect(categoryEntries.count == 2)

        let foodEntry = try #require(categoryEntries.first { $0.title.contains("食費") })
        #expect(foodEntry.calculation.budgetAmount == 110_000)
        #expect(foodEntry.calculation.actualAmount == 50000)

        let transportEntry = try #require(categoryEntries.first { $0.title.contains("交通") })
        #expect(transportEntry.calculation.budgetAmount == 40000)
        #expect(transportEntry.calculation.actualAmount == 10000)
    }

    @Test("予算更新：金額とカテゴリを変更できる")
    internal func updateBudget_changesValues() throws {
        let (store, context) = try makeStore()
        let food = Category(name: "食費", displayOrder: 1)
        let transport = Category(name: "交通", displayOrder: 2)
        context.insert(food)
        context.insert(transport)

        let budget = Budget(
            amount: 10000,
            category: food,
            year: store.currentYear,
            month: store.currentMonth,
        )
        context.insert(budget)
        try context.save()

        try store.updateBudget(
            budget: budget,
            amount: 12000,
            categoryId: transport.id,
            startYear: store.currentYear,
            startMonth: store.currentMonth,
            endYear: store.currentYear,
            endMonth: store.currentMonth + 1,
        )

        #expect(budget.amount == 12000)
        #expect(budget.category?.id == transport.id)
        #expect(budget.endMonth == store.currentMonth + 1)
    }

    @Test("予算削除：削除後にリストから除外される")
    internal func deleteBudget_removesBudget() throws {
        let (store, context) = try makeStore()
        let budget = Budget(
            amount: 8000,
            year: store.currentYear,
            month: store.currentMonth,
        )
        context.insert(budget)
        try context.save()

        try store.deleteBudget(budget)

        #expect(store.monthlyBudgets.isEmpty)
    }

    @Test("年次特別枠：登録と更新")
    internal func upsertAnnualBudgetConfig_createsAndUpdates() throws {
        let (store, context) = try makeStore()
        let food = Category(name: "食費")
        let travel = Category(name: "旅行")
        context.insert(food)
        context.insert(travel)
        try context.save()

        #expect(store.annualBudgetConfig == nil)

        try store.upsertAnnualBudgetConfig(
            totalAmount: 300_000,
            policy: .manual,
            allocations: [
                AnnualAllocationDraft(categoryId: food.id, amount: 200_000),
                AnnualAllocationDraft(categoryId: travel.id, amount: 100_000),
            ],
        )

        let createdConfig = try #require(store.annualBudgetConfig)
        #expect(createdConfig.totalAmount == 300_000)
        #expect(createdConfig.policy == .manual)
        #expect(createdConfig.allocations.count == 2)

        let allocationMap = Dictionary(uniqueKeysWithValues: createdConfig.allocations
            .map { ($0.category.id, $0.amount) })
        #expect(allocationMap[food.id] == 200_000)
        #expect(allocationMap[travel.id] == 100_000)

        try store.upsertAnnualBudgetConfig(
            totalAmount: 500_000,
            policy: .disabled,
            allocations: [
                AnnualAllocationDraft(categoryId: travel.id, amount: 300_000),
            ],
        )

        let updatedConfig = try #require(store.annualBudgetConfig)
        #expect(updatedConfig.totalAmount == 500_000)
        #expect(updatedConfig.policy == .disabled)
        #expect(updatedConfig.allocations.count == 1)
        #expect(updatedConfig.allocations.first?.category.id == travel.id)
        #expect(updatedConfig.allocations.first?.amount == 300_000)
    }

    @Test("年次特別枠：カテゴリ重複はエラー")
    internal func upsertAnnualBudgetConfig_duplicateCategories() throws {
        let (store, context) = try makeStore()
        let food = Category(name: "食費")
        context.insert(food)
        try context.save()

        #expect(
            throws: BudgetStoreError.duplicateAnnualAllocationCategory,
        ) {
            try store.upsertAnnualBudgetConfig(
                totalAmount: 100_000,
                policy: .automatic,
                allocations: [
                    AnnualAllocationDraft(categoryId: food.id, amount: 60000),
                    AnnualAllocationDraft(categoryId: food.id, amount: 40000),
                ],
            )
        }
    }

    // MARK: - Helpers

    private func makeStore() throws -> (BudgetStore, ModelContext) {
        let container = try createInMemoryContainer()
        let context = ModelContext(container)
        let store = BudgetStore(modelContext: context)
        store.currentYear = 2025
        store.currentMonth = 11
        return (store, context)
    }

    private func createInMemoryContainer() throws -> ModelContainer {
        try ModelContainer.createInMemoryContainer()
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        Date.from(year: year, month: month, day: day) ?? Date()
    }

    // MARK: - Special Payment Savings Tests

    @Test("特別支払い積立：月次積立金額の合計を取得")
    internal func specialPaymentSavings_monthlyTotal() throws {
        let (store, context) = try setupStore()

        let category = Category(name: "保険・税金")
        let definition1 = SpecialPaymentDefinition(
            name: "自動車税",
            amount: 45000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: makeDate(year: 2026, month: 5, day: 1),
            category: category,
            savingStrategy: .evenlyDistributed,
        )
        let definition2 = SpecialPaymentDefinition(
            name: "車検",
            amount: 120_000,
            recurrenceIntervalMonths: 24,
            firstOccurrenceDate: makeDate(year: 2027, month: 3, day: 1),
            category: category,
            savingStrategy: .customMonthly,
            customMonthlySavingAmount: 6000,
        )

        context.insert(category)
        context.insert(definition1)
        context.insert(definition2)
        try context.save()

        // When
        let total = store.monthlySpecialPaymentSavingsTotal

        // Then
        #expect(total == 9750) // 3750 + 6000
    }

    @Test("特別支払い積立：カテゴリ別積立金額を取得")
    internal func specialPaymentSavings_byCategory() throws {
        let (store, context) = try setupStore()

        let categoryTax = Category(name: "保険・税金")
        let categoryEducation = Category(name: "教育費")

        let definition1 = SpecialPaymentDefinition(
            name: "自動車税",
            amount: 45000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: makeDate(year: 2026, month: 5, day: 1),
            category: categoryTax,
            savingStrategy: .evenlyDistributed,
        )
        let definition2 = SpecialPaymentDefinition(
            name: "学資保険",
            amount: 120_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: makeDate(year: 2026, month: 3, day: 1),
            category: categoryEducation,
            savingStrategy: .evenlyDistributed,
        )

        context.insert(categoryTax)
        context.insert(categoryEducation)
        context.insert(definition1)
        context.insert(definition2)
        try context.save()

        // When
        let allocations = store.categorySpecialPaymentSavings

        // Then
        #expect(allocations.count == 2)
        #expect(allocations[categoryTax.id] == 3750)
        #expect(allocations[categoryEducation.id] == 10000)
    }

    @Test("特別支払い積立：積立状況一覧を取得")
    internal func specialPaymentSavings_entries() throws {
        let (store, context) = try setupStore()

        let balanceService = SpecialPaymentBalanceService()

        let definition = SpecialPaymentDefinition(
            name: "車検",
            amount: 120_000,
            recurrenceIntervalMonths: 24,
            firstOccurrenceDate: makeDate(year: 2027, month: 3, day: 1),
            savingStrategy: .evenlyDistributed,
        )
        context.insert(definition)

        // 12ヶ月分の積立を記録
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
        try context.save()

        // When
        let entries = store.specialPaymentSavingsEntries

        // Then
        #expect(entries.count == 1)
        let entry = try #require(entries.first)
        #expect(entry.name == "車検")
        #expect(entry.monthlySaving == 5000)
        #expect(entry.balance == 60000) // 5000 × 12
        #expect(!entry.hasAlert)
        #expect(entry.progress > 0)
        #expect(entry.progress <= 1.0)
    }

    @Test("特別支払い積立：残高不足の場合アラートフラグが立つ")
    internal func specialPaymentSavings_alertFlag() throws {
        let (store, context) = try setupStore()

        let definition = SpecialPaymentDefinition(
            name: "車検",
            amount: 120_000,
            recurrenceIntervalMonths: 24,
            firstOccurrenceDate: makeDate(year: 2027, month: 3, day: 1),
            savingStrategy: .evenlyDistributed,
        )

        let balance = SpecialPaymentSavingBalance(
            definition: definition,
            totalSavedAmount: 100_000,
            totalPaidAmount: 120_000, // 超過払い
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
        )

        context.insert(definition)
        context.insert(balance)
        try context.save()

        // When
        let entries = store.specialPaymentSavingsEntries

        // Then
        let entry = try #require(entries.first)
        #expect(entry.hasAlert) // 残高がマイナスなのでアラート
        #expect(entry.balance == -20000)
    }
}
