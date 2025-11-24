import SwiftUI

/// StoreFactoryをEnvironmentに渡すためのキー
internal struct StoreFactoryKey: EnvironmentKey {
    internal static let defaultValue: StoreFactory? = nil
}

extension EnvironmentValues {
    internal var storeFactory: StoreFactory? {
        get { self[StoreFactoryKey.self] }
        set { self[StoreFactoryKey.self] = newValue }
    }
}
