//
//  AluminumTests.swift
//  AluminumTests
//
//  Created by Maxim Vainshtein on 18/01/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import XCTest
import Aluminum


class AluminumTests: XCTestCase {
    enum TestError: Error {
        case noFunctionForName
    }
    
    private var device: MTLDevice!
    private var library: MTLLibrary!
    

    override func setUp() {
        device = MTLCreateSystemDefaultDevice()
        library = try! device.makeDefaultLibrary(bundle: Bundle(for: AluminumTests.self))
    }

    func testArguments() {
        let controller = try! makeComputePipelineState(functionName: "test_arguments")
        let binder = controller.makeBinder()
        
        let buff = device.makeBuffer(length: 1, options: .storageModeShared)!
        
        do {
            try binder.bind("buff", to: buff)
            try binder.bind("uniforms", struct: TestArgumentsUniforms(bufferLength: uint(buff.length)))
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }

}

private extension AluminumTests {
    func makeComputePipelineState(functionName: String) throws -> ComputePipelineStateController {
        guard let function = library.makeFunction(name: functionName) else {
            throw TestError.noFunctionForName
        }
        
        return try ComputePipelineStateController(function: function)
    }
}
