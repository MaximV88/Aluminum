//
//  Path+VisualFormat.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 10/03/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal


private extension Path {
    private static let argumentPattern = "[a-zA-Z0-9_]+"
    private static let indexPattern = "\\[[\\d]+\\]"
    private static let regex = try! NSRegularExpression(pattern: "(?<argument>\(argumentPattern))|(?<index>\(indexPattern))")
}

private extension Path {
    static func path(withVisualFormat format: String) -> Path {
        let matches = regex.matches(in: format, options: [], range: NSRange(0 ..< format.count))
        
        return matches.compactMap {
            let argumentRange = $0.range(withName: "argument")
            let indexRange = $0.range(withName: "index")

            if let argument = format.substring(with: argumentRange) {
                return .argument(argument)
            } else if let rawIndex = format.substring(with: indexRange) {
                return .index(Int(rawIndex.substring(with: NSMakeRange(1, rawIndex.count - 2))!)!) // ignore '[', ']'
            } else {
                return nil
            }
        }
    }
}

// MARK: - VisualPath support extension

public extension BytesEncoder {
    
    /// Bind data (by copy) for a given argument by name.
    /// Infers data length as the stride of the value's memory layout.
    /// This will remove any previous binding at given path.
    ///
    /// Refer to `setBytes(_:length:index:)` regarding input requirements.
    ///
    /// - Parameter parameter: Value to bind (note that the instance's bytes are copied).
    /// - Parameter path: A visual path to an argument on which binding will be performed.
    func encode<T>(_ parameter: T, to path: String) {
        encode(parameter, to: Path.path(withVisualFormat: path))
    }

    /// Bind data (by copy) for a given argument by name.
    /// This will remove any previous binding at given path.
    ///
    /// Copying is done by targeting offset of value in argument buffer.
    ///
    /// - Parameter bytes: The memory address from which to copy the data.
    /// - Parameter count: The number of bytes to copy.
    /// - Parameter path: A visual path to an argument on which binding will be performed.
    func encode(_ bytes: UnsafeRawPointer, count: Int, to path: String) {
        encode(bytes, count: count, to: Path.path(withVisualFormat: path))
    }
}

public extension ArgumentBufferEncoder {
    
    /// Initializes a new `ArgumentBufferEncoder` at the given path destination.
    /// Destination must refer to a buffer.
    ///
    /// - Parameter path: A visual path to a buffer destination for which the encoder is initialized.
    /// - Returns: An `ArgumentBufferEncoder` for the destination buffer specified at `path`.
    func childEncoder(for path: String) -> ArgumentBufferEncoder {
        childEncoder(for: Path.path(withVisualFormat: path))
    }
    
    /// Binds a `MTLBuffer` to destination argument with a default offset of 0.
    /// This will remove any previous binding.
    ///
    /// - Parameter buffer: The `MTLBuffer` object to set in the argument table.
    /// - Parameter path: A visual path to an argument on which binding will be performed.
    func encode(_ buffer: MTLBuffer, to path: String) {
        encode(buffer, to: Path.path(withVisualFormat: path))
    }
    
    /// Binds a `MTLBuffer` to destination argument.
    /// This will remove any previous binding.
    ///
    /// - Parameter buffer: The `MTLBuffer` object to set in the argument table.
    /// - Parameter offset: Where the data begins, in bytes, from the start of the buffer.
    /// - Parameter path: A visual path to an argument on which binding will be performed.
    func encode(_ buffer: MTLBuffer, offset: Int, to path: String) {
        encode(buffer, offset: offset, to: Path.path(withVisualFormat: path))
    }

    /// Binds a `MTLBuffer` to destination argument, with addition of changing values in buffer for target argument with a default offset of 0.
    /// This will remove any previous binding.
    ///
    /// - Parameter buffer: The `MTLBuffer` object to set in the argument buffer.
    /// - Parameter path: A visual path to an argument on which binding will be performed.
    /// - Parameter encoderClosure: A closure that provides `BytesEncoder` to encode target argument values.
    func encode(_ buffer: MTLBuffer, to path: String, _ encoderClosure: (BytesEncoder)->()) {
        encode(buffer, to: Path.path(withVisualFormat: path), encoderClosure)
    }
    
    /// Binds a `MTLBuffer` to destination argument, with addition of changing values in buffer for target argument.
    /// This will remove any previous binding.
    ///
    /// - Parameter buffer: The `MTLBuffer` object to set in the argument buffer.
    /// - Parameter offset: Where the data begins, in bytes, from the start of the buffer.
    /// - Parameter path: A visual path to an argument on which binding will be performed.
    /// - Parameter encoderClosure: A closure that provides `BytesEncoder` to encode target argument values.
    func encode(_ buffer: MTLBuffer, offset: Int, to path: String, _ encoderClosure: (BytesEncoder)->()) {
        encode(buffer, offset: offset, to: Path.path(withVisualFormat: path), encoderClosure)
    }
    
