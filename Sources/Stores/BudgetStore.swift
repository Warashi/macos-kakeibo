import Foundation
import Observation
import SwiftData

/// 予算管理ストア
///
/// 月次予算と年次特別枠の状態管理・データ操作を担当します。
@Observable
@MainActor
internal final class BudgetStore {
    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let budgetCalculator: BudgetCalculator
    private let annualBudgetAllocator: AnnualBudgetAllocator

    // MARK: - State

    /// 現在の表示対象年
    internal var currentYear: Int

    /// 現在の表示対象月
    internal var currentMonth: Int

    // MARK: - Initialization

    internal init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.budgetCalculator = BudgetCalculator()
        self.annualBudgetAllocator = AnnualBudgetAllocator()

        let now = Date()
        self.currentYear = now.year
        self.currentMonth = now.month
    }

    // MARK: - Fetch Helpers

    private var allBudgets: [Budget] {
        let descriptor = FetchDescriptor<Budget>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private var allTransactions: [Transaction] {
        let descriptor = FetchDescriptor<Transaction>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private var allCategories: [Category] {
        let descriptor = FetchDescriptor<Category>(
            sortBy: [
                SortDescriptor(\.displayOrder),
                SortDescriptor(\.name, order: .forward),
            ],
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func category(for id: UUID) -> Category? {
        var descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.id == id },
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    // MARK: - Public Accessors

    /// 月次予算の一覧（当月）
    internal var monthlyBudgets: [Budget] {
        allBudgets.filter { budget in
            budget.year == currentYear && budget.month == currentMonth
        }
    }

    /// カテゴリ選択用の候補
    internal var selectableCategories: [Category] {
        allCategories
    }

    /// 月次予算計算
    internal var monthlyBudgetCalculation: MonthlyBudgetCalculation {
        budgetCalculator.calculateMonthlyBudget(
            transactions: allTransactions,
            budgets: allBudgets,
            year: currentYear,
            month: currentMonth,
            filter: .default,
        )
    }

    /// グリッド表示用のカテゴリ別予算
    internal var categoryBudgetEntries: [MonthlyBudgetEntry] {
        let calculation = monthlyBudgetCalculation

        let calculationMap: [UUID: BudgetCalculation] = Dictionary(
            uniqueKeysWithValues: calculation.categoryCalculations.map { item in
                (item.categoryId, item.calculation)
            },
        )

        return monthlyBudgets
            .compactMap { budget -> MonthlyBudgetEntry? in
                guard let category = budget.category else { return nil }
                let calc = calculationMap[category.id] ?? budgetCalculator.calculate(
                    budgetAmount: budget.amount,
                    actualAmount: 0,
                )

                return MonthlyBudgetEntry(
                    budget: budget,
                    title: category.fullName,
                    calculation: calc,
                )
            }
            .sorted { lhs, rhs in
                lhs.displayOrderTuple < rhs.displayOrderTuple
            }
    }

    /// 全体予算
    internal var overallBudgetEntry: MonthlyBudgetEntry? {
        guard let budget = monthlyBudgets.first(where: { $0.category == nil }),
              let calculation = monthlyBudgetCalculation.overallCalculation else {
            return nil
        }

        return MonthlyBudgetEntry(
            budget: budget,
            title: "全体予算",
            calculation: calculation,
        )
    }

    /// 年次特別枠設定（対象年）
    internal var annualBudgetConfig: AnnualBudgetConfig? {
        var descriptor = FetchDescriptor<AnnualBudgetConfig>(
            predicate: #Predicate { $0.year == currentYear },
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    /// 年次特別枠の使用状況
    internal var annualBudgetUsage: AnnualBudgetUsage? {
        guard let config = annualBudgetConfig else { return nil }
        let params = AllocationCalculationParams(
            transactions: allTransactions,
            budgets: allBudgets,
            annualBudgetConfig: config,
            filter: .default,
        )

        return annualBudgetAllocator.calculateAnnualBudgetUsage(
            params: params,
            upToMonth: currentMonth,
        )
    }

    // MARK: - Actions (Navigation)

    internal func moveToPreviousMonth() {
        if currentMonth == 1 {
            currentMonth = 12
            currentYear -= 1
        } else {
            currentMonth -= 1
        }
    }

    internal func moveToNextMonth() {
        if currentMonth == 12 {
            currentMonth = 1
            currentYear += 1
        } else {
            currentMonth += 1
        }
    }

    internal func moveToCurrentMonth() {
        let now = Date()
        currentYear = now.year
        currentMonth = now.month
    }

    // MARK: - CRUD

    /// 月次予算を追加
    internal func addBudget(
        amount: Decimal,
        categoryId: UUID?,
    ) throws {
        let category = try resolvedCategory(categoryId: categoryId)
        let budget = Budget(
            amount: amount,
            category: category,
            year: currentYear,
            month: currentMonth,
        )
        modelContext.insert(budget)
        try modelContext.save()
    }

    /// 月次予算を更新
    internal func updateBudget(
        budget: Budget,
        amount: Decimal,
        categoryId: UUID?,
    ) throws {
        let category = try resolvedCategory(categoryId: categoryId)
        budget.amount = amount
        budget.category = category
        budget.updatedAt = Date()
        try modelContext.save()
    }

    /// 月次予算を削除
    internal func deleteBudget(_ budget: Budget) throws {
        modelContext.delete(budget)
        try modelContext.save()
    }

    /// 年次特別枠設定を登録/更新
    internal func upsertAnnualBudgetConfig(
        totalAmount: Decimal,
        policy: AnnualBudgetPolicy,
        allocations: [AnnualAllocationDraft],
    ) throws {
        if let config = annualBudgetConfig {
            config.totalAmount = totalAmount
            config.policy = policy
            config.updatedAt = Date()
            try syncAllocations(
                config: config,
                drafts: allocations,
            )
        } else {
            let config = AnnualBudgetConfig(
                year: currentYear,
                totalAmount: totalAmount,
                policy: policy,
            )
            modelContext.insert(config)
            try syncAllocations(
                config: config,
                drafts: allocations,
            )
        }
        try modelContext.save()
    }

    // MARK: - Helpers

    private func resolvedCategory(categoryId: UUID?) throws -> Category? {
        guard let id = categoryId else { return nil }
        guard let category = category(for: id) else {
            throw BudgetStoreError.categoryNotFound
        }
        return category
    }

    private func syncAllocations(
        config: AnnualBudgetConfig,
        drafts: [AnnualAllocationDraft],
    ) throws {
        let uniqueCategoryIds = Set(drafts.map(\.categoryId))
        guard uniqueCategoryIds.count == drafts.count else {
            throw BudgetStoreError.duplicateAnnualAllocationCategory
        }

        var existingAllocations: [UUID: AnnualBudgetAllocation] = [:]
        for allocation in config.allocations {
            existingAllocations[allocation.category.id] = allocation
        }

        let now = Date()
        var seenCategoryIds: Set<UUID> = []

        for draft in drafts {
            guard let category = try resolvedCategory(categoryId: draft.categoryId) else {
                throw BudgetStoreError.categoryNotFound
            }

            seenCategoryIds.insert(category.id)

            if let allocation = existingAllocations[category.id] {
                allocation.amount = draft.amount
                allocation.updatedAt = now
            } else {
                let allocation = AnnualBudgetAllocation(
                    amount: draft.amount,
                    category: category,
                )
                allocation.updatedAt = now
                config.allocations.append(allocation)
            }
        }

        // Remove allocations that are no longer present
        let allocationsToRemove = config.allocations.filter { !seenCategoryIds.contains($0.category.id) }
        for allocation in allocationsToRemove {
            if let index = config.allocations.firstIndex(where: { $0.id == allocation.id }) {
                config.allocations.remove(at: index)
            }
            modelContext.delete(allocation)
        }
    }
}

// MARK: - Entry Model

/// 月次予算の表示用エントリ
internal struct MonthlyBudgetEntry: Identifiable {
    internal let budget: Budget
    internal let title: String
    internal let calculation: BudgetCalculation

    internal var id: UUID { budget.id }

    internal var isOverallBudget: Bool {
        budget.category == nil
    }

    /// ソート用にカテゴリのdisplayOrderを親子で考慮したタプルを返す
    internal var displayOrderTuple: (Int, Int, String) {
        let parentOrder = budget.category?.parent?.displayOrder ?? budget.category?.displayOrder ?? 0
        let ownOrder = budget.category?.displayOrder ?? 0
        return (parentOrder, ownOrder, title)
    }
}

// MARK: - Error

internal enum BudgetStoreError: Error {
    case categoryNotFound
    case duplicateAnnualAllocationCategory
}

// MARK: - Annual Allocation Draft

internal struct AnnualAllocationDraft {
    internal let categoryId: UUID
    internal let amount: Decimal
}
