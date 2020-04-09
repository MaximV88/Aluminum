//
//  EncodableBufferEncoder.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 09/04/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal


internal class EncodableBufferEncoder {
    private let encoding: Parser.Encoding
    private let encodableBuffer: MTLBuffer
    private let offset: Int

    init(encoding: Parser.Encoding, encodableBuffer: MTLBuffer, offset: Int) {
        assert(encoding.dataType.isEncodableBuffer)
        
        self.encoding = encoding
        self.encodableBuffer = encodableBuffer
        self.offset = offset
    }
}

extension EncodableBufferEncoder: BytesEncoder {
    func encode(_ bytes: UnsafeRawPointer, count: Int, to path: Path) {
        let dataTypePath = encoding.localDataTypePath(for: path)
        assert(dataTypePath.last!.isBytes, .invalidBytesPath(dataTypePath.last!))

        let pathOffset = queryOffset(for: path, dataTypePath: dataTypePath[1...])
        let destination = encodableBuffer.contents().assumingMemoryBound(to: UInt8.self)
        let source = bytes.assumingMemoryBound(to: UInt8.self)
        
        for i in 0 ..< count {
            destination[offset + pathOffset + i] = source[i]
        }
    }
}
