import SwiftUI

/// 月次予算エディタシート
///
/// 月次予算の作成・編集を行うためのシートビュー。
internal struct BudgetEditorSheet: View {
    @Binding internal var formState: BudgetEditorFormState
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
            },
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

                LabeledField(title: "期間") {
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            DatePicker(
                                "開始",
                                selection: $formState.startDate,
                                displayedComponents: [.date],
                            )
                            .datePickerStyle(.field)
                            .labelsHidden()

                            Text("〜")

                            DatePicker(
                                "終了",
                                selection: $formState.endDate,
                                displayedComponents: [.date],
                            )
                            .datePickerStyle(.field)
                            .labelsHidden()
                        }
                        Text("月あたりの金額として扱われます。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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
                        .foregroundColor(.error)
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
