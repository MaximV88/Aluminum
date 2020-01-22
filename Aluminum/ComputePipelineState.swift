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
    
    public var argumentBufferEncodedLength: Int {
        return parser.argumentBufferEncodedLength
    }
    
    private let reflection: MTLComputePipelineReflection
    private let parser: Parser
    
    public init(function: MTLFunction) throws {
        self.function = function
        
        var reflection: MTLComputePipelineReflection?
        self.computePipelineState = try function.device.makeComputePipelineState(function: function,
                                                                                 options: [.argumentInfo, .bufferTypeInfo],
                                                                                 reflection: &reflection)
        
        self.reflection = reflection!
        self.parser = try Parser(arguments: reflection!.arguments)
    }
    
    public func makeBinder() -> Binder {
        return Binder(parser: parser)
    }
    
    public func makeEncoder() -> Encoder {
         return Encoder(function: function, reflection: reflection)
     }
}
