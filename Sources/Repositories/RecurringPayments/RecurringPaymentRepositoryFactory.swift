import Foundation
import SwiftData

internal enum RecurringPaymentRepositoryFactory {
    @DatabaseActor
    internal static func make(
        modelContext: ModelContext,
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
            modelContext: modelContext,
            scheduleService: scheduleService,
            currentDateProvider: currentDateProvider,
        )
    }
}
