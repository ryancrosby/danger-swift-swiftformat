import Danger
import DangerShellExecutor
import Foundation

public enum SwiftFormat {
    public enum FormatStyle {
        /// Lints all the files instead of only the modified and created files.
        /// - Parameters:
        ///   - directory: Optional property to set the --path to execute at.
        case all(directory: String?)

        /// Only lints the modified and created files with `.swift` extension.
        /// - Parameters:
        ///   - directory: Optional property to set the --path to execute at.
        case modifiedAndCreatedFiles(directory: String?)

        /// Lints only the given files. This can be useful to do some manual filtering.
        /// The files will be filtered on `.swift` only.
        case files([File])
    }

    public enum SwiftformatPath {
        case swiftPackage(String)
        case bin(String)

        var command: String {
            switch self {
            case let .swiftPackage(path):
                return "swift run --package-path \(path) swiftformat"
            case let .bin(path):
                return path
            }
        }
    }

    static let danger = Danger()
    static let shellExecutor = ShellExecutor()

    @discardableResult
    public static func format(
        _ formatStyle: FormatStyle = .all(directory: nil),
        inline: Bool = false,
        configFile: String? = nil,
        quiet: Bool = true,
        swiftformatPath: String? = nil
    ) -> [SwiftFormatViolation] {
        format(
            formatStyle: formatStyle,
            danger: danger,
            shellExecutor: shellExecutor,
            swiftformatPath: swiftformatPath.map(SwiftformatPath.bin),
            inline: inline,
            configFile: configFile,
            quiet: quiet
        )
    }
}

extension SwiftFormat {
    static func format(
        formatStyle: FormatStyle = .all(directory: nil),
        danger: DangerDSL,
        shellExecutor: ShellExecuting,
        swiftformatPath: SwiftformatPath?,
        inline: Bool = false,
        configFile: String? = nil,
        severity: SwiftFormatViolation.Severity = .error,
        quiet: Bool = true,
        currentPathProvider: CurrentPathProvider = DefaultCurrentPathProvider(),
        outputFilePath: String = tmpSwiftlintOutputFilePath,
        reportDeleter: SwiftFormatReportDeleting = SwiftFormatReportDeleter(),
        markdownAction: (String) -> Void = markdown,
        failAction: (String) -> Void = fail,
        failInlineAction: (String, String, Int) -> Void = fail,
        warnInlineAction: (String, String, Int) -> Void = warn,
        readFile: (String) -> String = danger.utils.readFile
    ) -> [SwiftFormatViolation] {
        var arguments = ["--lint", "--lenient", "--reporter json"]

        if quiet {
            arguments.append("--quiet")
        }

        if let configFile {
            arguments.append("--config \"\(configFile)\"")
        }

        defer {
            try? reportDeleter.deleteReport(atPath: outputFilePath)
        }

        var violations: [SwiftFormatViolation]
        let swiftformatPath = swiftformatPath?.command ?? SwiftFormat.swiftformatDefaultPath()

        switch formatStyle {
        case let .all(directory):
            violations = lintAll(
                directory: directory,
                arguments: arguments,
                shellExecutor: shellExecutor,
                swiftformatPath: swiftformatPath,
                outputFilePath: outputFilePath,
                failAction: failAction,
                readFile: readFile
            )
        case let .modifiedAndCreatedFiles(directory):
            // Gathers modified+created files, invokes SwiftLint on each, and posts collected errors+warnings to Danger.
            var files = (danger.git.createdFiles + danger.git.modifiedFiles)
            if let directory = directory {
                files = files.filter { $0.hasPrefix(directory) }
            }

            violations = lintFiles(files,
                                   danger: danger,
                                   arguments: arguments,
                                   shellExecutor: shellExecutor,
                                   swiftformatPath: swiftformatPath,
                                   outputFilePath: outputFilePath,
                                   failAction: failAction,
                                   readFile: readFile)

        case let .files(files):
            violations = lintFiles(files,
                                   danger: danger,
                                   arguments: arguments,
                                   shellExecutor: shellExecutor,
                                   swiftformatPath: swiftformatPath,
                                   outputFilePath: outputFilePath,
                                   failAction: failAction,
                                   readFile: readFile)

        }

        guard !violations.isEmpty else {
            return []
        }

        violations = violations.updatingForCurrentPathProvider(currentPathProvider, severity: severity)
        handleViolations(
            violations,
            inline: inline,
            markdownAction: markdownAction,
            failInlineAction: failInlineAction,
            warnInlineAction: warnInlineAction
        )

        return violations
    }

