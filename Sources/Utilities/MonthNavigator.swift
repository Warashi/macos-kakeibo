import Foundation

/// 年月のナビゲーションを共通化するユーティリティ
internal struct MonthNavigator {
    private let calendar: Calendar
    private let currentDateProvider: () -> Date

    internal private(set) var year: Int
    internal private(set) var month: Int

    internal init(
        year: Int,
        month: Int,
        calendar: Calendar = .current,
        currentDateProvider: @escaping () -> Date = Date.init
    ) {
        precondition((1 ... 12).contains(month), "month must be between 1 and 12")
        self.year = year
        self.month = month
        self.calendar = calendar
        self.currentDateProvider = currentDateProvider
    }

    internal init(
        date: Date = Date(),
        calendar: Calendar = .current,
        currentDateProvider: @escaping () -> Date = Date.init
    ) {
        let components = calendar.dateComponents([.year, .month], from: date)
        let resolvedYear = components.year ?? calendar.component(.year, from: currentDateProvider())
        let resolvedMonth = components.month ?? calendar.component(.month, from: currentDateProvider())
        self.init(
            year: resolvedYear,
            month: resolvedMonth,
            calendar: calendar,
            currentDateProvider: currentDateProvider
        )
    }

    internal mutating func moveToPreviousMonth() {
        if month == 1 {
            month = 12
            year -= 1
        } else {
            month -= 1
        }
    }

    internal mutating func moveToNextMonth() {
        if month == 12 {
            month = 1
            year += 1
        } else {
            month += 1
        }
    }

    internal mutating func moveToCurrentMonth() {
        let now = currentDateProvider()
        let components = calendar.dateComponents([.year, .month], from: now)
        year = components.year ?? year
        month = components.month ?? month
    }

    internal mutating func moveToPreviousYear() {
        year -= 1
    }

    internal mutating func moveToNextYear() {
        year += 1
    }

    internal mutating func moveToCurrentYear() {
        year = calendar.component(.year, from: currentDateProvider())
    }
}

/// Dateベースの状態とMonthNavigatorを橋渡しするアダプタ
internal struct MonthNavigatorDateAdapter {
    private let calendar: Calendar

    internal init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    internal func makeNavigator(
        from date: Date,
        currentDateProvider: @escaping () -> Date = Date.init
    ) -> MonthNavigator {
        MonthNavigator(
            date: date,
            calendar: calendar,
            currentDateProvider: currentDateProvider
        )
    }

    internal func date(from navigator: MonthNavigator) -> Date? {
        var components = DateComponents()
        components.year = navigator.year
        components.month = navigator.month
        components.day = 1
        return calendar.date(from: components)
    }
}
