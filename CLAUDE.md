# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

macOS向けのSwiftUI + SwiftDataで構築された家計簿アプリケーション。取引管理、予算管理、定期支払い、CSVインポート/エクスポートなどの機能を提供します。

## ビルドとテスト

### プロジェクト生成とビルド

```bash
# XcodeGenでプロジェクトファイルを生成
make generate

# デバッグビルド
make build

# リリースビルド
make release

# ビルドしてアプリを起動
make run
```

### テスト実行

```bash
# 全テストを実行
make test

# 特定のテストスイートを実行（例: TransactionTests）
timeout 120 xcodebuild -project Kakeibo.xcodeproj -scheme Kakeibo \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO test \
  -only-testing:KakeiboTests/TransactionTests
```

### コード品質チェック

```bash
# Lintチェック（SwiftLint + SwiftFormat）
make lint

# 自動フォーマット
make format

# クリーンビルド
make clean
make generate
make build
```

### その他のコマンド

```bash
# アプリを/Applicationsにインストール
make install
```

## アーキテクチャ

### レイヤー構造

クリーンアーキテクチャをベースにした階層構造:

- **Domain**: ビジネスロジックの核心
  - `Models/`: ドメインモデル（Transaction, Budget, Category等）
  - `ValueObjects/`: 値オブジェクト（DayOfMonthPattern, Weekday等）
  - `Repositories/`: リポジトリのプロトコル定義
  - `Inputs/`: 入力DTO（TransactionInput, BudgetInputs, RecurringPaymentInputs等）

- **Infrastructure**: 外部システムとの連携
  - `Persistence/Models/SwiftData/`: SwiftDataモデル（SwiftDataTransaction等）
  - `Persistence/Repositories/SwiftData/`: リポジトリの実装
  - `Persistence/Queries/`: SwiftData用のクエリ構築ロジック

- **UseCases**: アプリケーション固有のビジネスロジック
  - `Budgets/`: 予算関連のユースケース
  - `Transactions/`: 取引関連のユースケース

- **Services**: 複数のユースケースで共有されるサービス
  - `CSV/`: CSVインポート/エクスポート
  - `Calculations/`: 予算計算エンジン
  - `RecurringPayments/`: 定期支払いのスケジューリング
  - `SavingsGoals/`: 貯蓄目標管理

- **Stores**: SwiftUIのObservableな状態管理
  - `BudgetStore`: 予算画面の状態管理
  - `TransactionStore`: 取引画面の状態管理
  - `DashboardStore`: ダッシュボード画面の状態管理

- **Views**: SwiftUIのビューコンポーネント
  - `Budgets/`: 予算関連のビュー
  - `Transactions/`: 取引関連のビュー
  - `Dashboard/`: ダッシュボード
  - `Settings/`: 設定画面

- **Presenters**: ビューに表示するためのデータ変換
  - `Budgets/`: 予算表示用のエントリ

### 依存関係の方向

- Domain層は他のどの層にも依存しない
- Infrastructure層はDomain層のプロトコルを実装
- UseCases層はDomain層とInfrastructure層に依存
- Services層はDomain層に依存
- Stores層はUseCases層とServices層に依存
- Views層はStores層に依存

### アーキテクチャ原則

**オニオンアーキテクチャの厳格な適用:**
- Repository protocolのinput/outputは必ずSendableに準拠すること
- `unsafe`, `unchecked`の使用は禁止
- Infrastructure層以外でSwiftData依存のコードを書かない
- View層でSwiftDataモデル（`SwiftData*`）に直接アクセスしない
- 入力DTOは`Sources/Domain/Inputs/`に配置
- クエリ・フィルタ型はすべてSendableに準拠

### データの流れ

1. ユーザー操作 → View
2. View → Store（@Observable）
3. Store → UseCase
4. UseCase → Repository（Domain protocol）
5. Repository実装 → SwiftData

### ModelActorパターン

バックグラウンドでのModelContext操作には専用のModelActorを使用:
- `BudgetModelActor`: 予算データの非同期操作
- `TransactionModelActor`: 取引データの非同期操作
- `RecurringPaymentModelActor`: 定期支払いデータの非同期操作

これらはメインスレッドをブロックせずにSwiftDataの読み書きを行います。

### 定期支払い機能

定期支払い（RecurringPayment）は以下のコンポーネントで構成:
- `RecurringPaymentDefinition`: 定期支払いの定義（スケジュール、金額等）
- `RecurringPaymentOccurrence`: 実際の支払い発生記録
- `BusinessDayService`: 営業日判定（日本の祝日対応）
- `HolidayProvider`: 祝日情報の提供（JapaneseHolidayProvider等）

### 予算計算

複雑な予算計算は以下のサービスで実行:
- `BudgetCalculator`: 月次予算の計算
- `AnnualBudgetAllocator`: 年次予算の配分
- `AnnualBudgetProgressCalculator`: 年次予算の進捗計算
- `BudgetCalculationCache`: 計算結果のキャッシュ

## 技術的な制約

- **Swift 6.2**: プロジェクト全体でSwift 6.2の厳密な並行性チェックを有効化
- **macOS 26.0以降**: デプロイメントターゲット
- **Swift Concurrency**: async/await、Actor、@Sendableを全面的に使用
- **Swift Testing**: テストフレームワーク（XCTestではない）
- **警告をエラーとして扱う**: `OTHER_SWIFT_FLAGS: -warnings-as-errors`

## 開発時の注意点

### プロジェクトファイルの管理

- `project.yml`がソースで、`Kakeibo.xcodeproj`は生成物
- プロジェクト構造を変更する場合は`project.yml`を編集し、`make generate`を実行

### Mintの使用

SwiftLint、SwiftFormat、XcodeGenはMintで管理されています。必要に応じて:

```bash
mint bootstrap  # 初回のみ
```

### テストの並行性

全てのテストは`@MainActor`アノテーションを使用するか、SwiftDataのModelContextを適切なActorで扱う必要があります。

### SwiftDataの扱い

- `SwiftData*`プレフィックスのモデルはInfrastructure層のみ
- Domain層では純粋なSwift構造体を使用
- リポジトリ層でSwiftDataモデル ⇔ ドメインモデルの変換を行う
