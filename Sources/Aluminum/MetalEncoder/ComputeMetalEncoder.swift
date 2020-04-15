//
//  ComputeMetalEncoder.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 11/04/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal


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
