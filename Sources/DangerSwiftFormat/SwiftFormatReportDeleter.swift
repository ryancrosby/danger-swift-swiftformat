import Foundation

protocol SwiftFormatReportDeleting {
    func deleteReport(atPath path: String) throws
}

struct SwiftFormatReportDeleter: SwiftFormatReportDeleting {
    let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func deleteReport(atPath path: String) throws {
        try fileManager.removeItem(atPath: path)
    }
}
