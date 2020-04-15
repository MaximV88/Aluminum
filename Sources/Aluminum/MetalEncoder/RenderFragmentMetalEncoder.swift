//
//  RenderFragmentMetalEncoder.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 11/04/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal


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
