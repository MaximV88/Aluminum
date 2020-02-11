//
//  Encoder.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 20/01/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal



public extension ComputePipelineStateController {
    class Encoder {
        
        private let function: MTLFunction
        private let reflection: MTLComputePipelineReflection
        private let computePipelineState: MTLComputePipelineState

        private weak var computeCommandEncoder: MTLComputeCommandEncoder!
        private weak var binder: ComputePipelineStateController.Binder!
        private weak var argumentBuffer: MTLBuffer!
                        
        internal init(function: MTLFunction,
                      reflection: MTLComputePipelineReflection,
                      computePipelineState: MTLComputePipelineState)
        {
            self.function = function
            self.reflection = reflection
            self.computePipelineState = computePipelineState
        }
    }
}

public extension ComputePipelineStateController.Encoder {
    func encode(_ computeCommandEncoder: MTLComputeCommandEncoder,
                binder: ComputePipelineStateController.Binder,
                argumentBuffer: MTLBuffer? = nil)
    {
        self.computeCommandEncoder = computeCommandEncoder
        self.binder = binder
        self.argumentBuffer = argumentBuffer
        
        computeCommandEncoder.setComputePipelineState(computePipelineState)

        reflection.arguments.forEach {
            traverseArgument($0)
        }
    }
}

private extension ComputePipelineStateController.Encoder {
    enum Encoder {
        case computeCommandEncoder(_ computeEncoder: MTLComputeCommandEncoder)
        case argumentEncoder(_ argumentEncoder: MTLArgumentEncoder)
    }
    
    func traverseArgument(_ argument: MTLArgument) {
        switch argument.type {
        case .buffer:traversePointer(argument.bufferPointerType!,
                                     in: [.argument(argument)],
                                     encoder: .computeCommandEncoder(computeCommandEncoder))
        case .texture: fatalError() // TODO: can have an array
        default: fatalError()
        }
    }
    
    func traversePointer(_ pointer: MTLPointerType, in argumentPath: [Parser.Argument], encoder: Encoder) {
        // pointers may represent argument buffers
        let pointerEncoder: Encoder
        if pointer.elementIsArgumentBuffer {
            
            pointerEncoder = makeArgumentEncoder(from: encoder,
                                                 at: index(from: argumentPath),
                                                 offset: baseOffset(from: argumentPath),
                                                 alignment: pointer.alignment)
        } else {
            pointerEncoder = encoder
        }
        
        let argumentPath = argumentPath + [.type(pointer)]
        apply(argumentPath, with: pointerEncoder)

        switch pointer.elementType {
        case .struct: traverseStruct(pointer.elementStructType()!, in: argumentPath, encoder: pointerEncoder)
        // ???: cant find a case where a pointer contains a reference to an array, seems that an array is always in a struct
        case .array: traverseArray(pointer.elementArrayType()!, in: argumentPath , encoder: pointerEncoder)
        default: break
        }
    }

    func traverseStruct(_ struct: MTLStructType, in argumentPath: [Parser.Argument], encoder: Encoder) {
        for member in `struct`.members {
            let argumentPath = argumentPath + [.structMember(member)]
            apply(argumentPath, with: encoder)

            switch member.dataType {
            case .struct: traverseStruct(member.structType()!, in: argumentPath, encoder: encoder)
            case .array: traverseArray(member.arrayType()!, in: argumentPath, encoder: encoder)
            default: break
            }
        }
    }

    func traverseArray(_ array: MTLArrayType, in argumentPath: [Parser.Argument], encoder: Encoder) {
        let argumentPath = argumentPath + [.type(array)]
        apply(argumentPath, with: encoder)
        
        switch array.elementType {
        case .array: traverseArray(array.element()!, in: argumentPath, encoder: encoder)
        case .struct: traverseStruct(array.elementStructType()!, in: argumentPath, encoder: encoder)
        default: break
        }
    }
}

private extension ComputePipelineStateController.Encoder {
    func apply(_ argumentPath: [Parser.Argument], with encoder: Encoder) {
        let lastArgument = argumentPath.last!

        let bindings = binder.bindings(for: lastArgument)
        guard !bindings.isEmpty else { return }

        // TODO: all binding need to be homogenous, otherwise binding buffer/bytes to same index will override each other
                
        switch encoder {
        case .argumentEncoder:
            applyArgumentEncoder(encoder,
                                 argumentPath: argumentPath,
                                 bindings: bindings)
        case .computeCommandEncoder:
            applyComputeCommandEncoder(encoder,
                                       argumentPath: argumentPath,
                                       bindings: bindings)
        }
    }
    
    func applyArgumentEncoder(_ encoder: Encoder,
                              argumentPath: [Parser.Argument],
                              bindings: [ComputePipelineStateController.Binder.Binding])
    {
        guard case .argumentEncoder(let argumentEncoder) = encoder else {
            return
        }
        
        // argument encoders use local indices
        let index = localIndex(from: argumentPath)

        // bytes are encoded using 'constantData', index starts at nested type, not at origin.
        let bytesBaseOffset = -nestedBaseOffset(from: argumentPath)
        
        for binding in bindings {
            switch binding.value {
            case .bytes(let data):
                
                let destination = argumentEncoder.constantData(at: index).assumingMemoryBound(to: UInt8.self)
                let indexOffset = bytesBaseOffset + offset(for: binding.indexPath, from: argumentPath)
                
                encode(data, destination: destination, offset: indexOffset)
                
            case .buffer(let buffer, let offset):
                
                argumentEncoder.setBuffer(buffer, offset: offset, index: index)
                
                // buffer encoding assumes pointer argument
                computeCommandEncoder.useResource(buffer, usage: argumentPath.last!.usage!)
                
            case .custom(let encodable): break
            }
        }
    }
    
