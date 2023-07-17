//
//  File.swift
//  
//
//  Created by Ryan Crosby on 7/15/23.
//

import Foundation

public struct SwiftFormatViolation: Decodable {
    public enum Severity: String, Decodable {
        case warning = "Warning"
        case error = "Error"
    }

    public internal(set) var file: String
    // Swift Format does not support severity, this can be overridden via passed in arguments
    public internal(set) var severity: Severity = .error
    public let line: Int
    public let reason: String
    public let ruleID: String

    enum CodingKeys: String, CodingKey {
        case file, line, reason
        case ruleID = "rule_id"
    }


    var messageText: String {
        reason + " (`\(ruleID)`)"
    }

    public func toMarkdown() -> String {
        let formattedFile = file.split(separator: "/").last.map { "\($0):\(line)" } ?? ""
        return "\(severity.rawValue) | \(formattedFile) | \(messageText) |"
    }
}

/*
 {
 "file" : "/Users/ryancrosby/development/file.swift",
 "line" : 116,
 "reason" : "Convert trivial map { $0.foo } closures to keyPath-based syntax.",
 "rule_id" : "preferKeyPath"
 },
 */
