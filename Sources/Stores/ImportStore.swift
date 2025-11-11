import Foundation
import Observation
import SwiftData

/// CSVインポート画面の状態を管理するストア
@Observable
@MainActor
internal final class ImportStore {
    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let parser: CSVParser
    private let importer: CSVImporter

    // MARK: - State

    internal private(set) var step: Step = .fileSelection
    internal private(set) var configuration: CSVImportConfiguration = .init()
    internal private(set) var mapping: CSVColumnMapping = .init()
    internal private(set) var document: CSVDocument?
    internal private(set) var preview: CSVImportPreview?
    internal private(set) var summary: CSVImportSummary?
    internal private(set) var selectedFileName: String?
    internal private(set) var errorMessage: String?
    internal private(set) var statusMessage: String?
    internal private(set) var isProcessing: Bool = false
    internal private(set) var lastUpdatedAt: Date?

    private var didManuallyEditMapping: Bool = false

    // MARK: - Initialization

    internal init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.parser = CSVParser()
        self.importer = CSVImporter()
    }

    // MARK: - Actions

    internal func loadFile(from url: URL) async {
        guard !isProcessing else { return }
        isProcessing = true
        errorMessage = nil
        statusMessage = "CSVを読み込み中..."

        defer { isProcessing = false }

        do {
            let document = try await SecurityScopedResourceAccess.performAsync(with: url) {
                let data = try Data(contentsOf: url)
                return try parser.parse(
                    data: data,
                    configuration: configuration,
                )
            }
            applyDocument(document, fileName: url.lastPathComponent)
            statusMessage = "\(url.lastPathComponent) を読み込みました"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    internal func goToPreviousStep() {
        guard canGoBack else { return }
        errorMessage = nil
        summary = nil

        switch step {
        case .fileSelection:
            break
        case .columnMapping:
            step = .fileSelection
        case .validation:
            step = .columnMapping
        }
    }

    internal func handleNextAction() async {
        guard !isProcessing else { return }
        errorMessage = nil

        switch step {
        case .fileSelection:
            guard document != nil else {
                errorMessage = "CSVファイルを選択してください"
                return
            }
            step = .columnMapping
        case .columnMapping:
            await generatePreview()
        case .validation:
            if summary == nil {
                await performImport()
            } else {
                reset()
            }
        }
    }

    internal func updateHasHeaderRow(_ flag: Bool) {
        configuration.hasHeaderRow = flag
        preview = nil

        // 列名が変わるため自動マッピングを再計算
        didManuallyEditMapping = false
        mapping = CSVColumnMapping.automatic(for: columnOptions)
    }

    internal func updateMapping(column: CSVColumn, to columnIndex: Int?) {
        didManuallyEditMapping = true
        mapping.assign(column, to: columnIndex)
    }

    internal func reset() {
        document = nil
        preview = nil
        summary = nil
        selectedFileName = nil
        statusMessage = nil
        errorMessage = nil
        step = .fileSelection
        configuration = .init()
        mapping = .init()
        didManuallyEditMapping = false
        lastUpdatedAt = Date()
    }

    internal func presentError(_ message: String) {
        errorMessage = message
    }
}

// MARK: - Nested Types

internal extension ImportStore {
    enum Step: Int, CaseIterable, Identifiable {
        case fileSelection
        case columnMapping
        case validation

        internal var id: Self { self }

        internal var title: String {
            switch self {
            case .fileSelection:
                "ファイル選択"
            case .columnMapping:
                "列マッピング"
            case .validation:
                "検証と取り込み"
            }
        }

        internal var description: String {
            switch self {
            case .fileSelection:
                "取り込み対象のCSVファイルを選択します。"
            case .columnMapping:
                "CSV列とアプリ内の項目を対応付けます。"
            case .validation:
                "プレビューで内容を確認し、データを取り込みます。"
            }
        }
    }
}

// MARK: - Computed State

internal extension ImportStore {
    var canGoBack: Bool {
        step != .fileSelection && !isProcessing
    }

    var nextButtonTitle: String {
        switch step {
        case .fileSelection:
            "列マッピングへ"
        case .columnMapping:
            "検証を開始"
        case .validation:
            summary == nil ? "取り込みを実行" : "新しい取り込みを開始"
        }
    }

    var isNextButtonDisabled: Bool {
        if isProcessing {
            return true
        }

        switch step {
        case .fileSelection:
            return document == nil
        case .columnMapping:
            return document == nil || !mapping.hasRequiredAssignments
        case .validation:
            if summary != nil {
                return false
            }
            guard let preview else { return true }
            return preview.validRecords.isEmpty
        }
    }

    var columnOptions: [CSVColumnOption] {
        guard let document else { return [] }

        let columnCount = document.maxColumnCount
        guard columnCount > 0 else { return [] }

        let headers: [String]
        if configuration.hasHeaderRow, let headerRow = document.rows.first {
            var inferred = headerRow.values
            if inferred.count < columnCount {
                inferred.append(
                    contentsOf: Array(repeating: "", count: columnCount - inferred.count),
                )
            }
            headers = inferred.enumerated().map { index, title in
                title.trimmed.isEmpty ? "列\(index + 1)" : title
            }
        } else {
            headers = (0 ..< columnCount).map { "列\($0 + 1)" }
        }

        return headers.enumerated().map { CSVColumnOption(id: $0.offset, title: $0.element) }
    }

    var sampleRows: [CSVRow] {
        Array(dataRows.prefix(5))
    }

    var dataRows: [CSVRow] {
        document?.dataRows(skipHeader: configuration.hasHeaderRow) ?? []
    }

    var hasPreview: Bool {
        preview != nil
    }
}

// MARK: - Internal Helpers (for testing)

internal extension ImportStore {
    func applyDocument(_ document: CSVDocument, fileName: String?) {
        self.document = document
        self.preview = nil
        self.summary = nil
        self.selectedFileName = fileName
        self.step = .fileSelection
        self.lastUpdatedAt = Date()
        self.didManuallyEditMapping = false

        mapping = CSVColumnMapping.automatic(for: columnOptions)
    }
}

// MARK: - Private Helpers

private extension ImportStore {
    func generatePreview() async {
        guard let document else {
            errorMessage = "CSVファイルが読み込まれていません"
            return
        }
        guard mapping.hasRequiredAssignments else {
            errorMessage = "必須カラム（日付・内容・金額）を割り当ててください"
            return
        }

        isProcessing = true
        statusMessage = "プレビューを生成中..."

        defer { isProcessing = false }

        do {
            let preview = try await importer.makePreview(
                document: document,
                mapping: mapping,
                configuration: configuration,
            )
            self.preview = preview
            self.summary = nil
            self.step = .validation
            self.lastUpdatedAt = Date()
            self.statusMessage = "検証結果を更新しました"
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func performImport() async {
        guard let preview else {
            errorMessage = "プレビューが生成されていません"
            return
        }
        guard !preview.validRecords.isEmpty else {
            errorMessage = "取り込める行がありません"
            return
        }

        isProcessing = true
        statusMessage = "取り込み中..."

        defer { isProcessing = false }

        do {
            let summary = try importer.performImport(preview: preview, modelContext: modelContext)
            self.summary = summary
            self.statusMessage = "取り込みが完了しました"
            self.lastUpdatedAt = Date()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}
