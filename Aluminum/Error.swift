//
//  Errors.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 20/03/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Foundation

func fatalError(_ error: AluminumError) -> Never {
    fatalError(error.localizedDescription)
}

func assert(_ condition: @autoclosure () -> Bool,
            _ error: AluminumError,
            file: StaticString = #file,
            line: UInt = #line)
{
    assert(condition(),
           error.localizedDescription,
           file: file,
           line: line)
}

func assertionFailure(_ error: AluminumError,
                      file: StaticString = #file,
                      line: UInt = #line)
{
    assertionFailure(error.localizedDescription,
                     file: file,
                     line: line)
}

enum AluminumError: Error {
    case unknownArgument(String) // name does not match any argument
    case nonExistingPath
    case invalidEncoderPath // encoder does not support given path (extends outside of it)
    case noArgumentBuffer // did not set argument buffer for encoder
    case invalidArgumentBuffer // argument buffer is too short
    case pathIndexOutOfBounds(Int) // index is not in bounds of array - index of invalid path
    case invalidBufferPath(PathType) // path does not point to a buffer (actual value)
    case invalidBytesPath(PathType) // path does not point to bytes (actual value)
    case invalidBufferEncoderPath(PathType) // path used is not compatible for configuring a buffer (i.e. pointer to indexed struct)
    case invalidChildEncoderPath(PathType) // path used is not compatible for using a child encoder
}
