# ベースラインメトリクス & テスト影響リスト

- 最終更新日: 2025-11-10
- 取得手順: `scripts/baseline_metrics.sh`, `swiftlint lint`, `swiftformat --lint .`
- ログファイル: `docs/baseline/swiftlint-2025-11-10.log`, `docs/baseline/swiftformat-2025-11-10.log`

## 1. 収集フロー

1. `scripts/baseline_metrics.sh` を実行して主要ファイルの行数や `FetchDescriptor`/`CategoryHierarchyGrouping` 指標を取得する。
2. `swiftlint lint` を単体で実行し、`docs/baseline/` 以下にログを保存する（ `make lint` だと SwiftFormat に到達する前に終了するため）。
3. `swiftformat --lint .` を実行し、同様にログを保存する。`build/DerivedData` が存在する場合はクリーンアップしてからの実行が望ましい。
4. 本ドキュメントの表を更新し、「6. 更新テンプレート」にスナップショットを追記する。

## 2. 行数スナップショット

### 2.1 Stores（上位10本）

| ファイル | 行数 | 備考 |
| --- | ---: | --- |
| `Sources/Stores/BudgetStore.swift` | 613 | SwiftLint file_length 警告閾値 (600) を超過 |
| `Sources/Stores/TransactionStore.swift` | 593 | 600行目前、フェーズ1のリファクタ対象 |
| `Sources/Stores/SpecialPaymentReconciliationStore.swift` | 566 | 特別支払い照合作業の中核 |
| `Sources/Stores/SpecialPaymentStore.swift` | 406 | 定義・発生スケジュール管理 |
| `Sources/Stores/SpecialPaymentListStore.swift` | 351 | リスト表示用フィルタロジックが集中 |
| `Sources/Stores/ImportStore.swift` | 316 | CSVインポート系 |
| `Sources/Stores/DashboardStore.swift` | 309 | ダッシュボード集計 |
| `Sources/Stores/SettingsStore.swift` | 236 | 設定画面とバックアップ |
| `Sources/Stores/AppState.swift` | 65 | 画面状態管理 |
| `Sources/Stores/TransactionStore+CategoryFiltering.swift` | 17 | トランザクションカテゴリの拡張 |

### 2.2 Services（上位10本）

| ファイル | 行数 | 備考 |
| --- | ---: | --- |
| `Sources/Services/Calculations/AnnualBudgetAllocator.swift` | 729 | file_length/type_body_length/function_parameter_count の複数違反 |
| `Sources/Services/DataManagement/BackupManager.swift` | 410 | バックアップ／リストア |
| `Sources/Services/CSV/CSVTypes.swift` | 387 | CSV モデル変換 |
| `Sources/Services/Calculations/BudgetCalculator.swift` | 327 | 予算計算 |
| `Sources/Services/Calculations/TransactionAggregator.swift` | 312 | 集計処理 |
| `Sources/Services/CSV/CSVImporter.swift` | 244 | CSV インポート制御 |
| `Sources/Services/Calculations/AnnualBudgetProgressCalculator.swift` | 220 | 進捗計算 |
| `Sources/Services/SpecialPayments/SpecialPaymentBalanceService.swift` | 218 | 特別支払い残高 |
| `Sources/Services/SpecialPayments/SpecialPaymentScheduleService.swift` | 191 | スケジュール生成 |
| `Sources/Services/DataManagement/CSVExporter.swift` | 190 | CSV エクスポート |

## 3. API/型利用指標

### 3.1 `FetchDescriptor` の出現状況

| 領域 | 出現数 | 補足 |
| --- | ---: | --- |
| `Sources/Stores` | 22 | 取引・予算・特別支払いのクエリが集中 |
| `Sources/Services` | 8 | CSV/Backup などデータ同期系 |
| `Tests` | 15 | ストア／サービスのフェッチ検証 |
| その他 (`Sources/App`, `Sources/Dev`, など) | 6 | SeedHelper など |
| **合計** | **51** | `scripts/baseline_metrics.sh` より |

### 3.2 `CategoryHierarchyGrouping` の利用箇所

| ファイル | 用途 |
| --- | --- |
| `Sources/Utilities/CategoryHierarchyGrouping.swift` | グルーピング実装 |
| `Sources/Views/Budgets/BudgetEditorSheet.swift` | 予算編集 UI |
| `Sources/Views/Components/CategoryHierarchyPicker.swift` | 汎用ピッカー |
| `Tests/Utilities/CategoryHierarchyGroupingTests.swift` | 単体テスト |

