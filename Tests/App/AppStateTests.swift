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
}
