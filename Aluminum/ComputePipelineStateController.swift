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
    
    // remove compute command encoder
    public func makeEncoder(for argument: String, with computeCommandEncoder: MTLComputeCommandEncoder) -> RootEncoder
    {
        let encoding = parser.encoding(for: argument)

        // need to be set once
        computeCommandEncoder.setComputePipelineState(computePipelineState)

        return makeRootEncoder(for: encoding,
                               rootPath: [.argument(argument)],
                               function: function,
                               metalEncoder: ComputeMetalEncoder(computeCommandEncoder))
    }

    public func makeEncoderGroup() -> ComputeEncoderGroup {
        return ComputeEncoderGroup(computePipelineState: computePipelineState,
                                   function: function,
                                   parser: parser)
    }
}


// MARK: - Caching

public protocol Interactor {
    func setBytes<T>(_ parameter: T)
    func setBytes(_ bytes: UnsafeRawPointer, count: Int)
}

public protocol ComputeEncoderGroupDataSourceDelegate: AnyObject {
    func didRequestSetBytes(for argumentName: String, with interactor: Interactor)
}

// use cache (Data) - or avoid cache if delegate is provided
// remeber setBuffers actually sets multiple arguments since an argument cant have a buffer array (illigal)

// make generic via typedef?
public class ComputeEncoderGroup {
    private let computePipelineState: MTLComputePipelineState
    private let function: MTLFunction
    private let parser: Parser

    public weak var dataSourceDelegate: ComputeEncoderGroupDataSourceDelegate?
    
    public var computeCommandEncoder: MTLComputeCommandEncoder?
    
    // storage ---
    // check maximum range value from arguments?
    // need to track resources that are removed in override
    
    
    fileprivate init(computePipelineState: MTLComputePipelineState, function: MTLFunction, parser: Parser) {
        self.computePipelineState = computePipelineState
    }
    
    public func makeEncoder(for argument: String) -> RootEncoder {
        let encoding = parser.encoding(for: argument)
        return makeRootEncoder(for: encoding,
                               rootPath: [.argument(argument)],
                               function: function,
                               metalEncoder: self)
    }
    
    // apply on current command encoder, throw if there is no command encoder
    func apply() {
        
    }
}



extension ComputeEncoderGroup: MetalEncoder {
    func encode(_ bytes: UnsafeRawPointer, count: Int, to index: Int) {
        // throw if command encoder is not set, specify that if setBytes is used there has to be a command encoder
    }
    
    func encode(_ buffer: MTLBuffer, offset: Int, to index: Int) {
        <#code#>
    }
    
    func encode(_ buffers: [MTLBuffer], offsets: [Int], to range: Range<Int>) {
        <#code#>
    }
    
    func encode(_ texture: MTLTexture, to index: Int) {
        <#code#>
    }
    
    func encode(_ textures: [MTLTexture], to range: Range<Int>) {
        <#code#>
    }
    
    func encode(_ sampler: MTLSamplerState, to index: Int) {
        <#code#>
    }
    
    func encode(_ sampler: MTLSamplerState, lodMinClamp: Float, lodMaxClamp: Float, to index: Int) {
        <#code#>
    }
    
    func encode(_ samplers: [MTLSamplerState], to range: Range<Int>) {
        <#code#>
    }
    
    func encode(_ samplers: [MTLSamplerState], lodMinClamps: [Float], lodMaxClamps: [Float], to range: Range<Int>) {
        <#code#>
    }
    
    func useResource(_ resource: MTLResource, usage: MTLResourceUsage) {
        <#code#>
    }
    
    func useResources(_ resources: [MTLResource], usage: MTLResourceUsage) {
        <#code#>
    }
}
