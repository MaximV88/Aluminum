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
    
    // TODO: throw if not struct
    func encode(_ buffer: MTLBuffer, offset: Int, to path: Path, _ encoderClosure: (Encoder)->())

    // TODO: missing stubs for texture/...

}

public protocol ComputePipelineStateEncoder: Encoder {
    var encodedLength: Int { get }

    func setArgumentBuffer(_ argumentBuffer: MTLBuffer, offset: Int)
    
    func childEncoder(for path: Path) -> ComputePipelineStateEncoder
}

public extension Encoder {
    func encode(_ buffer: MTLBuffer, to path: Path)  {
        encode(buffer, offset: 0, to: path)
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
}

class RootEncoder {
    private let internalEncoder: ComputePipelineStateEncoder
        
    init(encoding: Parser.Encoding,
         rootPath: Path,
         function: MTLFunction,
         computeCommandEncoder: MTLComputeCommandEncoder)
    {
        switch encoding.pathType {
        case .argument:
            internalEncoder = RootArgumentEncoder(encoding: encoding,
                                                  function: function,
                                                  computeCommandEncoder: computeCommandEncoder)
        case .argumentContainingArgumentBuffer:
            let index = queryIndex(for: rootPath, argumentPath: encoding.argumentPath)
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

    init(encoding: Parser.Encoding,
         function: MTLFunction,
         computeCommandEncoder: MTLComputeCommandEncoder)
    {
        guard case let .argument(argument) = encoding.argumentPath.first else {
            fatalError("RootEncoder expects an argument path that starts with an argument.")
        }
        
        self.encoding = encoding
        self.argument = argument
        self.function = function
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
    
    func encode(_ bytes: UnsafeRawPointer, count: Int, to path: Path) {
        assert(argumentBuffer != nil, .noArgumentBuffer)

        let argumentPath = encoding.argumentPath(for: path)
        let pathType = lastPathType(for: argumentPath)
        assert(pathType.isBytes, .invalidBytesPath(pathType))

        // TODO: make sure that count is within argument length (i.e. prevent overflow)

        let pathOffset = queryOffset(for: path, argumentPath: argumentPath)
        let destination = argumentBuffer.contents().assumingMemoryBound(to: UInt8.self)
        let source = bytes.assumingMemoryBound(to: UInt8.self)
        
        for i in 0 ..< count {
            destination[bufferOffset + pathOffset + i] = source[i]
        }
    }
    
    func encode(_ buffer: MTLBuffer, offset: Int, to path: Path) {
        let argumentPath = encoding.argumentPath(for: path)
        let pathType = lastPathType(for: argumentPath)
        assert(pathType.isBuffer, .invalidBufferPath(pathType))
        
        let index = queryIndex(for: path, argumentPath: argumentPath)
        assert(index != argument.index) // shouldnt override argument buffer
        
        computeCommandEncoder.setBuffer(buffer, offset: offset, index: index)
    }
    
    func encode(_ buffer: MTLBuffer, offset: Int, to path: Path, _ encoderClosure: (Encoder)->()) {
        let argumentPath = encoding.argumentPath(for: path)
        let pathType = lastPathType(for: argumentPath)
        assert(pathType.isEncodableBuffer, .invalidBufferEncoderPath(pathType))
        
        fatalError("Logical error. MTLArgument does not access pointer of struct (encodable buffer)")
    }
    
    func childEncoder(for path: Path) -> ComputePipelineStateEncoder {
        let childEncoding = encoding.childEncoding(for: path)
        let index = queryIndex(for: path, argumentPath: childEncoding.argumentPath)
                        
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
        switch encoding.pathType {
        case .argumentBuffer(let p): pointer = p
        case .argumentContainingArgumentBuffer(_, let p): pointer = p
        default: fatalError("Invalid instantiation of encoder per encoding type.")
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
    
    func encode(_ bytes: UnsafeRawPointer, count: Int, to path: Path) {
        validateArgumentBuffer()
        
        let argumentPath = encoding.localArgumentPath(for: path)
        let pathType = lastPathType(for: argumentPath)
        assert(pathType.isBytes, .invalidBytesPath(pathType))
        
        // TODO: make sure that count is within argument length (i.e. prevent overflow)
        let bytesIndex = queryIndex(for: path, argumentPath: argumentPath)
        let destination = argumentEncoder.constantData(at: bytesIndex).assumingMemoryBound(to: UInt8.self)
        let source = bytes.assumingMemoryBound(to: UInt8.self)
        
        for i in 0 ..< count {
            destination[i] = source[i]
        }
    }
    
    func encode(_ buffer: MTLBuffer, offset: Int, to path: Path) {
        validateArgumentBuffer()

        let argumentPath = encoding.localArgumentPath(for: path)
        let pathType = lastPathType(for: argumentPath)
        
        switch pathType {
        case let .buffer(p): fallthrough
        case let .encodableBuffer(p, _):

            let pointerIndex = queryIndex(for: path, argumentPath: argumentPath)
            argumentEncoder.setBuffer(buffer, offset: offset, index: pointerIndex)
            computeCommandEncoder.useResource(buffer, usage: p.access.usage)

        default: fatalError(.invalidBufferPath(pathType))
        }
    }
    
    func encode(_ buffer: MTLBuffer, offset: Int, to path: Path, _ encoderClosure: (Encoder)->()) {
        validateArgumentBuffer()

        let argumentPath = encoding.localArgumentPath(for: path)
        let childEncoding = encoding.childEncoding(for: path)
        
        guard case let .encodableBuffer(p, _) = childEncoding.pathType else {
            fatalError(.invalidBufferEncoderPath(childEncoding.pathType)) // TODO: change to invalid encodable buffer ...
        }

        // TODO: use encoder ...
        let pointerIndex = queryIndex(for: path, argumentPath: argumentPath)
        argumentEncoder.setBuffer(buffer, offset: offset, index: pointerIndex)
        computeCommandEncoder.useResource(buffer, usage: p.access.usage)
    }

    func childEncoder(for path: Path) -> ComputePipelineStateEncoder {
        validateArgumentBuffer()

        let childEncoding = encoding.childEncoding(for: path)
        let index = queryIndex(for: path, argumentPath: childEncoding.localArgumentPath)

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

private class BytesEncoder {
    private let encoding: Parser.Encoding

    init(encoding: Parser.Encoding) {
        self.encoding = encoding
    }
}

private func queryIndex<ArgumentArray: RandomAccessCollection>(
    for path: Path,
    argumentPath: ArgumentArray
) -> Int
    where ArgumentArray.Element == Argument
{
    assert(!path.isEmpty)
    assert(!argumentPath.isEmpty)

    var index = 0
    var pathIndex: Int = 0

    for item in argumentPath {
        switch item {
        case .argument(let a):
            index += a.index
            pathIndex += 1
        case .array(let a):
            let inputIndex = path[pathIndex].index!
            
            assert(inputIndex >= 0 && inputIndex < a.arrayLength, .pathIndexOutOfBounds(pathIndex))

            index += a.argumentIndexStride * Int(inputIndex)
            pathIndex += 1
        case .structMember(let s):
            index += s.argumentIndex
            
            // ignore array struct as argument since they are not part of path
            if s.dataType != .array {
                pathIndex += 1
            }
 
        default: break
        }
    }
    
    return index
}

private func queryOffset<ArgumentArray: RandomAccessCollection>(
    for path: Path,
    argumentPath: ArgumentArray
) -> Int
    where ArgumentArray.Element == Argument
{
    assert(!path.isEmpty)
    assert(!argumentPath.isEmpty)

    var offset: Int = 0
    var pathIndex: Int = 0
    
    for item in argumentPath {
        switch item {
        case .argument:
            pathIndex += 1
        case .array(let a):
            let index = path[pathIndex].index!
            assert(index >= 0 && index < a.arrayLength, .pathIndexOutOfBounds(pathIndex))
            
            offset += Int(index) * a.stride
            pathIndex += 1
        case .structMember(let s):
            offset += s.offset

            // ignore array struct as argument since they are not part of path
            if s.dataType != .array {
                pathIndex += 1
            }
        default: break
        }
    }
    
    // expect entire path iteration
    assert(pathIndex == path.count)
    
    return offset
}

private extension Argument {
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

private extension Int {
    func aligned(by alignment: Int) -> Int {
        return (((self + (alignment - 1)) / alignment) * alignment)
    }
    
    mutating func align(by alignment: Int) {
        self = aligned(by: alignment)
    }
}
