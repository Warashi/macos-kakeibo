import Foundation

/// 年次予算エントリ
internal struct AnnualBudgetEntry: Identifiable {
    internal enum EntryID: Hashable {
        case overall
        case category(UUID)
    }

    internal let id: EntryID
    internal let budget: Budget
    internal let title: String
    internal let calculation: BudgetCalculation
    internal let isOverallBudget: Bool
    internal let displayOrderTuple: (Int, Int, String)
}

/// 年次予算進捗計算結果
internal struct AnnualBudgetProgressResult {
    internal let overallEntry: AnnualBudgetEntry?
    internal let categoryEntries: [AnnualBudgetEntry]
    internal let aggregateCalculation: BudgetCalculation?
}

/// 年次予算進捗計算機
internal struct AnnualBudgetProgressCalculator {
    private let aggregator: TransactionAggregator
    private let budgetCalculator: BudgetCalculator

    internal init() {
        self.aggregator = TransactionAggregator()
        self.budgetCalculator = BudgetCalculator()
    }

    internal func calculate(
        budgets: [Budget],
        transactions: [Transaction],
        year: Int,
        filter: AggregationFilter = .default
    ) -> AnnualBudgetProgressResult {
        let annualBudgets = budgets.filter { $0.overlaps(year: year) }
        guard !annualBudgets.isEmpty else {
            return AnnualBudgetProgressResult(
                overallEntry: nil,
                categoryEntries: [],
                aggregateCalculation: nil
            )
        }

        let annualSummary = aggregator.aggregateAnnually(
            transactions: transactions,
            year: year,
            filter: filter
        )

        let actualMap: [UUID: Decimal] = Dictionary(
            uniqueKeysWithValues: annualSummary.categorySummaries.compactMap { summary in
                guard let categoryId = summary.categoryId else { return nil }
                return (categoryId, summary.totalExpense)
            }
        )

        let overallEntry = makeOverallEntry(
            year: year,
            budgets: annualBudgets,
            totalExpense: annualSummary.totalExpense
        )

        let categoryEntries = makeCategoryEntries(
            year: year,
            budgets: annualBudgets,
            actualMap: actualMap
        )

        let aggregateCalculation: BudgetCalculation?
        if let overallEntry {
            aggregateCalculation = overallEntry.calculation
        } else if !categoryEntries.isEmpty {
            let totalBudget = categoryEntries.reduce(Decimal.zero) { $0 + $1.calculation.budgetAmount }
            let totalActual = categoryEntries.reduce(Decimal.zero) { $0 + $1.calculation.actualAmount }
            aggregateCalculation = budgetCalculator.calculate(
                budgetAmount: totalBudget,
                actualAmount: totalActual
            )
        } else {
            aggregateCalculation = nil
        }

        return AnnualBudgetProgressResult(
            overallEntry: overallEntry,
            categoryEntries: categoryEntries,
            aggregateCalculation: aggregateCalculation
        )
    }

    // MARK: - Helpers

    private func makeOverallEntry(
        year: Int,
        budgets: [Budget],
        totalExpense: Decimal
    ) -> AnnualBudgetEntry? {
        let items = budgets.filter { $0.category == nil }
        guard let budget = items.first else { return nil }

        let totalAmount = items.reduce(Decimal.zero) { partial, budget in
            partial + budget.annualBudgetAmount(for: year)
        }

        let calculation = budgetCalculator.calculate(
            budgetAmount: totalAmount,
            actualAmount: totalExpense
        )

        return AnnualBudgetEntry(
            id: .overall,
            budget: budget,
            title: "全体予算",
            calculation: calculation,
            isOverallBudget: true,
            displayOrderTuple: (-1, -1, "全体予算")
        )
    }

    private func makeCategoryEntries(
        year: Int,
        budgets: [Budget],
        actualMap: [UUID: Decimal]
    ) -> [AnnualBudgetEntry] {
        let categoryBudgets = budgets.compactMap { budget -> (Category, Budget)? in
            guard let category = budget.category else { return nil }
            return (category, budget)
        }

        let groupedBudgets = Dictionary(grouping: categoryBudgets) { $0.0.id }

        return groupedBudgets.compactMap { categoryId, pairedItems -> AnnualBudgetEntry? in
            guard let category = pairedItems.first?.0 else { return nil }

            let totalAmount = pairedItems.reduce(Decimal.zero) { $0 + $1.1.annualBudgetAmount(for: year) }
            let actualAmount = actualMap[categoryId] ?? 0
            let calculation = budgetCalculator.calculate(
                budgetAmount: totalAmount,
                actualAmount: actualAmount
            )

            guard let budget = pairedItems.first?.1 else { return nil }

            return AnnualBudgetEntry(
                id: .category(categoryId),
                budget: budget,
                title: category.fullName,
                calculation: calculation,
                isOverallBudget: false,
                displayOrderTuple: displayOrderTuple(for: category)
            )
        }
        .sorted { lhs, rhs in
            lhs.displayOrderTuple < rhs.displayOrderTuple
        }
    }

    private func displayOrderTuple(for category: Category) -> (Int, Int, String) {
        let parentOrder = category.parent?.displayOrder ?? category.displayOrder
        let ownOrder = category.displayOrder
        return (parentOrder, ownOrder, category.fullName)
    }
}
