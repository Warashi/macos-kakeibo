import Foundation

/// 計算結果の整形を担当
internal struct AnnualBudgetResultFormatter: Sendable {
    internal func makeUsage(
        accumulationResult: AnnualBudgetAllocationEngine.AccumulationResult,
        config: AnnualBudgetConfigDTO,
    ) -> AnnualBudgetUsage {
        let remaining = config.totalAmount - accumulationResult.totalUsed
        let usageRate: Double = if config.totalAmount > 0 {
            NSDecimalNumber(decimal: accumulationResult.totalUsed)
                .doubleValue / NSDecimalNumber(decimal: config.totalAmount).doubleValue
        } else {
            0.0
        }

        return AnnualBudgetUsage(
            year: config.year,
            totalAmount: config.totalAmount,
            usedAmount: accumulationResult.totalUsed,
            remainingAmount: remaining,
            usageRate: usageRate,
            categoryAllocations: accumulationResult.categoryAllocations,
        )
    }

    internal func makeDisabledUsage(year: Int, config: AnnualBudgetConfigDTO) -> AnnualBudgetUsage {
        AnnualBudgetUsage(
            year: year,
            totalAmount: config.totalAmount,
            usedAmount: 0,
            remainingAmount: config.totalAmount,
            usageRate: 0.0,
            categoryAllocations: [],
        )
    }

    internal func makeMonthlyAllocation(
        year: Int,
        month: Int,
        annualUsage: AnnualBudgetUsage,
        categoryAllocations: [CategoryAllocation],
    ) -> MonthlyAllocation {
        MonthlyAllocation(
            year: year,
            month: month,
            annualBudgetUsage: annualUsage,
            categoryAllocations: categoryAllocations,
        )
    }
}
