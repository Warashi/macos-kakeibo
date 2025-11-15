import Foundation
import Testing

@testable import Kakeibo

@Suite("BusinessDayService - isBusinessDay")
internal struct BusinessDayServiceIsBusinessDayTests {
    private let service: BusinessDayService = BusinessDayService()

    @Test("平日（月曜日）は営業日")
    internal func isBusinessDay_monday() throws {
        // 2025-01-06は月曜日
        let date = try #require(Date.from(year: 2025, month: 1, day: 6))
        #expect(service.isBusinessDay(date))
    }

    @Test("平日（火曜日）は営業日")
    internal func isBusinessDay_tuesday() throws {
        // 2025-01-07は火曜日
        let date = try #require(Date.from(year: 2025, month: 1, day: 7))
        #expect(service.isBusinessDay(date))
    }

    @Test("平日（水曜日）は営業日")
    internal func isBusinessDay_wednesday() throws {
        // 2025-01-08は水曜日
        let date = try #require(Date.from(year: 2025, month: 1, day: 8))
        #expect(service.isBusinessDay(date))
    }

    @Test("平日（木曜日）は営業日")
    internal func isBusinessDay_thursday() throws {
        // 2025-01-09は木曜日
        let date = try #require(Date.from(year: 2025, month: 1, day: 9))
        #expect(service.isBusinessDay(date))
    }

    @Test("平日（金曜日）は営業日")
    internal func isBusinessDay_friday() throws {
        // 2025-01-10は金曜日
        let date = try #require(Date.from(year: 2025, month: 1, day: 10))
        #expect(service.isBusinessDay(date))
    }

    @Test("土曜日は営業日ではない")
    internal func isBusinessDay_saturday() throws {
        // 2025-01-04は土曜日
        let date = try #require(Date.from(year: 2025, month: 1, day: 4))
        #expect(!service.isBusinessDay(date))
    }

    @Test("日曜日は営業日ではない")
    internal func isBusinessDay_sunday() throws {
        // 2025-01-05は日曜日
        let date = try #require(Date.from(year: 2025, month: 1, day: 5))
        #expect(!service.isBusinessDay(date))
    }
}
