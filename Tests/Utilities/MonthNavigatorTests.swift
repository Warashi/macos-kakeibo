import Foundation
import Testing

@testable import Kakeibo

@Suite
internal struct MonthNavigatorTests {
    @Test("前月への移動は年跨ぎを考慮する")
    internal func moveToPreviousMonth_handlesYearBoundary() throws {
        var navigator = MonthNavigator(year: 2025, month: 1)
        navigator.moveToPreviousMonth()

        #expect(navigator.year == 2024)
        #expect(navigator.month == 12)
    }

    @Test("次月への移動は年跨ぎを考慮する")
    internal func moveToNextMonth_handlesYearBoundary() throws {
        var navigator = MonthNavigator(year: 2025, month: 12)
        navigator.moveToNextMonth()

        #expect(navigator.year == 2026)
        #expect(navigator.month == 1)
    }

    @Test("現在の年月へ移動する")
    internal func moveToCurrentMonth_usesDateProvider() throws {
        let expectedDate = try #require(Date.from(year: 2026, month: 4, day: 15))
        var navigator = MonthNavigator(
            year: 2020,
            month: 5,
            currentDateProvider: { expectedDate }
        )

        navigator.moveToCurrentMonth()

        #expect(navigator.year == 2026)
        #expect(navigator.month == 4)
    }

    @Test("現在の年へ移動する")
    internal func moveToCurrentYear_usesDateProvider() throws {
        let expectedDate = try #require(Date.from(year: 2030, month: 3, day: 10))
        var navigator = MonthNavigator(
            year: 2020,
            month: 5,
            currentDateProvider: { expectedDate }
        )

        navigator.moveToCurrentYear()

        #expect(navigator.year == 2030)
        #expect(navigator.month == 5)
    }

    @Test("DateアダプタでDateとNavigatorを相互変換できる")
    internal func dateAdapter_roundTrips() throws {
        let adapter = MonthNavigatorDateAdapter()
        let sourceDate = try #require(Date.from(year: 2024, month: 7, day: 20))

        var navigator = adapter.makeNavigator(from: sourceDate)
        #expect(navigator.year == 2024)
        #expect(navigator.month == 7)

        navigator.moveToNextMonth()

        let convertedDate = try #require(adapter.date(from: navigator))
        #expect(convertedDate.year == 2024)
        #expect(convertedDate.month == 8)
        #expect(convertedDate.day == 1)
    }
}
