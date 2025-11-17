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

    private let domainDirectory = ModelActorIsolationTests.projectRoot.appendingPathComponent("Sources/Domain")
    private let useCaseDirectory = ModelActorIsolationTests.projectRoot.appendingPathComponent("Sources/UseCases")

    @Test("Domain 層は SwiftData を import しない")
    func domainFilesDoNotImportSwiftData() throws {
        try assertFiles(in: domainDirectory, doNotContain: "import SwiftData")
    }

    @Test("Domain 層は ModelContext を参照しない")
    func domainFilesDoNotReferenceModelContext() throws {
        try assertFiles(in: domainDirectory, doNotContain: "ModelContext")
    }

    @Test("UseCase 層は SwiftData を import しない")
    func useCaseFilesDoNotImportSwiftData() throws {
        try assertFiles(in: useCaseDirectory, doNotContain: "import SwiftData")
    }

    @Test("UseCase 層は ModelContext を参照しない")
    func useCaseFilesDoNotReferenceModelContext() throws {
        try assertFiles(in: useCaseDirectory, doNotContain: "ModelContext")
    }
}

private extension ModelActorIsolationTests {
    func assertFiles(in directory: URL, doNotContain disallowedToken: String) throws {
        let swiftFiles = try Self.collectSwiftFiles(in: directory)
        for fileURL in swiftFiles {
            let content = try String(contentsOf: fileURL)
            #expect(
                content.contains(disallowedToken) == false,
                "\(fileURL.path) で \"\(disallowedToken)\" が使われています。"
            )
        }
    }

    static func collectSwiftFiles(in directory: URL) throws -> [URL] {
        var files: [URL] = []
        let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isDirectoryKey])
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
