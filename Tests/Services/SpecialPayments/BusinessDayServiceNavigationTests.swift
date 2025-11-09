import Foundation
import Testing

@testable import Kakeibo

@Suite("BusinessDayService - Navigation")
internal struct BusinessDayServiceNavigationTests {
    private let calendar: Calendar = Calendar(identifier: .gregorian)
    private let service: BusinessDayService = BusinessDayService()

    // MARK: - previousBusinessDay Tests

    @Test("金曜日の前営業日は木曜日")
    internal func previousBusinessDay_friday() throws {
        let friday = try #require(Date.from(year: 2025, month: 1, day: 10))
        let previous = try #require(service.previousBusinessDay(from: friday))
        let thursday = try #require(Date.from(year: 2025, month: 1, day: 9))
        #expect(calendar.isDate(previous, inSameDayAs: thursday))
    }

    @Test("月曜日の前営業日は金曜日（週末をスキップ）")
    internal func previousBusinessDay_monday() throws {
        let monday = try #require(Date.from(year: 2025, month: 1, day: 6))
        let previous = try #require(service.previousBusinessDay(from: monday))
        let friday = try #require(Date.from(year: 2025, month: 1, day: 3))
        #expect(calendar.isDate(previous, inSameDayAs: friday))
    }

    @Test("日曜日の前営業日は金曜日")
    internal func previousBusinessDay_sunday() throws {
        let sunday = try #require(Date.from(year: 2025, month: 1, day: 5))
        let previous = try #require(service.previousBusinessDay(from: sunday))
        let friday = try #require(Date.from(year: 2025, month: 1, day: 3))
        #expect(calendar.isDate(previous, inSameDayAs: friday))
    }

    @Test("土曜日の前営業日は金曜日")
    internal func previousBusinessDay_saturday() throws {
        let saturday = try #require(Date.from(year: 2025, month: 1, day: 4))
        let previous = try #require(service.previousBusinessDay(from: saturday))
        let friday = try #require(Date.from(year: 2025, month: 1, day: 3))
        #expect(calendar.isDate(previous, inSameDayAs: friday))
    }

    // MARK: - nextBusinessDay Tests

    @Test("金曜日の次営業日は月曜日（週末をスキップ）")
    internal func nextBusinessDay_friday() throws {
        let friday = try #require(Date.from(year: 2025, month: 1, day: 3))
        let next = try #require(service.nextBusinessDay(from: friday))
        let monday = try #require(Date.from(year: 2025, month: 1, day: 6))
        #expect(calendar.isDate(next, inSameDayAs: monday))
    }

    @Test("木曜日の次営業日は金曜日")
    internal func nextBusinessDay_thursday() throws {
        let thursday = try #require(Date.from(year: 2025, month: 1, day: 9))
        let next = try #require(service.nextBusinessDay(from: thursday))
        let friday = try #require(Date.from(year: 2025, month: 1, day: 10))
        #expect(calendar.isDate(next, inSameDayAs: friday))
    }

    @Test("土曜日の次営業日は月曜日")
    internal func nextBusinessDay_saturday() throws {
        let saturday = try #require(Date.from(year: 2025, month: 1, day: 4))
        let next = try #require(service.nextBusinessDay(from: saturday))
        let monday = try #require(Date.from(year: 2025, month: 1, day: 6))
        #expect(calendar.isDate(next, inSameDayAs: monday))
    }

    @Test("日曜日の次営業日は月曜日")
    internal func nextBusinessDay_sunday() throws {
        let sunday = try #require(Date.from(year: 2025, month: 1, day: 5))
        let next = try #require(service.nextBusinessDay(from: sunday))
        let monday = try #require(Date.from(year: 2025, month: 1, day: 6))
        #expect(calendar.isDate(next, inSameDayAs: monday))
    }
}
