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
    }
    
    private let vertexData: Data?
    private let fragmentData: Data?
    
    public init(_ descriptor: MTLRenderPipelineDescriptor) throws {
        guard let function = descriptor.vertexFunction ?? descriptor.fragmentFunction else {
            fatalError("MTLRenderPipelineDescriptor does not contain any functions.".padded)
        }
        
        
        var reflection: MTLRenderPipelineReflection?
        renderPipelineState = try function.device.makeRenderPipelineState(descriptor: descriptor,
                                                                          options: [.argumentInfo, .bufferTypeInfo],
                                                                          reflection: &reflection)
        
        if let vertexArguments = reflection?.vertexArguments {
            vertexData = Data(parser: Parser(arguments: vertexArguments), function: descriptor.vertexFunction!)
        } else {
            vertexData = nil
        }
        
        if let fragmentArguments = reflection?.fragmentArguments {
            fragmentData = Data(parser: Parser(arguments: fragmentArguments), function: descriptor.fragmentFunction!)
        } else {
            fragmentData = nil
        }
    }
    
    public func makeVertexEncoder(for argument: String, with renderCommandEncoder: MTLRenderCommandEncoder) -> RootEncoder {
        guard let data = vertexData else {
            fatalError("No vertex function found.".padded)
        }
        
        let encoding = data.parser.encoding(for: argument)
                
        renderCommandEncoder.setRenderPipelineState(renderPipelineState)
        
        return makeRootEncoder(for: encoding,
                               rootPath: [.argument(argument)],
                               function: data.function,
                               metalEncoder: RenderVertexMetalEncoder(renderCommandEncoder))
    }

    public func makeFragmentEncoder(for argument: String, with renderCommandEncoder: MTLRenderCommandEncoder) -> RootEncoder {
        guard let data = fragmentData else {
            fatalError("No fragment function found.".padded)
        }

        let encoding = data.parser.encoding(for: argument)
                
        renderCommandEncoder.setRenderPipelineState(renderPipelineState)

        return makeRootEncoder(for: encoding,
                               rootPath: [.argument(argument)],
                               function: data.function,
                               metalEncoder: RenderVertexMetalEncoder(renderCommandEncoder))

    }
}
