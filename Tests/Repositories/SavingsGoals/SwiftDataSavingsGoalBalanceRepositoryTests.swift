import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite("SwiftDataSavingsGoalBalanceRepository")
internal struct SavingsGoalBalanceRepositoryTests {
    @Test("fetchBalance: 指定されたgoalIdの残高を取得できる")
    internal func fetchBalanceByGoalId() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let repository = SwiftDataSavingsGoalBalanceRepository(modelContainer: container)

        let goal1 = SwiftDataSavingsGoal(
            name: "海外旅行",
            targetAmount: 500_000,
            monthlySavingAmount: 50000,
            categoryId: nil,
            notes: nil,
            startDate: Date(),
            targetDate: nil,
            isActive: true,
        )

        let goal2 = SwiftDataSavingsGoal(
            name: "車購入",
            targetAmount: 2_000_000,
            monthlySavingAmount: 100_000,
            categoryId: nil,
            notes: nil,
            startDate: Date(),
            targetDate: nil,
            isActive: true,
        )

        context.insert(goal1)
        context.insert(goal2)

        let balance1 = SwiftDataSavingsGoalBalance(
            goal: goal1,
            totalSavedAmount: 150_000,
            totalWithdrawnAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
        )

        let balance2 = SwiftDataSavingsGoalBalance(
            goal: goal2,
            totalSavedAmount: 300_000,
            totalWithdrawnAmount: 50000,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
        )

        context.insert(balance1)
        context.insert(balance2)
        try context.save()

        let result = try await repository.fetchBalance(forGoalId: goal1.id)
        #expect(result != nil)
        #expect(result?.goalId == goal1.id)
        #expect(result?.totalSavedAmount == 150_000)
        #expect(result?.totalWithdrawnAmount == 0)
        #expect(result?.balance == 150_000)
    }

    @Test("fetchBalance: 存在しないgoalIdの場合nilを返す")
    internal func fetchBalanceNotFound() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let repository = SwiftDataSavingsGoalBalanceRepository(modelContainer: container)

        let result = try await repository.fetchBalance(forGoalId: UUID())
        #expect(result == nil)
    }

    @Test("fetchAllBalances: すべての残高を取得できる")
    internal func fetchAllBalances() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let repository = SwiftDataSavingsGoalBalanceRepository(modelContainer: container)

        let goal1 = SwiftDataSavingsGoal(
            name: "海外旅行",
            targetAmount: 500_000,
            monthlySavingAmount: 50000,
            categoryId: nil,
            notes: nil,
            startDate: Date(),
            targetDate: nil,
            isActive: true,
        )

        let goal2 = SwiftDataSavingsGoal(
            name: "車購入",
            targetAmount: 2_000_000,
            monthlySavingAmount: 100_000,
            categoryId: nil,
            notes: nil,
            startDate: Date(),
            targetDate: nil,
            isActive: true,
        )

        context.insert(goal1)
        context.insert(goal2)

        let balance1 = SwiftDataSavingsGoalBalance(
            goal: goal1,
            totalSavedAmount: 150_000,
            totalWithdrawnAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
        )

        let balance2 = SwiftDataSavingsGoalBalance(
            goal: goal2,
            totalSavedAmount: 300_000,
            totalWithdrawnAmount: 50000,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
        )

        context.insert(balance1)
        context.insert(balance2)
        try context.save()

        let results = try await repository.fetchAllBalances()
        #expect(results.count == 2)

        let goalIds = results.map(\.goalId)
        #expect(goalIds.contains(goal1.id))
        #expect(goalIds.contains(goal2.id))
    }
}
