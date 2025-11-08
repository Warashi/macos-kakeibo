import Foundation

internal struct SpecialPaymentScheduleService {
    /// 既定のスケジュール生成期間（月単位）
    internal static let defaultHorizonMonths: Int = 36

    /// 生成対象となるOccurrenceの情報
    internal struct ScheduleTarget: Equatable {
        internal let scheduledDate: Date
        internal let expectedAmount: Decimal
    }

    private let calendar: Calendar = Calendar(identifier: .gregorian)
    private let maxIterations: Int = 600

    /// 定義に基づき、指定した開始日から将来のOccurrence候補を生成する
    /// - Parameters:
    ///   - definition: 特別支払い定義
    ///   - seedDate: 計算開始基準日（通常は初回発生日か、最新実績の次回予定日）
    ///   - referenceDate: 判定基準となる日付（通常は「今日」）
    ///   - horizonMonths: 参照日から先の生成期間（月数）
    /// - Returns: 作成対象のOccurrence
    internal func scheduleTargets(
        for definition: SpecialPaymentDefinition,
        seedDate: Date,
        referenceDate: Date,
        horizonMonths: Int,
    ) -> [ScheduleTarget] {
        guard definition.recurrenceIntervalMonths > 0 else {
            return []
        }

        let safeSeed = max(seedDate, definition.firstOccurrenceDate)
        let safeHorizon = max(0, horizonMonths)
        let referenceStart = referenceDate.startOfMonth

        var currentDate = safeSeed
        var iterationCount = 0

        while currentDate < referenceStart, iterationCount < maxIterations {
            guard let next = advance(date: currentDate, months: definition.recurrenceIntervalMonths) else {
                break
            }
            currentDate = next
            iterationCount += 1
        }

        let horizonEnd = calendar.date(byAdding: .month, value: safeHorizon, to: referenceStart) ?? referenceStart
        let endBoundary = max(horizonEnd, currentDate)

        var targets: [ScheduleTarget] = []
        var generationDate = currentDate
        var generationIteration = iterationCount

        while generationDate <= endBoundary, generationIteration < maxIterations {
            targets.append(
                ScheduleTarget(
                    scheduledDate: generationDate,
                    expectedAmount: definition.amount,
                ),
            )

            guard let next = advance(
                date: generationDate,
                months: definition.recurrenceIntervalMonths,
            ) else {
                break
            }

            generationDate = next
            generationIteration += 1
        }

        if targets.isEmpty {
            targets.append(
                ScheduleTarget(
                    scheduledDate: currentDate,
                    expectedAmount: definition.amount,
                ),
            )
        }

        return targets
    }

    /// リードタイムと参照日に応じたデフォルトステータス
    /// - Parameters:
    ///   - scheduledDate: 予定日
    ///   - referenceDate: 判定基準日
    ///   - leadTimeMonths: リードタイム（月数）
    /// - Returns: 予定/積立ステータス
    internal func defaultStatus(
        for scheduledDate: Date,
        referenceDate: Date,
        leadTimeMonths: Int,
    ) -> SpecialPaymentStatus {
        let normalizedReference = referenceDate.startOfMonth
        let normalizedScheduled = scheduledDate.startOfMonth

        if normalizedScheduled <= normalizedReference {
            return .saving
        }

        let clampedLeadTime = max(0, leadTimeMonths)
        let monthsUntil = calendar.dateComponents(
            [.month],
            from: normalizedReference,
            to: normalizedScheduled,
        ).month ?? 0

        return monthsUntil <= clampedLeadTime ? .saving : .planned
    }

    private func advance(date: Date, months: Int) -> Date? {
        calendar.date(byAdding: .month, value: months, to: date)
    }
}
