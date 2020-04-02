//
//  Errors.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 20/03/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Foundation

func fatalError(_ error: AluminumError) -> Never {
    fatalError(error.localizedDescription)
}

func assert(_ condition: @autoclosure () -> Bool,
            _ error: AluminumError,
            file: StaticString = #file,
            line: UInt = #line)
{
    assert(condition(),
           error.localizedDescription,
           file: file,
           line: line)
}

func assertionFailure(_ error: AluminumError,
                      file: StaticString = #file,
                      line: UInt = #line)
{
    assertionFailure(error.localizedDescription,
                     file: file,
                     line: line)
}

enum AluminumError: Error {
    case unknownArgument(String)
    case nonExistingPath
    case invalidEncoderPath
    case noArgumentBuffer
    case invalidArgumentBuffer
    case invalidBuffer
    case pathIndexOutOfBounds(Int)
    case invalidBufferPath(DataType)
    case invalidBytesPath(DataType)
    case invalidEncodableBufferPath(DataType)
    case invalidChildEncoderPath
}

extension AluminumError: LocalizedError {
    var localizedDescription: String {
        switch self {
        case .unknownArgument(let a): return "\(a) does not match any root argument.".padded
        case .nonExistingPath: return "Given path does not exist.".padded
        case .invalidEncoderPath: return "Encoder does not support given path (extends outside of it).".padded
        case .noArgumentBuffer: return "Did not set argument buffer for encoder.".padded
        case .invalidArgumentBuffer: return "Argument buffer is too short.".padded
        case .invalidBuffer: return "Buffer is too short".padded
        case .pathIndexOutOfBounds(let i): return "index \(i) is not in bounds of related array.".padded
        case .invalidBufferPath(let d): return "Expected buffer for path. Encountered \(d.named)".padded
        case .invalidBytesPath(let d): return "Expected assignable value for path. Encountered \(d.named)".padded
        case .invalidEncodableBufferPath(let d): return "Expected encodable buffer for path. Encountered \(d.named)".padded
        case .invalidChildEncoderPath: return "Path used is not compatible for using a child encoder".padded
        }
    }
}

private extension DataType {
    var named: String {
        switch self {
        case .argument(let a): fallthrough
        case .argumentContainingArgumentBuffer(let a, _): return "root argument named \(a)"
        case .argumentBuffer(_, let s): return "argument named \(s.name)"
        case .buffer(_, let s): return "buffer named \(s.name)"
        case .bytes(_, let s): return "assignable value named \(s.name)"
        case .encodableBuffer(_, _, let s): return "encodable buffer named \(s.name)"
        }
    }
}

private extension String {
    var padded: String {
        return "\n\n\(self)\n\n"
    }
}
