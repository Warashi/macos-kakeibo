import Foundation

internal enum TestEnvironment {
    internal static let defaultTimeZoneIdentifier = "Asia/Tokyo"

    private static let configureTimeZoneOnce: Void = {
        guard let timeZone = TimeZone(identifier: defaultTimeZoneIdentifier) else {
            fatalError("Asia/Tokyo time zone is required for tests.")
        }
        TimeZone.ReferenceType.default = timeZone
    }()

    internal static func configure() {
        _ = configureTimeZoneOnce
    }
}

// Configure shared test state (time zone) as soon as the test bundle is loaded.
private let _ = {
    TestEnvironment.configure()
}()
