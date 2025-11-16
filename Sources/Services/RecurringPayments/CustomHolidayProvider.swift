import Foundation
import SwiftData

/// ユーザー定義祝日を提供するプロバイダー
internal struct CustomHolidayProvider: HolidayProvider {
    private let modelContainer: ModelContainer
    private let calendar: Calendar

    internal init(modelContainer: ModelContainer, calendar: Calendar = Calendar(identifier: .gregorian)) {
        self.modelContainer = modelContainer
        self.calendar = calendar
    }

    internal func holidays(for year: Int) -> Set<Date> {
        let modelContext = ModelContext(modelContainer)
        let descriptor: ModelFetchRequest<CustomHoliday> = ModelFetchFactory.make()

        guard let customHolidays = try? modelContext.fetch(descriptor) else {
            return []
        }

        var holidays = Set<Date>()

        for holiday in customHolidays {
            if holiday.isRecurring {
                // 繰り返しの場合、指定年の日付を生成
                let components = calendar.dateComponents([.month, .day], from: holiday.date)
                if let date = calendar.date(from: DateComponents(
                    year: year,
                    month: components.month,
                    day: components.day,
                )) {
                    holidays.insert(calendar.startOfDay(for: date))
                }
            } else {
                // 繰り返しでない場合、年が一致する場合のみ追加
                let holidayYear = calendar.component(.year, from: holiday.date)
                if holidayYear == year {
                    holidays.insert(calendar.startOfDay(for: holiday.date))
                }
            }
        }

        return holidays
    }
}
