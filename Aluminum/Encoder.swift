//
//  Encoder.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 20/01/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal


public protocol Encoder {

    func encode(_ bytes: UnsafeRawPointer, count: Int, to path: Path)
    
    func encode(_ buffer: MTLBuffer, offset: Int, to path: Path)
    
    func encode(_ buffer: MTLBuffer, offset: Int, to path: Path, _ encoderClosure: (Encoder)->())

    // TODO: missing stubs for texture/...

}

public protocol ComputePipelineStateEncoder: Encoder {
    var encodedLength: Int { get } 

    func setArgumentBuffer(_ argumentBuffer: MTLBuffer, offset: Int)
    
    // issue warning if bytes is above 4k (i.e. count or enoder call)
    func encode(_ bytes: UnsafeRawPointer, count: Int) // copy bytes to root
    // throw when in argument buffer
    
    func childEncoder(for path: Path) -> ComputePipelineStateEncoder
}

public extension Encoder {
    func encode(_ buffer: MTLBuffer, to path: Path)  {
        encode(buffer, offset: 0, to: path)
    }
    
    func encode(_ buffer: MTLBuffer, to path: Path, _ encoderClosure: (Encoder)->()) {
        encode(buffer, offset: 0, to: path, encoderClosure)
    }

    func encode<T>(_ parameter: T, to path: Path) {
        withUnsafePointer(to: parameter) { ptr in
            encode(ptr, count: MemoryLayout<T>.stride, to: path)
        }
    }
}

public extension ComputePipelineStateEncoder {
    func setArgumentBuffer(_ argumentBuffer: MTLBuffer) {
        setArgumentBuffer(argumentBuffer, offset: 0)
    }
    
    func encode<T>(_ parameter: T) {
        withUnsafePointer(to: parameter) { ptr in
            encode(ptr, count: MemoryLayout<T>.size * 5)
        }
    }
}

class RootEncoder {
    private let internalEncoder: ComputePipelineStateEncoder
        
    init(encoding: Parser.Encoding,
         rootPath: Path,
         function: MTLFunction,
         computeCommandEncoder: MTLComputeCommandEncoder)
    {
        switch encoding.dataType {
        case .argument:
            internalEncoder = RootArgumentEncoder(encoding: encoding,
                                                  function: function,
                                                  computeCommandEncoder: computeCommandEncoder)
        case .argumentContainingArgumentBuffer:
            let index = queryIndex(for: rootPath, dataTypePath: encoding.dataTypePath)
            internalEncoder = ArgumentEncoder(encoding: encoding,
                                              encoderIndex: index,
                                              argumentEncoder: function.makeArgumentEncoder(bufferIndex: index),
                                              parentArgumentEncoder: nil,
                                              computeCommandEncoder: computeCommandEncoder)
        default: fatalError("RootEncoder must start with an argument.")
        }
    }
}

extension RootEncoder: ComputePipelineStateEncoder {
    var encodedLength: Int {
        return internalEncoder.encodedLength
    }
    
    func setArgumentBuffer(_ argumentBuffer: MTLBuffer, offset: Int) {
        internalEncoder.setArgumentBuffer(argumentBuffer, offset: offset)
    }
    
    func encode(_ bytes: UnsafeRawPointer, count: Int) {
        internalEncoder.encode(bytes, count: count)
    }
    
    func encode(_ bytes: UnsafeRawPointer, count: Int, to path: Path) {
        internalEncoder.encode(bytes, count: count, to: path)
    }

    func encode(_ buffer: MTLBuffer, offset: Int, to path: Path) {
        internalEncoder.encode(buffer, offset: offset, to: path)
    }
    
    func encode(_ buffer: MTLBuffer, offset: Int, to path: Path, _ encoderClosure: (Encoder) -> ()) {
        internalEncoder.encode(buffer, offset: offset, to: path, encoderClosure)
    }

    func childEncoder(for path: Path) -> ComputePipelineStateEncoder {
        return internalEncoder.childEncoder(for: path)
    }
}


private class RootArgumentEncoder {
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
            fatalError("RootEncoder expects an argument path that starts with an argument.")
        }

        self.encoding = encoding
        self.function = function
        self.argument = argument
        self.computeCommandEncoder = computeCommandEncoder
    }
}

extension RootArgumentEncoder: ComputePipelineStateEncoder {
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
    
