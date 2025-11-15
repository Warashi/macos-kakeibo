import SwiftUI

/// 予算ビューのツールバーセクション
internal struct BudgetToolbarView: View {
    internal let store: BudgetStore
    @Binding internal var isPresentingReconciliation: Bool

    internal var body: some View {
        HStack(spacing: 12) {
            Picker(
                "表示モード",
                selection: Binding(
                    get: { store.displayMode },
                    set: { store.displayMode = $0 },
                ),
            ) {
                ForEach(BudgetStore.DisplayMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()

            Spacer()

            if store.displayModeTraits.showsNavigation {
                switch store.displayModeTraits.navigationStyle {
                case .monthly:
                    BudgetMonthNavigationView(store: store)
                case .annual:
                    BudgetYearNavigationView(store: store)
                case .hidden:
                    EmptyView()
                }

                if let presentLabel = store.displayModeTraits.presentButtonLabel {
                    Button(presentLabel) {
                        store.moveToPresent()
                    }
                }
            }

            Button("定期支払いの突合") {
                isPresentingReconciliation = true
            }
        }
        .padding()
        .background(Color.backgroundTertiary)
        .cornerRadius(10)
    }
}

/// 月次ナビゲーションボタン
internal struct BudgetMonthNavigationView: View {
    internal let store: BudgetStore

    internal var body: some View {
        HStack(spacing: 12) {
            Button {
                store.moveToPreviousMonth()
            } label: {
                Image(systemName: "chevron.left")
            }

            Text("\(store.currentYear.yearDisplayString)年\(store.currentMonth)月")
                .font(.title3)
                .frame(minWidth: 140)

            Button {
                store.moveToNextMonth()
            } label: {
                Image(systemName: "chevron.right")
            }
        }
    }
}

/// 年次ナビゲーションボタン
internal struct BudgetYearNavigationView: View {
    internal let store: BudgetStore

    internal var body: some View {
        HStack(spacing: 12) {
            Button {
                store.moveToPreviousYear()
            } label: {
                Image(systemName: "chevron.left")
            }

            Text("\(store.currentYear.yearDisplayString)年")
                .font(.title3)
                .frame(minWidth: 140)

            Button {
                store.moveToNextYear()
            } label: {
                Image(systemName: "chevron.right")
            }
        }
    }
}
