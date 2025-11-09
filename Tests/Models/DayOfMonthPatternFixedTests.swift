import Foundation
import Testing

@testable import Kakeibo

@Suite("DayOfMonthPattern - Fixed & Month-End")
internal struct DayOfMonthPatternFixedTests {
    private let calendar: Calendar = Calendar(identifier: .gregorian)
    private let service: BusinessDayService = BusinessDayService()

    // MARK: - fixed Tests

    @Test("固定日：15日")
    internal func fixed_fifteenth() throws {
        let pattern = DayOfMonthPattern.fixed(15)
        let result = try #require(pattern.date(
            in: 2025,
            month: 1,
            calendar: calendar,
            businessDayService: service,
        ))
        let expected = try #require(Date.from(year: 2025, month: 1, day: 15))
        #expect(calendar.isDate(result, inSameDayAs: expected))
    }

    @Test("固定日：1日")
    internal func fixed_first() throws {
        let pattern = DayOfMonthPattern.fixed(1)
        let result = try #require(pattern.date(
            in: 2025,
            month: 2,
            calendar: calendar,
            businessDayService: service,
        ))
        let expected = try #require(Date.from(year: 2025, month: 2, day: 1))
        #expect(calendar.isDate(result, inSameDayAs: expected))
    }

    // MARK: - endOfMonth Tests

    @Test("月末：31日の月")
    internal func endOfMonth_31days() throws {
        let pattern = DayOfMonthPattern.endOfMonth
        let result = try #require(pattern.date(
            in: 2025,
            month: 1,
            calendar: calendar,
            businessDayService: service,
        ))
        let expected = try #require(Date.from(year: 2025, month: 1, day: 31))
        #expect(calendar.isDate(result, inSameDayAs: expected))
    }

    @Test("月末：30日の月")
    internal func endOfMonth_30days() throws {
        let pattern = DayOfMonthPattern.endOfMonth
        let result = try #require(pattern.date(
            in: 2025,
            month: 4,
            calendar: calendar,
            businessDayService: service,
        ))
        let expected = try #require(Date.from(year: 2025, month: 4, day: 30))
        #expect(calendar.isDate(result, inSameDayAs: expected))
    }

    @Test("月末：2月（平年）")
    internal func endOfMonth_february() throws {
        let pattern = DayOfMonthPattern.endOfMonth
        let result = try #require(pattern.date(
            in: 2025,
            month: 2,
            calendar: calendar,
            businessDayService: service,
        ))
        let expected = try #require(Date.from(year: 2025, month: 2, day: 28))
        #expect(calendar.isDate(result, inSameDayAs: expected))
    }

    @Test("月末：2月（閏年）")
    internal func endOfMonth_februaryLeapYear() throws {
        let pattern = DayOfMonthPattern.endOfMonth
        let result = try #require(pattern.date(
            in: 2024,
            month: 2,
            calendar: calendar,
            businessDayService: service,
        ))
        let expected = try #require(Date.from(year: 2024, month: 2, day: 29))
        #expect(calendar.isDate(result, inSameDayAs: expected))
    }

    // MARK: - endOfMonthMinus Tests

    @Test("月末3日前")
    internal func endOfMonthMinus_three() throws {
        let pattern = DayOfMonthPattern.endOfMonthMinus(days: 3)
        let result = try #require(pattern.date(
            in: 2025,
            month: 1,
            calendar: calendar,
            businessDayService: service,
        ))
        let expected = try #require(Date.from(year: 2025, month: 1, day: 28))
        #expect(calendar.isDate(result, inSameDayAs: expected))
    }

    @Test("月末5日前（30日の月）")
    internal func endOfMonthMinus_five_30days() throws {
        let pattern = DayOfMonthPattern.endOfMonthMinus(days: 5)
        let result = try #require(pattern.date(
            in: 2025,
            month: 4,
            calendar: calendar,
            businessDayService: service,
        ))
        let expected = try #require(Date.from(year: 2025, month: 4, day: 25))
        #expect(calendar.isDate(result, inSameDayAs: expected))
    }

    @Test("月末0日前は月末")
    internal func endOfMonthMinus_zero() throws {
        let pattern = DayOfMonthPattern.endOfMonthMinus(days: 0)
        let result = try #require(pattern.date(
            in: 2025,
            month: 1,
            calendar: calendar,
            businessDayService: service,
        ))
        let expected = try #require(Date.from(year: 2025, month: 1, day: 31))
        #expect(calendar.isDate(result, inSameDayAs: expected))
    }
}