    private static func lintAll(
        directory: String?,
        arguments: [String],
        shellExecutor: ShellExecuting,
        swiftformatPath: String,
        outputFilePath: String,
        failAction: (String) -> Void,
        readFile: (String) -> String
    ) -> [SwiftFormatViolation] {
        var arguments = arguments

        if let directory = directory {
            arguments.append("--path \"\(directory)\"")
        } else {
            arguments.append(".")
        }

        return swiftformatViolations(
            swiftformatPath: swiftformatPath,
            arguments: arguments,
            environmentVariables: [:],
            outputFilePath: outputFilePath,
            shellExecutor: shellExecutor,
            failAction: failAction,
            readFile: readFile
        )
    }

    // swiftlint:disable function_parameter_count
    private static func lintFiles(
        _ files: [File],
        danger _: DangerDSL,
        arguments: [String],
        shellExecutor: ShellExecuting,
        swiftformatPath: String,
        outputFilePath: String,
        failAction: (String) -> Void,
        readFile: (String) -> String
    ) -> [SwiftFormatViolation] {
        let files = files.filter { $0.fileType == .swift }

        // Only run Swiftlint, if there are files to lint
        guard !files.isEmpty else {
            return []
        }

        var arguments = arguments
        arguments.append("--scriptinput")

        // swiftlint takes input files via environment variables
        var inputFiles = ["SCRIPT_INPUT_FILE_COUNT": "\(files.count)"]
        for (index, file) in files.enumerated() {
            inputFiles["SCRIPT_INPUT_FILE_\(index)"] = file
        }

        return swiftformatViolations(
            swiftformatPath: swiftformatPath,
            arguments: arguments,
            environmentVariables: inputFiles,
            outputFilePath: outputFilePath,
            shellExecutor: shellExecutor,
            failAction: failAction,
            readFile: readFile
        )
    }

    private static func swiftformatViolations(
        swiftformatPath: String,
        arguments: [String],
        environmentVariables: [String: String],
        outputFilePath: String,
        shellExecutor: ShellExecuting,
        failAction: (String) -> Void,
        readFile: (String) -> String
    ) -> [SwiftFormatViolation] {
        shellExecutor.execute(
            swiftformatPath,
            arguments: arguments,
            environmentVariables: environmentVariables,
            outputFile: outputFilePath
        )

        let outputJSON = readFile(outputFilePath)
        return makeViolations(from: outputJSON, failAction: failAction)
    }

    private static func makeViolations(from response: String, failAction: (String) -> Void) -> [SwiftFormatViolation] {
        let decoder = JSONDecoder()
        do {
            let violations = try decoder.decode([SwiftFormatViolation].self, from: Data(response.utf8))
            return violations
        } catch {
            failAction("Error deserializing SwiftLint JSON response (\(response)): \(error)")
            return []
        }
    }

    static func swiftformatDefaultPath(packagePath: String = "Package.swift") -> String {
        let swiftPackageDepPattern = #"\.package\(.*SwiftFormat.*"#
        if let packageContent = try? String(contentsOfFile: packagePath),
           let regex = try? NSRegularExpression(pattern: swiftPackageDepPattern, options: .allowCommentsAndWhitespace),
           regex.firstMatchingString(in: packageContent) != nil
        {
            return "swift run swiftformat"
        } else {
            return "swiftformat"
        }
    }

    /// Prints out the violation either inline or in Markdown.
    private static func handleViolations(
        _ violations: [SwiftFormatViolation],
        inline: Bool,
        markdownAction: (String) -> Void,
        failInlineAction: (String, String, Int) -> Void,
        warnInlineAction: (String, String, Int) -> Void
    ) {
        if inline {
            violations.forEach { violation in
                switch violation.severity {
                case .error:
                    failInlineAction(violation.messageText, violation.file, violation.line)
                case .warning:
                    warnInlineAction(violation.messageText, violation.file, violation.line)
                }
            }
        } else {
            var markdownMessage = """
            ### SwiftFormat found issues

            | Severity | File | Reason |
            | -------- | ---- | ------ |\n
            """
            markdownMessage += violations.map { $0.toMarkdown() }.joined(separator: "\n")
            markdownAction(markdownMessage)
        }
    }

    private static var tmpSwiftlintOutputFilePath: String {
        if #available(OSX 10.12, *) {
            return FileManager.default.temporaryDirectory.appendingPathComponent("swiftlintReport.json").path
        } else {
            return NSTemporaryDirectory() + "swiftlintReport.json"
        }
    }
}

private extension Array where Element == SwiftFormatViolation {
    func updatingForCurrentPathProvider(_ currentPathProvider: CurrentPathProvider, severity: SwiftFormatViolation.Severity) -> [Element] {
        let currentPath = currentPathProvider.currentPath
        return map { violation -> SwiftFormatViolation in
            var violation = violation

            let updatedPath = violation.file.deletingPrefix(currentPath).deletingPrefix("/")
            violation.file = updatedPath
            violation.severity = severity
            return violation
        }
    }
}

private extension StringProtocol {
    func deletingPrefix(_ prefix: String) -> String {
        guard hasPrefix(prefix) else { return String(self) }
        return String(dropFirst(prefix.count))
    }
}
