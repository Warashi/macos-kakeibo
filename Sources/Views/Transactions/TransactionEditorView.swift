import SwiftUI

internal struct TransactionEditorView: View {
    @Bindable internal var store: TransactionStore

    private var institutions: [FinancialInstitution] {
        store.availableInstitutions.sorted { lhs, rhs in
            if lhs.displayOrder == rhs.displayOrder {
                return lhs.name < rhs.name
            }
            return lhs.displayOrder < rhs.displayOrder
        }
    }

    private var minorCategories: [Category] {
        store.minorCategories(for: store.formState.majorCategoryId)
    }

    internal var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(store.editingTransaction == nil ? "取引を追加" : "取引を編集")
                .font(.title2.bold())

            Form {
                Section("基本情報") {
                    DatePicker("日付", selection: $store.formState.date, displayedComponents: [.date])

                    TextField("内容", text: $store.formState.title)

                    Picker("種別", selection: $store.formState.transactionKind) {
                        ForEach(TransactionStore.TransactionKind.allCases) { kind in
                            Text(kind.label).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextField("金額（絶対値）", text: $store.formState.amountText)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)

                    TextField("メモ", text: $store.formState.memo, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                Section("カテゴリ") {
                    Picker("大項目", selection: $store.formState.majorCategoryId) {
                        Text("未分類").tag(UUID?.none)
                        ForEach(store.majorCategories, id: \.id) { category in
                            Text(category.name).tag(Optional(category.id))
                        }
                    }
                    .onChange(of: store.formState.majorCategoryId) { _, _ in
                        store.ensureMinorCategoryConsistency()
                    }

                    Picker("中項目", selection: $store.formState.minorCategoryId) {
                        Text("未選択").tag(UUID?.none)
                        ForEach(minorCategories, id: \.id) { category in
                            Text(category.name).tag(Optional(category.id))
                        }
                    }
                    .disabled(store.formState.majorCategoryId == nil)
                }

                Section("その他") {
                    Picker("金融機関", selection: $store.formState.financialInstitutionId) {
                        Text("未設定").tag(UUID?.none)
                        ForEach(institutions, id: \.id) { institution in
                            Text(institution.name).tag(Optional(institution.id))
                        }
                    }

                    Toggle("計算対象に含める", isOn: $store.formState.isIncludedInCalculation)
                    Toggle("振替", isOn: $store.formState.isTransfer)
                }
            }

            if !store.formErrors.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(store.formErrors, id: \.self) { error in
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }

            HStack {
                Button("キャンセル", role: .cancel) {
                    store.cancelEditing()
                }

                Spacer()

                Button("保存") {
                    _ = store.saveCurrentForm()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(minWidth: 520, minHeight: 520)
    }
}