## 4. 静的解析ログ概要

### 4.1 SwiftLint（10件、ログ: `docs/baseline/swiftlint-2025-11-10.log`）

- `BudgetView.swift:279` に cyclomatic_complexity 10（許容 8）の関数が存在。
- `AnnualBudgetAllocator.swift` で `file_length` (729行) と `type_body_length` (416行) に加え、6パラメータ関数が4本存在。
- `AnnualBudgetAllocatorTests.swift` 系で `type_body_length` / `large_tuple` 違反が各1件ずつ、`AnnualBudgetAllocatorCategoryTests.swift` でも large_tuple が1件。
- 重点監視領域: 計算サービスとそのテスト群。フェーズ2以降のリファクタで優先的に解消する。

### 4.2 SwiftFormat（ログ: `docs/baseline/swiftformat-2025-11-10.log`）

- `build/DerivedData` を削除した状態で再実行した結果、指摘 0 件。
- 生成物に依存する指摘は、テストやビルドで DerivedData が再生成された際のみ再発する。

## 5. テスト影響リスト（想定実行時間は M2 MacBook Air での目安）

| フェーズ | 目的 / スコープ | 推奨テスト | コマンド例 | 想定時間 | 注意点 |
| --- | --- | --- | --- | --- | --- |
| Phase 0 | UI 以外のビルド破壊検知 | なし（`make generate` のみ） | `make generate` | 1分 | XcodeProj 再生成で差分確認 |
| Phase 1 | 取引・予算ストア回帰 | `TransactionStoreTests`, `BudgetStoreTestsBasic`, `BudgetStoreTestsAnnualConfig` | `timeout 120 xcodebuild ... -only-testing:KakeiboTests/TransactionStoreTests -only-testing:KakeiboTests/BudgetStoreTestsBasic -only-testing:KakeiboTests/BudgetStoreTestsAnnualConfig` | 3〜4分 | SwiftData の in-memory Container を多用するため、テスト前に `DerivedData` をクリーン推奨 |
| Phase 2 | 特別支払いストア／サービス | `SpecialPaymentStoreTests`, `SpecialPaymentStoreCreateDefinitionTests`, `SpecialPaymentStoreDeleteDefinitionTests`, `SpecialPaymentStoreUpdateDefinitionTests`, `SpecialPaymentScheduleService*`, `SpecialPaymentListStore_FilterTests` | `timeout 180 xcodebuild ... -only-testing:KakeiboTests/SpecialPaymentStoreTests ...` | 5〜6分 | 逐次実行（`@Suite(.serialized)`）が多く、タイムアウトが発生しやすい |
| Phase 3 | 予算計算・割当アルゴリズム | `BudgetCalculator*Tests`, `AnnualBudgetAllocatorTests`, `AnnualBudgetAllocatorCategoryTests`, `AnnualBudgetProgressCalculatorTests`, `TransactionAggregatorTests` | `timeout 180 xcodebuild ... -only-testing:KakeiboTests/AnnualBudgetAllocatorTests ...` | 4〜5分 | SwiftLint 違反箇所と同じファイル群。挙動変更時はテスト入力の大規模 CSV を再生成する |
| Phase 4 | リリース前フル回帰 | `make test` (全テスト) | `make test` | 10〜12分 | `CODE_SIGNING_ALLOWED=NO` 済み。並列化されないテストが混在するため時間に余裕を確保 |

> `...` 部分の xcodebuild コマンド引数は `-project Kakeibo.xcodeproj -scheme Kakeibo -destination 'platform=macOS,arch=arm64' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO test` を共通で付与する。

## 6. 更新テンプレート

| 日付 | 担当 | scripts 出力コミット | SwiftLint違反数 | SwiftFormat指摘数 | メモ |
| --- | --- | --- | ---: | ---: | --- |
| 2025-11-10 | Agent | `scripts/baseline_metrics.sh` 追加 | 10 | 0 | DerivedData削除後に再測定 |
| YYYY-MM-DD | | | | | |

- 新しいスナップショットを取る場合は、上記テーブルに追記し、必要に応じてログファイル名も日付付きで追加する。
