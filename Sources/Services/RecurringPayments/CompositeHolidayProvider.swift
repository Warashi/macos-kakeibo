import Foundation

/// 複数の祝日プロバイダーを組み合わせるプロバイダー
internal struct CompositeHolidayProvider: HolidayProvider {
    private let providers: [HolidayProvider]

    internal init(providers: [HolidayProvider]) {
        self.providers = providers
    }

    internal func holidays(for year: Int) -> Set<Date> {
        var allHolidays = Set<Date>()

        for provider in providers {
            allHolidays.formUnion(provider.holidays(for: year))
        }

        return allHolidays
    }
}
