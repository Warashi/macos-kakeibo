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
        let scheduleService = RecurringPaymentScheduleService(
            calendar: calendar,
            businessDayService: businessDayService,
            holidayProvider: holidayProvider,
        )

        return SwiftDataRecurringPaymentRepository(
            modelContainer: modelContainer,
            scheduleService: scheduleService,
            currentDateProvider: currentDateProvider,
        )
    }
}
