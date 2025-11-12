import Foundation

/// AnnualBudgetAllocatorで使用する前処理を担当
internal struct AnnualBudgetAllocationValidator: Sendable {
    internal func makeContext(
        params: AllocationCalculationParams,
        upToMonth: Int?,
    ) -> ValidatedAllocationContext {
        let accumulationParams = AccumulationParams(
            params: params,
            year: params.annualBudgetConfig.year,
            endMonth: sanitizedMonth(upToMonth),
            policy: params.annualBudgetConfig.policy,
            annualBudgetConfig: params.annualBudgetConfig,
        )

        return ValidatedAllocationContext(
            accumulationParams: accumulationParams,
            policyOverrides: buildPolicyOverrideMap(from: params.annualBudgetConfig),
        )
    }

    private func sanitizedMonth(_ rawValue: Int?) -> Int {
        guard let rawValue else { return 12 }
        return min(max(rawValue, 1), 12)
    }

    private func buildPolicyOverrideMap(from config: AnnualBudgetConfigDTO) -> [UUID: AnnualBudgetPolicy] {
        config.allocations.reduce(into: [:]) { partialResult, allocation in
            guard let override = allocation.policyOverride else { return }
            partialResult[allocation.categoryId] = override
        }
    }
}

/// Validatorが構築した計算文脈
internal struct ValidatedAllocationContext {
    internal let accumulationParams: AccumulationParams
    internal let policyOverrides: [UUID: AnnualBudgetPolicy]

    internal var policy: AnnualBudgetPolicy {
        accumulationParams.policy
    }

    internal var annualBudgetConfig: AnnualBudgetConfigDTO {
        accumulationParams.annualBudgetConfig
    }

    internal var isPolicyCompletelyDisabled: Bool {
        policy == .disabled && policyOverrides.isEmpty
    }
}

/// 累積計算パラメータ
internal struct AccumulationParams {
    internal let params: AllocationCalculationParams
    internal let year: Int
    internal let endMonth: Int
    internal let policy: AnnualBudgetPolicy
    internal let annualBudgetConfig: AnnualBudgetConfigDTO
}
