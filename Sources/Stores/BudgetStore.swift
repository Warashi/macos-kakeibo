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
        didSet {
            refreshToken = UUID()
            recalculate()
        }
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
            recalculate()
        }
    }

    internal var displayMode: DisplayMode = .monthly
    internal private(set) var refreshToken: UUID = .init()

    internal var displayModeTraits: BudgetDisplayModeTraits {
        BudgetDisplayModeTraits(mode: displayMode)
    }

    // MARK: - Cached Data

    /// 現在の月の予算一覧
    internal var monthlyBudgets: [Budget] = []

    /// カテゴリ選択肢
    internal var selectableCategories: [Category] = []

    /// 月次計算結果
    internal var monthlyBudgetCalculation: MonthlyBudgetCalculation

    /// カテゴリ別エントリ
    internal var categoryBudgetEntries: [MonthlyBudgetEntry] = []

    /// 全体予算エントリ
    internal var overallBudgetEntry: MonthlyBudgetEntry?

    /// 年次特別枠設定
    internal var annualBudgetConfig: AnnualBudgetConfig?

    /// 年次特別枠の使用状況
    internal var annualBudgetUsage: AnnualBudgetUsage?

    /// 年次全体予算エントリ
    internal var annualOverallBudgetEntry: AnnualBudgetEntry?

    /// 年次カテゴリ別エントリ
    internal var annualCategoryBudgetEntries: [AnnualBudgetEntry] = []

    /// 月次積立金額の合計
    internal var monthlySpecialPaymentSavingsTotal: Decimal = .zero

    /// カテゴリ別積立金額
    internal var categorySpecialPaymentSavings: [UUID: Decimal] = [:]

    /// 特別支払い積立計算結果
    internal var specialPaymentSavingsCalculations: [SpecialPaymentSavingsCalculation] = []

    /// 特別支払い積立の表示用エントリ
    internal var specialPaymentSavingsEntries: [SpecialPaymentSavingsEntry] = []

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
            mutationUseCase: mutationUseCase,
        )
    }

    internal init(
        repository: BudgetRepository,
        monthlyUseCase: MonthlyBudgetUseCaseProtocol,
        annualUseCase: AnnualBudgetUseCaseProtocol,
        specialPaymentUseCase: SpecialPaymentSavingsUseCaseProtocol,
        mutationUseCase: BudgetMutationUseCaseProtocol,
        currentDateProvider: @escaping () -> Date = Date.init,
    ) {
        self.repository = repository
        self.monthlyUseCase = monthlyUseCase
        self.annualUseCase = annualUseCase
        self.specialPaymentUseCase = specialPaymentUseCase
        self.mutationUseCase = mutationUseCase
        self.currentDateProvider = currentDateProvider

        let now = currentDateProvider()
        let initialYear = now.year
        let initialMonth = now.month

        self.currentYear = initialYear
        self.currentMonth = initialMonth

        // 初期値を設定（recalculate で上書きされる）
        self.monthlyBudgetCalculation = MonthlyBudgetCalculation(
            year: initialYear,
            month: initialMonth,
            overallCalculation: nil,
            categoryCalculations: [],
        )

        reloadSnapshot()
    }
}

// MARK: - Data Refresh

internal extension BudgetStore {
    /// データを再取得
    func refresh() {
        reloadSnapshot()
    }

