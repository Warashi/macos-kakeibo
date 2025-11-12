import Foundation

/// 実際の計算ロジックを束ねるエンジン
internal struct AnnualBudgetAllocationEngine: Sendable {
    internal struct AccumulationResult: Sendable {
        internal let totalUsed: Decimal
        internal let categoryAllocations: [CategoryAllocation]
    }

    private let categoryCalculator: AnnualBudgetAllocationCategoryCalculator

    internal init(
        categoryCalculator: AnnualBudgetAllocationCategoryCalculator = AnnualBudgetAllocationCategoryCalculator(),
    ) {
        self.categoryCalculator = categoryCalculator
    }

    internal func accumulateCategoryAllocations(
        accumulationParams: AccumulationParams,
        policyOverrides: [UUID: AnnualBudgetPolicy],
        categories: [CategoryDTO],
    ) -> AccumulationResult {
        var totalUsed: Decimal = 0
        var categoryAccumulator: [UUID: CategoryAllocationAccumulator] = [:]
        let categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })

        for allocation in accumulationParams.annualBudgetConfig.allocations {
            let categoryId = allocation.categoryId
            guard let category = categoryMap[categoryId] else { continue }
            let categoryName = buildCategoryName(category: category, categories: categories)
            categoryAccumulator[categoryId] = CategoryAllocationAccumulator(
                categoryId: categoryId,
                categoryName: categoryName,
                annualBudgetAmount: allocation.amount,
                monthlyBudgetAmount: 0,
                actualAmount: 0,
                excessAmount: 0,
                allocatableAmount: 0,
                remainingAfterAllocation: 0,
            )
        }

        for month in 1 ... accumulationParams.endMonth {
            let request = MonthlyCategoryAllocationRequest(
                params: accumulationParams.params,
                year: accumulationParams.year,
                month: month,
                policy: accumulationParams.policy,
                policyOverrides: policyOverrides,
            )
            let monthlyCategoryAllocations = categoryCalculator.calculateCategoryAllocations(
                request: request,
                categories: categories,
            )

            let monthlyUsed = monthlyCategoryAllocations.reduce(Decimal.zero) { $0 + $1.allocatableAmount }
            totalUsed += monthlyUsed

            accumulateCategory(
                allocations: monthlyCategoryAllocations,
                into: &categoryAccumulator,
            )
        }

        let categoryAllocations = categoryAccumulator.values
            .map { accumulator in
                CategoryAllocation(
                    categoryId: accumulator.categoryId,
                    categoryName: accumulator.categoryName,
                    annualBudgetAmount: accumulator.annualBudgetAmount,
                    monthlyBudgetAmount: accumulator.monthlyBudgetAmount,
                    actualAmount: accumulator.actualAmount,
                    excessAmount: accumulator.excessAmount,
                    allocatableAmount: accumulator.allocatableAmount,
                    remainingAfterAllocation: accumulator.remainingAfterAllocation,
                )
            }
            .sorted { $0.categoryName < $1.categoryName }

        return AccumulationResult(
            totalUsed: totalUsed,
            categoryAllocations: categoryAllocations,
        )
    }

    internal func calculateCategoryAllocations(
        request: MonthlyCategoryAllocationRequest,
        categories: [CategoryDTO],
    ) -> [CategoryAllocation] {
        categoryCalculator.calculateCategoryAllocations(request: request, categories: categories)
    }

    private func buildCategoryName(category: CategoryDTO, categories: [CategoryDTO]) -> String {
        if let parentId = category.parentId,
           let parent = categories.first(where: { $0.id == parentId }) {
            return "\(parent.name) > \(category.name)"
        }
        return category.name
    }

    private func accumulateCategory(
        allocations: [CategoryAllocation],
        into categoryAccumulator: inout [UUID: CategoryAllocationAccumulator],
    ) {
        for allocation in allocations {
            if var accumulator = categoryAccumulator[allocation.categoryId] {
                accumulator.monthlyBudgetAmount += allocation.monthlyBudgetAmount
                accumulator.actualAmount += allocation.actualAmount
                accumulator.excessAmount += allocation.excessAmount
                accumulator.allocatableAmount += allocation.allocatableAmount
                accumulator.remainingAfterAllocation += allocation.remainingAfterAllocation
                categoryAccumulator[allocation.categoryId] = accumulator
            } else {
                categoryAccumulator[allocation.categoryId] = CategoryAllocationAccumulator(
                    categoryId: allocation.categoryId,
                    categoryName: allocation.categoryName,
                    annualBudgetAmount: allocation.annualBudgetAmount,
                    monthlyBudgetAmount: allocation.monthlyBudgetAmount,
                    actualAmount: allocation.actualAmount,
                    excessAmount: allocation.excessAmount,
                    allocatableAmount: allocation.allocatableAmount,
                    remainingAfterAllocation: allocation.remainingAfterAllocation,
                )
            }
        }
    }
}

private struct CategoryAllocationAccumulator {
    let categoryId: UUID
    let categoryName: String
    let annualBudgetAmount: Decimal
    var monthlyBudgetAmount: Decimal
    var actualAmount: Decimal
    var excessAmount: Decimal
    var allocatableAmount: Decimal
    var remainingAfterAllocation: Decimal
}
