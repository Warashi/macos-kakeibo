import Foundation
import SwiftData

@ModelActor
internal actor SwiftDataSavingsGoalBalanceRepository: SavingsGoalBalanceRepository {
    private var context: ModelContext { modelContext }

    internal func fetchBalance(forGoalId goalId: UUID) async throws -> SavingsGoalBalance? {
        let descriptor = FetchDescriptor<SwiftDataSavingsGoalBalance>(
            predicate: #Predicate { $0.goal.id == goalId },
        )
        return try context.fetch(descriptor).first.map { SavingsGoalBalance(from: $0) }
    }

    internal func fetchAllBalances() async throws -> [SavingsGoalBalance] {
        let descriptor = FetchDescriptor<SwiftDataSavingsGoalBalance>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)],
        )
        let balances = try context.fetch(descriptor)
        return balances.map { SavingsGoalBalance(from: $0) }
    }

    @discardableResult
    internal func observeBalances(
        onChange: @escaping @Sendable ([SavingsGoalBalance]) -> Void,
    ) async throws -> ObservationHandle {
        let descriptor = FetchDescriptor<SwiftDataSavingsGoalBalance>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)],
        )
        return context.observe(
            descriptor: descriptor,
            transform: { balances in
                balances.map { SavingsGoalBalance(from: $0) }
            },
            onChange: onChange,
        )
    }
}
