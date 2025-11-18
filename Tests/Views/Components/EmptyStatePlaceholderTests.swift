import SwiftUI
import Testing

@testable import Kakeibo

@Suite("EmptyStatePlaceholder Tests")
@MainActor
internal struct EmptyStatePlaceholderTests {
    @Test("シンプルなプレースホルダを初期化できる")
    internal func initializesPlaceholder() {
        let view = EmptyStatePlaceholder(
            systemImage: "tray",
            title: "データがありません",
            message: "サンプルメッセージ",
            minHeight: 120,
        )
        let _: any View = view
    }
}
