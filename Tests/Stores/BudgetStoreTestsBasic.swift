import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite(.serialized)
@MainActor
internal struct BudgetStoreTestsBasic {
    @Test("初期化：現在の年月で開始する")
    internal func initialization_setsCurrentDate() async throws {
        let container = try createInMemoryContainer()
        let context = ModelContext(container)

        let store = try await makeBudgetStore(container: container, context: context)
        let now = Date()

        #expect(store.currentYear == now.year)
        #expect(store.currentMonth == now.month)
    }

    @Test("予算追加：全体予算を作成できる")
    internal func addBudget_createsOverallBudget() async throws {
        let (store, _) = try await makeStore()

        let input = BudgetInput(
            amount: 50000,
            categoryId: nil,
            startYear: store.currentYear,
            startMonth: store.currentMonth,
            endYear: store.currentYear,
            endMonth: store.currentMonth,
        )
        try await store.addBudget(input)

        #expect(store.monthlyBudgets.count == 1)
        #expect(store.overallBudgetEntry?.calculation.budgetAmount == 50000)
        #expect(store.overallBudgetEntry?.calculation.actualAmount == 0)
    }

    @Test("期間予算は複数月で参照できる")
    internal func periodBudget_appliesAcrossMonths() async throws {
        let (store, _) = try await makeStore()

        let input = BudgetInput(
            amount: 4000,
            categoryId: nil,
            startYear: store.currentYear,
            startMonth: store.currentMonth,
            endYear: store.currentYear + 1,
            endMonth: 1,
        )
        try await store.addBudget(input)

        #expect(store.monthlyBudgets.count == 1)
        await store.moveToNextMonth()
        #expect(store.monthlyBudgets.count == 1)
        await store.moveToNextMonth()
        #expect(store.monthlyBudgets.count == 1)
    }

