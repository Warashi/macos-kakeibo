import Foundation

/// 月の集計期間を計算するサービス
internal struct MonthPeriodCalculator {
    private let monthStartDay: Int
    private let monthStartDayAdjustment: BusinessDayAdjustment
    private let businessDayService: BusinessDayService

    internal init(
        monthStartDay: Int = 1,
        monthStartDayAdjustment: BusinessDayAdjustment = .none,
        businessDayService: BusinessDayService,
    ) {
        self.monthStartDay = monthStartDay
        self.monthStartDayAdjustment = monthStartDayAdjustment
        self.businessDayService = businessDayService
    }

    /// 指定年月の集計期間を計算
    /// - Parameters:
    ///   - year: 年
    ///   - month: 月
    /// - Returns: 集計期間の開始日と終了日
    internal func calculatePeriod(for year: Int, month: Int) -> (start: Date, end: Date)? {
        guard let range = Date.customMonthRange(
            year: year,
            month: month,
            startDay: monthStartDay,
            adjustment: monthStartDayAdjustment,
            businessDayService: businessDayService,
        ) else {
            return nil
        }

        return (start: range.start, end: range.end)
    }

    /// 指定した日付が属する月番号を返す
    /// - Parameters:
    ///   - date: 判定対象の日付
    ///   - year: 年
    /// - Returns: 1〜12の月番号。対象年の期間外の場合はnil。
    internal func monthContaining(_ date: Date, in year: Int) -> Int? {
        for month in 1 ... 12 {
            guard let period = calculatePeriod(for: year, month: month) else { continue }
            guard date >= period.start, date < period.end else { continue }
            return month
        }
        return nil
    }

    /// 年初から指定日までに経過した月数を計算（1月=1）
    /// - Parameters:
    ///   - year: 年
    ///   - date: 判定対象の日付
    /// - Returns: 経過月数（0〜12）
    internal func monthsElapsed(in year: Int, until date: Date) -> Int {
        struct Period {
            let month: Int
            let start: Date
            let end: Date
        }

        let periods: [Period] = (1 ... 12).compactMap { month -> Period? in
            guard let period = calculatePeriod(for: year, month: month) else {
                return nil
            }
            return Period(month: month, start: period.start, end: period.end)
        }

        guard let first = periods.first else {
            return 0
        }

        if date < first.start {
            return 0
        }

        for period in periods {
            guard date < period.end else { continue }
            return date < period.start ? max(period.month - 1, 0) : period.month
        }

        return periods.last?.month ?? 12
    }
}
