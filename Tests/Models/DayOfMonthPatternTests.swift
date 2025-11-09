import Foundation
import Testing

@testable import Kakeibo

@Suite("DayOfMonthPattern")
internal struct DayOfMonthPatternTests {
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

    // MARK: - firstBusinessDay Tests

    @Test("最初の営業日（月初が平日）")
    internal func firstBusinessDay_startsOnWeekday() throws {
        let pattern = DayOfMonthPattern.firstBusinessDay
        let result = try #require(pattern.date(
            in: 2025,
            month: 1,
            calendar: calendar,
            businessDayService: service,
        ))
        let expected = try #require(Date.from(year: 2025, month: 1, day: 1))
        #expect(calendar.isDate(result, inSameDayAs: expected))
    }

    @Test("最初の営業日（月初が土曜日）")
    internal func firstBusinessDay_startsOnSaturday() throws {
        let pattern = DayOfMonthPattern.firstBusinessDay
        let result = try #require(pattern.date(
            in: 2025,
            month: 2,
            calendar: calendar,
            businessDayService: service,
        ))
        let expected = try #require(Date.from(year: 2025, month: 2, day: 3))
        #expect(calendar.isDate(result, inSameDayAs: expected))
    }

    @Test("最初の営業日（月初が日曜日）")
    internal func firstBusinessDay_startsOnSunday() throws {
        let pattern = DayOfMonthPattern.firstBusinessDay
        let result = try #require(pattern.date(
            in: 2025,
            month: 6,
            calendar: calendar,
            businessDayService: service,
        ))
        let expected = try #require(Date.from(year: 2025, month: 6, day: 2))
        #expect(calendar.isDate(result, inSameDayAs: expected))
    }

    // MARK: - lastBusinessDay Tests

    @Test("最終営業日（月末が平日）")
    internal func lastBusinessDay_endsOnWeekday() throws {
        let pattern = DayOfMonthPattern.lastBusinessDay
        let result = try #require(pattern.date(
            in: 2025,
            month: 1,
            calendar: calendar,
            businessDayService: service,
        ))
        let expected = try #require(Date.from(year: 2025, month: 1, day: 31))
        #expect(calendar.isDate(result, inSameDayAs: expected))
    }

    @Test("最終営業日（月末が土曜日）")
    internal func lastBusinessDay_endsOnSaturday() throws {
        let pattern = DayOfMonthPattern.lastBusinessDay
        let result = try #require(pattern.date(
            in: 2025,
            month: 5,
            calendar: calendar,
            businessDayService: service,
        ))
        let expected = try #require(Date.from(year: 2025, month: 5, day: 30))
        #expect(calendar.isDate(result, inSameDayAs: expected))
    }

    @Test("最終営業日（月末が日曜日）")
    internal func lastBusinessDay_endsOnSunday() throws {
        let pattern = DayOfMonthPattern.lastBusinessDay
        let result = try #require(pattern.date(
            in: 2025,
            month: 8,
            calendar: calendar,
            businessDayService: service,
        ))
        let expected = try #require(Date.from(year: 2025, month: 8, day: 29))
        #expect(calendar.isDate(result, inSameDayAs: expected))
    }

    // MARK: - nthBusinessDay Tests

    @Test("1番目の営業日")
    internal func nthBusinessDay_first() throws {
        let pattern = DayOfMonthPattern.nthBusinessDay(1)
        let result = try #require(pattern.date(
            in: 2025,
            month: 1,
            calendar: calendar,
            businessDayService: service,
        ))
        let expected = try #require(Date.from(year: 2025, month: 1, day: 1))
        #expect(calendar.isDate(result, inSameDayAs: expected))
    }

    @Test("5番目の営業日")
    internal func nthBusinessDay_fifth() throws {
        let pattern = DayOfMonthPattern.nthBusinessDay(5)
        let result = try #require(pattern.date(
            in: 2025,
            month: 1,
            calendar: calendar,
            businessDayService: service,
        ))
        let expected = try #require(Date.from(year: 2025, month: 1, day: 7))
        #expect(calendar.isDate(result, inSameDayAs: expected))
    }

    @Test("10番目の営業日")
    internal func nthBusinessDay_tenth() throws {
        let pattern = DayOfMonthPattern.nthBusinessDay(10)
        let result = try #require(pattern.date(
            in: 2025,
            month: 1,
            calendar: calendar,
            businessDayService: service,
        ))
        let expected = try #require(Date.from(year: 2025, month: 1, day: 14))
        #expect(calendar.isDate(result, inSameDayAs: expected))
    }

    @Test("月初が週末の場合のN番目の営業日")
    internal func nthBusinessDay_startsOnWeekend() throws {
        let pattern = DayOfMonthPattern.nthBusinessDay(2)
        let result = try #require(pattern.date(
            in: 2025,
            month: 2,
            calendar: calendar,
            businessDayService: service,
        ))
        let expected = try #require(Date.from(year: 2025, month: 2, day: 4))
        #expect(calendar.isDate(result, inSameDayAs: expected))
    }

    // MARK: - lastBusinessDayMinus Tests

    @Test("最終営業日の0営業日前")
    internal func lastBusinessDayMinus_zero() throws {
        let pattern = DayOfMonthPattern.lastBusinessDayMinus(days: 0)
        let result = try #require(pattern.date(
            in: 2025,
            month: 1,
            calendar: calendar,
            businessDayService: service,
        ))
        let expected = try #require(Date.from(year: 2025, month: 1, day: 31))
        #expect(calendar.isDate(result, inSameDayAs: expected))
    }

    @Test("最終営業日の1営業日前")
    internal func lastBusinessDayMinus_one() throws {
        let pattern = DayOfMonthPattern.lastBusinessDayMinus(days: 1)
        let result = try #require(pattern.date(
            in: 2025,
            month: 1,
            calendar: calendar,
            businessDayService: service,
        ))
        let expected = try #require(Date.from(year: 2025, month: 1, day: 30))
        #expect(calendar.isDate(result, inSameDayAs: expected))
    }

    @Test("最終営業日の3営業日前")
    internal func lastBusinessDayMinus_three() throws {
        let pattern = DayOfMonthPattern.lastBusinessDayMinus(days: 3)
        let result = try #require(pattern.date(
            in: 2025,
            month: 1,
            calendar: calendar,
            businessDayService: service,
        ))
        let expected = try #require(Date.from(year: 2025, month: 1, day: 28))
        #expect(calendar.isDate(result, inSameDayAs: expected))
    }

    @Test("月末が週末の場合の最終営業日前N営業日")
    internal func lastBusinessDayMinus_endsOnWeekend() throws {
        let pattern = DayOfMonthPattern.lastBusinessDayMinus(days: 2)
        let result = try #require(pattern.date(
            in: 2025,
            month: 8,
            calendar: calendar,
            businessDayService: service,
        ))
        let expected = try #require(Date.from(year: 2025, month: 8, day: 27))
        #expect(calendar.isDate(result, inSameDayAs: expected))
    }
}
