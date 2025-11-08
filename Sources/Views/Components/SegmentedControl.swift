import SwiftUI

/// セグメント化されたコントロールコンポーネント
///
/// 複数の選択肢から1つを選択するためのUIコンポーネント。
/// SwiftUIのPickerをベースにしたmacOSネイティブなセグメンテッドコントロール。
public struct SegmentedControl<SelectionValue: Hashable>: View {
    /// 選択された値
    @Binding private var selection: SelectionValue
    /// セグメントのオプション
    private let options: [SegmentOption<SelectionValue>]
    /// セグメントのスタイル
    private let pickerStyle: PickerStyle

    /// セグメントのオプション
    public struct SegmentOption<Value: Hashable>: Identifiable {
        /// オプションのID
        public let id: Value
        /// オプションのラベル
        public let label: String
        /// オプションのアイコン（オプション）
        public let icon: String?

        /// SegmentOptionを初期化します
        /// - Parameters:
        ///   - value: オプションの値
        ///   - label: オプションのラベル
        ///   - icon: オプションのアイコン（SF Symbolsの名前）
        public init(value: Value, label: String, icon: String? = nil) {
            self.id = value
            self.label = label
            self.icon = icon
        }
    }

    /// SegmentedControlを初期化します
    /// - Parameters:
    ///   - selection: 選択された値のBinding
    ///   - options: セグメントのオプション配列
    ///   - pickerStyle: Pickerのスタイル（デフォルト: .segmented）
    public init(
        selection: Binding<SelectionValue>,
        options: [SegmentOption<SelectionValue>],
        pickerStyle: PickerStyle = .segmented,
    ) {
        self._selection = selection
        self.options = options
        self.pickerStyle = pickerStyle
    }

    /// 便利なイニシャライザ（値とラベルのタプル配列から生成）
    /// - Parameters:
    ///   - selection: 選択された値のBinding
    ///   - items: (値, ラベル)のタプル配列
    ///   - pickerStyle: Pickerのスタイル（デフォルト: .segmented）
    public init(
        selection: Binding<SelectionValue>,
        items: [(SelectionValue, String)],
        pickerStyle: PickerStyle = .segmented,
    ) {
        self._selection = selection
        self.options = items.map { SegmentOption(value: $0.0, label: $0.1) }
        self.pickerStyle = pickerStyle
    }

    public var body: some View {
        Picker("", selection: $selection) {
            ForEach(options) { option in
                if let icon: String = option.icon {
                    Label(option.label, systemImage: icon)
                        .tag(option.id)
                } else {
                    Text(option.label)
                        .tag(option.id)
                }
            }
        }
        .pickerStyle(pickerStyle)
        .labelsHidden()
    }
}

#if DEBUG
private enum Period: String, CaseIterable {
    case day = "日"
    case week = "週"
    case month = "月"
    case year = "年"
}

private enum TransactionType: String, CaseIterable {
    case all = "すべて"
    case income = "収入"
    case expense = "支出"
}

#Preview("Segmented Control - Period") {
    VStack(spacing: 20) {
        Text("期間選択")
            .font(.headline)

        SegmentedControl(
            selection: .constant(Period.month),
            items: Period.allCases.map { ($0, $0.rawValue) },
        )
        .frame(width: 300)
    }
    .padding()
}

#Preview("Segmented Control - Transaction Type") {
    VStack(spacing: 20) {
        Text("取引種別")
            .font(.headline)

        SegmentedControl(
            selection: .constant(TransactionType.all),
            items: TransactionType.allCases.map { ($0, $0.rawValue) },
        )
        .frame(width: 300)
    }
    .padding()
}

#Preview("Segmented Control - With Icons") {
    VStack(spacing: 20) {
        Text("アイコン付きセグメント")
            .font(.headline)

        SegmentedControl(
            selection: .constant(TransactionType.expense),
            options: [
                .init(value: .all, label: "すべて", icon: "list.bullet"),
                .init(value: .income, label: "収入", icon: "arrow.down.circle"),
                .init(value: .expense, label: "支出", icon: "arrow.up.circle"),
            ],
        )
        .frame(width: 400)
    }
    .padding()
}
#endif