    func encode(_ bytes: UnsafeRawPointer, count: Int, to path: Path) {
        assert(!didCopyBytes) // TODO: add error that setting value to specific location after using encode will override previous data
        assert(argumentBuffer != nil, .noArgumentBuffer)

        // get index of path and make copyBytes ...  that will override previos call
        
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
    
    func encode(_ buffer: MTLBuffer, offset: Int, to path: Path, _ encoderClosure: (Encoder)->()) {
        let dataTypePath = encoding.localDataTypePath(for: path)
        assert(dataTypePath.last!.isEncodableBuffer, .invalidEncodableBufferPath(dataTypePath.last!))
        
        fatalError("Logical error. MTLArgument does not access pointer of struct (encodable buffer)")
    }
    
    func childEncoder(for path: Path) -> ComputePipelineStateEncoder {
        let childEncoding = encoding.childEncoding(for: path)
        let index = queryIndex(for: path, dataTypePath: childEncoding.dataTypePath)
                        
        return ArgumentEncoder(encoding: childEncoding,
                               encoderIndex: index,
                               argumentEncoder: function.makeArgumentEncoder(bufferIndex: index),
                               parentArgumentEncoder: nil,
                               computeCommandEncoder: computeCommandEncoder)
    }
}

private class ArgumentEncoder {
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
        case let .argumentBuffer(p, _): pointer = p
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

extension ArgumentEncoder: ComputePipelineStateEncoder {
    var encodedLength: Int {
        return argumentEncoder.encodedLength
    }
    
    func setArgumentBuffer(_ argumentBuffer: MTLBuffer, offset: Int) {
        assert(argumentBuffer.length - offset >= encodedLength, .invalidArgumentBuffer)

        hasArgumentBuffer = true
        argumentEncoder.setArgumentBuffer(argumentBuffer, offset: offset)
        
        // TODO: check if required
        if let parentArgumentEncoder = parentArgumentEncoder {
            parentArgumentEncoder.setBuffer(argumentBuffer, offset: offset, index: encoderIndex)
            computeCommandEncoder.useResource(argumentBuffer, usage: pointer.access.usage)
        } else {
            computeCommandEncoder.setBuffer(argumentBuffer, offset: offset, index: encoderIndex)
        }
    }
    
    func encode(_ bytes: UnsafeRawPointer, count: Int) {
        fatalError() // TODO: add error regarding inability of argument buffer encoder to use setBytes since its an argument buffer
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
        case let .buffer(p, _): fallthrough
        case let .encodableBuffer(p, _, _):

            let pointerIndex = queryIndex(for: path, dataTypePath: dataTypePath[1...])
            argumentEncoder.setBuffer(buffer, offset: offset, index: pointerIndex)
            computeCommandEncoder.useResource(buffer, usage: p.access.usage)

        default: fatalError(.invalidBufferPath(dataTypePath.last!))
        }
    }
    
    func encode(_ buffer: MTLBuffer, offset: Int, to path: Path, _ encoderClosure: (Encoder)->()) {
        validateArgumentBuffer()

        let childEncoding = encoding.childEncoding(for: path)
        
        guard case let .encodableBuffer(p, _, _) = childEncoding.dataType else {
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

    func childEncoder(for path: Path) -> ComputePipelineStateEncoder {
        validateArgumentBuffer()

        let childEncoding = encoding.childEncoding(for: path)
        let index = queryIndex(for: path, dataTypePath: encoding.localDataTypePath(to: childEncoding)[1...])

        return ArgumentEncoder(encoding: childEncoding,
                               encoderIndex: index,
                               argumentEncoder: argumentEncoder.makeArgumentEncoderForBuffer(atIndex: index)!,
                               parentArgumentEncoder: argumentEncoder,
                               computeCommandEncoder: computeCommandEncoder)
    }
}

private extension ArgumentEncoder {
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

extension EncodableBufferEncoder: Encoder {
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
    
    func encode(_ buffer: MTLBuffer, offset: Int, to path: Path) {
        // need reference to argument encoder
        fatalError("Find case")
    }
    
    func encode(_ buffer: MTLBuffer, offset: Int, to path: Path, _ encoderClosure: (Encoder)->()) {
        // need reference to argument encoder
        fatalError("Find case")
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
        case .argument(let a):
            index += a.index
            pathIndex += 1
        case .buffer(_, let s): fallthrough
        case .argumentBuffer(_, let s): fallthrough
        case .encodableBuffer(_, _, let s): fallthrough
        case .bytes(_, let s) where s.dataType != .array:
            index += s.argumentIndex
            pathIndex += 1
        case .bytes(let t, let s) where s.dataType == .array:
            guard case let .array(a) = t else { fatalError() }
            
            let inputIndex = path[pathIndex].index!
            assert(inputIndex >= 0 && inputIndex < a.arrayLength, .pathIndexOutOfBounds(pathIndex))
            
            index += a.argumentIndexStride * Int(inputIndex) + s.argumentIndex
            pathIndex += 1
        default: break
        }
        
    }
    
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
        case .buffer(_, let s): fallthrough
        case .argumentBuffer(_, let s): fallthrough
        case .encodableBuffer(_, _, let s): fallthrough
        case .bytes(_, let s) where s.dataType != .array:
            offset += s.offset
        case .bytes(let t, let s) where s.dataType == .array:
            guard case let .array(a) = t else { fatalError() }
            
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

private extension MetalType {
    var index: Int? {
        switch self {
        case .argument(let a): return a.index
        case .structMember(let s): return s.argumentIndex
        default: return nil
        }
    }
    
    var pointer: MTLPointerType? {
        guard case let .pointer(p) = self else {
            return nil
        }
        
        return p
    }
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
