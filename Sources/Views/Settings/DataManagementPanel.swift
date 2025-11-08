import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// データ管理パネル（バックアップ・リストア・CSVエクスポート）
internal struct DataManagementPanel: View {
    @Bindable private var store: SettingsStore

    @State private var backupDocument: DataFileDocument = DataFileDocument()
    @State private var csvDocument: DataFileDocument = DataFileDocument()
    @State private var showBackupExporter: Bool = false
    @State private var showCSVExporter: Bool = false
    @State private var showBackupImporter: Bool = false
    @State private var backupFileName: String = ""
    @State private var csvFileName: String = ""
    @State private var showDeleteConfirmationDialog: Bool = false
    @State private var showDeleteVerificationSheet: Bool = false
    @State private var deleteVerificationText: String = ""

    internal init(store: SettingsStore) {
        self.store = store
    }

    internal var body: some View {
        SettingsSectionCard(
            title: "データ管理",
            iconName: "externaldrive",
            description: "バックアップやリストア、CSVエクスポートを実行します。",
            content: {
                VStack(alignment: .leading, spacing: 16) {
                    statisticsSection
                    backupInfoSection
                    if store.isProcessingBackup {
                        ProgressView("処理中…")
                    }
                    if store.isProcessingDeletion {
                        ProgressView("データを削除しています…")
                    }
                    actionButtons
                    deletionSection
                    if let status = store.statusMessage {
                        StatusMessageView(message: status)
                    }
                }
            }
        )
        .fileExporter(
            isPresented: $showBackupExporter,
            document: backupDocument,
            contentType: .json,
            defaultFilename: backupFileName,
            onCompletion: handleExportCompletion
        )
        .fileExporter(
            isPresented: $showCSVExporter,
            document: csvDocument,
            contentType: .commaSeparatedText,
            defaultFilename: csvFileName,
            onCompletion: handleExportCompletion
        )
        .fileImporter(
            isPresented: $showBackupImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false,
            onCompletion: handleImportResult
        )
        .confirmationDialog(
            "バックアップは取得済みですか？",
            isPresented: $showDeleteConfirmationDialog,
            titleVisibility: .visible
        ) {
            Button("削除する", role: .destructive) {
                deleteVerificationText = ""
                showDeleteVerificationSheet = true
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("すべてのデータを削除すると元に戻せません。")
        }
        .sheet(isPresented: $showDeleteVerificationSheet) {
            DeleteVerificationSheet(
                input: $deleteVerificationText,
                onConfirm: {
                    performDeletion()
                },
                onCancel: {
                    showDeleteVerificationSheet = false
                }
            )
        }
    }

    // MARK: - Sections

    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("データ件数")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    store.refreshStatistics()
                } label: {
                    Label("更新", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
            VStack(alignment: .leading, spacing: 4) {
                statRow(label: "取引", value: store.statistics.transactions)
                statRow(label: "カテゴリ", value: store.statistics.categories)
                statRow(label: "予算", value: store.statistics.budgets)
                statRow(label: "年次特別枠", value: store.statistics.annualBudgetConfigs)
                statRow(label: "金融機関", value: store.statistics.financialInstitutions)
                Divider()
                statRow(label: "合計", value: store.statistics.totalRecords, emphasize: true)
            }
        }
    }

