import Foundation
import Testing

@testable import Kakeibo

@Suite("DayOfMonthPattern - Business Day")
internal struct DayOfMonthPatternBusinessDayTests {
    private let calendar: Calendar = Calendar(identifier: .gregorian)
    private let service: BusinessDayService = BusinessDayService()

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
