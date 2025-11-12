import SwiftData
import SwiftUI

/// 予算管理ビュー
///
/// 月次予算と年次特別枠を編集・確認するための画面。
internal struct BudgetView: View {
    @Environment(\.appModelContainer) private var modelContainer: ModelContainer?
    @State private var store: BudgetStore?

    @State private var isPresentingBudgetEditor: Bool = false
    @State private var isPresentingAnnualEditor: Bool = false
    @State private var isPresentingReconciliation: Bool = false
    @State private var isPresentingSpecialPaymentEditor: Bool = false

    @State private var budgetEditorMode: BudgetEditorMode = .create
    @State private var budgetFormState: BudgetEditorFormState = .init()
    @State private var annualFormState: AnnualBudgetFormState = .init()
    @State private var specialPaymentEditorMode: SpecialPaymentEditorMode = .create
    @State private var specialPaymentFormState: SpecialPaymentFormState = .init()

    @State private var budgetFormError: String?
    @State private var annualFormError: String?
    @State private var specialPaymentFormError: String?

    @State private var budgetPendingDeletion: BudgetDTO?
    @State private var specialPaymentPendingDeletion: SpecialPaymentDefinition?
    @State private var errorMessage: String?
    @State private var isShowingErrorAlert: Bool = false

    internal var body: some View {
        VStack(spacing: 0) {
            if let store {
                let refreshToken = store.refreshToken

                Group {
                    BudgetToolbarView(store: store, isPresentingReconciliation: $isPresentingReconciliation)
                        .padding(.horizontal)
                        .padding(.top)

                    ScrollView {
                        VStack(spacing: 20) {
                            switch store.displayMode {
                            case .monthly:
                                MonthlyBudgetGrid(
                                    title: "\(store.currentYear.yearDisplayString)年\(store.currentMonth)月",
                                    overallEntry: store.overallBudgetEntry,
                                    categoryEntries: store.categoryBudgetEntries,
                                    onAdd: { presentBudgetEditor(for: nil) },
                                    onEdit: { presentBudgetEditor(for: $0) },
                                    onDelete: { budgetPendingDeletion = $0 },
                                )

                                AnnualBudgetPanel(
                                    year: store.currentYear,
                                    config: store.annualBudgetConfig,
                                    usage: store.annualBudgetUsage,
                                    categories: store.selectableCategories,
                                    onEdit: presentAnnualEditor,
                                )

                                BudgetSpecialPaymentSection(
                                    onEdit: { presentSpecialPaymentEditor(for: $0) },
                                    onDelete: { specialPaymentPendingDeletion = $0 },
                                    onAdd: { presentSpecialPaymentEditor(for: nil) },
                                )

                            case .annual:
                                AnnualBudgetGrid(
                                    title: "\(store.currentYear.yearDisplayString)年",
                                    overallEntry: store.annualOverallBudgetEntry,
                                    categoryEntries: store.annualCategoryBudgetEntries,
                                )

                                AnnualBudgetPanel(
                                    year: store.currentYear,
                                    config: store.annualBudgetConfig,
                                    usage: store.annualBudgetUsage,
                                    categories: store.selectableCategories,
                                    onEdit: presentAnnualEditor,
                                )

                                BudgetSpecialPaymentSection(
                                    onEdit: { presentSpecialPaymentEditor(for: $0) },
                                    onDelete: { specialPaymentPendingDeletion = $0 },
                                    onAdd: { presentSpecialPaymentEditor(for: nil) },
                                )

                            case .specialPaymentsList:
                                SpecialPaymentListView()
                            }
                        }
                        .padding()
                    }
                }
                .id(refreshToken)
            } else {
                ProgressView("データを読み込み中…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("予算")
        .onAppear(perform: prepareStore)
        .sheet(isPresented: $isPresentingBudgetEditor) {
            if let store {
                BudgetEditorSheet(
                    formState: $budgetFormState,
                    categories: store.selectableCategories,
                    mode: budgetEditorMode,
                    errorMessage: budgetFormError,
                    onCancel: dismissBudgetEditor,
                    onSave: saveBudget,
                )
                .frame(minWidth: 420, minHeight: 260)
                .presentationSizing(.fitted)
            }
        }
        .sheet(isPresented: $isPresentingAnnualEditor) {
            AnnualBudgetEditorSheet(
                formState: $annualFormState,
                categories: store?.selectableCategories ?? [],
                errorMessage: annualFormError,
                onCancel: dismissAnnualEditor,
                onSave: saveAnnualBudgetConfig,
            )
            .frame(minWidth: 420, minHeight: 220)
            .presentationSizing(.fitted)
        }
        .sheet(isPresented: $isPresentingReconciliation) {
            SpecialPaymentReconciliationView()
        }
        .sheet(isPresented: $isPresentingSpecialPaymentEditor) {
            if let store {
                SpecialPaymentEditorSheet(
                    formState: $specialPaymentFormState,
                    categories: store.selectableCategories,
                    mode: specialPaymentEditorMode,
                    errorMessage: specialPaymentFormError,
                    onCancel: dismissSpecialPaymentEditor,
                    onSave: saveSpecialPayment,
                )
                .frame(minWidth: 520, minHeight: 600)
                .presentationSizing(.fitted)
            }
        }
        .confirmationDialog(
            "予算を削除しますか？",
            isPresented: Binding(
                get: { budgetPendingDeletion != nil },
                set: { if !$0 { budgetPendingDeletion = nil } },
            ),
            titleVisibility: .visible,
        ) {
            Button("削除", role: .destructive) {
                deletePendingBudget()
            }
            Button("キャンセル", role: .cancel) {}
        }
        .confirmationDialog(
            "特別支払いを削除しますか？",
            isPresented: Binding(
                get: { specialPaymentPendingDeletion != nil },
                set: { if !$0 { specialPaymentPendingDeletion = nil } },
            ),
            titleVisibility: .visible,
        ) {
            Button("削除", role: .destructive) {
                deletePendingSpecialPayment()
            }
            Button("キャンセル", role: .cancel) {}
        }
        .alert(
            "エラー",
            isPresented: $isShowingErrorAlert,
            actions: {
                Button("OK", role: .cancel) {}
            },
            message: {
                Text(errorMessage ?? "不明なエラーが発生しました")
            },
        )
    }
}

// MARK: - Store Preparation

private extension BudgetView {
    func prepareStore() {
        guard store == nil else { return }
        Task { @DatabaseActor in
            guard await MainActor.run(body: { store == nil }) else { return }
            guard let container = await MainActor.run(body: { modelContainer }) else {
                assertionFailure("ModelContainer is unavailable")
                return
            }
            let context = ModelContext(container)
            let repository = SwiftDataBudgetRepository(modelContext: context)
            let monthlyUseCase = DefaultMonthlyBudgetUseCase()
            let annualUseCase = DefaultAnnualBudgetUseCase()
            let specialPaymentUseCase = DefaultSpecialPaymentSavingsUseCase()
            let mutationUseCase = DefaultBudgetMutationUseCase(repository: repository)
            let budgetStore = BudgetStore(
                repository: repository,
                monthlyUseCase: monthlyUseCase,
                annualUseCase: annualUseCase,
                specialPaymentUseCase: specialPaymentUseCase,
                mutationUseCase: mutationUseCase,
            )
            await MainActor.run {
                guard store == nil else { return }
                store = budgetStore
            }
        }
    }
}

// MARK: - Budget Editor

private extension BudgetView {
    func presentBudgetEditor(for budget: BudgetDTO?) {
        guard let store else { return }
        budgetFormError = nil
        if let budget {
            budgetEditorMode = .edit(budget)
            budgetFormState.load(from: budget)
        } else {
            budgetEditorMode = .create
            budgetFormState.reset(
                defaultYear: store.currentYear,
                defaultMonth: store.currentMonth,
            )
        }
        isPresentingBudgetEditor = true
    }

    func dismissBudgetEditor() {
        isPresentingBudgetEditor = false
    }

    func saveBudget() {
        guard let store else { return }
        guard let amount = budgetFormState.decimalAmount, amount > 0 else {
            budgetFormError = "金額を正しく入力してください"
            return
        }

        let normalizedStart = budgetFormState.normalizedStartDate
        let normalizedEnd = budgetFormState.normalizedEndDate
        guard normalizedStart <= normalizedEnd else {
            budgetFormError = "終了月は開始月以降を選択してください"
            return
        }

        let startYear = normalizedStart.year
        let startMonth = normalizedStart.month
        let endYear = normalizedEnd.year
        let endMonth = normalizedEnd.month

        let input = BudgetInput(
            amount: amount,
            categoryId: budgetFormState.selectedCategoryId,
            startYear: startYear,
            startMonth: startMonth,
            endYear: endYear,
            endMonth: endMonth,
        )

        Task {
            do {
                switch budgetEditorMode {
                case .create:
                    try await store.addBudget(input)
                case let .edit(budget):
                    try await store.updateBudget(budget: budget, input: input)
                }
                isPresentingBudgetEditor = false
            } catch BudgetStoreError.categoryNotFound {
                budgetFormError = "選択したカテゴリが見つかりませんでした"
            } catch BudgetStoreError.invalidPeriod {
                budgetFormError = "期間が不正です。終了月は開始月以降を選択してください"
            } catch {
                showError(message: "予算の保存に失敗しました: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Annual Budget Editor

private extension BudgetView {
    func presentAnnualEditor() {
        guard let store else { return }
        annualFormError = nil
        if let config = store.annualBudgetConfig {
            annualFormState.load(from: config, categories: store.selectableCategories)
        } else {
            annualFormState.reset()
            annualFormState.ensureInitialRow()
        }
        isPresentingAnnualEditor = true
    }

    func dismissAnnualEditor() {
        isPresentingAnnualEditor = false
    }

    func saveAnnualBudgetConfig() {
        guard let store else { return }
        guard let amount = validatedAnnualTotalAmount() else { return }
        guard let finalizedDrafts = finalizedAnnualAllocations(totalAmount: amount) else {
            return
        }
        guard ensureUniqueAnnualCategories(finalizedDrafts) else { return }

        Task {
            do {
                try await store.upsertAnnualBudgetConfig(
                    totalAmount: amount,
                    policy: annualFormState.policy,
                    allocations: finalizedDrafts,
                )
                isPresentingAnnualEditor = false
            } catch BudgetStoreError.categoryNotFound {
                annualFormError = "選択したカテゴリが見つかりませんでした"
            } catch BudgetStoreError.duplicateAnnualAllocationCategory {
                annualFormError = "カテゴリが重複しています"
            } catch {
                showError(message: "年次特別枠の保存に失敗しました: \(error.localizedDescription)")
            }
        }
    }

    func validatedAnnualTotalAmount() -> Decimal? {
        guard let amount = annualFormState.decimalAmount, amount > 0 else {
            annualFormError = "総額を正しく入力してください"
            return nil
        }
        return amount
    }

    func finalizedAnnualAllocations(totalAmount: Decimal) -> [AnnualAllocationDraft]? {
        switch annualFormState.finalizeAllocations(totalAmount: totalAmount) {
        case let .success(result):
            return result
        case let .failure(error):
            switch error {
            case .noAllocations:
                annualFormError = "カテゴリと金額を入力してください"
            case .manualDoesNotMatchTotal:
                annualFormError = "カテゴリ合計が総額と一致していません"
            }
            return nil
        }
    }

    func ensureUniqueAnnualCategories(_ drafts: [AnnualAllocationDraft]) -> Bool {
        let uniqueCategoryIds = Set(drafts.map(\.categoryId))
        let hasDuplicates = uniqueCategoryIds.count != drafts.count
        if hasDuplicates {
            annualFormError = "カテゴリが重複しています"
        }
        return !hasDuplicates
    }
}

// MARK: - Special Payment Editor

private extension BudgetView {
    func presentSpecialPaymentEditor(for definition: SpecialPaymentDefinition?) {
        specialPaymentFormError = nil
        if let definition {
            specialPaymentEditorMode = .edit(definition)
            specialPaymentFormState.load(from: definition)
        } else {
            specialPaymentEditorMode = .create
            specialPaymentFormState.reset()
        }
        isPresentingSpecialPaymentEditor = true
    }

    func dismissSpecialPaymentEditor() {
        isPresentingSpecialPaymentEditor = false
    }

    @MainActor
    func saveSpecialPayment() {
        guard specialPaymentFormState.isValid else {
            specialPaymentFormError = "入力内容を確認してください"
            return
        }

        guard let amount = specialPaymentFormState.decimalAmount else {
            specialPaymentFormError = "金額を正しく入力してください"
            return
        }

        let input = SpecialPaymentDefinitionInput(
            name: specialPaymentFormState.nameText.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: specialPaymentFormState.notesText,
            amount: amount,
            recurrenceIntervalMonths: specialPaymentFormState.recurrenceIntervalMonths,
            firstOccurrenceDate: specialPaymentFormState.firstOccurrenceDate,
            leadTimeMonths: specialPaymentFormState.leadTimeMonths,
            categoryId: specialPaymentFormState.selectedCategoryId,
            savingStrategy: specialPaymentFormState.savingStrategy,
            customMonthlySavingAmount: specialPaymentFormState.customMonthlySavingAmount,
            dateAdjustmentPolicy: specialPaymentFormState.dateAdjustmentPolicy,
            recurrenceDayPattern: specialPaymentFormState.recurrenceDayPattern,
        )
        Task { @DatabaseActor in
            guard let container = await MainActor.run(body: { modelContainer }) else {
                assertionFailure("ModelContainer is unavailable")
                return
            }
            let context = ModelContext(container)
            let mode = await MainActor.run { specialPaymentEditorMode }
            let repository = SwiftDataSpecialPaymentRepository(modelContext: context)
            let specialPaymentStore = SpecialPaymentStore(repository: repository)

            do {
                switch mode {
                case .create:
                    try await specialPaymentStore.createDefinition(input)
                case let .edit(definition):
                    try await specialPaymentStore.updateDefinition(definitionId: definition.id, input: input)
                }
                await MainActor.run {
                    isPresentingSpecialPaymentEditor = false
                }
            } catch SpecialPaymentDomainError.categoryNotFound {
                await MainActor.run {
                    specialPaymentFormError = "選択したカテゴリが見つかりませんでした"
                }
            } catch let SpecialPaymentDomainError.validationFailed(errors) {
                await MainActor.run {
                    specialPaymentFormError = errors.joined(separator: "\n")
                }
            } catch {
                await MainActor.run {
                    showError(message: "特別支払いの保存に失敗しました: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Delete

private extension BudgetView {
    func deletePendingBudget() {
        guard let store, let budget = budgetPendingDeletion else { return }
        Task {
            do {
                try await store.deleteBudget(budget)
            } catch {
                showError(message: "予算の削除に失敗しました: \(error.localizedDescription)")
            }
            budgetPendingDeletion = nil
        }
    }

    @MainActor
    func deletePendingSpecialPayment() {
        guard let definition = specialPaymentPendingDeletion else { return }
        Task { @DatabaseActor in
            guard let container = await MainActor.run(body: { modelContainer }) else {
                assertionFailure("ModelContainer is unavailable")
                return
            }
            let context = ModelContext(container)
            let repository = SwiftDataSpecialPaymentRepository(modelContext: context)
            let specialPaymentStore = SpecialPaymentStore(repository: repository)
            do {
                try await specialPaymentStore.deleteDefinition(definitionId: definition.id)
            } catch {
                await MainActor.run {
                    showError(message: "特別支払いの削除に失敗しました: \(error.localizedDescription)")
                }
            }
            await MainActor.run {
                specialPaymentPendingDeletion = nil
            }
        }
    }
}

// MARK: - Error Handling

private extension BudgetView {
    func showError(message: String) {
        errorMessage = message
        isShowingErrorAlert = true
    }
}
