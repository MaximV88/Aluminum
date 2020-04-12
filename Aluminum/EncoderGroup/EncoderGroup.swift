//
//  EncoderGroup.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 12/04/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal


public class EncoderGroup {
    fileprivate struct Buffer {
        let buffer: MTLBuffer
        let offset: Int
        let index: Int // due to need to ignore setBytes in buffer ordering
    }
    
    fileprivate struct Sampler {
        let sampler: MTLSamplerState
        let lodClamps: (min: Float, max: Float)?
    }
    
    fileprivate struct Resource {
        let resource: MTLResource
        let usage: MTLResourceUsage
    }
    
    fileprivate var buffers: [Buffer?]
    fileprivate var textures: [MTLTexture?]
    fileprivate var samplerStates: [Sampler?]
    fileprivate let argumentNameIndices: [String: Int]

    private let function: MTLFunction
    private let parser: Parser

    private var lastBufferIndex: Int? // used for useResources assignment
    private var resourcesList = [Int: [Resource]]()
    
    internal init(function: MTLFunction,
                  parser: Parser,
                  bufferCount: Int,
                  samplerCount: Int,
                  textureCount: Int,
                  argumentNameIndices: [String: Int])
    {
        self.function = function
        self.parser = parser
        self.argumentNameIndices = argumentNameIndices
        
        buffers = [Buffer?](repeating: nil, count: bufferCount)
        textures = [MTLTexture?](repeating: nil, count: textureCount)
        samplerStates = [Sampler?](repeating: nil, count: samplerCount)
    }

    public func makeEncoder(for argument: String) -> RootEncoder {
        let encoding = parser.encoding(for: argument)
        return makeRootEncoder(for: encoding,
                               rootPath: [.argument(argument)],
                               function: function,
                               metalEncoder: self)
    }
    
    internal func makeSetBytesEncoder<T: MetalEncoder>(for encoder: T) -> SetBytesEncoder {
        return ConcreteSetBytesEncoder<T>(encoder: encoder,
                                          argumentNameIndices: argumentNameIndices)
    }
}

private extension EncoderGroup {
    struct ConcreteSetBytesEncoder<MetalEncoderType: MetalEncoder>: SetBytesEncoder {
        let encoder: MetalEncoderType
        let argumentNameIndices: [String: Int]
        
        func setBytes<T>(_ parameter: T?, to path: String) {
            guard let index = argumentNameIndices[path] else {
                fatalError(.unknownArgument(path))
            }
            
            withUnsafePointer(to: parameter) { ptr in
                encoder.encode(ptr, count: MemoryLayout<T>.stride, to: index)
            }
        }
        
        func setBytes(_ bytes: UnsafeRawPointer, count: Int, to path: String) {
            guard let index = argumentNameIndices[path] else {
                fatalError(.unknownArgument(path))
            }

            encoder.encode(bytes, count: count, to: index)
        }
    }
}

internal extension EncoderGroup {
    func applyOn(_ encoder: MetalEncoder) {
        // TODO: optimize to use continous

        let textures = self.textures.compactMap({ $0 })
        assert(textures.count == self.textures.count,
               .missingTextureEncodings(textures.count, self.textures.count))
        
        let samplerStates = self.samplerStates.compactMap({ $0 })
        assert(samplerStates.count == self.samplerStates.count,
               .missingSamplerStateEncodings(samplerStates.count, self.samplerStates.count))
        
        buffers.forEach {
            if case let .some(value) = $0 {
                encoder.encode(value.buffer, offset: value.offset, to: value.index)
            }
        }
        
        if !textures.isEmpty {
            encoder.encode(textures, to: 0 ..< textures.count)
        }
        
        samplerStates.enumerated().forEach {
            if let lodClamps = $1.lodClamps {
                encoder.encode($1.sampler, lodMinClamp: lodClamps.min, lodMaxClamp: lodClamps.max, to: $0)
            } else {
                encoder.encode($1.sampler, to: $0)
            }
        }
    }
}

extension EncoderGroup: MetalEncoder {
    func encode(_ bytes: UnsafeRawPointer, count: Int, to index: Int) {
        fatalError(.noDirectSetBytesSupportInGroupEncoder)
    }

    func encode(_ buffer: MTLBuffer, offset: Int, to index: Int) {
        lastBufferIndex = index
        
        // reset existing resources at index, buffer encoding refers to different encodings
        resourcesList[index] = []
        
        buffers[index] = Buffer(buffer: buffer, offset: offset, index: index)
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
