import Foundation

/// 予算のDTO（Sendable）
internal struct BudgetDTO: Sendable, Hashable, Equatable {
    internal let id: UUID
    internal let amount: Decimal
    internal let categoryId: UUID?
    internal let startYear: Int
    internal let startMonth: Int
    internal let endYear: Int
    internal let endMonth: Int
    internal let createdAt: Date
    internal let updatedAt: Date

    internal init(
        id: UUID,
        amount: Decimal,
        categoryId: UUID?,
        startYear: Int,
        startMonth: Int,
        endYear: Int,
        endMonth: Int,
        createdAt: Date,
        updatedAt: Date,
    ) {
        self.id = id
        self.amount = amount
        self.categoryId = categoryId
        self.startYear = startYear
        self.startMonth = startMonth
        self.endYear = endYear
        self.endMonth = endMonth
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    internal init(from budget: BudgetEntity) {
        self.id = budget.id
        self.amount = budget.amount
        self.categoryId = budget.category?.id
        self.startYear = budget.startYear
        self.startMonth = budget.startMonth
        self.endYear = budget.endYear
        self.endMonth = budget.endMonth
        self.createdAt = budget.createdAt
        self.updatedAt = budget.updatedAt
    }

    /// 開始年月の文字列表現（例: "2025-11"）
    internal var yearMonthString: String {
        String(format: "%04d-%02d", startYear, startMonth)
    }

    /// 開始月のDate表現（その月の1日）
    internal var targetDate: Date {
        Date.from(year: startYear, month: startMonth) ?? Date()
    }

    /// 終了月のDate表現（その月の1日）
    internal var endDate: Date {
        Date.from(year: endYear, month: endMonth) ?? Date()
    }

    /// 期間の表示（例: "2025年1月〜2025年3月"）
    internal var periodDescription: String {
        if startYear == endYear, startMonth == endMonth {
            return "\(startYear)年\(startMonth)月"
        }
        return "\(startYear)年\(startMonth)月〜\(endYear)年\(endMonth)月"
    }

    /// 指定年月を含むかどうか
    internal func contains(year: Int, month: Int) -> Bool {
        let target = yearMonthIndex(year: year, month: month)
        return target >= startIndex && target <= endIndex
    }

    /// 指定年における有効月数
    internal func monthsActive(in year: Int) -> Int {
        let yearStart = yearMonthIndex(year: year, month: 1)
        let yearEnd = yearMonthIndex(year: year, month: 12)
        let start = max(startIndex, yearStart)
        let end = min(endIndex, yearEnd)
        if start > end {
            return 0
        }
        return end - start + 1
    }

    /// 総月数
    internal var totalMonthCount: Int {
        max(0, endIndex - startIndex + 1)
    }

    /// 指定年における合計予算額（月次金額 × 有効月数）
    internal func annualBudgetAmount(for year: Int) -> Decimal {
        Decimal(monthsActive(in: year)) * amount
    }

    /// 指定年と期間が重なるかどうか
    internal func overlaps(year: Int) -> Bool {
        monthsActive(in: year) > 0
    }

    private var startIndex: Int {
        yearMonthIndex(year: startYear, month: startMonth)
    }

    private var endIndex: Int {
        yearMonthIndex(year: endYear, month: endMonth)
    }

    private func yearMonthIndex(year: Int, month: Int) -> Int {
        (year * 12) + (month - 1)
    }
}
