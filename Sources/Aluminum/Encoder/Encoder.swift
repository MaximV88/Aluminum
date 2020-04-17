//
//  Encoder.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 20/01/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal



/// `BytesEncoder` can encode only to a struct that has no buffers/textures/samplers,
/// which is why only data copy is permitted.
public protocol BytesEncoder {
    
    /// Bind data (by copy) for a given argument by name.
    /// This will remove any previous binding at given path.
    ///
    /// Copying is done by targeting offset of value in argument buffer.
    ///
    /// - Parameter bytes: The memory address from which to copy the data.
    /// - Parameter count: The number of bytes to copy.
    /// - Parameter path: A path to an argument on which binding will be performed.
    func encode(_ bytes: UnsafeRawPointer, count: Int, to path: Path)

}


/// `ArgumentBufferEncoder` represents an encoder that uses an `MTLArgumentEncoder`,
/// thus the API is very similar to `MTLArgumentEncoder`'s API.
///
/// The encoder makes sure that resources bound by it are available
/// in compute/render pass by calling `useResource(_:usage:)`.
public protocol ArgumentBufferEncoder: BytesEncoder {
        
    /// The number of bytes required to store the encoded resources of an argument buffer.
    ///
    /// Refer to `encodedLength` in `MTLArgumentEncoder` regarding usage.
    var encodedLength: Int { get }

    /// Specifies the argument buffer that resources are encoded into.
    /// This will remove any previous binding.
    ///
    /// Refer to `setArgumentBuffer(_:offset:)` in `MTLArgumentEncoder` regarding usage.
    ///
    /// - Parameter argumentBuffer: The destination buffer that represents an argument buffer.
    /// - Parameter offset: The byte offset of the buffer.
    func setArgumentBuffer(_ argumentBuffer: MTLBuffer, offset: Int)

    /// Initializes a new `ArgumentBufferEncoder` at the given path destination.
    /// Destination must refer to a buffer.
    ///
    /// - Parameter path: A path to a buffer destination for which the encoder is initialized.
    /// - Returns: An `ArgumentBufferEncoder` for the destination buffer specified at `path`.
    func childEncoder(for path: Path) -> ArgumentBufferEncoder

    /// Binds a `MTLBuffer` to destination argument.
    /// This will remove any previous binding.
    ///
    /// - Parameter buffer: The `MTLBuffer` object to set in the argument table.
    /// - Parameter offset: Where the data begins, in bytes, from the start of the buffer.
    /// - Parameter path: A path to an argument on which binding will be performed.
    func encode(_ buffer: MTLBuffer, offset: Int, to path: Path)

    /// Binds an array `MTLBuffer` to destination argument.
    /// This will remove any previous binding.
    ///
    /// - Parameter buffers: The `MTLBuffer` array  to set in the argument buffer.
    /// - Parameter offset: Where the data begins, in bytes, from the start of the buffer, where index corresponds to index in `buffers`.
    /// - Parameter path: A path to an argument on which binding will be performed.
    func encode(_ buffers: [MTLBuffer], offsets: [Int], to path: Path)
    
    /// Binds a `MTLBuffer` to destination argument, with addition of changing values in buffer for target argument.
    /// This will remove any previous binding.
    ///
    /// - Parameter buffer: The `MTLBuffer` object to set in the argument buffer.
    /// - Parameter offset: Where the data begins, in bytes, from the start of the buffer.
    /// - Parameter path: A path to an argument on which binding will be performed.
    /// - Parameter encoderClosure: A closure that provides `BytesEncoder` to encode target argument values.
    func encode(_ buffer: MTLBuffer, offset: Int, to path: Path, _ encoderClosure: (BytesEncoder)->())

    /// Binds a `MTLTexture` to destination argument.
    /// This will remove any previous binding.
    ///
    /// Refer to `setTexture(_:index:)` in `MTLArgumentEncoder` regarding usage.
    ///
    /// - Parameter texture: The texture to set in the texture argument buffer.
    /// - Parameter path: A path to an argument on which binding will be performed.
    func encode(_ texture: MTLTexture, to path: Path)
        
    /// Binds an array of `MTLTexture` to destination argument.
    /// This will remove any previous binding.
    ///
    /// Refer to `setTextures(_:range:)` in `MTLArgumentEncoder` regarding usage.
    ///
    /// - Parameter textures: The array of textures to set in the argument buffer.
    /// - Parameter path: A path to an argument on which binding will be performed.
    func encode(_ textures: [MTLTexture], to path: Path)

