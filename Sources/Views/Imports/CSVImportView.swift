import SwiftData
import SwiftUI
import UniformTypeIdentifiers

internal struct CSVImportView: View {
    @Environment(\.appModelContainer) private var modelContainer: ModelContainer?
    @State private var store: ImportStore?

    internal var body: some View {
        Group {
            if let store {
                CSVImportContentView(store: store)
            } else {
                ProgressView("読み込み中…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("CSVインポート")
        .task {
            await prepareStore()
        }
    }
}

private extension CSVImportView {
    @MainActor
    func prepareStore() async {
        guard store == nil else { return }
        guard let modelContainer else {
            assertionFailure("ModelContainer is unavailable")
            return
        }

        store = await SettingsStackBuilder.makeImportStore(modelContainer: modelContainer)
    }
}

// MARK: - Content

private struct CSVImportContentView: View {
    @Bindable internal var store: ImportStore

    internal var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        CSVImportStepIndicator(currentStep: store.step)

                        if let status = store.statusMessage {
                            Label(status, systemImage: "info.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let error = store.errorMessage {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(.callout)
                                .foregroundStyle(.red)
                        }

                        stepContent
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(maxHeight: .infinity)

                Divider()

                footerButtons
                    .padding()
                    .background(Color(nsColor: .windowBackgroundColor))
            }
            .disabled(store.isProcessing)

            if store.isProcessing {
                ProgressView("処理中…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var stepContent: some View {
        switch store.step {
        case .fileSelection:
            CSVFileSelectionStepView(store: store)
        case .columnMapping:
            CSVColumnMappingStepView(store: store)
        case .validation:
            CSVValidationStepView(store: store)
        }
    }

    private var footerButtons: some View {
        HStack {
            Button("戻る") {
                store.goToPreviousStep()
            }
            .disabled(!store.canGoBack)

            Spacer()

            Button(store.nextButtonTitle) {
                Task(priority: .userInitiated) {
                    await store.handleNextAction()
                }
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(store.isNextButtonDisabled)
        }
    }
}

// MARK: - Step indicator

private struct CSVImportStepIndicator: View {
    internal let currentStep: ImportStore.Step

    internal var body: some View {
        HStack(spacing: 24) {
            ForEach(Array(ImportStore.Step.allCases.enumerated()), id: \.offset) { index, step in
                let isCurrent = step == currentStep

                HStack(spacing: 8) {
                    Circle()
                        .fill(isCurrent ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Text("\(index + 1)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(isCurrent ? Color.white : Color.primary),
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title)
                            .font(.headline)
                        Text(step.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }
}

// MARK: - File Selection

private struct CSVFileSelectionStepView: View {
    @Bindable internal var store: ImportStore
    @State private var isImporterPresented: Bool = false

    internal var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CSVファイルを選択してください")
                .font(.title3.weight(.semibold))

            Text("日付・内容・金額の列が含まれたCSVファイルに対応しています。必要に応じて文字コード（UTF-8推奨）をご確認ください。")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack {
                Label(store.selectedFileName ?? "ファイル未選択", systemImage: "doc")
                    .foregroundStyle(store.selectedFileName == nil ? .secondary : .primary)
                Spacer()
                Button {
                    isImporterPresented = true
                } label: {
                    Label("ファイルを選択", systemImage: "folder")
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("取り込み可能な主な列")
                    .font(.headline)
                Text("日付 / 内容 / 金額 / メモ / 金融機関 / 大項目 / 中項目 / 計算対象 / 振替")
                    .font(.callout)
            }
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false,
        ) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else { return }
                Task(priority: .userInitiated) {
                    await store.loadFile(from: url)
                }
            case let .failure(error):
                store.presentError(error.localizedDescription)
            }
        }
    }
}

// MARK: - Column Mapping

private struct CSVColumnMappingStepView: View {
    @Bindable internal var store: ImportStore

    internal var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CSV列とアプリの項目を対応付けます。")
                .font(.headline)

            Toggle(
                "1行目をヘッダーとして扱う",
                isOn: Binding(
                    get: { store.configuration.hasHeaderRow },
                    set: { store.updateHasHeaderRow($0) },
                ),
            )

            if store.columnOptions.isEmpty {
                ContentUnavailableView {
                    Label("列情報がありません", systemImage: "exclamationmark.triangle")
                        .font(.title2)
                } description: {
                    Text("CSVファイルを読み込んでから列マッピングを行ってください。")
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(CSVColumn.allCases) { column in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(column.displayName)
                                    .font(.subheadline.weight(.semibold))
                                if column.isRequired {
                                    Text("必須")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.red.opacity(0.1), in: Capsule())
                                }
                            }

                            Picker("列", selection: binding(for: column)) {
                                Text("未割り当て").tag(-1)
                                ForEach(store.columnOptions) { option in
                                    Text(option.title).tag(option.id)
                                }
                            }
                            .pickerStyle(.menu)

                            Text(column.helpText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(8)
                        .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            if !store.sampleRows.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("サンプル行（先頭5件）")
                        .font(.subheadline.weight(.semibold))
                    ScrollView(.horizontal) {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(store.sampleRows) { row in
                                Text(row.values.joined(separator: ", "))
                                    .font(.caption)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 2)
                                    .padding(.horizontal, 4)
                                    .background(Color.gray.opacity(0.05), in: RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }
                }
            }
        }
    }

    private func binding(for column: CSVColumn) -> Binding<Int> {
        Binding(
            get: {
                store.mapping.index(for: column) ?? -1
            },
            set: { newValue in
                store.updateMapping(
                    column: column,
                    to: newValue >= 0 ? newValue : nil,
                )
            },
        )
    }
}

// MARK: - Validation & Import

private struct CSVValidationStepView: View {
    @Bindable internal var store: ImportStore

    internal var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let preview = store.preview {
                CSVPreviewSummaryView(preview: preview, summary: store.summary)
                if let progress = store.importProgress {
                    CSVImportProgressView(progress: progress)
                }

                Divider()

                if preview.records.isEmpty {
                    ContentUnavailableView(
                        "取り込めるデータがありません",
                        image: "tray.and.arrow.down",
                        description: Text("列マッピングやCSVの内容をご確認ください。"),
                    )
                } else {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(preview.records) { record in
                            CSVImportRecordRow(record: record)
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "プレビューを生成してください",
                    image: "doc.text.magnifyingglass",
                    description: Text("列マッピングを設定し、「検証を開始」を押してプレビューを作成します。"),
                )
            }
        }
    }
}

private struct CSVPreviewSummaryView: View {
    internal let preview: CSVImportPreview
    internal let summary: CSVImportSummary?

    internal var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                summaryStat(title: "総行数", value: "\(preview.totalCount)")
                summaryStat(title: "取り込み予定", value: "\(preview.validRecords.count)")
                summaryStat(title: "スキップ", value: "\(preview.skippedCount)")
                summaryStat(title: "検出した指摘", value: "\(preview.issueCount)")
            }

            if let summary {
                VStack(alignment: .leading, spacing: 4) {
                    Text("取り込み結果")
                        .font(.headline)

                    Text(
                        "新規 \(summary.importedCount) 件 / 更新 \(summary.updatedCount) 件 / スキップ \(summary.skippedCount) 件",
                    )
                    .font(.callout)

                    if summary.createdFinancialInstitutions > 0 || summary.createdCategories > 0 {
                        let message = "新規作成: 金融機関 \(summary.createdFinancialInstitutions) 件"
                            + " / カテゴリ \(summary.createdCategories) 件"
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func summaryStat(title: String, value: String) -> some View {
        VStack {
            Text(value)
                .font(.title2.weight(.semibold))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct CSVImportProgressView: View {
    internal let progress: (current: Int, total: Int)

    internal var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("取り込み中... (\(progress.current)/\(progress.total))")
                .font(.subheadline.weight(.semibold))
            ProgressView(
                value: Double(progress.current),
                total: Double(max(progress.total, 1))
            )
            .progressViewStyle(.linear)
        }
        .padding()
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct CSVImportRecordRow: View {
    internal let record: CSVImportRecord

    internal var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("行 \(record.rowNumber)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                statusLabel
            }

            if let draft = record.draft {
                Text("\(draft.title) ・ \(draft.date.shortDateFormatted)")
                    .font(.callout)
            }

            if record.issues.isEmpty {
                Text("問題は検出されませんでした")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(record.issues) { issue in
                    Label(
                        issue.message,
                        systemImage: issue.severity == .error ? "exclamationmark.triangle.fill" : "info.circle",
                    )
                    .font(.caption)
                    .foregroundStyle(issue.severity == .error ? Color.red : Color.orange)
                }
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }

    private var statusLabel: some View {
        Group {
            if record.isValid {
                Label("有効", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Label("要確認", systemImage: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
        .font(.caption)
    }
}
