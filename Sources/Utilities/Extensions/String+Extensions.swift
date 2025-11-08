import Foundation

// MARK: - 基本的な文字列処理

/// 基本的な文字列処理の拡張
public extension String {
    /// 空白文字列かどうか（空文字列または空白のみの場合true）
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 空白文字列でないかどうか
    var isNotBlank: Bool {
        !isBlank
    }

    /// 前後の空白を削除
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// nilまたは空白の場合にデフォルト値を返す
    /// - Parameter defaultValue: デフォルト値
    /// - Returns: 値またはデフォルト値
    func orDefault(_ defaultValue: String) -> String {
        isBlank ? defaultValue : self
    }
}

// MARK: - 変換

/// 文字列変換の拡張
public extension String {
    /// Decimalに変換
    var toDecimal: Decimal? {
        Decimal(string: self)
    }

    /// Intに変換
    var toInt: Int? {
        Int(self)
    }

    /// Doubleに変換
    var toDouble: Double? {
        Double(self)
    }

    /// Dateに変換（yyyy-MM-dd形式）
    var toDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.date(from: self)
    }

    /// Dateに変換（yyyy-MM-dd HH:mm:ss形式）
    var toDateTime: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.date(from: self)
    }
}

// MARK: - バリデーション

/// バリデーションの拡張
public extension String {
    /// 数値文字列かどうか
    var isNumeric: Bool {
        !isEmpty && allSatisfy(\.isNumber)
    }

    /// 半角英数字のみかどうか
    var isAlphanumeric: Bool {
        !isEmpty && allSatisfy { $0.isLetter || $0.isNumber }
    }

    /// メールアドレスの形式かどうか（簡易チェック）
    var isEmail: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: self)
    }

    /// 指定した長さの範囲内かどうか
    /// - Parameters:
    ///   - min: 最小長
    ///   - max: 最大長
    /// - Returns: 範囲内の場合true
    func hasLength(min: Int, max: Int) -> Bool {
        count >= min && count <= max
    }

    /// 指定した長さ以上かどうか
    /// - Parameter min: 最小長
    /// - Returns: 最小長以上の場合true
    func hasMinLength(_ min: Int) -> Bool {
        count >= min
    }

    /// 指定した長さ以下かどうか
    /// - Parameter max: 最大長
    /// - Returns: 最大長以下の場合true
    func hasMaxLength(_ max: Int) -> Bool {
        count <= max
    }
}

// MARK: - 文字列操作

/// 文字列操作の拡張
public extension String {
    /// 指定した長さで切り詰める（末尾に省略記号を追加）
    /// - Parameters:
    ///   - length: 最大長
    ///   - trailing: 末尾に追加する文字列（デフォルト: "..."）
    /// - Returns: 切り詰められた文字列
    func truncate(length: Int, trailing: String = "...") -> String {
        if count > length {
            return String(prefix(length)) + trailing
        }
        return self
    }

    /// 先頭の文字を大文字に変換
    var capitalizedFirst: String {
        guard !isEmpty else { return self }
        return prefix(1).uppercased() + dropFirst()
    }

    /// スネークケースをキャメルケースに変換
    var camelCased: String {
        let components = split(separator: "_")
        guard let first = components.first else { return self }
        let rest = components.dropFirst().map { String($0).capitalizedFirst }
        return ([String(first)] + rest).joined()
    }

    /// キャメルケースをスネークケースに変換
    var snakeCased: String {
        let pattern = "([a-z0-9])([A-Z])"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(location: 0, length: utf16.count)
        let result = regex?.stringByReplacingMatches(
            in: self,
            options: [],
            range: range,
            withTemplate: "$1_$2",
        )
        return result?.lowercased() ?? lowercased()
    }
}

// MARK: - サブスクリプト

/// サブスクリプトの拡張
public extension String {
    /// 安全な文字列のサブスクリプト（範囲外の場合はnil）
    subscript(safe index: Int) -> Character? {
        guard index >= 0, index < count else { return nil }
        return self[self.index(startIndex, offsetBy: index)]
    }

    /// 安全な文字列のサブスクリプト（範囲外の場合は空文字列）
    subscript(safe range: Range<Int>) -> String {
        let start = max(0, range.lowerBound)
        let end = min(count, range.upperBound)
        guard start < end else { return "" }
        let startIndex = index(startIndex, offsetBy: start)
        let endIndex = index(startIndex, offsetBy: end)
        return String(self[startIndex ..< endIndex])
    }
}