    /// Binds a `MTLSamplerState` to destination argument.
    /// This will remove any previous binding.
    ///
    /// Refer to `setSamplerState(_:index:)` in `MTLArgumentEncoder` regarding usage.
    ///
    /// - Parameter sampler: The sampler state to set in the argument buffer.
    /// - Parameter path: A path to an argument on which binding will be performed.
    func encode(_ sampler: MTLSamplerState, to path: Path)

    /// Binds an array of `MTLSamplerState` to destination argument.
    /// This will remove any previous binding.
    ///
    /// Refer to `setSamplerStates(_:range:)` in `MTLArgumentEncoder` regarding usage.
    ///
    /// - Parameter samplers: The array of sampler states to set in the argument buffer.
    /// - Parameter path: A path to an argument on which binding will be performed.
    func encode(_ samplers: [MTLSamplerState], to path: Path)
    
    /// Binds a `MTLRenderPipelineState` to destination argument.
    /// This will remove any previous binding.
    ///
    /// Refer to `setRenderPipelineState(_:)` in `MTLArgumentEncoder` regarding usage.
    ///
    /// - Parameter pipeline: The render pipeline state to set in the argument buffer.
    /// - Parameter path: A path to an argument on which binding will be performed.
    @available(iOS 13, *)
    func encode(_ pipeline: MTLRenderPipelineState, to path: Path)
    
    /// Binds an array of `MTLRenderPipelineState` to destination argument.
    /// This will remove any previous binding.
    ///
    /// Refer to `setRenderPipelineStates(_:range:)` in `MTLArgumentEncoder` regarding usage.
    ///
    /// - Parameter pipelines: The array of render pipeline states to set in the argument buffer.
    /// - Parameter path: A path to an argument on which binding will be performed.
#if os(macOS)
    func encode(_ pipelines: [MTLRenderPipelineState], to path: Path)
#endif
    
    /// Binds a `MTLIndirectCommandBuffer` to destination argument.
    /// This will remove any previous binding.
    ///
    /// Refer to `setIndirectCommandBuffer(_:index:)` in `MTLArgumentEncoder` regarding usage.
    ///
    /// - Parameter buffer: The indirect command buffer to set in the argument buffer.
    /// - Parameter path: A path to an argument on which binding will be performed.
    func encode(_ buffer: MTLIndirectCommandBuffer, to path: Path)

    /// Binds an array of `MTLIndirectCommandBuffer` to destination argument.
    /// This will remove any previous binding.
    ///
    /// Refer to `setIndirectCommandBuffers(_:range:)` in `MTLArgumentEncoder` regarding usage.
    ///
    /// - Parameter buffers: The array of indirect command buffers to set in the argument buffer.
    /// - Parameter path: A path to an argument on which binding will be performed.
    func encode(_ buffers: [MTLIndirectCommandBuffer], to path: Path)
    
}


/// `RootEncoder` represents an encoder that targets an argument in some `Metal` function.
/// It provides a common interface that has access to all the various Metal binding functions.
///
/// Each encoder has a specific argument (i.e. the parameter itself in the metal function) for which it was created.
/// The argument dictates how encoding (binding) can be performed.
///
/// APIs specified in `RootEncoder` protocol target the 'root' of an argument, but it's inheritace from `ArgumentBufferEncoder`
/// allows it to create, if underlying argument permits so, a child encoder with which it can use to encode an argument buffer.
public protocol RootEncoder: ArgumentBufferEncoder {
    
    // TODO: implement buffer offset
//    func setBufferOffset(_ offset: Int)

    /// Binds a `MTLBuffer` to `RootEncoder`'s argument.
    /// This will remove any previous binding.
    ///
    /// Refer to `setBuffer(_:offset:index:)` regarding input requirements.
    ///
    /// - Parameter buffer: The `MTLBuffer` object to set in the argument table.
    /// - Parameter offset: Where the data begins, in bytes, from the start of the buffer.
    func encode(_ buffer: MTLBuffer, offset: Int)
    
    /// Binds data to `RootEncoder`'s argument by copying it.
    /// This will remove any previous binding.
    ///
    /// Refer to `setBytes(_:length:index:)` regarding input requirements.
    ///
    /// - Parameter bytes: The memory address from which to copy the data.
    /// - Parameter count: The number of bytes to copy.
    func encode(_ bytes: UnsafeRawPointer, count: Int)
    
