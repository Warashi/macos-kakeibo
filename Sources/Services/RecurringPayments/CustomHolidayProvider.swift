import Foundation

/// ユーザー定義祝日を提供するプロバイダー
internal struct CustomHolidayProvider: HolidayProvider {
    private let repository: CustomHolidayRepository

    internal init(repository: CustomHolidayRepository) {
        self.repository = repository
    }

    internal func holidays(for year: Int) -> Set<Date> {
        // HolidayProvider は同期APIだが、Repository は非同期
        // 注: この実装は一時的なもので、将来的にHolidayProviderを非同期に変更すべき
        // 同期的に待機する
        return withUnsafeCurrentTask { task in
            guard task == nil else {
                // すでにTask内にいる場合は、デッドロックを避けるために空を返す
                return []
            }

            let semaphore = DispatchSemaphore(value: 0)
            var result: Set<Date> = []

            Task {
                let holidays = try? await repository.holidays(for: year)
                result = holidays ?? []
                semaphore.signal()
            }

            semaphore.wait()
            return result
        }
    }
}
