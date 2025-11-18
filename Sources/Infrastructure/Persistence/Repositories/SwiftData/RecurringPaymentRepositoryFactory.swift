import Foundation
import SwiftData

internal enum RecurringPaymentRepositoryFactory {
    internal static func make(
        modelContainer: ModelContainer,
        calendar: Calendar = Calendar(identifier: .gregorian),
        currentDateProvider: @escaping @Sendable () -> Date = { Date() },
    ) async -> RecurringPaymentRepository {
        let repository = SwiftDataRecurringPaymentRepository(modelContainer: modelContainer)
        await repository.configure(calendar: calendar, currentDateProvider: currentDateProvider)
        return repository
    }
}
