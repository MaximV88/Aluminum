//
//  Encoder.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 20/01/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal


public protocol ComputePipelineStateEncoder {
    var encodedLength: UInt { get }

    func setArgumentBuffer(_ argumentBuffer: MTLBuffer, offset: Int)
    
    func encode(bytes: UnsafeRawPointer, count: Int, to path: Path) throws

    func encode(buffer: MTLBuffer, offset: Int, to path: Path) throws

    // TODO: missing stubs for texture/...
    
    // child encoder is only applicable on pointers
    func childEncoder(for path: Path) throws -> ComputePipelineStateEncoder
}

public extension ComputePipelineStateEncoder {
    func setArgumentBuffer(_ argumentBuffer: MTLBuffer) {
        setArgumentBuffer(argumentBuffer, offset: 0)
    }
    
    func encode(buffer: MTLBuffer, to path: Path) throws  {
        try encode(buffer: buffer, offset: 0, to: path)
    }

    func encode<T>(_ parameter: T, to path: Path) throws {
        try withUnsafePointer(to: parameter) { ptr in
            try encode(bytes: ptr, count: MemoryLayout<T>.stride, to: path)
        }
    }
}


// 3 types of encoders that need to support ComputePipelineStateEncoder:
// 1. RootEncoder - root up to pointer of argument encoder
// 2. ArgumentEncoder - up to pointer that is not an argument encoder, otherwise creates child
// 3. InternalArgumentEncoder - non argument encoder pointer

// since argument buffer is set manually, no need to calculate offset


class RootEncoder {
    private let internalEncoder: ComputePipelineStateEncoder
        
