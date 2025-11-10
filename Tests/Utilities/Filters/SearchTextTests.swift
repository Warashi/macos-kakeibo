import Foundation
import Testing

@testable import Kakeibo

@Suite
internal struct SearchTextTests {
    @Test("comparisonValue はトリミング・小文字化される")
    internal func comparisonValueIsNormalized() {
        let search = SearchText("  Hello World  ")
        #expect(search.trimmedValue == "Hello World")
        #expect(search.normalizedValue == "Hello World")
        #expect(search.comparisonValue == "hello world")
    }

    @Test("matches はキーワード未入力の場合に常に true")
    internal func matchesAlwaysTrueWhenEmpty() {
        let search = SearchText("   ")
        #expect(search.matches(haystack: "anything"))
        #expect(search.matchesAny(haystacks: []))
    }

    @Test("matchesAny は配列内のいずれかに部分一致するか判定する")
    internal func matchesAnyChecksLowercasedHaystacks() {
        let search = SearchText("自動車")
        #expect(search.matchesAny(haystacks: ["家賃", "自動車税", "電気代"]))
        #expect(!search.matchesAny(haystacks: ["食費", "通信費"]))
    }
}
