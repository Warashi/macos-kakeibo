import Foundation
import Testing

@testable import Kakeibo

@Suite("BusinessDayService")
internal struct BusinessDayServiceTests {
    private let calendar: Calendar = Calendar(identifier: .gregorian)
    private let service: BusinessDayService = BusinessDayService()

    // MARK: - isBusinessDay Tests

    @Test("平日（月曜日）は営業日")
    internal func isBusinessDay_monday() throws {
        // 2025-01-06は月曜日
        let date = try #require(Date.from(year: 2025, month: 1, day: 6))
        #expect(service.isBusinessDay(date))
    }

    @Test("平日（火曜日）は営業日")
    internal func isBusinessDay_tuesday() throws {
        // 2025-01-07は火曜日
        let date = try #require(Date.from(year: 2025, month: 1, day: 7))
        #expect(service.isBusinessDay(date))
    }

    @Test("平日（水曜日）は営業日")
    internal func isBusinessDay_wednesday() throws {
        // 2025-01-08は水曜日
        let date = try #require(Date.from(year: 2025, month: 1, day: 8))
        #expect(service.isBusinessDay(date))
    }

    @Test("平日（木曜日）は営業日")
    internal func isBusinessDay_thursday() throws {
        // 2025-01-09は木曜日
        let date = try #require(Date.from(year: 2025, month: 1, day: 9))
        #expect(service.isBusinessDay(date))
    }

    @Test("平日（金曜日）は営業日")
    internal func isBusinessDay_friday() throws {
        // 2025-01-10は金曜日
        let date = try #require(Date.from(year: 2025, month: 1, day: 10))
        #expect(service.isBusinessDay(date))
    }

    @Test("土曜日は営業日ではない")
    internal func isBusinessDay_saturday() throws {
        // 2025-01-04は土曜日
        let date = try #require(Date.from(year: 2025, month: 1, day: 4))
        #expect(!service.isBusinessDay(date))
    }

    @Test("日曜日は営業日ではない")
    internal func isBusinessDay_sunday() throws {
        // 2025-01-05は日曜日
        let date = try #require(Date.from(year: 2025, month: 1, day: 5))
        #expect(!service.isBusinessDay(date))
    }

    // MARK: - previousBusinessDay Tests

    @Test("金曜日の前営業日は木曜日")
    internal func previousBusinessDay_friday() throws {
        let friday = try #require(Date.from(year: 2025, month: 1, day: 10))
        let previous = try #require(service.previousBusinessDay(from: friday))
        let thursday = try #require(Date.from(year: 2025, month: 1, day: 9))
        #expect(calendar.isDate(previous, inSameDayAs: thursday))
    }

    @Test("月曜日の前営業日は金曜日（週末をスキップ）")
    internal func previousBusinessDay_monday() throws {
        let monday = try #require(Date.from(year: 2025, month: 1, day: 6))
        let previous = try #require(service.previousBusinessDay(from: monday))
        let friday = try #require(Date.from(year: 2025, month: 1, day: 3))
        #expect(calendar.isDate(previous, inSameDayAs: friday))
    }

    @Test("日曜日の前営業日は金曜日")
    internal func previousBusinessDay_sunday() throws {
        let sunday = try #require(Date.from(year: 2025, month: 1, day: 5))
        let previous = try #require(service.previousBusinessDay(from: sunday))
        let friday = try #require(Date.from(year: 2025, month: 1, day: 3))
        #expect(calendar.isDate(previous, inSameDayAs: friday))
    }

    @Test("土曜日の前営業日は金曜日")
    internal func previousBusinessDay_saturday() throws {
        let saturday = try #require(Date.from(year: 2025, month: 1, day: 4))
        let previous = try #require(service.previousBusinessDay(from: saturday))
        let friday = try #require(Date.from(year: 2025, month: 1, day: 3))
        #expect(calendar.isDate(previous, inSameDayAs: friday))
    }

    // MARK: - nextBusinessDay Tests

