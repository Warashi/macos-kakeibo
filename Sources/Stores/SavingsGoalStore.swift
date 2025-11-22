import Foundation
import Observation
import SwiftData

/// 貯蓄目標管理ストア
///
/// 貯蓄目標の作成、更新、削除、一覧表示を管理します。
@MainActor
@Observable
internal final class SavingsGoalStore {
    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let balanceService: SavingsGoalBalanceService

    // MARK: - State

    /// 貯蓄目標一覧
    internal private(set) var goals: [SavingsGoal] = []

    /// 選択中の貯蓄目標
    internal var selectedGoal: SavingsGoal?

    /// フォーム入力状態
    internal var formInput: SavingsGoalFormInput = SavingsGoalFormInput()

    /// フォーム表示フラグ
    internal var isShowingForm: Bool = false

    // MARK: - Initialization

    internal init(
        modelContext: ModelContext,
        balanceService: SavingsGoalBalanceService = SavingsGoalBalanceService(),
    ) {
        self.modelContext = modelContext
        self.balanceService = balanceService
    }

    // MARK: - Actions

    /// 貯蓄目標一覧を読み込み
    internal func loadGoals() {
        let descriptor = FetchDescriptor<SwiftDataSavingsGoal>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)],
        )

        do {
            let swiftDataGoals = try modelContext.fetch(descriptor)
            goals = swiftDataGoals.map { $0.toDomain() }
        } catch {
            goals = []
        }
    }

    /// 新規貯蓄目標を作成
    internal func createGoal() throws {
        let validationErrors = formInput.validate()
        guard validationErrors.isEmpty else {
            throw SavingsGoalStoreError.validationFailed(validationErrors)
        }

        let newGoal = SwiftDataSavingsGoal(
            name: formInput.name,
            targetAmount: formInput.targetAmount,
            monthlySavingAmount: formInput.monthlySavingAmount,
            categoryId: formInput.categoryId,
            notes: formInput.notes,
            startDate: formInput.startDate,
            targetDate: formInput.targetDate,
            isActive: true,
        )

        modelContext.insert(newGoal)
        try modelContext.save()

        loadGoals()
        resetForm()
    }

    /// 貯蓄目標を更新
    internal func updateGoal(_ goalId: UUID) throws {
        let descriptor = FetchDescriptor<SwiftDataSavingsGoal>(
            predicate: #Predicate { $0.id == goalId },
        )

        guard let goal = try modelContext.fetch(descriptor).first else {
            throw SavingsGoalStoreError.goalNotFound
        }

        let validationErrors = formInput.validate()
        guard validationErrors.isEmpty else {
            throw SavingsGoalStoreError.validationFailed(validationErrors)
        }

        goal.name = formInput.name
        goal.targetAmount = formInput.targetAmount
        goal.monthlySavingAmount = formInput.monthlySavingAmount
        goal.categoryId = formInput.categoryId
        goal.notes = formInput.notes
        goal.startDate = formInput.startDate
        goal.targetDate = formInput.targetDate
        goal.updatedAt = Date()

        try modelContext.save()

        loadGoals()
        resetForm()
    }

    /// 貯蓄目標を削除
    internal func deleteGoal(_ goalId: UUID) throws {
        let descriptor = FetchDescriptor<SwiftDataSavingsGoal>(
            predicate: #Predicate { $0.id == goalId },
        )

        guard let goal = try modelContext.fetch(descriptor).first else {
            throw SavingsGoalStoreError.goalNotFound
        }

        modelContext.delete(goal)
        try modelContext.save()

        loadGoals()
    }

    /// 貯蓄目標の有効/無効を切り替え
    internal func toggleGoalActive(_ goalId: UUID) throws {
        let descriptor = FetchDescriptor<SwiftDataSavingsGoal>(
            predicate: #Predicate { $0.id == goalId },
        )

        guard let goal = try modelContext.fetch(descriptor).first else {
            throw SavingsGoalStoreError.goalNotFound
        }

        goal.isActive.toggle()
        goal.updatedAt = Date()
        try modelContext.save()

        loadGoals()
    }

    /// 引出を記録
    internal func recordWithdrawal(params: WithdrawalParameters) throws {
        let goalDescriptor = FetchDescriptor<SwiftDataSavingsGoal>(
            predicate: #Predicate { $0.id == params.goalId },
        )

        guard let goal = try modelContext.fetch(goalDescriptor).first else {
            throw SavingsGoalStoreError.goalNotFound
        }

        let withdrawal = SwiftDataSavingsGoalWithdrawal(
            goal: goal,
            amount: params.amount,
            withdrawalDate: params.withdrawalDate,
            purpose: params.purpose,
            transactionId: params.transactionId,
        )

        modelContext.insert(withdrawal)

        // 残高を更新
        if let balance = goal.balance {
            _ = balanceService.processWithdrawal(withdrawal: withdrawal, balance: balance)
        }

        try modelContext.save()
        loadGoals()
    }

    // MARK: - Form Management

    internal func prepareFormForCreate() {
        formInput = SavingsGoalFormInput()
        selectedGoal = nil
        isShowingForm = true
    }

    internal func prepareFormForEdit(_ goal: SavingsGoal) {
        formInput = SavingsGoalFormInput(
            name: goal.name,
            targetAmount: goal.targetAmount,
            monthlySavingAmount: goal.monthlySavingAmount,
            categoryId: goal.categoryId,
            notes: goal.notes,
            startDate: goal.startDate,
            targetDate: goal.targetDate,
        )
        selectedGoal = goal
        isShowingForm = true
    }

    internal func resetForm() {
        formInput = SavingsGoalFormInput()
        selectedGoal = nil
        isShowingForm = false
    }
}

// MARK: - Form Input

/// 貯蓄目標フォーム入力
internal struct SavingsGoalFormInput {
    internal var name: String = ""
    internal var targetAmount: Decimal?
    internal var monthlySavingAmount: Decimal = 0
    internal var categoryId: UUID?
    internal var notes: String?
    internal var startDate: Date = Date()
    internal var targetDate: Date?

    internal func validate() -> [String] {
        var errors: [String] = []

        if name.isEmpty {
            errors.append("名称は必須です")
        }
        if monthlySavingAmount < 0 {
            errors.append("月次積立額は0以上である必要があります")
        }
        if let targetAmount, targetAmount < 0 {
            errors.append("目標金額は0以上である必要があります")
        }
        if let targetDate, targetDate < startDate {
            errors.append("目標達成日は開始日以降である必要があります")
        }

        return errors
    }
}

// MARK: - Withdrawal Parameters

/// 引出パラメータ
internal struct WithdrawalParameters {
    internal let goalId: UUID
    internal let amount: Decimal
    internal let withdrawalDate: Date
    internal let purpose: String?
    internal let transactionId: UUID?
}

// MARK: - Errors

/// 貯蓄目標ストアエラー
internal enum SavingsGoalStoreError: Error {
    case goalNotFound
    case validationFailed([String])
}
