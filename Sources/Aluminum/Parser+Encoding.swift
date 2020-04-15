//
//  Parser+Encoding.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 15/04/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal


extension Parser {
    class Encoding {
        
        let dataTypePath: [DataType]
        
        var dataType: DataType {
            return dataTypePath[startIndex]
        }
        
        private let parsePath: [ParseType]
        private let parser: Parser
        private let startIndex: Int
        
        init(dataTypePath: [DataType],
             parsePath: ParsePath,
             parser: Parser,
             startIndex: Int)
        {
            precondition(validateEncodablePath(from: dataTypePath[startIndex...]), .invalidEncoderPath)
            
            self.dataTypePath = dataTypePath
            self.parsePath = parsePath
            self.parser = parser
            self.startIndex = startIndex
        }
        
        func childEncoding(for localPath: Path) -> Encoding {
            let parsePath = self.parsePath + localPath.parsePath
            
            guard let dataTypePath = parser.mapping[parsePath] else {
                fatalError(.nonExistingPath)
            }
            
            for (index, dataType) in dataTypePath[(startIndex + 1)...].enumerated() {
                if !dataType.isEncodable { continue }

                return Encoding(dataTypePath: dataTypePath,
                                parsePath: parsePath,
                                parser: parser,
                                startIndex: startIndex + index + 1)
            }
                        
            fatalError(.invalidChildEncoderPath)
        }
                
        func localDataTypePath(for localPath: Path) -> [DataType] {
            guard let dataTypePath = parser.mapping[parsePath + localPath.parsePath] else {
                fatalError(.nonExistingPath)
            }

            precondition(validateEncodablePath(from: dataTypePath[(startIndex + 1)...]), .invalidEncoderPath)
            return Array(dataTypePath[startIndex...])
        }
        
        func localDataTypePath(to childEncoder: Encoding) -> [DataType] {
            // validate encoders share same path
            assert(childEncoder.dataTypePath[...(dataTypePath.count - 1)] == dataTypePath[...])
            return Array(childEncoder.dataTypePath[startIndex...childEncoder.startIndex])
        }
        
        /// Non fatal query since query is intended for candidate paths
        func candidateLocalDataTypePath(for candidatePath: Path) -> [DataType] {
            guard let dataTypePath = parser.mapping[parsePath + candidatePath.parsePath] else {
                return []
            }
            
            guard validateEncodablePath(from: dataTypePath[(startIndex + 1)...]) else {
                return []
            }
            
            return Array(dataTypePath[startIndex...])
        }
    }
}

private func validateEncodablePath<DataTypeArray: RandomAccessCollection>(
    from path: DataTypeArray
) -> Bool
    where DataTypeArray.Element == DataType, DataTypeArray.Index == Int
{
    guard !path.isEmpty else { return true }
    
    var encounteredEncodable = false

    for item in path {
        if item.isEncodable {
            guard !encounteredEncodable else {
                return false
            }
            
            encounteredEncodable = true
        }
    }
    
    return true
}
