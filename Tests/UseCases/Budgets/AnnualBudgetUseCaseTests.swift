import Foundation
@testable import Kakeibo
import Testing

@Suite
internal struct AnnualBudgetUseCaseTests {
    @Test("年次全体エントリを計算する")
    internal func calculatesAnnualOverallEntry() {
        let year = 2025
        let budgets = [
            DomainFixtures.budget(amount: 100_000, startYear: year, startMonth: 1),
            DomainFixtures.budget(amount: 120_000, startYear: year, startMonth: 2),
        ]
        let transactions = [
            DomainFixtures.transaction(
                date: Date.from(year: year, month: 1, day: 10) ?? Date(),
                title: "家賃",
                amount: -80000,
            ),
        ]
        let snapshot = BudgetSnapshot(
            budgets: budgets,
            transactions: transactions,
            categories: [],
            annualBudgetConfig: nil,
            recurringPaymentDefinitions: [],
            recurringPaymentBalances: [],
            recurringPaymentOccurrences: [],
            savingsGoals: [],
            savingsGoalBalances: [],
        )
        let useCase = DefaultAnnualBudgetUseCase()

        let entry = useCase.annualOverallEntry(snapshot: snapshot, year: year, month: nil)

        #expect(entry?.calculation.budgetAmount == 220_000)
        #expect(entry?.calculation.actualAmount == 80000)
    }

    @Test("年次全体エントリを月指定で計算する")
    internal func calculatesAnnualOverallEntryWithMonth() {
        let year = 2025
        let budgets = [
            DomainFixtures.budget(amount: 100_000, startYear: year, startMonth: 1),
        ]
        let transactions = [
            DomainFixtures.transaction(
                date: Date.from(year: year, month: 1, day: 10) ?? Date(),
                title: "1月の支出",
                amount: -30000,
            ),
            DomainFixtures.transaction(
                date: Date.from(year: year, month: 2, day: 10) ?? Date(),
                title: "2月の支出",
                amount: -40000,
            ),
            DomainFixtures.transaction(
                date: Date.from(year: year, month: 3, day: 10) ?? Date(),
                title: "3月の支出",
                amount: -50000,
            ),
        ]
        let snapshot = BudgetSnapshot(
            budgets: budgets,
            transactions: transactions,
            categories: [],
            annualBudgetConfig: nil,
            recurringPaymentDefinitions: [],
            recurringPaymentBalances: [],
            recurringPaymentOccurrences: [],
            savingsGoals: [],
            savingsGoalBalances: [],
        )
        let useCase = DefaultAnnualBudgetUseCase()

        let entry = useCase.annualOverallEntry(snapshot: snapshot, year: year, month: 2)

        #expect(entry?.calculation.budgetAmount == 100_000)
        #expect(entry?.calculation.actualAmount == 70000) // 1月と2月の合計のみ
    }

    @Test("年次カテゴリ別エントリを算出する")
    internal func calculatesCategoryEntries() throws {
        let year = 2025
        let food = DomainFixtures.category(name: "食費", displayOrder: 1)
        let budgets = [
            DomainFixtures.budget(amount: 50000, category: food, startYear: year, startMonth: 1),
            DomainFixtures.budget(amount: 60000, category: food, startYear: year, startMonth: 2),
        ]
        let transactions = [
            DomainFixtures.transaction(
                date: Date.from(year: year, month: 1, day: 5) ?? Date(),
                title: "スーパー",
                amount: -20000,
                majorCategory: food,
            ),
        ]
        let snapshot = BudgetSnapshot(
            budgets: budgets,
            transactions: transactions,
            categories: [food],
            annualBudgetConfig: nil,
            recurringPaymentDefinitions: [],
            recurringPaymentBalances: [],
            recurringPaymentOccurrences: [],
            savingsGoals: [],
            savingsGoalBalances: [],
        )
        let useCase = DefaultAnnualBudgetUseCase()

        let entries = useCase.annualCategoryEntries(snapshot: snapshot, year: year, month: nil)

        let entry = try #require(entries.first)
        #expect(entry.calculation.budgetAmount == 110_000)
        #expect(entry.calculation.actualAmount == 20000)
    }

    @Test("年次カテゴリ別エントリを月指定で算出する")
    internal func calculatesCategoryEntriesWithMonth() throws {
        let year = 2025
        let food = DomainFixtures.category(name: "食費", displayOrder: 1)
        let budgets = [
            DomainFixtures.budget(amount: 50000, category: food, startYear: year, startMonth: 1),
        ]
        let transactions = [
            DomainFixtures.transaction(
                date: Date.from(year: year, month: 1, day: 5) ?? Date(),
                title: "1月の食費",
                amount: -15000,
                majorCategory: food,
            ),
            DomainFixtures.transaction(
                date: Date.from(year: year, month: 2, day: 5) ?? Date(),
                title: "2月の食費",
                amount: -25000,
                majorCategory: food,
            ),
            DomainFixtures.transaction(
                date: Date.from(year: year, month: 3, day: 5) ?? Date(),
                title: "3月の食費",
                amount: -35000,
                majorCategory: food,
            ),
        ]
        let snapshot = BudgetSnapshot(
            budgets: budgets,
            transactions: transactions,
            categories: [food],
            annualBudgetConfig: nil,
            recurringPaymentDefinitions: [],
            recurringPaymentBalances: [],
            recurringPaymentOccurrences: [],
            savingsGoals: [],
            savingsGoalBalances: [],
        )
        let useCase = DefaultAnnualBudgetUseCase()

        let entries = useCase.annualCategoryEntries(snapshot: snapshot, year: year, month: 2)

        let entry = try #require(entries.first)
        #expect(entry.calculation.budgetAmount == 50000)
        #expect(entry.calculation.actualAmount == 40000) // 1月と2月の合計のみ
    }

    @Test("年次特別枠の使用状況を算出する")
    internal func calculatesAnnualUsage() {
        let year = 2025
        let food = DomainFixtures.category(name: "食費", displayOrder: 1)
        let allocation = DomainFixtures.annualBudgetAllocation(
            amount: 200_000,
            category: food,
            policyOverride: .automatic,
        )
        let config = DomainFixtures.annualBudgetConfig(
            year: year,
            totalAmount: 200_000,
            policy: .automatic,
            allocations: [allocation],
        )
        let transactions = [
            DomainFixtures.transaction(
                date: Date.from(year: year, month: 1, day: 1) ?? Date(),
                title: "家電",
                amount: -50000,
                majorCategory: food,
            ),
        ]
        let snapshot = BudgetSnapshot(
            budgets: [],
            transactions: transactions,
            categories: [food],
            annualBudgetConfig: config,
            recurringPaymentDefinitions: [],
            recurringPaymentBalances: [],
            recurringPaymentOccurrences: [],
            savingsGoals: [],
            savingsGoalBalances: [],
        )
        let useCase = DefaultAnnualBudgetUseCase()

        let usage = useCase.annualBudgetUsage(snapshot: snapshot, year: year, month: 6)

        #expect(usage?.usedAmount == 50000)
        #expect(usage?.remainingAmount == 150_000)
    }
}
