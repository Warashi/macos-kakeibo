import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Hello World")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("家計簿アプリへようこそ")
                .font(.title2)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 400, minHeight: 300)
        .padding()
    }
}
