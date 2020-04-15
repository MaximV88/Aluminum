//
//  MTLComputeCommandEncoder+EncoderGroup.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 12/04/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal


/// Provided explicitly for writing data to a given bind point, by
/// copying data to a temporary buffer of a command encoder.
///
/// Copy is performed by using `setBytes(_:length:index:)`.
public protocol SetBytesEncoder {
    
    /// Bind data (by copy) for a given argument by name.
    /// Infers data length as the stride of the value's memory layout.
    /// This will remove any previous binding for given argument.
    ///
    /// - Parameter parameter: Value to bind (note that the instance's bytes are copied).
    /// - Parameter to: Name of argument (metal function parameter) to bind.
    func setBytes<T>(_ parameter: T?, to: String)
    
    /// Bind data (by copy) for a given argument by name.
    /// This will remove any previous binding for given argument.
    ///
    /// - Parameter bytes: Pointer to memory location from which to begin copy.
    /// - Parameter count: Number of bytes to copy from starting memory location.
    /// - Parameter to: Name of argument (metal function parameter) to bind.
    func setBytes(_ bytes: UnsafeRawPointer, count: Int, to: String)
}

public extension MTLComputeCommandEncoder {
    
    /// Applies the bindings stored in `EncoderGroup` to the applied `MTLComputeCommandEncoder`.
    ///
    /// - Parameter encoderGroup: Group containing all bindings required for it's target function.
    /// - Parameter setBytesClosure: Provides an encoder that is capable of writing to the `MTLComputeCommandEncoder`'s temporary buffer.
    func apply(_ encoderGroup: EncoderGroup, _ setBytesClosure: ((SetBytesEncoder)->())? = nil) {
        let encoder = ComputeMetalEncoder(self)
        
        encoderGroup.applyOn(encoder)
        setBytesClosure?(encoderGroup.makeSetBytesEncoder(for: encoder))
    }
}

public extension MTLRenderCommandEncoder {
    
    /// Applies the bindings stored in `EncoderGroup` to the applied `MTLRenderCommandEncoder`'s `vertex` function.
    ///
    /// - Parameter encoderGroup: Group containing all bindings required for it's target function.
    /// - Parameter setBytesClosure: Provides an encoder that is capable of writing to the `MTLComputeCommandEncoder`'s temporary buffer.
    func applyVertex(_ encoderGroup: EncoderGroup, _ setBytesClosure: ((SetBytesEncoder)->())? = nil) {
        let encoder = RenderVertexMetalEncoder(self)
        
        encoderGroup.applyOn(encoder)
        setBytesClosure?(encoderGroup.makeSetBytesEncoder(for: encoder))
    }
    
    /// Applies the bindings stored in `EncoderGroup` to the applied `MTLRenderCommandEncoder`'s `fragment` function.
    ///
    /// - Parameter encoderGroup: Group containing all bindings required for it's target function.
    /// - Parameter setBytesClosure: Provides an encoder that is capable of writing to the `MTLComputeCommandEncoder`'s temporary buffer.
    func applyFragment(_ encoderGroup: EncoderGroup, _ setBytesClosure: ((SetBytesEncoder)->())? = nil) {
        let encoder = RenderFragmentMetalEncoder(self)
        
        encoderGroup.applyOn(encoder)
        setBytesClosure?(encoderGroup.makeSetBytesEncoder(for: encoder))
    }
}
