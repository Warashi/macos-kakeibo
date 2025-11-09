import Foundation
import Testing

@testable import Kakeibo

@Suite("DayOfMonthPattern - Weekday")
internal struct DayOfMonthPatternWeekdayTests {
    private let calendar: Calendar = Calendar(identifier: .gregorian)
    private let service: BusinessDayService = BusinessDayService()

    // MARK: - nthWeekday Tests

    @Test("第1水曜日")
    internal func nthWeekday_firstWednesday() throws {
        let pattern = DayOfMonthPattern.nthWeekday(week: 1, weekday: .wednesday)
        let result = try #require(pattern.date(
            in: 2025,
            month: 1,
            calendar: calendar,
            businessDayService: service,
        ))
        let expected = try #require(Date.from(year: 2025, month: 1, day: 1))
        #expect(calendar.isDate(result, inSameDayAs: expected))
    }

    @Test("第2水曜日")
    internal func nthWeekday_secondWednesday() throws {
        let pattern = DayOfMonthPattern.nthWeekday(week: 2, weekday: .wednesday)
        let result = try #require(pattern.date(
            in: 2025,
            month: 1,
            calendar: calendar,
            businessDayService: service,
        ))
        let expected = try #require(Date.from(year: 2025, month: 1, day: 8))
        #expect(calendar.isDate(result, inSameDayAs: expected))
    }

    @Test("第3金曜日")
    internal func nthWeekday_thirdFriday() throws {
        let pattern = DayOfMonthPattern.nthWeekday(week: 3, weekday: .friday)
        let result = try #require(pattern.date(
            in: 2025,
            month: 1,
            calendar: calendar,
            businessDayService: service,
        ))
        let expected = try #require(Date.from(year: 2025, month: 1, day: 17))
        #expect(calendar.isDate(result, inSameDayAs: expected))
    }

    @Test("第1月曜日")
    internal func nthWeekday_firstMonday() throws {
        let pattern = DayOfMonthPattern.nthWeekday(week: 1, weekday: .monday)
        let result = try #require(pattern.date(
            in: 2025,
            month: 1,
            calendar: calendar,
            businessDayService: service,
        ))
        let expected = try #require(Date.from(year: 2025, month: 1, day: 6))
        #expect(calendar.isDate(result, inSameDayAs: expected))
    }

    // MARK: - lastWeekday Tests

    @Test("最終金曜日")
    internal func lastWeekday_friday() throws {
        let pattern = DayOfMonthPattern.lastWeekday(.friday)
        let result = try #require(pattern.date(
            in: 2025,
            month: 1,
            calendar: calendar,
            businessDayService: service,
        ))
        let expected = try #require(Date.from(year: 2025, month: 1, day: 31))
        #expect(calendar.isDate(result, inSameDayAs: expected))
    }

    @Test("最終月曜日")
    internal func lastWeekday_monday() throws {
        let pattern = DayOfMonthPattern.lastWeekday(.monday)
        let result = try #require(pattern.date(
            in: 2025,
            month: 1,
            calendar: calendar,
            businessDayService: service,
        ))
        let expected = try #require(Date.from(year: 2025, month: 1, day: 27))
        #expect(calendar.isDate(result, inSameDayAs: expected))
    }

    @Test("最終日曜日")
    internal func lastWeekday_sunday() throws {
        let pattern = DayOfMonthPattern.lastWeekday(.sunday)
        let result = try #require(pattern.date(
            in: 2025,
            month: 2,
            calendar: calendar,
            businessDayService: service,
        ))
        let expected = try #require(Date.from(year: 2025, month: 2, day: 23))
        #expect(calendar.isDate(result, inSameDayAs: expected))
    }
}
