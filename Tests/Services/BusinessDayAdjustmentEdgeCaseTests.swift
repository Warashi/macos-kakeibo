import Foundation
import Testing

@testable import Kakeibo

@Suite("BusinessDayAdjustment Edge Case Tests")
internal struct BusinessDayAdjustmentEdgeCaseTests {
    @Test("週末（土曜日）の場合 - 前営業日は金曜日")
    internal func testWeekendSaturdayPrevious() {
        // 2025年1月4日は土曜日
        let businessDayService = BusinessDayService()
        let calculator = MonthPeriodCalculator(
            monthStartDay: 4,
            monthStartDayAdjustment: .previous,
            businessDayService: businessDayService
        )

        let period = calculator.calculatePeriod(for: 2025, month: 1)
        #expect(period != nil)

        guard let (start, _) = period else { return }

        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.year, .month, .day, .weekday], from: start)

        // 1月3日（金曜日）に調整される
        #expect(startComponents.day == 3)
        #expect(startComponents.weekday == 6) // 金曜日
    }

    @Test("週末（土曜日）の場合 - 次営業日は月曜日")
    internal func testWeekendSaturdayNext() {
        // 2025年1月4日は土曜日
        let businessDayService = BusinessDayService()
        let calculator = MonthPeriodCalculator(
            monthStartDay: 4,
            monthStartDayAdjustment: .next,
            businessDayService: businessDayService
        )

        let period = calculator.calculatePeriod(for: 2025, month: 1)
        #expect(period != nil)

        guard let (start, _) = period else { return }

        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.year, .month, .day, .weekday], from: start)

        // 1月6日（月曜日）に調整される
        #expect(startComponents.day == 6)
        #expect(startComponents.weekday == 2) // 月曜日
    }

    @Test("週末（日曜日）の場合 - 前営業日は金曜日")
    internal func testWeekendSundayPrevious() {
        // 2025年1月5日は日曜日
        let businessDayService = BusinessDayService()
        let calculator = MonthPeriodCalculator(
            monthStartDay: 5,
            monthStartDayAdjustment: .previous,
            businessDayService: businessDayService
        )

        let period = calculator.calculatePeriod(for: 2025, month: 1)
        #expect(period != nil)

        guard let (start, _) = period else { return }

        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.year, .month, .day, .weekday], from: start)

        // 1月3日（金曜日）に調整される
        #expect(startComponents.day == 3)
        #expect(startComponents.weekday == 6) // 金曜日
    }

    @Test("週末（日曜日）の場合 - 次営業日は月曜日")
    internal func testWeekendSundayNext() {
        // 2025年1月5日は日曜日
        let businessDayService = BusinessDayService()
        let calculator = MonthPeriodCalculator(
            monthStartDay: 5,
            monthStartDayAdjustment: .next,
            businessDayService: businessDayService
        )

        let period = calculator.calculatePeriod(for: 2025, month: 1)
        #expect(period != nil)

        guard let (start, _) = period else { return }

        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.year, .month, .day, .weekday], from: start)

        // 1月6日（月曜日）に調整される
        #expect(startComponents.day == 6)
        #expect(startComponents.weekday == 2) // 月曜日
    }

    @Test("3連休（元日・土日）の場合 - 前営業日")
    internal func testThreeDayWeekendPrevious() {
        // 2025年1月1日（水）は元日、4日（土）、5日（日）が連休
        let calendar = Calendar(identifier: .gregorian)
        var holidays = Set<Date>()
        if let newYear = calendar.date(from: DateComponents(year: 2025, month: 1, day: 1)) {
            holidays.insert(calendar.startOfDay(for: newYear))
        }

        let businessDayService = BusinessDayService(holidays: holidays)
        let calculator = MonthPeriodCalculator(
            monthStartDay: 4, // 土曜日
            monthStartDayAdjustment: .previous,
            businessDayService: businessDayService
        )

        let period = calculator.calculatePeriod(for: 2025, month: 1)
        #expect(period != nil)

        guard let (start, _) = period else { return }

        let startComponents = calendar.dateComponents([.year, .month, .day], from: start)

        // 1月3日（金曜日）に調整される
        #expect(startComponents.day == 3)
    }

    @Test("3連休（元日・土日）の場合 - 次営業日")
    internal func testThreeDayWeekendNext() {
        // 2025年1月1日（水）は元日、4日（土）、5日（日）が連休
        let calendar = Calendar(identifier: .gregorian)
        var holidays = Set<Date>()
        if let newYear = calendar.date(from: DateComponents(year: 2025, month: 1, day: 1)) {
            holidays.insert(calendar.startOfDay(for: newYear))
        }

        let businessDayService = BusinessDayService(holidays: holidays)
        let calculator = MonthPeriodCalculator(
            monthStartDay: 4, // 土曜日
            monthStartDayAdjustment: .next,
            businessDayService: businessDayService
        )

        let period = calculator.calculatePeriod(for: 2025, month: 1)
        #expect(period != nil)

        guard let (start, _) = period else { return }

        let startComponents = calendar.dateComponents([.year, .month, .day], from: start)

        // 1月6日（月曜日）に調整される
        #expect(startComponents.day == 6)
    }

    @Test("2月（短い月）の場合 - 28日開始でも正常に動作")
    internal func testFebruaryShortMonth() {
        let businessDayService = BusinessDayService()
        let calculator = MonthPeriodCalculator(
            monthStartDay: 28,
            monthStartDayAdjustment: .none,
            businessDayService: businessDayService
        )

        // 2025年2月は28日まで
        let period = calculator.calculatePeriod(for: 2025, month: 2)
        #expect(period != nil)

        guard let (start, end) = period else { return }

        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.year, .month, .day], from: start)
        let endComponents = calendar.dateComponents([.year, .month, .day], from: end)

        #expect(startComponents.year == 2025)
        #expect(startComponents.month == 2)
        #expect(startComponents.day == 28)

        #expect(endComponents.year == 2025)
        #expect(endComponents.month == 3)
        #expect(endComponents.day == 28)
    }

    @Test("うるう年の2月 - 29日が存在する年")
    internal func testLeapYearFebruary() {
        let businessDayService = BusinessDayService()
        let calculator = MonthPeriodCalculator(
            monthStartDay: 28,
            monthStartDayAdjustment: .none,
            businessDayService: businessDayService
        )

        // 2024年はうるう年（2月29日まで）
        let period = calculator.calculatePeriod(for: 2024, month: 2)
        #expect(period != nil)

        guard let (start, end) = period else { return }

        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: start, to: end)

        // 2月28日から3月28日までなので、29日間
        #expect(components.day == 29)
    }

    @Test("月末が週末の場合 - 前営業日調整")
    internal func testMonthEndWeekendPrevious() {
        // 2025年3月29日は土曜日
        let businessDayService = BusinessDayService()
        let calculator = MonthPeriodCalculator(
            monthStartDay: 29,
            monthStartDayAdjustment: .previous,
            businessDayService: businessDayService
        )

        let period = calculator.calculatePeriod(for: 2025, month: 3)
        #expect(period != nil)

        guard let (start, _) = period else { return }

        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.year, .month, .day], from: start)

        // 3月28日（金曜日）に調整される
        #expect(startComponents.day == 28)
    }

    @Test("連続する祝日（ゴールデンウィーク風）のシミュレーション")
    internal func testConsecutiveHolidays() {
        // 5月1日〜5日を連続休日と仮定
        let calendar = Calendar(identifier: .gregorian)
        var holidays = Set<Date>()
        for day in 1 ... 5 {
            if let holiday = calendar.date(from: DateComponents(year: 2025, month: 5, day: day)) {
                holidays.insert(calendar.startOfDay(for: holiday))
            }
        }

        let businessDayService = BusinessDayService(holidays: holidays)
        let calculator = MonthPeriodCalculator(
            monthStartDay: 3, // 連休の真ん中
            monthStartDayAdjustment: .previous,
            businessDayService: businessDayService
        )

        let period = calculator.calculatePeriod(for: 2025, month: 5)
        #expect(period != nil)

        guard let (start, _) = period else { return }

        let startComponents = calendar.dateComponents([.year, .month, .day], from: start)

        // 4月30日（水曜日）に調整される
        #expect(startComponents.year == 2025)
        #expect(startComponents.month == 4)
        #expect(startComponents.day == 30)
    }
}
