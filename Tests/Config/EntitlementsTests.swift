import Foundation
import XCTest

internal final class EntitlementsTests: XCTestCase {
    internal func testUserSelectedFileAccessEntitlementsAreEnabled() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let entitlementsURL = repoRoot
            .appendingPathComponent("Config")
            .appendingPathComponent("Kakeibo.entitlements")

        let data = try Data(contentsOf: entitlementsURL)
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)

        guard let entitlements = plist as? [String: Any] else {
            XCTFail("Kakeibo.entitlements が辞書として読み取れませんでした")
            return
        }

        XCTAssertEqual(
            entitlements["com.apple.security.app-sandbox"] as? Bool,
            true,
            "App Sandbox を有効にしてください",
        )

        XCTAssertEqual(
            entitlements["com.apple.security.files.user-selected.read-only"] as? Bool,
            true,
            "ユーザー選択ファイルの読み取り権限がありません",
        )
    }
}
