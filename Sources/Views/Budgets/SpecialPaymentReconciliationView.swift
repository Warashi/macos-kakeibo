import SwiftData
import SwiftUI

internal struct SpecialPaymentReconciliationView: View {
    @Environment(\.modelContext) private var modelContext: ModelContext
    @State private var store: SpecialPaymentReconciliationStore?

    internal var body: some View {
        Group {
            if let store {
                SpecialPaymentReconciliationContentView(store: store)
            } else {
                ProgressView("特別支払い情報を読み込み中…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear(perform: prepareStore)
        .frame(minWidth: 920, minHeight: 620)
    }

    private func prepareStore() {
        guard store == nil else { return }
        let reconciliationStore = SpecialPaymentReconciliationStore(modelContext: modelContext)
        reconciliationStore.refresh()
        store = reconciliationStore
    }
}

internal struct SpecialPaymentReconciliationContentView: View {
    @Bindable internal var store: SpecialPaymentReconciliationStore
    @State private var isErrorAlertPresented: Bool = false

    internal var body: some View {
        VStack(spacing: 16) {
            header
            Divider()
            HStack(spacing: 16) {
                occurrenceList
                    .frame(width: 320)
                Divider()
                detailPanel
            }
        }
        .padding()
        .overlay(alignment: .bottom) {
            if store.isSaving {
                ProgressView("保存中…")
                    .padding()
                    .background(.thinMaterial, in: Capsule())
                    .padding()
            }
        }
        .onChange(of: store.errorMessage) { _, newValue in
            isErrorAlertPresented = newValue != nil
        }
        .alert(
            "エラー",
            isPresented: $isErrorAlertPresented,
            presenting: store.errorMessage,
        ) { _ in
            Button("OK", role: .cancel) {
                store.clearError()
            }
        } message: { message in
            Text(message)
        }
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("特別支払いと取引の突合")
                    .font(.title2.bold())
                Spacer()
                Button {
                    store.refresh()
                } label: {
                    Label("再読み込み", systemImage: "arrow.clockwise")
                }
                .disabled(store.isLoading)
            }

            if let status = store.statusMessage {
                Label(status, systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                TextField(
                    "キーワード検索",
                    text: $store.searchText,
                )
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 280)

                Picker("状態", selection: $store.filter) {
                    ForEach(SpecialPaymentReconciliationStore.OccurrenceFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)
            }
        }
    }

    private var occurrenceList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("特別支払い一覧")
                .font(.headline)

            if store.filteredRows.isEmpty {
                ContentUnavailableView {
                    Label("対象の特別支払いがありません", systemImage: "tray")
                } description: {
                    Text("フィルタや検索条件を調整してください。")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: Binding(
                    get: { store.selectedOccurrenceId },
                    set: { store.selectedOccurrenceId = $0 },
                )) {
                    ForEach(store.filteredRows) { row in
                        OccurrenceRowView(row: row)
                            .tag(row.id)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var detailPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let selected = store.selectedRow {
                detailHeader(for: selected)
                Divider()
                plannedInfo(for: selected)
                Divider()
                formSection
                Divider()
                candidateList
                Spacer()
            } else {
                ContentUnavailableView {
                    Label("特別支払いを選択してください", systemImage: "hand.point.up.left")
                } description: {
                    Text("左の一覧から突合したい項目を選びます。")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func detailHeader(for row: SpecialPaymentReconciliationStore.OccurrenceRow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(row.definitionName)
                    .font(.title3.bold())
                StatusBadge(text: row.statusLabel, isHighlighted: row.needsAttention, isCompleted: row.isCompleted)
            }
            Text(row.categoryName ?? "カテゴリ未設定")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func plannedInfo(for row: SpecialPaymentReconciliationStore.OccurrenceRow) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 12) {
            gridRow(title: "予定日", value: row.scheduledDate.longDateFormatted)
            gridRow(title: "予定金額", value: row.expectedAmount.currencyFormatted)
            gridRow(title: "周期", value: row.recurrenceDescription)
            gridRow(
                title: "候補取引",
                value: row.transactionTitle ?? "未リンク",
            )
        }
        .font(.subheadline)
    }

    private func gridRow(title: String, value: String) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
        }
    }

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("実績の調整")
                .font(.headline)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("実績金額")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("例: 150000", text: $store.actualAmountText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 180)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("実績日")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DatePicker(
                        "",
                        selection: $store.actualDate,
                        displayedComponents: [.date],
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                }
            }

            HStack(spacing: 12) {
                Button {
                    store.saveSelectedOccurrence()
                } label: {
                    Label("実績を保存", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isSaving)

                Button("リセット") {
                    store.resetFormToExpectedValues()
                }

                Button("リンク解除", role: .destructive) {
                    store.unlinkSelectedOccurrence()
                }
                .disabled(store.selectedRow?.transactionTitle == nil)
            }
        }
    }

    private var candidateList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("候補取引")
                .font(.headline)

            if store.candidateTransactions.isEmpty {
                ContentUnavailableView {
                    Label("候補が見つかりません", systemImage: "exclamationmark.circle")
                } description: {
                    Text("期間や金額が大きく異なる場合は手動で入力してください。")
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(store.candidateTransactions) { candidate in
                        CandidateRow(
                            candidate: candidate,
                            isSelected: candidate.id == store.selectedTransactionId,
                            onSelect: {
                                store.selectCandidate(candidate.id)
                            },
                        )
                    }
                }
            }
        }
    }
}

private struct OccurrenceRowView: View {
    internal let row: SpecialPaymentReconciliationStore.OccurrenceRow

    internal var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(row.definitionName)
                    .font(.headline)
                Spacer()
                Text(row.scheduledDate.shortDateFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(row.categoryName ?? "カテゴリ未設定")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                StatusBadge(text: row.statusLabel, isHighlighted: row.needsAttention, isCompleted: row.isCompleted)
                if row.isOverdue {
                    Label("期限超過", systemImage: "clock.badge.exclamationmark")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15), in: Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct CandidateRow: View {
    internal let candidate: SpecialPaymentReconciliationStore.TransactionCandidate
    internal let isSelected: Bool
    internal let onSelect: () -> Void

    private var transaction: Transaction { candidate.transaction }

    internal var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(transaction.title)
                        .font(.headline)
                    Spacer()
                    Text(candidate.score.confidenceText)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15), in: Capsule())
                }
                HStack {
                    Text(transaction.date.shortDateFormatted)
                    Text(transaction.amount.currencyFormatted)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Text(candidate.score.detailDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.blue.opacity(0.08) : Color.gray.opacity(0.08)),
            )
        }
        .buttonStyle(.plain)
    }
}

private struct StatusBadge: View {
    internal let text: String
    internal let isHighlighted: Bool
    internal let isCompleted: Bool

    internal var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(badgeColor.opacity(0.15)),
            )
            .foregroundStyle(badgeColor)
    }

    private var badgeColor: Color {
        if isCompleted {
            return .green
        }
        if isHighlighted {
            return .orange
        }
        return .gray
    }
}
