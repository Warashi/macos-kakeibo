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

    @Test("自動充当行には残額が均等に割り当てられる")
    internal func finalizeDistributesRemainingAcrossAutomaticRows() throws {
        var state = AnnualBudgetFormState()
        state.policy = .automatic
        let manualCategory = UUID()
        let automaticCategory1 = UUID()
        let automaticCategory2 = UUID()

        state.allocationRows = [
            AnnualBudgetAllocationRowState(
                selectedMajorCategoryId: manualCategory,
                amountText: "40000",
                selectedPolicyOverride: .manual,
            ),
            AnnualBudgetAllocationRowState(
                selectedMajorCategoryId: automaticCategory1,
                amountText: "",
                selectedPolicyOverride: nil,
            ),
            AnnualBudgetAllocationRowState(
                selectedMajorCategoryId: automaticCategory2,
                amountText: "",
                selectedPolicyOverride: nil,
            ),
        ]

        let result = state.finalizeAllocations(totalAmount: 100_000)
        guard case let .success(drafts) = result else {
            Issue.record()
            return
        }
        let amounts = Dictionary(uniqueKeysWithValues: drafts.map { ($0.categoryId, $0.amount) })

        #expect(amounts[manualCategory] == 40000)
        #expect(amounts[automaticCategory1] == 30000)
        #expect(amounts[automaticCategory2] == 30000)
    }

    @Test("残額が自動行の数で割り切れない場合でも切り捨てで配分される")
    internal func finalizeTruncatesRemainder() throws {
        var state = AnnualBudgetFormState()
        state.policy = .automatic
        let manualCategory = UUID()
        let automaticCategory1 = UUID()
        let automaticCategory2 = UUID()

        state.allocationRows = [
            AnnualBudgetAllocationRowState(
                selectedMajorCategoryId: manualCategory,
                amountText: "51000",
                selectedPolicyOverride: .manual,
            ),
            AnnualBudgetAllocationRowState(
                selectedMajorCategoryId: automaticCategory1,
                amountText: "",
                selectedPolicyOverride: nil,
            ),
            AnnualBudgetAllocationRowState(
                selectedMajorCategoryId: automaticCategory2,
                amountText: "",
                selectedPolicyOverride: nil,
            ),
        ]

        let result = state.finalizeAllocations(totalAmount: 100_000)
        guard case let .success(drafts) = result else {
            Issue.record()
            return
        }
        let amounts = Dictionary(uniqueKeysWithValues: drafts.map { ($0.categoryId, $0.amount) })

        #expect(amounts[automaticCategory1] == 24000)
        #expect(amounts[automaticCategory2] == 24000)
        #expect(amounts[manualCategory] == 51000)
    }

    @Test("自動配分でも手動合計が総額を超えたらエラー")
    internal func finalizeFailsWhenManualExceedsTotal() {
        var state = AnnualBudgetFormState()
        state.policy = .automatic
        state.allocationRows = [
            AnnualBudgetAllocationRowState(
                selectedMajorCategoryId: UUID(),
                amountText: "120000",
                selectedPolicyOverride: .manual,
            ),
            AnnualBudgetAllocationRowState(
                selectedMajorCategoryId: UUID(),
                amountText: "",
                selectedPolicyOverride: nil,
            ),
        ]

        let result = state.finalizeAllocations(totalAmount: 100_000)
        if case let .failure(error) = result {
            #expect(error == .manualExceedsTotal)
        } else {
            Issue.record()
        }
    }

    @Test("自動行が無いときは合計が一致しないとエラー")
    internal func finalizeRequiresExactSumWithoutAutomatic() {
        var state = AnnualBudgetFormState()
        state.policy = .manual
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

        let result = state.finalizeAllocations(totalAmount: 60000)
        if case let .failure(error) = result {
            #expect(error == .manualDoesNotMatchTotal)
        } else {
            Issue.record()
        }
    }
}