    private func statRow(label: String, value: Int, emphasize: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(emphasize ? .headline : .body)
            Spacer()
            Text("\(value)")
                .font(emphasize ? .headline : .body)
        }
    }

    private var backupInfoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("バックアップ情報")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let metadata = store.lastBackupMetadata {
                let counts = metadata.recordCounts
                let total = counts.transactions + counts.categories + counts.budgets + counts.annualBudgetConfigs + counts.financialInstitutions
                VStack(alignment: .leading, spacing: 2) {
                    Text("最終生成: \(metadata.generatedAt.longDateFormatted)")
                    Text("対象件数: 取引\(counts.transactions)件 / 合計\(total)件")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("まだバックアップは作成されていません。")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var actionButtons: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    createBackup()
                } label: {
                    Label("バックアップを作成", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isProcessingBackup)

                Button {
                    showBackupImporter = true
                } label: {
                    Label("バックアップから復元", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(store.isProcessingBackup)
            }

            Button {
                exportCSV()
            } label: {
                Label("取引CSVをエクスポート", systemImage: "doc.text")
            }
        }
    }

    private var deletionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            Label {
                Text("データ初期化")
                    .font(.subheadline)
            } icon: {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
            Text("アプリケーション内のすべてのデータを削除します。実行前にバックアップを取得してください。")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button(role: .destructive) {
                showDeleteConfirmationDialog = true
            } label: {
                Label("全データを削除", systemImage: "trash")
            }
            .disabled(store.isProcessingDeletion || store.statistics.totalRecords == 0)
        }
    }

    // MARK: - Actions

    private func createBackup() {
        Task {
            do {
                let archive = try await store.createBackupArchive()
                backupDocument = DataFileDocument(data: archive.data)
                backupFileName = archive.suggestedFileName
                showBackupExporter = true
            } catch {
                store.statusMessage = "バックアップに失敗しました: \(error.localizedDescription)"
            }
        }
    }

    private func exportCSV() {
        do {
            let result = try store.exportTransactionsCSV()
            csvDocument = DataFileDocument(data: result.data)
            csvFileName = makeCSVFileName()
            showCSVExporter = true
            store.statusMessage = "取引\(result.rowCount)件をエクスポートしました"
        } catch {
            store.statusMessage = "CSVエクスポートに失敗しました: \(error.localizedDescription)"
        }
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else {
                store.statusMessage = "ファイルが選択されませんでした"
                return
            }
            restoreBackup(from: url)
        case let .failure(error):
            store.statusMessage = "ファイルを開けませんでした: \(error.localizedDescription)"
        }
    }

    private func restoreBackup(from url: URL) {
        Task {
            do {
                let data = try Data(contentsOf: url)
                _ = try await store.restoreBackup(from: data)
            } catch {
                store.statusMessage = "復元に失敗しました: \(error.localizedDescription)"
            }
        }
    }

    private func handleExportCompletion(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            store.statusMessage = "ファイルを保存しました"
        case let .failure(error):
            store.statusMessage = "保存に失敗しました: \(error.localizedDescription)"
        }
    }

    private func makeCSVFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmm"
        formatter.locale = Foundation.Locale(identifier: "en_US_POSIX")
        return "transactions_\(formatter.string(from: Date())).csv"
    }

    private func performDeletion() {
        do {
            try store.deleteAllData()
        } catch {
            store.statusMessage = "データ削除に失敗しました: \(error.localizedDescription)"
        }
        showDeleteVerificationSheet = false
        deleteVerificationText = ""
    }
}

// MARK: - Status Message View

private struct StatusMessageView: View {
    internal let message: String

    internal var body: some View {
        HStack {
            Image(systemName: "info.circle")
            Text(message)
            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: AppConstants.UserInterface.smallCornerRadius)
                .fill(Color.blue.opacity(0.1))
        )
    }
}

// MARK: - Delete Verification Sheet

private struct DeleteVerificationSheet: View {
    @Binding internal var input: String
    internal var onConfirm: () -> Void
    internal var onCancel: () -> Void

    private var isInputValid: Bool {
        input == "DELETE"
    }

    internal var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("データ削除の確認")
                .font(.title2)
                .bold()
            Text("確認のため「DELETE」と入力してください。すべての取引・カテゴリ・予算などが削除されます。")
                .foregroundStyle(.secondary)
            TextField("DELETE", text: $input)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    if isInputValid {
                        onConfirm()
                    }
                }
            HStack {
                Button("キャンセル") {
                    onCancel()
                }
                Spacer()
                Button("削除", role: .destructive) {
                    onConfirm()
                }
                .disabled(!isInputValid)
            }
        }
        .padding(24)
        .frame(minWidth: 360)
    }
}
