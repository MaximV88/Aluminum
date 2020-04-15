//
//  ComputePipelineState.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 18/01/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal


/// Controller for a `MTLComputePipelineState` instance, manages it's lifecycle.
/// Responsible for creation of `Encoder` and `EncoderGroup` objects
/// that bind arguments of `MTLComputePipelineState`'s function.
public class ComputePipelineStateController {
    
    /// Managed `MTLComputePipelineState`.
    public let pipelineState: MTLComputePipelineState
        
    private let function: MTLFunction
    private let parser: Parser
    private let factory: EncoderGroupFactory
    
    private init(function: MTLFunction,
                 computePipelineState: MTLComputePipelineState,
                 arguments: [MTLArgument])
    {
        self.function = function
        self.parser = Parser(arguments: arguments)
        self.pipelineState = computePipelineState
        self.factory = EncoderGroupFactory(arguments: arguments)
    }
    
    /// Initializes a new controller with provided metal function.
    ///
    /// - Throws: propogates `makeComputePipelineState` throw.
    /// - Parameter function: Function that controller should manage.
    public convenience init(_ function: MTLFunction) throws {
        var reflection: MTLComputePipelineReflection?
        let pipeline = try function.device.makeComputePipelineState(function: function,
                                                                    options: [.argumentInfo, .bufferTypeInfo],
                                                                    reflection: &reflection)
        
        self.init(function: function,
                  computePipelineState: pipeline,
                  arguments: reflection!.arguments)
    }
    
    /// Initializes a new controller with provided `MTLComputePipelineDescriptor` instance.
    ///
    /// - Throws: propogates `makeComputePipelineState` throw.
    /// - Parameter descriptor: Descriptor that references function that controller should manage.
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
    
    /// Initializes a new encoder that binds `MTLComputeCommandEncoder`'s arguments directly.
    ///
    /// - Parameter argument: Name of argument (metal function parameter) to bind for.
    /// - Parameter computeCommandEncoder: A `MTLComputeCommandEncoder` instance that is target of binding.
    /// - Returns: A `RootEncoder` assigned to specified argument.
    func makeEncoder(for argument: String, with computeCommandEncoder: MTLComputeCommandEncoder) -> RootEncoder
    {
        return makeRootEncoder(for: parser.encoding(for: argument),
                               rootPath: [.argument(argument)],
                               function: function,
                               metalEncoder: ComputeMetalEncoder(computeCommandEncoder))
    }
    
    /// Initializes a new `EncoderGroup`.
    ///
    /// - Returns: An `EncoderGroup` that targets the creating Controller's function.
    func makeEncoderGroup() -> EncoderGroup {
        factory.makeEncoderGroup(function: function, parser: parser)
    }
}
