import Foundation
import Observation
import SwiftData

/// ダッシュボードストア
///
/// ダッシュボード画面の状態管理を行います。
/// - 月次/年次の総括計算
/// - カテゴリ別ハイライトの集計
/// - 年次特別枠の残額計算
@Observable
@MainActor
internal final class DashboardStore {
    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let aggregator: TransactionAggregator
    private let budgetCalculator: BudgetCalculator
    private let annualBudgetAllocator: AnnualBudgetAllocator
    private let annualBudgetProgressCalculator: AnnualBudgetProgressCalculator

    // MARK: - State

    /// 現在の表示対象年
    internal var currentYear: Int

    /// 現在の表示対象月
    internal var currentMonth: Int

    /// 表示モード（月次/年次）
    internal var displayMode: DisplayMode = .monthly

    // MARK: - Initialization

    /// イニシャライザ
    /// - Parameter modelContext: SwiftDataのモデルコンテキスト
    internal init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.aggregator = TransactionAggregator()
        self.budgetCalculator = BudgetCalculator()
        self.annualBudgetAllocator = AnnualBudgetAllocator()
        self.annualBudgetProgressCalculator = AnnualBudgetProgressCalculator()

        // 現在の年月で初期化
        let now = Date()
        self.currentYear = now.year
        self.currentMonth = now.month

