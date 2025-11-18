import Foundation
import SwiftData

/// 予算スタックの依存関係
internal struct BudgetStackDependencies {
    internal let repository: BudgetRepository
    internal let monthlyUseCase: MonthlyBudgetUseCaseProtocol
    internal let annualUseCase: AnnualBudgetUseCaseProtocol
    internal let recurringPaymentUseCase: RecurringPaymentSavingsUseCaseProtocol
    internal let mutationUseCase: BudgetMutationUseCaseProtocol
}

/// BudgetStore 構築用のビルダー
///
/// Repository / UseCase の生成を一か所にまとめておくことで、
/// 将来的に `@ModelActor` へ切り替える際の変更範囲を限定する。
internal enum BudgetStackBuilder {
    /// BudgetStore に必要な依存を構築
    /// - Parameter modelContainer: SwiftData ModelContainer
    /// - Returns: Repository / UseCase のセット
    internal static func makeDependencies(modelContainer: ModelContainer) async -> BudgetStackDependencies {
        let repository = SwiftDataBudgetRepository(modelContainer: modelContainer)
        let monthlyUseCase = DefaultMonthlyBudgetUseCase()
        let annualUseCase = DefaultAnnualBudgetUseCase()
        let recurringPaymentUseCase = DefaultRecurringPaymentSavingsUseCase()
        let mutationUseCase = DefaultBudgetMutationUseCase(repository: repository)
        return BudgetStackDependencies(
            repository: repository,
            monthlyUseCase: monthlyUseCase,
            annualUseCase: annualUseCase,
            recurringPaymentUseCase: recurringPaymentUseCase,
            mutationUseCase: mutationUseCase,
        )
    }

    /// BudgetStore を構築
    /// - Parameter modelContainer: SwiftData ModelContainer
    /// - Returns: 初期化済み BudgetStore
    internal static func makeStore(modelContainer: ModelContainer) async -> BudgetStore {
        let dependencies = await makeDependencies(modelContainer: modelContainer)
        return await MainActor.run {
            BudgetStore(
                repository: dependencies.repository,
                monthlyUseCase: dependencies.monthlyUseCase,
                annualUseCase: dependencies.annualUseCase,
                recurringPaymentUseCase: dependencies.recurringPaymentUseCase,
                mutationUseCase: dependencies.mutationUseCase,
            )
        }
    }

    /// BudgetStore に必要な依存を ModelActor から構築
    /// - Parameter modelActor: 予算用 ModelActor
    internal static func makeDependencies(modelActor: BudgetModelActor) async -> BudgetStackDependencies {
        let container = modelActor.modelContainer
        return await makeDependencies(modelContainer: container)
    }

    /// BudgetStore を ModelActor ベースで構築
    /// - Parameter modelActor: 予算用 ModelActor
    /// - Returns: 初期化済み BudgetStore
    internal static func makeStore(modelActor: BudgetModelActor) async -> BudgetStore {
        let dependencies = await makeDependencies(modelActor: modelActor)
        return await MainActor.run {
            BudgetStore(
                repository: dependencies.repository,
                monthlyUseCase: dependencies.monthlyUseCase,
                annualUseCase: dependencies.annualUseCase,
                recurringPaymentUseCase: dependencies.recurringPaymentUseCase,
                mutationUseCase: dependencies.mutationUseCase,
            )
        }
    }
}
