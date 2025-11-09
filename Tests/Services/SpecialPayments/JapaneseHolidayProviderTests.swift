import Foundation
import Testing

@testable import Kakeibo

@Suite("JapaneseHolidayProvider Tests", .serialized)
internal struct JapaneseHolidayProviderTests {
    private let provider: JapaneseHolidayProvider
    private let calendar: Calendar

    internal init() {
        calendar = Calendar(identifier: .gregorian)
        provider = JapaneseHolidayProvider(calendar: calendar)
    }

    // MARK: - 固定祝日のテスト

    @Test("元日が祝日として認識される")
    internal func testNewYearsDayIsRecognizedAsHoliday() throws {
        let holidays2025 = provider.holidays(for: 2025)

        let newYearsDay = makeDate(year: 2025, month: 1, day: 1)
        #expect(holidays2025.contains(newYearsDay))
    }

    @Test("建国記念の日が祝日として認識される")
    internal func testFoundationDayIsRecognizedAsHoliday() throws {
        let holidays2025 = provider.holidays(for: 2025)

        let foundationDay = makeDate(year: 2025, month: 2, day: 11)
        #expect(holidays2025.contains(foundationDay))
    }

    @Test("天皇誕生日_2020年以降は2月23日")
    internal func testEmperorsBirthdayIsFeb23After2020() throws {
        let holidays2025 = provider.holidays(for: 2025)

        let emperorBirthday = makeDate(year: 2025, month: 2, day: 23)
        #expect(holidays2025.contains(emperorBirthday))
    }

    @Test("天皇誕生日_2019年以前は12月23日")
    internal func testEmperorsBirthdayIsDec23Before2019() throws {
        let holidays2018 = provider.holidays(for: 2018)

        let emperorBirthday = makeDate(year: 2018, month: 12, day: 23)
        #expect(holidays2018.contains(emperorBirthday))
    }

    @Test("ゴールデンウィークの祝日_憲法記念日_みどりの日_こどもの日")
    internal func testGoldenWeekHolidays() throws {
        let holidays2025 = provider.holidays(for: 2025)

        let constitutionDay = makeDate(year: 2025, month: 5, day: 3)
        let greeneryDay = makeDate(year: 2025, month: 5, day: 4)
        let childrensDay = makeDate(year: 2025, month: 5, day: 5)

        #expect(holidays2025.contains(constitutionDay))
        #expect(holidays2025.contains(greeneryDay))
        #expect(holidays2025.contains(childrensDay))
    }

    // MARK: - 移動祝日のテスト

    @Test("成人の日_2000年以降は1月第2月曜日")
    internal func testComingOfAgeDayIsSecondMondayAfter2000() throws {
        let holidays2025 = provider.holidays(for: 2025)

        // 2025年1月第2月曜日は13日
        let comingOfAgeDay = makeDate(year: 2025, month: 1, day: 13)
        #expect(holidays2025.contains(comingOfAgeDay))

        // 月曜日であることを確認
        let weekday = calendar.component(.weekday, from: comingOfAgeDay)
        #expect(weekday == 2) // 2 = Monday
    }

    @Test("成人の日_1999年以前は1月15日")
    internal func testComingOfAgeDayIsJan15Before1999() throws {
        let holidays1999 = provider.holidays(for: 1999)

        let comingOfAgeDay = makeDate(year: 1999, month: 1, day: 15)
        #expect(holidays1999.contains(comingOfAgeDay))
    }

    @Test("海の日_2003年以降は7月第3月曜日")
    internal func testMarineDayIsThirdMondayAfter2003() throws {
        let holidays2025 = provider.holidays(for: 2025)

        // 2025年7月第3月曜日は21日
        let marineDay = makeDate(year: 2025, month: 7, day: 21)
        #expect(holidays2025.contains(marineDay))

        // 月曜日であることを確認
        let weekday = calendar.component(.weekday, from: marineDay)
        #expect(weekday == 2)
    }

