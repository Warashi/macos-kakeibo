import SwiftData
import SwiftUI

// MARK: - View Builders

internal extension BudgetView {
    @ViewBuilder
    func toolbarSection(store: BudgetStore) -> some View {
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
            .frame(maxWidth: 200)

            Spacer()

            if store.displayMode != .specialPaymentsList {
                if store.displayMode == .monthly {
                    monthNavigationButtons(store: store)
                } else {
                    yearNavigationButtons(store: store)
                }

                Button(store.displayMode == .monthly ? "今月" : "今年") {
                    if store.displayMode == .monthly {
                        store.moveToCurrentMonth()
                    } else {
                        store.moveToCurrentYear()
                    }
                }
            }

            Button("特別支払いの突合") {
                isPresentingReconciliation = true
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }

    @ViewBuilder
    func monthNavigationButtons(store: BudgetStore) -> some View {
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

    @ViewBuilder
    func yearNavigationButtons(store: BudgetStore) -> some View {
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

    @ViewBuilder
    var specialPaymentListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("特別支払い")
                    .font(.title2.bold())
                Spacer()
                Button {
                    presentSpecialPaymentEditor(for: nil)
                } label: {
                    Label("追加", systemImage: "plus")
                }
            }

            if specialPaymentDefinitions.isEmpty {
                ContentUnavailableView {
                    Label("特別支払いがありません", systemImage: "calendar.badge.exclamationmark")
                } description: {
                    Text("定期的な大きな支払いを登録して、月次の積立計画を立てましょう。")
                }
                .frame(height: 200)
            } else {
                VStack(spacing: 12) {
                    ForEach(specialPaymentDefinitions) { definition in
                        SpecialPaymentRow(
                            definition: definition,
                            onEdit: { presentSpecialPaymentEditor(for: definition) },
                            onDelete: { specialPaymentPendingDeletion = definition },
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
    }

    var specialPaymentDefinitions: [SpecialPaymentDefinition] {
        let descriptor = FetchDescriptor<SpecialPaymentDefinition>(
            sortBy: [
                SortDescriptor(\.firstOccurrenceDate),
                SortDescriptor(\.name),
            ],
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}
