import Foundation
import Observation

/// CSVインポート画面の状態を管理するストア
@Observable
internal final class ImportStore: @unchecked Sendable {
    // MARK: - Dependencies

    private let transactionRepository: TransactionRepository
    private let budgetRepository: BudgetRepository
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
    internal private(set) var importProgress: (current: Int, total: Int)?

    private var didManuallyEditMapping: Bool = false

    // MARK: - Initialization

    internal init(
        transactionRepository: TransactionRepository,
        budgetRepository: BudgetRepository,
        parser: CSVParser = CSVParser(),
        importer: CSVImporter? = nil
    ) {
        self.transactionRepository = transactionRepository
        self.budgetRepository = budgetRepository
        self.parser = parser
        self.importer = importer ?? CSVImporter(
            transactionRepository: transactionRepository,
            budgetRepository: budgetRepository
        )
    }

    // MARK: - Actions

    internal func loadFile(from url: URL) async {
        guard await beginProcessing(status: "CSVを読み込み中...") else {
            return
        }

        let configuration = await MainActor.run { self.configuration }

        do {
            let document = try await SecurityScopedResourceAccess.performAsync(with: url) {
                let data = try Data(contentsOf: url)
                return try parser.parse(
                    data: data,
                    configuration: configuration,
                )
            }
            await MainActor.run {
                self.applyDocument(document, fileName: url.lastPathComponent)
                self.statusMessage = "\(url.lastPathComponent) を読み込みました"
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }

        await endProcessing()
    }

    @MainActor
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
        let isProcessing = await MainActor.run { self.isProcessing }
        guard !isProcessing else { return }

        await MainActor.run {
            self.errorMessage = nil
        }

        let currentStep = await MainActor.run { self.step }

        switch currentStep {
        case .fileSelection:
            let hasDocument = await MainActor.run { self.document != nil }
            if !hasDocument {
                await MainActor.run {
                    self.errorMessage = "CSVファイルを選択してください"
                }
                return
            }
            await MainActor.run {
                self.step = .columnMapping
            }
        case .columnMapping:
            await generatePreview()
        case .validation:
            let summary = await MainActor.run { self.summary }
            if summary == nil {
                await performImport()
            } else {
                await MainActor.run {
                    self.reset()
                }
            }
        }
    }

    @MainActor
    internal func updateHasHeaderRow(_ flag: Bool) {
        configuration.hasHeaderRow = flag
        preview = nil

        // 列名が変わるため自動マッピングを再計算
        didManuallyEditMapping = false
        mapping = CSVColumnMapping.automatic(for: columnOptions)
    }

    @MainActor
    internal func updateMapping(column: CSVColumn, to columnIndex: Int?) {
        didManuallyEditMapping = true
        mapping.assign(column, to: columnIndex)
    }

    @MainActor
    internal func reset() {
        document = nil
        preview = nil
        summary = nil
        selectedFileName = nil
        statusMessage = nil
        errorMessage = nil
        importProgress = nil
        step = .fileSelection
        configuration = .init()
        mapping = .init()
        didManuallyEditMapping = false
        lastUpdatedAt = Date()
    }

    @MainActor
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
    @MainActor
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
        let payload = await MainActor.run(resultType: (CSVDocument, CSVColumnMapping, CSVImportConfiguration)?.self) {
            guard let document = self.document else {
                self.errorMessage = "CSVファイルが読み込まれていません"
                return nil
            }
            guard self.mapping.hasRequiredAssignments else {
                self.errorMessage = "必須カラム（日付・内容・金額）を割り当ててください"
                return nil
            }
            return (document, self.mapping, self.configuration)
        }
        guard let payload else { return }

        guard await beginProcessing(status: "プレビューを生成中...") else {
            return
        }

        do {
            let preview = try await importer.makePreview(
                document: payload.0,
                mapping: payload.1,
                configuration: payload.2
            )
            await MainActor.run {
                self.preview = preview
                self.summary = nil
                self.step = .validation
                self.lastUpdatedAt = Date()
                self.statusMessage = "検証結果を更新しました"
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }

        await endProcessing()
    }

    func performImport() async {
        let preview = await MainActor.run(resultType: CSVImportPreview?.self) {
            guard let preview = self.preview else {
                self.errorMessage = "プレビューが生成されていません"
                return nil
            }
            guard !preview.validRecords.isEmpty else {
                self.errorMessage = "取り込める行がありません"
                return nil
            }
            return preview
        }
        guard let preview else { return }

        guard await beginProcessing(status: "取り込み中...") else {
            return
        }

        let totalCount = preview.validRecords.count
        await MainActor.run {
            self.importProgress = (0, totalCount)
        }

        do {
            let summary = try await importer.performImport(
                preview: preview
            ) { [weak self] current, total in
                guard let self else { return }
                self.updateImportProgress(current: current, total: total)
            }
            await MainActor.run {
                self.summary = summary
                self.statusMessage = "取り込みが完了しました"
                self.lastUpdatedAt = Date()
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }

        await MainActor.run {
            self.importProgress = nil
        }
        await endProcessing()
    }

    private func beginProcessing(status: String) async -> Bool {
        await MainActor.run {
            guard !isProcessing else { return false }
            isProcessing = true
            errorMessage = nil
            statusMessage = status
            return true
        }
    }

    private func endProcessing(status: String? = nil) async {
        await MainActor.run {
            isProcessing = false
            if let status {
                statusMessage = status
            }
        }
    }

    @MainActor
    private func updateImportProgress(current: Int, total: Int) {
        importProgress = (current, total)
        statusMessage = "取り込み中... (\(current)/\(total))"
    }
}
