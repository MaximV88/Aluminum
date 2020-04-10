//
//  Encoder+Default.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 09/04/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal


extension BytesEncoder {
    func encode(_ bytes: UnsafeRawPointer, count: Int, to path: Path) {
        fatalError(.noExistingBuffer)
    }
}

extension ResourceEncoder {
    func encode(_ buffer: MTLBuffer, offset: Int, to path: Path) {
        fatalError(.noExistingBuffer)
    }
    
    func encode(_ buffers: [MTLBuffer], offsets: [Int], to path: Path) {
        fatalError(.noExistingBuffer)
    }
    
    func encode(_ buffer: MTLBuffer, offset: Int, to path: Path, _ encoderClosure: (BytesEncoder)->()) {
        fatalError(.noExistingBuffer)
    }

    func encode(_ texture: MTLTexture, to path: Path) {
        fatalError(.noExistingTexture)
    }
        
    func encode(_ textures: [MTLTexture], to path: Path) {
        fatalError(.noExistingTexture)
    }
    
    func encode(_ sampler: MTLSamplerState, to path: Path) {
        fatalError(.noExistingSampler)
    }

    func encode(_ samplers: [MTLSamplerState], to path: Path) {
        fatalError(.noExistingSampler)
    }
    
    func encode(_ buffer: MTLIndirectCommandBuffer, to path: Path) {
        fatalError(.noExistingIndirectBuffer)
    }
    
    func encode(_ buffers: [MTLIndirectCommandBuffer], to path: Path) {
        fatalError(.noExistingIndirectBuffer)
    }
}

extension ArgumentBufferEncoder {
    var encodedLength: Int {
        fatalError(.noArgumentBufferRequired)
    }

    func setArgumentBuffer(_ argumentBuffer: MTLBuffer, offset: Int) {
        fatalError(.noArgumentBufferRequired)
    }

    func childEncoder(for path: Path) -> ArgumentBufferEncoder {
        fatalError(.noChildEncoderExists)
    }
}

extension RootEncoder {
    func encode(_ buffer: MTLBuffer, offset: Int) {
        fatalError(.noExistingBuffer)
    }
    
    func encode(_ bytes: UnsafeRawPointer, count: Int) {
        fatalError(.noExistingBuffer)
    }
    
    func encode(_ texture: MTLTexture) {
        fatalError(.noExistingTexture)
    }
    
    func encode(_ textures: [MTLTexture]) {
        fatalError(.noExistingTexture)
    }
    
    func encode(_ sampler: MTLSamplerState) {
        fatalError(.noExistingSampler)
    }
    
    func encode(_ sampler: MTLSamplerState, lodMinClamp: Float, lodMaxClamp: Float) {
        fatalError(.noExistingSampler)
    }

    func encode(_ sampler: [MTLSamplerState]) {
        fatalError(.noExistingSampler)
    }
    
    func encode(_ samplers: [MTLSamplerState], lodMinClamps: [Float], lodMaxClamps: [Float]) {
        fatalError(.noExistingSampler)
    }
}
