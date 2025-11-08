import SwiftUI

internal struct ContentView: View {
    @State private var appState: AppState = .init()

    internal var body: some View {
        RootView(appState: appState)
            .frame(minWidth: 800, minHeight: 600)
    }
}