    /// Binds a `MTLTexture` to `RootEncoder`'s argument.
    /// This will remove any previous binding.
    ///
    /// Refer to `setTexture(_:index:)` regarding input requirements.
    ///
    /// - Parameter texture: The texture to set in the texture argument table.
    func encode(_ texture: MTLTexture)
    
    /// Binds an array of `MTLTexture` to `RootEncoder`'s argument.
    /// This will remove any previous binding.
    ///
    /// Refer to `setTextures(_:range:)` regarding input requirements.
    ///
    /// - Parameter textures: The array of textures to set in the texture argument table.
    func encode(_ textures: [MTLTexture])
    
    /// Binds a `MTLSamplerState` to `RootEncoder`'s argument.
    /// This will remove any previous binding.
    ///
    /// Refer to `setSamplerState(_:index:)` regarding input requirements.
    ///
    /// - Parameter sampler: The sampler state to set in the sampler state argument table.
    func encode(_ sampler: MTLSamplerState)

    /// Binds a `MTLSamplerState` to `RootEncoder`'s argument,
    /// specifying clamp values for the level of detail.
    /// This will remove any previous binding.
    ///
    /// Refer to `setSamplerState(_:lodMinClamp:lodMaxClamp:index:)` regarding input requirements.
    ///
    /// - Parameter sampler: The sampler state to set in the sampler state argument table.
    /// - Parameter lodMinClamp: The minimum level of detail used when sampling a texture.
    /// - Parameter lodMaxClamp: The maximum level of detail used when sampling a texture.
    func encode(_ sampler: MTLSamplerState, lodMinClamp: Float, lodMaxClamp: Float)

    /// Binds an array of `MTLSamplerState` to `RootEncoder`'s argument.
    /// This will remove any previous binding.
    ///
    /// Refer to `setSamplerStates(_:range:)` regarding input requirements.
    ///
    /// - Parameter samplers: The array of sampler states to set in the sampler state argument table.
    func encode(_ samplers: [MTLSamplerState])

    /// Binds an array of `MTLSamplerState` to `RootEncoder`'s argument,
    /// specifying clamp values for the level of detail.
    /// This will remove any previous binding.
    ///
    /// All input arrays are expected to be equal in size since input is organized by index.
    ///
    /// Refer to `setSamplerStates(_:range:)` regarding input requirements.
    ///
    /// - Parameter samplers: An array of `MTLSamplerState` objects to set in the argument table.
    /// - Parameter lodMinClamps: An array of minimum levels of detail corresponding to the samplers array used when sampling textures.
    /// - Parameter lodMaxClamps: An array of maximum levels of detail corresponding to the samplers array used when sampling textures.
    func encode(_ samplers: [MTLSamplerState], lodMinClamps: [Float], lodMaxClamps: [Float])
    
}

public extension BytesEncoder {
    
    /// Bind data (by copy) for a given argument by name.
    /// Infers data length as the stride of the value's memory layout.
    /// This will remove any previous binding at given path.
    ///
    /// Refer to `setBytes(_:length:index:)` regarding input requirements.
    ///
    /// - Parameter parameter: Value to bind (note that the instance's bytes are copied).
    /// - Parameter path: A path to an argument on which binding will be performed.
    func encode<T>(_ parameter: T, to path: Path) {
        withUnsafePointer(to: parameter) { ptr in
            encode(ptr, count: MemoryLayout<T>.stride, to: path)
        }
    }
    
    /// Bind data (by copy) for a given argument array by name.
    /// Infers data length as the stride of the array's element memory layout.
    /// This will remove any previous binding at given path.
    ///
    /// Refer to `setBytes(_:length:index:)` regarding input requirements.
    ///
    /// - Parameter array: Array of values to bind (note that the instance's bytes are copied).
    /// - Parameter path: A path to an argument on which binding will be performed.
    func encode<T>(_ array: [T], to path: Path) {
        var conformedPath: Path
        var startingIndex: Int = 0 // default starting index
        
        if let index = path.last!.index {
            startingIndex = index
            conformedPath = Array(path[...(path.count - 2)])
        } else {
            conformedPath = path
        }
        
        for (index, element) in array.enumerated() {
            withUnsafePointer(to: element) { ptr in
                encode(ptr, count: MemoryLayout<T>.stride, to: conformedPath + [.index(startingIndex + index)])
            }
        }
    }
}

public extension ArgumentBufferEncoder {
    
