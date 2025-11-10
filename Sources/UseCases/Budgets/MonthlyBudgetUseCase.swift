import Foundation

internal protocol MonthlyBudgetUseCaseProtocol {
    func monthlyBudgets(
        snapshot: BudgetSnapshot,
        year: Int,
        month: Int
    ) -> [Budget]

    func monthlyCalculation(
        snapshot: BudgetSnapshot,
        year: Int,
        month: Int
    ) -> MonthlyBudgetCalculation

    func categoryEntries(
        snapshot: BudgetSnapshot,
        year: Int,
        month: Int
    ) -> [MonthlyBudgetEntry]

    func overallEntry(
        snapshot: BudgetSnapshot,
        year: Int,
        month: Int
    ) -> MonthlyBudgetEntry?
}

internal final class DefaultMonthlyBudgetUseCase: MonthlyBudgetUseCaseProtocol {
    private let calculator: BudgetCalculator

    internal init(calculator: BudgetCalculator = BudgetCalculator()) {
        self.calculator = calculator
    }

    internal func monthlyBudgets(
        snapshot: BudgetSnapshot,
        year: Int,
        month: Int
    ) -> [Budget] {
        snapshot.budgets.filter { $0.contains(year: year, month: month) }
    }

    internal func monthlyCalculation(
        snapshot: BudgetSnapshot,
        year: Int,
        month: Int
    ) -> MonthlyBudgetCalculation {
        calculator.calculateMonthlyBudget(
            transactions: snapshot.transactions,
            budgets: snapshot.budgets,
            year: year,
            month: month,
            filter: .default,
            excludedCategoryIds: excludedCategoryIds(from: snapshot)
        )
    }

    internal func categoryEntries(
        snapshot: BudgetSnapshot,
        year: Int,
        month: Int
    ) -> [MonthlyBudgetEntry] {
        let calculation = monthlyCalculation(snapshot: snapshot, year: year, month: month)
        let calculationMap: [UUID: BudgetCalculation] = Dictionary(
            uniqueKeysWithValues: calculation.categoryCalculations.map { item in
                (item.categoryId, item.calculation)
            }
        )

        return monthlyBudgets(snapshot: snapshot, year: year, month: month)
            .compactMap { budget -> MonthlyBudgetEntry? in
                guard let category = budget.category else { return nil }
                let calc = calculationMap[category.id] ?? calculator.calculate(
                    budgetAmount: budget.amount,
                    actualAmount: 0
                )
                return MonthlyBudgetEntry(
                    budget: budget,
                    title: category.fullName,
                    calculation: calc
                )
            }
            .sorted { lhs, rhs in
                lhs.displayOrderKey < rhs.displayOrderKey
            }
    }

    internal func overallEntry(
        snapshot: BudgetSnapshot,
        year: Int,
        month: Int
    ) -> MonthlyBudgetEntry? {
        guard let budget = monthlyBudgets(snapshot: snapshot, year: year, month: month)
            .first(where: { $0.category == nil }) else {
            return nil
        }

        guard let calculation = monthlyCalculation(snapshot: snapshot, year: year, month: month).overallCalculation else {
            return nil
        }

        return MonthlyBudgetEntry(
            budget: budget,
            title: "全体予算",
            calculation: calculation
        )
    }
}

private extension DefaultMonthlyBudgetUseCase {
    func excludedCategoryIds(from snapshot: BudgetSnapshot) -> Set<UUID> {
        snapshot.annualBudgetConfig?.fullCoverageCategoryIDs(
            includingChildrenFrom: snapshot.categories
        ) ?? [] as Set<UUID>
    }
}
