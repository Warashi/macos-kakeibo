import Foundation
import Observation

@MainActor
@Observable
internal final class AppState {
    internal enum Screen: String, CaseIterable, Identifiable, Hashable {
        case dashboard
        case transactions
        case budgets
        case savingsGoals
        case imports
        case settings

        internal var id: Self { self }

        internal var displayName: String {
            switch self {
            case .dashboard:
                "ダッシュボード"
            case .transactions:
                "取引"
            case .budgets:
                "予算"
            case .savingsGoals:
                "貯蓄目標"
            case .imports:
                "インポート"
            case .settings:
                "設定"
            }
        }

        internal var symbolName: String {
            switch self {
            case .dashboard:
                "chart.pie.fill"
            case .transactions:
                "list.bullet.rectangle"
            case .budgets:
                "creditcard"
            case .savingsGoals:
                "banknote.fill"
            case .imports:
                "tray.and.arrow.down"
            case .settings:
                "gearshape"
            }
        }

        internal var description: String {
            switch self {
            case .dashboard:
                "家計簿の全体状況を確認できます。"
            case .transactions:
                "収支の一覧を閲覧・管理する画面です。"
            case .budgets:
                "予算の設定や進捗を管理します。"
            case .savingsGoals:
                "貯蓄目標を管理します。"
            case .imports:
                "CSVなどからデータを取り込みます。"
            case .settings:
                "アプリの各種設定を調整します。"
            }
        }
    }

    internal var selectedScreen: Screen?

    // 画面間で共有される年月の状態
    internal var sharedYear: Int
    internal var sharedMonth: Int

    internal init(selectedScreen: Screen = .dashboard) {
        self.selectedScreen = selectedScreen

        // 現在の年月で初期化
        let now = Date()
        let calendar = Calendar.current
        self.sharedYear = calendar.component(.year, from: now)
        self.sharedMonth = calendar.component(.month, from: now)
    }
}
