# Kakeibo

macOS向けの家計簿アプリケーション。SwiftUI + SwiftDataで構築されたネイティブアプリケーションです。

## 必要な環境

- macOS 26.0以降
- Xcode（Swift 6.2対応版）
- XcodeGen
- SwiftLint
- SwiftFormat

## ビルド方法

### 1. プロジェクトファイルの生成

```bash
make generate
```

XcodeGenを使用してXcodeプロジェクト（Kakeibo.xcodeproj）を生成します。

### 2. ビルド

```bash
make build
```

Debug構成でビルドされます。

### 3. テスト実行

```bash
make test
```

全テストを実行します。

## 開発

### コードフォーマット

```bash
make format  # 自動整形
make lint    # SwiftLint + SwiftFormat のチェック
```

### クリーンビルド

```bash
make clean
make generate
make build
```

## その他のコマンド

個別のテストスイートを実行する場合:

```bash
# TransactionTestsスイート全体
timeout 120 xcodebuild -project Kakeibo.xcodeproj -scheme Kakeibo \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO test \
  -only-testing:KakeiboTests/TransactionTests
```

## 機能

- 取引（収入・支出）の記録
- カテゴリ別の集計
- 月次予算管理
- 年次予算・特別枠の設定
- 特別支払いのスケジュール管理と積立計算
- CSVインポート/エクスポート
- データバックアップ

## 技術スタック

- **SwiftUI**: UIフレームワーク
- **SwiftData**: データ永続化
- **Swift Concurrency**: 非同期処理
- **Swift Testing**: テストフレームワーク
