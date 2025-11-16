import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite("CustomHolidayProvider Tests", .serialized)
internal struct CustomHolidayProviderTests {
    private let calendar: Calendar

    internal init() {
        calendar = Calendar(identifier: .gregorian)
    }

    @Test("ユーザー定義の祝日を取得できる")
    internal func canGetUserDefinedHolidays() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        // カスタム祝日を追加（繰り返しなし）
        let customHoliday = CustomHoliday(
            date: makeDate(year: 2025, month: 6, day: 15),
            name: "会社創立記念日",
            isRecurring: false,
        )
        context.insert(customHoliday)

        try context.save()

        let provider = CustomHolidayProvider(modelContainer: container, calendar: calendar)
        let holidays = provider.holidays(for: 2025)

        let expectedDate = calendar.startOfDay(for: makeDate(year: 2025, month: 6, day: 15))
        #expect(holidays.contains(expectedDate))
        #expect(holidays.count == 1)
    }

    @Test("繰り返し祝日が毎年適用される")
    internal func recurringHolidaysApplyEveryYear() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        // 繰り返しカスタム祝日を追加
        let recurringHoliday = CustomHoliday(
            date: makeDate(year: 2024, month: 8, day: 10),
            name: "会社記念日",
            isRecurring: true,
        )
        context.insert(recurringHoliday)

        try context.save()

        let provider = CustomHolidayProvider(modelContainer: container, calendar: calendar)

        // 2025年でも8月10日が祝日になる
        let holidays2025 = provider.holidays(for: 2025)
        let expectedDate2025 = calendar.startOfDay(for: makeDate(year: 2025, month: 8, day: 10))
        #expect(holidays2025.contains(expectedDate2025))

        // 2026年でも8月10日が祝日になる
        let holidays2026 = provider.holidays(for: 2026)
        let expectedDate2026 = calendar.startOfDay(for: makeDate(year: 2026, month: 8, day: 10))
        #expect(holidays2026.contains(expectedDate2026))
    }

    @Test("繰り返しでない祝日は指定年のみ適用される")
    internal func nonRecurringHolidaysApplyOnlyToSpecifiedYear() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        // 繰り返しなしのカスタム祝日を追加
        let oneTimeHoliday = CustomHoliday(
            date: makeDate(year: 2025, month: 7, day: 20),
            name: "特別休日",
            isRecurring: false,
        )
        context.insert(oneTimeHoliday)

        try context.save()

        let provider = CustomHolidayProvider(modelContainer: container, calendar: calendar)

        // 2025年には祝日が存在
        let holidays2025 = provider.holidays(for: 2025)
        let expectedDate2025 = calendar.startOfDay(for: makeDate(year: 2025, month: 7, day: 20))
        #expect(holidays2025.contains(expectedDate2025))

        // 2026年には祝日が存在しない
        let holidays2026 = provider.holidays(for: 2026)
        #expect(!holidays2026.contains(where: { calendar.component(.day, from: $0) == 20 }))
    }

    @Test("複数のカスタム祝日を管理できる")
    internal func canManageMultipleCustomHolidays() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        // 複数のカスタム祝日を追加
        let holiday1 = CustomHoliday(
            date: makeDate(year: 2025, month: 4, day: 1),
            name: "カスタム祝日1",
            isRecurring: false,
        )
        let holiday2 = CustomHoliday(
            date: makeDate(year: 2025, month: 4, day: 15),
            name: "カスタム祝日2",
            isRecurring: false,
        )
        let holiday3 = CustomHoliday(
            date: makeDate(year: 2025, month: 9, day: 30),
            name: "カスタム祝日3",
            isRecurring: true,
        )

        context.insert(holiday1)
        context.insert(holiday2)
        context.insert(holiday3)

        try context.save()

        let provider = CustomHolidayProvider(modelContainer: container, calendar: calendar)
        let holidays = provider.holidays(for: 2025)

        #expect(holidays.count == 3)
    }

    @Test("カスタム祝日が存在しない場合は空のSetを返す")
    internal func returnsEmptySetWhenNoCustomHolidays() throws {
        let container = try ModelContainer.createInMemoryContainer()

        let provider = CustomHolidayProvider(modelContainer: container, calendar: calendar)
        let holidays = provider.holidays(for: 2025)

        #expect(holidays.isEmpty)
    }

    @Test("期間を指定してカスタム祝日を取得できる")
    internal func canGetCustomHolidaysWithinDateRange() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        let holiday1 = CustomHoliday(
            date: makeDate(year: 2025, month: 6, day: 10),
            name: "6月の祝日",
            isRecurring: false,
        )
        let holiday2 = CustomHoliday(
            date: makeDate(year: 2025, month: 7, day: 10),
            name: "7月の祝日",
            isRecurring: false,
        )

        context.insert(holiday1)
        context.insert(holiday2)

        try context.save()

        let provider = CustomHolidayProvider(modelContainer: container, calendar: calendar)

        // 6月1日〜6月30日の期間で取得
        let startDate = makeDate(year: 2025, month: 6, day: 1)
        let endDate = makeDate(year: 2025, month: 6, day: 30)
        let holidays = provider.holidays(from: startDate, to: endDate)

        // 6月の祝日のみが含まれる
        #expect(holidays.count == 1)
        let expectedDate = calendar.startOfDay(for: makeDate(year: 2025, month: 6, day: 10))
        #expect(holidays.contains(expectedDate))
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
