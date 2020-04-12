//
//  RenderPipelineStateController.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 10/04/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal


public class RenderPipelineStateController {
    public let renderPipelineState: MTLRenderPipelineState
    
    
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
    
    public init(_ descriptor: MTLRenderPipelineDescriptor) throws {
        guard let function = descriptor.vertexFunction ?? descriptor.fragmentFunction else {
            fatalError("MTLRenderPipelineDescriptor does not contain any functions.".padded)
        }
        
        
        var reflection: MTLRenderPipelineReflection?
        renderPipelineState = try function.device.makeRenderPipelineState(descriptor: descriptor,
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
    func makeVertexEncoder(for argument: String, with renderCommandEncoder: MTLRenderCommandEncoder) -> RootEncoder {
        let data = safeVertexData
        let encoding = data.parser.encoding(for: argument)
        
        renderCommandEncoder.setRenderPipelineState(renderPipelineState)
        
        return makeRootEncoder(for: encoding,
                               rootPath: [.argument(argument)],
                               function: data.function,
                               metalEncoder: RenderVertexMetalEncoder(renderCommandEncoder))
    }
    
    func makeFragmentEncoder(for argument: String, with renderCommandEncoder: MTLRenderCommandEncoder) -> RootEncoder {
        let data = safeFragmentData
        let encoding = data.parser.encoding(for: argument)
        
        renderCommandEncoder.setRenderPipelineState(renderPipelineState)
        
        return makeRootEncoder(for: encoding,
                               rootPath: [.argument(argument)],
                               function: data.function,
                               metalEncoder: RenderVertexMetalEncoder(renderCommandEncoder))
        
    }
    
    func makeVertexEncoderGroup() -> EncoderGroup {
        let data = safeVertexData
        return data.factory.makeEncoderGroup(function: data.function, parser: data.parser)
    }
    
    func makeFragmentEncoderGroup() -> EncoderGroup {
        let data = safeFragmentData
        return data.factory.makeEncoderGroup(function: data.function, parser: data.parser)
    }
}
