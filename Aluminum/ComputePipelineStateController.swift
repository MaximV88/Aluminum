//
//  ComputePipelineState.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 18/01/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal


public class ComputePipelineStateController {
    
    enum ControllerError: Error {
        case unknownArgument(String) // name does not match any argument
        case nonExistingPath
        case invalidEncoderPath(String) // encoder does not support given path (extends outside of it) - first unsupported parameter name
        case invalidPathIndexPlacement(Int) // index is missing at expected position
        case invalidBufferPath // last element in path should be a pointer
        case invalidBytesPath // last element in path shouldnt be a pointer
    }
    
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
        let rootPath: Path = [.argument(argument)]
        
        guard
            let rootArgument = parser.argumentPath(for: rootPath)?.first,
            case let .argument(mtlArgument) = rootArgument
            else
        {
            throw ControllerError.unknownArgument(argument)
        }
        
        computeCommandEncoder.setComputePipelineState(computePipelineState)
        
        return RootEncoder(rootPath: rootPath,
                           argument: mtlArgument,
                           parser: parser,
                           function: function,
                           computeCommandEncoder: computeCommandEncoder)
     }
}
