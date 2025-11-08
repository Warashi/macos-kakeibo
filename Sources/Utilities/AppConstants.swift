import Foundation
import SwiftUI

/// アプリケーション全体で使用する定数
public enum AppConstants {
    // MARK: - アプリケーション情報

    /// アプリケーション情報
    public enum App {
        /// アプリケーション名
        public static let name: String = "家計簿"

        /// アプリケーションバージョン
        public static var version: String {
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        }

        /// ビルド番号
        public static var build: String {
            Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        }
    }

    // MARK: - ロケール・フォーマット

    /// ロケールとフォーマット設定
    public enum Locale {
        /// デフォルトロケール
        public static let `default`: Foundation.Locale = Foundation.Locale(identifier: "ja_JP")

        /// 通貨記号
        public static let currencySymbol: String = "¥"

        /// 通貨コード
        public static let currencyCode: String = "JPY"
    }

    // MARK: - 日付・時刻

    /// 日付と時刻の設定
    public enum Date {
        /// サポートする最小年
        public static let minYear: Int = 2000

        /// サポートする最大年
        public static let maxYear: Int = 2100

        /// デフォルトの年月フォーマット
        public static let yearMonthFormat: String = "yyyy年MM月"

        /// デフォルトの日付フォーマット
        public static let dateFormat: String = "yyyy年MM月dd日"

        /// 短い日付フォーマット
        public static let shortDateFormat: String = "yyyy/MM/dd"
    }

    // MARK: - 金額

    /// 金額の設定
    public enum Amount {
        /// 最小金額
        public static let min: Decimal = 0

        /// 最大金額
        public static let max: Decimal = 999_999_999

        /// デフォルト金額
        public static let `default`: Decimal = 0
    }

    // MARK: - 文字列長

    /// 文字列長の制限
    public enum StringLength {
        /// カテゴリ名の最大長
        public static let categoryName: Int = 50

        /// メモの最大長
        public static let memo: Int = 500

        /// 金融機関名の最大長
        public static let financialInstitutionName: Int = 50

        /// 一般的な名前の最大長
        public static let name: Int = 100
    }

    // MARK: - UI

    /// ユーザーインターフェースの設定
    public enum UserInterface {
        /// 基本的な余白
        public static let spacing: CGFloat = 8

        /// 大きい余白
        public static let largeSpacing: CGFloat = 16

        /// 小さい余白
        public static let smallSpacing: CGFloat = 4

        /// 基本的な角丸
        public static let cornerRadius: CGFloat = 8

        /// 小さい角丸
        public static let smallCornerRadius: CGFloat = 4

        /// アニメーション時間
        public static let animationDuration: Double = 0.3

        /// カードの影の半径
        public static let cardShadowRadius: CGFloat = 4

        /// カードの影の不透明度
        public static let cardShadowOpacity: Double = 0.1

        /// 最小ウィンドウ幅
        public static let minWindowWidth: CGFloat = 800

        /// 最小ウィンドウ高さ
        public static let minWindowHeight: CGFloat = 600
    }

    // MARK: - CSV

    /// CSV設定
    public enum CSV {
        /// デフォルトの文字エンコーディング
        public static let encoding: String.Encoding = String.Encoding.utf8

        /// デフォルトのデリミタ
        public static let delimiter: String = ","

        /// デフォルトの改行コード
        public static let newline: String = "\n"
    }

    // MARK: - バックアップ

    /// バックアップ設定
    public enum Backup {
        /// バックアップファイルの拡張子
        public static let fileExtension: String = "json"

        /// バックアップファイル名のプレフィックス
        public static let filePrefix: String = "kakeibo_backup_"

        /// バックアップファイル名の日時フォーマット
        public static let fileDateFormat: String = "yyyyMMdd_HHmmss"
    }

    // MARK: - データベース

    /// データベース設定
    public enum Database {
        /// データベースファイル名
        public static let fileName: String = "Kakeibo.sqlite"

        /// バッチサイズ（大量データ処理時）
        public static let batchSize: Int = 100
    }

    // MARK: - 検証

    /// バリデーション設定
    public enum Validation {
        /// カテゴリの最大階層数
        public static let maxCategoryDepth: Int = 2

        /// 月の範囲
        public static let monthRange: ClosedRange<Int> = 1 ... 12

        /// 年の範囲
        public static let yearRange: ClosedRange<Int> = Date.minYear ... Date.maxYear
    }
}
