@testable import Kakeibo
import SwiftUI
import Testing

@Suite("Kakeibo Tests")
struct KakeiboTests {
    @Test("ContentView can be initialized")
    func contentViewInitialization() {
        let view = ContentView()
        // ViewがSwiftUIのView protocolに準拠していることを確認
        let _: any View = view
    }
}
