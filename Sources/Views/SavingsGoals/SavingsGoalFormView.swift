import SwiftUI

/// 貯蓄目標作成・編集フォーム
internal struct SavingsGoalFormView: View {
    @Bindable internal var store: SavingsGoalStore
    @Environment(\.dismiss) private var dismiss: DismissAction
    @State private var hasTargetAmount: Bool = false
    @State private var hasTargetDate: Bool = false
    @State private var errorMessage: String?

    internal var body: some View {
        NavigationStack {
            Form {
                Section("基本情報") {
                    TextField("名称", text: $store.formInput.name)

                    TextField(
                        "月次積立額",
                        value: $store.formInput.monthlySavingAmount,
                        format: .number,
                    )
                }

                Section("目標設定") {
                    Toggle("目標金額を設定", isOn: $hasTargetAmount)
                        .onChange(of: hasTargetAmount) { _, newValue in
                            if !newValue {
                                store.formInput.targetAmount = nil
                            } else if store.formInput.targetAmount == nil {
                                store.formInput.targetAmount = 0
                            }
                        }

                    if hasTargetAmount {
                        TextField(
                            "目標金額",
                            value: Binding(
                                get: { store.formInput.targetAmount ?? 0 },
                                set: { store.formInput.targetAmount = $0 },
                            ),
                            format: .number,
                        )
                    }

                    Toggle("目標達成日を設定", isOn: $hasTargetDate)
                        .onChange(of: hasTargetDate) { _, newValue in
                            if !newValue {
                                store.formInput.targetDate = nil
                            } else if store.formInput.targetDate == nil {
                                store.formInput.targetDate = Date()
                            }
                        }

                    if hasTargetDate {
                        DatePicker(
                            "目標達成日",
                            selection: Binding(
                                get: { store.formInput.targetDate ?? Date() },
                                set: { store.formInput.targetDate = $0 },
                            ),
                            displayedComponents: .date,
                        )
                    }
                }

                Section("詳細") {
                    DatePicker("開始日", selection: $store.formInput.startDate, displayedComponents: .date)

                    TextField(
                        "メモ（オプション）",
                        text: Binding(
                            get: { store.formInput.notes ?? "" },
                            set: { store.formInput.notes = $0.isEmpty ? nil : $0 },
                        ),
                        axis: .vertical,
                    )
                    .lineLimit(3 ... 6)
                }
            }
            .navigationTitle(store.selectedGoal == nil ? "新規貯蓄目標" : "貯蓄目標編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveGoal()
                    }
                }
            }
            .alert(
                "エラー",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } },
                ),
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear {
                initializeFormState()
            }
        }
    }

    private func initializeFormState() {
        hasTargetAmount = store.formInput.targetAmount != nil
        hasTargetDate = store.formInput.targetDate != nil
    }

    private func saveGoal() {
        do {
            if let selectedGoal = store.selectedGoal {
                try store.updateGoal(selectedGoal.id)
            } else {
                try store.createGoal()
            }
            dismiss()
        } catch let error as SavingsGoalStoreError {
            switch error {
            case .goalNotFound:
                errorMessage = "貯蓄目標が見つかりません"
            case let .validationFailed(errors):
                errorMessage = errors.joined(separator: "\n")
            }
        } catch {
            errorMessage = "予期しないエラーが発生しました: \(error.localizedDescription)"
        }
    }
}