    @Test("金曜日の次営業日は月曜日（週末をスキップ）")
    internal func nextBusinessDay_friday() throws {
        let friday = try #require(Date.from(year: 2025, month: 1, day: 3))
        let next = try #require(service.nextBusinessDay(from: friday))
        let monday = try #require(Date.from(year: 2025, month: 1, day: 6))
        #expect(calendar.isDate(next, inSameDayAs: monday))
    }

    @Test("木曜日の次営業日は金曜日")
    internal func nextBusinessDay_thursday() throws {
        let thursday = try #require(Date.from(year: 2025, month: 1, day: 9))
        let next = try #require(service.nextBusinessDay(from: thursday))
        let friday = try #require(Date.from(year: 2025, month: 1, day: 10))
        #expect(calendar.isDate(next, inSameDayAs: friday))
    }

    @Test("土曜日の次営業日は月曜日")
    internal func nextBusinessDay_saturday() throws {
        let saturday = try #require(Date.from(year: 2025, month: 1, day: 4))
        let next = try #require(service.nextBusinessDay(from: saturday))
        let monday = try #require(Date.from(year: 2025, month: 1, day: 6))
        #expect(calendar.isDate(next, inSameDayAs: monday))
    }

    @Test("日曜日の次営業日は月曜日")
    internal func nextBusinessDay_sunday() throws {
        let sunday = try #require(Date.from(year: 2025, month: 1, day: 5))
        let next = try #require(service.nextBusinessDay(from: sunday))
        let monday = try #require(Date.from(year: 2025, month: 1, day: 6))
        #expect(calendar.isDate(next, inSameDayAs: monday))
    }

    // MARK: - firstBusinessDay Tests

    @Test("月初が平日の場合、最初の営業日は1日")
    internal func firstBusinessDay_startsOnWeekday() throws {
        // 2025-01-01は水曜日
        let first = try #require(service.firstBusinessDay(of: 2025, month: 1))
        let expected = try #require(Date.from(year: 2025, month: 1, day: 1))
        #expect(calendar.isDate(first, inSameDayAs: expected))
    }

    @Test("月初が土曜日の場合、最初の営業日は月曜日")
    internal func firstBusinessDay_startsOnSaturday() throws {
        // 2025-02-01は土曜日
        let first = try #require(service.firstBusinessDay(of: 2025, month: 2))
        let expected = try #require(Date.from(year: 2025, month: 2, day: 3))
        #expect(calendar.isDate(first, inSameDayAs: expected))
    }

    @Test("月初が日曜日の場合、最初の営業日は月曜日")
    internal func firstBusinessDay_startsOnSunday() throws {
        // 2025-06-01は日曜日
        let first = try #require(service.firstBusinessDay(of: 2025, month: 6))
        let expected = try #require(Date.from(year: 2025, month: 6, day: 2))
        #expect(calendar.isDate(first, inSameDayAs: expected))
    }

    // MARK: - lastBusinessDay Tests

    @Test("月末が平日の場合、最終営業日は月末")
    internal func lastBusinessDay_endsOnWeekday() throws {
        // 2025-01-31は金曜日
        let last = try #require(service.lastBusinessDay(of: 2025, month: 1))
        let expected = try #require(Date.from(year: 2025, month: 1, day: 31))
        #expect(calendar.isDate(last, inSameDayAs: expected))
    }

    @Test("月末が土曜日の場合、最終営業日は金曜日")
    internal func lastBusinessDay_endsOnSaturday() throws {
        // 2025-03-31は月曜日（確認必要）、2025-05-31は土曜日
        let last = try #require(service.lastBusinessDay(of: 2025, month: 5))
        let expected = try #require(Date.from(year: 2025, month: 5, day: 30))
        #expect(calendar.isDate(last, inSameDayAs: expected))
    }

    @Test("月末が日曜日の場合、最終営業日は金曜日")
    internal func lastBusinessDay_endsOnSunday() throws {
        // 2025-08-31は日曜日
        let last = try #require(service.lastBusinessDay(of: 2025, month: 8))
        let expected = try #require(Date.from(year: 2025, month: 8, day: 29))
        #expect(calendar.isDate(last, inSameDayAs: expected))
    }

