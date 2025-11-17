import Foundation
import SwiftData

internal enum RecurringPaymentRepositoryFactory {
    @DatabaseActor
    internal static func make(
        modelContainer: ModelContainer,
        calendar: Calendar = Calendar(identifier: .gregorian),
        businessDayService: BusinessDayService? = nil,
        holidayProvider: HolidayProvider? = nil,
        currentDateProvider: @escaping () -> Date = { Date() },
    ) -> RecurringPaymentRepository {
        let resolvedHolidayProvider: HolidayProvider? = {
            if let holidayProvider {
                return holidayProvider
            }
            let japaneseProvider = JapaneseHolidayProvider(calendar: calendar)
            let customProvider = CustomHolidayProvider(modelContainer: modelContainer, calendar: calendar)
            return CompositeHolidayProvider(providers: [japaneseProvider, customProvider])
        }()

        let scheduleService = RecurringPaymentScheduleService(
            calendar: calendar,
            businessDayService: businessDayService,
            holidayProvider: resolvedHolidayProvider,
        )

        return SwiftDataRecurringPaymentRepository(
            modelContainer: modelContainer,
            scheduleService: scheduleService,
            currentDateProvider: currentDateProvider,
        )
    }
}
