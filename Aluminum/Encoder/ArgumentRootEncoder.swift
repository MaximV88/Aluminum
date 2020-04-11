//
//  ArgumentRootEncoder.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 09/04/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal


internal class ArgumentRootEncoder {
    private let encoding: Parser.Encoding
    private let argument: MTLArgument

    private let metalEncoder: MetalEncoder
    private weak var argumentBuffer: MTLBuffer!
    
    init(encoding: Parser.Encoding,
         metalEncoder: MetalEncoder)
    {
        guard case let .argument(argument) = encoding.dataType else {
            fatalError("ArgumentRootEncoder expects an argument path that starts with an argument.")
        }

        self.encoding = encoding
        self.argument = argument
        self.metalEncoder = metalEncoder
    }
}

extension ArgumentRootEncoder: RootEncoder {
    func encode(_ buffer: MTLBuffer, offset: Int) {
        metalEncoder.encode(buffer, offset: offset, to: argument.index)
    }

    func encode(_ bytes: UnsafeRawPointer, count: Int) {
        metalEncoder.encode(bytes, count: count, to: argument.index)
    }
}
