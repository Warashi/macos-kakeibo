import Foundation

internal protocol MonthlyBudgetUseCaseProtocol {
    func monthlyBudgets(
        snapshot: BudgetSnapshot,
        year: Int,
        month: Int,
    ) -> [BudgetDTO]

    func monthlyCalculation(
        snapshot: BudgetSnapshot,
        year: Int,
        month: Int,
    ) -> MonthlyBudgetCalculation

    func categoryEntries(
        snapshot: BudgetSnapshot,
        year: Int,
        month: Int,
    ) -> [MonthlyBudgetEntry]

    func overallEntry(
        snapshot: BudgetSnapshot,
        year: Int,
        month: Int,
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
        month: Int,
    ) -> [BudgetDTO] {
        snapshot.budgets.filter { $0.contains(year: year, month: month) }
    }

    internal func monthlyCalculation(
        snapshot: BudgetSnapshot,
        year: Int,
        month: Int,
    ) -> MonthlyBudgetCalculation {
        let filter = makeFilter(from: snapshot)
        return calculator.calculateMonthlyBudget(
            input: BudgetCalculator.MonthlyBudgetInput(
                transactions: snapshot.transactions,
                budgets: snapshot.budgets,
                categories: snapshot.categories,
                year: year,
                month: month,
                filter: filter,
                excludedCategoryIds: excludedCategoryIds(from: snapshot),
            ),
        )
    }

    internal func categoryEntries(
        snapshot: BudgetSnapshot,
        year: Int,
        month: Int,
    ) -> [MonthlyBudgetEntry] {
        let calculation = monthlyCalculation(snapshot: snapshot, year: year, month: month)
        let calculationMap: [UUID: BudgetCalculation] = Dictionary(
            uniqueKeysWithValues: calculation.categoryCalculations.map { item in
                (item.categoryId, item.calculation)
            },
        )

        let categoryMap = Dictionary(uniqueKeysWithValues: snapshot.categories.map { ($0.id, $0) })

        return monthlyBudgets(snapshot: snapshot, year: year, month: month)
            .compactMap { budget -> MonthlyBudgetEntry? in
                guard let categoryId = budget.categoryId,
                      let category = categoryMap[categoryId] else { return nil }
                let calc = calculationMap[category.id] ?? calculator.calculate(
                    budgetAmount: budget.amount,
                    actualAmount: 0,
                )

                let fullName = buildFullName(for: category, categories: snapshot.categories)
                let parentOrder: Int = if let parentId = category.parentId,
                                          let parent = categoryMap[parentId] {
                    parent.displayOrder
                } else {
                    category.displayOrder
                }

                return MonthlyBudgetEntry(
                    budget: budget,
                    title: fullName,
                    calculation: calc,
                    categoryDisplayOrder: category.displayOrder,
                    parentCategoryDisplayOrder: parentOrder,
                )
            }
            .sorted { lhs, rhs in
                lhs.displayOrderKey < rhs.displayOrderKey
            }
    }

    internal func overallEntry(
        snapshot: BudgetSnapshot,
        year: Int,
        month: Int,
    ) -> MonthlyBudgetEntry? {
        guard let budget = monthlyBudgets(snapshot: snapshot, year: year, month: month)
            .first(where: { $0.categoryId == nil }) else {
            return nil
        }

        guard let calculation = monthlyCalculation(snapshot: snapshot, year: year, month: month)
            .overallCalculation else {
            return nil
        }

        return MonthlyBudgetEntry(
            budget: budget,
            title: "全体予算",
            calculation: calculation,
            categoryDisplayOrder: 0,
            parentCategoryDisplayOrder: 0,
        )
    }

    private func buildFullName(for category: CategoryDTO, categories: [CategoryDTO]) -> String {
        guard let parentId = category.parentId,
              let parent = categories.first(where: { $0.id == parentId }) else {
            return category.name
        }
        return "\(parent.name) > \(category.name)"
    }
}

private extension DefaultMonthlyBudgetUseCase {
    func excludedCategoryIds(from snapshot: BudgetSnapshot) -> Set<UUID> {
        snapshot.annualBudgetConfig?.fullCoverageCategoryIDs(
            includingChildrenFrom: snapshot.categories,
        ) ?? [] as Set<UUID>
    }

    /// 定期支払いとリンクされた取引を除外するフィルタを作成
    func makeFilter(from snapshot: BudgetSnapshot) -> AggregationFilter {
        let excludedTransactionIds = Set(
            snapshot.recurringPaymentOccurrences
                .compactMap(\.transactionId),
        )
        return AggregationFilter(
            includeOnlyCalculationTarget: true,
            excludeTransfers: true,
            financialInstitutionId: nil,
            categoryId: nil,
            excludedTransactionIds: excludedTransactionIds,
        )
    }
}
