import Danger
@testable import DangerFixtures
@testable import DangerSwiftFormat
import XCTest

final class DangerSwiftFormatTests: XCTestCase {
    var executor: FakeShellExecutor!
    var fakePathProvider: FakeCurrentPathProvider!
    var danger: DangerDSL!

    override func setUp() {
        super.setUp()
        executor = FakeShellExecutor()
        fakePathProvider = FakeCurrentPathProvider()
        danger = githubFixtureDSL
    }

    override func tearDown() {
        super.tearDown()
        executor = nil
        fakePathProvider = nil
        danger = nil
    }

    func testExecutesTheShell() {
        _ = SwiftFormat.format(
            danger: danger,
            shellExecutor: executor,
            swiftformatPath: .bin("swiftformat"),
            currentPathProvider: fakePathProvider,
            outputFilePath: "swiftformatReport.json",
            readFile: mockedEmptyJSON
        )

        XCTAssertEqual(executor.invocations.count, 1)
        XCTAssertEqual(executor.invocations.first?.command, "swiftformat")
    }

    func testExecutesTheShellWithCustomSwiftformatPath() {
        _ = SwiftFormat.format(danger: danger,
                               shellExecutor: executor,
                               swiftformatPath: .bin("Pods/SwiftFormat/CommandLineTool/swiftformat"),
                               currentPathProvider: fakePathProvider,
                               outputFilePath: "swiftformatReport.json",
                               readFile: mockedEmptyJSON)

        XCTAssertEqual(executor.invocations.count, 1)
        XCTAssertEqual(executor.invocations.first?.command, "Pods/SwiftFormat/CommandLineTool/swiftformat")
    }

    func testDoNotExecuteSwiftformatWhenNoFilesToCheck() {
        let modified = [
            "CHANGELOG.md",
            "Harvey/SomeOtherFile.m",
            "circle.yml",
        ]

        danger = githubWithFilesDSL(created: [], modified: modified, deleted: [], fileMap: [:])

        _ = SwiftFormat.format(
            danger: danger,
            shellExecutor: executor,
            swiftformatPath: .bin("swiftformat"),
            currentPathProvider: fakePathProvider,
            outputFilePath: "swiftformatReport.json",
            readFile: mockedEmptyJSON
        )

        XCTAssertEqual(executor.invocations.count, 0, "If there are no files to lint, SwiftFormat should not be executed")
    }
}