    // MARK: - nthBusinessDay Tests

    @Test("1番目の営業日")
    internal func nthBusinessDay_first() throws {
        // 2025-01-01は水曜日
        let first = try #require(service.nthBusinessDay(1, of: 2025, month: 1))
        let expected = try #require(Date.from(year: 2025, month: 1, day: 1))
        #expect(calendar.isDate(first, inSameDayAs: expected))
    }

    @Test("5番目の営業日")
    internal func nthBusinessDay_fifth() throws {
        // 2025-01: 1(水), 2(木), 3(金), 6(月), 7(火) = 5営業日目
        let fifth = try #require(service.nthBusinessDay(5, of: 2025, month: 1))
        let expected = try #require(Date.from(year: 2025, month: 1, day: 7))
        #expect(calendar.isDate(fifth, inSameDayAs: expected))
    }

    @Test("10番目の営業日")
    internal func nthBusinessDay_tenth() throws {
        // 2025-01: 1-3(3日), 6-10(5日), 13-14(2日) = 10営業日目
        let tenth = try #require(service.nthBusinessDay(10, of: 2025, month: 1))
        let expected = try #require(Date.from(year: 2025, month: 1, day: 14))
        #expect(calendar.isDate(tenth, inSameDayAs: expected))
    }

    @Test("月初が週末の場合のN番目の営業日")
    internal func nthBusinessDay_startsOnWeekend() throws {
        // 2025-02-01は土曜日、3(月)が1営業日目、4(火)が2営業日目
        let second = try #require(service.nthBusinessDay(2, of: 2025, month: 2))
        let expected = try #require(Date.from(year: 2025, month: 2, day: 4))
        #expect(calendar.isDate(second, inSameDayAs: expected))
    }

    @Test("存在しないN番目の営業日はnil")
    internal func nthBusinessDay_tooLarge() throws {
        // 1ヶ月に100営業日はない
        let result = service.nthBusinessDay(100, of: 2025, month: 1)
        #expect(result == nil)
    }

    @Test("0番目の営業日はnil")
    internal func nthBusinessDay_zero() throws {
        let result = service.nthBusinessDay(0, of: 2025, month: 1)
        #expect(result == nil)
    }

    @Test("負の番号の営業日はnil")
    internal func nthBusinessDay_negative() throws {
        let result = service.nthBusinessDay(-1, of: 2025, month: 1)
        #expect(result == nil)
    }

    // MARK: - lastBusinessDayMinus Tests

    @Test("最終営業日の0営業日前は最終営業日")
    internal func lastBusinessDayMinus_zero() throws {
        // 2025-01-31は金曜日
        let result = try #require(service.lastBusinessDayMinus(days: 0, of: 2025, month: 1))
        let expected = try #require(Date.from(year: 2025, month: 1, day: 31))
        #expect(calendar.isDate(result, inSameDayAs: expected))
    }

    @Test("最終営業日の1営業日前")
    internal func lastBusinessDayMinus_one() throws {
        // 2025-01-31は金曜日、30は木曜日
        let result = try #require(service.lastBusinessDayMinus(days: 1, of: 2025, month: 1))
        let expected = try #require(Date.from(year: 2025, month: 1, day: 30))
        #expect(calendar.isDate(result, inSameDayAs: expected))
    }

    @Test("最終営業日の3営業日前")
    internal func lastBusinessDayMinus_three() throws {
        // 2025-01-31(金), 30(木), 29(水), 28(火) = 3営業日前
        let result = try #require(service.lastBusinessDayMinus(days: 3, of: 2025, month: 1))
        let expected = try #require(Date.from(year: 2025, month: 1, day: 28))
        #expect(calendar.isDate(result, inSameDayAs: expected))
    }

    @Test("月末が週末の場合の最終営業日前N営業日")
    internal func lastBusinessDayMinus_endsOnWeekend() throws {
        // 2025-08-31は日曜日、最終営業日は29(金)、2営業日前は27(水)
        let result = try #require(service.lastBusinessDayMinus(days: 2, of: 2025, month: 8))
        let expected = try #require(Date.from(year: 2025, month: 8, day: 27))
        #expect(calendar.isDate(result, inSameDayAs: expected))
    }

