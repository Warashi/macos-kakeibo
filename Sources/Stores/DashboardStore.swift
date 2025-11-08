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
    }

    // MARK: - Display Mode

    /// 表示モード
    internal enum DisplayMode: String, CaseIterable {
        case monthly = "月次"
        case annual = "年次"
    }

    // MARK: - Data Access

    /// すべての取引を取得
    private var allTransactions: [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)],
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// すべての予算を取得
    private var allBudgets: [Budget] {
        let descriptor = FetchDescriptor<Budget>()
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

    // MARK: - Computed Properties

    /// 月次集計
    internal var monthlySummary: MonthlySummary {
        aggregator.aggregateMonthly(
            transactions: allTransactions,
            year: currentYear,
            month: currentMonth,
            filter: .default,
        )
    }

    /// 年次集計
    internal var annualSummary: AnnualSummary {
        aggregator.aggregateAnnually(
            transactions: allTransactions,
            year: currentYear,
            filter: .default,
        )
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

    /// 年次特別枠使用状況
    internal var annualBudgetUsage: AnnualBudgetUsage? {
        guard let config = getAnnualBudgetConfig(year: currentYear) else {
            return nil
        }

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

    /// 月次充当結果
    internal var monthlyAllocation: MonthlyAllocation? {
        guard let config = getAnnualBudgetConfig(year: currentYear) else {
            return nil
        }

        let params = AllocationCalculationParams(
            transactions: allTransactions,
            budgets: allBudgets,
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
        let result = annualBudgetProgressCalculator.calculate(
            budgets: allBudgets,
            transactions: allTransactions,
            year: currentYear,
            filter: .default,
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
        if currentMonth == 1 {
            currentYear -= 1
            currentMonth = 12
        } else {
            currentMonth -= 1
        }
    }

    /// 次月に移動
    internal func moveToNextMonth() {
        if currentMonth == 12 {
            currentYear += 1
            currentMonth = 1
        } else {
            currentMonth += 1
        }
    }

    /// 今月に戻る
    internal func moveToCurrentMonth() {
        let now = Date()
        currentYear = now.year
        currentMonth = now.month
    }

    /// 前年に移動
    internal func moveToPreviousYear() {
        currentYear -= 1
    }

    /// 次年に移動
    internal func moveToNextYear() {
        currentYear += 1
    }

    /// 今年に戻る
    internal func moveToCurrentYear() {
        currentYear = Date().year
    }

    /// データを再読み込み
    internal func refresh() {
        // @Observableなので、computed propertyは自動的に再計算される
        // 必要に応じて明示的な処理をここに追加
    }
}
