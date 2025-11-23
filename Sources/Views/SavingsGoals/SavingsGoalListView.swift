import SwiftData
import SwiftUI

/// 貯蓄目標一覧ビュー
internal struct SavingsGoalListView: View {
    @State private var store: SavingsGoalStore
    @Query private var goals: [SwiftDataSavingsGoal]
    @State private var goalPendingDeletion: UUID?

    internal init(modelContext: ModelContext) {
        let repository = SwiftDataSavingsGoalRepository(modelContainer: modelContext.container)
        _store = State(initialValue: SavingsGoalStore(repository: repository, modelContext: modelContext))
    }

    internal var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                Card(title: "貯蓄目標") {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("貯蓄目標一覧")
                                .font(.headline)
                            Spacer()
                            Button {
                                store.prepareFormForCreate()
                            } label: {
                                Label("貯蓄目標を追加", systemImage: "plus")
                            }
                        }

                        if goals.isEmpty {
                            EmptyStatePlaceholder(
                                systemImage: "banknote",
                                title: "貯蓄目標が未登録です",
                                message: "「貯蓄目標を追加」ボタンから新しい貯蓄目標を作成できます。",
                            )
                        } else {
                            Table(goals) {
                                TableColumn("名称") { goal in
                                    HStack(spacing: 8) {
                                        Text(goal.name)
                                            .fontWeight(.regular)

                                        if !goal.isActive {
                                            Text("無効")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.gray.opacity(0.2))
                                                .cornerRadius(4)
                                        }
                                    }
                                }

                                TableColumn("月次積立額") { goal in
                                    Text(goal.monthlySavingAmount.currencyFormatted)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }

                                TableColumn("目標金額") { goal in
                                    Group {
                                        if let targetAmount = goal.targetAmount {
                                            Text(targetAmount.currencyFormatted)
                                        } else {
                                            Text("—")
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                }

                                TableColumn("現在残高") { goal in
                                    Group {
                                        if let balance = goal.balance {
                                            Text(balance.balance.currencyFormatted)
                                                .foregroundColor(balance.balance >= 0 ? .primary : .red)
                                        } else {
                                            Text("¥0")
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                }

                                TableColumn("進捗") { goal in
                                    HStack(spacing: 8) {
                                        if let targetAmount = goal.targetAmount,
                                           let balance = goal.balance,
                                           targetAmount > 0 {
                                            let currentBalance = NSDecimalNumber(decimal: balance.balance).doubleValue
                                            let targetValue = NSDecimalNumber(decimal: targetAmount).doubleValue
                                            let progress = min(1.0, currentBalance / targetValue)

                                            ProgressView(value: progress, total: 1.0)
                                                .progressViewStyle(.linear)
                                                .frame(maxWidth: 100)

                                            Text(String(format: "%.0f%%", progress * 100))
                                                .font(.caption)
                                                .foregroundColor(progress >= 1.0 ? .green : .secondary)
                                                .frame(minWidth: 40, alignment: .trailing)
                                        } else {
                                            Text("—")
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                TableColumn("操作") { goal in
                                    HStack {
                                        Button {
                                            store.prepareFormForEdit(goal.toDomain())
                                        } label: {
                                            Image(systemName: "pencil")
                                        }
                                        .buttonStyle(.borderless)
                                        .help("編集")

                                        Button {
                                            Task {
                                                try? await store.toggleGoalActive(goal.id)
                                            }
                                        } label: {
                                            Image(systemName: goal.isActive ? "pause.circle" : "play.circle")
                                        }
                                        .buttonStyle(.borderless)
                                        .help(goal.isActive ? "無効化" : "有効化")

                                        Button(role: .destructive) {
                                            goalPendingDeletion = goal.id
                                        } label: {
                                            Image(systemName: "trash")
                                        }
                                        .buttonStyle(.borderless)
                                        .help("削除")
                                    }
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                            }
                            .frame(minHeight: 200)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("貯蓄目標")
        .sheet(isPresented: $store.isShowingForm) {
            SavingsGoalFormView(store: store)
        }
        .confirmationDialog(
            "貯蓄目標を削除しますか？",
            isPresented: Binding(
                get: { goalPendingDeletion != nil },
                set: { if !$0 { goalPendingDeletion = nil } },
            ),
            titleVisibility: .visible,
        ) {
            Button("削除", role: .destructive) {
                Task {
                    await deletePendingGoal()
                }
            }
            Button("キャンセル", role: .cancel) {}
        }
        .task {
            await store.observeGoals()
        }
    }

    private func deletePendingGoal() async {
        guard let goalId = goalPendingDeletion else { return }
        try? await store.deleteGoal(goalId)
        goalPendingDeletion = nil
    }
}
