import Foundation
import Testing

@Suite("Test Environment")
internal struct TestEnvironmentTests {
    @Test("Calendar.current uses Asia/Tokyo time zone")
    internal func calendarUsesAsiaTokyoTimeZone() throws {
        #expect(Calendar.current.timeZone.identifier == TestEnvironment.defaultTimeZoneIdentifier)
    }

    @Test("Date.from generates dates in Asia/Tokyo time zone")
    internal func dateFromUsesAsiaTokyoTimeZone() throws {
        guard let tokyo = TimeZone(identifier: TestEnvironment.defaultTimeZoneIdentifier) else {
            Issue.record("Asia/Tokyo time zone is not available on this platform.")
            return
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tokyo

        let expected = try #require(calendar.date(from: DateComponents(year: 2025, month: 1, day: 15)))
        let actual = try #require(Date.from(year: 2025, month: 1, day: 15))

        #expect(actual == expected)
    }
}
