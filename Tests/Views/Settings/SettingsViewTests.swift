@testable import Kakeibo
import SwiftData
import SwiftUI
import Testing

@Suite("SettingsView")
@MainActor
internal struct SettingsViewTests {
    @Test("bodyがクラッシュせず構築される")
    internal func bodyBuildsHierarchy() {
        let view = SettingsView()
        let body = view.body
        let _: any View = body
    }
}

@Suite("SettingsSectionCard")
@MainActor
internal struct SettingsSectionCardTests {
    @Test("初期化されたコンテンツがbodyに含まれる")
    internal func cardRendersProvidedContent() {
        let card = SettingsSectionCard(
            title: "データ管理",
            iconName: "externaldrive",
            description: "バックアップやCSVエクスポートの設定です。",
            content: {
                Text("dummy content")
            },
        )

        #expect(card.title == "データ管理")
        #expect(card.iconName == "externaldrive")
        #expect(card.description.contains("バックアップ"))
        let body = card.body
        let _: any View = body
    }
}
