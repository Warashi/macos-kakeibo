import Foundation
import Testing

@testable import Kakeibo

@Suite("SavingsGoalListEntry")
internal struct SavingsGoalListEntryTests {
    @Test("idはgoal.idを返す")
    internal func id_returnsGoalId() throws {
        let goal = SavingsGoal(
            id: UUID(),
            name: "新車購入",
            targetAmount: 3_000_000,
            monthlySavingAmount: 100_000,
            categoryId: nil,
            notes: nil,
            startDate: Date(),
            targetDate: nil,
            isActive: true,
            createdAt: Date(),
            updatedAt: Date()
        )

        let entry = SavingsGoalListEntry(goal: goal, balance: nil)

        #expect(entry.id == goal.id)
    }

    @Test("進捗計算: 目標金額と残高がある場合")
    internal func progress_withTargetAndBalance() throws {
        let goal = SavingsGoal(
            id: UUID(),
            name: "新車購入",
            targetAmount: 3_000_000,
            monthlySavingAmount: 100_000,
            categoryId: nil,
            notes: nil,
            startDate: Date(),
            targetDate: nil,
            isActive: true,
            createdAt: Date(),
            updatedAt: Date()
        )

        let balance = SavingsGoalBalance(
            id: UUID(),
            goalId: goal.id,
            totalSavedAmount: 1_500_000,
            totalWithdrawnAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
            createdAt: Date(),
            updatedAt: Date()
        )

        let entry = SavingsGoalListEntry(goal: goal, balance: balance)

        #expect(entry.progress == 0.5)
    }

    @Test("進捗計算: 目標金額を超えた場合は1.0")
    internal func progress_cappedAtOne() throws {
        let goal = SavingsGoal(
            id: UUID(),
            name: "新車購入",
            targetAmount: 3_000_000,
            monthlySavingAmount: 100_000,
            categoryId: nil,
            notes: nil,
            startDate: Date(),
            targetDate: nil,
            isActive: true,
            createdAt: Date(),
            updatedAt: Date()
        )

        let balance = SavingsGoalBalance(
            id: UUID(),
            goalId: goal.id,
            totalSavedAmount: 4_000_000,
            totalWithdrawnAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
            createdAt: Date(),
            updatedAt: Date()
        )

        let entry = SavingsGoalListEntry(goal: goal, balance: balance)

        #expect(entry.progress == 1.0)
    }

    @Test("進捗計算: 目標金額がない場合はnil")
    internal func progress_nilWhenNoTarget() throws {
        let goal = SavingsGoal(
            id: UUID(),
            name: "緊急資金",
            targetAmount: nil,
            monthlySavingAmount: 50_000,
            categoryId: nil,
            notes: nil,
            startDate: Date(),
            targetDate: nil,
            isActive: true,
            createdAt: Date(),
            updatedAt: Date()
        )

        let balance = SavingsGoalBalance(
            id: UUID(),
            goalId: goal.id,
            totalSavedAmount: 500_000,
            totalWithdrawnAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
            createdAt: Date(),
            updatedAt: Date()
        )

        let entry = SavingsGoalListEntry(goal: goal, balance: balance)

        #expect(entry.progress == nil)
    }

    @Test("進捗計算: 残高がない場合はnil")
    internal func progress_nilWhenNoBalance() throws {
        let goal = SavingsGoal(
            id: UUID(),
            name: "新車購入",
            targetAmount: 3_000_000,
            monthlySavingAmount: 100_000,
            categoryId: nil,
            notes: nil,
            startDate: Date(),
            targetDate: nil,
            isActive: true,
            createdAt: Date(),
            updatedAt: Date()
        )

        let entry = SavingsGoalListEntry(goal: goal, balance: nil)

        #expect(entry.progress == nil)
    }

    @Test("進捗計算: 目標金額が0の場合はnil")
    internal func progress_nilWhenTargetIsZero() throws {
        let goal = SavingsGoal(
            id: UUID(),
            name: "テスト",
            targetAmount: 0,
            monthlySavingAmount: 10_000,
            categoryId: nil,
            notes: nil,
            startDate: Date(),
            targetDate: nil,
            isActive: true,
            createdAt: Date(),
            updatedAt: Date()
        )

        let balance = SavingsGoalBalance(
            id: UUID(),
            goalId: goal.id,
            totalSavedAmount: 100_000,
            totalWithdrawnAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
            createdAt: Date(),
            updatedAt: Date()
        )

        let entry = SavingsGoalListEntry(goal: goal, balance: balance)

        #expect(entry.progress == nil)
    }

    @Test("進捗計算: 引出を考慮した残高")
    internal func progress_withWithdrawals() throws {
        let goal = SavingsGoal(
            id: UUID(),
            name: "新車購入",
            targetAmount: 3_000_000,
            monthlySavingAmount: 100_000,
            categoryId: nil,
            notes: nil,
            startDate: Date(),
            targetDate: nil,
            isActive: true,
            createdAt: Date(),
            updatedAt: Date()
        )

        let balance = SavingsGoalBalance(
            id: UUID(),
            goalId: goal.id,
            totalSavedAmount: 2_000_000,
            totalWithdrawnAmount: 500_000,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
            createdAt: Date(),
            updatedAt: Date()
        )

        let entry = SavingsGoalListEntry(goal: goal, balance: balance)

        // balance.balance = 2,000,000 - 500,000 = 1,500,000
        // progress = 1,500,000 / 3,000,000 = 0.5
        #expect(entry.progress == 0.5)
    }
}
