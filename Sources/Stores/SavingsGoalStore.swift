import Foundation
import Observation

/// 貯蓄目標管理ストア
///
/// 貯蓄目標の作成、更新、削除、一覧表示を管理します。
@MainActor
@Observable
internal final class SavingsGoalStore {
    // MARK: - Dependencies

    private let repository: SavingsGoalRepository
    private let balanceRepository: SavingsGoalBalanceRepository
    private let withdrawalRepository: SavingsGoalWithdrawalRepository

    @ObservationIgnored
    private var goalsHandle: ObservationHandle?

    @ObservationIgnored
    private var balancesHandle: ObservationHandle?

    // MARK: - State

    /// 貯蓄目標エントリ一覧
    internal private(set) var entries: [SavingsGoalListEntry] = []

    /// 貯蓄目標一覧（内部用）
    @ObservationIgnored
    private var goals: [SavingsGoal] = []

    /// 残高一覧（内部用）
    @ObservationIgnored
    private var balances: [SavingsGoalBalance] = []

    /// 選択中の貯蓄目標
    internal var selectedGoal: SavingsGoal?

    /// フォーム入力状態
    internal var formInput: SavingsGoalFormInput = SavingsGoalFormInput()

    /// フォーム表示フラグ
    internal var isShowingForm: Bool = false

    // MARK: - Initialization

    internal init(
        repository: SavingsGoalRepository,
        balanceRepository: SavingsGoalBalanceRepository,
        withdrawalRepository: SavingsGoalWithdrawalRepository
    ) {
        self.repository = repository
        self.balanceRepository = balanceRepository
        self.withdrawalRepository = withdrawalRepository
    }

    deinit {
        goalsHandle?.cancel()
        balancesHandle?.cancel()
    }

    // MARK: - Actions

    /// 貯蓄目標の監視を開始
    internal func observeGoals() async {
        goalsHandle?.cancel()
        balancesHandle?.cancel()

        do {
            // 貯蓄目標を監視
            let goalsHandleResult = try await repository.observeGoals { [weak self] goals in
                Task { @MainActor in
                    self?.goals = goals
                    self?.updateEntries()
                }
            }
            goalsHandle = goalsHandleResult

            // 残高を監視
            let balancesHandleResult = try await balanceRepository.observeBalances { [weak self] balances in
                Task { @MainActor in
                    self?.balances = balances
                    self?.updateEntries()
                }
            }
            balancesHandle = balancesHandleResult
        } catch {
            goals = []
            balances = []
            entries = []
        }
    }

    /// goalsとbalancesを結合してentriesを更新
    private func updateEntries() {
        // balancesをgoalId でマッピング
        let balanceMap = Dictionary(uniqueKeysWithValues: balances.map { ($0.goalId, $0) })

        // goalsとbalancesを結合してエントリを作成
        entries = goals.map { goal in
            SavingsGoalListEntry(goal: goal, balance: balanceMap[goal.id])
        }
    }

    /// 新規貯蓄目標を作成
    internal func createGoal() async throws {
        let validationErrors = formInput.validate()
        guard validationErrors.isEmpty else {
            throw SavingsGoalStoreError.validationFailed(validationErrors)
        }

        let input = SavingsGoalInput(
            name: formInput.name,
            targetAmount: formInput.targetAmount,
            monthlySavingAmount: formInput.monthlySavingAmount,
            categoryId: formInput.categoryId,
            notes: formInput.notes,
            startDate: formInput.startDate,
            targetDate: formInput.targetDate
        )

        _ = try await repository.createGoal(input)
        resetForm()
    }

    /// 貯蓄目標を更新
    internal func updateGoal(_ goalId: UUID) async throws {
        let validationErrors = formInput.validate()
        guard validationErrors.isEmpty else {
            throw SavingsGoalStoreError.validationFailed(validationErrors)
        }

        let input = SavingsGoalInput(
            name: formInput.name,
            targetAmount: formInput.targetAmount,
            monthlySavingAmount: formInput.monthlySavingAmount,
            categoryId: formInput.categoryId,
            notes: formInput.notes,
            startDate: formInput.startDate,
            targetDate: formInput.targetDate
        )

        let updateInput = SavingsGoalUpdateInput(id: goalId, input: input)
        _ = try await repository.updateGoal(updateInput)
        resetForm()
    }

    /// 貯蓄目標を削除
    internal func deleteGoal(_ goalId: UUID) async throws {
        try await repository.deleteGoal(goalId)
    }

    /// 貯蓄目標の有効/無効を切り替え
    internal func toggleGoalActive(_ goalId: UUID) async throws {
        try await repository.toggleGoalActive(goalId)
    }

    /// 引出を記録
    internal func recordWithdrawal(params: WithdrawalParameters) async throws {
        let input = SavingsGoalWithdrawalInput(
            goalId: params.goalId,
            amount: params.amount,
            withdrawalDate: params.withdrawalDate,
            purpose: params.purpose,
            transactionId: params.transactionId
        )
        _ = try await withdrawalRepository.createWithdrawal(input)
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
            targetDate: goal.targetDate
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
