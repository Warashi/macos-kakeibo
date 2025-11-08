import Foundation

// MARK: - 通貨フォーマット

/// 通貨フォーマットの拡張
public extension Decimal {
    /// 通貨形式でフォーマット（例: "¥1,234"）
    var currencyFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.maximumFractionDigits = 0
        return formatter.string(from: self as NSDecimalNumber) ?? "¥0"
    }

    /// 通貨形式でフォーマット（記号なし、例: "1,234"）
    var currencyFormattedWithoutSymbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.maximumFractionDigits = 0
        return formatter.string(from: self as NSDecimalNumber) ?? "0"
    }

    /// 符号付き通貨形式でフォーマット（例: "+¥1,234"、"-¥1,234"）
    var signedCurrencyFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.maximumFractionDigits = 0
        formatter.positivePrefix = "+"
        formatter.negativePrefix = "-"
        return formatter.string(from: self as NSDecimalNumber) ?? "¥0"
    }
}

// MARK: - 金額計算

/// 金額計算の拡張
public extension Decimal {
    /// 正の値かどうか
    var isPositive: Bool {
        self > 0
    }

    /// 負の値かどうか
    var isNegative: Bool {
        self < 0
    }

    /// ゼロかどうか
    var isZero: Bool {
        self == 0
    }

    /// 絶対値を返す
    var absoluteValue: Decimal {
        abs(self)
    }

    /// 安全な加算（オーバーフロー対策）
    /// - Parameter other: 加算する値
    /// - Returns: 加算結果
    func safeAdd(_ other: Decimal) -> Decimal {
        var lhs = self
        var rhs = other
        var result = Decimal()
        NSDecimalAdd(&result, &lhs, &rhs, .plain)
        return result
    }

    /// 安全な減算（オーバーフロー対策）
    /// - Parameter other: 減算する値
    /// - Returns: 減算結果
    func safeSubtract(_ other: Decimal) -> Decimal {
        var lhs = self
        var rhs = other
        var result = Decimal()
        NSDecimalSubtract(&result, &lhs, &rhs, .plain)
        return result
    }

    /// 安全な乗算（オーバーフロー対策）
    /// - Parameter other: 乗算する値
    /// - Returns: 乗算結果
    func safeMultiply(_ other: Decimal) -> Decimal {
        var lhs = self
        var rhs = other
        var result = Decimal()
        NSDecimalMultiply(&result, &lhs, &rhs, .plain)
        return result
    }

    /// 安全な除算（ゼロ除算対策）
    /// - Parameter other: 除算する値
    /// - Returns: 除算結果（ゼロ除算の場合は0を返す）
    func safeDivide(_ other: Decimal) -> Decimal {
        guard other != 0 else { return 0 }
        var lhs = self
        var rhs = other
        var result = Decimal()
        NSDecimalDivide(&result, &lhs, &rhs, .plain)
        return result
    }

    /// パーセンテージを計算
    /// - Parameter total: 全体の値
    /// - Returns: パーセンテージ（0-100）
    func percentage(of total: Decimal) -> Decimal {
        guard total != 0 else { return 0 }
        return (self / total) * 100
    }

    /// 指定したパーセンテージの値を計算
    /// - Parameter percentage: パーセンテージ（0-100）
    /// - Returns: 計算結果
    func applying(percentage: Decimal) -> Decimal {
        self * (percentage / 100)
    }
}

// MARK: - 丸め処理

/// 丸め処理の拡張
public extension Decimal {
    /// 指定した桁数で四捨五入
    /// - Parameter scale: 小数点以下の桁数
    /// - Returns: 四捨五入された値
    func rounded(scale: Int = 0) -> Decimal {
        var result = self
        var rounded = Decimal()
        NSDecimalRound(&rounded, &result, scale, .plain)
        return rounded
    }

    /// 切り上げ
    /// - Parameter scale: 小数点以下の桁数
    /// - Returns: 切り上げられた値
    func roundedUp(scale: Int = 0) -> Decimal {
        var result = self
        var rounded = Decimal()
        NSDecimalRound(&rounded, &result, scale, .up)
        return rounded
    }

    /// 切り捨て
    /// - Parameter scale: 小数点以下の桁数
    /// - Returns: 切り捨てられた値
    func roundedDown(scale: Int = 0) -> Decimal {
        var result = self
        var rounded = Decimal()
        NSDecimalRound(&rounded, &result, scale, .down)
        return rounded
    }
}

// MARK: - 比較

/// 比較の拡張
public extension Decimal {
    /// 範囲内かチェック
    /// - Parameters:
    ///   - min: 最小値
    ///   - max: 最大値
    /// - Returns: 範囲内の場合true
    func isInRange(min: Decimal, max: Decimal) -> Bool {
        self >= min && self <= max
    }
}

// MARK: - 変換

/// 型変換の拡張
public extension Decimal {
    /// Doubleに変換
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }

    /// Intに変換（切り捨て）
    var intValue: Int {
        NSDecimalNumber(decimal: self).intValue
    }
}
