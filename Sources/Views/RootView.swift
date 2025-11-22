import Observation
import SwiftData
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
    @Environment(\.modelContext) private var modelContext: ModelContext
    internal let screen: AppState.Screen

    internal var body: some View {
        switch screen {
        case .dashboard:
            DashboardView()
        case .transactions:
            TransactionListView()
        case .budgets:
            BudgetView()
        case .savingsGoals:
            SavingsGoalListView(modelContext: modelContext)
        case .imports:
            CSVImportView()
        case .settings:
            SettingsView()
        }
    }
}
