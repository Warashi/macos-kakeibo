import Foundation
import Observation
import SwiftData

/// 予算管理ストア
///
/// 月次/年次/特別支払いモードを切り替えながら、表示状態を管理します。
@Observable
@MainActor
internal final class BudgetStore {
    // MARK: - Types

    /// 表示モード
    internal enum DisplayMode: String, CaseIterable {
        case monthly = "月次"
        case annual = "年次"
        case specialPaymentsList = "特別支払い一覧"
    }

    // MARK: - Dependencies

    private let repository: BudgetRepository
    private let monthlyUseCase: MonthlyBudgetUseCaseProtocol
    private let annualUseCase: AnnualBudgetUseCaseProtocol
    private let specialPaymentUseCase: SpecialPaymentSavingsUseCaseProtocol
    private let mutationUseCase: BudgetMutationUseCaseProtocol
    private let currentDateProvider: () -> Date

    // MARK: - State

    private var snapshot: BudgetSnapshot? {
        didSet { refreshToken = UUID() }
    }

    internal var currentYear: Int {
        didSet {
            guard oldValue != currentYear else { return }
            reloadSnapshot()
        }
    }

    internal var currentMonth: Int {
        didSet {
            guard oldValue != currentMonth else { return }
            refreshToken = UUID()
        }
    }

    internal var displayMode: DisplayMode = .monthly
    internal private(set) var refreshToken: UUID = .init()

    // MARK: - Initialization

    internal convenience init(modelContext: ModelContext) {
        let repository = SwiftDataBudgetRepository(modelContext: modelContext)
        let monthlyUseCase = DefaultMonthlyBudgetUseCase()
        let annualUseCase = DefaultAnnualBudgetUseCase()
        let specialPaymentUseCase = DefaultSpecialPaymentSavingsUseCase()
        let mutationUseCase = DefaultBudgetMutationUseCase(repository: repository)
        self.init(
            repository: repository,
            monthlyUseCase: monthlyUseCase,
            annualUseCase: annualUseCase,
            specialPaymentUseCase: specialPaymentUseCase,
            mutationUseCase: mutationUseCase
        )
    }

    internal init(
        repository: BudgetRepository,
        monthlyUseCase: MonthlyBudgetUseCaseProtocol,
        annualUseCase: AnnualBudgetUseCaseProtocol,
        specialPaymentUseCase: SpecialPaymentSavingsUseCaseProtocol,
        mutationUseCase: BudgetMutationUseCaseProtocol,
        currentDateProvider: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.monthlyUseCase = monthlyUseCase
        self.annualUseCase = annualUseCase
        self.specialPaymentUseCase = specialPaymentUseCase
        self.mutationUseCase = mutationUseCase
        self.currentDateProvider = currentDateProvider

        let now = currentDateProvider()
        self.currentYear = now.year
        self.currentMonth = now.month

        reloadSnapshot()
    }
}

// MARK: - Data Accessors

internal extension BudgetStore {
    /// データを再取得
    func refresh() {
        reloadSnapshot()
    }

    /// 現在の月の予算一覧
    var monthlyBudgets: [Budget] {
        guard let snapshot else { return [] }
        return monthlyUseCase.monthlyBudgets(
            snapshot: snapshot,
            year: currentYear,
            month: currentMonth
        )
    }

    /// カテゴリ選択肢
    var selectableCategories: [Category] {
        snapshot?.categories ?? []
    }

    /// 月次計算結果
    var monthlyBudgetCalculation: MonthlyBudgetCalculation {
        guard let snapshot else {
            return MonthlyBudgetCalculation(
                year: currentYear,
                month: currentMonth,
                overallCalculation: nil,
                categoryCalculations: []
            )
        }
        return monthlyUseCase.monthlyCalculation(
            snapshot: snapshot,
            year: currentYear,
            month: currentMonth
        )
    }

    /// カテゴリ別エントリ
    var categoryBudgetEntries: [MonthlyBudgetEntry] {
        guard let snapshot else { return [] }
        return monthlyUseCase.categoryEntries(
            snapshot: snapshot,
            year: currentYear,
            month: currentMonth
        )
    }

    /// 全体予算エントリ
    var overallBudgetEntry: MonthlyBudgetEntry? {
        guard let snapshot else { return nil }
        return monthlyUseCase.overallEntry(
            snapshot: snapshot,
            year: currentYear,
            month: currentMonth
        )
    }

