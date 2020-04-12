//
//  ComputePipelineState.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 18/01/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal


public class ComputePipelineStateController {
    public let computePipelineState: MTLComputePipelineState
        
    private let function: MTLFunction
    private let parser: Parser
    private let factory: EncoderGroupFactory
    
    private init(function: MTLFunction,
                 computePipelineState: MTLComputePipelineState,
                 arguments: [MTLArgument])
    {
        self.function = function
        self.parser = Parser(arguments: arguments)
        self.computePipelineState = computePipelineState
        self.factory = EncoderGroupFactory(arguments: arguments)
    }
    
    public convenience init(_ function: MTLFunction) throws {
        var reflection: MTLComputePipelineReflection?
        let pipeline = try function.device.makeComputePipelineState(function: function,
                                                                    options: [.argumentInfo, .bufferTypeInfo],
                                                                    reflection: &reflection)
        
        self.init(function: function,
                  computePipelineState: pipeline,
                  arguments: reflection!.arguments)
    }
    
    public convenience init(_ descriptor: MTLComputePipelineDescriptor) throws {
        guard let function = descriptor.computeFunction else {
            fatalError(.descriptorConstructorRequiresFunction)
        }
        
        var reflection: MTLComputePipelineReflection?
        let pipeline = try function.device.makeComputePipelineState(descriptor: descriptor,
                                                                    options: [.argumentInfo, .bufferTypeInfo],
                                                                    reflection: &reflection)
        
        self.init(function: function,
                  computePipelineState: pipeline,
                  arguments: reflection!.arguments)
    }
}

public extension ComputePipelineStateController {
    func makeEncoder(for argument: String, with computeCommandEncoder: MTLComputeCommandEncoder) -> RootEncoder
    {
        return makeRootEncoder(for: parser.encoding(for: argument),
                               rootPath: [.argument(argument)],
                               function: function,
                               metalEncoder: ComputeMetalEncoder(computeCommandEncoder))
    }
    
    func makeEncoderGroup() -> EncoderGroup {
        factory.makeEncoderGroup(function: function, parser: parser)
    }
}
