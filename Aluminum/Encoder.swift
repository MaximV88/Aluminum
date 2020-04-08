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

public protocol ResourceEncoder: BytesEncoder {
    
    func encode(_ buffer: MTLBuffer, offset: Int, to path: Path)
    
    func encode(_ buffer: MTLBuffer, offset: Int, to path: Path, _ encoderClosure: (BytesEncoder)->())

    func encode(_ texture: MTLTexture, to path: Path)
    
    // TODO: add stubs for buffer/texture arrays
    
}

public protocol ArgumentBufferEncoder: ResourceEncoder {
    
    var encodedLength: Int { get }

    func setArgumentBuffer(_ argumentBuffer: MTLBuffer, offset: Int)

    func childEncoder(for path: Path) -> ArgumentBufferEncoder

}

public protocol RootEncoder: ArgumentBufferEncoder {
    
    func encode(_ bytes: UnsafeRawPointer, count: Int)
    
    func encode(_ texture: MTLTexture)
    
}

public extension BytesEncoder {
    func encode<T>(_ parameter: T, to path: Path) {
        withUnsafePointer(to: parameter) { ptr in
            encode(ptr, count: MemoryLayout<T>.stride, to: path)
        }
    }
}

public extension ResourceEncoder {
    func encode(_ buffer: MTLBuffer, to path: Path)  {
        encode(buffer, offset: 0, to: path)
    }
    
    func encode<T: MTLBuffer>(_ parameter: T?, to path: Path) {
        switch parameter {
        case .some(let some): encode(some as MTLBuffer, to: path)
        case .none: fatalError()
        }
    }
    
    func encode<T: MTLTexture>(_ parameter: T?, to path: Path) {
        switch parameter {
        case .some(let some): encode(some as MTLTexture, to: path)
        case .none: fatalError()
        }
    }
    
    func encode(_ buffer: MTLBuffer, to path: Path, _ encoderClosure: (BytesEncoder)->()) {
        encode(buffer, offset: 0, to: path, encoderClosure)
    }
}

public extension ArgumentBufferEncoder {
    func setArgumentBuffer(_ argumentBuffer: MTLBuffer) {
        setArgumentBuffer(argumentBuffer, offset: 0)
    }
}

public extension RootEncoder {
    func encode<T>(_ parameter: T) {
        withUnsafePointer(to: parameter) { ptr in
            encode(ptr, count: MemoryLayout<T>.stride)
        }
    }
    
    func encode<T: MTLBuffer>(_ parameter: T?) {
        fatalError() // TODO: notify setting a buffer for given encoder should be done via setArgument
    }

    func encode<T: MTLTexture>(_ parameter: T?) {
        switch parameter {
        case .some(let some): encode(some as MTLTexture)
        case .none: fatalError()
        }
    }
}

internal func makeRootEncoder(
    for encoding: Parser.Encoding,
    rootPath: Path,
    function: MTLFunction,
    computeCommandEncoder: MTLComputeCommandEncoder
) -> RootEncoder
{
    switch encoding.dataType {
    case .argument:
        return ArgumentRootEncoder(encoding: encoding,
                                   function: function,
                                   computeCommandEncoder: computeCommandEncoder)
    case .argumentTexture:
        return TextureRootEncoder(encoding: encoding,
                                  computeCommandEncoder: computeCommandEncoder)
    case .argumentContainingArgumentBuffer:
        let index = queryIndex(for: rootPath, dataTypePath: encoding.dataTypePath)
        return ArgumentBufferRootEncoder(encoding: encoding,
                                         encoderIndex: index,
                                         argumentEncoder: function.makeArgumentEncoder(bufferIndex: index),
                                         parentArgumentEncoder: nil,
                                         computeCommandEncoder: computeCommandEncoder)
    default: fatalError("RootEncoder must start with an argument.")
    }
}

private class TextureRootEncoder {
    private let encoding: Parser.Encoding
    private let argument: MTLArgument
    private weak var computeCommandEncoder: MTLComputeCommandEncoder!
    
    init(encoding: Parser.Encoding,
         computeCommandEncoder: MTLComputeCommandEncoder)
    {
        guard case let .argumentTexture(argument) = encoding.dataType else {
            fatalError("RootTextureEncoder expects an argument path that starts with an argument texture.")
        }
        
        self.encoding = encoding
        self.argument = argument
        self.computeCommandEncoder = computeCommandEncoder
    }
}

