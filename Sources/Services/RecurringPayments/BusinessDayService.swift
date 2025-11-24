import Foundation

/// 営業日判定サービス
internal struct BusinessDayService: Sendable {
    private let calendar: Calendar

    /// 祝日プロバイダー
    private let holidayProvider: (any HolidayProvider)?

    /// 直接指定された祝日リスト（後方互換性のため残す）
    private var holidays: Set<Date>

    internal init(
        calendar: Calendar = Calendar(identifier: .gregorian),
        holidays: Set<Date> = [],
        holidayProvider: HolidayProvider? = nil,
    ) {
        self.calendar = calendar
        self.holidays = holidays
        self.holidayProvider = holidayProvider
    }

    /// 指定日が営業日かどうか判定
    internal func isBusinessDay(_ date: Date) -> Bool {
        // 土日判定
        let weekday = calendar.component(.weekday, from: date)
        if weekday == 1 || weekday == 7 {
            return false
        }

        // 祝日判定
        let normalizedDate = calendar.startOfDay(for: date)

        // 直接指定された祝日
        if holidays.contains(normalizedDate) {
            return false
        }

        // HolidayProviderから祝日を取得
        if let provider = holidayProvider {
            let year = calendar.component(.year, from: date)
            let yearHolidays = provider.holidays(for: year)
            if yearHolidays.contains(normalizedDate) {
                return false
            }
        }

        return true
    }

    /// 前営業日を取得
    internal func previousBusinessDay(from date: Date) -> Date? {
        var current = date
        let maxIterations = 10 // 10日間検索しても見つからなければ諦める

        for _ in 0 ..< maxIterations {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: current) else {
                return nil
            }
            if isBusinessDay(previous) {
                return previous
            }
            current = previous
        }

        return nil
    }

    /// 次営業日を取得
    internal func nextBusinessDay(from date: Date) -> Date? {
        var current = date
        let maxIterations = 10 // 10日間検索しても見つからなければ諦める

        for _ in 0 ..< maxIterations {
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else {
                return nil
            }
            if isBusinessDay(next) {
                return next
            }
            current = next
        }

        return nil
    }

    /// 指定月の最初の営業日
    internal func firstBusinessDay(of year: Int, month: Int) -> Date? {
        guard let firstDay = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else {
            return nil
        }

        if isBusinessDay(firstDay) {
            return firstDay
        }
        return nextBusinessDay(from: firstDay)
    }

    /// 指定月の最終営業日
    internal func lastBusinessDay(of year: Int, month: Int) -> Date? {
        guard let firstDay = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstDay),
              let lastDay = calendar.date(byAdding: .day, value: -1, to: nextMonth) else {
            return nil
        }

        if isBusinessDay(lastDay) {
            return lastDay
        }
        return previousBusinessDay(from: lastDay)
    }

    /// 指定月のN番目の営業日
    internal func nthBusinessDay(_ nth: Int, of year: Int, month: Int) -> Date? {
        guard nth > 0 else { return nil }
        guard let firstDay = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else {
            return nil
        }

        var current = firstDay
        var count = 0
        let maxDays = 31 // 安全のための上限

        for _ in 0 ..< maxDays {
            if isBusinessDay(current) {
                count += 1
                if count == nth {
                    return current
                }
            }

            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else {
                return nil
            }
            current = next

            // 月が変わったら終了
            if calendar.component(.month, from: current) != month {
                return nil
            }
        }

        return nil
    }

    /// 最終営業日からN営業日前
    internal func lastBusinessDayMinus(days: Int, of year: Int, month: Int) -> Date? {
        guard days >= 0 else { return nil }
        guard let lastBizDay = lastBusinessDay(of: year, month: month) else {
            return nil
        }

        if days == 0 {
            return lastBizDay
        }

        var current = lastBizDay
        var count = 0

        while count < days {
            guard let previous = previousBusinessDay(from: current) else {
                return nil
            }
            current = previous
            count += 1
        }

        return current
    }
}
