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
        runTestController(for: "test_argument_pointer", expected: 1)
        { controller, computeCommandEncoder in
            
            let encoder = controller.makeEncoder(for: "buffer", with: computeCommandEncoder)
            let buffer = makeBuffer(length: encoder.encodedLength, value: UInt32(1))
            encoder.setArgumentBuffer(buffer)
        }
    }
    
    func testArgumentPointerWithCopyBytes() {
        runTestController(for: "test_argument_pointer", expected: 1)
        { controller, computeCommandEncoder in

            let encoder = controller.makeEncoder(for: "buffer", with: computeCommandEncoder)
            encoder.encode(UInt32(1))
        }
    }
        
    func testArgumentArray() {
        runTestController(for: "test_argument_array", expected: 45)
        { controller, computeCommandEncoder in

            let encoder = controller.makeEncoder(for: "array", with: computeCommandEncoder)
            let buffer = makeBuffer(length: encoder.encodedLength)
            encoder.setArgumentBuffer(buffer)

            for i: UInt in 0 ..< 10 {
                encoder.encode(UInt32(i), to: [.index(i)])
            }
        }
    }

    func testArgumentStruct() {
        runTestController(for: "test_argument_struct", expected: 7)
        { controller, computeCommandEncoder in

            let encoder = controller.makeEncoder(for: "argument_struct", with: computeCommandEncoder)
            let buffer = makeBuffer(length: encoder.encodedLength)
            encoder.setArgumentBuffer(buffer)

            encoder.encode(1, to: "i")
            encoder.encode(2, to: "j")
            encoder.encode(true, to: "k")
            encoder.encode(Float(3), to: "l")
        }
    }
    
    func testArgumentComplexStruct() {
        runTestController(for: "test_argument_complex_struct", expected: 100)
        { controller, computeCommandEncoder in

            let encoder = controller.makeEncoder(for: "argument_complex_struct", with: computeCommandEncoder)
            let buffer = makeBuffer(length: encoder.encodedLength)
            encoder.setArgumentBuffer(buffer)
            
            (0 ..< 10).forEach {
                encoder.encode(Int32($0), to: "i_arr[\($0)]")
                encoder.encode(UInt32($0), to: [.argument("ui_arr"), .index(UInt($0))])
            }
            
            encoder.encode(UInt(10), to: [.argument("j")])
        }
    }
        
    func testArgumentBuffer() {
        runTestController(for: "test_argument_buffer", expected: 68)
        { controller, computeCommandEncoder in

            let encoder = controller.makeEncoder(for: "argument_buffer", with: computeCommandEncoder)
            let buffer = makeBuffer(length: encoder.encodedLength)
            encoder.setArgumentBuffer(buffer)
            
            let intBuffer = makeBuffer(length: MemoryLayout<Int32>.size * 10)
            let intBufferPtr = intBuffer.contents().assumingMemoryBound(to: Int32.self)
            (0 ..< 10).forEach { intBufferPtr[$0] = Int32($0) }
            
            encoder.encode(intBuffer, to: [.argument("buff")])
            encoder.encode(11, to: [.argument("i")])
            encoder.encode(12, to: [.argument("j")])
        }
    }
        
    func testArgumentBufferArray() {
        runTestController(for: "test_argument_buffer_array", expected: 680)
        { controller, computeCommandEncoder in

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
        }
    }

    func testArgumentBufferWithNestedArgumentBuffer() {
        runTestController(for: "test_argument_buffer_with_nested_argument_buffer", expected: 168)
        { controller, computeCommandEncoder in

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
        }
    }

    func testArgumentBufferArrayWithNestedArray() {
        runTestController(for: "test_argument_buffer_array_with_nested_array", expected: 1935)
        { controller, computeCommandEncoder in
            
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
            }
        }
    }
    
    func testArgumentBufferArrayWithNestedArgumentBuffer() {
        runTestController(for: "test_argument_buffer_array_with_nested_argument_buffer", expected: 680)
        { controller, computeCommandEncoder in

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
        }
    }

    func testArgumentBufferArrayWithNestedArgumentBufferArray() {
        runTestController(for: "test_argument_buffer_array_with_nested_argument_buffer_array", expected: 1405)
        { controller, computeCommandEncoder in

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
        }
    }
        
    func testArgumentBufferArrayWithNestedArgumentBufferAndArray() {
        runTestController(for: "test_argument_buffer_array_with_nested_argument_buffer_and_array", expected: 1580)
        { controller, computeCommandEncoder in
            
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
        }
    }
    
    func testArgumentBufferArrayWithNestedArgumentBufferAndArgumentBufferArray() {
        runTestController(for: "test_argument_buffer_array_with_nested_argument_buffer_and_argument_buffer_array", expected: 2040)
        { controller, computeCommandEncoder in
            
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
        }
    }
    
    func testArgumentBufferWithMultiNestedArgumentBuffer() {
        runTestController(for: "test_argument_buffer_with_multi_nested_argument_buffer", expected: 68)
        { controller, computeCommandEncoder in

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
        }
    }
    
    func testArgumentBufferArrayWithMultiNestedArgumentBuffer() {
        runTestController(for: "test_argument_buffer_array_with_multi_nested_argument_buffer", expected: 680)
        { controller, computeCommandEncoder in

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
            }
        }
    }
    
    func testArgumentBufferEncodableBuffer() {
        runTestController(for: "test_argument_buffer_encodable_buffer", expected: 6)
        { controller, computeCommandEncoder in

            let encoder = controller.makeEncoder(for: "argument_buffer", with: computeCommandEncoder)
            let buffer = makeBuffer(length: encoder.encodedLength, value: UInt32(1))
            encoder.setArgumentBuffer(buffer)
            
            let encodableBuffer = makeBuffer(length: 12)
            encoder.encode(encodableBuffer, to: "i") { encoder in
                encoder.encode(true, to: "k")
                encoder.encode(Int32(2), to: "i")
                encoder.encode(UInt32(3), to: "j")
            }
        }
    }
    
    func testArgumentBufferEncodableBufferArray() {
        runTestController(for: "test_argument_buffer_encodable_buffer_array", expected: 60)
        { controller, computeCommandEncoder in

            let encoder = controller.makeEncoder(for: "argument_buffer", with: computeCommandEncoder)
            let buffer = makeBuffer(length: encoder.encodedLength, value: UInt32(1))
            encoder.setArgumentBuffer(buffer)
            
            for i: UInt in 0 ..< 10 {
                let encodableBuffer = makeBuffer(length: 12)
                encoder.encode(encodableBuffer, to: [.argument("arr"), .index(i)]) { encoder in
                    encoder.encode(true, to: "k")
                    encoder.encode(Int32(2), to: "i")
                    encoder.encode(UInt32(3), to: "j")
                }
            }
        }
    }
    
    func testArgumentBufferArrayEncodableBufferArray() {
        runTestController(for: "test_argument_buffer_array_encodable_buffer_array", expected: 600)
        { controller, computeCommandEncoder in

            let encoder = controller.makeEncoder(for: "argument_buffer", with: computeCommandEncoder)
            let buffer = makeBuffer(length: encoder.encodedLength, value: UInt32(1))
            encoder.setArgumentBuffer(buffer)
            
            for i: UInt in 0 ..< 10 {
                for j: UInt in 0 ..< 10 {
                    let encodableBuffer = makeBuffer(length: 12)
                    encoder.encode(encodableBuffer, to: [.index(i), .argument("arr"), .index(j)]) { encoder in
                        encoder.encode(true, to: "k")
                        encoder.encode(Int32(2), to: "i")
                        encoder.encode(UInt32(3), to: "j")
                    }
                }
            }
        }
    }
    
    func testArgumentBufferStructArray() {
        runTestController(for: "test_argument_buffer_struct_array", expected: 680)
        { controller, computeCommandEncoder in
            let encoder = controller.makeEncoder(for: "argument", with: computeCommandEncoder)
            let buffer = makeBuffer(length: encoder.encodedLength, value: UInt32(1))
            encoder.setArgumentBuffer(buffer)
            
            let intBuffer = makeBuffer(length: MemoryLayout<Int32>.size * 10)
            let intBufferPtr = intBuffer.contents().assumingMemoryBound(to: Int32.self)
            (0 ..< 10).forEach { intBufferPtr[$0] = Int32($0) }

            for i: UInt in 0 ..< 10 {
                encoder.encode(intBuffer, to: "arr[\(i)].buff")
                encoder.encode(Int32(11), to: "arr[\(i)].i")
                encoder.encode(UInt32(12), to: "arr[\(i)].j")
            }
        }
    }
    
    func testArgumentBufferPointerArray() {
        runTestController(for: "test_argument_buffer_pointer_array", expected: 450)
        { controller, computeCommandEncoder in

            let encoder = controller.makeEncoder(for: "argument", with: computeCommandEncoder)
            let buffer = makeBuffer(length: encoder.encodedLength, value: UInt32(1))
            encoder.setArgumentBuffer(buffer)
            
            let intBuffer = makeBuffer(length: MemoryLayout<Int32>.size * 10)
            let intBufferPtr = intBuffer.contents().assumingMemoryBound(to: Int32.self)
            (0 ..< 10).forEach { intBufferPtr[$0] = Int32($0) }

            for i: UInt in 0 ..< 10 {
                encoder.encode(intBuffer, to: [.argument("arr"), .index(i)])
            }
        }
    }
        
}

private extension AluminumTests {
    func runTestController<T: Equatable>(for functionName: String,
                                         expected: T,
                                         _ configurationBlock: (ComputePipelineStateController, MTLComputeCommandEncoder)->())
    {
        let controller = try! makeComputePipelineState(functionName: functionName)
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let computeCommandEncoder = commandBuffer.makeComputeCommandEncoder()!

        let resultEncoder = controller.makeEncoder(for: "result", with: computeCommandEncoder)
        let resultBuffer = makeBuffer(length: resultEncoder.encodedLength)
        resultEncoder.setArgumentBuffer(resultBuffer)
        
        configurationBlock(controller, computeCommandEncoder)
        dispatchAndCommit(computeCommandEncoder, commandBuffer: commandBuffer, threadCount: 1)

        XCTAssertEqual(resultBuffer.value(), expected)
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
