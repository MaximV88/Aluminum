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
        
    func testArgumentPointerWithArgumentBuffer() {
        var resultBuffer: MTLBuffer!

        dispatchController(with: "test_argument_pointer") { controller, computeCommandEncoder in
            let encoder = controller.makeEncoder(for: "buffer", with: computeCommandEncoder)
            let buffer = makeBuffer(length: encoder.encodedLength, value: UInt32(1))
            encoder.setArgumentBuffer(buffer)
            
            let resultEncoder = controller.makeEncoder(for: "result", with: computeCommandEncoder)
            resultBuffer = makeBuffer(length: resultEncoder.encodedLength)
            resultEncoder.setArgumentBuffer(resultBuffer)
        }
        
        XCTAssertEqual(resultBuffer.contents().assumingMemoryBound(to: UInt32.self).pointee, UInt32(1))
    }
    
    func testArgumentPointerWithCopyBytes() {
        var resultBuffer: MTLBuffer!

        dispatchController(with: "test_argument_pointer") { controller, computeCommandEncoder in
            let encoder = controller.makeEncoder(for: "buffer", with: computeCommandEncoder)
            encoder.encode(UInt32(1))
            
            let resultEncoder = controller.makeEncoder(for: "result", with: computeCommandEncoder)
            resultBuffer = makeBuffer(length: resultEncoder.encodedLength)
            resultEncoder.setArgumentBuffer(resultBuffer)
        }
        
        XCTAssertEqual(resultBuffer.contents().assumingMemoryBound(to: UInt32.self).pointee, UInt32(1))
    }
        
    func testArgumentArray() {
        var resultBuffer: MTLBuffer!

        dispatchController(with: "test_argument_array") { controller, computeCommandEncoder in
            let encoder = controller.makeEncoder(for: "array", with: computeCommandEncoder)
            let buffer = makeBuffer(length: encoder.encodedLength)
            encoder.setArgumentBuffer(buffer)

            for i: UInt in 0 ..< 10 {
                encoder.encode(UInt32(i), to: [.index(i)])
            }
            
            let resultEncoder = controller.makeEncoder(for: "result", with: computeCommandEncoder)
            resultBuffer = makeBuffer(length: resultEncoder.encodedLength)
            resultEncoder.setArgumentBuffer(resultBuffer)
        }
        
        XCTAssertEqual(resultBuffer.contents().assumingMemoryBound(to: UInt32.self).pointee, UInt32(45))
    }

    func testArgumentStruct() {
        var resultBuffer: MTLBuffer!

        dispatchController(with: "test_argument_struct") { controller, computeCommandEncoder in
            let encoder = controller.makeEncoder(for: "argument_struct", with: computeCommandEncoder)
            let buffer = makeBuffer(length: encoder.encodedLength)
            encoder.setArgumentBuffer(buffer)

            encoder.encode(1, to: [.argument("i")])
            encoder.encode(2, to: [.argument("j")])
            encoder.encode(true, to: [.argument("k")])
            encoder.encode(Float(3), to: [.argument("l")])
            
            let resultEncoder = controller.makeEncoder(for: "result", with: computeCommandEncoder)
            resultBuffer = makeBuffer(length: resultEncoder.encodedLength)
            resultEncoder.setArgumentBuffer(resultBuffer)
        }
        
        XCTAssertEqual(resultBuffer.contents().assumingMemoryBound(to: UInt32.self).pointee, UInt32(7))
    }
    
    func testArgumentComplexStruct() {
        var resultBuffer: MTLBuffer!

        dispatchController(with: "test_argument_complex_struct") { controller, computeCommandEncoder in
            let encoder = controller.makeEncoder(for: "argument_complex_struct", with: computeCommandEncoder)
            let buffer = makeBuffer(length: encoder.encodedLength)
            encoder.setArgumentBuffer(buffer)
            
            (0 ..< 10).forEach {
                encoder.encode(Int32($0), to: [.argument("i_arr"), .index(UInt($0))])
                encoder.encode(UInt32($0), to: [.argument("ui_arr"), .index(UInt($0))])
            }
            
            let resultEncoder = controller.makeEncoder(for: "result", with: computeCommandEncoder)
            resultBuffer = makeBuffer(length: resultEncoder.encodedLength)
            resultEncoder.setArgumentBuffer(resultBuffer)
        }
        
        XCTAssertEqual(resultBuffer.contents().assumingMemoryBound(to: UInt32.self).pointee, UInt32(68))
    }
    
    func testArgumentBuffer() {
        var resultBuffer: MTLBuffer!

        dispatchController(with: "test_argument_buffer") { controller, computeCommandEncoder in
            let encoder = controller.makeEncoder(for: "argument_buffer", with: computeCommandEncoder)
            let buffer = makeBuffer(length: encoder.encodedLength)
            encoder.setArgumentBuffer(buffer)
            
            let intBuffer = makeBuffer(length: MemoryLayout<Int32>.size * 10)
            let intBufferPtr = intBuffer.contents().assumingMemoryBound(to: Int32.self)
            (0 ..< 10).forEach { intBufferPtr[$0] = Int32($0) }
            

            encoder.encode(intBuffer, to: [.argument("buff")])
            encoder.encode(11, to: [.argument("i")])
            encoder.encode(12, to: [.argument("j")])
            
            let resultEncoder = controller.makeEncoder(for: "result", with: computeCommandEncoder)
            resultBuffer = makeBuffer(length: resultEncoder.encodedLength)
            resultEncoder.setArgumentBuffer(resultBuffer)
        }
        
        XCTAssertEqual(resultBuffer.contents().assumingMemoryBound(to: UInt32.self).pointee, UInt32(68))
    }
    

    // test complex struct ...
    // toDO: check with complex struct that there cant be a case wheres the an argument encoder where an Argument dataType is at

    
    func testArgumentBufferArray() { }
    func testArgumentBufferWithPointer() { }
    func testArgumentBufferArrayWithNestedArray() { }
    func testArgumentBufferArrayWithNestedArgumentBuffer() { }
    func testArgumentBufferArrayWithNestedArgumentBufferAndArray() { }
    
    func testArrayArgument() {
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let computeCommandEncoder = commandBuffer.makeComputeCommandEncoder()!
        
        let controller = try! makeComputePipelineState(functionName: "test_array_argument")
        let arrEncoder = controller.makeEncoder(for: "arr", with: computeCommandEncoder)
        let tarrEncoder = controller.makeEncoder(for: "tarr", with: computeCommandEncoder)
        let resultEncoder = controller.makeEncoder(for: "result", with: computeCommandEncoder)
                
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
            tarrEncoder.encode(trBuffer, to: [.index(i), .argument("arr_t"), .index(0), .argument("tr")]) { encoder in
                encoder.encode(UInt32(i), to: "i")
                encoder.encode(Float(2), to: "k")
                encoder.encode(false, to: "j")
            }
            
                        
            let t1Encoder = tarrEncoder.childEncoder(for: [.index(i), .argument("t1")])
            t1Encoder.setArgumentBuffer(t1Buffers[Int(i)])

            t1Encoder.encode(intBuffer, to: [.argument("buffer")])
        }
        
        
        dispatchAndCommit(computeCommandEncoder, commandBuffer: commandBuffer, threadCount: 1)
        
        XCTAssertEqual(resultBuffer.contents().assumingMemoryBound(to: UInt32.self).pointee, UInt32(138))
        
        
    }
}

private extension AluminumTests {
    func dispatchController(with functionName: String,
                            threadCount: Int = 1,
                            _ configurationBlock: (ComputePipelineStateController, MTLComputeCommandEncoder)->())
    {
        let controller = try! makeComputePipelineState(functionName: functionName)
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let computeCommandEncoder = commandBuffer.makeComputeCommandEncoder()!

        configurationBlock(controller, computeCommandEncoder)
        dispatchAndCommit(computeCommandEncoder, commandBuffer: commandBuffer, threadCount: threadCount)
    }
    
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

    func makeBuffer(length: Int) -> MTLBuffer {
        return device.makeBuffer(length: length, options: .storageModeShared)!
    }

    func makeBuffer<T>(length: Int, value: T) -> MTLBuffer {
        let buffer = makeBuffer(length: length)
        buffer.contents().assumingMemoryBound(to: T.self).pointee = value
        
        return buffer
    }
}
