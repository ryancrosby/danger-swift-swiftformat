//
//  File.swift
//  
//
//  Created by Ryan Crosby on 7/17/23.
//

import Foundation
@testable import DangerSwiftFormat

final class FakeCurrentPathProvider: CurrentPathProvider {
    var currentPath: String = ""
}
