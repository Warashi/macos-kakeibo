import Foundation
import SwiftData

@Model
internal final class Category {
    internal var id: UUID
    internal var name: String

    /// 階層構造: 親カテゴリがnilなら大項目、あれば中項目
    internal var parent: Category?

    /// 逆参照: 子カテゴリのリスト（大項目の場合のみ使用）
    @Relationship(deleteRule: .cascade, inverse: \Category.parent)
    internal var children: [Category]

    /// 年次特別枠の使用可否（大項目・中項目どちらでも設定可能）
    internal var allowsAnnualBudget: Bool

    /// 表示順序
    internal var displayOrder: Int

    /// 作成・更新日時
    internal var createdAt: Date
    internal var updatedAt: Date

    internal init(
        id: UUID = UUID(),
        name: String,
        parent: Category? = nil,
        allowsAnnualBudget: Bool = false,
        displayOrder: Int = 0,
    ) {
        self.id = id
        self.name = name
        self.parent = parent
        self.children = []
        self.allowsAnnualBudget = allowsAnnualBudget
        self.displayOrder = displayOrder

        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }
}

// MARK: - Computed Properties

internal extension Category {
    /// 大項目かどうか
    var isMajor: Bool {
        parent == nil
    }

    /// 中項目かどうか
    var isMinor: Bool {
        parent != nil
    }

    /// フルパス表示用の名前（例: "食費 / 外食"）
    var fullName: String {
        if let parent {
            return "\(parent.name) / \(name)"
        }
        return name
    }
}

// MARK: - Convenience

internal extension Category {
    /// 指定された名前の子カテゴリを取得
    func child(named name: String) -> Category? {
        children.first { $0.name == name }
    }

    /// 子カテゴリを追加
    func addChild(_ child: Category) {
        child.parent = self
        children.append(child)
    }
}
