import SwiftUI

/// 年次予算エディタシート
///
/// 年次特別枠の設定を行うためのシートビュー。
internal struct AnnualBudgetEditorSheet: View {
    @Binding internal var formState: AnnualBudgetFormState
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
                let disableRemove: Bool = formState.allocationRows.count <= 1
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
