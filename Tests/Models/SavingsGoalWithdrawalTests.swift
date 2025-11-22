import Foundation
@testable import Kakeibo
import SwiftData
import Testing

@Suite("SwiftDataSavingsGoalWithdrawal Tests")
internal struct SavingsGoalWithdrawalTests {
    private func sampleGoal() -> SwiftDataSavingsGoal {
        SwiftDataSavingsGoal(
            name: "緊急費用",
            targetAmount: 100_000,
            monthlySavingAmount: 10_000,
            categoryId: nil,
            notes: nil,
            startDate: Date(),
            targetDate: nil,
            isActive: true,
        )
    }

    @Test("貯蓄引出を初期化できる")
    internal func initializeWithdrawal() {
        let goal = sampleGoal()
        let withdrawal = SwiftDataSavingsGoalWithdrawal(
            goal: goal,
            amount: 30000,
            withdrawalDate: Date(),
            purpose: "医療費",
            transaction: nil,
        )

        #expect(withdrawal.goal === goal)
        #expect(withdrawal.amount == 30000)
        #expect(withdrawal.purpose == "医療費")
        #expect(withdrawal.transaction == nil)
    }

    @Test("引出額が0以下の場合はバリデーションエラー")
    internal func validateZeroAmount() {
        let goal = sampleGoal()
        let withdrawal = SwiftDataSavingsGoalWithdrawal(
            goal: goal,
            amount: 0,
            withdrawalDate: Date(),
            purpose: nil,
            transaction: nil,
        )

        let errors = withdrawal.validate()
        #expect(errors.contains { $0.contains("引出額は0より大きい必要があります") })
        #expect(!withdrawal.isValid)
    }

    @Test("引出額が負の場合はバリデーションエラー")
    internal func validateNegativeAmount() {
        let goal = sampleGoal()
        let withdrawal = SwiftDataSavingsGoalWithdrawal(
            goal: goal,
            amount: -10000,
            withdrawalDate: Date(),
            purpose: nil,
            transaction: nil,
        )

        let errors = withdrawal.validate()
        #expect(errors.contains { $0.contains("引出額は0より大きい必要があります") })
        #expect(!withdrawal.isValid)
    }

    @Test("有効なデータはバリデーションを通過する")
    internal func validateValidWithdrawal() {
        let goal = sampleGoal()
        let withdrawal = SwiftDataSavingsGoalWithdrawal(
            goal: goal,
            amount: 50000,
            withdrawalDate: Date(),
            purpose: "医療費",
            transaction: nil,
        )

        #expect(withdrawal.validate().isEmpty)
        #expect(withdrawal.isValid)
    }

    @Test("目的なしでも有効")
    internal func validWithoutPurpose() {
        let goal = sampleGoal()
        let withdrawal = SwiftDataSavingsGoalWithdrawal(
            goal: goal,
            amount: 20000,
            withdrawalDate: Date(),
            purpose: nil,
            transaction: nil,
        )

        #expect(withdrawal.isValid)
        #expect(withdrawal.validate().isEmpty)
        #expect(withdrawal.purpose == nil)
    }

    @Test("インメモリModelContainerに保存して取得できる")
    internal func persistUsingInMemoryContainer() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let goal = sampleGoal()
        let withdrawal = SwiftDataSavingsGoalWithdrawal(
            goal: goal,
            amount: 40000,
            withdrawalDate: Date(),
            purpose: "車修理",
            transaction: nil,
        )

        context.insert(goal)
        context.insert(withdrawal)

        try context.save()

        let descriptor: ModelFetchRequest<SwiftDataSavingsGoalWithdrawal> = ModelFetchFactory.make()
        let storedWithdrawals = try context.fetch(descriptor)

        #expect(storedWithdrawals.count == 1)
        let storedWithdrawal = try #require(storedWithdrawals.first)
        #expect(storedWithdrawal.amount == 40000)
        #expect(storedWithdrawal.purpose == "車修理")
        #expect(storedWithdrawal.goal?.name == "緊急費用")
    }

    @Test("複数の引出を記録できる")
    internal func multipleWithdrawals() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let goal = sampleGoal()
        context.insert(goal)

        let withdrawal1 = SwiftDataSavingsGoalWithdrawal(
            goal: goal,
            amount: 20000,
            withdrawalDate: Date(),
            purpose: "医療費",
            transaction: nil,
        )
        let withdrawal2 = SwiftDataSavingsGoalWithdrawal(
            goal: goal,
            amount: 30000,
            withdrawalDate: Calendar.current.date(byAdding: .day, value: 10, to: Date())!,
            purpose: "車修理",
            transaction: nil,
        )

        context.insert(withdrawal1)
        context.insert(withdrawal2)

        try context.save()

        let descriptor: ModelFetchRequest<SwiftDataSavingsGoalWithdrawal> = ModelFetchFactory.make()
        let storedWithdrawals = try context.fetch(descriptor)

        #expect(storedWithdrawals.count == 2)
        let totalWithdrawn = storedWithdrawals.reduce(Decimal(0)) { $0.safeAdd($1.amount) }
        #expect(totalWithdrawn == 50000)
    }
}
