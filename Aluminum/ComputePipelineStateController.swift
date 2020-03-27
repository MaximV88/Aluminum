//
//  ComputePipelineState.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 18/01/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal


public class ComputePipelineStateController {
    
    public let function: MTLFunction
    
    public let computePipelineState: MTLComputePipelineState
    
    
    private let reflection: MTLComputePipelineReflection
    private let parser: Parser
    
    public init(function: MTLFunction) throws {
        self.function = function
        
        var reflection: MTLComputePipelineReflection?
        self.computePipelineState = try function.device.makeComputePipelineState(function: function,
                                                                                 options: [.argumentInfo, .bufferTypeInfo],
                                                                                 reflection: &reflection)
        
        self.reflection = reflection!
        self.parser = Parser(arguments: reflection!.arguments)
    }
    
    public func makeEncoder(for argument: String, with computeCommandEncoder: MTLComputeCommandEncoder) throws -> ComputePipelineStateEncoder {
        let encoding = parser.encoding(for: argument)
                
        computeCommandEncoder.setComputePipelineState(computePipelineState)
        
        return RootEncoder(encoding: encoding,
                           rootPath: [.argument(argument)],
                           function: function,
                           computeCommandEncoder: computeCommandEncoder)
    }
}
