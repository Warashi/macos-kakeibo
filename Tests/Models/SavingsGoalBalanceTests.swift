import Foundation
@testable import Kakeibo
import SwiftData
import Testing

@Suite("SwiftDataSavingsGoalBalance Tests")
internal struct SavingsGoalBalanceTests {
    private func sampleGoal() -> SwiftDataSavingsGoal {
        SwiftDataSavingsGoal(
            name: "緊急費用",
            targetAmount: 100_000,
            monthlySavingAmount: 10000,
            categoryId: nil,
            notes: nil,
            startDate: Date(),
            targetDate: nil,
            isActive: true,
        )
    }

    @Test("貯蓄残高を初期化できる")
    internal func initializeBalance() {
        let goal = sampleGoal()
        let balance = SwiftDataSavingsGoalBalance(
            goal: goal,
            totalSavedAmount: 50000,
            totalWithdrawnAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
        )

        #expect(balance.goal === goal)
        #expect(balance.totalSavedAmount == 50000)
        #expect(balance.totalWithdrawnAmount == 0)
        #expect(balance.balance == 50000)
        #expect(balance.lastUpdatedYear == 2025)
        #expect(balance.lastUpdatedMonth == 11)
    }

    @Test("残高は累計積立額から累計引出額を差し引いて計算される")
    internal func balanceCalculation() {
        let goal = sampleGoal()
        let balance = SwiftDataSavingsGoalBalance(
            goal: goal,
            totalSavedAmount: 120_000,
            totalWithdrawnAmount: 50000,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
        )

        #expect(balance.balance == 70000)
    }

    @Test("残高がマイナスの場合、不足フラグが立つ")
    internal func insufficientBalanceDetection() {
        let goal = sampleGoal()
        let balance = SwiftDataSavingsGoalBalance(
            goal: goal,
            totalSavedAmount: 30000,
            totalWithdrawnAmount: 50000,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
        )

        #expect(balance.balance == -20000)
        #expect(balance.isBalanceInsufficient)
    }

    @Test("残高がプラスの場合、不足フラグは立たない")
    internal func sufficientBalance() {
        let goal = sampleGoal()
        let balance = SwiftDataSavingsGoalBalance(
            goal: goal,
            totalSavedAmount: 100_000,
            totalWithdrawnAmount: 30000,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
        )

        #expect(balance.balance == 70000)
        #expect(!balance.isBalanceInsufficient)
    }

    @Test("最終更新年月の文字列表現が正しい")
    internal func yearMonthStringFormat() {
        let goal = sampleGoal()
        let balance = SwiftDataSavingsGoalBalance(
            goal: goal,
            totalSavedAmount: 10000,
            totalWithdrawnAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 3,
        )

        #expect(balance.lastUpdatedYearMonthString == "2025-03")
    }

    @Test("累計積立額がマイナスの場合バリデーションエラーになる")
    internal func validateNegativeSavedAmount() {
        let goal = sampleGoal()
        let balance = SwiftDataSavingsGoalBalance(
            goal: goal,
            totalSavedAmount: -1000,
            totalWithdrawnAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
        )

        let errors = balance.validate()
        #expect(errors.contains { $0.contains("累計積立額は0以上") })
        #expect(!balance.isValid)
    }

    @Test("累計引出額がマイナスの場合バリデーションエラーになる")
    internal func validateNegativeWithdrawnAmount() {
        let goal = sampleGoal()
        let balance = SwiftDataSavingsGoalBalance(
            goal: goal,
            totalSavedAmount: 10000,
            totalWithdrawnAmount: -5000,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
        )

        let errors = balance.validate()
        #expect(errors.contains { $0.contains("累計引出額は0以上") })
        #expect(!balance.isValid)
    }

    @Test("不正な年月はバリデーションエラーになる")
    internal func validateInvalidYearMonth() {
        let goal = sampleGoal()
        let balance1 = SwiftDataSavingsGoalBalance(
            goal: goal,
            totalSavedAmount: 10000,
            totalWithdrawnAmount: 0,
            lastUpdatedYear: 1999,
            lastUpdatedMonth: 11,
        )

        let errors1 = balance1.validate()
        #expect(errors1.contains { $0.contains("最終更新年が不正") })
        #expect(!balance1.isValid)

        let balance2 = SwiftDataSavingsGoalBalance(
            goal: goal,
            totalSavedAmount: 10000,
            totalWithdrawnAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 13,
        )

        let errors2 = balance2.validate()
        #expect(errors2.contains { $0.contains("最終更新月が不正") })
        #expect(!balance2.isValid)
    }

    @Test("有効なデータはバリデーションを通過する")
    internal func validateValidBalance() {
        let goal = sampleGoal()
        let balance = SwiftDataSavingsGoalBalance(
            goal: goal,
            totalSavedAmount: 120_000,
            totalWithdrawnAmount: 50000,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
        )

        #expect(balance.validate().isEmpty)
        #expect(balance.isValid)
    }

    @Test("インメモリModelContainerに保存して取得できる")
    internal func persistUsingInMemoryContainer() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let goal = sampleGoal()
        let balance = SwiftDataSavingsGoalBalance(
            goal: goal,
            totalSavedAmount: 60000,
            totalWithdrawnAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 11,
        )

        context.insert(goal)
        context.insert(balance)

        try context.save()

        let descriptor: ModelFetchRequest<SwiftDataSavingsGoalBalance> = ModelFetchFactory.make()
        let storedBalances = try context.fetch(descriptor)

        #expect(storedBalances.count == 1)
        let storedBalance = try #require(storedBalances.first)
        #expect(storedBalance.totalSavedAmount == 60000)
        #expect(storedBalance.balance == 60000)
        #expect(storedBalance.goal.name == "緊急費用")
    }

    @Test("積立と引出を繰り返すシナリオ")
    internal func savingsAndWithdrawalScenario() {
        let goal = sampleGoal()
        let balance = SwiftDataSavingsGoalBalance(
            goal: goal,
            totalSavedAmount: 0,
            totalWithdrawnAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 1,
        )

        // 12ヶ月積立（月10000円）
        for _ in 1 ... 12 {
            balance.totalSavedAmount = balance.totalSavedAmount.safeAdd(10000)
        }
        #expect(balance.balance == 120_000)

        // 1回目の引出（50000円）
        balance.totalWithdrawnAmount = balance.totalWithdrawnAmount.safeAdd(50000)
        #expect(balance.balance == 70000)

        // さらに12ヶ月積立
        for _ in 1 ... 12 {
            balance.totalSavedAmount = balance.totalSavedAmount.safeAdd(10000)
        }
        #expect(balance.balance == 190_000)

        // 2回目の引出（100000円）
        balance.totalWithdrawnAmount = balance.totalWithdrawnAmount.safeAdd(100_000)
        #expect(balance.balance == 90000)

        #expect(balance.totalSavedAmount == 240_000)
        #expect(balance.totalWithdrawnAmount == 150_000)
    }
}
