import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite("SavingsGoalStore Tests")
@MainActor
internal struct SavingsGoalStoreTests {
    @Test("貯蓄目標を作成できる")
    func 貯蓄目標を作成できる() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let store = SavingsGoalStore(modelContext: context)

        store.formInput = SavingsGoalFormInput(
            name: "緊急費用",
            targetAmount: 100_000,
            monthlySavingAmount: 10000,
            categoryId: nil,
            notes: "万が一のため",
            startDate: Date(),
            targetDate: nil,
        )

        try store.createGoal()

        let descriptor = FetchDescriptor<SwiftDataSavingsGoal>()
        let goals = try context.fetch(descriptor)

        #expect(goals.count == 1)
        #expect(goals[0].name == "緊急費用")
        #expect(goals[0].monthlySavingAmount == 10000)
        #expect(goals[0].targetAmount == 100_000)
        #expect(goals[0].isActive == true)
        #expect(store.isShowingForm == false)
    }

    @Test("貯蓄目標を更新できる")
    func 貯蓄目標を更新できる() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let goal = SwiftDataSavingsGoal(
            name: "旅行費用",
            targetAmount: 50000,
            monthlySavingAmount: 5000,
            categoryId: nil,
            notes: nil,
            startDate: Date(),
            targetDate: nil,
            isActive: true,
        )
        context.insert(goal)
        try context.save()

        let store = SavingsGoalStore(modelContext: context)

        store.formInput = SavingsGoalFormInput(
            name: "海外旅行費用",
            targetAmount: 100_000,
            monthlySavingAmount: 10000,
            categoryId: nil,
            notes: "ヨーロッパ旅行",
            startDate: Date(),
            targetDate: nil,
        )

        try store.updateGoal(goal.id)

        let goalId = goal.id
        let descriptor = FetchDescriptor<SwiftDataSavingsGoal>(
            predicate: #Predicate { $0.id == goalId },
        )
        let updatedGoal = try context.fetch(descriptor).first

        #expect(updatedGoal?.name == "海外旅行費用")
        #expect(updatedGoal?.monthlySavingAmount == 10000)
        #expect(updatedGoal?.targetAmount == 100_000)
        #expect(updatedGoal?.notes == "ヨーロッパ旅行")
    }

    @Test("貯蓄目標を削除できる")
    func 貯蓄目標を削除できる() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let goal = SwiftDataSavingsGoal(
            name: "削除テスト",
            targetAmount: nil,
            monthlySavingAmount: 1000,
            categoryId: nil,
            notes: nil,
            startDate: Date(),
            targetDate: nil,
            isActive: true,
        )
        context.insert(goal)
        try context.save()

        let store = SavingsGoalStore(modelContext: context)

        try store.deleteGoal(goal.id)

        let goalId = goal.id
        let descriptor = FetchDescriptor<SwiftDataSavingsGoal>(
            predicate: #Predicate { $0.id == goalId },
        )
        let deletedGoal = try context.fetch(descriptor).first

        #expect(deletedGoal == nil)
    }

    @Test("貯蓄目標の有効/無効を切り替えられる")
    func 貯蓄目標の有効無効を切り替えられる() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let goal = SwiftDataSavingsGoal(
            name: "有効/無効テスト",
            targetAmount: nil,
            monthlySavingAmount: 1000,
            categoryId: nil,
            notes: nil,
            startDate: Date(),
            targetDate: nil,
            isActive: true,
        )
        context.insert(goal)
        try context.save()

        let store = SavingsGoalStore(modelContext: context)

        #expect(goal.isActive == true)

        try store.toggleGoalActive(goal.id)

        #expect(goal.isActive == false)

        try store.toggleGoalActive(goal.id)

        #expect(goal.isActive == true)
    }

    @Test("バリデーションエラーが正しく動作する")
    func バリデーションエラーが正しく動作する() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let store = SavingsGoalStore(modelContext: context)

        store.formInput = SavingsGoalFormInput(
            name: "",
            targetAmount: nil,
            monthlySavingAmount: -100,
            categoryId: nil,
            notes: nil,
            startDate: Date(),
            targetDate: nil,
        )

        do {
            try store.createGoal()
            Issue.record("バリデーションエラーが発生すべき")
        } catch let error as SavingsGoalStoreError {
            guard case let .validationFailed(errors) = error else {
                Issue.record("期待されるエラー型ではありません")
                return
            }
            #expect(errors.contains("名称は必須です"))
            #expect(errors.contains("月次積立額は0以上である必要があります"))
        }
    }

    @Test("目標金額と目標達成日のバリデーション")
    func 目標金額と目標達成日のバリデーション() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let store = SavingsGoalStore(modelContext: context)

        let startDate = Date()
        let targetDate = Calendar.current.date(byAdding: .day, value: -1, to: startDate)!

        store.formInput = SavingsGoalFormInput(
            name: "テスト",
            targetAmount: -50000,
            monthlySavingAmount: 5000,
            categoryId: nil,
            notes: nil,
            startDate: startDate,
            targetDate: targetDate,
        )

        do {
            try store.createGoal()
            Issue.record("バリデーションエラーが発生すべき")
        } catch let error as SavingsGoalStoreError {
            guard case let .validationFailed(errors) = error else {
                Issue.record("期待されるエラー型ではありません")
                return
            }
            #expect(errors.contains("目標金額は0以上である必要があります"))
            #expect(errors.contains("目標達成日は開始日以降である必要があります"))
        }
    }
}
