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
        let tarrEncoder = try! controller.makeEncoder(for: "tarr", with: computeCommandEncoder)
        let resultEncoder = try! controller.makeEncoder(for: "result", with: computeCommandEncoder)
                
        let arrBuffer = device.makeBuffer(length: arrEncoder.encodedLength, options: .storageModeShared)!
        let tarrBuffer = device.makeBuffer(length: tarrEncoder.encodedLength, options: .storageModeShared)!
        let resultBuffer = device.makeBuffer(length: MemoryLayout<UInt32>.stride * 1 , options: .storageModeShared)!
        
        let testBufferArr: [MTLBuffer] = (0..<40).map { _ in
            return device.makeBuffer(length: MemoryLayout<Float>.stride * 4 , options: .storageModeShared)!
        }
        
        let intBuffer = device.makeBuffer(length: MemoryLayout<Int>.stride, options: .storageModeShared)!
        intBuffer.contents().assumingMemoryBound(to: Int.self).pointee = 5
    
        let trBuffer = device.makeBuffer(length: 1000, options: .storageModeShared)!
        trBuffer.contents().assumingMemoryBound(to: UInt.self).pointee = 0
        
        let t1Buffers: [MTLBuffer] = (0..<40).map { _ in
            return device.makeBuffer(length: 128, options: .storageModeShared)!
        }
        
        for i in 0 ..< 40 {
            testBufferArr[i].contents().assumingMemoryBound(to: Float.self).pointee = Float(i)
        }
                
        
        arrEncoder.setArgumentBuffer(arrBuffer)
        tarrEncoder.setArgumentBuffer(tarrBuffer)
        resultEncoder.setArgumentBuffer(resultBuffer)
                
        for i: UInt in 0 ..< 40 {
            arrEncoder.encode(UInt32(i), to: [.index(i), .argument("a")])
            arrEncoder.encode(UInt16(i), to: [.index(i), .argument("c")])
            arrEncoder.encode(UInt32(i), to: [.index(i), .argument("arr"), .index(0)])
            arrEncoder.encode(UInt32(1), to: [.index(i), .argument("arr"), .index(1)])
            arrEncoder.encode(testBufferArr[Int(i)], to: [.index(i), .argument("t")])

            tarrEncoder.encode(UInt(1), to: [.index(i), .argument("l")])
            tarrEncoder.encode(intBuffer, to: [.index(i), .argument("arr_t"), .index(0), .argument("buffer")])
            tarrEncoder.encode(trBuffer, to: [.index(i), .argument("arr_t"), .index(0), .argument("tr")])
                        
            let t1Encoder = tarrEncoder.childEncoder(for: [.index(i), .argument("t1"), .argument("tr")])
            t1Encoder.setArgumentBuffer(t1Buffers[Int(i)])

            t1Encoder.encode(intBuffer, to: [.argument("buffer")])
        }
        
        
        dispatchAndCommit(computeCommandEncoder, commandBuffer: commandBuffer, threadCount: 1)
        
        XCTAssertEqual(resultBuffer.contents().assumingMemoryBound(to: UInt32.self).pointee, UInt32(138))
        
        
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