    /// 計算結果を再計算
    private func recalculate() {
        guard let snapshot else {
            // snapshotがない場合は初期値を設定
            monthlyBudgets = []
            selectableCategories = []
            monthlyBudgetCalculation = MonthlyBudgetCalculation(
                year: currentYear,
                month: currentMonth,
                overallCalculation: nil,
                categoryCalculations: [],
            )
            categoryBudgetEntries = []
            overallBudgetEntry = nil
            annualBudgetConfig = nil
            annualBudgetUsage = nil
            annualOverallBudgetEntry = nil
            annualCategoryBudgetEntries = []
            monthlySpecialPaymentSavingsTotal = .zero
            categorySpecialPaymentSavings = [:]
            specialPaymentSavingsCalculations = []
            specialPaymentSavingsEntries = []
            return
        }

        // 月次データの計算
        monthlyBudgets = monthlyUseCase.monthlyBudgets(
            snapshot: snapshot,
            year: currentYear,
            month: currentMonth,
        )
        selectableCategories = snapshot.categories
        monthlyBudgetCalculation = monthlyUseCase.monthlyCalculation(
            snapshot: snapshot,
            year: currentYear,
            month: currentMonth,
        )
        categoryBudgetEntries = monthlyUseCase.categoryEntries(
            snapshot: snapshot,
            year: currentYear,
            month: currentMonth,
        )
        overallBudgetEntry = monthlyUseCase.overallEntry(
            snapshot: snapshot,
            year: currentYear,
            month: currentMonth,
        )

        // 年次データの計算
        annualBudgetConfig = snapshot.annualBudgetConfig
        annualBudgetUsage = annualUseCase.annualBudgetUsage(
            snapshot: snapshot,
            year: currentYear,
            month: currentMonth,
        )
        annualOverallBudgetEntry = annualUseCase.annualOverallEntry(
            snapshot: snapshot,
            year: currentYear,
        )
        annualCategoryBudgetEntries = annualUseCase.annualCategoryEntries(
            snapshot: snapshot,
            year: currentYear,
        )

        // 特別支払いデータの計算
        monthlySpecialPaymentSavingsTotal = specialPaymentUseCase.monthlySavingsTotal(
            snapshot: snapshot,
            year: currentYear,
            month: currentMonth,
        )
        categorySpecialPaymentSavings = specialPaymentUseCase.categorySavings(
            snapshot: snapshot,
            year: currentYear,
            month: currentMonth,
        )
        specialPaymentSavingsCalculations = specialPaymentUseCase.calculations(
            snapshot: snapshot,
            year: currentYear,
            month: currentMonth,
        )
        specialPaymentSavingsEntries = specialPaymentUseCase.entries(
            snapshot: snapshot,
            year: currentYear,
            month: currentMonth,
        )
    }
}

// MARK: - Navigation

internal extension BudgetStore {
    func moveToPreviousMonth() {
        updateNavigation { $0.moveToPreviousMonth() }
    }

    func moveToNextMonth() {
        updateNavigation { $0.moveToNextMonth() }
    }

    func moveToCurrentMonth() {
        updateNavigation { $0.moveToCurrentMonth() }
    }

    func moveToPreviousYear() {
        updateNavigation { $0.moveToPreviousYear() }
    }

    func moveToNextYear() {
        updateNavigation { $0.moveToNextYear() }
    }

    func moveToCurrentYear() {
        updateNavigation { $0.moveToCurrentYear() }
    }

    func moveToPresent() {
        updateNavigation { $0.moveToPresent(displayMode: displayMode) }
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
        allocations: [AnnualAllocationDraft],
    ) throws {
        let input = AnnualBudgetConfigInput(
            existingConfig: snapshot?.annualBudgetConfig,
            year: currentYear,
            totalAmount: totalAmount,
            policy: policy,
            allocations: allocations,
        )
        try mutationUseCase.upsertAnnualBudgetConfig(input)
        reloadSnapshot()
    }
}

// MARK: - Private Helpers

private extension BudgetStore {
    func reloadSnapshot() {
        snapshot = try? repository.fetchSnapshot(for: currentYear)
    }

    private func updateNavigation(_ update: (inout BudgetNavigationState) -> Bool) {
        var state = BudgetNavigationState(
            year: currentYear,
            month: currentMonth,
            currentDateProvider: currentDateProvider,
        )
        let changed = update(&state)
        guard changed else { return }
        applyNavigation(state)
    }

    private func applyNavigation(_ state: BudgetNavigationState) {
        if currentYear != state.year {
            currentYear = state.year
        }
        if currentMonth != state.month {
            currentMonth = state.month
        }
    }
}

// MARK: - Error

internal enum BudgetStoreError: Error {
    case categoryNotFound
    case duplicateAnnualAllocationCategory
    case invalidPeriod
}
