import Foundation
import Testing

@testable import Kakeibo

@Suite
internal struct DateRangeTests {
    @Test("startDate > endDate の場合でも自動で並び替えられる")
    internal func normalizesOrder() {
        let start = Date.from(year: 2025, month: 5, day: 10) ?? Date()
        let end = Date.from(year: 2025, month: 5, day: 5) ?? Date()
        let range = DateRange(startDate: start, endDate: end)
        #expect(range.startDate <= range.endDate)
        #expect(range.contains(Date.from(year: 2025, month: 5, day: 7) ?? Date()))
    }

    @Test("currentMonthThroughFutureMonths は開始月を月初に揃える")
    internal func initializesFromCurrentMonth() {
        let reference = Date.from(year: 2025, month: 4, day: 15) ?? Date()
        let range = DateRange.currentMonthThroughFutureMonths(referenceDate: reference, monthsAhead: 3)
        let calendar = Calendar(identifier: .gregorian)
        let expectedStart = calendar.date(from: DateComponents(year: 2025, month: 4, day: 1)) ?? reference
        #expect(range.startDate == expectedStart)
    }
}