extension TextureRootEncoder: RootEncoder {
    var encodedLength: Int {
        // TODO: assert that texture argument doesnt have encoded length
        return 0
    }
    
    func setArgumentBuffer(_ argumentBuffer: MTLBuffer, offset: Int) {
        fatalError()
    }
    
    func encode(_ bytes: UnsafeRawPointer, count: Int) {
        fatalError()
    }
    
    func encode(_ texture: MTLTexture) {
        // texture array cannot be set using a single texture assignment
        assert(argument.arrayLength == 1, .nonExistingPath) // TODO: send a more informative error that the given argument is array
        computeCommandEncoder.setTexture(texture, index: argument.index)
    }
    
    func encode(_ texture: MTLTexture, to path: Path) {
        let dataTypePath = encoding.localDataTypePath(for: path)
        assert(dataTypePath.last!.isArgumentTexture, .invalidTexturePath(dataTypePath.last!))
        
        let index = queryIndex(for: path, dataTypePath: dataTypePath)
        computeCommandEncoder.setTextures([texture], range: index ..< index + 1)
    }

    func encode(_ buffer: MTLBuffer, offset: Int, to path: Path, _ encoderClosure: (BytesEncoder) -> ()) {
        fatalError()
    }
    
    func encode(_ buffer: MTLBuffer, offset: Int, to path: Path) {
        fatalError()
    }
    
    func encode(_ bytes: UnsafeRawPointer, count: Int, to path: Path) {
        fatalError()
    }
    
    func childEncoder(for path: Path) -> ArgumentBufferEncoder {
        fatalError()
    }
}


private class ArgumentRootEncoder {
    private let encoding: Parser.Encoding
    private let argument: MTLArgument
    private let function: MTLFunction

    private weak var computeCommandEncoder: MTLComputeCommandEncoder!
    private weak var argumentBuffer: MTLBuffer!
    
    private var bufferOffset: Int = 0
    private var didCopyBytes = false

    init(encoding: Parser.Encoding,
         function: MTLFunction,
         computeCommandEncoder: MTLComputeCommandEncoder)
    {
        guard case let .argument(argument) = encoding.dataType else {
            fatalError("RootArgumentEncoder expects an argument path that starts with an argument.")
        }

        self.encoding = encoding
        self.function = function
        self.argument = argument
        self.computeCommandEncoder = computeCommandEncoder
    }
}

extension ArgumentRootEncoder: RootEncoder {
    var encodedLength: Int {
        return argument.bufferDataSize
    }
    
    func setArgumentBuffer(_ argumentBuffer: MTLBuffer, offset: Int) {
        assert(argumentBuffer.length - offset >= encodedLength, .invalidArgumentBuffer)
        
        self.argumentBuffer = argumentBuffer
        self.bufferOffset = offset
        
        computeCommandEncoder.setBuffer(argumentBuffer, offset: offset, index: argument.index)
    }

    func encode(_ bytes: UnsafeRawPointer, count: Int) {
        // TODO: issue warning if bytes is above 4k (i.e. count or enoder call)

        if let argumentBuffer = argumentBuffer {
            let destination = argumentBuffer.contents().assumingMemoryBound(to: UInt8.self)
            let source = bytes.assumingMemoryBound(to: UInt8.self)

            for i in 0 ..< count {
                destination[bufferOffset + i] = source[i]
            }
        } else {
            computeCommandEncoder.setBytes(bytes, length: count, index: argument.index)
            didCopyBytes = true
        }
    }
    
    func encode(_ texture: MTLTexture) {
        fatalError()
    }
    
    func encode(_ texture: MTLTexture, to path: Path) {
        fatalError()
    }
    
    func encode(_ bytes: UnsafeRawPointer, count: Int, to path: Path) {
        assert(!didCopyBytes, .overridesSingleUseData)
        assert(argumentBuffer != nil, .noArgumentBuffer)
        
        let dataTypePath = encoding.localDataTypePath(for: path)
        assert(dataTypePath.last!.isBytes, .invalidBytesPath(dataTypePath.last!))

        let pathOffset = queryOffset(for: path, dataTypePath: dataTypePath[1...])
        let destination = argumentBuffer.contents().assumingMemoryBound(to: UInt8.self)
        let source = bytes.assumingMemoryBound(to: UInt8.self)
        
        for i in 0 ..< count {
            destination[bufferOffset + pathOffset + i] = source[i]
        }
    }
    
