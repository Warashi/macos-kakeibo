import Foundation

/// DayOfMonthPattern の日付計算に使うコンテキスト
internal struct DateCalculationContext {
    internal let year: Int
    internal let month: Int
    internal let calendar: Calendar
    internal let businessDayService: BusinessDayService
}

internal extension DayOfMonthPattern {
    /// 指定された年月でこのパターンに該当する日付を計算する
    func date(
        in year: Int,
        month: Int,
        calendar: Calendar,
        businessDayService: BusinessDayService,
    ) -> Date? {
        let context = DateCalculationContext(
            year: year,
            month: month,
            calendar: calendar,
            businessDayService: businessDayService,
        )

        switch self {
        case let .fixed(day):
            return calendar.date(from: DateComponents(year: year, month: month, day: day))
        case .endOfMonth:
            return endOfMonthDate(year: year, month: month, calendar: calendar)
        case let .endOfMonthMinus(days):
            return endOfMonthMinusDate(context: context, days: days)
        case let .nthWeekday(week, weekday):
            return nthWeekdayDate(context: context, week: week, weekday: weekday)
        case let .lastWeekday(weekday):
            return lastWeekdayDate(year: year, month: month, weekday: weekday, calendar: calendar)
        case .firstBusinessDay, .lastBusinessDay, .nthBusinessDay, .lastBusinessDayMinus:
            return businessDayDate(year: year, month: month, businessDayService: businessDayService)
        }
    }

    private func businessDayDate(year: Int, month: Int, businessDayService: BusinessDayService) -> Date? {
        switch self {
        case .firstBusinessDay:
            businessDayService.firstBusinessDay(of: year, month: month)
        case .lastBusinessDay:
            businessDayService.lastBusinessDay(of: year, month: month)
        case let .nthBusinessDay(nth):
            businessDayService.nthBusinessDay(nth, of: year, month: month)
        case let .lastBusinessDayMinus(days):
            businessDayService.lastBusinessDayMinus(days: days, of: year, month: month)
        default:
            nil
        }
    }

    private func endOfMonthDate(year: Int, month: Int, calendar: Calendar) -> Date? {
        guard let firstDay = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstDay),
              let lastDay = calendar.date(byAdding: .day, value: -1, to: nextMonth) else {
            return nil
        }
        return lastDay
    }

    private func endOfMonthMinusDate(context: DateCalculationContext, days: Int) -> Date? {
        guard let endDate = DayOfMonthPattern.endOfMonth.date(
            in: context.year,
            month: context.month,
            calendar: context.calendar,
            businessDayService: context.businessDayService,
        ) else {
            return nil
        }
        return context.calendar.date(byAdding: .day, value: -days, to: endDate)
    }

    private func nthWeekdayDate(context: DateCalculationContext, week: Int, weekday: Weekday) -> Date? {
        var components = DateComponents()
        components.year = context.year
        components.month = context.month
        components.weekday = weekday.rawValue
        components.weekdayOrdinal = week
        return context.calendar.date(from: components)
    }

    private func lastWeekdayDate(year: Int, month: Int, weekday: Weekday, calendar: Calendar) -> Date? {
        guard let firstDay = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstDay) else {
            return nil
        }

        var current = nextMonth
        for _ in 0 ..< 7 {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: current) else {
                return nil
            }
            current = previous

            if calendar.component(.weekday, from: current) == weekday.rawValue {
                return current
            }
        }
        return nil
    }
}
