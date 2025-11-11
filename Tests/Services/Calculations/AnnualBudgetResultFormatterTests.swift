import Foundation
import Testing

@testable import Kakeibo

@Suite
internal struct AnnualBudgetResultFormatterTests {
    private let formatter: AnnualBudgetResultFormatter = AnnualBudgetResultFormatter()

    @Test("使用状況フォーマット：残額と利用率を計算")
    internal func formatUsage() throws {
        let config = AnnualBudgetConfig(
            year: 2025,
            totalAmount: 200_000,
            policy: .automatic,
        )
        let accumulationResult = AnnualBudgetAllocationEngine.AccumulationResult(
            totalUsed: 50000,
            categoryAllocations: [
                CategoryAllocation(
                    categoryId: UUID(),
                    categoryName: "食費",
                    annualBudgetAmount: 100_000,
                    monthlyBudgetAmount: 50000,
                    actualAmount: 80000,
                    excessAmount: 30000,
                    allocatableAmount: 30000,
                    remainingAfterAllocation: 0,
                ),
            ],
        )

        let usage = formatter.makeUsage(accumulationResult: accumulationResult, config: config)

        #expect(usage.remainingAmount == 150_000)
        #expect(abs(usage.usageRate - 0.25) < 0.0001)
        #expect(usage.categoryAllocations.count == 1)
    }

    @Test("無効時は空の使用状況を返す")
    internal func disabledUsage() throws {
        let config = AnnualBudgetConfig(
            year: 2025,
            totalAmount: 100_000,
            policy: .disabled,
        )

        let usage = formatter.makeDisabledUsage(year: 2025, config: config)

        #expect(usage.usedAmount == 0)
        #expect(usage.categoryAllocations.isEmpty)
    }

    @Test("月次結果の整形で年次使用状況を保持する")
    internal func formatMonthlyAllocation() throws {
        let usage = AnnualBudgetUsage(
            year: 2025,
            totalAmount: 100_000,
            usedAmount: 10000,
            remainingAmount: 90000,
            usageRate: 0.1,
            categoryAllocations: [],
        )

        let monthly = formatter.makeMonthlyAllocation(
            year: 2025,
            month: 4,
            annualUsage: usage,
            categoryAllocations: [],
        )

        #expect(monthly.year == 2025)
        #expect(monthly.month == 4)
        #expect(monthly.annualBudgetUsage.usedAmount == 10000)
    }
}
