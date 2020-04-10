//
//  Errors.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 20/03/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Foundation


func fatalError(_ error: AluminumError) -> Never {
    fatalError(error.localizedDescription.padded)
}

func assert(_ condition: @autoclosure () -> Bool,
            _ error: AluminumError,
            file: StaticString = #file,
            line: UInt = #line)
{
    assert(condition(),
           error.localizedDescription.padded,
           file: file,
           line: line)
}

func assertionFailure(_ error: AluminumError,
                      file: StaticString = #file,
                      line: UInt = #line)
{
    assertionFailure(error.localizedDescription.padded,
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
    case invalidSamplerPath(DataType)
    case invalidIndirectCommandBufferPath(DataType)
    case invalidChildEncoderPath
    case noArgumentBufferSupportForSingleUseData
    case overridesSingleUseData
    case requiresPathReference
    case requiresArrayReference
    case noExistingTexture
    case noExistingBuffer
    case noExistingSampler
    case noExistingIndirectBuffer
    case noArgumentBufferRequired
    case noChildEncoderExists
    case nilValuesAreInvalid
    case arrayOutOfBounds(Int)
}

// TODO: path description does not provide any useful information
extension AluminumError: LocalizedError {
    var localizedDescription: String {
        switch self {
        case .unknownArgument(let a): return "\(a) does not match any root argument."
        case .nonExistingPath: return "Given path does not exist."
        case .invalidEncoderPath: return "Encoder does not support given path (extends outside of it)."
        case .noArgumentBuffer: return "Did not set argument buffer for encoder."
        case .invalidArgumentBuffer: return "Argument buffer is too short."
        case .invalidBuffer: return "Buffer is too short."
        case .pathIndexOutOfBounds(let i): return "index \(i) is not in bounds of related array."
        case .invalidBufferPath(let d): return "Expected buffer for path. Encountered \(d.named)."
        case .invalidBytesPath(let d): return "Expected assignable value for path. Encountered \(d.named)."
        case .invalidEncodableBufferPath(let d): return "Expected encodable buffer for path. Encountered \(d.named)."
        case .invalidTexturePath(let d): return "Expected texture for path. Encountered \(d.named)."
        case .invalidSamplerPath(let d): return "Expected sampler for path. Encountered \(d.named)."
        case .invalidIndirectCommandBufferPath(let d): return "Expected indirect command buffer for path. Encountered \(d.named)."
        case .invalidChildEncoderPath: return "Path used is not compatible for using a child encoder."
        case .noArgumentBufferSupportForSingleUseData: return "Argument buffer cannot set single use data storage."
        case .overridesSingleUseData: return "Removes single use data that was already set."
        case .requiresPathReference: return "Argument configuration requires a path."
        case .requiresArrayReference: return "Argument configuration requires an array path reference."
        case .noExistingTexture: return "Encoder does not contain a texture."
        case .noExistingBuffer: return "Encoder does not contain a buffer."
        case .noExistingSampler: return "Encoder does not contain a sampler."
        case .noExistingIndirectBuffer: return "Encoder does not contain an indirect buffer."
        case .noArgumentBufferRequired: return "Encoder does not require an argument buffer."
        case .noChildEncoderExists: return "Encoder does not contain child encoders."
        case .nilValuesAreInvalid: return "Encoder does not support encoding nil values."
        case .arrayOutOfBounds(let i): return "Array size can have maximum count of \(i)."
        }
    }
}

private extension DataType {
    var named: String {
        switch self {
        case .argument(let a): fallthrough
        case .argumentContainingArgumentBuffer(let a, _): return "root argument named \(a)"
        case .encodableArgument(let a): return "root encodable argument named \(a)"
        case .textureArgument(let a): return "root argument of texture named \(a)"
        case .samplerArgument(let a): return "root argument of sampler named \(a)"
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
