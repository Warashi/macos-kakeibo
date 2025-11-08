@testable import Kakeibo
import Testing

@Suite("AppState")
internal struct AppStateTests {
    @Test("デフォルトではダッシュボードが選択される")
    internal func defaultSelectionIsDashboard() {
        let state = AppState()
        #expect(state.selectedScreen == .dashboard)
    }

    @Test("画面の切り替えが状態に反映される")
    internal func screenSelectionUpdatesState() {
        let state = AppState()
        state.selectedScreen = .budgets
        #expect(state.selectedScreen == .budgets)
    }

    @Test("サイドバーに表示される順序は固定されている")
    internal func screenOrderIsStable() {
        let expectedOrder: [AppState.Screen] = [
            .dashboard,
            .transactions,
            .budgets,
            .imports,
            .settings,
        ]
        #expect(AppState.Screen.allCases == expectedOrder)
    }

    @Test("各画面の説明文が定義されている")
    internal func screenDescriptionsMatchExpectations() {
        let expectedDescriptions: [AppState.Screen: String] = [
            .dashboard: "家計簿の全体状況を確認できます。",
            .transactions: "収支の一覧を閲覧・管理する画面です。",
            .budgets: "予算の設定や進捗を管理します。",
            .imports: "CSVなどからデータを取り込みます。",
            .settings: "アプリの各種設定を調整します。",
        ]

        for screen in AppState.Screen.allCases {
            #expect(screen.description == expectedDescriptions[screen])
        }
    }
}