    init(rootPath: Path,
         argument: MTLArgument,
         parser: Parser,
         function: MTLFunction,
         computeCommandEncoder: MTLComputeCommandEncoder)
    {
        if let argumentPath = parser.argumentPath(for: rootPath),
            argumentPath.count > 1,
            case let .pointer(pointer) = argumentPath[1],
            pointer.elementIsArgumentBuffer {
            // TODO: argument path index to start local argument path
            internalEncoder = ArgumentEncoder(rootPath: rootPath,
                                              parser: parser,
                                              encoderIndex: argument.index,
                                              argumentIndex: 1 ,
                                              argumentEncoder: function.makeArgumentEncoder(bufferIndex: argument.index),
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
    var encodedLength: UInt {
        return internalEncoder.encodedLength
    }
    
    func setArgumentBuffer(_ argumentBuffer: MTLBuffer, offset: Int) {
        internalEncoder.setArgumentBuffer(argumentBuffer, offset: offset)
    }
    
    func encode(bytes: UnsafeRawPointer, count: Int, to path: Path) throws {
        try internalEncoder.encode(bytes: bytes, count: count, to: path)
    }

    func encode(buffer: MTLBuffer, offset: Int, to path: Path) throws {
        try internalEncoder.encode(buffer: buffer, offset: offset, to: path)
    }

    func childEncoder(for path: Path) throws -> ComputePipelineStateEncoder {
        return try internalEncoder.childEncoder(for: path)
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
    var encodedLength: UInt {
        return UInt(argument.bufferDataSize)
    }
    
    func setArgumentBuffer(_ argumentBuffer: MTLBuffer, offset: Int) {
        precondition(argumentBuffer.length >= encodedLength)
        self.argumentBuffer = argumentBuffer
        self.bufferOffset = offset
        
        computeCommandEncoder.setBuffer(argumentBuffer, offset: offset, index: argument.index)
    }
    
    func encode(bytes: UnsafeRawPointer, count: Int, to path: Path) throws {
        let pathOffset = try offset(for: rootPath + path)

        let destination = argumentBuffer.contents().assumingMemoryBound(to: UInt8.self)
        let source = bytes.assumingMemoryBound(to: UInt8.self)
        
        for i in 0 ..< count {
            destination[bufferOffset + pathOffset + i] = source[i]
        }
    }
    
    func encode(buffer: MTLBuffer, offset: Int, to path: Path) throws {
        guard let argumentPath = parser.argumentPath(for: path) else {
            throw ComputePipelineStateController.ControllerError.nonExistingPath
        }
        
        let index = try pointerIndex(for: argumentPath)
        assert(index != argument.index)

        computeCommandEncoder.setBuffer(buffer, offset: offset, index: index)
    }
    
    func childEncoder(for path: Path) throws -> ComputePipelineStateEncoder {
        let encoderPath = rootPath + path
        
        guard let argumentPath = parser.argumentPath(for: path) else {
            throw ComputePipelineStateController.ControllerError.nonExistingPath
        }
        
        let index = try pointerIndex(for: argumentPath)
                
        return ArgumentEncoder(rootPath: encoderPath,
                               parser: parser,
                               encoderIndex: index,
                               argumentIndex: argumentPath.count - 1,
                               argumentEncoder: function.makeArgumentEncoder(bufferIndex: index),
                               computeCommandEncoder: computeCommandEncoder)
    }
}

private extension RootArgumentEncoder {
    func pointerIndex(for argumentPath: [Argument]) throws -> Int {
        guard case .pointer = argumentPath.last else {
            throw ComputePipelineStateController.ControllerError.invalidBufferPath
        }
        
        guard case .argument(let a) = argumentPath.first else {
            fatalError("RootArgumentEncoder root must be an MTLArgument.")
        }
        
        var lastNamedArgument = a.name
        var index = a.index
        
        // first and last are already accounted for
        for item in argumentPath[1...(argumentPath.count - 1)] {
            switch item {
            case .structMember(let s):
                lastNamedArgument = s.name
                index += s.argumentIndex
            case .pointer:
                throw ComputePipelineStateController.ControllerError.invalidEncoderPath(lastNamedArgument)
            default: break
            }
        }
        
        return index
    }

    func offset(for path: Path) throws -> Int {
        guard let argumentPath = parser.argumentPath(for: path) else {
            throw ComputePipelineStateController.ControllerError.nonExistingPath
        }

        var offset: Int = 0
        var pathIndex: Int = 0
        
        for item in argumentPath {
            switch item {
            case .array(let array):
                guard let index = path[pathIndex].index else {
                    throw ComputePipelineStateController.ControllerError.invalidPathIndexPlacement(pathIndex)
                }
                
                offset += Int(index) * array.stride
                pathIndex += 1
            case .structMember(let s):
                guard s.dataType != .pointer else {
                    throw ComputePipelineStateController.ControllerError.invalidEncoderPath(s.name)
                }
                
                offset += s.offset
                pathIndex += 1
            default: break
            }
        }
        
        // expect entire path iteration
        assert(pathIndex == path.count)
        
        return offset
    }
}

class ArgumentEncoder {
    private let rootPath: Path
    private let parser: Parser
    private let encoderIndex: Int
    private let argumentIndex: Int
    
    private let argumentEncoder: MTLArgumentEncoder
    private weak var computeCommandEncoder: MTLComputeCommandEncoder!

    init(rootPath: Path,
         parser: Parser,
         encoderIndex: Int,
         argumentIndex: Int,
         argumentEncoder: MTLArgumentEncoder,
         computeCommandEncoder: MTLComputeCommandEncoder)
    {
        self.rootPath = rootPath
        self.parser = parser
        self.encoderIndex = encoderIndex
        self.argumentIndex = argumentIndex
        self.argumentEncoder = argumentEncoder
        self.computeCommandEncoder = computeCommandEncoder
    }
}

extension ArgumentEncoder: ComputePipelineStateEncoder {
    var encodedLength: UInt {
        return UInt(argumentEncoder.encodedLength)
    }
    
    func setArgumentBuffer(_ argumentBuffer: MTLBuffer, offset: Int) {
        argumentEncoder.setArgumentBuffer(argumentBuffer, offset: offset)
        computeCommandEncoder.setBuffer(argumentBuffer, offset: offset, index: encoderIndex)
    }
    
    func encode(bytes: UnsafeRawPointer, count: Int, to path: Path) throws {
        guard let argumentPath = parser.argumentPath(for: rootPath + path) else {
            throw ComputePipelineStateController.ControllerError.nonExistingPath
        }
        
        if case .pointer = argumentPath.last {
            throw ComputePipelineStateController.ControllerError.invalidBytesPath
        }
        
        let index = try self.index(for: path, argumentPath: argumentPath[(argumentIndex + 1)...(argumentPath.count - 1)])
        let destination = argumentEncoder.constantData(at: index).assumingMemoryBound(to: UInt8.self)
        let source = bytes.assumingMemoryBound(to: UInt8.self)

        for i in 0 ..< count {
            destination[i] = source[i]
        }
    }
    
    func encode(buffer: MTLBuffer, offset: Int, to path: Path) throws {
        guard let argumentPath = parser.argumentPath(for: rootPath + path) else {
            throw ComputePipelineStateController.ControllerError.nonExistingPath
        }
        
        guard case .pointer(let p) = argumentPath.last else {
            throw ComputePipelineStateController.ControllerError.invalidBufferPath
        }
        
        let index = try self.index(for: path, argumentPath: argumentPath[(argumentIndex + 1)...(argumentPath.count - 2)])
        argumentEncoder.setBuffer(buffer, offset: offset, index: index)
        computeCommandEncoder.useResource(buffer, usage: p.access.usage)
    }

    func childEncoder(for path: Path) throws -> ComputePipelineStateEncoder {
        // should differ by .pointer being arg or not
        return self
    }
}

private extension ArgumentEncoder {
    func index(for path: Path, argumentPath: ArraySlice<Argument>) throws -> Int {
        // in argument encoder, the starting argument is a struct (by definition)
        var lastNamedArgument: String!
        var index = 0
        var pathIndex: Int = 0

        // pointers are not expected in argument since each pointer represents an encoder
        for item in argumentPath {
            switch item {
            case .array(let a):
                guard let inputIndex = path[pathIndex].index else {
                    throw ComputePipelineStateController.ControllerError.invalidPathIndexPlacement(pathIndex)
                }

                index += a.argumentIndexStride * Int(inputIndex)
                pathIndex += 1
            case .structMember(let s):
                lastNamedArgument = s.name
                index += s.argumentIndex
                
                // ignore array struct as argument since they are not part of path
                if s.dataType != .array {
                    pathIndex += 1
                }
            case .pointer:
                throw ComputePipelineStateController.ControllerError.invalidEncoderPath(lastNamedArgument)
            default: break
            }
        }
        
        return index
    }
}

//    func applyArgumentEncoder(_ encoder: Encoder,
//                              argumentPath: [Parser.Argument],
//                              bindings: [ComputePipelineStateController.Binder.Binding])
//    {
//        guard case .argumentEncoder(let argumentEncoder) = encoder else {
//            return
//        }
//
//        // argument encoders use local indices
//        let index = localIndex(from: argumentPath)
//
//        // bytes are encoded using 'constantData', index starts at nested type, not at origin.
//        let bytesBaseOffset = -nestedBaseOffset(from: argumentPath)
//
//        argumentEncoder.setBuffer(argumentBuffer, offset: 19200, index: index) // from encoding
//
//
//        for binding in bindings {
//            switch binding.value {
//            case .bytes(let data):
//
//                let destination = buf.contents().assumingMemoryBound(to: UInt8.self) // cont data points to arg buffer ...
//                // keep ref of previous buffer in case of buffer
////                let indexOffset =  offset(for: binding.indexPath, from: argumentPath)
//
//                // ptr offset
//                encode(data, destination: destination, offset: 0) // calculate offset manually ... from pointer to struct that buf points to
//                // this means that need to keep buf, and pointer in case that it doesnt have an argument encoder
//                // need to create a custom argument encoder that takes a parameter a buffer and d
//
//            case .buffer(let buffer, let offset):
//
//                argumentEncoder.setBuffer(buffer, offset: offset, index: index)
//                buf = buffer
//                // buffer encoding assumes pointer argument
//                computeCommandEncoder.useResource(buffer, usage: argumentPath.last!.usage!)// probably crash since this needs a pointer arg
//
//            case .custom(let encodable): break
//            }
//        }
//    }
//
//    func applyComputeCommandEncoder(_ encoder: Encoder,
//                                    argumentPath: [Parser.Argument],
//                                    bindings: [ComputePipelineStateController.Binder.Binding])
//    {
//        guard case .computeCommandEncoder(let computeCommandEncoder) = encoder else {
//            return
//        }
//
//        let index = self.index(from: argumentPath)
//
//        computeCommandEncoder.setBuffer(argumentBuffer,
//                                        offset: baseOffset(from: argumentPath),
//                                        index: index)
//
//        for binding in bindings {
//            switch binding.value {
//            case .bytes(let data):
//
//                let destination = argumentBuffer.contents().assumingMemoryBound(to: UInt8.self)
//                let indexOffset = offset(for: binding.indexPath, from: argumentPath)
//
//                encode(data, destination: destination, offset: indexOffset)
//
//            case .buffer(let buffer, let offset):
//
//                computeCommandEncoder.setBuffer(buffer, offset: offset, index: index)
//
//            case .custom(let encodable): break
//            }
//        }
//    }
//
//    func nestedBaseOffset(from argumentPath: [Parser.Argument]) -> Int {
//        return offset(for: [Int](repeating: 0, count: argumentPath.count), from: argumentPath)
//    }
//
//    func baseOffset(from argumentPath: [Parser.Argument]) -> Int {
//        var baseOffset = nestedBaseOffset(from: argumentPath)
//
//        // when dealing with struct, the base offset needs to point to struct's offset, not the type nested in that struct
//        for argument in argumentPath {
//            switch argument {
//            case .structMember(let s): baseOffset -= s.offset
//            default: continue
//            }
//        }
//
//        return baseOffset
//    }
//
//
//    func argumentOffset(_ argument: MTLArgument) -> Int {
//        // argument's 'arrayLength' does not contribute to offset since its usage is restricted to textures
//        // TODO: check size contribution in child encoder size
//
//        // TODO: will crash on non buffer types, check valid results when fixing
//        return reflection.arguments[..<argument.index].reduce(0) {
//            let alignment = $1.bufferAlignment
//            let aligned = $0.aligned(by: alignment)
//            return aligned + $1.bufferDataSize
//        }
//    }
//
//    func localIndex(from argumentPath: [Parser.Argument]) -> Int {
//        guard case let .argument(argument) = argumentPath[0] else {
//            fatalError("First item in argument path must be an argument.")
//        }
//
//        // disregard global (argument) index
//        return index(from: argumentPath) - argument.index
//    }



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


private extension Argument {
    var index: Int? {
        switch self {
        case .argument(let a): return a.index
        case .structMember(let s): return s.argumentIndex
        default: return nil
        }
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
