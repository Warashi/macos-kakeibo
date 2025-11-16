import Foundation
import Testing

@testable import Kakeibo

@Suite
internal struct AnnualBudgetAllocationValidatorTests {
    private let validator: AnnualBudgetAllocationValidator = AnnualBudgetAllocationValidator()

    @Test("upToMonthがnilの場合は12ヶ月分を計算")
    internal func defaultMonthRange() throws {
        let params = makeParams(policy: .automatic)

        let context = validator.makeContext(params: params, upToMonth: nil)

        #expect(context.accumulationParams.endMonth == 12)
    }

    @Test("upToMonthが範囲外の場合でも1〜12にクランプされる")
    internal func clampMonthRange() throws {
        let params = makeParams(policy: .automatic)

        let lower = validator.makeContext(params: params, upToMonth: 0)
        let upper = validator.makeContext(params: params, upToMonth: 20)

        #expect(lower.accumulationParams.endMonth == 1)
        #expect(upper.accumulationParams.endMonth == 12)
    }

    @Test("ポリシーが無効でもカテゴリ毎の上書きがあれば計算を継続する")
    internal func disabledPolicyWithOverrides() throws {
        let category = CategoryEntity(name: "特別支出", allowsAnnualBudget: true)
        let allocation = AnnualBudgetAllocationEntity(
            amount: 100_000,
            category: category,
            policyOverride: .automatic,
        )
        let params = makeParams(
            policy: .disabled,
            allocations: [allocation],
        )

        let context = validator.makeContext(params: params, upToMonth: 5)

        #expect(context.isPolicyCompletelyDisabled == false)
        #expect(context.policyOverrides[category.id] == .automatic)
    }

    @Test("ポリシーが無効かつ上書きがない場合は完全に停止する")
    internal func disabledPolicyWithoutOverrides() throws {
        let params = makeParams(policy: .disabled)

        let context = validator.makeContext(params: params, upToMonth: 6)

        #expect(context.isPolicyCompletelyDisabled)
        #expect(context.policyOverrides.isEmpty)
    }

    private func makeParams(
        policy: AnnualBudgetPolicy,
        allocations: [AnnualBudgetAllocationEntity] = [],
    ) -> AllocationCalculationParams {
        let config = AnnualBudgetConfigEntity(
            year: 2025,
            totalAmount: 500_000,
            policy: policy,
        )
        config.allocations = allocations
        allocations.forEach { $0.config = config }

        return AllocationCalculationParams(
            transactions: [],
            budgets: [],
            annualBudgetConfig: AnnualBudgetConfig(from: config),
        )
    }
}
