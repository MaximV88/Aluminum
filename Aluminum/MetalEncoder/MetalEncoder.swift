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
