//
//  Parser.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 20/01/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal


internal class Parser {
    enum ParseType: Hashable {
        case named(String)
        case indexed
    }
    
    typealias ParsePath = [ParseType]
    private(set) var mapping = [ParsePath: [DataType]]()

    init(arguments: [MTLArgument]) {
        arguments.forEach {
            parseArgument($0)
        }
    }
        
    func encoding(for argument: String) -> Encoding {
        let parsePath: [ParseType] = [.named(argument)]
        guard let dataTypePath = mapping[parsePath] else {
            fatalError(.unknownArgument(argument))
        }
                
        return Encoding(dataTypePath: dataTypePath,
                        parsePath: parsePath,
                        parser: self,
                        startIndex: 0)
    }
}

private extension Parser {
    func parseArgument(_ argument: MTLArgument) {
        traverseToLeaf([.argument(argument)])
    }
    
    func traverseToLeaf(_ metalTypePath: [MetalType]) {
        guard !metalTypePath.last!.children().isEmpty else {
            // reached leaf
            processFromLeaf(metalTypePath)
            return
        }
        
        for child in metalTypePath.last!.children() {
            traverseToLeaf(metalTypePath + [child])
        }
    }
    
    func processFromLeaf(_ metalTypePath: [MetalType]) {
        assert(!metalTypePath.isEmpty)
        
        var iterator = DataTypeIterator(metalTypePath: metalTypePath)
        var aggragateParsePath = [ParseType]()
        var aggragateDataTypePath = [DataType]()
        
        while !iterator.isFinished {
            let result = iterator.next()!
             aggragateDataTypePath.append(result)
               
            let types = Parser.parseTypes(from: result)
            
            // parse path should be mapped for every item in path to it's path
            for itemIndex in 0 ..< types.count {
                let currentParsePath = aggragateParsePath + types[0 ... itemIndex]
                mapping[currentParsePath] = aggragateDataTypePath
            }
            
            aggragateParsePath.append(contentsOf: types)
            
            mapping[aggragateParsePath] = aggragateDataTypePath
        }
    }
    
    static func parseTypes(from pathType: DataType) -> [ParseType] {
        switch pathType {
        case .argument(let a): fallthrough
        case .samplerArgument(let a): fallthrough
        case .textureArgument(let a): fallthrough
        case .encodableArgument(let a): fallthrough
        case .argumentContainingArgumentBuffer(let a, _):
            return a.arrayLength > 1 ? [.named(a.name), .indexed] : [.named(a.name)]
        case .structMember(let s): return [.named(s.name)]
        case .array, .metalArray: return [.indexed]
        default: return []
        }
    }
}

internal extension Path {
    var parsePath: Parser.ParsePath {
        assert(!isEmpty)

        return compactMap {
            switch $0 {
            case .argument(let a): return .named(a)
            case .index: return .indexed
            }
        }
    }
}
