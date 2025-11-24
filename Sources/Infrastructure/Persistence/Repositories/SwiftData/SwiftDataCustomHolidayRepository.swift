import Foundation
import SwiftData

@ModelActor
internal actor SwiftDataCustomHolidayRepository: CustomHolidayRepository {
    private var calendar: Calendar = Calendar(identifier: .gregorian)

    internal init(modelContainer: ModelContainer, calendar: Calendar = Calendar(identifier: .gregorian)) {
        let context = ModelContext(modelContainer)
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: context)
        self.modelContainer = modelContainer
        self.calendar = calendar
    }

    internal func holidays(for year: Int) async throws -> Set<Date> {
        let descriptor: FetchDescriptor<SwiftDataCustomHoliday> = FetchDescriptor()
        let customHolidays = try modelContext.fetch(descriptor)

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
