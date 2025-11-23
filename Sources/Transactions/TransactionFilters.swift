import Foundation

/// 取引リストの表示種別フィルタ
internal enum TransactionFilterKind: String, CaseIterable, Identifiable, Hashable, Sendable {
    case all = "すべて"
    case income = "収入"
    case expense = "支出"

    internal var id: Self { self }
    internal var label: String { rawValue }
}

/// 取引フォームで使用する入出金種別
internal enum TransactionKind: String, CaseIterable, Identifiable, Sendable {
    case income = "収入"
    case expense = "支出"

    internal var id: Self { self }
    internal var label: String { rawValue }
}

/// 並び替えオプション
internal enum TransactionSortOption: String, CaseIterable, Identifiable, Sendable {
    case dateDescending = "日付（新しい順）"
    case dateAscending = "日付（古い順）"
    case amountDescending = "金額（大きい順）"
    case amountAscending = "金額（小さい順）"

    internal var id: Self { self }
    internal var label: String { rawValue }
}
