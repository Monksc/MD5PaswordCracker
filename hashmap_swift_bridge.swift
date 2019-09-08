//
//  hashmap_swift_bridge.swift
//  ReverseMD5Metal
//
//  Created by Cameron Monks on 7/17/19.
//  Copyright © 2019 Cameron Monks. All rights reserved.
//

import Foundation

extension String {
    func toUnsafeMutablePointer() -> UnsafeMutablePointer<Int8> {
        let ns = NSString.init(string: self)
        let ump = UnsafeMutablePointer<Int8>.init(mutating: ns.utf8String!)
        return ump
    }
}


func charStartToString(p: UnsafeMutablePointer<Int8>) -> String {
    
    var p = p
    var str = ""
    while p.pointee != 0 {
        let c = Character(UnicodeScalar(UInt8(p.pointee)))
        str.append(c)
        p = p.advanced(by: 1)
    }
    
    return str
}


// MARK: Linked List

func NodeInit(str: String) -> UnsafeMutablePointer<Node>? {
    let ump = str.toUnsafeMutablePointer()
    let f = NodeInit(ump)
    return f!
}

func NodeAdd(self: UnsafeMutablePointer<Node>, str: String, allowDuplicates: Bool) -> UnsafeMutablePointer<Node>? {
    return NodeAdd(self, str.toUnsafeMutablePointer(), bool(rawValue: allowDuplicates ? 1 : 0))
}

func NodeContains(self: UnsafeMutablePointer<Node>, str: String) -> Bool {
    
    let b = NodeContains(self, str.toUnsafeMutablePointer())
    
    return b.rawValue != 0
}


// MARK: HashSet

func HashSetAdd(self: UnsafeMutablePointer<HashSet>, str: String) -> Bool {
    
    let b = HashSetAdd(self, str.toUnsafeMutablePointer())
    return b.rawValue != 0
}

func HashSetContains(self: UnsafeMutablePointer<HashSet>, str: String) -> Bool {
    
    let b = HashSetContains(self, str.toUnsafeMutablePointer())
    print(b)
    return b.rawValue != 0
}


/*
 
 bool HashSetContains(const HashSet *self, const char *str);
 */
