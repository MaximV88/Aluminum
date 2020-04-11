//
//  Encoder.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 20/01/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal


public protocol BytesEncoder {
    
    func encode(_ bytes: UnsafeRawPointer, count: Int, to path: Path)

}

public protocol ArgumentBufferEncoder: BytesEncoder {
        
    var encodedLength: Int { get }

    func setArgumentBuffer(_ argumentBuffer: MTLBuffer, offset: Int)

    func childEncoder(for path: Path) -> ArgumentBufferEncoder

    func encode(_ buffer: MTLBuffer, offset: Int, to path: Path)
    
    func encode(_ buffers: [MTLBuffer], offsets: [Int], to path: Path)
    
    func encode(_ buffer: MTLBuffer, offset: Int, to path: Path, _ encoderClosure: (BytesEncoder)->())

    func encode(_ texture: MTLTexture, to path: Path)
        
    func encode(_ textures: [MTLTexture], to path: Path)

    func encode(_ sampler: MTLSamplerState, to path: Path)

    func encode(_ samplers: [MTLSamplerState], to path: Path)
    
    func encode(_ pipeline: MTLRenderPipelineState, to path: Path)
    
    func encode(_ pipelines: [MTLRenderPipelineState], to path: Path)
    
    func encode(_ buffer: MTLIndirectCommandBuffer, to path: Path)

    func encode(_ buffers: [MTLIndirectCommandBuffer], to path: Path)
    
}

public protocol RootEncoder: ArgumentBufferEncoder {
    // TODO: implement buffer offset
//    func setBufferOffset(_ offset: Int)

    func encode(_ buffer: MTLBuffer, offset: Int)
    
    func encode(_ bytes: UnsafeRawPointer, count: Int)
    
    func encode(_ texture: MTLTexture)
    
    func encode(_ textures: [MTLTexture])
    
    func encode(_ sampler: MTLSamplerState)

    func encode(_ sampler: MTLSamplerState, lodMinClamp: Float, lodMaxClamp: Float)

    func encode(_ samplers: [MTLSamplerState])

    func encode(_ samplers: [MTLSamplerState], lodMinClamps: [Float], lodMaxClamps: [Float])
    
}

public extension BytesEncoder {
    func encode<T>(_ parameter: T, to path: Path) {
        withUnsafePointer(to: parameter) { ptr in
            encode(ptr, count: MemoryLayout<T>.stride, to: path)
        }
    }
}

public extension ArgumentBufferEncoder {
    func setArgumentBuffer(_ argumentBuffer: MTLBuffer) {
        setArgumentBuffer(argumentBuffer, offset: 0)
    }

    func encode(_ buffer: MTLBuffer, to path: Path)  {
        encode(buffer, offset: 0, to: path)
    }
    
    func encode(_ buffers: [MTLBuffer], to path: Path) {
        encode(buffers, offsets: [Int](repeating: 0, count: buffers.count), to: path)
    }
    
    func encode(_ buffer: MTLBuffer, to path: Path, _ encoderClosure: (BytesEncoder)->()) {
        encode(buffer, offset: 0, to: path, encoderClosure)
    }

    func encode<T: MTLBuffer>(_ buffer: T?, to path: Path) {
        switch buffer {
        case .some(let some): encode(some as MTLBuffer, to: path)
        case .none: fatalError(.nilValuesAreInvalid)
        }
    }
    
    func encode<T: MTLTexture>(_ texture: T?, to path: Path) {
        switch texture {
        case .some(let some): encode(some as MTLTexture, to: path)
        case .none: fatalError(.nilValuesAreInvalid)
        }
    }

    func encode<T: MTLSamplerState>(_ sampler: T?, to path: Path) {
        switch sampler {
        case .some(let some): encode(some as MTLSamplerState, to: path)
        case .none: fatalError(.nilValuesAreInvalid)
        }
    }
    
    func encode<T: MTLRenderPipelineState>(_ pipeline: T?, to path: Path) {
        switch pipeline {
        case .some(let some): encode(some as MTLRenderPipelineState, to: path)
        case .none: fatalError(.nilValuesAreInvalid)
        }
    }

    func encode<T: MTLIndirectCommandBuffer>(_ buffer: T?, to path: Path) {
        switch buffer {
        case .some(let some): encode(some as MTLIndirectCommandBuffer, to: path)
        case .none: fatalError(.nilValuesAreInvalid)
        }
    }
}

public extension RootEncoder {
    func encode(_ buffer: MTLBuffer)  {
        encode(buffer, offset: 0)
    }
}

public extension RootEncoder {
    func encode<T>(_ parameter: T) {
        withUnsafePointer(to: parameter) { ptr in
            encode(ptr, count: MemoryLayout<T>.stride)
        }
    }
    
