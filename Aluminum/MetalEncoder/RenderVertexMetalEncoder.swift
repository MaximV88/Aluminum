//
//  RenderVertexMetalEncoder.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 11/04/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal


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
