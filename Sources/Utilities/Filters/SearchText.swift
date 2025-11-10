import Foundation

/// 検索キーワードの正規化・照合を行う値オブジェクト。
internal struct SearchText: Equatable, Sendable {
    /// 入力された生文字列
    internal let rawValue: String

    internal init(_ rawValue: String = "") {
        self.rawValue = rawValue
    }

    /// 前後の空白を除去した文字列（大文字・小文字は保持）
    internal var trimmedValue: String {
        rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 前後空白除去後の値。空文字なら `nil`
    internal var normalizedValue: String? {
        let value = trimmedValue
        return value.isEmpty ? nil : value
    }

    /// 検索比較用に小文字へ正規化した値。空文字の場合は `nil`
    internal var comparisonValue: String? {
        normalizedValue?.lowercased()
    }

    internal var isEmpty: Bool {
        normalizedValue == nil
    }

    /// 値が存在する場合に true/false を返す。値が空なら常に true。
    internal func matches(haystack: String) -> Bool {
        guard let keyword = comparisonValue else { return true }
        return haystack.lowercased().contains(keyword)
    }

    /// 値が存在する場合に、与えられた文字列配列のいずれかに含まれるかを判定する。
    internal func matchesAny(haystacks: [String]) -> Bool {
        guard let keyword = comparisonValue else { return true }
        return haystacks.contains { $0.lowercased().contains(keyword) }
    }
}
