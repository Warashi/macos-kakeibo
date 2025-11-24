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
}
