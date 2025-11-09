import SwiftUI

/// 特別支払いエディタシート
///
/// 特別支払い定義の作成・編集を行うためのシートビュー。
internal struct SpecialPaymentEditorSheet: View {
    @Binding internal var formState: SpecialPaymentFormState
    internal let categories: [Category]
    internal let mode: SpecialPaymentEditorMode
    internal let errorMessage: String?
    internal let onCancel: () -> Void
    internal let onSave: () -> Void

    internal var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    LabeledField(title: "名称") {
                        TextField("例: 自動車税", text: $formState.nameText)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: .infinity)
                    }

                    LabeledField(title: "カテゴリ") {
                        CategoryHierarchyPicker(
                            categories: categories,
                            selectedMajorCategoryId: $formState.selectedMajorCategoryId,
                            selectedMinorCategoryId: $formState.selectedMinorCategoryId,
                            majorPlaceholder: "大項目を選択",
                            minorPlaceholder: "中項目を選択",
                            inactiveMinorMessage: "大項目を選択すると中項目を指定できます",
                            noMinorMessage: "この大項目に中項目はありません",
                        )
                    }

                    LabeledField(title: "金額（例: 50000）") {
                        TextField("", text: $formState.amountText)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: .infinity)
                    }

                    LabeledField(title: "周期") {
                        HStack(spacing: 12) {
                            Stepper(value: $formState.recurrenceYears, in: 0 ... 10) {
                                HStack {
                                    Text("\(formState.recurrenceYears)")
                                        .frame(minWidth: 30, alignment: .trailing)
                                    Text("年")
                                }
                            }
                            .frame(width: 140)

                            Stepper(value: $formState.recurrenceMonths, in: 0 ... 11) {
                                HStack {
                                    Text("\(formState.recurrenceMonths)")
                                        .frame(minWidth: 30, alignment: .trailing)
                                    Text("か月")
                                }
                            }
                            .frame(width: 160)
                        }
                    }

                    LabeledField(title: "開始日（初回発生予定日）") {
                        DatePicker(
                            "",
                            selection: $formState.firstOccurrenceDate,
                            displayedComponents: [.date],
                        )
                        .datePickerStyle(.field)
                        .labelsHidden()
                    }

                    LabeledField(title: "リードタイム（月数）") {
                        Stepper(value: $formState.leadTimeMonths, in: 0 ... 24) {
                            HStack {
                                Text("\(formState.leadTimeMonths)")
                                    .frame(minWidth: 30, alignment: .trailing)
                                Text("か月前から積立開始")
                            }
                        }
                    }

                    LabeledField(title: "積立戦略") {
                        Picker("積立戦略", selection: $formState.savingStrategy) {
                            Text("積立なし").tag(SpecialPaymentSavingStrategy.disabled)
                            Text("周期で均等積立").tag(SpecialPaymentSavingStrategy.evenlyDistributed)
                            Text("カスタム月次金額").tag(SpecialPaymentSavingStrategy.customMonthly)
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }

                    if formState.savingStrategy == .customMonthly {
                        LabeledField(title: "カスタム積立金額（月次）") {
                            TextField("例: 4000", text: $formState.customMonthlySavingAmountText)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    LabeledField(title: "メモ") {
                        TextEditor(text: $formState.notesText)
                            .font(.body)
                            .frame(height: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.neutral.opacity(0.3), lineWidth: 1),
                            )
                    }

                    LabeledField(title: "休日の日付調整") {
                        Picker("休日の日付調整", selection: $formState.dateAdjustmentPolicy) {
                            Text("調整なし").tag(DateAdjustmentPolicy.none)
                            Text("前営業日に移動").tag(DateAdjustmentPolicy.moveToPreviousBusinessDay)
                            Text("次営業日に移動").tag(DateAdjustmentPolicy.moveToNextBusinessDay)
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    LabeledField(title: "繰り返しパターン") {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("パターン", selection: $formState.recurrenceDayPattern) {
                                Text("なし（日付固定）").tag(DayOfMonthPattern?.none)
                                Text("月末").tag(DayOfMonthPattern?.some(.endOfMonth))
                                Text("月末3日前").tag(DayOfMonthPattern?.some(.endOfMonthMinus(days: 3)))
                                Text("月末5日前").tag(DayOfMonthPattern?.some(.endOfMonthMinus(days: 5)))
                                Text("最初の営業日").tag(DayOfMonthPattern?.some(.firstBusinessDay))
                                Text("最終営業日").tag(DayOfMonthPattern?.some(.lastBusinessDay))
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Text("パターンを使用すると、月ごとに異なる日付に調整されます（例：月末は28〜31日）")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider()

                    previewSection

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.error)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
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

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("プレビュー")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                GridRow {
                    Text("周期")
                        .foregroundStyle(.secondary)
                    Text(recurrenceDescription)
                }
                GridRow {
                    Text("月次積立額")
                        .foregroundStyle(.secondary)
                    Text(formState.monthlySavingAmountPreview.currencyFormatted)
                }
                GridRow {
                    Text("次回発生予定日")
                        .foregroundStyle(.secondary)
                    Text(formState.firstOccurrenceDate.longDateFormatted)
                }
            }
            .font(.subheadline)
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(8)
    }

    private var recurrenceDescription: String {
        let months = formState.recurrenceIntervalMonths
        guard months > 0 else { return "未設定" }
        let years = months / 12
        let remainingMonths = months % 12

        switch (years, remainingMonths) {
        case let (0, monthsOnly):
            return "\(monthsOnly)か月"
        case let (yearsOnly, 0):
            return "\(yearsOnly)年"
        default:
            return "\(years)年\(remainingMonths)か月"
        }
    }
}
