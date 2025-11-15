import Foundation
import Testing

@testable import Kakeibo

@Suite("BusinessDayService - Nth Day")
internal struct BusinessDayServiceNthDayTests {
    private let calendar: Calendar = Calendar(identifier: .gregorian)
    private let service: BusinessDayService = BusinessDayService()

    // MARK: - nthBusinessDay Tests

    @Test("1番目の営業日")
    internal func nthBusinessDay_first() throws {
        // 2025-01-01は水曜日
        let first = try #require(service.nthBusinessDay(1, of: 2025, month: 1))
        let expected = try #require(Date.from(year: 2025, month: 1, day: 1))
        #expect(calendar.isDate(first, inSameDayAs: expected))
    }

    @Test("5番目の営業日")
    internal func nthBusinessDay_fifth() throws {
        // 2025-01: 1(水), 2(木), 3(金), 6(月), 7(火) = 5営業日目
        let fifth = try #require(service.nthBusinessDay(5, of: 2025, month: 1))
        let expected = try #require(Date.from(year: 2025, month: 1, day: 7))
        #expect(calendar.isDate(fifth, inSameDayAs: expected))
    }

    @Test("10番目の営業日")
    internal func nthBusinessDay_tenth() throws {
        // 2025-01: 1-3(3日), 6-10(5日), 13-14(2日) = 10営業日目
        let tenth = try #require(service.nthBusinessDay(10, of: 2025, month: 1))
        let expected = try #require(Date.from(year: 2025, month: 1, day: 14))
        #expect(calendar.isDate(tenth, inSameDayAs: expected))
    }

    @Test("月初が週末の場合のN番目の営業日")
    internal func nthBusinessDay_startsOnWeekend() throws {
        // 2025-02-01は土曜日、3(月)が1営業日目、4(火)が2営業日目
        let second = try #require(service.nthBusinessDay(2, of: 2025, month: 2))
        let expected = try #require(Date.from(year: 2025, month: 2, day: 4))
        #expect(calendar.isDate(second, inSameDayAs: expected))
    }

    @Test("存在しないN番目の営業日はnil")
    internal func nthBusinessDay_tooLarge() throws {
        // 1ヶ月に100営業日はない
        let result = service.nthBusinessDay(100, of: 2025, month: 1)
        #expect(result == nil)
    }

    @Test("0番目の営業日はnil")
    internal func nthBusinessDay_zero() throws {
        let result = service.nthBusinessDay(0, of: 2025, month: 1)
        #expect(result == nil)
    }

    @Test("負の番号の営業日はnil")
    internal func nthBusinessDay_negative() throws {
        let result = service.nthBusinessDay(-1, of: 2025, month: 1)
        #expect(result == nil)
    }

    // MARK: - lastBusinessDayMinus Tests

    @Test("最終営業日の0営業日前は最終営業日")
    internal func lastBusinessDayMinus_zero() throws {
        // 2025-01-31は金曜日
        let result = try #require(service.lastBusinessDayMinus(days: 0, of: 2025, month: 1))
        let expected = try #require(Date.from(year: 2025, month: 1, day: 31))
        #expect(calendar.isDate(result, inSameDayAs: expected))
    }

    @Test("最終営業日の1営業日前")
    internal func lastBusinessDayMinus_one() throws {
        // 2025-01-31は金曜日、30は木曜日
        let result = try #require(service.lastBusinessDayMinus(days: 1, of: 2025, month: 1))
        let expected = try #require(Date.from(year: 2025, month: 1, day: 30))
        #expect(calendar.isDate(result, inSameDayAs: expected))
    }

    @Test("最終営業日の3営業日前")
    internal func lastBusinessDayMinus_three() throws {
        // 2025-01-31(金), 30(木), 29(水), 28(火) = 3営業日前
        let result = try #require(service.lastBusinessDayMinus(days: 3, of: 2025, month: 1))
        let expected = try #require(Date.from(year: 2025, month: 1, day: 28))
        #expect(calendar.isDate(result, inSameDayAs: expected))
    }

    @Test("月末が週末の場合の最終営業日前N営業日")
    internal func lastBusinessDayMinus_endsOnWeekend() throws {
        // 2025-08-31は日曜日、最終営業日は29(金)、2営業日前は27(水)
        let result = try #require(service.lastBusinessDayMinus(days: 2, of: 2025, month: 8))
        let expected = try #require(Date.from(year: 2025, month: 8, day: 27))
        #expect(calendar.isDate(result, inSameDayAs: expected))
    }

    @Test("負の営業日数はnil")
    internal func lastBusinessDayMinus_negative() throws {
        let result = service.lastBusinessDayMinus(days: -1, of: 2025, month: 1)
        #expect(result == nil)
    }
}
