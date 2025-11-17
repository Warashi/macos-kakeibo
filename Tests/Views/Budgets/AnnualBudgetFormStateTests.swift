import Foundation
import Testing

@testable import Kakeibo

@Suite("AnnualBudgetFormState Tests")
internal struct AnnualBudgetFormStateTests {
    @Test("ロード時、0円でも文字列として保持する")
    internal func loadKeepsZeroAmountText() throws {
        let category = SwiftDataCategory(name: "特別", allowsAnnualBudget: true)
        let config = SwiftDataAnnualBudgetConfig(year: 2025, totalAmount: 100_000, policy: .automatic)
        let allocation = SwiftDataAnnualBudgetAllocation(amount: 0, category: category)
        config.allocations = [allocation]

        var state = AnnualBudgetFormState()
        state.load(from: AnnualBudgetConfig(from: config), categories: [Category(from: category)])

        let row = try #require(state.allocationRows.first)
        #expect(row.amountText == "0")
    }

    @Test("金額未入力の行は常にドラフト生成に失敗する")
    internal func makeAllocationDraftsRequireAmount() {
        var state = AnnualBudgetFormState()
        state.policy = .automatic
        state.allocationRows = [
            AnnualBudgetAllocationRowState(
                selectedMajorCategoryId: UUID(),
                amountText: "",
                selectedPolicyOverride: nil,
            ),
        ]

        #expect(state.makeAllocationDrafts() == nil)
    }

    @Test("金額を入力すればドラフトを生成できる")
    internal func makeAllocationDraftsSucceedWithAmount() throws {
        var state = AnnualBudgetFormState()
        let categoryId = UUID()
        state.allocationRows = [
            AnnualBudgetAllocationRowState(
                selectedMajorCategoryId: categoryId,
                amountText: "50000",
                selectedPolicyOverride: .manual,
            ),
        ]

        let drafts = try #require(state.makeAllocationDrafts())
        #expect(drafts.count == 1)
        #expect(drafts.first?.categoryId == categoryId)
        #expect(drafts.first?.amount == 50000)
    }

    @Test("カテゴリ合計が総額と一致すれば確定できる")
    internal func finalizeSucceedsWhenSumMatches() throws {
        var state = AnnualBudgetFormState()
        let category1 = UUID()
        let category2 = UUID()
        state.allocationRows = [
            AnnualBudgetAllocationRowState(
                selectedMajorCategoryId: category1,
                amountText: "30000",
                selectedPolicyOverride: .manual,
            ),
            AnnualBudgetAllocationRowState(
                selectedMajorCategoryId: category2,
                amountText: "70000",
                selectedPolicyOverride: .manual,
            ),
        ]

        let result = state.finalizeAllocations(totalAmount: 100_000)
        guard case let .success(drafts) = result else {
            Issue.record()
            return
        }

        let amounts = Dictionary(uniqueKeysWithValues: drafts.map { ($0.categoryId, $0.amount) })
        #expect(amounts[category1] == 30000)
        #expect(amounts[category2] == 70000)
    }

    @Test("カテゴリ合計が総額と一致しない場合はエラー")
    internal func finalizeFailsWhenSumDoesNotMatch() {
        var state = AnnualBudgetFormState()
        state.allocationRows = [
            AnnualBudgetAllocationRowState(
                selectedMajorCategoryId: UUID(),
                amountText: "30000",
                selectedPolicyOverride: .manual,
            ),
            AnnualBudgetAllocationRowState(
                selectedMajorCategoryId: UUID(),
                amountText: "40000",
                selectedPolicyOverride: .manual,
            ),
        ]

        let result = state.finalizeAllocations(totalAmount: 80000)
        if case let .failure(error) = result {
            #expect(error == .manualDoesNotMatchTotal)
        } else {
            Issue.record()
        }
    }
}
