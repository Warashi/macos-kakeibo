import Foundation

/// 日付範囲を表す値オブジェクト。
internal struct DateRange: Equatable, Sendable {
    internal var startDate: Date {
        didSet { normalizeOrder() }
    }

    internal var endDate: Date {
        didSet { normalizeOrder() }
    }

    internal init(startDate: Date, endDate: Date) {
        if startDate <= endDate {
            self.startDate = startDate
            self.endDate = endDate
        } else {
            self.startDate = endDate
            self.endDate = startDate
        }
    }

    /// 指定した日付が範囲内かどうか
    internal func contains(_ date: Date) -> Bool {
        startDate <= date && date <= endDate
    }

    /// 期間を今月開始〜指定月数後までに初期化
    internal static func currentMonthThroughFutureMonths(
        referenceDate: Date,
        monthsAhead: Int,
        calendar: Calendar = .current
    ) -> DateRange {
        let start = calendar.startOfMonth(for: referenceDate) ?? referenceDate
        let end = calendar.date(byAdding: .month, value: monthsAhead, to: start) ?? start
        return DateRange(startDate: start, endDate: end)
    }

    private mutating func normalizeOrder() {
        guard startDate > endDate else { return }
        let newStart = endDate
        let newEnd = startDate
        startDate = newStart
        endDate = newEnd
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date? {
        self.date(from: dateComponents([.year, .month], from: date))
    }
}
