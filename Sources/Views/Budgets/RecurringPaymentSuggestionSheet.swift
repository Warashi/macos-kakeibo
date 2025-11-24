import SwiftUI

/// 定期支払い提案シート
internal struct RecurringPaymentSuggestionSheet: View {
    @Bindable private var store: RecurringPaymentSuggestionStore
    @Environment(\.dismiss) private var dismiss

    internal init(store: RecurringPaymentSuggestionStore) {
        self.store = store
    }

    internal var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            headerView

            Divider()

            // メインコンテンツ
            if store.isLoading {
                loadingView
            } else if store.suggestions.isEmpty {
                emptyView
            } else {
                suggestionListView
            }

            Divider()

            // フッター
            footerView
        }
        .frame(minWidth: 700, maxWidth: 700, minHeight: 600, maxHeight: 600)
        .sheet(isPresented: $store.isEditorPresented) {
            if store.editingSuggestion != nil {
                // 編集シートを表示（RecurringPaymentEditorSheetを再利用）
                // 注: この実装は後で統合が必要
                Text("編集機能は後で実装")
            }
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("定期支払いの提案")
                    .font(.headline)
                if !store.suggestions.isEmpty {
                    Text("\(store.suggestions.count)件の候補が見つかりました")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button("閉じる") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding()
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("取引データを分析中...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("定期的な支払いは見つかりませんでした")
                .font(.headline)
            Text("過去3年間の取引データから、2回以上繰り返される支払いを検出します")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var suggestionListView: some View {
        VStack(spacing: 0) {
            // 全選択チェックボックス
            HStack {
                Button {
                    store.toggleSelectAll()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: store.selectedCount == store.suggestions.count ? "checkmark.square.fill" : "square")
                        Text("全選択")
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)

                Spacer()

                Text("\(store.selectedCount)件選択中")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // 提案リスト
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(store.suggestions) { suggestion in
                        SuggestionCardView(
                            suggestion: suggestion,
                            isSelected: store.selectedSuggestionIds.contains(suggestion.id),
                            onToggleSelection: {
                                if store.selectedSuggestionIds.contains(suggestion.id) {
                                    store.selectedSuggestionIds.remove(suggestion.id)
                                } else {
                                    store.selectedSuggestionIds.insert(suggestion.id)
                                }
                            },
                            onEdit: {
                                store.startEditing(suggestion: suggestion)
                            },
                            onIgnore: {
                                store.ignoreSuggestion(suggestion.id)
                            }
                        )

                        if suggestion.id != store.suggestions.last?.id {
                            Divider()
                                .padding(.leading, 48)
                        }
                    }
                }
            }
        }
    }

    private var footerView: some View {
        HStack {
            if let errorMessage = store.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Spacer()

            Button("選択した項目を登録 (\(store.selectedCount)件)") {
                Task {
                    let success = await store.registerSelectedSuggestions()
                    if success {
                        dismiss()
                    }
                }
            }
            .disabled(store.selectedCount == 0)
            .keyboardShortcut(.defaultAction)
        }
        .padding()
    }
}

// MARK: - SuggestionCardView

