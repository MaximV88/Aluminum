//
//  MTLComputeCommandEncoder+EncoderGroup.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 12/04/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal


public protocol SetBytesEncoder {
    func setBytes<T>(_ parameter: T?, to: String)
    func setBytes(_ bytes: UnsafeRawPointer, count: Int, to: String)
}

public extension MTLComputeCommandEncoder {
    func apply(_ encoderGroup: EncoderGroup, _ setBytesClosure: ((SetBytesEncoder)->())? = nil) {
        let encoder = ComputeMetalEncoder(self)
        
        encoderGroup.applyOn(encoder)
        setBytesClosure?(encoderGroup.makeSetBytesEncoder(for: encoder))
    }
}

public extension MTLRenderCommandEncoder {
    func applyVertex(_ encoderGroup: EncoderGroup, _ setBytesClosure: ((SetBytesEncoder)->())? = nil) {
        let encoder = RenderVertexMetalEncoder(self)
        
        encoderGroup.applyOn(encoder)
        setBytesClosure?(encoderGroup.makeSetBytesEncoder(for: encoder))
    }
    
    func applyFragment(_ encoderGroup: EncoderGroup, _ setBytesClosure: ((SetBytesEncoder)->())? = nil) {
        let encoder = RenderFragmentMetalEncoder(self)
        
        encoderGroup.applyOn(encoder)
        setBytesClosure?(encoderGroup.makeSetBytesEncoder(for: encoder))
    }
}
