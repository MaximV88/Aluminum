//
//  Path+VisualFormat.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 10/03/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Foundation


private extension Path {
    private static let argumentPattern = "[[:alpha:]]+"
    private static let indexPattern = "[[\\d]+]"
    private static let regex = try! NSRegularExpression(pattern: "(?<argument>\(argumentPattern))|(?<index>\(indexPattern))")
}

public extension Path {
    static func path(withVisualFormat format: String) -> Path {
        let matches = regex.matches(in: format, options: [], range: NSRange(0 ..< format.count))
        
        return matches.compactMap {
            let argumentRange = $0.range(withName: "argument")
            let indexRange = $0.range(withName: "index")

            if let argument = format.substring(with: argumentRange) {
                return .argument(argument)
            } else if let rawIndex = format.substring(with: indexRange) {
                return .index(UInt(rawIndex)!) // regex gurantees conversion
            } else {
                return nil
            }
        }
    }
}

