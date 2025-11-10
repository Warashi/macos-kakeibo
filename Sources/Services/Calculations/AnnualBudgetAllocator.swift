import Foundation

/// 年次特別枠充当サービス
///
/// Facadeとしてバリデーション・エンジン・整形を連携させる。
internal struct AnnualBudgetAllocator: Sendable {
    private let budgetCalculator: BudgetCalculator
    private let validator: AnnualBudgetAllocationValidator
    private let engine: AnnualBudgetAllocationEngine
    private let resultFormatter: AnnualBudgetResultFormatter

    internal init(
        budgetCalculator: BudgetCalculator = BudgetCalculator(),
        validator: AnnualBudgetAllocationValidator = AnnualBudgetAllocationValidator(),
        engine: AnnualBudgetAllocationEngine = AnnualBudgetAllocationEngine(),
        resultFormatter: AnnualBudgetResultFormatter = AnnualBudgetResultFormatter()
    ) {
        self.budgetCalculator = budgetCalculator
        self.validator = validator
        self.engine = engine
        self.resultFormatter = resultFormatter
    }

    /// 年次特別枠の使用状況を計算
    internal func calculateAnnualBudgetUsage(
        params: AllocationCalculationParams,
        upToMonth: Int? = nil,
    ) -> AnnualBudgetUsage {
        let context = validator.makeContext(
            params: params,
            upToMonth: upToMonth,
        )

        if context.isPolicyCompletelyDisabled {
            return resultFormatter.makeDisabledUsage(
                year: context.accumulationParams.year,
                config: context.accumulationParams.annualBudgetConfig,
            )
        }

        let accumulationResult = engine.accumulateCategoryAllocations(
            accumulationParams: context.accumulationParams,
            policyOverrides: context.policyOverrides,
        )

        return resultFormatter.makeUsage(
            accumulationResult: accumulationResult,
            config: context.accumulationParams.annualBudgetConfig,
        )
    }

    /// 月次の年次特別枠充当を計算
    internal func calculateMonthlyAllocation(
        params: AllocationCalculationParams,
        year: Int,
        month: Int,
    ) -> MonthlyAllocation {
        let context = validator.makeContext(
            params: params,
            upToMonth: month,
        )

        let categoryAllocations = engine.calculateCategoryAllocations(
            params: params,
            year: year,
            month: month,
            policy: context.policy,
            policyOverrides: context.policyOverrides,
        )

        let accumulationResult = engine.accumulateCategoryAllocations(
            accumulationParams: context.accumulationParams,
            policyOverrides: context.policyOverrides,
        )

        let annualUsage = resultFormatter.makeUsage(
            accumulationResult: accumulationResult,
            config: context.accumulationParams.annualBudgetConfig,
        )

        return resultFormatter.makeMonthlyAllocation(
            year: year,
            month: month,
            annualUsage: annualUsage,
            categoryAllocations: categoryAllocations,
        )
    }
}
