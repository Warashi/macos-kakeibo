import Foundation
import Testing

@testable import Kakeibo

@Suite("BusinessDayService - Month Boundary")
internal struct BusinessDayServiceMonthBoundaryTests {
    private let calendar: Calendar = Calendar(identifier: .gregorian)
    private let service: BusinessDayService = BusinessDayService()

    // MARK: - firstBusinessDay Tests

    @Test("月初が平日の場合、最初の営業日は1日")
    internal func firstBusinessDay_startsOnWeekday() throws {
        // 2025-01-01は水曜日
        let first = try #require(service.firstBusinessDay(of: 2025, month: 1))
        let expected = try #require(Date.from(year: 2025, month: 1, day: 1))
        #expect(calendar.isDate(first, inSameDayAs: expected))
    }

    @Test("月初が土曜日の場合、最初の営業日は月曜日")
    internal func firstBusinessDay_startsOnSaturday() throws {
        // 2025-02-01は土曜日
        let first = try #require(service.firstBusinessDay(of: 2025, month: 2))
        let expected = try #require(Date.from(year: 2025, month: 2, day: 3))
        #expect(calendar.isDate(first, inSameDayAs: expected))
    }

    @Test("月初が日曜日の場合、最初の営業日は月曜日")
    internal func firstBusinessDay_startsOnSunday() throws {
        // 2025-06-01は日曜日
        let first = try #require(service.firstBusinessDay(of: 2025, month: 6))
        let expected = try #require(Date.from(year: 2025, month: 6, day: 2))
        #expect(calendar.isDate(first, inSameDayAs: expected))
    }

    // MARK: - lastBusinessDay Tests

    @Test("月末が平日の場合、最終営業日は月末")
    internal func lastBusinessDay_endsOnWeekday() throws {
        // 2025-01-31は金曜日
        let last = try #require(service.lastBusinessDay(of: 2025, month: 1))
        let expected = try #require(Date.from(year: 2025, month: 1, day: 31))
        #expect(calendar.isDate(last, inSameDayAs: expected))
    }

    @Test("月末が土曜日の場合、最終営業日は金曜日")
    internal func lastBusinessDay_endsOnSaturday() throws {
        // 2025-03-31は月曜日（確認必要）、2025-05-31は土曜日
        let last = try #require(service.lastBusinessDay(of: 2025, month: 5))
        let expected = try #require(Date.from(year: 2025, month: 5, day: 30))
        #expect(calendar.isDate(last, inSameDayAs: expected))
    }

    @Test("月末が日曜日の場合、最終営業日は金曜日")
    internal func lastBusinessDay_endsOnSunday() throws {
        // 2025-08-31は日曜日
        let last = try #require(service.lastBusinessDay(of: 2025, month: 8))
        let expected = try #require(Date.from(year: 2025, month: 8, day: 29))
        #expect(calendar.isDate(last, inSameDayAs: expected))
    }
}
