import Observation
import SwiftUI

internal struct RootView: View {
    @Bindable private var appState: AppState
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    internal init(appState: AppState) {
        self.appState = appState
    }

    internal var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(appState: appState)
        } detail: {
            RootDetailView(screen: appState.selectedScreen ?? .dashboard)
        }
        .navigationSplitViewStyle(.prominentDetail)
    }
}

private struct RootDetailView: View {
    internal let screen: AppState.Screen

    internal var body: some View {
        ContentUnavailableView {
            Label(screen.displayName, systemImage: screen.symbolName)
                .font(.largeTitle)
        } description: {
            Text(screen.description)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}