    func encode<T: MTLBuffer>(_ parameter: T?) {
        switch parameter {
        case .some(let some): encode(some as MTLBuffer)
        case .none: fatalError(.nilValuesAreInvalid)
        }
    }

    func encode<T: MTLTexture>(_ parameter: T?) {
        switch parameter {
        case .some(let some): encode(some as MTLTexture)
        case .none: fatalError(.nilValuesAreInvalid)
        }
    }
    
    func encode<T: MTLSamplerState>(_ parameter: T?) {
        switch parameter {
        case .some(let some): encode(some as MTLSamplerState)
        case .none: fatalError(.nilValuesAreInvalid)
        }
    }
    
    func encode<T: MTLSamplerState>(_ parameter: T?, lodMinClamp: Float, lodMaxClamp: Float) {
        switch parameter {
        case .some(let some): encode(some as MTLSamplerState, lodMinClamp: lodMinClamp, lodMaxClamp: lodMaxClamp)
        case .none: fatalError(.nilValuesAreInvalid)
        }
    }
}

internal func makeRootEncoder(
    for encoding: Parser.Encoding,
    rootPath: Path,
    function: MTLFunction,
    metalEncoder: MetalEncoder
) -> RootEncoder
{
    switch encoding.dataType {
    case .argument:
        return ArgumentRootEncoder(encoding: encoding,
                                   metalEncoder: metalEncoder)
    case .encodableArgument:
        return EncodableArgumentRootEncoder(encoding: encoding,
                                            metalEncoder: metalEncoder)
    case .textureArgument:
        return TextureRootEncoder(encoding: encoding,
                                  metalEncoder: metalEncoder)
    case .samplerArgument:
        return SamplerRootEncoder(encoding: encoding,
                                  metalEncoder: metalEncoder)
    case .argumentContainingArgumentBuffer:
        let index = queryIndex(for: rootPath, dataTypePath: encoding.dataTypePath)
        return ArgumentBufferRootEncoder(encoding: encoding,
                                         encoderIndex: index,
                                         argumentEncoder: function.makeArgumentEncoder(bufferIndex: index),
                                         parentArgumentEncoder: nil,
                                         metalEncoder: metalEncoder)
    default: fatalError("RootEncoder must start with an argument.")
    }
}

internal func queryIndex<DataTypeArray: RandomAccessCollection>(
    for path: Path,
    dataTypePath: DataTypeArray
) -> Int
    where DataTypeArray.Element == DataType
{
    assert(!path.isEmpty)
    assert(!dataTypePath.isEmpty)

    var index = 0
    var pathIndex: Int = 0

    for dataType in dataTypePath {
        switch dataType {
        case .argumentContainingArgumentBuffer(let a, _): fallthrough
        case .encodableArgument(let a): fallthrough
        case .textureArgument(let a): fallthrough
        case .argument(let a):
            index += a.index
            
            // TODO: replace parse naming rules in naming iteration
            if a.arrayLength > 1 {
                let inputIndex = path[pathIndex].index!
                assert(inputIndex >= 0 && inputIndex < a.arrayLength, .pathIndexOutOfBounds(pathIndex))
                index += Int(inputIndex)
            }
            
            pathIndex += 1
        case .structMember(let s):
            index += s.argumentIndex
            pathIndex += 1
        case .array(let a):
            let inputIndex = path[pathIndex].index!
            assert(inputIndex >= 0 && inputIndex < a.arrayLength, .pathIndexOutOfBounds(pathIndex))
            index += a.argumentIndexStride * Int(inputIndex)
            pathIndex += 1
        case .metalArray(let a, let s):
            let inputIndex = path[pathIndex].index!
            assert(inputIndex >= 0 && inputIndex < a.arrayLength, .pathIndexOutOfBounds(pathIndex))
            index += a.argumentIndexStride * Int(inputIndex) + s.argumentIndex
            pathIndex += 1
        default: break
        }
    }
    
    // expect entire path iteration
    assert(pathIndex == path.count)
    
    return index
}

internal func queryOffset<DataTypeArray: RandomAccessCollection>(
    for path: Path,
    dataTypePath: DataTypeArray
) -> Int
    where DataTypeArray.Element == DataType
{
    assert(!path.isEmpty)
    assert(!dataTypePath.isEmpty)

    var offset: Int = 0
    var pathIndex: Int = 0
    
    for dataType in dataTypePath {
        switch dataType {
        case .structMember(let s): offset += s.offset
        case .array(let a): fallthrough
        case .metalArray(let a, _):
            let index = path[pathIndex].index!
            assert(index >= 0 && index < a.arrayLength, .pathIndexOutOfBounds(pathIndex))
            offset += Int(index) * a.stride
        default: break
        }
        
        pathIndex += 1
    }
    
    // expect entire path iteration
    assert(pathIndex == path.count)
    
    return offset
}
