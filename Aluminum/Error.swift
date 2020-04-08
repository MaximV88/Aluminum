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
    case invalidTexturePath(DataType)
    case invalidChildEncoderPath
    case noArgumentBufferSupportForSingleUseData
    case overridesSingleUseData
    case noSupportForTextureWithoutPath
    case noExistingTexture
    case noExistingBuffer
    case noArgumentBufferRequired
    case noChildEncoderExists
}

// TODO: path description does not provide any useful information
extension AluminumError: LocalizedError {
    var localizedDescription: String {
        switch self {
        case .unknownArgument(let a): return "\(a) does not match any root argument.".padded
        case .nonExistingPath: return "Given path does not exist.".padded
        case .invalidEncoderPath: return "Encoder does not support given path (extends outside of it).".padded
        case .noArgumentBuffer: return "Did not set argument buffer for encoder.".padded
        case .invalidArgumentBuffer: return "Argument buffer is too short.".padded
        case .invalidBuffer: return "Buffer is too short.".padded
        case .pathIndexOutOfBounds(let i): return "index \(i) is not in bounds of related array.".padded
        case .invalidBufferPath(let d): return "Expected buffer for path. Encountered \(d.named).".padded
        case .invalidBytesPath(let d): return "Expected assignable value for path. Encountered \(d.named).".padded
        case .invalidEncodableBufferPath(let d): return "Expected encodable buffer for path. Encountered \(d.named).".padded
        case .invalidTexturePath(let d): return "Expected texture for path. Encountered \(d.named).".padded
        case .invalidChildEncoderPath: return "Path used is not compatible for using a child encoder.".padded
        case .noArgumentBufferSupportForSingleUseData: return "Argument buffer cannot set single use data storage.".padded
        case .overridesSingleUseData: return "Removes single use data that was already set.".padded
        case .noSupportForTextureWithoutPath: return "Argument configuration requires a path to set texture.".padded
        case .noExistingTexture: return "Encoder does not contain a texture.".padded
        case .noExistingBuffer: return "Encoder does not contain a buffer.".padded
        case .noArgumentBufferRequired: return "Encoder does not require an argument buffer.".padded
        case .noChildEncoderExists: return "Encoder does not contain child encoders".padded
        }
    }
}

private extension DataType {
    var named: String {
        switch self {
        case .argument(let a): fallthrough
        case .argumentContainingArgumentBuffer(let a, _): return "root argument named \(a)"
        case .argumentTexture(let a): return "root argument of texture named \(a)"
        case .argumentBuffer: return "argument buffer"
        case .array, .metalArray: return "array"
        case .structMember(let s) where s.dataType != .pointer: return "assignable value named \(s.name)"
        case .structMember(let s): return "buffer container named \(s.name)"
        case .atomicVariable: return "atomic assignable value"
        case .encodableBuffer: return "encodable buffer"
        case .buffer: return "buffer"
        }
    }
}

private extension String {
    var padded: String {
        return "\n\n\(self)\n\n"
    }
}
