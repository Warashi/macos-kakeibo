import SwiftData
import SwiftUI

private struct AppModelContainerKey: EnvironmentKey {
    internal static let defaultValue: ModelContainer? = nil
}

internal extension EnvironmentValues {
    var appModelContainer: ModelContainer? {
        get { self[AppModelContainerKey.self] }
        set { self[AppModelContainerKey.self] = newValue }
    }
}
