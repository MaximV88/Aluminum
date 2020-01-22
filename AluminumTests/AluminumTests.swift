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
    private var commandQueue: MTLCommandQueue!
    

    override func setUp() {
        device = MTLCreateSystemDefaultDevice()
        library = try! device.makeDefaultLibrary(bundle: Bundle(for: AluminumTests.self))
        commandQueue = device.makeCommandQueue()
    }

    func testArguments() {
        let controller = try! makeComputePipelineState(functionName: "test_arguments")
        let binder = controller.makeBinder()
        
        let buff = device.makeBuffer(length: 1, options: .storageModeShared)!
        
        do {
//            try binder.bind("buff", to: buff)
//            try binder.bind("uniforms", to: TestArgumentsUniforms(bufferLength: uint(buff.length)))
            try binder.bind("arr[10]", to: TestArgumentsUniforms(bufferLength: uint(buff.length)))
        } catch {
            XCTFail(error.localizedDescription)
        }
        
        let encoder = controller.makeEncoder()
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let computeCommandEncoder = commandBuffer.makeComputeCommandEncoder()!
        encoder.encode(computeCommandEncoder, binder: binder)
        
        computeCommandEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
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
