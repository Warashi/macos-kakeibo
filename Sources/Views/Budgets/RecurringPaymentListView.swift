import SwiftData
import SwiftUI

/// 定期支払い一覧ビュー
internal struct RecurringPaymentListView: View {
    @Environment(\.appModelContainer) private var modelContainer: ModelContainer?
    @State private var store: RecurringPaymentListStore?

    internal var body: some View {
        Group {
            if let store {
                RecurringPaymentListContentView(store: store)
            } else {
                ProgressView("データを読み込み中…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear(perform: prepareStore)
    }

    private func prepareStore() {
        guard store == nil else { return }
        guard let container = modelContainer else {
            assertionFailure("ModelContainer is unavailable")
            return
        }
        Task {
            let listStore = await RecurringPaymentStackBuilder.makeListStore(modelContainer: container)
            await listStore.refreshEntries()
            await MainActor.run {
                store = listStore
            }
        }
    }
}

/// 定期支払い一覧コンテンツビュー
internal struct RecurringPaymentListContentView: View {
    @Bindable internal var store: RecurringPaymentListStore
    @Query private var allCategoryEntities: [SwiftDataCategory]
    @State private var csvDocument: DataFileDocument?
    @State private var isExportingCSV: Bool = false
    @State private var exportError: String?

    internal var body: some View {
        VStack(spacing: 16) {
            RecurringPaymentFilterToolbarView(store: store)
            RecurringPaymentEntriesTableView(store: store)
        }
        .padding()
        .navigationTitle("定期支払い一覧")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    store.resetFilters()
                } label: {
                    Label("フィルタをリセット", systemImage: "arrow.counterclockwise")
                }

                Button {
                    exportToCSV()
                } label: {
                    Label("CSVエクスポート", systemImage: "square.and.arrow.up")
                }
                .disabled(store.cachedEntries.isEmpty)
            }
        }
        .fileExporter(
            isPresented: $isExportingCSV,
            document: csvDocument,
            contentType: .commaSeparatedText,
            defaultFilename: defaultCSVFilename(),
            onCompletion: handleExportCompletion,
        )
        .alert(
            "エクスポートエラー",
            isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } },
            ),
            actions: {
                Button("OK", role: .cancel) {}
            },
            message: {
                Text(exportError ?? "")
            },
        )
        .onAppear {
            store.categoryFilter.updateCategories(domainCategories)
        }
        .onChange(of: allCategoryEntities) { _, _ in
            store.categoryFilter.updateCategories(domainCategories)
        }
        .onChange(of: store.dateRange) { [store] _, _ in
            Task { await store.refreshEntries() }
        }
        .onChange(of: store.searchText) { [store] _, _ in
            Task { await store.refreshEntries() }
        }
        .onChange(of: store.categoryFilter.selectedMajorCategoryId) { [store] _, _ in
            Task { await store.refreshEntries() }
        }
        .onChange(of: store.categoryFilter.selectedMinorCategoryId) { [store] _, _ in
            Task { await store.refreshEntries() }
        }
        .onChange(of: store.selectedStatus) { [store] _, _ in
            Task { await store.refreshEntries() }
        }
        .onChange(of: store.sortOrder) { [store] _, _ in
            Task { await store.refreshEntries() }
        }
    }

    // MARK: - Export Helpers

    private func exportToCSV() {
        let exporter: CSVExporter = CSVExporter()

        do {
            let result = try exporter.exportRecurringPaymentListEntries(store.cachedEntries)
            csvDocument = DataFileDocument(data: result.data)
            isExportingCSV = true
        } catch {
            exportError = "CSVエクスポートに失敗しました: \(error.localizedDescription)"
        }
    }

    private func defaultCSVFilename() -> String {
        let formatter: DateFormatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let dateString: String = formatter.string(from: Date())
        return "定期支払い一覧_\(dateString).csv"
    }

    private func handleExportCompletion(result: Result<URL, Error>) {
        switch result {
        case .success:
            // エクスポート成功
            break
        case let .failure(error):
            exportError = "ファイル保存に失敗しました: \(error.localizedDescription)"
        }
    }
}

private extension RecurringPaymentListContentView {
    var domainCategories: [Category] {
        allCategoryEntities.map { Category(from: $0) }
    }
}

// MARK: - Filter Toolbar View

private struct RecurringPaymentFilterToolbarView: View {
    @Bindable internal var store: RecurringPaymentListStore