        if getAnnualBudgetConfig(year: currentYear) == nil,
           let fallbackYear = latestAnnualBudgetConfigYear() {
            self.currentYear = fallbackYear
        }
    }

    // MARK: - Display Mode

    /// 表示モード
    internal enum DisplayMode: String, CaseIterable {
        case monthly = "月次"
        case annual = "年次"
    }

    // MARK: - Data Access

    /// 指定した期間の取引を取得
    private func fetchTransactions(year: Int, month: Int? = nil) -> [Transaction] {
        guard let startDate = Date.from(year: year, month: month ?? 1) else {
            return []
        }

        let endDate: Date
        if let month {
            let nextMonth = month == 12 ? 1 : month + 1
            let nextYear = month == 12 ? year + 1 : year
            endDate = Date.from(year: nextYear, month: nextMonth) ?? startDate
        } else {
            endDate = Date.from(year: year + 1, month: 1) ?? startDate
        }

        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate {
                $0.date >= startDate && $0.date < endDate
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)],
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// 指定年に関係する予算を取得
    private func fetchBudgets(overlapping year: Int) -> [Budget] {
        let descriptor = FetchDescriptor<Budget>(
            predicate: #Predicate {
                $0.startYear <= year && $0.endYear >= year
            },
            sortBy: [
                SortDescriptor(\.startYear),
                SortDescriptor(\.startMonth),
                SortDescriptor(\.createdAt),
            ],
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// カテゴリを取得
    private func fetchCategories() -> [Category] {
        let descriptor = FetchDescriptor<Category>(
            sortBy: [
                SortDescriptor(\.displayOrder),
                SortDescriptor(\.name),
            ],
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// 年次特別枠設定を取得
    private func getAnnualBudgetConfig(year: Int) -> AnnualBudgetConfig? {
        var descriptor = FetchDescriptor<AnnualBudgetConfig>(
            predicate: #Predicate { $0.year == year },
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    /// 最新の年次特別枠設定の年を取得
    private func latestAnnualBudgetConfigYear() -> Int? {
        var descriptor = FetchDescriptor<AnnualBudgetConfig>(
            sortBy: [SortDescriptor(\.year, order: .reverse)],
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first?.year
    }

    // MARK: - Computed Properties

    /// 月次集計
    internal var monthlySummary: MonthlySummary {
        let transactions = fetchTransactions(year: currentYear, month: currentMonth)
        return aggregator.aggregateMonthly(
            transactions: transactions,
            year: currentYear,
            month: currentMonth,
            filter: .default,
        )
    }

    /// 年次集計
    internal var annualSummary: AnnualSummary {
        let transactions = fetchTransactions(year: currentYear)
        return aggregator.aggregateAnnually(
            transactions: transactions,
            year: currentYear,
            filter: .default,
        )
    }

    /// 月次予算計算
    internal var monthlyBudgetCalculation: MonthlyBudgetCalculation {
        let config = getAnnualBudgetConfig(year: currentYear)
        let categories = fetchCategories()
        let excludedCategoryIds = config?.fullCoverageCategoryIDs(
            includingChildrenFrom: categories,
        ) ?? []
        let transactions = fetchTransactions(year: currentYear, month: currentMonth)
        let budgets = fetchBudgets(overlapping: currentYear)
        return budgetCalculator.calculateMonthlyBudget(
            transactions: transactions,
            budgets: budgets,
            year: currentYear,
            month: currentMonth,
            filter: .default,
            excludedCategoryIds: excludedCategoryIds,
        )
    }

    /// 年次特別枠使用状況
    internal var annualBudgetUsage: AnnualBudgetUsage? {
        guard let config = getAnnualBudgetConfig(year: currentYear) else {
            return nil
        }

        let transactions = fetchTransactions(year: currentYear)
        let budgets = fetchBudgets(overlapping: currentYear)
        let params = AllocationCalculationParams(
            transactions: transactions,
            budgets: budgets,
            annualBudgetConfig: config,
            filter: .default,
        )

        return annualBudgetAllocator.calculateAnnualBudgetUsage(
            params: params,
            upToMonth: currentMonth,
        )
    }

    /// 月次充当結果
    internal var monthlyAllocation: MonthlyAllocation? {
        guard let config = getAnnualBudgetConfig(year: currentYear) else {
            return nil
        }

        let transactions = fetchTransactions(year: currentYear)
        let budgets = fetchBudgets(overlapping: currentYear)
        let params = AllocationCalculationParams(
            transactions: transactions,
            budgets: budgets,
            annualBudgetConfig: config,
            filter: .default,
        )

        return annualBudgetAllocator.calculateMonthlyAllocation(
            params: params,
            year: currentYear,
            month: currentMonth,
        )
    }

    /// カテゴリ別ハイライト（支出額上位）
    internal var categoryHighlights: [CategorySummary] {
        let summaries = displayMode == .monthly
            ? monthlySummary.categorySummaries
            : annualSummary.categorySummaries

        // 支出額上位10件を返す
        return Array(summaries.prefix(10))
    }

    /// 年次予算進捗
    private var annualBudgetProgressResult: AnnualBudgetProgressResult? {
        let budgets = fetchBudgets(overlapping: currentYear)
        let transactions = fetchTransactions(year: currentYear)
        let config = getAnnualBudgetConfig(year: currentYear)
        let categories = fetchCategories()
        let excludedCategoryIds = config?.fullCoverageCategoryIDs(
            includingChildrenFrom: categories,
        ) ?? []
        let result = annualBudgetProgressCalculator.calculate(
            budgets: budgets,
            transactions: transactions,
            year: currentYear,
            filter: .default,
            excludedCategoryIds: excludedCategoryIds,
        )
        if result.overallEntry == nil, result.categoryEntries.isEmpty {
            return nil
        }
        return result
    }

    /// 年次予算進捗（全体）
    internal var annualBudgetProgressCalculation: BudgetCalculation? {
        annualBudgetProgressResult?.aggregateCalculation
    }

    /// 年次カテゴリ別予算進捗
    internal var annualBudgetCategoryEntries: [AnnualBudgetEntry] {
        annualBudgetProgressResult?.categoryEntries ?? []
    }

    // MARK: - Actions

    /// 前月に移動
    internal func moveToPreviousMonth() {
        updateMonthNavigator { $0.moveToPreviousMonth() }
    }

    /// 次月に移動
    internal func moveToNextMonth() {
        updateMonthNavigator { $0.moveToNextMonth() }
    }

    /// 今月に戻る
    internal func moveToCurrentMonth() {
        updateMonthNavigator { $0.moveToCurrentMonth() }
    }

    /// 前年に移動
    internal func moveToPreviousYear() {
        updateMonthNavigator { $0.moveToPreviousYear() }
    }

    /// 次年に移動
    internal func moveToNextYear() {
        updateMonthNavigator { $0.moveToNextYear() }
    }

    /// 今年に戻る
    internal func moveToCurrentYear() {
        updateMonthNavigator { $0.moveToCurrentYear() }
    }

    /// データを再読み込み
    internal func refresh() {
        // @Observableなので、computed propertyは自動的に再計算される
        // 必要に応じて明示的な処理をここに追加
    }

    private func updateMonthNavigator(_ update: (inout MonthNavigator) -> Void) {
        var navigator = MonthNavigator(year: currentYear, month: currentMonth)
        update(&navigator)
        currentYear = navigator.year
        currentMonth = navigator.month
    }
}
