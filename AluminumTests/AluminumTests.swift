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
        
        for i in 0 ..< 40 {
            testBufferArr[i].contents().assumingMemoryBound(to: Float.self).pointee = Float(i)
        }
                
        
        do {
            try arrEncoder.setArgumentBuffer(arrBuffer)
            try tarrEncoder.setArgumentBuffer(tarrBuffer)
            try resultEncoder.setArgumentBuffer(resultBuffer)

            for i: UInt in 0 ..< 40 {
                try arrEncoder.encode(UInt32(i), to: [.index(i), .argument("a")])
                try arrEncoder.encode(UInt16(i), to: [.index(i), .argument("c")])
                try arrEncoder.encode(UInt32(i), to: [.index(i), .argument("arr"), .index(0)])
                try arrEncoder.encode(UInt32(1), to: [.index(i), .argument("arr"), .index(1)])
                try arrEncoder.encode(testBufferArr[Int(i)], to: [.index(i), .argument("t")])
                
                try tarrEncoder.encode(UInt(1), to: [.index(i), .argument("l")])
                try tarrEncoder.encode(intBuffer, to: [.index(i), .argument("arr_t"), .index(0), .argument("buffer")])
                try tarrEncoder.encode(trBuffer, to: [.index(i), .argument("arr_t"), .index(0), .argument("tr")])

                try tarrEncoder.encode(trBuffer, to: [.index(i), .argument("t1")])

            }
                    
            
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