    func encode(_ buffer: MTLBuffer, offset: Int, to path: Path) {
        let dataTypePath = encoding.localDataTypePath(for: path)
        assert(dataTypePath.last!.isBuffer, .invalidBufferPath(dataTypePath.last!))
        
        let index = queryIndex(for: path, dataTypePath: dataTypePath)
        assert(index != argument.index) // shouldnt override argument buffer
        
        computeCommandEncoder.setBuffer(buffer, offset: offset, index: index)
    }
    
    func encode(_ buffer: MTLBuffer, offset: Int, to path: Path, _ encoderClosure: (BytesEncoder)->()) {
        let dataTypePath = encoding.localDataTypePath(for: path)
        assert(dataTypePath.last!.isEncodableBuffer, .invalidEncodableBufferPath(dataTypePath.last!))
        
        fatalError("Logical error. MTLArgument does not access pointer of struct (encodable buffer)")
    }
    
    func childEncoder(for path: Path) -> ArgumentBufferEncoder {
        let childEncoding = encoding.childEncoding(for: path)
        let index = queryIndex(for: path, dataTypePath: childEncoding.dataTypePath)
                        
        return ArgumentBufferRootEncoder(encoding: childEncoding,
                                         encoderIndex: index,
                                         argumentEncoder: function.makeArgumentEncoder(bufferIndex: index),
                                         parentArgumentEncoder: nil,
                                         computeCommandEncoder: computeCommandEncoder)
    }
}

private class ArgumentBufferRootEncoder {
    private let encoding: Parser.Encoding
    private let encoderIndex: Int
    
    private let pointer: MTLPointerType
    private let argumentEncoder: MTLArgumentEncoder
    private let parentArgumentEncoder: MTLArgumentEncoder?
    private weak var computeCommandEncoder: MTLComputeCommandEncoder!

    private var hasArgumentBuffer: Bool = false

    init(encoding: Parser.Encoding,
         encoderIndex: Int,
         argumentEncoder: MTLArgumentEncoder,
         parentArgumentEncoder: MTLArgumentEncoder?,
         computeCommandEncoder: MTLComputeCommandEncoder)
    {
        let pointer: MTLPointerType
        switch encoding.dataType {
        case let .argumentBuffer(p): pointer = p
        case let .argumentContainingArgumentBuffer(_, p): pointer = p
        default: fatalError("Invalid instantiation of encoder per encoding path type.")
        }
        
        self.encoding = encoding
        self.encoderIndex = encoderIndex
        self.pointer = pointer
        self.argumentEncoder = argumentEncoder
        self.parentArgumentEncoder = parentArgumentEncoder
        self.computeCommandEncoder = computeCommandEncoder
    }
}

extension ArgumentBufferRootEncoder: RootEncoder {
    var encodedLength: Int {
        return argumentEncoder.encodedLength
    }
    
    func setArgumentBuffer(_ argumentBuffer: MTLBuffer, offset: Int) {
        assert(argumentBuffer.length - offset >= encodedLength, .invalidArgumentBuffer)

        hasArgumentBuffer = true
        argumentEncoder.setArgumentBuffer(argumentBuffer, offset: offset)
        
        if let parentArgumentEncoder = parentArgumentEncoder {
            parentArgumentEncoder.setBuffer(argumentBuffer, offset: offset, index: encoderIndex)
            computeCommandEncoder.useResource(argumentBuffer, usage: pointer.access.usage)
        } else {
            computeCommandEncoder.setBuffer(argumentBuffer, offset: offset, index: encoderIndex)
        }
    }
    
    func encode(_ bytes: UnsafeRawPointer, count: Int) {
        fatalError(.noArgumentBufferSupportForSingleUseData)
    }
    
    func encode(_ texture: MTLTexture) {
        fatalError() // error about that a texture is not an argument buffer
    }
    
    func encode(_ texture: MTLTexture, to path: Path) {
        validateArgumentBuffer()
        
        let dataTypePath = encoding.localDataTypePath(for: path)
        assert(dataTypePath.last!.isTexture, .invalidTexturePath(dataTypePath.last!))

        let index = queryIndex(for: path, dataTypePath: dataTypePath[1...])
        argumentEncoder.setTexture(texture, index: index)
    }
    
