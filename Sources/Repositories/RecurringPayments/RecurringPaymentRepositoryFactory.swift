import Foundation
import SwiftData

internal enum SpecialPaymentRepositoryFactory {
    @DatabaseActor
    internal static func make(
        modelContext: ModelContext,
        calendar: Calendar = Calendar(identifier: .gregorian),
        businessDayService: BusinessDayService? = nil,
        holidayProvider: HolidayProvider? = nil,
        currentDateProvider: @escaping () -> Date = { Date() },
    ) -> SpecialPaymentRepository {
        let scheduleService = SpecialPaymentScheduleService(
            calendar: calendar,
            businessDayService: businessDayService,
            holidayProvider: holidayProvider,
        )

        return SwiftDataSpecialPaymentRepository(
            modelContext: modelContext,
            scheduleService: scheduleService,
            currentDateProvider: currentDateProvider,
        )
    }
}