    @Test("負の営業日数はnil")
    internal func lastBusinessDayMinus_negative() throws {
        let result = service.lastBusinessDayMinus(days: -1, of: 2025, month: 1)
        #expect(result == nil)
    }

    // MARK: - HolidayProvider統合テスト

    @Test("日本の祝日プロバイダーを使用して営業日判定ができる")
    internal func testCanDetermineBusinessDaysUsingJapaneseHolidayProvider() throws {
        let japaneseProvider = JapaneseHolidayProvider(calendar: calendar)
        let serviceWithHolidays = BusinessDayService(holidayProvider: japaneseProvider)

        // 2025-01-01（元日）は祝日なので営業日ではない
        let newYearsDay = try #require(Date.from(year: 2025, month: 1, day: 1))
        #expect(!serviceWithHolidays.isBusinessDay(newYearsDay))

        // 2025-01-02（木曜日）は営業日
        let january2 = try #require(Date.from(year: 2025, month: 1, day: 2))
        #expect(serviceWithHolidays.isBusinessDay(january2))
    }

    @Test("祝日プロバイダーを使用した営業日計算")
    internal func testBusinessDayCalculationUsingHolidayProvider() throws {
        let japaneseProvider = JapaneseHolidayProvider(calendar: calendar)
        let serviceWithHolidays = BusinessDayService(holidayProvider: japaneseProvider)

        // 2025-01-01（元日、水曜日）の次の営業日は1/2（木曜日）
        let newYearsDay = try #require(Date.from(year: 2025, month: 1, day: 1))
        let nextBusinessDay = try #require(serviceWithHolidays.nextBusinessDay(from: newYearsDay))
        let expected = try #require(Date.from(year: 2025, month: 1, day: 2))
        #expect(calendar.isDate(nextBusinessDay, inSameDayAs: expected))
    }

    @Test("ゴールデンウィークの営業日計算")
    internal func testBusinessDayCalculationDuringGoldenWeek() throws {
        let japaneseProvider = JapaneseHolidayProvider(calendar: calendar)
        let serviceWithHolidays = BusinessDayService(holidayProvider: japaneseProvider)

        // 2025-05-03（憲法記念日、土曜日）から次の営業日を取得
        let constitutionDay = try #require(Date.from(year: 2025, month: 5, day: 3))
        let nextBusinessDay = try #require(serviceWithHolidays.nextBusinessDay(from: constitutionDay))

        // 5/3(土), 5/4(日・みどりの日), 5/5(月・こどもの日), 5/6(火・振替休日)を飛ばして5/7(水)
        let expected = try #require(Date.from(year: 2025, month: 5, day: 7))
        #expect(calendar.isDate(nextBusinessDay, inSameDayAs: expected))
    }

    @Test("直接指定された祝日とプロバイダーの祝日が両方適用される")
    internal func testBothDirectHolidaysAndProviderHolidaysAreApplied() throws {
        let japaneseProvider = JapaneseHolidayProvider(calendar: calendar)

        // 直接指定の祝日（会社独自の休日）
        let companyHoliday = try #require(Date.from(year: 2025, month: 6, day: 15))
        let holidays: Set<Date> = [calendar.startOfDay(for: companyHoliday)]

        let serviceWithBoth = BusinessDayService(holidays: holidays, holidayProvider: japaneseProvider)

        // 日本の祝日（元日）は営業日ではない
        let newYearsDay = try #require(Date.from(year: 2025, month: 1, day: 1))
        #expect(!serviceWithBoth.isBusinessDay(newYearsDay))

        // 会社独自の休日も営業日ではない
        #expect(!serviceWithBoth.isBusinessDay(companyHoliday))

        // 通常の平日は営業日
        let normalDay = try #require(Date.from(year: 2025, month: 6, day: 16))
        #expect(serviceWithBoth.isBusinessDay(normalDay))
    }
}
