@testable import DangerSwiftFormat
import Foundation

final class FakeCurrentPathProvider: CurrentPathProvider {
    var currentPath: String = ""
}