    @Test("期間が不正な場合はエラーになる")
    internal func addBudget_invalidPeriodThrows() async throws {
        let (store, _) = try await makeStore()

        await #expect(
            throws: BudgetStoreError.invalidPeriod,
        ) {
            let input = BudgetInput(
                amount: 1000,
                categoryId: nil,
                startYear: store.currentYear,
                startMonth: store.currentMonth,
                endYear: store.currentYear,
                endMonth: store.currentMonth - 1,
            )
            try await store.addBudget(input)
        }
    }

    @Test("予算更新：金額とカテゴリを変更できる")
    internal func updateBudget_changesValues() async throws {
        let (store, context) = try await makeStore()
        let food = CategoryEntity(name: "食費", displayOrder: 1)
        let transport = CategoryEntity(name: "交通", displayOrder: 2)
        context.insert(food)
        context.insert(transport)

        let budget = BudgetEntity(
            amount: 10000,
            category: food,
            year: store.currentYear,
            month: store.currentMonth,
        )
        context.insert(budget)
        try context.save()

        let budgetDTO = Budget(from: budget)

        let input = BudgetInput(
            amount: 12000,
            categoryId: transport.id,
            startYear: store.currentYear,
            startMonth: store.currentMonth,
            endYear: store.currentYear,
            endMonth: store.currentMonth + 1,
        )
        try await store.updateBudget(budget: budgetDTO, input: input)

        #expect(budget.amount == 12000)
        #expect(budget.category?.id == transport.id)
        #expect(budget.endMonth == store.currentMonth + 1)
    }

    @Test("予算削除：削除後にリストから除外される")
    internal func deleteBudget_removesBudget() async throws {
        let (store, context) = try await makeStore()
        let budget = BudgetEntity(
            amount: 8000,
            year: store.currentYear,
            month: store.currentMonth,
        )
        context.insert(budget)
        try context.save()

        let budgetDTO = Budget(from: budget)
        try await store.deleteBudget(budgetDTO)

        #expect(store.monthlyBudgets.isEmpty)
    }

    @Test("CRUD後にリフレッシュトークンが更新される")
    internal func refreshToken_updatesAfterMutations() async throws {
        let (store, _) = try await makeStore()
        let initialToken = store.refreshToken

        let input = BudgetInput(
            amount: 6000,
            categoryId: nil,
            startYear: store.currentYear,
            startMonth: store.currentMonth,
            endYear: store.currentYear,
            endMonth: store.currentMonth,
        )

        try await store.addBudget(input)

        #expect(store.refreshToken != initialToken)
    }

    @Test("displayModeTraitsはモードに応じてナビゲーション情報を返す")
    internal func displayModeTraits_reflectModes() async throws {
        let (store, _) = try await makeStore()

        #expect(store.displayModeTraits.navigationStyle == .monthly)
        #expect(store.displayModeTraits.presentButtonLabel == "今月")

        store.displayMode = .annual
        #expect(store.displayModeTraits.navigationStyle == .annual)
        #expect(store.displayModeTraits.presentButtonLabel == "今年")

        store.displayMode = .recurringPaymentsList
        #expect(store.displayModeTraits.showsNavigation == false)
        #expect(store.displayModeTraits.presentButtonLabel == nil)
    }

    @Test("moveToPresent: 月次モードでは現在の年月に戻す")
    internal func moveToPresent_resetsMonthAndYear() async throws {
        let (store, _) = try await makeStore()
        store.displayMode = .monthly
        store.currentYear = 2000
        store.currentMonth = 1

        let expectedYear = Date().year
        let expectedMonth = Date().month

        await store.moveToPresent()

        #expect(store.currentYear == expectedYear)
        #expect(store.currentMonth == expectedMonth)
    }

    @Test("moveToPresent: 年次モードでは年のみ更新")
    internal func moveToPresent_updatesOnlyYearForAnnual() async throws {
        let (store, _) = try await makeStore()
        store.displayMode = .annual
        store.currentYear = 2000
        store.currentMonth = 6

        let expectedYear = Date().year
        await store.moveToPresent()

        #expect(store.currentYear == expectedYear)
        #expect(store.currentMonth == 6)
    }

    @Test("moveToPresent: 定期支払い一覧では変化しない")
    internal func moveToPresent_doesNothingForRecurringPayments() async throws {
        let (store, _) = try await makeStore()
        store.displayMode = .recurringPaymentsList
        store.currentYear = 2000
        store.currentMonth = 6

        await store.moveToPresent()

        #expect(store.currentYear == 2000)
        #expect(store.currentMonth == 6)
    }

    // MARK: - Helpers

    @MainActor
    private func makeStore() async throws -> (BudgetStore, ModelContext) {
        let container = try createInMemoryContainer()
        let context = ModelContext(container)
        let store = try await makeBudgetStore(container: container, context: context)
        store.currentYear = 2025
        store.currentMonth = 11
        return (store, context)
    }

    @DatabaseActor
    private func makeBudgetStore(container: ModelContainer, context: ModelContext) async throws -> BudgetStore {
        let repository = SwiftDataBudgetRepository(modelContext: context, modelContainer: container)
        let calculator = BudgetCalculator()
        let monthlyUseCase = DefaultMonthlyBudgetUseCase(calculator: calculator)
        let annualUseCase = DefaultAnnualBudgetUseCase()
        let recurringPaymentUseCase = DefaultRecurringPaymentSavingsUseCase(calculator: calculator)
        let mutationUseCase = DefaultBudgetMutationUseCase(repository: repository)

        return await BudgetStore(
            repository: repository,
            monthlyUseCase: monthlyUseCase,
            annualUseCase: annualUseCase,
            recurringPaymentUseCase: recurringPaymentUseCase,
            mutationUseCase: mutationUseCase,
        )
    }

    private func createInMemoryContainer() throws -> ModelContainer {
        try ModelContainer.createInMemoryContainer()
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        Date.from(year: year, month: month, day: day) ?? Date()
    }
}
