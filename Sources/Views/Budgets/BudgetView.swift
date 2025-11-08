import SwiftData
import SwiftUI

/// 予算管理ビュー
///
/// 月次予算と年次特別枠を編集・確認するための画面。
internal struct BudgetView: View {
    @Environment(\.modelContext) private var modelContext: ModelContext
    @State private var store: BudgetStore?

    @State private var isPresentingBudgetEditor = false
    @State private var isPresentingAnnualEditor = false

    @State private var budgetEditorMode: BudgetEditorMode = .create
    @State private var budgetFormState: BudgetEditorFormState = .init()
    @State private var annualFormState: AnnualBudgetFormState = .init()

    @State private var budgetFormError: String?
    @State private var annualFormError: String?

    @State private var budgetPendingDeletion: Budget?
    @State private var errorMessage: String?
    @State private var isShowingErrorAlert = false

    internal var body: some View {
        Group {
            if let store {
                ScrollView {
                    VStack(spacing: 20) {
                        toolbarSection(store: store)

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
                            onEdit: presentAnnualEditor,
                        )
                    }
                    .padding()
                }
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

    // MARK: - View Builders

    @ViewBuilder
    private func toolbarSection(store: BudgetStore) -> some View {
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

            Spacer()

            Button("今月") {
                store.moveToCurrentMonth()
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }

    // MARK: - Store Preparation

    private func prepareStore() {
        guard store == nil else { return }
        store = BudgetStore(modelContext: modelContext)
    }

    // MARK: - Budget Editor

    private func presentBudgetEditor(for budget: Budget?) {
        budgetFormError = nil
        if let budget {
            budgetEditorMode = .edit(budget)
            budgetFormState.load(from: budget)
        } else {
            budgetEditorMode = .create
            budgetFormState.reset()
        }
        isPresentingBudgetEditor = true
    }

    private func dismissBudgetEditor() {
        isPresentingBudgetEditor = false
    }

    private func saveBudget() {
        guard let store else { return }
        guard let amount = budgetFormState.decimalAmount, amount > 0 else {
            budgetFormError = "金額を正しく入力してください"
            return
        }

        do {
            switch budgetEditorMode {
            case .create:
                try store.addBudget(amount: amount, categoryId: budgetFormState.selectedCategoryId)
            case let .edit(budget):
                try store.updateBudget(
                    budget: budget,
                    amount: amount,
                    categoryId: budgetFormState.selectedCategoryId,
                )
            }
            isPresentingBudgetEditor = false
        } catch BudgetStoreError.categoryNotFound {
            budgetFormError = "選択したカテゴリが見つかりませんでした"
        } catch {
            showError(message: "予算の保存に失敗しました: \(error.localizedDescription)")
        }
    }

    // MARK: - Annual Budget Editor

    private func presentAnnualEditor() {
        annualFormError = nil
        if let config = store?.annualBudgetConfig {
            annualFormState.load(from: config)
        } else {
            annualFormState.reset()
            annualFormState.ensureInitialRow()
        }
        isPresentingAnnualEditor = true
    }

    private func dismissAnnualEditor() {
        isPresentingAnnualEditor = false
    }

    private func saveAnnualBudgetConfig() {
        guard let store else { return }
        guard let amount = annualFormState.decimalAmount, amount > 0 else {
            annualFormError = "総額を正しく入力してください"
            return
        }

        guard let drafts = annualFormState.makeAllocationDrafts(), !drafts.isEmpty else {
            annualFormError = "カテゴリと金額を入力してください"
            return
        }

        let uniqueCategoryIds = Set(drafts.map(\.categoryId))
        guard uniqueCategoryIds.count == drafts.count else {
            annualFormError = "カテゴリが重複しています"
            return
        }

        let allocationSum = drafts.reduce(0) { $0 + $1.amount }
        guard allocationSum == amount else {
            annualFormError = "カテゴリ合計（\(allocationSum.currencyFormatted)）と総額（\(amount.currencyFormatted)）が一致していません"
            return
        }

        do {
            try store.upsertAnnualBudgetConfig(
                totalAmount: amount,
                policy: annualFormState.policy,
                allocations: drafts,
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

    // MARK: - Delete

    private func deletePendingBudget() {
        guard let store, let budget = budgetPendingDeletion else { return }
        do {
            try store.deleteBudget(budget)
        } catch {
            showError(message: "予算の削除に失敗しました: \(error.localizedDescription)")
        }
        budgetPendingDeletion = nil
    }

    // MARK: - Error Handling

    private func showError(message: String) {
        errorMessage = message
        isShowingErrorAlert = true
    }
}

// MARK: - Budget Editor Sheet

private struct BudgetEditorSheet: View {
    @Binding var formState: BudgetEditorFormState
    internal let categories: [Category]
    internal let mode: BudgetEditorMode
    internal let errorMessage: String?
    internal let onCancel: () -> Void
    internal let onSave: () -> Void

    private var categoryGrouping: CategoryHierarchyGrouping {
        CategoryHierarchyGrouping(categories: categories)
    }

    private var majorSelectionBinding: Binding<UUID?> {
        Binding(
            get: { formState.selectedMajorCategoryId },
            set: { newValue in
                formState.updateMajorSelection(to: newValue)
            }
        )
    }

    internal var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                LabeledField(title: "金額（例: 50000）") {
                    TextField("", text: $formState.amountText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                }

                LabeledField(title: "対象カテゴリ") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("大項目", selection: majorSelectionBinding) {
                            Text("全体予算").tag(UUID?.none)
                            ForEach(categoryGrouping.majorCategories, id: \.id) { category in
                                Text(category.name).tag(Optional(category.id))
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if let selectedMajorId = formState.selectedMajorCategoryId {
                            let minors = categoryGrouping.minorCategories(forMajorId: selectedMajorId)
                            if minors.isEmpty {
                                Text("この大項目に中項目はありません")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Picker("中項目", selection: $formState.selectedMinorCategoryId) {
                                    Text("中項目を選択").tag(UUID?.none)
                                    ForEach(minors, id: \.id) { category in
                                        Text(category.name).tag(Optional(category.id))
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .navigationTitle(mode.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: onSave)
                        .disabled(!formState.isValid)
                }
            }
        }
    }
}

// MARK: - Annual Budget Editor Sheet

private struct AnnualBudgetEditorSheet: View {
    @Binding var formState: AnnualBudgetFormState
    internal let categories: [Category]
    internal let errorMessage: String?
    internal let onCancel: () -> Void
    internal let onSave: () -> Void

    internal var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                LabeledField(title: "総額（例: 200000）") {
                    TextField("", text: $formState.totalAmountText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                }

                LabeledField(title: "充当ポリシー") {
                    Picker("充当ポリシー", selection: $formState.policy) {
                        ForEach(AnnualBudgetPolicy.allCases, id: \.self) { policy in
                            Text(policy.displayName).tag(policy)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }

                Divider()

                allocationSection

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .navigationTitle("年次特別枠を編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: onSave)
                        .disabled(!formState.isValid)
                }
            }
        }
    }

    private var allocationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("カテゴリ配分")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    formState.addAllocationRow()
                } label: {
                    Label("カテゴリを追加", systemImage: "plus")
                }
            }

            if categories.isEmpty {
                Text("カテゴリがまだ登録されていません。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                let disableRemove = formState.allocationRows.count <= 1
                ForEach($formState.allocationRows) { $row in
                    HStack(spacing: 12) {
                        Picker("カテゴリ", selection: $row.selectedCategoryId) {
                            Text("カテゴリを選択").tag(UUID?.none)
                            ForEach(categories, id: \.id) { category in
                                Text(category.fullName).tag(Optional(category.id))
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 180, alignment: .leading)

                        TextField("金額", text: $row.amountText)
                            .textFieldStyle(.roundedBorder)

                        Button {
                            formState.removeAllocationRow(id: row.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .disabled(disableRemove)
                    }
                }
            }
        }
    }
}

// MARK: - Common Field Layout

private struct LabeledField<Content: View>: View {
    internal let title: String
    @ViewBuilder internal let content: () -> Content

    internal var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            content()
        }
    }
}

// MARK: - Form States

private struct BudgetEditorFormState {
    internal var amountText: String = ""
    internal var selectedMajorCategoryId: UUID?
    internal var selectedMinorCategoryId: UUID?

    internal var selectedCategoryId: UUID? {
        selectedMinorCategoryId ?? selectedMajorCategoryId
    }

    internal mutating func load(from budget: Budget) {
        amountText = budget.amount.plainString
        if let category = budget.category {
            if category.isMajor {
                selectedMajorCategoryId = category.id
                selectedMinorCategoryId = nil
            } else {
                selectedMajorCategoryId = category.parent?.id
                selectedMinorCategoryId = category.id
            }
        } else {
            selectedMajorCategoryId = nil
            selectedMinorCategoryId = nil
        }
    }

    internal mutating func reset() {
        amountText = ""
        selectedMajorCategoryId = nil
        selectedMinorCategoryId = nil
    }

    private var normalizedAmountText: String {
        amountText.replacingOccurrences(of: ",", with: "")
    }

    internal var decimalAmount: Decimal? {
        Decimal(string: normalizedAmountText, locale: Locale(identifier: "ja_JP"))
            ?? Decimal(string: normalizedAmountText)
    }

    internal var isValid: Bool {
        guard let amount = decimalAmount else { return false }
        return amount > 0
    }

    internal mutating func updateMajorSelection(to newValue: UUID?) {
        guard selectedMajorCategoryId != newValue else { return }
        selectedMajorCategoryId = newValue
        selectedMinorCategoryId = nil
    }
}

private struct AnnualBudgetFormState {
    internal var totalAmountText: String = ""
    internal var policy: AnnualBudgetPolicy = .automatic
    internal var allocationRows: [AnnualBudgetAllocationRowState] = []

    internal mutating func load(from config: AnnualBudgetConfig) {
        totalAmountText = config.totalAmount.plainString
        policy = config.policy
        allocationRows = config.allocations.map { allocation in
            AnnualBudgetAllocationRowState(
                id: allocation.id,
                selectedCategoryId: allocation.category.id,
                amountText: allocation.amount.plainString,
            )
        }
        ensureInitialRow()
    }

    internal mutating func reset() {
        totalAmountText = ""
        policy = .automatic
        allocationRows = []
    }

    private var normalizedAmountText: String {
        totalAmountText.replacingOccurrences(of: ",", with: "")
    }

    internal var decimalAmount: Decimal? {
        Decimal(string: normalizedAmountText, locale: Locale(identifier: "ja_JP"))
            ?? Decimal(string: normalizedAmountText)
    }

    internal var isValid: Bool {
        guard let amount = decimalAmount else { return false }
        return amount > 0
    }

    internal mutating func ensureInitialRow() {
        if allocationRows.isEmpty {
            allocationRows.append(.init())
        }
    }

    internal mutating func addAllocationRow() {
        allocationRows.append(.init())
    }

    internal mutating func removeAllocationRow(id: UUID) {
        if allocationRows.count <= 1 { return }
        allocationRows.removeAll { $0.id == id }
        ensureInitialRow()
    }

    internal func makeAllocationDrafts() -> [AnnualAllocationDraft]? {
        var drafts: [AnnualAllocationDraft] = []
        for row in allocationRows {
            guard let categoryId = row.selectedCategoryId,
                  let amount = row.decimalAmount,
                  amount > 0 else {
                return nil
            }
            drafts.append(
                AnnualAllocationDraft(
                    categoryId: categoryId,
                    amount: amount,
                ),
            )
        }
        return drafts
    }
}

private struct AnnualBudgetAllocationRowState: Identifiable {
    internal let id: UUID
    internal var selectedCategoryId: UUID?
    internal var amountText: String

    internal init(
        id: UUID = UUID(),
        selectedCategoryId: UUID? = nil,
        amountText: String = "",
    ) {
        self.id = id
        self.selectedCategoryId = selectedCategoryId
        self.amountText = amountText
    }

    private var normalizedAmountText: String {
        amountText.replacingOccurrences(of: ",", with: "")
    }

    internal var decimalAmount: Decimal? {
        Decimal(string: normalizedAmountText, locale: Locale(identifier: "ja_JP"))
            ?? Decimal(string: normalizedAmountText)
    }
}

private enum BudgetEditorMode {
    case create
    case edit(Budget)

    internal var title: String {
        switch self {
        case .create:
            "予算を追加"
        case .edit:
            "予算を編集"
        }
    }
}

// MARK: - Decimal Helper

private extension Decimal {
    var plainString: String {
        NSDecimalNumber(decimal: self).stringValue
    }
}
