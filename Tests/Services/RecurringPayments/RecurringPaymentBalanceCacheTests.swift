import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite("RecurringPaymentBalanceService - キャッシュ")
internal struct RecurringPaymentBalanceCacheTests {
    private func makeDefinition() -> RecurringPaymentDefinitionEntity {
        RecurringPaymentDefinitionEntity(
            name: "自動車税",
            amount: 60000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: Date.from(year: 2025, month: 5) ?? Date(),
        )
    }

    @Test("同一パラメータで残高再計算を繰り返すとキャッシュがヒットする")
    internal func recalculateBalanceUsesCache() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let definition = makeDefinition()
        let balance = RecurringPaymentSavingBalanceEntity(
            definition: definition,
            totalSavedAmount: 0,
            totalPaidAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 1,
        )
        context.insert(definition)
        context.insert(balance)
        let service = RecurringPaymentBalanceService()

        var metrics = service.cacheMetrics()
        #expect(metrics.hits == 0)
        #expect(metrics.misses == 0)

        service.recalculateBalance(
            params: .init(
                definition: definition,
                balance: balance,
                year: 2025,
                month: 6,
                startYear: 2025,
                startMonth: 1,
            ),
        )
        service.recalculateBalance(
            params: .init(
                definition: definition,
                balance: balance,
                year: 2025,
                month: 6,
                startYear: 2025,
                startMonth: 1,
            ),
        )

        metrics = service.cacheMetrics()
        #expect(metrics.hits == 1)
        #expect(metrics.misses == 1)
    }

    @Test("積立記録後はキャッシュが無効化され再計算が再実行される")
    internal func invalidateCacheAfterSavings() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let definition = makeDefinition()
        let balance = RecurringPaymentSavingBalanceEntity(
            definition: definition,
            totalSavedAmount: 0,
            totalPaidAmount: 0,
            lastUpdatedYear: 2025,
            lastUpdatedMonth: 1,
        )
        context.insert(definition)
        context.insert(balance)
        let service = RecurringPaymentBalanceService()

        var metrics = service.cacheMetrics()
        #expect(metrics.hits == 0)
        #expect(metrics.misses == 0)

        service.recalculateBalance(
            params: .init(
                definition: definition,
                balance: balance,
                year: 2025,
                month: 6,
                startYear: 2025,
                startMonth: 1,
            ),
        )
        service.recalculateBalance(
            params: .init(
                definition: definition,
                balance: balance,
                year: 2025,
                month: 6,
                startYear: 2025,
                startMonth: 1,
            ),
        )

        service.recordMonthlySavings(
            params: .init(
                definition: definition,
                balance: balance,
                year: 2025,
                month: 7,
            ),
        )

        service.recalculateBalance(
            params: .init(
                definition: definition,
                balance: balance,
                year: 2025,
                month: 6,
                startYear: 2025,
                startMonth: 1,
            ),
        )

        metrics = service.cacheMetrics()
        #expect(metrics.misses == 2)
        #expect(metrics.hits == 1)
        #expect(metrics.invalidations == 1)
    }
}