    /// Binds a `MTLTexture` to destination argument.
    /// This will remove any previous binding.
    ///
    /// Refer to `setTexture(_:index:)` in `MTLArgumentEncoder` regarding usage.
    ///
    /// - Parameter texture: The texture to set in the texture argument buffer.
    /// - Parameter path: A visual path to an argument on which binding will be performed.
    func encode(_ texture: MTLTexture, to path: String) {
        encode(texture, to: Path.path(withVisualFormat: path))
    }
    
    /// Binds an array of `MTLTexture` to destination argument.
    /// This will remove any previous binding.
    ///
    /// Refer to `setTextures(_:range:)` in `MTLArgumentEncoder` regarding usage.
    ///
    /// - Parameter textures: The array of textures to set in the argument buffer.
    /// - Parameter path: A visual path to an argument on which binding will be performed.
    func encode(_ textures: [MTLTexture], to path: String) {
        encode(textures, to: Path.path(withVisualFormat: path))
    }

    /// Binds a `MTLSamplerState` to destination argument.
    /// This will remove any previous binding.
    ///
    /// Refer to `setSamplerState(_:index:)` in `MTLArgumentEncoder` regarding usage.
    ///
    /// - Parameter sampler: The sampler state to set in the argument buffer.
    /// - Parameter path: A visual path to an argument on which binding will be performed.
    func encode(_ sampler: MTLSamplerState, to path: String) {
        encode(sampler, to: Path.path(withVisualFormat: path))
    }

    /// Binds an array of `MTLSamplerState` to destination argument.
    /// This will remove any previous binding.
    ///
    /// Refer to `setSamplerStates(_:range:)` in `MTLArgumentEncoder` regarding usage.
    ///
    /// - Parameter samplers: The array of sampler states to set in the argument buffer.
    /// - Parameter path: A visual path to an argument on which binding will be performed.
    func encode(_ samplers: [MTLSamplerState], to path: String) {
        encode(samplers, to: Path.path(withVisualFormat: path))
    }
    
    /// Binds a `MTLRenderPipelineState` to destination argument.
    /// This will remove any previous binding.
    ///
    /// Refer to `setRenderPipelineState(_:)` in `MTLArgumentEncoder` regarding usage.
    ///
    /// - Parameter pipeline: The render pipeline state to set in the argument buffer.
    /// - Parameter path: A visual path to an argument on which binding will be performed.
    @available(iOS 13, *)
    func encode(_ pipeline: MTLRenderPipelineState, to path: String) {
        encode(pipeline, to: Path.path(withVisualFormat: path))
    }
    
    /// Binds an array of `MTLRenderPipelineState` to destination argument.
    /// This will remove any previous binding.
    ///
    /// Refer to `setRenderPipelineStates(_:range:)` in `MTLArgumentEncoder` regarding usage.
    ///
    /// - Parameter pipelines: The array of render pipeline states to set in the argument buffer.
    /// - Parameter path: A visual path to an argument on which binding will be performed.
#if os(macOS)
    func encode(_ pipelines: [MTLRenderPipelineState], to path: String) {
        encode(pipelines, to: Path.path(withVisualFormat: path))
    }
#endif

    /// Binds a `MTLIndirectCommandBuffer` to destination argument.
    /// This will remove any previous binding.
    ///
    /// Refer to `setIndirectCommandBuffer(_:index:)` in `MTLArgumentEncoder` regarding usage.
    ///
    /// - Parameter buffer: The indirect command buffer to set in the argument buffer.
    /// - Parameter path: A visual path to an argument on which binding will be performed.
    func encode(_ buffer: MTLIndirectCommandBuffer, to path: String) {
        encode(buffer, to: Path.path(withVisualFormat: path))
    }
    
    /// Binds an array of `MTLIndirectCommandBuffer` to destination argument.
    /// This will remove any previous binding.
    ///
    /// Refer to `setIndirectCommandBuffers(_:range:)` in `MTLArgumentEncoder` regarding usage.
    ///
    /// - Parameter buffers: The array of indirect command buffers to set in the argument buffer.
    /// - Parameter path: A visual path to an argument on which binding will be performed.
    func encode(_ buffers: [MTLIndirectCommandBuffer], to path: String) {
        encode(buffers, to: Path.path(withVisualFormat: path))
    }
}
