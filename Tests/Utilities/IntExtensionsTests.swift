import Testing

@testable import Kakeibo

@Suite("Int拡張のテスト")
internal struct IntExtensionsTests {
    @Test("yearDisplayStringは桁区切りを含まない")
    internal func yearDisplayString_removesGroupingSeparators() throws {
        #expect(2025.yearDisplayString == "2025")
        #expect(1_234_567.yearDisplayString == "1234567")
    }
}
