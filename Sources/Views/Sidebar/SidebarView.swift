import Observation
import SwiftUI

internal struct SidebarView: View {
    @Bindable private var appState: AppState

    internal init(appState: AppState) {
        self.appState = appState
    }

    internal var body: some View {
        List(selection: $appState.selectedScreen) {
            Section {
                ForEach(AppState.Screen.allCases) { screen in
                    Label(screen.displayName, systemImage: screen.symbolName)
                        .tag(screen)
                }
            } header: {
                Text("ナビゲーション")
            }
        }
        .listStyle(.sidebar)
    }
}
