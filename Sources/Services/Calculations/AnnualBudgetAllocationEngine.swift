import Foundation

/// 実際の計算ロジックを束ねるエンジン
internal struct AnnualBudgetAllocationEngine: Sendable {
    internal struct AccumulationResult: Sendable {
        internal let totalUsed: Decimal
        internal let categoryAllocations: [CategoryAllocation]
    }

    private let categoryCalculator: AnnualBudgetAllocationCategoryCalculator

    internal init(
        categoryCalculator: AnnualBudgetAllocationCategoryCalculator = AnnualBudgetAllocationCategoryCalculator()
    ) {
        self.categoryCalculator = categoryCalculator
    }

    internal func accumulateCategoryAllocations(
        accumulationParams: AccumulationParams,
        policyOverrides: [UUID: AnnualBudgetPolicy],
    ) -> AccumulationResult {
        var totalUsed: Decimal = 0
        var categoryAccumulator: [UUID: CategoryAllocationAccumulator] = [:]

        for allocation in accumulationParams.annualBudgetConfig.allocations {
            let category = allocation.category
            categoryAccumulator[category.id] = CategoryAllocationAccumulator(
                categoryId: category.id,
                categoryName: category.fullName,
                annualBudgetAmount: allocation.amount,
                monthlyBudgetAmount: 0,
                actualAmount: 0,
                excessAmount: 0,
                allocatableAmount: 0,
                remainingAfterAllocation: 0
            )
        }

        for month in 1 ... accumulationParams.endMonth {
            let monthlyCategoryAllocations = categoryCalculator.calculateCategoryAllocations(
                params: accumulationParams.params,
                year: accumulationParams.year,
                month: month,
                policy: accumulationParams.policy,
                policyOverrides: policyOverrides
            )

            let monthlyUsed = monthlyCategoryAllocations.reduce(Decimal.zero) { $0 + $1.allocatableAmount }
            totalUsed += monthlyUsed

            accumulateCategory(
                allocations: monthlyCategoryAllocations,
                into: &categoryAccumulator
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
                    remainingAfterAllocation: accumulator.remainingAfterAllocation
                )
            }
            .sorted { $0.categoryName < $1.categoryName }

        return AccumulationResult(
            totalUsed: totalUsed,
            categoryAllocations: categoryAllocations
        )
    }

    internal func calculateCategoryAllocations(
        params: AllocationCalculationParams,
        year: Int,
        month: Int,
        policy: AnnualBudgetPolicy,
        policyOverrides: [UUID: AnnualBudgetPolicy]
    ) -> [CategoryAllocation] {
        categoryCalculator.calculateCategoryAllocations(
            params: params,
            year: year,
            month: month,
            policy: policy,
            policyOverrides: policyOverrides
        )
    }

    private func accumulateCategory(
        allocations: [CategoryAllocation],
        into categoryAccumulator: inout [UUID: CategoryAllocationAccumulator]
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
                    remainingAfterAllocation: allocation.remainingAfterAllocation
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
