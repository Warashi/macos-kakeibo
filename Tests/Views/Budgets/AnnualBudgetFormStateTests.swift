import Foundation
import Testing

@testable import Kakeibo

@Suite("AnnualBudgetFormState Tests")
internal struct AnnualBudgetFormStateTests {
    @Test("ロード時、自動充当かつ金額0なら表示を空欄にする")
    internal func loadLeavesAmountBlankForAutomaticZero() throws {
        let category = Category(name: "特別", allowsAnnualBudget: true)
        let config = AnnualBudgetConfig(year: 2025, totalAmount: 100_000, policy: .automatic)
        let allocation = AnnualBudgetAllocation(amount: 0, category: category)
        config.allocations = [allocation]

        var state = AnnualBudgetFormState()
        state.load(from: config)

        let row = try #require(state.allocationRows.first)
        #expect(row.amountText.isEmpty)
    }

    @Test("自動充当では金額未入力でもドラフト生成できる")
    internal func automaticPolicyAllowsEmptyAmount() throws {
        var state = AnnualBudgetFormState()
        state.policy = .automatic
        let categoryId = UUID()
        state.allocationRows = [
            AnnualBudgetAllocationRowState(
                selectedMajorCategoryId: categoryId,
                amountText: "",
                selectedPolicyOverride: nil,
            ),
        ]

        let drafts = try #require(state.makeAllocationDrafts())
        #expect(drafts.count == 1)
        #expect(drafts.first?.categoryId == categoryId)
        #expect(drafts.first?.amount == 0)
    }

    @Test("手動充当では金額必須")
    internal func manualPolicyRequiresAmount() {
        var state = AnnualBudgetFormState()
        state.policy = .manual
        state.allocationRows = [
            AnnualBudgetAllocationRowState(
                selectedMajorCategoryId: UUID(),
                amountText: "",
                selectedPolicyOverride: nil,
            ),
        ]

        #expect(state.makeAllocationDrafts() == nil)
    }

    @Test("カテゴリ個別で自動充当指定した場合も金額は任意")
    internal func overrideAutomaticAllowsEmptyAmount() throws {
        var state = AnnualBudgetFormState()
        state.policy = .manual
        let categoryId = UUID()
        state.allocationRows = [
            AnnualBudgetAllocationRowState(
                selectedMajorCategoryId: categoryId,
                amountText: "",
                selectedPolicyOverride: .automatic,
            ),
        ]

        let drafts = try #require(state.makeAllocationDrafts())
        #expect(drafts.first?.categoryId == categoryId)
        #expect(drafts.first?.amount == 0)
        #expect(drafts.first?.policyOverride == .automatic)
    }
}
