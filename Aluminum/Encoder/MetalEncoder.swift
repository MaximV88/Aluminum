//
//  MetalEncoder.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 11/04/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal


internal protocol MetalEncoder {

    //    func setBufferOffset(_ offset: Int)

    func encode(_ bytes: UnsafeRawPointer, count: Int, to index: Int)

    func encode(_ buffer: MTLBuffer, offset: Int, to index: Int)
    
    func encode(_ buffers: [MTLBuffer], offsets: [Int], to range: Range<Int>)
    
    func encode(_ texture: MTLTexture, to index: Int)
        
    func encode(_ textures: [MTLTexture], to range: Range<Int>)

    func encode(_ sampler: MTLSamplerState, to index: Int)
    
    func encode(_ sampler: MTLSamplerState, lodMinClamp: Float, lodMaxClamp: Float, to index: Int)

    func encode(_ samplers: [MTLSamplerState], to range: Range<Int>)
    
    func encode(_ samplers: [MTLSamplerState], lodMinClamps: [Float], lodMaxClamps: [Float], to range: Range<Int>)
    
    func useResource(_ resource: MTLResource, usage: MTLResourceUsage)
    
    func useResources(_ resources: [MTLResource], usage: MTLResourceUsage)
}

internal class ComputeMetalEncoder: MetalEncoder {
    private weak var computeCommandEncoder: MTLComputeCommandEncoder!
    
    init(_ computeCommandEncoder: MTLComputeCommandEncoder) {
        self.computeCommandEncoder = computeCommandEncoder
    }
    
    func encode(_ bytes: UnsafeRawPointer, count: Int, to index: Int) {
        computeCommandEncoder.setBytes(bytes, length: count, index: index)
    }

    func encode(_ buffer: MTLBuffer, offset: Int, to index: Int) {
        computeCommandEncoder.setBuffer(buffer, offset: offset, index: index)
    }
    
    func encode(_ buffers: [MTLBuffer], offsets: [Int], to range: Range<Int>) {
        computeCommandEncoder.setBuffers(buffers, offsets: offsets, range: range)
    }
    
    func encode(_ texture: MTLTexture, to index: Int) {
        computeCommandEncoder.setTexture(texture, index: index)
    }
        
    func encode(_ textures: [MTLTexture], to range: Range<Int>) {
        computeCommandEncoder.setTextures(textures, range: range)
    }

    func encode(_ sampler: MTLSamplerState, to index: Int) {
        computeCommandEncoder.setSamplerState(sampler, index: index)
    }
    
    func encode(_ sampler: MTLSamplerState, lodMinClamp: Float, lodMaxClamp: Float, to index: Int) {
        computeCommandEncoder.setSamplerState(sampler, lodMinClamp: lodMinClamp, lodMaxClamp: lodMaxClamp, index: index)
    }

    func encode(_ samplers: [MTLSamplerState], to range: Range<Int>) {
        computeCommandEncoder.setSamplerStates(samplers, range: range)
    }
    
    func encode(_ samplers: [MTLSamplerState], lodMinClamps: [Float], lodMaxClamps: [Float], to range: Range<Int>) {
        computeCommandEncoder.setSamplerStates(samplers, lodMinClamps: lodMinClamps, lodMaxClamps: lodMaxClamps, range: range)
    }
        
    func useResource(_ resource: MTLResource, usage: MTLResourceUsage) {
        computeCommandEncoder.useResource(resource, usage: usage)
    }
    
    func useResources(_ resources: [MTLResource], usage: MTLResourceUsage) {
        computeCommandEncoder.useResources(resources, usage: usage)
    }
}

internal class RenderVertexMetalEncoder: MetalEncoder {
    private weak var renderCommandEncoder: MTLRenderCommandEncoder!
    
    init(_ renderCommandEncoder: MTLRenderCommandEncoder) {
        self.renderCommandEncoder = renderCommandEncoder
    }
    
    func encode(_ bytes: UnsafeRawPointer, count: Int, to index: Int) {
        renderCommandEncoder.setVertexBytes(bytes, length: count, index: index)
    }

    func encode(_ buffer: MTLBuffer, offset: Int, to index: Int) {
        renderCommandEncoder.setVertexBuffer(buffer, offset: offset, index: index)
    }
    
