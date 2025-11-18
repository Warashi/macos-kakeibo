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
internal struct AnnualBudgetProgressCalculator: Sendable {
    private let aggregator: TransactionAggregator
    private let budgetCalculator: BudgetCalculator

    internal init() {
        self.aggregator = TransactionAggregator()
        self.budgetCalculator = BudgetCalculator()
    }

    internal func calculate(
        budgets: [Budget],
        transactions: [Transaction],
        categories: [Category],
        year: Int,
        filter: AggregationFilter = .default,
        excludedCategoryIds: Set<UUID> = [],
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
            categories: categories,
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
            annualSummary: annualSummary,
            excludedCategoryIds: excludedCategoryIds,
        )

        let categoryEntries = makeCategoryEntries(
            year: year,
            budgets: annualBudgets,
            categories: categories,
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
        annualSummary: AnnualSummary,
        excludedCategoryIds: Set<UUID>,
    ) -> AnnualBudgetEntry? {
        let items = budgets.filter { $0.categoryId == nil }
        guard let budget = items.first else { return nil }

        let totalAmount = items.reduce(Decimal.zero) { partial, budget in
            partial + budget.annualBudgetAmount(for: year)
        }

        // 除外カテゴリの支出を計算
        let excludedExpense = annualSummary.categorySummaries.reduce(Decimal.zero) { partial, summary in
            guard let categoryId = summary.categoryId,
                  excludedCategoryIds.contains(categoryId) else {
                return partial
            }
            return partial + summary.totalExpense
        }

        // 全体支出から除外カテゴリの支出を引く
        let adjustedTotalExpense = annualSummary.totalExpense - excludedExpense

        let calculation = budgetCalculator.calculate(
            budgetAmount: totalAmount,
            actualAmount: adjustedTotalExpense,
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
        categories: [Category],
        actualMap: [UUID: Decimal],
    ) -> [AnnualBudgetEntry] {
        let categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })

        let categoryBudgets = budgets.compactMap { budget -> (Category, Budget)? in
            guard let categoryId = budget.categoryId,
                  let category = categoryMap[categoryId] else { return nil }
            return (category, budget)
        }

        let groupedBudgets = Dictionary(grouping: categoryBudgets) { $0.0.id }

        return groupedBudgets.compactMap { categoryId, pairedItems -> AnnualBudgetEntry? in
            guard let category = pairedItems.first?.0 else { return nil }

            let totalAmount = pairedItems.reduce(Decimal.zero) { $0 + $1.1.annualBudgetAmount(for: year) }

            // 実績額を計算：カテゴリ自身の実績 + 子カテゴリの実績
            let actualAmount = calculateActualAmount(
                for: category,
                categories: categories,
                from: actualMap,
            )

            let calculation = budgetCalculator.calculate(
                budgetAmount: totalAmount,
                actualAmount: actualAmount,
            )

            guard let budget = pairedItems.first?.1 else { return nil }

            let fullName = buildFullName(for: category, categories: categories)

            return AnnualBudgetEntry(
                id: .category(categoryId),
                budget: budget,
                title: fullName,
                calculation: calculation,
                isOverallBudget: false,
                displayOrder: createDisplayOrder(for: category, categories: categories),
            )
        }
        .sorted { lhs, rhs in
            lhs.displayOrder < rhs.displayOrder
        }
    }

    /// カテゴリの実績額を計算（子カテゴリの実績も含む）
    private func calculateActualAmount(
        for category: Category,
        categories: [Category],
        from actualMap: [UUID: Decimal],
    ) -> Decimal {
        var total = actualMap[category.id] ?? 0

        // 大項目の場合、子カテゴリ（中項目）の実績も合算
        if category.isMajor {
            let children = categories.filter { $0.parentId == category.id }
            for child in children {
                total += actualMap[child.id] ?? 0
            }
        }

        return total
    }

    private func buildFullName(for category: Category, categories: [Category]) -> String {
        guard let parentId = category.parentId,
              let parent = categories.first(where: { $0.id == parentId }) else {
            return category.name
        }
        return "\(parent.name) > \(category.name)"
    }

    private func createDisplayOrder(for category: Category, categories: [Category]) -> DisplayOrder {
        let parentOrder: Int = if let parentId = category.parentId,
                                  let parent = categories.first(where: { $0.id == parentId }) {
            parent.displayOrder
        } else {
            category.displayOrder
        }
        let ownOrder = category.displayOrder
        let fullName = buildFullName(for: category, categories: categories)
        return DisplayOrder(parentOrder: parentOrder, ownOrder: ownOrder, name: fullName)
    }
}