private struct SuggestionCardView: View {
    let suggestion: RecurringPaymentSuggestion
    let isSelected: Bool
    let onToggleSelection: () -> Void
    let onEdit: () -> Void
    let onIgnore: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // チェックボックス
            Button {
                onToggleSelection()
            } label: {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .blue : .secondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

            // メインコンテンツ
            VStack(alignment: .leading, spacing: 8) {
                // タイトル行
                HStack {
                    Text(suggestion.suggestedName)
                        .font(.headline)
                    Spacer()
                    Text(suggestion.suggestedAmount.formatted(.currency(code: "JPY")))
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                // 詳細情報
                HStack(spacing: 16) {
                    Label(suggestion.patternDescription, systemImage: "repeat")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Label("\(suggestion.occurrenceCount)回検出", systemImage: "checkmark.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let lastDate = suggestion.lastOccurrenceDate {
                        Label("最終: \(lastDate.formatted(date: .numeric, time: .omitted))", systemImage: "calendar")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                // 金額の変動情報
                if !suggestion.isAmountStable, let range = suggestion.amountRange {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Text("金額に変動あり: \(range.lowerBound.formatted(.currency(code: "JPY"))) 〜 \(range.upperBound.formatted(.currency(code: "JPY")))")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                // アクションボタン
                HStack(spacing: 12) {
                    Button("詳細を編集") {
                        onEdit()
                    }
                    .buttonStyle(.link)
                    .controlSize(.small)

                    Button("無視") {
                        onIgnore()
                    }
                    .buttonStyle(.link)
                    .controlSize(.small)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .contentShape(Rectangle())
        .onTapGesture {
            onToggleSelection()
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    @Previewable @State var store: RecurringPaymentSuggestionStore = {
        let suggestion = RecurringPaymentSuggestion(
            suggestedName: "Netflix",
            suggestedAmount: 1490,
            suggestedRecurrenceMonths: 1,
            suggestedStartDate: Date(),
            suggestedCategoryId: nil,
            suggestedDayPattern: .fixed(15),
            suggestedMatchKeywords: ["Netflix"],
            relatedTransactions: [],
            isAmountStable: true,
            amountRange: 1490...1490,
            confidenceScore: 0.85
        )

        return RecurringPaymentSuggestionStore(
            suggestionUseCase: PreviewRecurringPaymentSuggestionUseCase(suggestions: [suggestion]),
            recurringPaymentStore: RecurringPaymentStore(
                repository: PreviewRecurringPaymentRepository()
            )
        )
    }()

    RecurringPaymentSuggestionSheet(store: store)
}

// Preview用のモック
private struct PreviewRecurringPaymentSuggestionUseCase: RecurringPaymentSuggestionUseCaseProtocol {
    let suggestions: [RecurringPaymentSuggestion]

    func generateSuggestions(criteria: RecurringPaymentDetectionCriteria) async throws -> [RecurringPaymentSuggestion] {
        suggestions
    }
}

private struct PreviewRecurringPaymentRepository: RecurringPaymentRepository {
    func definitions(filter: RecurringPaymentDefinitionFilter?) async throws -> [RecurringPaymentDefinition] { [] }
    func occurrences(query: RecurringPaymentOccurrenceQuery?) async throws -> [RecurringPaymentOccurrence] { [] }
    func balances(query: RecurringPaymentBalanceQuery?) async throws -> [RecurringPaymentSavingBalance] { [] }
    func categoryNames(ids: Set<UUID>) async throws -> [UUID: String] { [:] }
    func createDefinition(_ input: RecurringPaymentDefinitionInput) async throws -> UUID { UUID() }
    func updateDefinition(definitionId: UUID, input: RecurringPaymentDefinitionInput) async throws -> Bool { false }
    func deleteDefinition(definitionId: UUID) async throws {}
    func synchronize(definitionId: UUID, horizonMonths: Int, referenceDate: Date?, backfillFromFirstDate: Bool) async throws -> RecurringPaymentSynchronizationSummary {
        RecurringPaymentSynchronizationSummary(syncedAt: Date(), createdCount: 0, updatedCount: 0, removedCount: 0)
    }
    func markOccurrenceCompleted(occurrenceId: UUID, input: OccurrenceCompletionInput, horizonMonths: Int) async throws -> RecurringPaymentSynchronizationSummary {
        RecurringPaymentSynchronizationSummary(syncedAt: Date(), createdCount: 0, updatedCount: 0, removedCount: 0)
    }
    func updateOccurrence(occurrenceId: UUID, input: OccurrenceUpdateInput, horizonMonths: Int) async throws -> RecurringPaymentSynchronizationSummary? { nil }
    func skipOccurrence(occurrenceId: UUID, horizonMonths: Int) async throws -> RecurringPaymentSynchronizationSummary {
        RecurringPaymentSynchronizationSummary(syncedAt: Date(), createdCount: 0, updatedCount: 0, removedCount: 0)
    }
    func saveChanges() async throws {}
}
#endif
