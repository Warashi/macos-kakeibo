import Foundation

internal extension Int {
    /// 年表示用に桁区切りなしでフォーマットした文字列を返す
    var yearDisplayString: String {
        formatted(.number.grouping(.never))
    }
}
