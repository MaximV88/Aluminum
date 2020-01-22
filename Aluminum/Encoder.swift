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
        
        private let function: MTLFunction
        private let reflection: MTLComputePipelineReflection

        private weak var computeCommandEncoder: MTLComputeCommandEncoder!
        private weak var binder: ComputePipelineStateController.Binder!
        private weak var argumentBuffer: MTLBuffer!
        
        private var offset: Int = 0
        
        internal init(function: MTLFunction,
                      reflection: MTLComputePipelineReflection)
        {
            self.function = function
            self.reflection = reflection
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
        
        offset = 0
        
        reflection.arguments.forEach {
            traverseArgument($0)
        }
    }
}

private extension ComputePipelineStateController.Encoder {
    func traverseArgument(_ argument: MTLArgument) {
        applyArgument(argument, with: .argument(argument))
        
        switch argument.type {
        case .buffer: traversePointer(argument.bufferPointerType!, in: argument)
        case .texture: break // TODO: can have an array
        default: break
        }
    }
    
    func traversePointer(_ pointer: MTLPointerType, in argument: MTLArgument) {
        applyArgument(argument, with: .type(pointer))
        
        switch pointer.elementType {
        case .struct: traverseStruct(pointer.elementStructType()!, in: argument)
        // ???: cant find a case where a pointer contains a reference to an array, seems that an array is always in a struct
        case .array: traverseArray(pointer.elementArrayType()!, in: argument)
        default: break
        }
    }
    
    func traverseStruct(_ struct: MTLStructType, in argument: MTLArgument) {
        applyArgument(argument, with: .type(`struct`))
        
        for member in `struct`.members {
            applyArgument(argument, with: .structMember(member))

            switch member.dataType {
            case .struct: traverseStruct(member.structType()!, in: argument)
            case .array: traverseArray(member.arrayType()!, in: argument)
            default: break
            }
        }
    }
    
    func traverseArray(_ array: MTLArrayType, in argument: MTLArgument) {
        applyArgument(argument, with: .type(array))
        
        switch array.elementType {
        case .array: traverseArray(array.element()!, in: argument)
        case .struct: traverseStruct(array.elementStructType()!, in: argument)
        default: break
        }
    }
}

private extension ComputePipelineStateController.Encoder {
    func applyArgument(_ argument: MTLArgument,
                        with candidate: Parser.Argument)
    {
        guard let binding = binder.binding(for: candidate) else {
            return
        }
        
        switch binding {
        case .value(let value): encodeArgument(argument, with: value)
        case .arrayMember(let value, let nestedIndices): encodeArgument(argument, with: value, inArrayAt: nestedIndices.first!) // first level
        }
    }
}

private extension ComputePipelineStateController.Encoder {
    func encodeArgument(_ argument: MTLArgument,
                        with value: ComputePipelineStateController.Binder.Value)
    {
        switch value {
        case .bytes(let data):
            data.withUnsafeBytes { bytes in
                let ptr: UnsafePointer<UInt8> = bytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
                computeCommandEncoder.setBytes(ptr, length: data.count, index: argument.index)
            }
        case .buffer(let buffer):
            computeCommandEncoder.setBuffer(buffer, offset: argument.bufferAlignment, index: argument.index)
        case .custom(let encodable):
            encodable.encode(to: computeCommandEncoder)
        }
    }
    
    func encodeArgument(_ argument: MTLArgument,
                        with value: ComputePipelineStateController.Binder.Value,
                        inArrayAt index: UInt)
    {
        guard argument.bufferDataType == .array else {
            fatalError()
        }
        
        
    }
}
