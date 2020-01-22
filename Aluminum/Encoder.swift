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
        // check whether argument was directly bound
        if let binding = binder.binding(for: .argument(argument)) {
            encodeArgument(argument, with: binding)
            return // TODO: add multiple bounds
        }
        
        
    }
}

private extension ComputePipelineStateController.Encoder {
    func encodeArgument(_ argument: MTLArgument,
                        with binding: ComputePipelineStateController.Binder.Binding)
    {
        switch binding {
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
}
