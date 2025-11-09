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
    private let aggregator: TransactionAggregator
    private let annualBudgetAllocator: AnnualBudgetAllocator
    private let annualBudgetProgressCalculator: AnnualBudgetProgressCalculator
    private let specialPaymentBalanceService: SpecialPaymentBalanceService

    // MARK: - State

    /// 現在の表示対象年
    internal var currentYear: Int

    /// 現在の表示対象月
    internal var currentMonth: Int

    /// 表示モード（月次/年次）
    internal var displayMode: DisplayMode = .monthly

    /// データの再取得トリガー
    internal private(set) var refreshToken: UUID = .init()

    // MARK: - Initialization

    internal init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.budgetCalculator = BudgetCalculator()
        self.aggregator = TransactionAggregator()
        self.annualBudgetAllocator = AnnualBudgetAllocator()
        self.annualBudgetProgressCalculator = AnnualBudgetProgressCalculator()
        self.specialPaymentBalanceService = SpecialPaymentBalanceService()

        let now = Date()
        self.currentYear = now.year
        self.currentMonth = now.month
    }

    // MARK: - Display Mode

    /// 表示モード
    internal enum DisplayMode: String, CaseIterable {
        case monthly = "月次"
        case annual = "年次"
        case specialPaymentsList = "特別支払い一覧"
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

    private var allSpecialPaymentDefinitions: [SpecialPaymentDefinition] {
        let descriptor = FetchDescriptor<SpecialPaymentDefinition>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private var allSpecialPaymentBalances: [SpecialPaymentSavingBalance] {
        let descriptor = FetchDescriptor<SpecialPaymentSavingBalance>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Public Accessors

    /// 月次予算の一覧（当月）
    internal var monthlyBudgets: [Budget] {
        allBudgets.filter { $0.contains(year: currentYear, month: currentMonth) }
    }

    /// カテゴリ選択用の候補
    internal var selectableCategories: [Category] {
        allCategories
    }

    /// 月次予算計算
    internal var monthlyBudgetCalculation: MonthlyBudgetCalculation {
        let config = annualBudgetConfig
        let excludedCategoryIds = config?.fullCoverageCategoryIDs(
            includingChildrenFrom: allCategories,
        ) ?? []
        return budgetCalculator.calculateMonthlyBudget(
            transactions: allTransactions,
            budgets: allBudgets,
            year: currentYear,
            month: currentMonth,
            filter: .default,
            excludedCategoryIds: excludedCategoryIds,
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
                lhs.displayOrderKey < rhs.displayOrderKey
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

    /// 年次集計
    private var annualSummary: AnnualSummary {
        aggregator.aggregateAnnually(
            transactions: allTransactions,
            year: currentYear,
            filter: .default,
        )
    }

    private var annualBudgetProgressResult: AnnualBudgetProgressResult {
        annualBudgetProgressCalculator.calculate(
            budgets: allBudgets,
            transactions: allTransactions,
            year: currentYear,
            filter: .default,
        )
    }

    /// 年次全体予算エントリ
    internal var annualOverallBudgetEntry: AnnualBudgetEntry? {
        annualBudgetProgressResult.overallEntry
    }

    /// 年次カテゴリ別予算エントリ
    internal var annualCategoryBudgetEntries: [AnnualBudgetEntry] {
        annualBudgetProgressResult.categoryEntries
    }

    // MARK: - Special Payment Savings

    /// 月次積立金額の合計
    internal var monthlySpecialPaymentSavingsTotal: Decimal {
        budgetCalculator.calculateMonthlySavingsAllocation(
            definitions: allSpecialPaymentDefinitions,
            year: currentYear,
            month: currentMonth,
        )
    }

    /// カテゴリ別の積立金額
    internal var categorySpecialPaymentSavings: [UUID: Decimal] {
        budgetCalculator.calculateCategorySavingsAllocation(
            definitions: allSpecialPaymentDefinitions,
            year: currentYear,
            month: currentMonth,
        )
    }

    /// 特別支払いの積立状況一覧
    internal var specialPaymentSavingsCalculations: [SpecialPaymentSavingsCalculation] {
        budgetCalculator.calculateSpecialPaymentSavings(
            definitions: allSpecialPaymentDefinitions,
            balances: allSpecialPaymentBalances,
            year: currentYear,
            month: currentMonth,
        )
    }

    /// 特別支払い積立の表示用エントリ
    internal var specialPaymentSavingsEntries: [SpecialPaymentSavingsEntry] {
        specialPaymentSavingsCalculations.map { calc in
            let progress: Double
            if calc.nextOccurrence != nil,
               let definition = allSpecialPaymentDefinitions.first(where: { $0.id == calc.definitionId }) {
                let targetAmount = definition.amount
                if targetAmount > 0 {
                    progress = min(
                        1.0,
                        NSDecimalNumber(decimal: calc.balance).doubleValue / NSDecimalNumber(decimal: targetAmount)
                            .doubleValue,
                    )
                } else {
                    progress = 0
                }
            } else {
                progress = 0
            }

            return SpecialPaymentSavingsEntry(
                calculation: calc,
                progress: progress,
                hasAlert: calc.balance < 0,
            )
        }
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

    internal func moveToPreviousYear() {
        currentYear -= 1
    }

    internal func moveToNextYear() {
        currentYear += 1
    }

    internal func moveToCurrentYear() {
        currentYear = Date().year
    }

    // MARK: - CRUD

    /// 月次予算を追加
    internal func addBudget(_ input: BudgetInput) throws {
        try validatePeriod(
            startYear: input.startYear,
            startMonth: input.startMonth,
            endYear: input.endYear,
            endMonth: input.endMonth,
        )
        let category = try resolvedCategory(categoryId: input.categoryId)
        let budget = Budget(
            amount: input.amount,
            category: category,
            startYear: input.startYear,
            startMonth: input.startMonth,
            endYear: input.endYear,
            endMonth: input.endMonth,
        )
        modelContext.insert(budget)
        try modelContext.save()
        notifyDataChanged()
    }

    /// 月次予算を更新
    internal func updateBudget(budget: Budget, input: BudgetInput) throws {
        try validatePeriod(
            startYear: input.startYear,
            startMonth: input.startMonth,
            endYear: input.endYear,
            endMonth: input.endMonth,
        )
        let category = try resolvedCategory(categoryId: input.categoryId)
        budget.amount = input.amount
        budget.category = category
        budget.startYear = input.startYear
        budget.startMonth = input.startMonth
        budget.endYear = input.endYear
        budget.endMonth = input.endMonth
        budget.updatedAt = Date()
        try modelContext.save()
        notifyDataChanged()
    }

    /// 月次予算を削除
    internal func deleteBudget(_ budget: Budget) throws {
        modelContext.delete(budget)
        try modelContext.save()
        notifyDataChanged()
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
        notifyDataChanged()
    }
}

// MARK: - Helpers

private extension BudgetStore {
    func notifyDataChanged() {
        refreshToken = UUID()
    }

    func resolvedCategory(categoryId: UUID?) throws -> Category? {
        guard let id = categoryId else { return nil }
        guard let category = category(for: id) else {
            throw BudgetStoreError.categoryNotFound
        }
        return category
    }

    func validatePeriod(
        startYear: Int,
        startMonth: Int,
        endYear: Int,
        endMonth: Int,
    ) throws {
        guard (2000 ... 2100).contains(startYear),
              (2000 ... 2100).contains(endYear),
              (1 ... 12).contains(startMonth),
              (1 ... 12).contains(endMonth) else {
            throw BudgetStoreError.invalidPeriod
        }

        let startIndex = startYear * 12 + startMonth
        let endIndex = endYear * 12 + endMonth
        guard startIndex <= endIndex else {
            throw BudgetStoreError.invalidPeriod
        }
    }

    func syncAllocations(
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

            if !category.allowsAnnualBudget {
                category.allowsAnnualBudget = true
                category.updatedAt = now
            }

            seenCategoryIds.insert(category.id)

            if let allocation = existingAllocations[category.id] {
                allocation.amount = draft.amount
                allocation.policyOverride = draft.policyOverride
                allocation.updatedAt = now
            } else {
                let allocation = AnnualBudgetAllocation(
                    amount: draft.amount,
                    category: category,
                    policyOverride: draft.policyOverride,
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

    internal var periodDescription: String {
        budget.periodDescription
    }

    internal var isOverallBudget: Bool {
        budget.category == nil
    }

    /// ソート用にカテゴリのdisplayOrderを親子で考慮した順序情報を返す
    internal var displayOrderKey: CategoryDisplayOrderKey {
        let parentOrder = budget.category?.parent?.displayOrder ?? budget.category?.displayOrder ?? 0
        let ownOrder = budget.category?.displayOrder ?? 0
        return CategoryDisplayOrderKey(parentOrder: parentOrder, ownOrder: ownOrder, title: title)
    }
}

// MARK: - Budget Input

/// 月次予算の入力パラメータ
internal struct BudgetInput {
    internal let amount: Decimal
    internal let categoryId: UUID?
    internal let startYear: Int
    internal let startMonth: Int
    internal let endYear: Int
    internal let endMonth: Int
}

// MARK: - Category Display Order Key

/// カテゴリの表示順序を表すキー
internal struct CategoryDisplayOrderKey: Comparable {
    internal let parentOrder: Int
    internal let ownOrder: Int
    internal let title: String

    internal static func < (lhs: CategoryDisplayOrderKey, rhs: CategoryDisplayOrderKey) -> Bool {
        if lhs.parentOrder != rhs.parentOrder {
            return lhs.parentOrder < rhs.parentOrder
        }
        if lhs.ownOrder != rhs.ownOrder {
            return lhs.ownOrder < rhs.ownOrder
        }
        return lhs.title < rhs.title
    }
}

// MARK: - Error

internal enum BudgetStoreError: Error {
    case categoryNotFound
    case duplicateAnnualAllocationCategory
    case invalidPeriod
}

// MARK: - Annual Allocation Draft

internal struct AnnualAllocationDraft {
    internal let categoryId: UUID
    internal let amount: Decimal
    internal let policyOverride: AnnualBudgetPolicy?

    internal init(
        categoryId: UUID,
        amount: Decimal,
        policyOverride: AnnualBudgetPolicy? = nil,
    ) {
        self.categoryId = categoryId
        self.amount = amount
        self.policyOverride = policyOverride
    }
}

// MARK: - Special Payment Savings Entry

/// 特別支払い積立の表示用エントリ
internal struct SpecialPaymentSavingsEntry: Identifiable {
    internal let calculation: SpecialPaymentSavingsCalculation

    /// 進捗率（0.0 〜 1.0）
    internal let progress: Double

    /// アラート表示フラグ（残高不足など）
    internal let hasAlert: Bool

    internal var id: UUID {
        calculation.definitionId
    }

    internal var name: String {
        calculation.name
    }

    internal var monthlySaving: Decimal {
        calculation.monthlySaving
    }

    internal var balance: Decimal {
        calculation.balance
    }

    internal var nextOccurrence: Date? {
        calculation.nextOccurrence
    }

    internal var progressPercentage: Double {
        progress * 100
    }
}