    /// Specifies the argument buffer that resources are encoded into with a default offset of 0.
    /// This will remove any previous binding.
    ///
    /// Refer to `setArgumentBuffer(_:offset:)` in `MTLArgumentEncoder` regarding usage.
    ///
    /// - Parameter argumentBuffer: The destination buffer that represents an argument buffer.
    func setArgumentBuffer(_ argumentBuffer: MTLBuffer) {
        setArgumentBuffer(argumentBuffer, offset: 0)
    }
    
    /// Binds a `MTLBuffer` to destination argument with a default offset of 0.
    /// This will remove any previous binding.
    ///
    /// - Parameter buffer: The `MTLBuffer` object to set in the argument table.
    /// - Parameter path: A path to an argument on which binding will be performed.
    func encode(_ buffer: MTLBuffer, to path: Path)  {
        encode(buffer, offset: 0, to: path)
    }
    
    /// Binds an array `MTLBuffer` to destination argument with a default offset of 0.
    /// This will remove any previous binding.
    ///
    /// - Parameter buffers: The `MTLBuffer` array  to set in the argument buffer.
    /// - Parameter path: A path to an argument on which binding will be performed.
    func encode(_ buffers: [MTLBuffer], to path: Path) {
        encode(buffers, offsets: [Int](repeating: 0, count: buffers.count), to: path)
    }
    
    /// Binds a `MTLBuffer` to destination argument, with addition of changing values in buffer for target argument with a default offset of 0.
    /// This will remove any previous binding.
    ///
    /// - Parameter buffer: The `MTLBuffer` object to set in the argument buffer.
    /// - Parameter path: A path to an argument on which binding will be performed.
    /// - Parameter encoderClosure: A closure that provides `BytesEncoder` to encode target argument values.
    func encode(_ buffer: MTLBuffer, to path: Path, _ encoderClosure: (BytesEncoder)->()) {
        encode(buffer, offset: 0, to: path, encoderClosure)
    }

    /// Binds a `MTLBuffer` to destination argument with a default offset of 0.
    /// This will remove any previous binding.
    ///
    /// - Parameter buffer: The `MTLBuffer` object to set in the argument table.
    /// - Parameter path: A path to an argument on which binding will be performed.
    func encode<T: MTLBuffer>(_ buffer: T?, to path: Path) {
        switch buffer {
        case .some(let some): encode(some as MTLBuffer, to: path)
        case .none: fatalError(.nilValuesAreInvalid)
        }
    }
    
    /// Binds a `MTLTexture` to destination argument.
    /// This will remove any previous binding.
    ///
    /// Refer to `setTexture(_:index:)` in `MTLArgumentEncoder` regarding usage.
    ///
    /// - Parameter texture: The texture to set in the texture argument buffer.
    /// - Parameter path: A path to an argument on which binding will be performed.
    func encode<T: MTLTexture>(_ texture: T?, to path: Path) {
        switch texture {
        case .some(let some): encode(some as MTLTexture, to: path)
        case .none: fatalError(.nilValuesAreInvalid)
        }
    }

    /// Binds a `MTLSamplerState` to destination argument.
    /// This will remove any previous binding.
    ///
    /// Refer to `setSamplerState(_:index:)` in `MTLArgumentEncoder` regarding usage.
    ///
    /// - Parameter sampler: The sampler state to set in the argument buffer.
    /// - Parameter path: A path to an argument on which binding will be performed.
    func encode<T: MTLSamplerState>(_ sampler: T?, to path: Path) {
        switch sampler {
        case .some(let some): encode(some as MTLSamplerState, to: path)
        case .none: fatalError(.nilValuesAreInvalid)
        }
    }
    
    /// Binds a `MTLRenderPipelineState` to destination argument.
    /// This will remove any previous binding.
    ///
    /// Refer to `setRenderPipelineState(_:)` in `MTLArgumentEncoder` regarding usage.
    ///
    /// - Parameter pipeline: The render pipeline state to set in the argument buffer.
    /// - Parameter path: A path to an argument on which binding will be performed.
    @available(iOS 13, *)
    func encode<T: MTLRenderPipelineState>(_ pipeline: T?, to path: Path) {
        switch pipeline {
        case .some(let some): encode(some as MTLRenderPipelineState, to: path)
        case .none: fatalError(.nilValuesAreInvalid)
        }
    }

