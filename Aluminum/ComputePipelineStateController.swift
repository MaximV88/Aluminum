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
    
    public init(_ function: MTLFunction) throws {
        self.function = function
        
        var reflection: MTLComputePipelineReflection?
        self.computePipelineState = try function.device.makeComputePipelineState(function: function,
                                                                                 options: [.argumentInfo, .bufferTypeInfo],
                                                                                 reflection: &reflection)
        
        self.parser = Parser(arguments: reflection!.arguments)
    }
    
    public init(_ descriptor: MTLComputePipelineDescriptor) throws {
        self.function = descriptor.computeFunction!
        
        var reflection: MTLComputePipelineReflection?
        self.computePipelineState = try function.device.makeComputePipelineState(descriptor: descriptor,
                                                                                 options: [.argumentInfo, .bufferTypeInfo],
                                                                                 reflection: &reflection)
        
        self.parser = Parser(arguments: reflection!.arguments)
    }
    
    public func makeEncoder(for argument: String, with computeCommandEncoder: MTLComputeCommandEncoder) -> RootEncoder {
        let encoding = parser.encoding(for: argument)
                
        computeCommandEncoder.setComputePipelineState(computePipelineState)
        
        return makeRootEncoder(for: encoding,
                               rootPath: [.argument(argument)],
                               function: function,
                               metalEncoder: ComputeMetalEncoder(computeCommandEncoder))
    }
}