    internal var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 期間選択
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("開始日")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DatePicker(
                        "",
                        selection: $store.dateRange.startDate,
                        displayedComponents: [.date],
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("終了日")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DatePicker(
                        "",
                        selection: $store.dateRange.endDate,
                        displayedComponents: [.date],
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                }

                Divider()

                // カテゴリフィルタ
                VStack(alignment: .leading, spacing: 4) {
                    Text("カテゴリ")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    CategoryHierarchyPicker(
                        categories: store.categoryFilter.availableCategories,
                        selectedMajorCategoryId: $store.categoryFilter.selectedMajorCategoryId,
                        selectedMinorCategoryId: $store.categoryFilter.selectedMinorCategoryId,
                        majorPlaceholder: "すべて",
                        minorPlaceholder: "中項目を選択",
                        inactiveMinorMessage: "大項目を選択すると中項目で絞り込めます",
                        noMinorMessage: "この大項目に中項目はありません",
                    )
                    .frame(minWidth: 200, alignment: .leading)
                }

                // ステータスフィルタ
                VStack(alignment: .leading, spacing: 4) {
                    Text("ステータス")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $store.selectedStatus) {
                        Text("すべて").tag(nil as RecurringPaymentStatus?)
                        Text("予定のみ").tag(RecurringPaymentStatus.planned as RecurringPaymentStatus?)
                        Text("積立中").tag(RecurringPaymentStatus.saving as RecurringPaymentStatus?)
                        Text("完了").tag(RecurringPaymentStatus.completed as RecurringPaymentStatus?)
                        Text("中止").tag(RecurringPaymentStatus.cancelled as RecurringPaymentStatus?)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(minWidth: 120)
                }

                Spacer()

                // 検索フィールド
                TextField("名称で検索", text: $store.searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 240)
            }

            // ソート順選択
            HStack(spacing: 12) {
                Text("並び順:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("", selection: $store.sortOrder) {
                    Text("日付（昇順）").tag(RecurringPaymentListStore.SortOrder.dateAscending)
                    Text("日付（降順）").tag(RecurringPaymentListStore.SortOrder.dateDescending)
                    Text("名称（昇順）").tag(RecurringPaymentListStore.SortOrder.nameAscending)
                    Text("名称（降順）").tag(RecurringPaymentListStore.SortOrder.nameDescending)
                    Text("金額（昇順）").tag(RecurringPaymentListStore.SortOrder.amountAscending)
                    Text("金額（降順）").tag(RecurringPaymentListStore.SortOrder.amountDescending)
                }
                .pickerStyle(.segmented)

                Spacer()

                Text("\(store.cachedEntries.count)件")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Entries Table View

private struct RecurringPaymentEntriesTableView: View {
    @Bindable internal var store: RecurringPaymentListStore

    internal var body: some View {
        if store.cachedEntries.isEmpty {
            ContentUnavailableView {
                Label("定期支払いがありません", systemImage: "tray")
            } description: {
                Text("フィルタを変更するか、定期支払いを追加してください。")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Table(store.cachedEntries) {
                TableColumn("名称") { entry in
                    HStack(spacing: 6) {
                        Text(entry.name)

                        if entry.hasDiscrepancy {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                                .help("実績額が予定額と異なります")
                        }

                        if entry.isOverdue {
                            Image(systemName: "clock.badge.exclamationmark")
                                .foregroundStyle(.red)
                                .font(.caption)
                                .help("期限超過")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                TableColumn("カテゴリ") { entry in
                    Text(entry.categoryName ?? "未設定")
                        .foregroundStyle(entry.categoryName == nil ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                TableColumn("予定日") { entry in
                    Text(entry.scheduledDate.shortDateFormatted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                TableColumn("予定額") { entry in
                    Text(entry.expectedAmount.currencyFormatted)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                TableColumn("実績額") { entry in
                    Group {
                        if let actualAmount = entry.actualAmount {
                            Text(actualAmount.currencyFormatted)
                        } else {
                            Text("—")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }

                TableColumn("積立状況") { entry in
                    HStack(spacing: 8) {
                        ProgressView(value: entry.savingsProgress, total: 1.0)
                            .progressViewStyle(.linear)
                            .frame(maxWidth: 100)

                        Text(String(format: "%.0f%%", entry.savingsProgress * 100))
                            .font(.caption)
                            .foregroundStyle(entry.isFullySaved ? .green : .secondary)
                            .frame(minWidth: 40, alignment: .trailing)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                TableColumn("ステータス") { entry in
                    Text(entry.status.displayName)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(entry.status.badgeColor.opacity(0.15)),
                        )
                        .foregroundStyle(entry.status.badgeColor)
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .frame(minHeight: 400)
        }
    }
}

// MARK: - RecurringPaymentStatus Extensions

private extension RecurringPaymentStatus {
    var displayName: String {
        switch self {
        case .planned:
            "予定のみ"
        case .saving:
            "積立中"
        case .completed:
            "完了"
        case .cancelled:
            "中止"
        }
    }

    var badgeColor: Color {
        switch self {
        case .planned:
            .gray
        case .saving:
            .blue
        case .completed:
            .green
        case .cancelled:
            .red
        }
    }
}
