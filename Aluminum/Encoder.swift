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
        private enum Action {
            case setBuffer
            case setBytes
        }
        
        private var cachedActions = [Action]()
        private var encoderOffset: Int = 0
        
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
        // possibility of using argument encoder with pointer types
        let pointerEncoder: Encoder
        if pointer.elementIsArgumentBuffer {
            pointerEncoder = makeArgumentEncoder(from: encoder, at: 0, alignment: pointer.alignment)
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

        let index = lastIndex(from: argumentPath)
        let baseOffset: Int = self.baseOffset(from: argumentPath, encoder: encoder)
        
        switch encoder {
        case .computeCommandEncoder(let e): e.setBuffer(argumentBuffer, offset: 0, index: index)
        case .argumentEncoder: break // buffer is bound when creating encoder
        }

        
        // TODO: all binding need to be homogenous, otherwise binding buffer/bytes to same index will override each other
        for binding in bindings {
            switch binding.value {
            case .bytes(let data):
                encode(data,
                       index: index,
                       offset: baseOffset + offset(for: binding.indexPath, from: argumentPath),
                       encoder: encoder)
            case .buffer(let buffer, let offset):
                encode(buffer,
                       index: index,
                       offset: offset,
                       encoder: encoder)
            case .custom(let encodable): break
            }
        }
    }

    func baseOffset(from argumentPath: [Parser.Argument], encoder: Encoder) -> Int {
        var baseOffset = offset(for: [Int](repeating: 0, count: argumentPath.count), from: argumentPath)
        
        switch encoder {
        case .argumentEncoder:
            
            // will be using 'constantData', index starts at nested type, not at origin.
            return -baseOffset
            
        case .computeCommandEncoder:
            
            // when dealing with struct, the base offset needs to point to struct's offset, not the type nested in that struct
            // this needs to be also considered when type is nested in a struct.
            for argument in argumentPath {
                switch argument {
                case .structMember(let s): baseOffset -= s.offset
                default: continue
                }
            }
            
            return baseOffset
        }
        
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
        return reflection.arguments[..<argument.index].reduce(0) { $0 + $1.bufferDataSize }
    }
    
    func lastIndex(from argumentPath: [Parser.Argument]) -> Int {
        for argument in argumentPath.reversed() {
            switch argument {
            case .argument(let a): return a.index
            case .structMember(let s):
                // ignore struct member that encapsulate arrays, they dont influence indexing
                if s.dataType != .array {
                    return s.argumentIndex
                }
            case .type: continue
            }
        }
        
        fatalError("No index found for given argument path.")
    }
}

private extension ComputePipelineStateController.Encoder {
    func makeArgumentEncoder(from encoder: Encoder, at index: Int, alignment: Int) -> Encoder {
        let childEncoder: MTLArgumentEncoder
        
        // align offset
        encoderOffset = (((encoderOffset + (alignment - 1)) / alignment) * alignment);
        
        // argument encoder requires encoding the buffer into parent in the original index
        switch encoder {
        case .computeCommandEncoder(let e):
            childEncoder = function.makeArgumentEncoder(bufferIndex: index)
            e.setBuffer(argumentBuffer, offset: encoderOffset, index: index)
        case .argumentEncoder(let e):
            childEncoder = e.makeArgumentEncoderForBuffer(atIndex: index)!
            e.setBuffer(argumentBuffer, offset: encoderOffset, index: index) // TODO: not correct for nested encoder ...
        }
        
        childEncoder.setArgumentBuffer(argumentBuffer, offset: encoderOffset)
        encoderOffset += childEncoder.encodedLength

        return .argumentEncoder(childEncoder)
    }
    
    func encode(_ buffer: MTLBuffer, index: Int, offset: Int, encoder: Encoder) {
        switch encoder {
        case .argumentEncoder(let encoder): encoder.setBuffer(buffer, offset: offset, index: index)
        case .computeCommandEncoder(let encoder): encoder.setBuffer(buffer, offset: offset, index: index)
        }
    }
    
    func encode(_ data: Data, index: Int, offset: Int, encoder: Encoder) {
        data.withUnsafeBytes { bytes in
            let ptr: UnsafeMutablePointer<UInt8>
            
            switch encoder {
            case .argumentEncoder(let e):
                ptr = e.constantData(at: index).assumingMemoryBound(to: UInt8.self)
            case .computeCommandEncoder:
                ptr = argumentBuffer.contents().assumingMemoryBound(to: UInt8.self)
            }
            
            let source = bytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
            for i in 0 ..< bytes.count {
                ptr[offset + i] = source[i]
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
