import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite("CompositeHolidayProvider Tests", .serialized)
internal struct CompositeHolidayProviderTests {
    private let calendar: Calendar

    internal init() {
        calendar = Calendar(identifier: .gregorian)
    }

    @Test("複数のプロバイダーを統合して祝日を取得できる")
    internal func canIntegrateMultipleProviders() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        // カスタム祝日を追加
        let customHoliday = CustomHoliday(
            date: makeDate(year: 2025, month: 6, day: 15),
            name: "会社創立記念日",
            isRecurring: false,
        )
        context.insert(customHoliday)

        // 日本の祝日プロバイダーとカスタム祝日プロバイダーを統合
        let japaneseProvider = JapaneseHolidayProvider(calendar: calendar)
        let customProvider = CustomHolidayProvider(modelContext: context, calendar: calendar)
        let compositeProvider = CompositeHolidayProvider(providers: [japaneseProvider, customProvider])

        let holidays2025 = compositeProvider.holidays(for: 2025)

        // 日本の祝日（元日）が含まれる
        let newYearsDay = calendar.startOfDay(for: makeDate(year: 2025, month: 1, day: 1))
        #expect(holidays2025.contains(newYearsDay))

        // カスタム祝日が含まれる
        let customHolidayDate = calendar.startOfDay(for: makeDate(year: 2025, month: 6, day: 15))
        #expect(holidays2025.contains(customHolidayDate))
    }

    @Test("空のプロバイダーリストでも動作する")
    internal func worksWithEmptyProviderList() throws {
        let compositeProvider = CompositeHolidayProvider(providers: [])
        let holidays = compositeProvider.holidays(for: 2025)

        #expect(holidays.isEmpty)
    }

    @Test("重複する祝日は1つにまとめられる")
    internal func duplicateHolidaysAreMerged() throws {
        // 同じ祝日を返す2つのプロバイダーを作成
        let japaneseProvider1 = JapaneseHolidayProvider(calendar: calendar)
        let japaneseProvider2 = JapaneseHolidayProvider(calendar: calendar)

        let compositeProvider = CompositeHolidayProvider(providers: [japaneseProvider1, japaneseProvider2])
        let holidays2025 = compositeProvider.holidays(for: 2025)

        // 日本の祝日プロバイダーを1つだけ使った場合と同じ数
        let singleProviderHolidays = japaneseProvider1.holidays(for: 2025)
        #expect(holidays2025.count == singleProviderHolidays.count)
    }

    @Test("期間指定で複数のプロバイダーから祝日を取得できる")
    internal func canGetHolidaysFromMultipleProvidersWithDateRange() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        // カスタム祝日を追加
        let customHoliday = CustomHoliday(
            date: makeDate(year: 2025, month: 5, day: 6),
            name: "特別休日",
            isRecurring: false,
        )
        context.insert(customHoliday)

        let japaneseProvider = JapaneseHolidayProvider(calendar: calendar)
        let customProvider = CustomHolidayProvider(modelContext: context, calendar: calendar)
        let compositeProvider = CompositeHolidayProvider(providers: [japaneseProvider, customProvider])

        // 5月の期間を指定
        let startDate = makeDate(year: 2025, month: 5, day: 1)
        let endDate = makeDate(year: 2025, month: 5, day: 31)
        let holidays = compositeProvider.holidays(from: startDate, to: endDate)

        // ゴールデンウィークの祝日が含まれる
        let constitutionDay = calendar.startOfDay(for: makeDate(year: 2025, month: 5, day: 3))
        #expect(holidays.contains(constitutionDay))

        // カスタム祝日が含まれる
        let customHolidayDate = calendar.startOfDay(for: makeDate(year: 2025, month: 5, day: 6))
        #expect(holidays.contains(customHolidayDate))
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
