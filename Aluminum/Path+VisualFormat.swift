//
//  Path+VisualFormat.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 10/03/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal


private extension Path {
    private static let argumentPattern = "[a-zA-Z0-9_]+"
    private static let indexPattern = "\\[[\\d]+\\]"
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
                return .index(UInt(rawIndex.substring(with: NSMakeRange(1, rawIndex.count - 2))!)!) // ignore '[', ']'
            } else {
                return nil
            }
        }
    }
}

// MARK: - VisualPath support extension

public extension BytesEncoder {
    func encode<T>(_ parameter: T, to path: String) {
        encode(parameter, to: Path.path(withVisualFormat: path))
    }

    func encode(_ bytes: UnsafeRawPointer, count: Int, to path: String) {
        encode(bytes, count: count, to: Path.path(withVisualFormat: path))
    }
}

public extension ResourceEncoder {
    func encode(_ buffer: MTLBuffer, to path: String) {
        encode(buffer, to: Path.path(withVisualFormat: path))
    }
    
    func encode(_ buffer: MTLBuffer, offset: Int, to path: String) {
        encode(buffer, offset: offset, to: Path.path(withVisualFormat: path))
    }

    func encode(_ buffer: MTLBuffer, to path: String, _ encoderClosure: (BytesEncoder)->()) {
        encode(buffer, to: Path.path(withVisualFormat: path), encoderClosure)
    }
    
    func encode(_ buffer: MTLBuffer, offset: Int, to path: String, _ encoderClosure: (BytesEncoder)->()) {
        encode(buffer, offset: offset, to: Path.path(withVisualFormat: path), encoderClosure)
    }
    
    func encode(_ texture: MTLTexture, to path: String) {
        encode(texture, to: Path.path(withVisualFormat: path))
    }
}

public extension ArgumentBufferEncoder {
    func childEncoder(for path: String) -> ArgumentBufferEncoder {
        childEncoder(for: Path.path(withVisualFormat: path))
    }
}
