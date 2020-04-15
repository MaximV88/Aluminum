//
//  RenderPipelineStateController.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 10/04/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal


/// Controller for a `RenderPipelineStateController` instance, manages it's lifecycle.
/// Responsible for creation of `Encoder` and `EncoderGroup` objects
/// that bind arguments of `RenderPipelineStateController`'s function.
public class RenderPipelineStateController {
    
    /// Managed `MTLRenderPipelineState`.
    public let pipelineState: MTLRenderPipelineState
    
    
    private struct Data {
        let parser: Parser
        let function: MTLFunction
        let factory: EncoderGroupFactory
    }
    
    private let vertexData: Data?
    private let fragmentData: Data?
    
    private var safeVertexData: Data {
        guard let data = vertexData else {
            fatalError(.noVertexFunctionFound)
        }
        
        return data
    }

    private var safeFragmentData: Data {
        guard let data = fragmentData else {
            fatalError(.noFragmentFunctionFound)
        }
        
        return data
    }
    
    
    /// Initializes a new controller with provided `MTLRenderPipelineDescriptor` instance.
    ///
    /// - Throws: propogates `makeRenderPipelineState` throw.
    /// - Parameter descriptor: Descriptor that references the functions that controller should manage (vertex, fragment or both).
    public init(_ descriptor: MTLRenderPipelineDescriptor) throws {
        guard let function = descriptor.vertexFunction ?? descriptor.fragmentFunction else {
            fatalError("MTLRenderPipelineDescriptor does not contain any functions.".padded)
        }
        
        
        var reflection: MTLRenderPipelineReflection?
        pipelineState = try function.device.makeRenderPipelineState(descriptor: descriptor,
                                                                    options: [.argumentInfo, .bufferTypeInfo],
                                                                    reflection: &reflection)
        
        if let vertexArguments = reflection?.vertexArguments {
            vertexData = Data(parser: Parser(arguments: vertexArguments),
                              function: descriptor.vertexFunction!,
                              factory: EncoderGroupFactory(arguments: vertexArguments))
        } else {
            vertexData = nil
        }
        
        if let fragmentArguments = reflection?.fragmentArguments {
            fragmentData = Data(parser: Parser(arguments: fragmentArguments),
                                function: descriptor.fragmentFunction!,
                                factory: EncoderGroupFactory(arguments: fragmentArguments))
        } else {
            fragmentData = nil
        }
    }
}

public extension RenderPipelineStateController {
    
    /// Initializes a new encoder that binds `MTLComputeCommandEncoder`'s arguments directly.
    /// Encodes for the `vertex` metal function provided in Controller's constructor.
    ///
    /// - Parameter argument: Name of argument (metal function parameter) to bind for.
    /// - Parameter renderCommandEncoder: A `MTLRenderCommandEncoder` instance that is target of binding.
    /// - Returns: A `RootEncoder` assigned to specified argument.
    func makeVertexEncoder(for argument: String, with renderCommandEncoder: MTLRenderCommandEncoder) -> RootEncoder {
        let data = safeVertexData
        let encoding = data.parser.encoding(for: argument)
                
        return makeRootEncoder(for: encoding,
                               rootPath: [.argument(argument)],
                               function: data.function,
                               metalEncoder: RenderVertexMetalEncoder(renderCommandEncoder))
    }
    
    /// Initializes a new encoder that binds `MTLComputeCommandEncoder`'s arguments directly.
    /// Encodes for the `fragment` metal function provided in Controller's constructor.
    ///
    /// - Parameter argument: Name of argument (metal function parameter) to bind for.
    /// - Parameter renderCommandEncoder: A `MTLRenderCommandEncoder` instance that is target of binding.
    /// - Returns: A `RootEncoder` assigned to specified argument.
    func makeFragmentEncoder(for argument: String, with renderCommandEncoder: MTLRenderCommandEncoder) -> RootEncoder {
        let data = safeFragmentData
        let encoding = data.parser.encoding(for: argument)
                
        return makeRootEncoder(for: encoding,
                               rootPath: [.argument(argument)],
                               function: data.function,
                               metalEncoder: RenderVertexMetalEncoder(renderCommandEncoder))
        
    }
    
    /// Initializes a new `EncoderGroup`.
    /// Encodes for the `vertex` metal function provided in Controller's constructor.
    ///
    /// - Returns: An `EncoderGroup` that targets the creating Controller's function.
    func makeVertexEncoderGroup() -> EncoderGroup {
        let data = safeVertexData
        return data.factory.makeEncoderGroup(function: data.function, parser: data.parser)
    }
    
    /// Initializes a new `EncoderGroup`.
    /// Encodes for the `fragment` metal function provided in Controller's constructor.
    ///
    /// - Returns: An `EncoderGroup` that targets the creating Controller's function.
    func makeFragmentEncoderGroup() -> EncoderGroup {
        let data = safeFragmentData
        return data.factory.makeEncoderGroup(function: data.function, parser: data.parser)
    }
}
