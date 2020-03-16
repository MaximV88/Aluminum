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

    private let captureManager = MTLCaptureManager.shared()
    
    func testArrayArgument() {
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let computeCommandEncoder = commandBuffer.makeComputeCommandEncoder()!
        
        let controller = try! makeComputePipelineState(functionName: "test_array_argument")
        let arrEncoder = try! controller.makeEncoder(for: "arr", with: computeCommandEncoder)
        let resultEncoder = try! controller.makeEncoder(for: "result", with: computeCommandEncoder)
                
        let argumentBuffer = device.makeBuffer(length: 800960, options: .storageModeShared)!
        let resultBuffer = device.makeBuffer(length: MemoryLayout<UInt32>.stride * 1 , options: .storageModeShared)!
        
        let testBufferArr: [MTLBuffer] = (0..<40).map { _ in
            return device.makeBuffer(length: MemoryLayout<Float>.stride * 4 , options: .storageModeShared)!
        }

        for i in 0 ..< 40 {
            testBufferArr[i].contents().assumingMemoryBound(to: Float.self).pointee = Float(i)
        }
        
        arrEncoder.setArgumentBuffer(argumentBuffer)
        resultEncoder.setArgumentBuffer(resultBuffer)
        
        do {
            for i in 0 ..< 40 {
                try arrEncoder.encode(UInt32(i), to: [.index(UInt(i)), .argument("a")])
                try arrEncoder.encode(UInt16(i), to: [.index(UInt(i)), .argument("c")])
                try arrEncoder.encode(UInt32(i), to: [.index(UInt(i)), .argument("arr"), .index(0)])
                try arrEncoder.encode(buffer: testBufferArr[i], to: [.index(UInt(i)), .argument("t")])
            }
            
//            try binder.bind("arr[0].a", to: UInt32(11))
//            try binder.bind("arr[1].a", to: UInt32(22.0))
//            try binder.bind("arr[2].a", to: UInt32(33.0))
//            try binder.bind("arr[3].a", to: UInt32(44.0))
//            try binder.bind("arr[0].arr[0]", to: UInt32(1.0))
//            try binder.bind("arr[1].arr[1]", to: UInt32(2.0))
//            try binder.bind("arr[2].arr[2]", to: UInt32(3.0))
//            try binder.bind("arr[3].arr[3]", to: UInt32(4.0))
//            try binder.bind("arr[3].d[3].a", to: UInt32(5.0))
//            try binder.bind("tarr[0].l", to: UInt32(6.0))
//            try binder.bind("tarr[0].arr_t[0].tr", to: testBuffer)
//            try binder.bind("tarr[0].arr_t[0].tr.i", to: UInt32(1))

            
            dispatchAndCommit(computeCommandEncoder, commandBuffer: commandBuffer, threadCount: 1)
            
            XCTAssertEqual(resultBuffer.contents().assumingMemoryBound(to: UInt32.self).pointee, UInt32(138))

        } catch {
            XCTFail(error.localizedDescription)
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
    
    func dispatchAndCommit(_ computeCommandEncoder: MTLComputeCommandEncoder, commandBuffer: MTLCommandBuffer, threadCount: Int) {
        let threadGroupsCount = MTLSizeMake(1, 1, 1)
        let threadGroups = MTLSizeMake(threadCount, 1, 1)
        
        computeCommandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupsCount)

        computeCommandEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
}