    @Test("敬老の日_2003年以降は9月第3月曜日")
    internal func testRespectForAgedDayIsThirdMondayAfter2003() throws {
        let holidays2025 = provider.holidays(for: 2025)

        // 2025年9月第3月曜日は15日
        let respectForAgedDay = makeDate(year: 2025, month: 9, day: 15)
        #expect(holidays2025.contains(respectForAgedDay))

        // 月曜日であることを確認
        let weekday = calendar.component(.weekday, from: respectForAgedDay)
        #expect(weekday == 2)
    }

    @Test("スポーツの日_2000年以降は10月第2月曜日")
    internal func testSportsDayIsSecondMondayAfter2000() throws {
        let holidays2025 = provider.holidays(for: 2025)

        // 2025年10月第2月曜日は13日
        let sportsDay = makeDate(year: 2025, month: 10, day: 13)
        #expect(holidays2025.contains(sportsDay))

        // 月曜日であることを確認
        let weekday = calendar.component(.weekday, from: sportsDay)
        #expect(weekday == 2)
    }

    // MARK: - 振替休日のテスト

    @Test("日曜日の祝日は翌日が振替休日になる")
    internal func testSundayHolidayCreatesSubstituteHoliday() throws {
        // 2024年2月11日(建国記念の日)は日曜日
        let holidays2024 = provider.holidays(for: 2024)

        let foundationDay = makeDate(year: 2024, month: 2, day: 11)
        let substituteHoliday = makeDate(year: 2024, month: 2, day: 12)

        // 建国記念の日が日曜日であることを確認
        let weekday = calendar.component(.weekday, from: foundationDay)
        #expect(weekday == 1) // 1 = Sunday

        // 振替休日が存在することを確認
        #expect(holidays2024.contains(foundationDay))
        #expect(holidays2024.contains(substituteHoliday))
    }

    // MARK: - 期間指定テスト

    @Test("期間を指定して祝日を取得できる")
    internal func testCanGetHolidaysWithinDateRange() throws {
        let startDate = makeDate(year: 2025, month: 5, day: 1)
        let endDate = makeDate(year: 2025, month: 5, day: 31)

        let holidays = provider.holidays(from: startDate, to: endDate)

        // 5月の祝日（憲法記念日、みどりの日、こどもの日、振替休日）が含まれる
        let constitutionDay = makeDate(year: 2025, month: 5, day: 3)
        let greeneryDay = makeDate(year: 2025, month: 5, day: 4)
        let childrensDay = makeDate(year: 2025, month: 5, day: 5)
        let substituteHoliday = makeDate(year: 2025, month: 5, day: 6)

        #expect(holidays.contains(constitutionDay))
        #expect(holidays.contains(greeneryDay))
        #expect(holidays.contains(childrensDay))
        #expect(holidays.contains(substituteHoliday))

        // 5月は4つの祝日（振替休日含む）
        #expect(holidays.count == 4)
    }

    @Test("複数年にまたがる期間の祝日を取得できる")
    internal func testCanGetHolidaysAcrossMultipleYears() throws {
        let startDate = makeDate(year: 2024, month: 12, day: 1)
        let endDate = makeDate(year: 2025, month: 1, day: 31)

        let holidays = provider.holidays(from: startDate, to: endDate)

        // 2025年の元日が含まれる
        let newYearsDay2025 = makeDate(year: 2025, month: 1, day: 1)
        #expect(holidays.contains(newYearsDay2025))

        // 2025年の成人の日が含まれる
        let comingOfAgeDay2025 = makeDate(year: 2025, month: 1, day: 13)
        #expect(holidays.contains(comingOfAgeDay2025))
    }

    // MARK: - ヘルパー

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        let components = DateComponents(year: year, month: month, day: day)
        guard let date = calendar.date(from: components) else {
            fatalError("Invalid date components: year=\(year), month=\(month), day=\(day)")
        }
        return date
    }
}
