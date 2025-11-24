import Foundation
import Observation

/// 定期支払い提案画面用のストア
@MainActor
@Observable
internal final class RecurringPaymentSuggestionStore {
    // MARK: - Properties

    private let suggestionUseCase: RecurringPaymentSuggestionUseCaseProtocol
    private let recurringPaymentStore: RecurringPaymentStore

    /// 提案リスト
    internal private(set) var suggestions: [RecurringPaymentSuggestion] = []

    /// 選択された提案のID
    internal var selectedSuggestionIds: Set<UUID> = []

    /// ローディング状態
    internal private(set) var isLoading = false

    /// エラーメッセージ
    internal private(set) var errorMessage: String?

    /// 編集モード用の状態
    internal var isEditorPresented = false
    internal var editingSuggestion: RecurringPaymentSuggestion?

    // MARK: - Initialization

    internal init(
        suggestionUseCase: RecurringPaymentSuggestionUseCaseProtocol,
        recurringPaymentStore: RecurringPaymentStore
    ) {
        self.suggestionUseCase = suggestionUseCase
        self.recurringPaymentStore = recurringPaymentStore
    }

    // MARK: - Public API

    /// 提案を生成
    func generateSuggestions(criteria: RecurringPaymentDetectionCriteria = .default) async {
        isLoading = true
        errorMessage = nil

        do {
            let results = try await suggestionUseCase.generateSuggestions(criteria: criteria)
            suggestions = results
            selectedSuggestionIds = []
        } catch {
            errorMessage = "提案の生成に失敗しました: \(error.localizedDescription)"
            suggestions = []
        }

        isLoading = false
    }

    /// 選択された提案を一括登録
    func registerSelectedSuggestions() async -> Bool {
        let selected = suggestions.filter { selectedSuggestionIds.contains($0.id) }
        guard !selected.isEmpty else { return false }

        var successCount = 0
        var failedNames: [String] = []

        for suggestion in selected {
            let success = await registerSuggestion(suggestion)
            if success {
                successCount += 1
            } else {
                failedNames.append(suggestion.suggestedName)
            }
        }

        // 成功した提案を削除
        suggestions.removeAll { selectedSuggestionIds.contains($0.id) }
        selectedSuggestionIds = []

        // エラーメッセージの設定
        if !failedNames.isEmpty {
            errorMessage = "一部の登録に失敗しました: \(failedNames.joined(separator: ", "))"
            return false
        }

        return true
    }

    /// 個別の提案を登録
    func registerSuggestion(_ suggestion: RecurringPaymentSuggestion) async -> Bool {
        let input = createDefinitionInput(from: suggestion)

        do {
            try await recurringPaymentStore.createDefinition(input)
            return true
        } catch {
            errorMessage = "\(suggestion.suggestedName)の登録に失敗しました: \(error.localizedDescription)"
            return false
        }
    }

    /// 提案を編集モードで開く
    func startEditing(suggestion: RecurringPaymentSuggestion) {
        editingSuggestion = suggestion
        isEditorPresented = true
    }

    /// 編集をキャンセル
    func cancelEditing() {
        editingSuggestion = nil
        isEditorPresented = false
    }

    /// 提案を無視（削除）
    func ignoreSuggestion(_ suggestionId: UUID) {
        suggestions.removeAll { $0.id == suggestionId }
        selectedSuggestionIds.remove(suggestionId)
    }

    /// 全選択/全解除
    func toggleSelectAll() {
        if selectedSuggestionIds.count == suggestions.count {
            selectedSuggestionIds = []
        } else {
            selectedSuggestionIds = Set(suggestions.map(\.id))
        }
    }

    /// 選択中の提案数
    var selectedCount: Int {
        selectedSuggestionIds.count
    }

    // MARK: - Private Helpers

    /// RecurringPaymentSuggestion から RecurringPaymentDefinitionInput を生成
    private func createDefinitionInput(from suggestion: RecurringPaymentSuggestion) -> RecurringPaymentDefinitionInput {
        RecurringPaymentDefinitionInput(
            name: suggestion.suggestedName,
            notes: "自動検出により登録（\(suggestion.occurrenceCount)回検出）",
            amount: suggestion.suggestedAmount,
            recurrenceIntervalMonths: suggestion.suggestedRecurrenceMonths,
            firstOccurrenceDate: suggestion.suggestedStartDate,
            endDate: nil,
            categoryId: suggestion.suggestedCategoryId,
            savingStrategy: .disabled,
            customMonthlySavingAmount: nil,
            dateAdjustmentPolicy: .none,
            recurrenceDayPattern: suggestion.suggestedDayPattern,
            matchKeywords: suggestion.suggestedMatchKeywords
        )
    }
}
