import Foundation

/// 表示順序を表す構造体
internal struct DisplayOrder: Comparable {
    internal let parentOrder: Int
    internal let ownOrder: Int
    internal let name: String

    internal static func < (lhs: DisplayOrder, rhs: DisplayOrder) -> Bool {
        if lhs.parentOrder != rhs.parentOrder {
            return lhs.parentOrder < rhs.parentOrder
        }
        if lhs.ownOrder != rhs.ownOrder {
            return lhs.ownOrder < rhs.ownOrder
        }
        return lhs.name < rhs.name
    }
}

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
    internal let displayOrder: DisplayOrder
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
        filter: AggregationFilter = .default,
    ) -> AnnualBudgetProgressResult {
        let annualBudgets = budgets.filter { $0.overlaps(year: year) }
        guard !annualBudgets.isEmpty else {
            return AnnualBudgetProgressResult(
                overallEntry: nil,
                categoryEntries: [],
                aggregateCalculation: nil,
            )
        }

        let annualSummary = aggregator.aggregateAnnually(
            transactions: transactions,
            year: year,
            filter: filter,
        )

        let actualMap: [UUID: Decimal] = Dictionary(
            uniqueKeysWithValues: annualSummary.categorySummaries.compactMap { summary in
                guard let categoryId = summary.categoryId else { return nil }
                return (categoryId, summary.totalExpense)
            },
        )

        let overallEntry = makeOverallEntry(
            year: year,
            budgets: annualBudgets,
            totalExpense: annualSummary.totalExpense,
        )

        let categoryEntries = makeCategoryEntries(
            year: year,
            budgets: annualBudgets,
            actualMap: actualMap,
        )

        let aggregateCalculation: BudgetCalculation?
        if let overallEntry {
            aggregateCalculation = overallEntry.calculation
        } else if !categoryEntries.isEmpty {
            let totalBudget = categoryEntries.reduce(Decimal.zero) { $0 + $1.calculation.budgetAmount }
            let totalActual = categoryEntries.reduce(Decimal.zero) { $0 + $1.calculation.actualAmount }
            aggregateCalculation = budgetCalculator.calculate(
                budgetAmount: totalBudget,
                actualAmount: totalActual,
            )
        } else {
            aggregateCalculation = nil
        }

        return AnnualBudgetProgressResult(
            overallEntry: overallEntry,
            categoryEntries: categoryEntries,
            aggregateCalculation: aggregateCalculation,
        )
    }

    // MARK: - Helpers

    private func makeOverallEntry(
        year: Int,
        budgets: [Budget],
        totalExpense: Decimal,
    ) -> AnnualBudgetEntry? {
        let items = budgets.filter { $0.category == nil }
        guard let budget = items.first else { return nil }

        let totalAmount = items.reduce(Decimal.zero) { partial, budget in
            partial + budget.annualBudgetAmount(for: year)
        }

        let calculation = budgetCalculator.calculate(
            budgetAmount: totalAmount,
            actualAmount: totalExpense,
        )

        return AnnualBudgetEntry(
            id: .overall,
            budget: budget,
            title: "全体予算",
            calculation: calculation,
            isOverallBudget: true,
            displayOrder: DisplayOrder(parentOrder: -1, ownOrder: -1, name: "全体予算"),
        )
    }

    private func makeCategoryEntries(
        year: Int,
        budgets: [Budget],
        actualMap: [UUID: Decimal],
    ) -> [AnnualBudgetEntry] {
        let categoryBudgets = budgets.compactMap { budget -> (Category, Budget)? in
            guard let category = budget.category else { return nil }
            return (category, budget)
        }

        let groupedBudgets = Dictionary(grouping: categoryBudgets) { $0.0.id }

        return groupedBudgets.compactMap { categoryId, pairedItems -> AnnualBudgetEntry? in
            guard let category = pairedItems.first?.0 else { return nil }

            let totalAmount = pairedItems.reduce(Decimal.zero) { $0 + $1.1.annualBudgetAmount(for: year) }

            // 実績額を計算：カテゴリ自身の実績 + 子カテゴリの実績
            let actualAmount = calculateActualAmount(for: category, from: actualMap)

            let calculation = budgetCalculator.calculate(
                budgetAmount: totalAmount,
                actualAmount: actualAmount,
            )

            guard let budget = pairedItems.first?.1 else { return nil }

            return AnnualBudgetEntry(
                id: .category(categoryId),
                budget: budget,
                title: category.fullName,
                calculation: calculation,
                isOverallBudget: false,
                displayOrder: createDisplayOrder(for: category),
            )
        }
        .sorted { lhs, rhs in
            lhs.displayOrder < rhs.displayOrder
        }
    }

    /// カテゴリの実績額を計算（子カテゴリの実績も含む）
    private func calculateActualAmount(
        for category: Category,
        from actualMap: [UUID: Decimal],
    ) -> Decimal {
        var total = actualMap[category.id] ?? 0

        // 大項目の場合、子カテゴリ（中項目）の実績も合算
        if category.isMajor {
            for child in category.children {
                total += actualMap[child.id] ?? 0
            }
        }

        return total
    }

    private func createDisplayOrder(for category: Category) -> DisplayOrder {
        let parentOrder = category.parent?.displayOrder ?? category.displayOrder
        let ownOrder = category.displayOrder
        return DisplayOrder(parentOrder: parentOrder, ownOrder: ownOrder, name: category.fullName)
    }
}
