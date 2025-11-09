import SwiftData
import SwiftUI

internal struct TransactionListView: View {
    @Environment(\.modelContext) private var modelContext: ModelContext
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
        .onAppear {
            guard store == nil else { return }
            store = TransactionStore(modelContext: modelContext)
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
                    store.refresh()
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
                                onEdit: { store.startEditing(transaction: $0) },
                                onDelete: { _ = store.deleteTransaction($0) },
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    _ = store.deleteTransaction(transaction)
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
}
