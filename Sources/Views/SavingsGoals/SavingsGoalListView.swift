import SwiftUI

/// 貯蓄目標一覧ビュー
internal struct SavingsGoalListView: View {
    @Environment(\.storeFactory) private var storeFactory: StoreFactory?
    @State private var store: SavingsGoalStore?
    @State private var goalPendingDeletion: UUID?

    internal init() {}

    internal var body: some View {
        VStack(spacing: 0) {
            if let store {
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

                            if store.entries.isEmpty {
                            EmptyStatePlaceholder(
                                systemImage: "banknote",
                                title: "貯蓄目標が未登録です",
                                message: "「貯蓄目標を追加」ボタンから新しい貯蓄目標を作成できます。",
                            )
                            } else {
                                Table(store.entries) {
                                    TableColumn("名称") { entry in
                                        HStack(spacing: 8) {
                                            Text(entry.goal.name)
                                                .fontWeight(.regular)

                                            if !entry.goal.isActive {
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

                                    TableColumn("月次積立額") { entry in
                                        Text(entry.goal.monthlySavingAmount.currencyFormatted)
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                    }

                                    TableColumn("目標金額") { entry in
                                        Group {
                                            if let targetAmount = entry.goal.targetAmount {
                                                Text(targetAmount.currencyFormatted)
                                            } else {
                                                Text("—")
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                    }

                                    TableColumn("現在残高") { entry in
                                        Group {
                                            if let balance = entry.balance {
                                                Text(balance.balance.currencyFormatted)
                                                    .foregroundColor(balance.balance >= 0 ? .primary : .red)
                                            } else {
                                                Text("¥0")
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                    }

                                    TableColumn("進捗") { entry in
                                        HStack(spacing: 8) {
                                            if let progress = entry.progress {
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

                                    TableColumn("操作") { entry in
                                        HStack {
                                            Button {
                                                store.prepareFormForEdit(entry.goal)
                                            } label: {
                                                Image(systemName: "pencil")
                                            }
                                            .buttonStyle(.borderless)
                                            .help("編集")

                                            Button {
                                                Task {
                                                    try? await store.toggleGoalActive(entry.goal.id)
                                                }
                                            } label: {
                                                Image(systemName: entry.goal.isActive ? "pause.circle" : "play.circle")
                                            }
                                            .buttonStyle(.borderless)
                                            .help(entry.goal.isActive ? "無効化" : "有効化")

                                            Button(role: .destructive) {
                                                goalPendingDeletion = entry.goal.id
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
                .navigationTitle("貯蓄目標")
                .sheet(isPresented: Binding(
                    get: { store.isShowingForm },
                    set: { store.isShowingForm = $0 }
                )) {
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
            } else {
                ProgressView()
            }
        }
        .task {
            await prepareStore()
        }
    }

    private func prepareStore() async {
        guard store == nil else { return }
        guard await MainActor.run(body: { store == nil }) else { return }
        guard let factory = await MainActor.run(body: { storeFactory }) else {
            assertionFailure("StoreFactory is unavailable")
            return
        }

        let savingsGoalStore = await factory.makeSavingsGoalStore()

        await MainActor.run {
            guard store == nil else { return }
            store = savingsGoalStore
        }
    }

    private func deletePendingGoal() async {
        guard let goalId = goalPendingDeletion else { return }
        try? await store?.deleteGoal(goalId)
        goalPendingDeletion = nil
    }
}
