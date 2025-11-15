import Foundation
import Testing

@testable import Kakeibo

@Suite("BusinessDayService - HolidayProvider Integration")
internal struct BusinessDayServiceHolidayProviderTests {
    private let calendar: Calendar = Calendar(identifier: .gregorian)

    @Test("日本の祝日プロバイダーを使用して営業日判定ができる")
    internal func canDetermineBusinessDaysUsingJapaneseHolidayProvider() throws {
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
    internal func businessDayCalculationUsingHolidayProvider() throws {
        let japaneseProvider = JapaneseHolidayProvider(calendar: calendar)
        let serviceWithHolidays = BusinessDayService(holidayProvider: japaneseProvider)

        // 2025-01-01（元日、水曜日）の次の営業日は1/2（木曜日）
        let newYearsDay = try #require(Date.from(year: 2025, month: 1, day: 1))
        let nextBusinessDay = try #require(serviceWithHolidays.nextBusinessDay(from: newYearsDay))
        let expected = try #require(Date.from(year: 2025, month: 1, day: 2))
        #expect(calendar.isDate(nextBusinessDay, inSameDayAs: expected))
    }

    @Test("ゴールデンウィークの営業日計算")
    internal func businessDayCalculationDuringGoldenWeek() throws {
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
    internal func bothDirectHolidaysAndProviderHolidaysAreApplied() throws {
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