    func applyComputeCommandEncoder(_ encoder: Encoder,
                                    argumentPath: [Parser.Argument],
                                    bindings: [ComputePipelineStateController.Binder.Binding])
    {
        guard case .computeCommandEncoder(let computeCommandEncoder) = encoder else {
            return
        }
        
        let index = self.index(from: argumentPath)

        computeCommandEncoder.setBuffer(argumentBuffer,
                                        offset: baseOffset(from: argumentPath),
                                        index: index)
        
        for binding in bindings {
            switch binding.value {
            case .bytes(let data):
                
                let destination = argumentBuffer.contents().assumingMemoryBound(to: UInt8.self)
                let indexOffset = offset(for: binding.indexPath, from: argumentPath)
                
                encode(data, destination: destination, offset: indexOffset)
                
            case .buffer(let buffer, let offset):
                
                computeCommandEncoder.setBuffer(buffer, offset: offset, index: index)
                
            case .custom(let encodable): break
            }
        }
    }
    
    func nestedBaseOffset(from argumentPath: [Parser.Argument]) -> Int {
        return offset(for: [Int](repeating: 0, count: argumentPath.count), from: argumentPath)
    }
    
    func baseOffset(from argumentPath: [Parser.Argument]) -> Int {
        var baseOffset = nestedBaseOffset(from: argumentPath)
        
        // when dealing with struct, the base offset needs to point to struct's offset, not the type nested in that struct
        for argument in argumentPath {
            switch argument {
            case .structMember(let s): baseOffset -= s.offset
            default: continue
            }
        }
        
        return baseOffset
    }
    
    /**
     calculates offset by considering argument types + associated indexpaths
     */
    func offset(for indexPath: [Int], from argumentPath: [Parser.Argument]) -> Int {
        guard case let .argument(argument) = argumentPath[0] else {
            fatalError("First item in argument path must be an argument.")
        }
        
        // go down the argument tree with an initial offset
        var offset = argumentOffset(argument)
        var pathIndex = 0
        
        for item in argumentPath[1...] {
            switch item {
            case .type(let t):
                if t.dataType == .array {
                    offset += indexPath[pathIndex] * (t as! MTLArrayType).stride
                    pathIndex += 1
                }
            case .structMember(let s): offset += s.offset
            case .argument: fatalError("Argument already accounted for.")
            }
        }
        
        return offset
    }
    
    func argumentOffset(_ argument: MTLArgument) -> Int {
        // argument's 'arrayLength' does not contribute to offset since its usage is restricted to textures
        // TODO: check size contribution in child encoder size
        
        // TODO: will crash on non buffer types, check valid results when fixing
        return reflection.arguments[..<argument.index].reduce(0) {
            let alignment = $1.bufferAlignment
            let aligned = $0.aligned(by: alignment)
            return aligned + $1.bufferDataSize
        } 
    }
    
    func index(from argumentPath: [Parser.Argument]) -> Int {
        return argumentPath.reduce(0) {
            return $0 + ($1.index ?? 0)
        }
    }
    
    func localIndex(from argumentPath: [Parser.Argument]) -> Int {
        guard case let .argument(argument) = argumentPath[0] else {
            fatalError("First item in argument path must be an argument.")
        }
        
        // disregal global (argument) index
        return index(from: argumentPath) - argument.index
    }
}

private extension ComputePipelineStateController.Encoder {
    func makeArgumentEncoder(from encoder: Encoder, at index: Int, offset: Int, alignment: Int) -> Encoder {
        let childEncoder: MTLArgumentEncoder
                
        // argument encoder requires encoding the buffer into parent in the original index
        switch encoder {
        case .computeCommandEncoder(let e):
            childEncoder = function.makeArgumentEncoder(bufferIndex: index)
            e.setBuffer(argumentBuffer, offset: offset, index: index)
        case .argumentEncoder(let e):
            childEncoder = e.makeArgumentEncoderForBuffer(atIndex: index)!
            e.setBuffer(argumentBuffer, offset: offset, index: index)
        }
        
        childEncoder.setArgumentBuffer(argumentBuffer, offset: offset)

        return .argumentEncoder(childEncoder)
    }
    
    func encode(_ data: Data, destination: UnsafeMutablePointer<UInt8>, offset: Int) {
        data.withUnsafeBytes { bytes in
            let source = bytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
            for i in 0 ..< bytes.count {
                destination[offset + i] = source[i]
            }
        }
    }
}

private extension Collection where Element == ComputePipelineStateController.Binder.Binding {
    var allBytes: Bool {
        for element in self {
            if case .bytes = element.value {
                continue
            }
            return false
        }
        return true
    }
}

private extension Collection where Element == Parser.Argument {
    var lastIndex: Int? {
        return first(where: { $0.index != nil })?.index ?? nil
    }
}

private extension Parser.Argument {
    var usage: MTLResourceUsage? {
        switch self {
        case .type(let t):
            // usage has meaning only with pointers
            if t.dataType == .pointer {
                return (t as! MTLPointerType).access.usage
            }
        default: break
        }
        
        return nil
    }
    
    var index: Int? {
        switch self {
        case .argument(let a): return a.index
        case .structMember(let s): return s.argumentIndex
        case .type: return nil
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

