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
        
    init(rootPath: Path,
         argumentPath: [Argument],
         parser: Parser,
         function: MTLFunction,
         computeCommandEncoder: MTLComputeCommandEncoder)
    {
        guard case .argument(let argument) = argumentPath.first else {
            fatalError("RootEncoder expects an argument path that starts with an argument.")
        }
        
        // path gurantees that there is at most a single argument encoder due to logic in parser
        assert(argumentPath.argumentEncoderCount <= 1)
        
        if let encoderPathIndex = argumentPath.firstArgumentEncoderIndex {
            internalEncoder = ArgumentEncoder(rootPath: rootPath,
                                              parser: parser,
                                              encoderIndex: argument.index,
                                              argumentIndex: encoderPathIndex,
                                              argumentEncoder: function.makeArgumentEncoder(bufferIndex: argument.index),
                                              parentArgumentEncoder: nil,
                                              computeCommandEncoder: computeCommandEncoder)
        } else {
            internalEncoder = RootArgumentEncoder(rootPath: rootPath,
                                                  argument: argument,
                                                  parser: parser,
                                                  function: function,
                                                  computeCommandEncoder: computeCommandEncoder)
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

class RootArgumentEncoder {
    private let rootPath: Path
    private let argument: MTLArgument
    private let function: MTLFunction
    private let parser: Parser

    private weak var computeCommandEncoder: MTLComputeCommandEncoder!
    private weak var argumentBuffer: MTLBuffer!
    
    private var bufferOffset: Int = 0

    init(rootPath: Path,
         argument: MTLArgument,
         parser: Parser,
         function: MTLFunction,
         computeCommandEncoder: MTLComputeCommandEncoder)
    {
        self.rootPath = rootPath
        self.argument = argument
        self.parser = parser
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

        let data = pathData(for: path)
        let pathType = queryPathType(for: data.argumentPath)
        assert(pathType.isBytes, .invalidBytesPath(pathType))

        // TODO: make sure that count is within argument length (i.e. prevent overflow)

        let pathOffset = queryOffset(for: data.absolutePath, argumentPath: data.argumentPath)
        let destination = argumentBuffer.contents().assumingMemoryBound(to: UInt8.self)
        let source = bytes.assumingMemoryBound(to: UInt8.self)
        
        for i in 0 ..< count {
            destination[bufferOffset + pathOffset + i] = source[i]
        }
    }
    
    func encode(_ buffer: MTLBuffer, offset: Int, to path: Path) {
        let data = pathData(for: path)
        let pathType = queryPathType(for: data.argumentPath)
        assert(pathType.isBuffer, .invalidBufferPath(pathType))
        
        let index = queryIndex(for: data.absolutePath, argumentPath: data.argumentPath)
        assert(index != argument.index) // shouldnt override argument buffer
        
        computeCommandEncoder.setBuffer(buffer, offset: offset, index: index)
    }
    
    func encode(_ buffer: MTLBuffer, offset: Int, to path: Path, _ encoderClosure: (Encoder)->()) {
        let data = pathData(for: path)
        let pathType = queryPathType(for: data.argumentPath)
        assert(pathType.isEncodableBuffer, .invalidBufferEncoderPath(pathType))
        
        fatalError("Logical error. MTLArgument does not access pointer of struct (encodable buffer)")
    }
    
    func childEncoder(for path: Path) -> ComputePipelineStateEncoder {
        let data = pathData(for: path, isPathToChildEncoder: true)
        let pathType = queryPathType(for: data.argumentPath)
        assert(pathType.isArgumentBuffer, .invalidChildEncoderPath(pathType))
        
        let index = queryIndex(for: data.absolutePath, argumentPath: data.argumentPath)
                
        return ArgumentEncoder(rootPath: data.absolutePath,
                               parser: parser,
                               encoderIndex: index,
                               argumentIndex: data.argumentPath.lastArgumentEncoderIndex!,
                               argumentEncoder: function.makeArgumentEncoder(bufferIndex: index),
                               parentArgumentEncoder: nil,
                               computeCommandEncoder: computeCommandEncoder)
    }
}

private extension RootArgumentEncoder {
    struct PathData {
        let absolutePath: Path
        let argumentPath: [Argument]
    }
    
    func pathData(for localPath: Path, isPathToChildEncoder: Bool = false) -> PathData {
        let absolutePath = rootPath + localPath
        let argumentPath = parser.safeArgumentPath(for: absolutePath)
        
        assert(validatePathLocality(for: argumentPath, isPathToChildEncoder: isPathToChildEncoder))

        return PathData(absolutePath: absolutePath, argumentPath: argumentPath)
    }
}

class ArgumentEncoder {
    private let rootPath: Path
    private let parser: Parser
    private let encoderIndex: Int
    private let argumentIndex: Int
    
    private let argumentEncoder: MTLArgumentEncoder
    private let parentArgumentEncoder: MTLArgumentEncoder?
    private weak var computeCommandEncoder: MTLComputeCommandEncoder!

    private var hasArgumentBuffer: Bool = false

    init(rootPath: Path,
         parser: Parser,
         encoderIndex: Int,
         argumentIndex: Int,
         argumentEncoder: MTLArgumentEncoder,
         parentArgumentEncoder: MTLArgumentEncoder?,
         computeCommandEncoder: MTLComputeCommandEncoder)
    {
        self.rootPath = rootPath
        self.parser = parser
        self.encoderIndex = encoderIndex
        self.argumentIndex = argumentIndex
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
        } else {
            computeCommandEncoder.setBuffer(argumentBuffer, offset: offset, index: encoderIndex)
        }
    }
    
    func encode(_ bytes: UnsafeRawPointer, count: Int, to path: Path) {
        validateArgumentBuffer()
        
        let argumentPath = localArgumentPath(for: path)
        let pathType = queryPathType(for: argumentPath)
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

        let argumentPath = localArgumentPath(for: path)
        let pathType = queryPathType(for: argumentPath)
        
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

        let argumentPath = localArgumentPath(for: path)
        let pathType = queryPathType(for: argumentPath)
        
        guard case let .encodableBuffer(p, s) = pathType else {
            fatalError(.invalidBufferEncoderPath(pathType))
        }

        // TODO: use encoder ...
        let pointerIndex = queryIndex(for: path, argumentPath: argumentPath)
        argumentEncoder.setBuffer(buffer, offset: offset, index: pointerIndex)
        computeCommandEncoder.useResource(buffer, usage: p.access.usage)
    }

    func childEncoder(for path: Path) -> ComputePipelineStateEncoder {
        validateArgumentBuffer()

        let encoderPath = rootPath + path
        let argumentPath = localArgumentPath(for: path, isPathToChildEncoder: true)
        let pathType = queryPathType(for: argumentPath)
        assert(pathType.isArgumentBuffer, .invalidChildEncoderPath(pathType))

        let index = queryIndex(for: path, argumentPath: argumentPath)

        return ArgumentEncoder(rootPath: encoderPath,
                               parser: parser,
                               encoderIndex: index,
                               argumentIndex: argumentPath.lastArgumentEncoderIndex!,
                               argumentEncoder: argumentEncoder.makeArgumentEncoderForBuffer(atIndex: index)!,
                               parentArgumentEncoder: argumentEncoder,
                               computeCommandEncoder: computeCommandEncoder)
    }
}

private extension ArgumentEncoder {
    func validateArgumentBuffer() {
        assert(hasArgumentBuffer, .noArgumentBuffer)
    }
    
    func localArgumentPath(for localPath: Path, isPathToChildEncoder: Bool = false) -> ArraySlice<Argument> {
        let absolutePath = rootPath + localPath
        let localArgumentPath = parser.safeArgumentPath(for: absolutePath)[(argumentIndex + 1)...]
        
        assert(validatePathLocality(for: localArgumentPath, isPathToChildEncoder: isPathToChildEncoder))

        return localArgumentPath
    }
}

private func queryPathType<ArgumentArray: RandomAccessCollection>(
    for argumentPath: ArgumentArray
) -> PathType
    where ArgumentArray.Element == Argument
{
    assert(!argumentPath.isEmpty)
    
    var candidateType: PathType!
    
    for argument in argumentPath {
        switch argument {
        case .argument(let a): candidateType = .argument(a)
        case .structMember(let s): candidateType = .bytes(s)
        case .pointer(let p) where p.elementIsArgumentBuffer: candidateType = .argumentBuffer(p)
        case .pointer(let p) where !p.elementIsArgumentBuffer: candidateType = .buffer(p)
        case .struct(let s):
            if case .buffer(let p) = candidateType {
                candidateType = .encodableBuffer(p, s)
            }
        default: break
        }
    }

    return candidateType
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
        case .array(let a):
            assert(pathIndex < path.count, .invalidPathStructure(pathIndex))
            
            guard let inputIndex = path[pathIndex].index else {
                fatalError(.invalidPathIndexPlacement(pathIndex))
            }
            
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
            assert(pathIndex < path.count, .invalidPathStructure(pathIndex))
            
            guard let index = path[pathIndex].index else {
                fatalError(.invalidPathIndexPlacement(pathIndex))
            }
            
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

private func validatePathLocality<ArgumentArray: RandomAccessCollection>(
    for argumentPath: ArgumentArray,
    isPathToChildEncoder: Bool
) -> Bool
    where ArgumentArray.Element == Argument
{
    assert(!argumentPath.isEmpty)

    var pathIndex: Int = 0

    for (index, item) in argumentPath.enumerated() {
        switch item {
        case .argument: pathIndex += 1
        case .array: pathIndex += 1
        case .structMember(let s):
            // ignore array struct as argument since they are not part of path
            if s.dataType != .array {
                pathIndex += 1
            }
        case .pointer(let p):
            // TODO: check encounters with pointer to pointer

            if isPathToChildEncoder {
                // only last item is allowed to be an argument buffer pointer, if path is specified as such
                assert(index >= argumentPath.count - 2 && p.elementIsArgumentBuffer, .invalidEncoderPath(pathIndex))
            } else {
                assert(index >= argumentPath.count - 2 && !p.elementIsArgumentBuffer, .invalidEncoderPath(pathIndex))
            }
        default: break
        }
    }

    return true
}


//    func makeArgumentEncoder(from encoder: Encoder, argumentPath: [Parser.Argument], alignment: Int) -> Encoder {
//        let childEncoder: MTLArgumentEncoder
//
//
//        // argument encoder requires encoding the buffer into parent in the original index
//        switch encoder {
//        case .computeCommandEncoder(let e):
//            let index = self.index(from: argumentPath)
//            let offset =  0//baseOffset(from: argumentPath).aligned(by: alignment)
//
//            childEncoder = function.makeArgumentEncoder(bufferIndex: index)
//            e.setBuffer(argumentBuffer, offset: offset, index: index)
//            childEncoder.setArgumentBuffer(argumentBuffer, offset: offset)
//
//        case .argumentEncoder(let e):
//            let index = localIndex(from: argumentPath)
//            let offset = nestedBaseOffset(from: argumentPath)
//
//            childEncoder = e.makeArgumentEncoderForBuffer(atIndex: index)!
//            e.setBuffer(argumentBuffer, offset: offset, index: index)
//            childEncoder.setArgumentBuffer(argumentBuffer, offset: offset)
//        }
//
//
//        return .argumentEncoder(childEncoder)
//    }
//

private extension Parser {
    func safeArgumentPath(for path: Path) -> [Argument] {
        guard let argumentPath = argumentPath(for: path) else {
            fatalError(.nonExistingPath)
        }
        
        return argumentPath
    }
}

private extension Argument {
    var index: Int? {
        switch self {
        case .argument(let a): return a.index
        case .structMember(let s): return s.argumentIndex
        default: return nil
        }
    }
}

// required for comparison without associated value
private extension PathType {
    var isArgument: Bool {
        if case .argument = self {
            return true
        }
        return false
    }
    
    var isBytes: Bool {
        if case .bytes = self {
            return true
        }
        return false
    }
    
    var isBuffer: Bool {
        if case .buffer = self {
            return true
        }
        return false
    }

    var isArgumentBuffer: Bool {
        if case .argumentBuffer = self {
            return true
        }
        return false
    }
    
    var isEncodableBuffer: Bool {
        if case .encodableBuffer = self {
            return true
        }
        return false
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

private extension PathComponent {
    var index: UInt? {
        switch self {
        case .index(let i): return i
        default: return nil
        }
    }
}

private extension RandomAccessCollection where Element == Argument, Index == Int {
    var argumentEncoderCount: Index {
        return reduce(0) {
            switch $1 {
            case .pointer(let p) where p.elementIsArgumentBuffer:
                return $0 + 1
            default: return $0
            }
        }
    }
    
    var firstArgumentEncoderIndex: Index? {
        return firstIndex {
            switch $0  {
            case .pointer(let p): return p.elementIsArgumentBuffer
            default: return false
            }
        }
    }
    
    var lastArgumentEncoderIndex: Index? {
        return lastIndex {
            switch $0  {
            case .pointer(let p): return p.elementIsArgumentBuffer
            default: return false
            }
        }
    }
}
