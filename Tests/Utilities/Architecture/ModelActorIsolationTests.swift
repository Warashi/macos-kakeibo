import Foundation
@testable import Kakeibo
import Testing

@Suite("ModelActor Isolation", .serialized)
internal struct ModelActorIsolationTests {
    private static let projectRoot: URL = {
        var url = URL(fileURLWithPath: #filePath)
        // .../Tests/Utilities/Architecture/ModelActorIsolationTests.swift -> project root
        for _ in 0 ..< 4 {
            url.deleteLastPathComponent()
        }
        return url
    }()

    private let domainDirectory: URL = ModelActorIsolationTests.projectRoot.appendingPathComponent("Sources/Domain")
    private let useCaseDirectory: URL = ModelActorIsolationTests.projectRoot.appendingPathComponent("Sources/UseCases")

    @Test("Domain 層は SwiftData を import しない")
    internal func domainFilesDoNotImportSwiftData() throws {
        try assertFiles(in: domainDirectory, doNotContain: "import SwiftData")
    }

    @Test("Domain 層は ModelContext を参照しない")
    internal func domainFilesDoNotReferenceModelContext() throws {
        try assertFiles(in: domainDirectory, doNotContain: "ModelContext")
    }

    @Test("UseCase 層は SwiftData を import しない")
    internal func useCaseFilesDoNotImportSwiftData() throws {
        try assertFiles(in: useCaseDirectory, doNotContain: "import SwiftData")
    }

    @Test("UseCase 層は ModelContext を参照しない")
    internal func useCaseFilesDoNotReferenceModelContext() throws {
        try assertFiles(in: useCaseDirectory, doNotContain: "ModelContext")
    }
}

private extension ModelActorIsolationTests {
    private func assertFiles(in directory: URL, doNotContain disallowedToken: String) throws {
        let swiftFiles = try Self.collectSwiftFiles(in: directory)
        for fileURL in swiftFiles {
            let content = try String(contentsOf: fileURL)
            #expect(
                content.contains(disallowedToken) == false,
                "\(fileURL.path) で \"\(disallowedToken)\" が使われています。",
            )
        }
    }

    private static func collectSwiftFiles(in directory: URL) throws -> [URL] {
        var files: [URL] = []
        let enumerator: FileManager.DirectoryEnumerator? = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
        )
        while let element = enumerator?.nextObject() as? URL {
            let resourceValues = try element.resourceValues(forKeys: [.isDirectoryKey])
            if resourceValues.isDirectory == true {
                continue
            }
            if element.pathExtension == "swift" {
                files.append(element)
            }
        }
        return files
    }
}