    /// 年次特別枠設定
    var annualBudgetConfig: AnnualBudgetConfig? {
        snapshot?.annualBudgetConfig
    }

    /// 年次特別枠の使用状況
    var annualBudgetUsage: AnnualBudgetUsage? {
        guard let snapshot else { return nil }
        return annualUseCase.annualBudgetUsage(
            snapshot: snapshot,
            year: currentYear,
            month: currentMonth
        )
    }

    /// 年次全体予算エントリ
    var annualOverallBudgetEntry: AnnualBudgetEntry? {
        guard let snapshot else { return nil }
        return annualUseCase.annualOverallEntry(
            snapshot: snapshot,
            year: currentYear
        )
    }

    /// 年次カテゴリ別エントリ
    var annualCategoryBudgetEntries: [AnnualBudgetEntry] {
        guard let snapshot else { return [] }
        return annualUseCase.annualCategoryEntries(
            snapshot: snapshot,
            year: currentYear
        )
    }

    /// 月次積立金額の合計
    var monthlySpecialPaymentSavingsTotal: Decimal {
        guard let snapshot else { return .zero }
        return specialPaymentUseCase.monthlySavingsTotal(
            snapshot: snapshot,
            year: currentYear,
            month: currentMonth
        )
    }

    /// カテゴリ別積立金額
    var categorySpecialPaymentSavings: [UUID: Decimal] {
        guard let snapshot else { return [:] }
        return specialPaymentUseCase.categorySavings(
            snapshot: snapshot,
            year: currentYear,
            month: currentMonth
        )
    }

    /// 特別支払い積立計算結果
    var specialPaymentSavingsCalculations: [SpecialPaymentSavingsCalculation] {
        guard let snapshot else { return [] }
        return specialPaymentUseCase.calculations(
            snapshot: snapshot,
            year: currentYear,
            month: currentMonth
        )
    }

    /// 特別支払い積立の表示用エントリ
    var specialPaymentSavingsEntries: [SpecialPaymentSavingsEntry] {
        guard let snapshot else { return [] }
        return specialPaymentUseCase.entries(
            snapshot: snapshot,
            year: currentYear,
            month: currentMonth
        )
    }
}

// MARK: - Navigation

internal extension BudgetStore {
    func moveToPreviousMonth() {
        if currentMonth == 1 {
            currentMonth = 12
            currentYear -= 1
        } else {
            currentMonth -= 1
        }
    }

    func moveToNextMonth() {
        if currentMonth == 12 {
            currentMonth = 1
            currentYear += 1
        } else {
            currentMonth += 1
        }
    }

    func moveToCurrentMonth() {
        let now = currentDateProvider()
        currentYear = now.year
        currentMonth = now.month
    }

    func moveToPreviousYear() {
        currentYear -= 1
    }

    func moveToNextYear() {
        currentYear += 1
    }

    func moveToCurrentYear() {
        currentYear = currentDateProvider().year
    }
}

// MARK: - Mutations

internal extension BudgetStore {
    func addBudget(_ input: BudgetInput) throws {
        try mutationUseCase.addBudget(input: input)
        reloadSnapshot()
    }

    func updateBudget(budget: Budget, input: BudgetInput) throws {
        try mutationUseCase.updateBudget(budget, input: input)
        reloadSnapshot()
    }

    func deleteBudget(_ budget: Budget) throws {
        try mutationUseCase.deleteBudget(budget)
        reloadSnapshot()
    }

    func upsertAnnualBudgetConfig(
        totalAmount: Decimal,
        policy: AnnualBudgetPolicy,
        allocations: [AnnualAllocationDraft]
    ) throws {
        try mutationUseCase.upsertAnnualBudgetConfig(
            existingConfig: snapshot?.annualBudgetConfig,
            year: currentYear,
            totalAmount: totalAmount,
            policy: policy,
            allocations: allocations
        )
        reloadSnapshot()
    }
}

// MARK: - Private Helpers

private extension BudgetStore {
    func reloadSnapshot() {
        snapshot = try? repository.fetchSnapshot(for: currentYear)
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
        policyOverride: AnnualBudgetPolicy? = nil
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
