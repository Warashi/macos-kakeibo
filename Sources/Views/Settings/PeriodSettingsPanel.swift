import SwiftUI

/// 集計期間設定パネル
internal struct PeriodSettingsPanel: View {
    @Binding internal var monthStartDay: Int
    @Binding internal var monthStartDayAdjustment: BusinessDayAdjustment

    internal var body: some View {
        SettingsSectionCard(
            title: "集計期間",
            iconName: "calendar",
            description: "月次集計の開始日を変更します。",
            content: {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("月の開始日")
                            Spacer()
                            Picker("", selection: $monthStartDay) {
                                ForEach(1 ... 28, id: \.self) { day in
                                    Text("\(day)日").tag(day)
                                }
                            }
                            .frame(width: 100)
                        }
                        Text("ダッシュボードや予算の集計期間の開始日を設定します（1〜28日）")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("休日調整")
                            Spacer()
                            Picker("", selection: $monthStartDayAdjustment) {
                                ForEach(BusinessDayAdjustment.allCases, id: \.self) { adjustment in
                                    Text(adjustment.displayName).tag(adjustment)
                                }
                            }
                            .frame(width: 120)
                        }
                        Text("開始日が休日の場合の調整方法を設定します")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            },
        )
    }
}
