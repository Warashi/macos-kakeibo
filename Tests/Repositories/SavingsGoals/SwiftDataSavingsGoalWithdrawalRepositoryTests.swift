import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite("SwiftDataSavingsGoalWithdrawalRepository")
internal struct SwiftDataSavingsGoalWithdrawalRepositoryTests {
    @Test("createWithdrawal: 引出記録を作成できる")
    internal func createWithdrawal() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let repository = SwiftDataSavingsGoalWithdrawalRepository(modelContainer: container)

        // 貯蓄目標を作成
        let goal = SwiftDataSavingsGoal(
            name: "海外旅行",
            targetAmount: 500_000,
            monthlySavingAmount: 50_000,
            categoryId: nil,
            notes: nil,
            startDate: Date(),
            targetDate: nil,
            isActive: true
        )
        context.insert(goal)

        // 残高を作成
        let balance = SwiftDataSavingsGoalBalance(
            goal: goal,
            totalSavedAmount: 200_000,
            totalWithdrawnAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11
        )
        context.insert(balance)
        try context.save()

        // 引出記録を作成
        let input = SavingsGoalWithdrawalInput(
            goalId: goal.id,
            amount: 50_000,
            withdrawalDate: Date(),
            purpose: "航空券購入"
        )

        let withdrawal = try await repository.createWithdrawal(input)
        #expect(withdrawal.goalId == goal.id)
        #expect(withdrawal.amount == 50_000)
        #expect(withdrawal.purpose == "航空券購入")

        // 残高が更新されているか確認
        let goalId = goal.id
        let balanceDescriptor = FetchDescriptor<SwiftDataSavingsGoalBalance>(
            predicate: #Predicate { $0.goal.id == goalId }
        )
        let updatedBalance = try context.fetch(balanceDescriptor).first
        #expect(updatedBalance?.totalWithdrawnAmount == 50_000)
    }

    @Test("createWithdrawal: 存在しないgoalIdの場合エラー")
    internal func createWithdrawalNotFound() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let repository = SwiftDataSavingsGoalWithdrawalRepository(modelContainer: container)

        let input = SavingsGoalWithdrawalInput(
            goalId: UUID(),
            amount: 50_000,
            withdrawalDate: Date(),
            purpose: "test"
        )

        await #expect(throws: RepositoryError.notFound) {
            try await repository.createWithdrawal(input)
        }
    }

    @Test("fetchWithdrawals: 指定されたgoalIdの引出記録を取得できる")
    internal func fetchWithdrawalsByGoalId() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let repository = SwiftDataSavingsGoalWithdrawalRepository(modelContainer: container)

        // 貯蓄目標を作成
        let goal1 = SwiftDataSavingsGoal(
            name: "海外旅行",
            targetAmount: 500_000,
            monthlySavingAmount: 50_000,
            categoryId: nil,
            notes: nil,
            startDate: Date(),
            targetDate: nil,
            isActive: true
        )

        let goal2 = SwiftDataSavingsGoal(
            name: "車購入",
            targetAmount: 2_000_000,
            monthlySavingAmount: 100_000,
            categoryId: nil,
            notes: nil,
            startDate: Date(),
            targetDate: nil,
            isActive: true
        )

        context.insert(goal1)
        context.insert(goal2)

        // 引出記録を作成
        let withdrawal1 = SwiftDataSavingsGoalWithdrawal(
            goal: goal1,
            amount: 50_000,
            withdrawalDate: Date(),
            purpose: "航空券"
        )

        let withdrawal2 = SwiftDataSavingsGoalWithdrawal(
            goal: goal1,
            amount: 30_000,
            withdrawalDate: Date(),
            purpose: "ホテル"
        )

        let withdrawal3 = SwiftDataSavingsGoalWithdrawal(
            goal: goal2,
            amount: 100_000,
            withdrawalDate: Date(),
            purpose: "頭金"
        )

        context.insert(withdrawal1)
        context.insert(withdrawal2)
        context.insert(withdrawal3)
        try context.save()

        let results = try await repository.fetchWithdrawals(forGoalId: goal1.id)
        #expect(results.count == 2)
        #expect(results.allSatisfy { $0.goalId == goal1.id })
    }

    @Test("fetchAllWithdrawals: すべての引出記録を取得できる")
    internal func fetchAllWithdrawals() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let repository = SwiftDataSavingsGoalWithdrawalRepository(modelContainer: container)

        // 貯蓄目標を作成
        let goal = SwiftDataSavingsGoal(
            name: "海外旅行",
            targetAmount: 500_000,
            monthlySavingAmount: 50_000,
            categoryId: nil,
            notes: nil,
            startDate: Date(),
            targetDate: nil,
            isActive: true
        )
        context.insert(goal)

        // 引出記録を作成
        let withdrawal1 = SwiftDataSavingsGoalWithdrawal(
            goal: goal,
            amount: 50_000,
            withdrawalDate: Date(),
            purpose: "航空券"
        )

        let withdrawal2 = SwiftDataSavingsGoalWithdrawal(
            goal: goal,
            amount: 30_000,
            withdrawalDate: Date(),
            purpose: "ホテル"
        )

        context.insert(withdrawal1)
        context.insert(withdrawal2)
        try context.save()

        let results = try await repository.fetchAllWithdrawals()
        #expect(results.count == 2)
    }

    @Test("deleteWithdrawal: 引出記録を削除できる")
    internal func deleteWithdrawal() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let repository = SwiftDataSavingsGoalWithdrawalRepository(modelContainer: container)

        // 貯蓄目標を作成
        let goal = SwiftDataSavingsGoal(
            name: "海外旅行",
            targetAmount: 500_000,
            monthlySavingAmount: 50_000,
            categoryId: nil,
            notes: nil,
            startDate: Date(),
            targetDate: nil,
            isActive: true
        )
        context.insert(goal)

        // 残高を作成
        let balance = SwiftDataSavingsGoalBalance(
            goal: goal,
            totalSavedAmount: 200_000,
            totalWithdrawnAmount: 50_000,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11
        )
        context.insert(balance)

        // 引出記録を作成
        let withdrawal = SwiftDataSavingsGoalWithdrawal(
            goal: goal,
            amount: 50_000,
            withdrawalDate: Date(),
            purpose: "航空券"
        )
        context.insert(withdrawal)
        try context.save()

        // 引出記録を削除
        let withdrawalId = withdrawal.id
        try await repository.deleteWithdrawal(withdrawalId)

        // 削除されたか確認
        let descriptor = FetchDescriptor<SwiftDataSavingsGoalWithdrawal>(
            predicate: #Predicate { $0.id == withdrawalId }
        )
        let deleted = try context.fetch(descriptor).first
        #expect(deleted == nil)

        // 残高が更新されているか確認
        let goalId = goal.id
        let balanceDescriptor = FetchDescriptor<SwiftDataSavingsGoalBalance>(
            predicate: #Predicate { $0.goal.id == goalId }
        )
        let updatedBalance = try context.fetch(balanceDescriptor).first
        #expect(updatedBalance?.totalWithdrawnAmount == 0)
    }
}
