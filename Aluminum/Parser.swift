//
//  Parser.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 20/01/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Metal


internal class Parser {
    private var mapping = [Path: [Argument]]()
    
    init(arguments: [MTLArgument]) {
        arguments.forEach {
            parseArgument($0)
        }
    }
    
    func argumentPath(for path: Path) -> [Argument]? {
        return mapping[path.argumentPath]
    }
}

private extension Parser {
    func parseArgument(_ argument: MTLArgument) {
        parseArgumentPath([.argument(argument)])
    }
    
    func parseArgumentPath(_ argumentPath: [Argument], from path: Path = []) {
        let component = Parser.pathComponent(for: argumentPath.last!)
        let currentPath = component != nil ? path + [component!] : path
        
        // children should override parent's mapping, assign before recursion
        mapping[currentPath] = argumentPath
        
        for child in argumentPath.last!.children() {
            parseArgumentPath(argumentPath + [child], from: currentPath)
        }
    }
    
    static func pathComponent(for argument: Argument) -> PathComponent? {
        switch argument {
        case .argument(let a): return .argument(a.name)
        case .structMember(let s):
            // invalid naming, ignore
            if s.arrayType() != nil {
                return nil
            }
            
            return .argument(s.name)
        default: return nil
        }
    }
}

private extension Path {
    var argumentPath: Path {
        return filter({
            switch $0 {
            case .argument: return true
            default: return false
            }
        })
    }
}
