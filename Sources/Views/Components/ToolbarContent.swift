import SwiftUI

/// 追加ボタンのツールバーアイテム
///
/// 新しいアイテムを追加するための標準的なツールバーボタン。
public struct AddToolbarItem: ToolbarContent {
    /// ボタンのラベル
    private let label: String
    /// ボタンがタップされた時のアクション
    private let action: () -> Void

    /// AddToolbarItemを初期化します
    /// - Parameters:
    ///   - label: ボタンのラベル（デフォルト: "追加"）
    ///   - action: ボタンがタップされた時のアクション
    public init(label: String = "追加", action: @escaping () -> Void) {
        self.label = label
        self.action = action
    }

    public var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button(action: action) {
                Label(label, systemImage: "plus")
            }
            .help(label)
        }
    }
}

/// 削除ボタンのツールバーアイテム
///
/// 選択されたアイテムを削除するための標準的なツールバーボタン。
public struct DeleteToolbarItem: ToolbarContent {
    /// ボタンのラベル
    private let label: String
    /// ボタンの有効/無効状態
    private let isEnabled: Bool
    /// ボタンがタップされた時のアクション
    private let action: () -> Void

    /// DeleteToolbarItemを初期化します
    /// - Parameters:
    ///   - label: ボタンのラベル（デフォルト: "削除"）
    ///   - isEnabled: ボタンの有効/無効状態（デフォルト: true）
    ///   - action: ボタンがタップされた時のアクション
    public init(label: String = "削除", isEnabled: Bool = true, action: @escaping () -> Void) {
        self.label = label
        self.isEnabled = isEnabled
        self.action = action
    }

    public var body: some ToolbarContent {
        ToolbarItem(placement: .destructiveAction) {
            Button(role: .destructive, action: action) {
                Label(label, systemImage: "trash")
            }
            .disabled(!isEnabled)
            .help(label)
        }
    }
}

/// エクスポートボタンのツールバーアイテム
///
/// データをエクスポートするための標準的なツールバーボタン。
public struct ExportToolbarItem: ToolbarContent {
    /// ボタンのラベル
    private let label: String
    /// ボタンがタップされた時のアクション
    private let action: () -> Void

    /// ExportToolbarItemを初期化します
    /// - Parameters:
    ///   - label: ボタンのラベル（デフォルト: "エクスポート"）
    ///   - action: ボタンがタップされた時のアクション
    public init(label: String = "エクスポート", action: @escaping () -> Void) {
        self.label = label
        self.action = action
    }

    public var body: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Button(action: action) {
                Label(label, systemImage: "square.and.arrow.up")
            }
            .help(label)
        }
    }
}

/// フィルタボタンのツールバーアイテム
///
/// フィルタパネルの表示/非表示を切り替えるための標準的なツールバーボタン。
public struct FilterToolbarItem: ToolbarContent {
    /// ボタンのラベル
    private let label: String
    /// フィルタの表示状態
    @Binding private var isShowingFilter: Bool

    /// FilterToolbarItemを初期化します
    /// - Parameters:
    ///   - label: ボタンのラベル（デフォルト: "フィルタ"）
    ///   - isShowingFilter: フィルタの表示状態のBinding
    public init(label: String = "フィルタ", isShowingFilter: Binding<Bool>) {
        self.label = label
        self._isShowingFilter = isShowingFilter
    }

    public var body: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Button(
                action: { isShowingFilter.toggle() },
                label: {
                    Label(
                        label,
                        systemImage: isShowingFilter ? "line.3.horizontal.decrease.circle.fill" :
                            "line.3.horizontal.decrease.circle",
                    )
                },
            )
            .help(label)
        }
    }
}

/// リフレッシュボタンのツールバーアイテム
///
/// データを再読み込みするための標準的なツールバーボタン。
public struct RefreshToolbarItem: ToolbarContent {
    /// ボタンのラベル
    private let label: String
    /// ボタンがタップされた時のアクション
    private let action: () -> Void

    /// RefreshToolbarItemを初期化します
    /// - Parameters:
    ///   - label: ボタンのラベル（デフォルト: "更新"）
    ///   - action: ボタンがタップされた時のアクション
    public init(label: String = "更新", action: @escaping () -> Void) {
        self.label = label
        self.action = action
    }

    public var body: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Button(action: action) {
                Label(label, systemImage: "arrow.clockwise")
            }
            .help(label)
        }
    }
}

/// 検索フィールドのツールバーアイテム
///
/// 検索機能を提供するための標準的なツールバー検索フィールド。
public struct SearchToolbarItem: ToolbarContent {
    /// プレースホルダーテキスト
    private let placeholder: String
    /// 検索テキスト
    @Binding private var searchText: String

    /// SearchToolbarItemを初期化します
    /// - Parameters:
    ///   - placeholder: プレースホルダーテキスト（デフォルト: "検索"）
    ///   - searchText: 検索テキストのBinding
    public init(placeholder: String = "検索", searchText: Binding<String>) {
        self.placeholder = placeholder
        self._searchText = searchText
    }

    public var body: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            TextField(placeholder, text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
        }
    }
}

#if DEBUG
#Preview("Toolbar Items") {
    NavigationStack {
        VStack {
            Text("ツールバーアイテムのプレビュー")
                .font(.headline)
            Text("上部のツールバーを確認してください")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            AddToolbarItem {
                print("Add tapped")
            }

            DeleteToolbarItem(isEnabled: true) {
                print("Delete tapped")
            }

            ExportToolbarItem {
                print("Export tapped")
            }

            FilterToolbarItem(isShowingFilter: .constant(false))

            RefreshToolbarItem {
                print("Refresh tapped")
            }

            SearchToolbarItem(searchText: .constant(""))
        }
    }
    .frame(width: 800, height: 600)
}

#Preview("Toolbar with Filter Active") {
    NavigationStack {
        VStack {
            Text("フィルタ有効状態")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            FilterToolbarItem(isShowingFilter: .constant(true))
            SearchToolbarItem(searchText: .constant("サンプル検索"))
        }
    }
    .frame(width: 800, height: 600)
}

#Preview("Toolbar with Disabled Delete") {
    NavigationStack {
        VStack {
            Text("削除ボタン無効状態")
                .font(.headline)
            Text("アイテムが選択されていない場合")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            AddToolbarItem {
                print("Add tapped")
            }

            DeleteToolbarItem(isEnabled: false) {
                print("Delete tapped")
            }
        }
    }
    .frame(width: 800, height: 600)
}
#endif
