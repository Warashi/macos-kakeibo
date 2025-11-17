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
        )
        let useCase = DefaultAnnualBudgetUseCase()

        let entry = useCase.annualOverallEntry(snapshot: snapshot, year: year)

        #expect(entry?.calculation.budgetAmount == 220_000)
        #expect(entry?.calculation.actualAmount == 80000)
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
        )
        let useCase = DefaultAnnualBudgetUseCase()

        let entries = useCase.annualCategoryEntries(snapshot: snapshot, year: year)

        let entry = try #require(entries.first)
        #expect(entry.calculation.budgetAmount == 110_000)
        #expect(entry.calculation.actualAmount == 20000)
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
        )
        let useCase = DefaultAnnualBudgetUseCase()

        let usage = useCase.annualBudgetUsage(snapshot: snapshot, year: year, month: 6)

        #expect(usage?.usedAmount == 50000)
        #expect(usage?.remainingAmount == 150_000)
    }
}
