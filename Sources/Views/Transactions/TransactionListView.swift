import SwiftUI

internal struct TransactionListView: View {
    @Environment(\.storeFactory) private var storeFactory: StoreFactory?
    @State private var store: TransactionStore?

    internal var body: some View {
        Group {
            if let store {
                TransactionListContentView(store: store)
            } else {
                ProgressView("データを読み込み中…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear(perform: prepareStore)
    }

    private func prepareStore() {
        guard store == nil else { return }
        guard let factory = storeFactory else {
            assertionFailure("StoreFactory is unavailable")
            return
        }
        Task {
            let transactionStore = await factory.makeTransactionStore()
            await MainActor.run {
                store = transactionStore
            }
        }
    }
}

internal struct TransactionListContentView: View {
    @Bindable internal var store: TransactionStore

    internal var body: some View {
        VStack(spacing: 16) {
            TransactionFilterBar(store: store)
            summaryBar
            content
        }
        .padding()
        .navigationTitle("取引一覧")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task {
                        await store.refresh()
                    }
                } label: {
                    Label("再読み込み", systemImage: "arrow.clockwise")
                }

                Button {
                    store.prepareForNewTransaction()
                } label: {
                    Label("取引を追加", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: [.command])
            }
        }
        .sheet(isPresented: $store.isEditorPresented) {
            TransactionEditorView(store: store)
        }
    }

    private var summaryBar: some View {
        HStack(spacing: 16) {
            summaryItem(title: "収入", value: store.totalIncome, tint: .income)
            summaryItem(title: "支出", value: store.totalExpense, tint: .expense)
            summaryItem(title: "差引", value: store.netAmount, tint: store.netAmount >= 0 ? .positive : .negative)
            Spacer()
            Text("\(store.transactions.count)件")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var content: some View {
        if store.sections.isEmpty {
            ContentUnavailableView {
                Label("取引がありません", systemImage: "tray")
            } description: {
                Text("フィルタを変更するか、取引を追加してください。")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(store.sections) { section in
                    Section(section.title) {
                        ForEach(section.transactions, id: \.id) { transaction in
                            TransactionRow(
                                transaction: transaction,
                                categoryFullName: categoryFullName(for: transaction),
                                institutionName: institutionName(for: transaction),
                                onEdit: { editedTransaction in
                                    store.startEditing(transaction: editedTransaction)
                                },
                                onDelete: { transactionId in
                                    Task { await store.deleteTransaction(transactionId) }
                                },
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    Task { await store.deleteTransaction(transaction.id) }
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }

                                Button {
                                    store.startEditing(transaction: transaction)
                                } label: {
                                    Label("編集", systemImage: "square.and.pencil")
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
    }

    private func summaryItem(title: String, value: Decimal, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value.currencyFormatted)
                .font(.title3.bold())
                .foregroundStyle(tint)
        }
    }

    private func categoryFullName(for transaction: Transaction) -> String {
        let majorName: String? = {
            guard let majorId = transaction.majorCategoryId else { return nil }
            return store.availableCategories.first { $0.id == majorId }?.name
        }()

        let minorName: String? = {
            guard let minorId = transaction.minorCategoryId else { return nil }
            return store.availableCategories.first { $0.id == minorId }?.name
        }()

        if let minorName, let majorName {
            return "\(majorName) / \(minorName)"
        } else if let majorName {
            return majorName
        } else {
            return "未分類"
        }
    }

    private func institutionName(for transaction: Transaction) -> String? {
        guard let institutionId = transaction.financialInstitutionId else {
            return nil
        }
        return store.availableInstitutions.first { $0.id == institutionId }?.name
    }
}
