import Foundation

/// 予算画面のナビゲーション状態をまとめるヘルパ
internal struct BudgetNavigationState {
    internal private(set) var year: Int
    internal private(set) var month: Int
    private let currentDateProvider: () -> Date

    internal init(
        year: Int,
        month: Int,
        currentDateProvider: @escaping () -> Date,
    ) {
        self.year = year
        self.month = month
        self.currentDateProvider = currentDateProvider
    }

    @discardableResult
    internal mutating func moveToPreviousMonth() -> Bool {
        updateNavigator { $0.moveToPreviousMonth() }
    }

    @discardableResult
    internal mutating func moveToNextMonth() -> Bool {
        updateNavigator { $0.moveToNextMonth() }
    }

    @discardableResult
    internal mutating func moveToCurrentMonth() -> Bool {
        updateNavigator { $0.moveToCurrentMonth() }
    }

    @discardableResult
    internal mutating func moveToPreviousYear() -> Bool {
        updateNavigator { $0.moveToPreviousYear() }
    }

    @discardableResult
    internal mutating func moveToNextYear() -> Bool {
        updateNavigator { $0.moveToNextYear() }
    }

    @discardableResult
    internal mutating func moveToCurrentYear() -> Bool {
        updateNavigator { $0.moveToCurrentYear() }
    }

    @discardableResult
    internal mutating func moveToPresent(displayMode: BudgetStore.DisplayMode) -> Bool {
        switch displayMode {
        case .monthly:
            moveToCurrentMonth()
        case .annual:
            moveToCurrentYear()
        case .specialPaymentsList:
            false
        }
    }

    private mutating func updateNavigator(_ update: (inout MonthNavigator) -> Void) -> Bool {
        let beforeYear = year
        let beforeMonth = month

        var navigator = MonthNavigator(
            year: year,
            month: month,
            currentDateProvider: currentDateProvider,
        )
        update(&navigator)
        year = navigator.year
        month = navigator.month

        return beforeYear != year || beforeMonth != month
    }
}
