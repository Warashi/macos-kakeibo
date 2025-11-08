import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// 任意のDataをFileDocumentとして扱うためのユーティリティ
internal struct DataFileDocument: FileDocument {
    internal static let readableContentTypes: [UTType] = [
        .json,
        .commaSeparatedText,
        .data,
    ]

    internal var data: Data

    internal init(data: Data = Data()) {
        self.data = data
    }

    internal init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    internal func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
