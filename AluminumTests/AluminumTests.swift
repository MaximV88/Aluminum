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
        
        XCTAssertEqual(resultBuffer.value(), 1)
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
        
        XCTAssertEqual(resultBuffer.value(), 1)
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
        
        XCTAssertEqual(resultBuffer.value(), 45)
    }

    func testArgumentStruct() {
        var resultBuffer: MTLBuffer!

        dispatchController(with: "test_argument_struct") { controller, computeCommandEncoder in
            let encoder = controller.makeEncoder(for: "argument_struct", with: computeCommandEncoder)
            let buffer = makeBuffer(length: encoder.encodedLength)
            encoder.setArgumentBuffer(buffer)

            encoder.encode(1, to: "i")
            encoder.encode(2, to: "j")
            encoder.encode(true, to: "k")
            encoder.encode(Float(3), to: "l")
            
            let resultEncoder = controller.makeEncoder(for: "result", with: computeCommandEncoder)
            resultBuffer = makeBuffer(length: resultEncoder.encodedLength)
            resultEncoder.setArgumentBuffer(resultBuffer)
        }
        
        XCTAssertEqual(resultBuffer.value(), 7)
    }
    
    func testArgumentComplexStruct() {
        var resultBuffer: MTLBuffer!

        dispatchController(with: "test_argument_complex_struct") { controller, computeCommandEncoder in
            let encoder = controller.makeEncoder(for: "argument_complex_struct", with: computeCommandEncoder)
            let buffer = makeBuffer(length: encoder.encodedLength)
            encoder.setArgumentBuffer(buffer)
            
            (0 ..< 10).forEach {
                encoder.encode(Int32($0), to: "i_arr[\($0)]")
                encoder.encode(UInt32($0), to: [.argument("ui_arr"), .index(UInt($0))])
            }
            
            encoder.encode(UInt(10), to: [.argument("j")])
            
            let resultEncoder = controller.makeEncoder(for: "result", with: computeCommandEncoder)
            resultBuffer = makeBuffer(length: resultEncoder.encodedLength)
            resultEncoder.setArgumentBuffer(resultBuffer)
        }
        
        XCTAssertEqual(resultBuffer.value(), 100)
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
        
        XCTAssertEqual(resultBuffer.value(), 68)
    }
        
    func testArgumentBufferArray() {
        var resultBuffer: MTLBuffer!

        dispatchController(with: "test_argument_buffer_array") { controller, computeCommandEncoder in
            let encoder = controller.makeEncoder(for: "argument_buffer_array", with: computeCommandEncoder)
            let buffer = makeBuffer(length: encoder.encodedLength)
            encoder.setArgumentBuffer(buffer)

            let intBuffers: [MTLBuffer] = (0..<10).map { _ in makeBuffer(length: MemoryLayout<Int32>.size * 10) }
            intBuffers.forEach {
                let intBufferPtr = $0.contents().assumingMemoryBound(to: Int32.self)
                (0 ..< 10).forEach { intBufferPtr[$0] = Int32($0) }
            }
            
            for i in 0 ..< 10 {
                encoder.encode(intBuffers[i], to: "[\(i)].buff")
                encoder.encode(11, to: [.index(UInt(i)), .argument("i")])
                encoder.encode(12, to: [.index(UInt(i)), .argument("j")])
            }
            
            let resultEncoder = controller.makeEncoder(for: "result", with: computeCommandEncoder)
            resultBuffer = makeBuffer(length: resultEncoder.encodedLength)
            resultEncoder.setArgumentBuffer(resultBuffer)
        }
        
        XCTAssertEqual(resultBuffer.value(), 680)
    }

    func testArgumentBufferWithNestedArgumentBuffer() {
        var resultBuffer: MTLBuffer!

        dispatchController(with: "test_argument_buffer_with_nested_argument_buffer") { controller, computeCommandEncoder in
            let encoder = controller.makeEncoder(for: "argument_buffer", with: computeCommandEncoder)
            let buffer = makeBuffer(length: encoder.encodedLength)
            encoder.setArgumentBuffer(buffer)
            
            encoder.encode(100, to: "i")
            
            let childEncoder = encoder.childEncoder(for: "child")
            let childArgumentBuffer = makeBuffer(length: childEncoder.encodedLength)
            childEncoder.setArgumentBuffer(childArgumentBuffer)
            
            let intBuffer = makeBuffer(length: MemoryLayout<Int32>.size * 10)
            let intBufferPtr = intBuffer.contents().assumingMemoryBound(to: Int32.self)
            (0 ..< 10).forEach { intBufferPtr[$0] = Int32($0) }
            
            childEncoder.encode(intBuffer, to: [.argument("buff")])
            childEncoder.encode(11, to: [.argument("i")])
            childEncoder.encode(12, to: [.argument("j")])
            
            let resultEncoder = controller.makeEncoder(for: "result", with: computeCommandEncoder)
            resultBuffer = makeBuffer(length: resultEncoder.encodedLength)
            resultEncoder.setArgumentBuffer(resultBuffer)
        }
        
        XCTAssertEqual(resultBuffer.value(), 168)
    }

    func testArgumentBufferArrayWithNestedArray() {
        var resultBuffer: MTLBuffer!

        dispatchController(with: "test_argument_buffer_array_with_nested_array") { controller, computeCommandEncoder in
            let encoder = controller.makeEncoder(for: "argument_buffer", with: computeCommandEncoder)
            let buffer = makeBuffer(length: encoder.encodedLength)
            encoder.setArgumentBuffer(buffer)
            
            for i: UInt in 0 ..< 10 {
                encoder.encode(UInt32(i), to: "[\(i)].i")
                
                for j: UInt in 0 ..< 2 {
                    encoder.encode(UInt32(i), to: "[\(i)].j[\(j)].j")
                    
                    (0 ..< 10).forEach {
                        encoder.encode(Int32($0), to: "[\(i)].j[\(j)].i_arr[\($0)]")
                        encoder.encode(UInt32($0), to: "[\(i)].j[\(j)].ui_arr[\($0)]")
                    }
                }
                
                let resultEncoder = controller.makeEncoder(for: "result", with: computeCommandEncoder)
                resultBuffer = makeBuffer(length: resultEncoder.encodedLength)
                resultEncoder.setArgumentBuffer(resultBuffer)
            }
        }
        
        XCTAssertEqual(resultBuffer.value(), 1935)
    }
    
    func testArgumentBufferArrayWithNestedArgumentBuffer() {
        var resultBuffer: MTLBuffer!

        dispatchController(with: "test_argument_buffer_array_with_nested_argument_buffer") { controller, computeCommandEncoder in
            
            let encoder = controller.makeEncoder(for: "argument_buffer", with: computeCommandEncoder)
            let buffer = makeBuffer(length: encoder.encodedLength)
            encoder.setArgumentBuffer(buffer)
            
            let intBuffer = makeBuffer(length: MemoryLayout<Int32>.size * 10)
            let intBufferPtr = intBuffer.contents().assumingMemoryBound(to: Int32.self)
            (0 ..< 10).forEach { intBufferPtr[$0] = Int32($0) }

            for i: UInt in 0 ..< 10 {
                let childEncoder = encoder.childEncoder(for: "[\(i)].i")
                let childEncoderBuffer = makeBuffer(length: childEncoder.encodedLength)
                childEncoder.setArgumentBuffer(childEncoderBuffer)
                
                childEncoder.encode(intBuffer, to: "buff")
                childEncoder.encode(Int32(11), to: "i")
                childEncoder.encode(UInt32(12), to: "j")
            }
            
            let resultEncoder = controller.makeEncoder(for: "result", with: computeCommandEncoder)
            resultBuffer = makeBuffer(length: resultEncoder.encodedLength)
            resultEncoder.setArgumentBuffer(resultBuffer)
        }
        
        XCTAssertEqual(resultBuffer.value(), 680)
    }

    func testArgumentBufferArrayWithNestedArgumentBufferArray() {
        var resultBuffer: MTLBuffer!

        dispatchController(with: "test_argument_buffer_array_with_nested_argument_buffer_array") { controller, computeCommandEncoder in
            let encoder = controller.makeEncoder(for: "argument_buffer", with: computeCommandEncoder)
            let buffer = makeBuffer(length: encoder.encodedLength)
            encoder.setArgumentBuffer(buffer)
            
            let intBuffer = makeBuffer(length: MemoryLayout<Int32>.size * 10)
            let intBufferPtr = intBuffer.contents().assumingMemoryBound(to: Int32.self)
            (0 ..< 10).forEach { intBufferPtr[$0] = Int32($0) }

            for i: UInt in 0 ..< 10 {
                encoder.encode(UInt32(i), to: [.index(i), .argument("i")])
                
                encoder.encode(intBuffer, to: "[\(i)].j[0].buff")
                encoder.encode(Int32(11), to: "[\(i)].j[0].i")
                encoder.encode(UInt32(12), to: "[\(i)].j[0].j")
                
                encoder.encode(intBuffer, to: "[\(i)].j[1].buff")
                encoder.encode(Int32(11), to: "[\(i)].j[1].i")
                encoder.encode(UInt32(12), to: "[\(i)].j[1].j")
            }
            
            let resultEncoder = controller.makeEncoder(for: "result", with: computeCommandEncoder)
            resultBuffer = makeBuffer(length: resultEncoder.encodedLength)
            resultEncoder.setArgumentBuffer(resultBuffer)
        }
        
        XCTAssertEqual(resultBuffer.value(), 1405)
    }
        
    func testArgumentBufferArrayWithNestedArgumentBufferAndArray() {
        var resultBuffer: MTLBuffer!

        dispatchController(with: "test_argument_buffer_array_with_nested_argument_buffer_and_array") {
            controller, computeCommandEncoder in
            
            let encoder = controller.makeEncoder(for: "argument_buffer", with: computeCommandEncoder)
            let buffer = makeBuffer(length: encoder.encodedLength)
            encoder.setArgumentBuffer(buffer)
            
            let intBuffer = makeBuffer(length: MemoryLayout<Int32>.size * 10)
            let intBufferPtr = intBuffer.contents().assumingMemoryBound(to: Int32.self)
            (0 ..< 10).forEach { intBufferPtr[$0] = Int32($0) }

            for i: UInt in 0 ..< 10 {
                (0 ..< 10).forEach {
                    encoder.encode(Int32($0), to: "[\(i)].i_arr[\($0)]")
                    encoder.encode(UInt32($0), to: "[\(i)].ui_arr[\($0)]")
                }

                let childEncoder = encoder.childEncoder(for: "[\(i)].i")
                let childEncoderBuffer = makeBuffer(length: childEncoder.encodedLength)
                childEncoder.setArgumentBuffer(childEncoderBuffer)
                
                childEncoder.encode(intBuffer, to: "buff")
                childEncoder.encode(Int32(11), to: "i")
                childEncoder.encode(UInt32(12), to: "j")
            }
            
            let resultEncoder = controller.makeEncoder(for: "result", with: computeCommandEncoder)
            resultBuffer = makeBuffer(length: resultEncoder.encodedLength)
            resultEncoder.setArgumentBuffer(resultBuffer)
        }
        
        XCTAssertEqual(resultBuffer.value(), 1580)
    }
    
    func testArgumentBufferArrayWithNestedArgumentBufferAndArgumentBufferArray() {
        var resultBuffer: MTLBuffer!

        dispatchController(with: "test_argument_buffer_array_with_nested_argument_buffer_and_argument_buffer_array") {
            controller, computeCommandEncoder in
            
            let encoder = controller.makeEncoder(for: "argument_buffer", with: computeCommandEncoder)
            let buffer = makeBuffer(length: encoder.encodedLength)
            encoder.setArgumentBuffer(buffer)
            
            let intBuffer = makeBuffer(length: MemoryLayout<Int32>.size * 10)
            let intBufferPtr = intBuffer.contents().assumingMemoryBound(to: Int32.self)
            (0 ..< 10).forEach { intBufferPtr[$0] = Int32($0) }

            for i: UInt in 0 ..< 10 {
                let childEncoder = encoder.childEncoder(for: "[\(i)].i")
                let childEncoderBuffer = makeBuffer(length: childEncoder.encodedLength)
                childEncoder.setArgumentBuffer(childEncoderBuffer)
                
                childEncoder.encode(intBuffer, to: "buff")
                childEncoder.encode(Int32(11), to: "i")
                childEncoder.encode(UInt32(12), to: "j")
                
                encoder.encode(intBuffer, to: "[\(i)].j[0].buff")
                encoder.encode(Int32(11), to: "[\(i)].j[0].i")
                encoder.encode(UInt32(12), to: "[\(i)].j[0].j")
                
                encoder.encode(intBuffer, to: "[\(i)].j[1].buff")
                encoder.encode(Int32(11), to: "[\(i)].j[1].i")
                encoder.encode(UInt32(12), to: "[\(i)].j[1].j")
            }
            
            let resultEncoder = controller.makeEncoder(for: "result", with: computeCommandEncoder)
            resultBuffer = makeBuffer(length: resultEncoder.encodedLength)
            resultEncoder.setArgumentBuffer(resultBuffer)
        }
        
        XCTAssertEqual(resultBuffer.value(), 2040)
    }
    
    func testArgumentBufferWithMultiNestedArgumentBuffer() {
        var resultBuffer: MTLBuffer!

        dispatchController(with: "test_argument_buffer_with_multi_nested_argument_buffer") { controller, computeCommandEncoder in
            
            let encoder = controller.makeEncoder(for: "argument_buffer", with: computeCommandEncoder)
            let buffer = makeBuffer(length: encoder.encodedLength)
            encoder.setArgumentBuffer(buffer)
            
            let intBuffer = makeBuffer(length: MemoryLayout<Int32>.size * 10)
            let intBufferPtr = intBuffer.contents().assumingMemoryBound(to: Int32.self)
            (0 ..< 10).forEach { intBufferPtr[$0] = Int32($0) }

            let childEncoderB = encoder.childEncoder(for: "b")
            let childEncoderBBuffer = makeBuffer(length: childEncoderB.encodedLength)
            childEncoderB.setArgumentBuffer(childEncoderBBuffer)
            
            let childEncoderC = childEncoderB.childEncoder(for: "c")
            let childEncoderCBuffer = makeBuffer(length: childEncoderC.encodedLength)
            childEncoderC.setArgumentBuffer(childEncoderCBuffer)
            
            let childEncoderMain = childEncoderC.childEncoder(for: "i")
            let childEncoderMainBuffer = makeBuffer(length: childEncoderMain.encodedLength)
            childEncoderMain.setArgumentBuffer(childEncoderMainBuffer)

            childEncoderMain.encode(intBuffer, to: "buff")
            childEncoderMain.encode(Int32(11), to: "i")
            childEncoderMain.encode(UInt32(12), to: "j")

            let resultEncoder = controller.makeEncoder(for: "result", with: computeCommandEncoder)
            resultBuffer = makeBuffer(length: resultEncoder.encodedLength)
            resultEncoder.setArgumentBuffer(resultBuffer)
        }
        
        XCTAssertEqual(resultBuffer.value(), 68)
    }
    
    func testArgumentBufferArrayWithMultiNestedArgumentBuffer() {
        var resultBuffer: MTLBuffer!

        dispatchController(with: "test_argument_buffer_array_with_multi_nested_argument_buffer") { controller, computeCommandEncoder in
            
            let encoder = controller.makeEncoder(for: "argument_buffer", with: computeCommandEncoder)
            let buffer = makeBuffer(length: encoder.encodedLength)
            encoder.setArgumentBuffer(buffer)
            
            let intBuffer = makeBuffer(length: MemoryLayout<Int32>.size * 10)
            let intBufferPtr = intBuffer.contents().assumingMemoryBound(to: Int32.self)
            (0 ..< 10).forEach { intBufferPtr[$0] = Int32($0) }
            
            for i: UInt in 0 ..< 10 {
                let childEncoderB = encoder.childEncoder(for: "[\(i)].b")
                let childEncoderBBuffer = makeBuffer(length: childEncoderB.encodedLength)
                childEncoderB.setArgumentBuffer(childEncoderBBuffer)
                
                let childEncoderC = childEncoderB.childEncoder(for: "c")
                let childEncoderCBuffer = makeBuffer(length: childEncoderC.encodedLength)
                childEncoderC.setArgumentBuffer(childEncoderCBuffer)
                
                let childEncoderMain = childEncoderC.childEncoder(for: "i")
                let childEncoderMainBuffer = makeBuffer(length: childEncoderMain.encodedLength)
                childEncoderMain.setArgumentBuffer(childEncoderMainBuffer)
                
                childEncoderMain.encode(intBuffer, to: "buff")
                childEncoderMain.encode(Int32(11), to: "i")
                childEncoderMain.encode(UInt32(12), to: "j")
                
                let resultEncoder = controller.makeEncoder(for: "result", with: computeCommandEncoder)
                resultBuffer = makeBuffer(length: resultEncoder.encodedLength)
                resultEncoder.setArgumentBuffer(resultBuffer)
            }
        }
        
        XCTAssertEqual(resultBuffer.value(), 680)
    }
    
    func testArgumentBufferEncodableBuffer() {
        var resultBuffer: MTLBuffer!

        dispatchController(with: "test_argument_buffer_encodable_buffer") { controller, computeCommandEncoder in
            let encoder = controller.makeEncoder(for: "argument_buffer", with: computeCommandEncoder)
            let buffer = makeBuffer(length: encoder.encodedLength, value: UInt32(1))
            encoder.setArgumentBuffer(buffer)
            
            let encodableBuffer = makeBuffer(length: 12)
            encoder.encode(encodableBuffer, to: "i") { encoder in
                encoder.encode(true, to: "k")
                encoder.encode(Int32(2), to: "i")
                encoder.encode(UInt32(3), to: "j")
            }
            
            let resultEncoder = controller.makeEncoder(for: "result", with: computeCommandEncoder)
            resultBuffer = makeBuffer(length: resultEncoder.encodedLength)
            resultEncoder.setArgumentBuffer(resultBuffer)
        }
        
        XCTAssertEqual(resultBuffer.value(), 6)
    }
    
    func testArgumentBufferEncodableBufferArray() {
        var resultBuffer: MTLBuffer!

        dispatchController(with: "test_argument_buffer_encodable_buffer_array") { controller, computeCommandEncoder in
            let encoder = controller.makeEncoder(for: "argument_buffer", with: computeCommandEncoder)
            let buffer = makeBuffer(length: encoder.encodedLength, value: UInt32(1))
            encoder.setArgumentBuffer(buffer)
            
            for i: UInt in 0 ..< 10 {
                let encodableBuffer = makeBuffer(length: 12)
                encoder.encode(encodableBuffer, to: [.index(i), .argument("i")]) { encoder in
                    encoder.encode(true, to: "k")
                    encoder.encode(Int32(2), to: "i")
                    encoder.encode(UInt32(3), to: "j")
                }
            }
            
            let resultEncoder = controller.makeEncoder(for: "result", with: computeCommandEncoder)
            resultBuffer = makeBuffer(length: resultEncoder.encodedLength)
            resultEncoder.setArgumentBuffer(resultBuffer)
        }
        
        XCTAssertEqual(resultBuffer.value(), 7)
    }
    
    // there cant be an argument buffer inside a metal array, so its an encoded buffer?
    
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

private extension MTLBuffer {
    func value<T>() -> T {
        return contents().assumingMemoryBound(to: T.self).pointee
    }
}
