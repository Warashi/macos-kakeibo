# SpecialPaymentRepository & ScheduleService

特別支払いドメインに対する読み書き操作を `SpecialPaymentRepository` に集約し、スケジュール生成の差分適用は `SpecialPaymentScheduleService` が担います。UI層やStore層は ModelContext を直接扱わず、Repository API を介して永続化と同期を行うことができます。

## Repository API

```swift
let repository = SwiftDataSpecialPaymentRepository(
    modelContext: modelContext,
    scheduleService: SpecialPaymentScheduleService(
        holidayProvider: JapaneseHolidayProvider()
    ),
    currentDateProvider: { Date() }
)

let definitions = try repository.definitions(
    filter: SpecialPaymentDefinitionFilter(
        searchText: "ローン",
        categoryIds: [selectedCategoryId]
    )
)

@discardableResult
func synchronizeDefinition(_ definition: SpecialPaymentDefinition) throws -> SpecialPaymentSynchronizationSummary {
    try repository.synchronize(
        definition: definition,
        horizonMonths: 36,
        referenceDate: Date()
    )
}
```

- `definitions(filter:)` / `occurrences(query:)` / `balances(query:)` で必要なデータを取得。
- `synchronize(definition:horizonMonths:referenceDate:)` は生成・更新・削除件数を `SpecialPaymentSynchronizationSummary` で返します。
- `markOccurrenceCompleted` / `updateOccurrence` は完了状態の変更に応じて自動で再同期を行います。
- エラーは `SpecialPaymentDomainError` に統一されています（validationFailed / categoryNotFound 等）。

## ScheduleService

`SpecialPaymentScheduleService` は `synchronizationPlan(...)` で差分を計算し、Repository が ModelContext へ反映します。

```swift
let service = SpecialPaymentScheduleService(
    calendar: Calendar(identifier: .gregorian),
    holidayProvider: CompositeHolidayProvider(
        providers: [JapaneseHolidayProvider(), CustomHolidayProvider(modelContext: modelContext)]
    )
)

let plan = service.synchronizationPlan(
    for: definition,
    referenceDate: Date(),
    horizonMonths: 24
)
```

- `SynchronizationResult` は `created/updated/removed/locked` のリストと並び替え済みOccurrenceを提供。
- `defaultStatus` と `leadTimeMonths` を用いて、完了・キャンセル済み以外のステータスを自動更新。

## テスト用 InMemory 実装

ユニットテストでは `InMemorySpecialPaymentRepository` を利用すると ModelContext を用意せずに同じ API を検証できます。

```swift
let repository = InMemorySpecialPaymentRepository(
    definitions: [definition],
    currentDateProvider: { referenceDate }
)

let summary = try repository.synchronize(
    definition: definition,
    horizonMonths: 12,
    referenceDate: referenceDate
)

#expect(summary.createdCount == 2)
```

## 導入ポイント

- Store層の初期化時に Repository を注入し、UIイベントからの命令は Repository 経由で完了/同期処理を行う。
- `SpecialPaymentScheduleService` は BusinessDayService/holiday provider を差し替え可能になったため、祝日計算のニーズに応じて DI する。
- 既存の `SpecialPaymentStore`, `SpecialPaymentListStore`, `SpecialPaymentReconciliationStore`, `BudgetStore` では `SpecialPaymentRepository` を受け取るイニシャライザを用意し、段階的に ModelContext 依存を除去していく。

## Presenter / DTO 層

一覧・調整ビューの整形ロジックは Presenter へ集約しました。

### SpecialPaymentListPresenter

```swift
let presenter = SpecialPaymentListPresenter()
let filter = SpecialPaymentListFilter(
    dateRange: DateRange(startDate: startDate, endDate: endDate),
    searchText: SearchText(searchText),
    categoryFilter: .init(
        majorCategoryId: selectedMajor,
        minorCategoryId: selectedMinor
    ),
    sortOrder: .dateAscending
)

let entries = presenter.entries(
    occurrences: occurrences,
    balances: balanceLookup,
    filter: filter,
    now: Date()
)
```

- `SpecialPaymentListEntry` はDTOとしてPresenterファイルに移動し、進捗率・残日数・差異判定を内部で計算。
- Store側はリポジトリからデータを引き、フィルタ情報を渡すだけで `[SpecialPaymentListEntry]` を取得する。

### SpecialPaymentReconciliationPresenter

```swift
let presenter = SpecialPaymentReconciliationPresenter()
let presentation = presenter.makePresentation(
    definitions: definitions,
    referenceDate: Date()
)

let candidates = presenter.transactionCandidates(
    for: occurrence,
    context: .init(
        transactions: allTransactions,
        linkedTransactionLookup: presentation.linkedTransactionLookup,
        windowDays: 60,
        limit: 12
    )
)
```

- `OccurrenceRow`・`TransactionCandidate` などのDTOをPresenterが提供し、needsAttention/スコアリング/ソート条件を単一箇所に集約。
- Storeはpresentation結果（rows/lookup）を保持し、検索やフォーム状態のみを管理。
- 候補スコアのロジックを共通化したことで、別画面での再利用やテストが容易になった。
