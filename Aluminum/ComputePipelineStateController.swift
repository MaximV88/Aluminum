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
    
    fileprivate struct TypeCount {
        let bufferCount: Int
        let samplerCount: Int
        let textureCount: Int
    }
    
    private let typeCount: TypeCount
    
    public init(_ function: MTLFunction) throws {
        self.function = function
        
        var reflection: MTLComputePipelineReflection?
        self.computePipelineState = try function.device.makeComputePipelineState(function: function,
                                                                                 options: [.argumentInfo, .bufferTypeInfo],
                                                                                 reflection: &reflection)
        
        self.parser = Parser(arguments: reflection!.arguments)
        
        var bufferCount = 0
        var samplerCount = 0
        var textureCount = 0

        reflection!.arguments.forEach {
            switch $0.type {
            case .buffer: bufferCount += $0.arrayLength // always 1
            case .sampler: samplerCount += $0.arrayLength
            case .texture: textureCount += $0.arrayLength
            default: break
            }
        }
        
        self.typeCount = TypeCount(bufferCount: bufferCount,
                                   samplerCount: samplerCount,
                                   textureCount: textureCount)
    }
    
    public init(_ descriptor: MTLComputePipelineDescriptor) throws {
        self.function = descriptor.computeFunction!

        var reflection: MTLComputePipelineReflection?
        self.computePipelineState = try function.device.makeComputePipelineState(descriptor: descriptor,
                                                                                 options: [.argumentInfo, .bufferTypeInfo],
                                                                                 reflection: &reflection)
        
        self.parser = Parser(arguments: reflection!.arguments)
        
        var bufferCount = 0
        var samplerCount = 0
        var textureCount = 0

        reflection!.arguments.forEach {
            switch $0.type {
            case .buffer: bufferCount += $0.arrayLength // always 1
            case .sampler: samplerCount += $0.arrayLength
            case .texture: textureCount += $0.arrayLength
            default: break
            }
        }
        
        self.typeCount = TypeCount(bufferCount: bufferCount,
                                   samplerCount: samplerCount,
                                   textureCount: textureCount)
    }

    public func makeEncoder(for argument: String, with computeCommandEncoder: MTLComputeCommandEncoder) -> RootEncoder
    {
        return makeRootEncoder(for: parser.encoding(for: argument),
                               rootPath: [.argument(argument)],
                               function: function,
                               metalEncoder: ComputeMetalEncoder(computeCommandEncoder))
    }

    public func makeEncoderGroup() -> ComputeEncoderGroup {
        return ComputeEncoderGroup(computePipelineState: computePipelineState,
                                   function: function,
                                   parser: parser,
                                   typeCount: typeCount)
    }
}


// MARK: - Caching

public protocol SetBytesEncoder {
    func setBytes<T>(_ parameter: T?, to: String)
    func setBytes(_ bytes: UnsafeRawPointer, count: Int, to: String)
}

// remeber setBuffers actually sets multiple arguments since an argument cant have a buffer array (illigal)

// make generic via typedef?
public class ComputeEncoderGroup {
    private struct Buffer {
        let buffer: MTLBuffer
        let offset: Int
    }
    
    private struct Sampler {
        let sampler: MTLSamplerState
        let lodClamps: (min: Float, max: Float)?
    }
    
    private struct Resource {
        let resource: MTLResource
        let usage: MTLResourceUsage
    }
    
    private var buffers = [Buffer]()
    private var textures = [MTLTexture]()
    private var samplerStates = [Sampler]()

    private let computePipelineState: MTLComputePipelineState
    private let function: MTLFunction
    private let parser: Parser

    private var lastBufferIndex: Int? // used for useResources assignment
    private var resourcesList = [Int: [Resource]]()

    // storage ---
    // need to track resources that are removed in override


    fileprivate init(computePipelineState: MTLComputePipelineState,
                     function: MTLFunction,
                     parser: Parser,
                     typeCount: ComputePipelineStateController.TypeCount)
    {
        self.computePipelineState = computePipelineState
        self.function = function
        self.parser = parser
        
        buffers.reserveCapacity(typeCount.bufferCount)
        textures.reserveCapacity(typeCount.textureCount)
        samplerStates.reserveCapacity(typeCount.samplerCount)
    }

    public func makeEncoder(for argument: String) -> RootEncoder {
        let encoding = parser.encoding(for: argument)
        return makeRootEncoder(for: encoding,
                               rootPath: [.argument(argument)],
                               function: function,
                               metalEncoder: self)
    }
}

public extension MTLComputeCommandEncoder {
    func apply(_ encoderGroup: ComputeEncoderGroup, _ interactorClosure: (SetBytesEncoder)->()) { //
        // TODO: optimize to use continous
        
    }
}

extension ComputeEncoderGroup: MetalEncoder {
    func encode(_ bytes: UnsafeRawPointer, count: Int, to index: Int) {
        // TODO: error that says setBytes can only be used in application on metal encoder via closure
        fatalError()
    }

    func encode(_ buffer: MTLBuffer, offset: Int, to index: Int) {
        lastBufferIndex = index
        
        // reset existing resources at index, buffer encoding refers to different encodings
        resourcesList[index] = []
        
        buffers[index] = Buffer(buffer: buffer, offset: offset)
    }

    func encode(_ buffers: [MTLBuffer], offsets: [Int], to range: Range<Int>) {
        fatalError("Not callable from encoding, used only by EncoderGroup.")
    }

    func encode(_ texture: MTLTexture, to index: Int) {
        textures[index] = texture
    }

    func encode(_ textures: [MTLTexture], to range: Range<Int>) {
        range.forEach {
            self.textures[$0] = textures[$0]
        }
    }

    func encode(_ sampler: MTLSamplerState, to index: Int) {
        samplerStates[index] = Sampler(sampler: sampler, lodClamps: nil)
    }

    func encode(_ sampler: MTLSamplerState, lodMinClamp: Float, lodMaxClamp: Float, to index: Int) {
        samplerStates[index] = Sampler(sampler: sampler,
                                       lodClamps: (min: lodMinClamp,
                                                   max: lodMaxClamp))
    }

    func encode(_ samplers: [MTLSamplerState], to range: Range<Int>) {
        range.forEach {
            samplerStates[$0] = Sampler(sampler: samplers[$0], lodClamps: nil)
        }
    }

    func encode(_ samplers: [MTLSamplerState], lodMinClamps: [Float], lodMaxClamps: [Float], to range: Range<Int>) {
        range.forEach {
            samplerStates[$0] = Sampler(sampler: samplers[$0],
                                        lodClamps: (min: lodMinClamps[$0],
                                                    max: lodMaxClamps[$0]))
        }
    }

    func useResource(_ resource: MTLResource, usage: MTLResourceUsage) {
        resourcesList[lastBufferIndex!]!.append(Resource(resource: resource, usage: usage))
    }

    func useResources(_ resources: [MTLResource], usage: MTLResourceUsage) {
        resources.forEach {
            resourcesList[lastBufferIndex!]!.append(Resource(resource: $0, usage: usage))
        }
    }
}
