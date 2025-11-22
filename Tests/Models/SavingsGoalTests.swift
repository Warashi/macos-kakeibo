import Foundation
@testable import Kakeibo
import SwiftData
import Testing

@Suite("SwiftDataSavingsGoal Tests")
internal struct SavingsGoalTests {
    @Test("正常な貯蓄目標を作成できる")
    internal func validSavingsGoal() {
        let goal = SwiftDataSavingsGoal(
            name: "緊急費用",
            targetAmount: 100_000,
            monthlySavingAmount: 10000,
            categoryId: nil,
            notes: "万が一のため",
            startDate: Date(),
            targetDate: nil,
            isActive: true,
        )

        #expect(goal.name == "緊急費用")
        #expect(goal.targetAmount == 100_000)
        #expect(goal.monthlySavingAmount == 10000)
        #expect(goal.isActive)
        #expect(goal.hasTargetAmount)
        #expect(!goal.hasTargetDate)
        #expect(goal.isValid)
        #expect(goal.validate().isEmpty)
    }

    @Test("名称が空の場合はバリデーションエラー")
    internal func emptyNameValidation() {
        let goal = SwiftDataSavingsGoal(
            name: "",
            targetAmount: nil,
            monthlySavingAmount: 10000,
            categoryId: nil,
            notes: nil,
            startDate: Date(),
            targetDate: nil,
            isActive: true,
        )

        #expect(!goal.isValid)
        #expect(goal.validate().contains { $0.contains("名称は必須です") })
    }

    @Test("月次積立額が負の場合はバリデーションエラー")
    internal func negativeMonthlySavingValidation() {
        let goal = SwiftDataSavingsGoal(
            name: "旅行",
            targetAmount: 500_000,
            monthlySavingAmount: -5000,
            categoryId: nil,
            notes: nil,
            startDate: Date(),
            targetDate: nil,
            isActive: true,
        )

        #expect(!goal.isValid)
        #expect(goal.validate().contains { $0.contains("月次積立額は0以上である必要があります") })
    }

    @Test("目標金額が負の場合はバリデーションエラー")
    internal func negativeTargetAmountValidation() {
        let goal = SwiftDataSavingsGoal(
            name: "旅行",
            targetAmount: -100_000,
            monthlySavingAmount: 10000,
            categoryId: nil,
            notes: nil,
            startDate: Date(),
            targetDate: nil,
            isActive: true,
        )

        #expect(!goal.isValid)
        #expect(goal.validate().contains { $0.contains("目標金額は0以上である必要があります") })
    }

    @Test("目標達成日が開始日より前の場合はバリデーションエラー")
    internal func invalidTargetDateValidation() {
        let startDate = Date()
        guard let targetDate = Calendar.current.date(byAdding: .day, value: -1, to: startDate) else {
            Issue.record("Failed to create target date")
            return
        }

        let goal = SwiftDataSavingsGoal(
            name: "旅行",
            targetAmount: 500_000,
            monthlySavingAmount: 50000,
            categoryId: nil,
            notes: nil,
            startDate: startDate,
            targetDate: targetDate,
            isActive: true,
        )

        #expect(!goal.isValid)
        #expect(goal.validate().contains { $0.contains("目標達成日は開始日以降である必要があります") })
    }

    @Test("目標達成日が開始日と同じか未来の場合は有効")
    internal func validTargetDate() {
        let startDate = Date()
        guard let targetDate = Calendar.current.date(byAdding: .month, value: 12, to: startDate) else {
            Issue.record("Failed to create target date")
            return
        }

        let goal = SwiftDataSavingsGoal(
            name: "旅行",
            targetAmount: 500_000,
            monthlySavingAmount: 50000,
            categoryId: nil,
            notes: "夏の旅行",
            startDate: startDate,
            targetDate: targetDate,
            isActive: true,
        )

        #expect(goal.isValid)
        #expect(goal.validate().isEmpty)
        #expect(goal.hasTargetDate)
    }

    @Test("目標金額なしでも有効")
    internal func validWithoutTargetAmount() {
        let goal = SwiftDataSavingsGoal(
            name: "積立",
            targetAmount: nil,
            monthlySavingAmount: 20000,
            categoryId: nil,
            notes: nil,
            startDate: Date(),
            targetDate: nil,
            isActive: true,
        )

        #expect(goal.isValid)
        #expect(goal.validate().isEmpty)
        #expect(!goal.hasTargetAmount)
    }

    @Test("インメモリModelContainerに保存して取得できる")
    internal func persistUsingInMemoryContainer() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let goal = SwiftDataSavingsGoal(
            name: "緊急費用",
            targetAmount: 100_000,
            monthlySavingAmount: 10000,
            categoryId: nil,
            notes: "万が一のため",
            startDate: Date(),
            targetDate: nil,
            isActive: true,
        )

        context.insert(goal)
        try context.save()

        let descriptor: ModelFetchRequest<SwiftDataSavingsGoal> = ModelFetchFactory.make()
        let storedGoals = try context.fetch(descriptor)

        #expect(storedGoals.count == 1)
        let storedGoal = try #require(storedGoals.first)
        #expect(storedGoal.name == "緊急費用")
        #expect(storedGoal.targetAmount == 100_000)
        #expect(storedGoal.monthlySavingAmount == 10000)
    }

    @Test("非アクティブな貯蓄目標を作成できる")
    internal func inactiveGoal() {
        let goal = SwiftDataSavingsGoal(
            name: "達成済み",
            targetAmount: 1_000_000,
            monthlySavingAmount: 0,
            categoryId: nil,
            notes: nil,
            startDate: Date(),
            targetDate: nil,
            isActive: false,
        )

        #expect(!goal.isActive)
        #expect(goal.isValid)
    }
}
