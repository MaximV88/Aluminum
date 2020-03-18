//
//  Path+VisualFormat.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 10/03/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal


private extension Path {
    private static let argumentPattern = "[[:alpha:]]+"
    private static let indexPattern = "[[\\d]+]"
    private static let regex = try! NSRegularExpression(pattern: "(?<argument>\(argumentPattern))|(?<index>\(indexPattern))")
}

private extension Path {
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

public extension ComputePipelineStateEncoder {
    func encode(_ buffer: MTLBuffer, to path: String) throws  {
        try encode(buffer, to: Path.path(withVisualFormat: path))
    }

    func encode<T>(_ parameter: T, to path: String) throws {
            try encode(parameter, to: Path.path(withVisualFormat: path))
    }
}

public extension ComputePipelineStateEncoder {
    func encode(_ bytes: UnsafeRawPointer, count: Int, to path: String) throws {
        try encode(bytes, count: count, to: Path.path(withVisualFormat: path))
    }

    func encode(_ buffer: MTLBuffer, offset: Int, to path: String) throws {
        try encode(buffer, offset: offset, to: Path.path(withVisualFormat: path))
    }

    func childEncoder(for path: String) throws -> ComputePipelineStateEncoder {
        try childEncoder(for: Path.path(withVisualFormat: path))
    }
}