    /// Binds a `MTLIndirectCommandBuffer` to destination argument.
    /// This will remove any previous binding.
    ///
    /// Refer to `setIndirectCommandBuffer(_:index:)` in `MTLArgumentEncoder` regarding usage.
    ///
    /// - Parameter buffer: The indirect command buffer to set in the argument buffer.
    /// - Parameter path: A path to an argument on which binding will be performed.
    func encode<T: MTLIndirectCommandBuffer>(_ buffer: T?, to path: Path) {
        switch buffer {
        case .some(let some): encode(some as MTLIndirectCommandBuffer, to: path)
        case .none: fatalError(.nilValuesAreInvalid)
        }
    }
}

public extension RootEncoder {
    
    /// Binds a `MTLBuffer` to `RootEncoder`'s argument with a default offset of 0.
    /// This will remove any previous binding.
    ///
    /// Refer to `setBuffer(_:offset:index:)` regarding input requirements.
    ///
    /// - Parameter buffer: The `MTLBuffer` object to set in the argument table.
    func encode(_ buffer: MTLBuffer)  {
        encode(buffer, offset: 0)
    }
}

public extension RootEncoder {
    
    /// Bind data (by copy) to `RootEncoder`'s argument.
    /// Infers data length as the stride of the value's memory layout.
    /// This will remove any previous binding for given argument.
    ///
    /// - Parameter parameter: Value to bind (note that the instance's bytes are copied).
    func encode<T>(_ parameter: T) {
        withUnsafePointer(to: parameter) { ptr in
            encode(ptr, count: MemoryLayout<T>.stride)
        }
    }
    
    /// Binds a `MTLBuffer` to `RootEncoder`'s argument with a default offset of 0.
    /// This will remove any previous binding.
    ///
    /// Refer to `setBuffer(_:offset:index:)` regarding input requirements.
    ///
    /// - Parameter buffer: The `MTLBuffer` object to set in the argument table.
    func encode<T: MTLBuffer>(_ parameter: T?) {
        switch parameter {
        case .some(let some): encode(some as MTLBuffer)
        case .none: fatalError(.nilValuesAreInvalid)
        }
    }

    /// Binds a `MTLTexture` to `RootEncoder`'s argument.
    /// This will remove any previous binding.
    ///
    /// Refer to `setTexture(_:index:)` regarding input requirements.
    ///
    /// - Parameter texture: The texture to set in the texture argument table.
    func encode<T: MTLTexture>(_ parameter: T?) {
        switch parameter {
        case .some(let some): encode(some as MTLTexture)
        case .none: fatalError(.nilValuesAreInvalid)
        }
    }
    
    /// Binds a `MTLSamplerState` to `RootEncoder`'s argument.
    /// This will remove any previous binding.
    ///
    /// Refer to `setSamplerState(_:index:)` regarding input requirements.
    ///
    /// - Parameter sampler: The sampler state to set in the sampler state argument table.
    func encode<T: MTLSamplerState>(_ parameter: T?) {
        switch parameter {
        case .some(let some): encode(some as MTLSamplerState)
        case .none: fatalError(.nilValuesAreInvalid)
        }
    }
    
    /// Binds a `MTLSamplerState` to `RootEncoder`'s argument,
    /// specifying clamp values for the level of detail.
    /// This will remove any previous binding.
    ///
    /// Refer to `setSamplerState(_:lodMinClamp:lodMaxClamp:index:)` regarding input requirements.
    ///
    /// - Parameter sampler: The sampler state to set in the sampler state argument table.
    /// - Parameter lodMinClamp: The minimum level of detail used when sampling a texture.
    /// - Parameter lodMaxClamp: The maximum level of detail used when sampling a texture.
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
                precondition(inputIndex >= 0 && inputIndex < a.arrayLength, .pathIndexOutOfBounds(pathIndex))
                index += Int(inputIndex)
            }
            
            pathIndex += 1
        case .structMember(let s):
            index += s.argumentIndex
            pathIndex += 1
        case .array(let a):
            let inputIndex = path[pathIndex].index!
            precondition(inputIndex >= 0 && inputIndex < a.arrayLength, .pathIndexOutOfBounds(pathIndex))
            index += a.argumentIndexStride * Int(inputIndex)
            pathIndex += 1
        case .metalArray(let a, let s):
            let inputIndex = path[pathIndex].index!
            precondition(inputIndex >= 0 && inputIndex < a.arrayLength, .pathIndexOutOfBounds(pathIndex))
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
            precondition(index >= 0 && index < a.arrayLength, .pathIndexOutOfBounds(pathIndex))
            offset += Int(index) * a.stride
        default: break
        }
        
        pathIndex += 1
    }
    
    // expect entire path iteration
    assert(pathIndex == path.count)
    
    return offset
}
