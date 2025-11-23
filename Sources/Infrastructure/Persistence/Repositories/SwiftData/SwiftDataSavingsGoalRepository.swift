import Foundation
import SwiftData

@ModelActor
internal actor SwiftDataSavingsGoalRepository: SavingsGoalRepository {
    private var context: ModelContext { modelContext }

    internal func createGoal(_ input: SavingsGoalInput) async throws -> SavingsGoal {
        let goal = SwiftDataSavingsGoal(
            name: input.name,
            targetAmount: input.targetAmount,
            monthlySavingAmount: input.monthlySavingAmount,
            categoryId: input.categoryId,
            notes: input.notes,
            startDate: input.startDate,
            targetDate: input.targetDate,
            isActive: true
        )
        context.insert(goal)
        try await saveChanges()
        return SavingsGoal(from: goal)
    }

    internal func updateGoal(_ input: SavingsGoalUpdateInput) async throws -> SavingsGoal {
        let goalId = input.id
        let descriptor = FetchDescriptor<SwiftDataSavingsGoal>(
            predicate: #Predicate { $0.id == goalId }
        )

        guard let goal = try context.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }

        goal.name = input.input.name
        goal.targetAmount = input.input.targetAmount
        goal.monthlySavingAmount = input.input.monthlySavingAmount
        goal.categoryId = input.input.categoryId
        goal.notes = input.input.notes
        goal.startDate = input.input.startDate
        goal.targetDate = input.input.targetDate
        goal.updatedAt = Date()

        try await saveChanges()
        return SavingsGoal(from: goal)
    }

    internal func deleteGoal(_ id: UUID) async throws {
        let descriptor = FetchDescriptor<SwiftDataSavingsGoal>(
            predicate: #Predicate { $0.id == id }
        )

        guard let goal = try context.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }

        context.delete(goal)
        try await saveChanges()
    }

    internal func fetchAllGoals() async throws -> [SavingsGoal] {
        let descriptor = FetchDescriptor<SwiftDataSavingsGoal>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let goals = try context.fetch(descriptor)
        return goals.map { SavingsGoal(from: $0) }
    }

    internal func fetchGoal(id: UUID) async throws -> SavingsGoal? {
        let descriptor = FetchDescriptor<SwiftDataSavingsGoal>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first.map { SavingsGoal(from: $0) }
    }

    internal func toggleGoalActive(_ id: UUID) async throws {
        let descriptor = FetchDescriptor<SwiftDataSavingsGoal>(
            predicate: #Predicate { $0.id == id }
        )

        guard let goal = try context.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }

        goal.isActive.toggle()
        goal.updatedAt = Date()
        try await saveChanges()
    }

    @discardableResult
    internal func observeGoals(
        onChange: @escaping @Sendable ([SavingsGoal]) -> Void
    ) async throws -> ObservationHandle {
        let descriptor = FetchDescriptor<SwiftDataSavingsGoal>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return context.observe(
            descriptor: descriptor,
            transform: { goals in
                goals.map { SavingsGoal(from: $0) }
            },
            onChange: onChange
        )
    }

    internal func saveChanges() async throws {
        try context.save()
    }
}