    func encode(_ buffers: [MTLBuffer], offsets: [Int], to range: Range<Int>) {
        renderCommandEncoder.setVertexBuffers(buffers, offsets: offsets, range: range)
    }
    
    func encode(_ texture: MTLTexture, to index: Int) {
        renderCommandEncoder.setVertexTexture(texture, index: index)
    }
        
    func encode(_ textures: [MTLTexture], to range: Range<Int>) {
        renderCommandEncoder.setVertexTextures(textures, range: range)
    }

    func encode(_ sampler: MTLSamplerState, to index: Int) {
        renderCommandEncoder.setVertexSamplerState(sampler, index: index)
    }
    
    func encode(_ sampler: MTLSamplerState, lodMinClamp: Float, lodMaxClamp: Float, to index: Int) {
        renderCommandEncoder.setVertexSamplerState(sampler, lodMinClamp: lodMinClamp, lodMaxClamp: lodMaxClamp, index: index)
    }

    func encode(_ samplers: [MTLSamplerState], to range: Range<Int>) {
        renderCommandEncoder.setVertexSamplerStates(samplers, range: range)
    }
    
    func encode(_ samplers: [MTLSamplerState], lodMinClamps: [Float], lodMaxClamps: [Float], to range: Range<Int>) {
        renderCommandEncoder.setVertexSamplerStates(samplers, lodMinClamps: lodMinClamps, lodMaxClamps: lodMaxClamps, range: range)
    }
    
    func useResource(_ resource: MTLResource, usage: MTLResourceUsage) {
        renderCommandEncoder.useResource(resource, usage: usage)
    }
    
    func useResources(_ resources: [MTLResource], usage: MTLResourceUsage) {
        renderCommandEncoder.useResources(resources, usage: usage)
    }

}

internal class RenderFragmentMetalEncoder: MetalEncoder {
    private weak var renderCommandEncoder: MTLRenderCommandEncoder!
    
    init(_ renderCommandEncoder: MTLRenderCommandEncoder) {
        self.renderCommandEncoder = renderCommandEncoder
    }
    
    func encode(_ bytes: UnsafeRawPointer, count: Int, to index: Int) {
        renderCommandEncoder.setFragmentBytes(bytes, length: count, index: index)
    }

    func encode(_ buffer: MTLBuffer, offset: Int, to index: Int) {
        renderCommandEncoder.setFragmentBuffer(buffer, offset: offset, index: index)
    }
    
    func encode(_ buffers: [MTLBuffer], offsets: [Int], to range: Range<Int>) {
        renderCommandEncoder.setFragmentBuffers(buffers, offsets: offsets, range: range)
    }
    
    func encode(_ texture: MTLTexture, to index: Int) {
        renderCommandEncoder.setFragmentTexture(texture, index: index)
    }
        
    func encode(_ textures: [MTLTexture], to range: Range<Int>) {
        renderCommandEncoder.setFragmentTextures(textures, range: range)
    }

    func encode(_ sampler: MTLSamplerState, to index: Int) {
        renderCommandEncoder.setFragmentSamplerState(sampler, index: index)
    }
    
    func encode(_ sampler: MTLSamplerState, lodMinClamp: Float, lodMaxClamp: Float, to index: Int) {
        renderCommandEncoder.setFragmentSamplerState(sampler, lodMinClamp: lodMinClamp, lodMaxClamp: lodMaxClamp, index: index)
    }

    func encode(_ samplers: [MTLSamplerState], to range: Range<Int>) {
        renderCommandEncoder.setFragmentSamplerStates(samplers, range: range)
    }
    
    func encode(_ samplers: [MTLSamplerState], lodMinClamps: [Float], lodMaxClamps: [Float], to range: Range<Int>) {
        renderCommandEncoder.setFragmentSamplerStates(samplers, lodMinClamps: lodMinClamps, lodMaxClamps: lodMaxClamps, range: range)
    }
    
    func useResource(_ resource: MTLResource, usage: MTLResourceUsage) {
        renderCommandEncoder.useResource(resource, usage: usage)
    }
    
    func useResources(_ resources: [MTLResource], usage: MTLResourceUsage) {
        renderCommandEncoder.useResources(resources, usage: usage)
    }
}
