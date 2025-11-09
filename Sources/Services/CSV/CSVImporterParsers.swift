import Foundation

// MARK: - Parsing Extensions

extension CSVImporter {
    /// 日付文字列をパース
    func parseDate(_ value: String) -> Date? {
        for formatter in dateFormatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return ISO8601DateFormatter().date(from: value)
    }

    /// 金額文字列をパース（カンマ、円記号などを除去）
    func parseDecimal(_ value: String) -> Decimal? {
        var sanitized = value
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: "円", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if sanitized.hasPrefix("("), sanitized.hasSuffix(")") {
            sanitized.removeFirst()
            sanitized.removeLast()
            sanitized = "-" + sanitized
        }

        return Decimal(string: sanitized, locale: locale)
    }

    /// ブール値文字列をパース
    func parseBoolean(_ value: String) -> Bool? {
        let lowered = value.lowercased()
        switch lowered {
        case "1", "true", "yes", "y", "on", "はい", "有", "true.":
            return true
        case "0", "false", "no", "n", "off", "いいえ", "無":
            return false
        default:
            return nil
        }
    }

    /// オプショナル文字列を正規化（空白のみの場合はnil）
    func normalizedOptional(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
