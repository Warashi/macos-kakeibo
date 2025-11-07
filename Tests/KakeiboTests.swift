import Testing
import SwiftUI
@testable import Kakeibo

@Suite("Kakeibo Tests")
struct KakeiboTests {
    @Test("ContentView can be initialized")
    func contentViewInitialization() {
        let view = ContentView()
        #expect(view.body != nil)
    }
}