    func encode(_ bytes: UnsafeRawPointer, count: Int, to path: Path) {
        validateArgumentBuffer()
        
        let dataTypePath = encoding.localDataTypePath(for: path)
        assert(dataTypePath.last!.isBytes, .invalidBytesPath(dataTypePath.last!))
        
        let bytesIndex = queryIndex(for: path, dataTypePath: dataTypePath[1...])
        let destination = argumentEncoder.constantData(at: bytesIndex).assumingMemoryBound(to: UInt8.self)
        let source = bytes.assumingMemoryBound(to: UInt8.self)
        
        for i in 0 ..< count {
            destination[i] = source[i]
        }
    }
    
    func encode(_ buffer: MTLBuffer, offset: Int, to path: Path) {
        validateArgumentBuffer()

        let dataTypePath = encoding.localDataTypePath(for: path)
        
        switch dataTypePath.last! {
        case let .buffer(p): fallthrough
        case let .encodableBuffer(p):

            let pointerIndex = queryIndex(for: path, dataTypePath: dataTypePath[1...])
            argumentEncoder.setBuffer(buffer, offset: offset, index: pointerIndex)
            computeCommandEncoder.useResource(buffer, usage: p.access.usage)

        default: fatalError(.invalidBufferPath(dataTypePath.last!))
        }
    }
    
    func encode(_ buffer: MTLBuffer, offset: Int, to path: Path, _ encoderClosure: (BytesEncoder)->()) {
        validateArgumentBuffer()

        let childEncoding = encoding.childEncoding(for: path)
        
        guard case let .encodableBuffer(p) = childEncoding.dataType else {
            fatalError(.invalidEncodableBufferPath(childEncoding.dataType))
        }
        
        assert(buffer.length - offset >= p.dataSize, .invalidBuffer)

        let pointerIndex = queryIndex(for: path, dataTypePath: encoding.localDataTypePath(to: childEncoding)[1...])
        argumentEncoder.setBuffer(buffer, offset: offset, index: pointerIndex)
        computeCommandEncoder.useResource(buffer, usage: p.access.usage)
        
        encoderClosure(EncodableBufferEncoder(encoding: childEncoding,
                                              encodableBuffer: buffer,
                                              offset: offset))
    }

    func childEncoder(for path: Path) -> ArgumentBufferEncoder {
        validateArgumentBuffer()

        let childEncoding = encoding.childEncoding(for: path)
        let index = queryIndex(for: path, dataTypePath: encoding.localDataTypePath(to: childEncoding)[1...])
        
        return ArgumentBufferRootEncoder(encoding: childEncoding,
                                         encoderIndex: index,
                                         argumentEncoder: argumentEncoder.makeArgumentEncoderForBuffer(atIndex: index)!,
                                         parentArgumentEncoder: argumentEncoder,
                                         computeCommandEncoder: computeCommandEncoder)
    }
}

private extension ArgumentBufferRootEncoder {
    func validateArgumentBuffer() {
        assert(hasArgumentBuffer, .noArgumentBuffer)
    }
}

private class EncodableBufferEncoder {
    private let encoding: Parser.Encoding
    private let encodableBuffer: MTLBuffer
    private let offset: Int

    init(encoding: Parser.Encoding, encodableBuffer: MTLBuffer, offset: Int) {
        assert(encoding.dataType.isEncodableBuffer)
        
        self.encoding = encoding
        self.encodableBuffer = encodableBuffer
        self.offset = offset
    }
}

extension EncodableBufferEncoder: BytesEncoder {
    func encode(_ bytes: UnsafeRawPointer, count: Int, to path: Path) {
        let dataTypePath = encoding.localDataTypePath(for: path)
        assert(dataTypePath.last!.isBytes, .invalidBytesPath(dataTypePath.last!))

        let pathOffset = queryOffset(for: path, dataTypePath: dataTypePath[1...])
        let destination = encodableBuffer.contents().assumingMemoryBound(to: UInt8.self)
        let source = bytes.assumingMemoryBound(to: UInt8.self)
        
        for i in 0 ..< count {
            destination[offset + pathOffset + i] = source[i]
        }
    }    
}

private func queryIndex<DataTypeArray: RandomAccessCollection>(
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
        case .argumentTexture(let a): fallthrough
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

private func queryOffset<DataTypeArray: RandomAccessCollection>(
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

private extension MTLArgumentAccess {
    var usage: MTLResourceUsage {
        switch self {
        case .readOnly: return .read
        case .writeOnly: return .write
        case .readWrite: return [.read, .write]
        default: fatalError("Unknown usage.")
        }
    }
}
