import Foundation
import SwiftData

@ModelActor
internal actor SwiftDataSavingsGoalWithdrawalRepository: SavingsGoalWithdrawalRepository {
    private var context: ModelContext { modelContext }

    internal func createWithdrawal(_ input: SavingsGoalWithdrawalInput) async throws -> SavingsGoalWithdrawal {
        let goalId = input.goalId
        let transactionId = input.transactionId

        // 貯蓄目標を取得
        let goalDescriptor = FetchDescriptor<SwiftDataSavingsGoal>(
            predicate: #Predicate { $0.id == goalId },
        )
        guard let goal = try context.fetch(goalDescriptor).first else {
            throw RepositoryError.notFound
        }

        // トランザクションを取得（存在する場合）
        var transaction: SwiftDataTransaction?
        if let transactionId {
            let transactionDescriptor = FetchDescriptor<SwiftDataTransaction>(
                predicate: #Predicate { $0.id == transactionId },
            )
            transaction = try context.fetch(transactionDescriptor).first
        }

        // 引出記録を作成
        let withdrawal = SwiftDataSavingsGoalWithdrawal(
            goal: goal,
            amount: input.amount,
            withdrawalDate: input.withdrawalDate,
            purpose: input.purpose,
            transaction: transaction,
        )
        context.insert(withdrawal)

        // 残高を更新
        try await updateBalanceAfterWithdrawal(goalId: input.goalId, withdrawalAmount: input.amount)

        try context.save()
        return SavingsGoalWithdrawal(from: withdrawal)
    }

    internal func fetchWithdrawals(forGoalId goalId: UUID) async throws -> [SavingsGoalWithdrawal] {
        let descriptor = FetchDescriptor<SwiftDataSavingsGoalWithdrawal>(
            predicate: #Predicate { $0.goalId == goalId },
            sortBy: [SortDescriptor(\.withdrawalDate, order: .reverse)],
        )
        let withdrawals = try context.fetch(descriptor)
        return withdrawals.map { SavingsGoalWithdrawal(from: $0) }
    }

    internal func fetchAllWithdrawals() async throws -> [SavingsGoalWithdrawal] {
        let descriptor = FetchDescriptor<SwiftDataSavingsGoalWithdrawal>(
            sortBy: [SortDescriptor(\.withdrawalDate, order: .reverse)],
        )
        let withdrawals = try context.fetch(descriptor)
        return withdrawals.map { SavingsGoalWithdrawal(from: $0) }
    }

    internal func deleteWithdrawal(_ id: UUID) async throws {
        let descriptor = FetchDescriptor<SwiftDataSavingsGoalWithdrawal>(
            predicate: #Predicate { $0.id == id },
        )

        guard let withdrawal = try context.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }

        let goalId = withdrawal.goalId
        let amount = withdrawal.amount

        context.delete(withdrawal)

        // 残高を更新（引出額を減算）
        try await updateBalanceAfterWithdrawalDeletion(goalId: goalId, withdrawalAmount: amount)

        try context.save()
    }

    @discardableResult
    internal func observeWithdrawals(
        onChange: @escaping @Sendable ([SavingsGoalWithdrawal]) -> Void,
    ) async throws -> ObservationHandle {
        let descriptor = FetchDescriptor<SwiftDataSavingsGoalWithdrawal>(
            sortBy: [SortDescriptor(\.withdrawalDate, order: .reverse)],
        )
        return context.observe(
            descriptor: descriptor,
            transform: { withdrawals in
                withdrawals.map { SavingsGoalWithdrawal(from: $0) }
            },
            onChange: onChange,
        )
    }

    // MARK: - Private Helper Methods

    private func updateBalanceAfterWithdrawal(goalId: UUID, withdrawalAmount: Decimal) async throws {
        let balanceDescriptor = FetchDescriptor<SwiftDataSavingsGoalBalance>(
            predicate: #Predicate { $0.goal.id == goalId },
        )

        if let balance = try context.fetch(balanceDescriptor).first {
            balance.totalWithdrawnAmount = balance.totalWithdrawnAmount.safeAdd(withdrawalAmount)
            balance.updatedAt = Date()
        }
    }

    private func updateBalanceAfterWithdrawalDeletion(goalId: UUID, withdrawalAmount: Decimal) async throws {
        let balanceDescriptor = FetchDescriptor<SwiftDataSavingsGoalBalance>(
            predicate: #Predicate { $0.goal.id == goalId },
        )

        if let balance = try context.fetch(balanceDescriptor).first {
            balance.totalWithdrawnAmount = balance.totalWithdrawnAmount.safeSubtract(withdrawalAmount)
            balance.updatedAt = Date()
        }
    }
}
