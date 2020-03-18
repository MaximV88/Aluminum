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
        case invalidEncoderPath(Int) // encoder does not support given path (extends outside of it) - first unsupported parameter index
        case invalidPathIndexPlacement(Int) // index is missing at expected position
        case invalidPathStructure(Int) // path has an index in an unexpected index - returns index of invalid path compoent
        case invalidBufferPath // last element in path should be a pointer
        case invalidBytesPath // last element in path shouldnt be a pointer
        case noArgumentBuffer // did not set argument buffer for encoder
        case invalidArgumentBuffer // argument buffer is too short
        case pathIndexOutOfBounds(Int) // index is not in bounds of array - index of invalid path
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
        
        guard let argumentPath = parser.argumentPath(for: rootPath) else {
            throw ControllerError.unknownArgument(argument)
        }
                
        computeCommandEncoder.setComputePipelineState(computePipelineState)
        
        return RootEncoder(rootPath: rootPath,
                           argumentPath: argumentPath,
                           parser: parser,
                           function: function,
                           computeCommandEncoder: computeCommandEncoder)
     }
}
