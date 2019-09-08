//
//  main.swift
//  ReverseMD5Metal
//
//  Created by Cameron Monks on 7/16/19.
//  Copyright © 2019 Cameron Monks. All rights reserved.
//

import Foundation
import Metal

var startBatch: UInt64 = 0
var batchSize: UInt64 = 256
var endBatch: UInt64 = 0

var hash_map: UnsafeMutablePointer<UInt32>!
var hash_map_size: UInt32!

var letterChoices: UnsafeMutablePointer<Node>!
var letterChoicesLength: Int! // How many letters can their be
var letterChoicesTotalSize: Int! // length of letterChoices


let semaphore = DispatchSemaphore(value: 1)

var percentDone: Int = 0
func getMinBatchAndSize(mustBeMax: Bool) -> (start: UInt64, size: UInt64)? {
    
    semaphore.wait()
    
    if startBatch >= endBatch {
        semaphore.signal()
        return nil
    }
    
    let start = startBatch
    var size = batchSize
    
    if startBatch + size > endBatch {
        if mustBeMax {
            semaphore.signal()
            return nil
        }
        size = endBatch - start
    }
    
    startBatch += batchSize
    
    let newPercentDone = Int(((100*start) / endBatch))
    if newPercentDone > percentDone {
        print("WERE \(newPercentDone)% DONE \(start)")
        percentDone = newPercentDone
    }
    
    semaphore.signal()
    
    return (start: start, size: size)
}

func updateBatchSize(newSize: UInt64) {
    
    semaphore.wait()
    
    batchSize = newSize
    
    semaphore.signal()
}

class MetalAddr {
    
    private let device: MTLDevice
    
    // The compute pipeline generated from the compute kernel in the .metal shader file.
    private let md5FunctionPSO: MTLComputePipelineState
    
    // The command queue used to pass commands to the device.
    private let commandQueue: MTLCommandQueue
    
    // Buffers to hold data.
    var hashMapBuffer: MTLBuffer
    var choicesBuffer: MTLBuffer
    var doesItWorkBuffer: MTLBuffer
    var startingIndexBuffer: MTLBuffer
    
    init?(device: MTLDevice) {
        self.device = device
        //self.arrayLength = arraySize
        //self.bufferSize = arraySize * (UInt32.bitWidth / UInt8.bitWidth)
        
        guard let defaultLibrary = device.makeDefaultLibrary(),
            let md5Function = defaultLibrary.makeFunction(name: "solve_md5"),
            let md5FunctionPSO = try? device.makeComputePipelineState(function: md5Function),
            let commandQueue = device.makeCommandQueue()
            else {
                return nil
        }
        
        self.md5FunctionPSO = md5FunctionPSO
        self.commandQueue = commandQueue
        
        let threadCount = 256 //md5FunctionPSO.maxTotalThreadsPerThreadgroup
        //updateBatchSize(newSize: UInt64(threadCount))
        
        
        self.hashMapBuffer = device.makeBuffer(length: Int(hash_map_size) * (UInt32.bitWidth / UInt8.bitWidth), options: MTLResourceOptions.storageModeShared)!
        self.choicesBuffer = device.makeBuffer(length: letterChoicesTotalSize, options: MTLResourceOptions.storageModeShared)!
        self.doesItWorkBuffer = device.makeBuffer(length: Int(threadCount), options: MTLResourceOptions.storageModeShared)!
        self.startingIndexBuffer = device.makeBuffer(length: 2 * (UInt32.bitWidth / UInt8.bitWidth), options: MTLResourceOptions.storageModeShared)!
        
        
        var ptr = hashMapBuffer.contents()
        let byteSize = UInt32.bitWidth / UInt8.bitWidth
        for i in 0..<hash_map_size {
            ptr.storeBytes(of: hash_map.advanced(by: Int(i)).pointee, toByteOffset: Int(i) * byteSize, as: UInt32.self)
        }
        
        let nodeArray = NodeToCharArray(letterChoices)!
        ptr = choicesBuffer.contents()
        for i in 0..<(letterChoicesTotalSize) {
            let value = nodeArray.advanced(by: i).pointee
            ptr.storeBytes(of: value, toByteOffset: i, as: Int8.self)
        }
        
    }
    
    func setDoesItWork(size: Int) {
        
        let ptr = doesItWorkBuffer.contents()
        for i in 0..<size {
            ptr.storeBytes(of: 0, toByteOffset: Int(i), as: Int8.self)
        }
    }
    
    func setStartIndexBuffer(start: UInt, passwordSize: UInt8) {
        let ptr = startingIndexBuffer.contents()
        ptr.storeBytes(of: start, toByteOffset: 0, as: UInt.self)
        ptr.storeBytes(of: passwordSize, toByteOffset: 4, as: UInt8.self)
    }
    
    
    // MARK: MD5
    
    func sendMD5Command() -> Bool {
        
        guard let (start, size) = getMinBatchAndSize(mustBeMax: true) else {
            return false
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(), // must be free
            let computeEncoder = commandBuffer.makeComputeCommandEncoder() // must be free
            else {
                print("ERROR ALREADY RECIEVED START: \(start) SIZE: \(size)")
                return false
        }
        
        setDoesItWork(size: Int(size))
        setStartIndexBuffer(start: UInt(start), passwordSize: UInt8(letterChoicesLength))
        
        encodeMD5Command(computeEncoder: computeEncoder, startIndex: start, size: size)
        computeEncoder.endEncoding()
        commandBuffer.commit()
        
        commandBuffer.waitUntilCompleted()
        
        // See What passwords are correct
        let ptr = doesItWorkBuffer.contents()
        for i in 0..<size {
            
            /*
            let hashPointer = UnsafePointer<UInt32>.init(OpaquePointer.init(hashMapBuffer.contents()))
            let choicesPointer: UnsafePointer<Int8> = UnsafePointer<Int8>.init(OpaquePointer.init(choicesBuffer.contents()))
            let doesItWorkBufferPointer = UnsafeMutablePointer<Int8>.init(OpaquePointer.init(doesItWorkBuffer.contents()))
            let startPointer = UnsafeMutablePointer<UInt32>.init(OpaquePointer.init(startingIndexBuffer.contents()))
            
            solve_md5_cpu(hashPointer, choicesPointer, doesItWorkBufferPointer, startPointer, uint(i))
            */
            
            let value = ptr.load(fromByteOffset: Int(i), as: Int8.self)
            
            if value != 0 {
                let id = i + start
                let passwordPointer: UnsafeMutablePointer<Int8>? = IntegerToAsci(UInt(id), letterChoices)
                let password = String.init(cString: passwordPointer!)
                
                let encryptedPassword = String.init([Character].init(repeating: "\0", count: 33))
                let encryptedPasswordPointer = encryptedPassword.toUnsafeMutablePointer()
                
                md52(passwordPointer, letterChoicesLength, encryptedPasswordPointer)
                
                print("|\(String.init(cString: encryptedPasswordPointer))| |\(password)|")
                free(passwordPointer)
            }
        }
        
        return true
    }
    
    private func encodeMD5Command(computeEncoder: MTLComputeCommandEncoder, startIndex: UInt64, size: UInt64) {
        
        // Encode the pipeline state object and its parameters.
        computeEncoder.setComputePipelineState(md5FunctionPSO)
        computeEncoder.setBuffer(hashMapBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(choicesBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(doesItWorkBuffer, offset: 0, index: 2)
        computeEncoder.setBuffer(startingIndexBuffer, offset: 0, index: 3)
        
        let gridSize = MTLSizeMake(Int(size), 1, 1)
        
        var threadGroupSize = md5FunctionPSO.maxTotalThreadsPerThreadgroup
        if (threadGroupSize > size) {
            threadGroupSize = Int(size)
        }
        
        let threadgroupSize = MTLSizeMake(threadGroupSize, 1, 1)
        
        computeEncoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadgroupSize)
    }
    
}


func test() {
    
    
    let f = "Hello World"
    var n = NodeInit(str: f)!
    
    if let p = NodeAdd(self: n, str: "SS", allowDuplicates: false) {
        n = p
    }
    
    if let p = NodeAdd(self: n, str: "SS", allowDuplicates: false) {
        n = p
    }
    
    
    NodePrint(n)
    
    print("CONTAINS: ", NodeContains(self: n, str: "SS"))
    print("CONTAINS: ", NodeContains(self: n, str: "Hello World"))
    print("CONTAINS: ", NodeContains(self: n, str: "Hello World2"))
    print("CONTAINS: ", NodeContains(self: n, str: "Hello"))
    
    
    let meHashMap = HashSetInit(16)!
    for s in ["Hello World", "Cameron", "Monks"] {
        print("|", s, "|", HashSetAdd(self: meHashMap, str: s))
    }
 
    for s in ["Hello World", "Cameron", "Monks", "Cameron2", "Monk"] {
        print("|", s, "|", HashSetContains(self: meHashMap, str: s))
    }
    
    
    HashSetPrint(meHashMap)
    
    let j = HashSetToArray(meHashMap)!
    
    for i in 0..<43 {
        print(i, ")", j.advanced(by: i).pointee)
    }
    
    for s in ["Hello World", "Cameron", "Monks", "Cameron2", "Monk"] {
        print("|", s, "|", HashSetArrayContains(j, s.toUnsafeMutablePointer()).rawValue == 1)
    }
    
    var letterChoices = NodeInit(str: "0123456789")!
    letterChoices = NodeAdd(self: letterChoices, str: "0123456789", allowDuplicates: true)!
    letterChoices = NodeAdd(self: letterChoices, str: "ABCDEFGHIJKLMNOPQRSTUVWXYZ", allowDuplicates: true)!
    
    let answer = IntegerToAsci(2576, letterChoices)!
    let answerAsString = charStartToString(p: answer)
    print("ANSWER: ", answerAsString)
    
    
    let passwordUnencrypted = "53cr3t#"
    let passwordUnencryptedPointer = passwordUnencrypted.toUnsafeMutablePointer()
    
    let passwordDecrypted = String.init(repeating: "\0", count: 33)
    let passwordDecryptedPointer = passwordDecrypted.toUnsafeMutablePointer()
    
    md52(passwordUnencryptedPointer, passwordUnencrypted.count, passwordDecryptedPointer)
    print(String.init(cString: passwordUnencryptedPointer))
    print(String.init(cString: passwordDecryptedPointer))
    assert("6db0bcc56ea41c547d38d393ffc83f82" == String.init(cString: passwordDecryptedPointer))
}

func gpuDoWork() {
    
    guard let device = MTLCreateSystemDefaultDevice(),
        let adder = MetalAddr(device: device)
        else {
            return
    }
    
    while adder.sendMD5Command() {
        
    }
}

func cpuDoWork() {
    while true {
        
        guard let (start, size) = getMinBatchAndSize(mustBeMax: false) else {
            return
        }
        
        for i in 0..<size {
            
            let id = start + i
            
            let password: UnsafeMutablePointer<Int8>? = IntegerToAsci(UInt(id), letterChoices)!
            
            let encryptedPassword = String.init([Character].init(repeating: "\0", count: 33))
            let encryptedPasswordPointer = encryptedPassword.toUnsafeMutablePointer()
            
            md52(password, letterChoicesLength, encryptedPasswordPointer)
            
            if HashSetArrayContains(hash_map, encryptedPasswordPointer).rawValue != 0 {
                
                print("|\(String.init(cString: encryptedPasswordPointer))| |\(String.init(cString: password!))|")
            }
            
            free(password)
        }
    }
}


func cpuDoWorkGPUTest() {
    
    let choicesArr = NodeToCharArray(letterChoices)
    
    let doesItWork = [Int8].init(repeating: 0, count: Int(batchSize))
    let doesItWorkPointerL = UnsafePointer<Int8>(doesItWork)
    let doesItWorkPointer = UnsafeMutablePointer<Int8>.init(mutating: doesItWorkPointerL)
    
    let startArray : [uint] = [0, UInt32(UInt(letterChoicesLength))]
    let startArrayIndexL = UnsafePointer<uint>(startArray)
    let startArrayIndex = UnsafeMutablePointer<uint>(mutating: startArrayIndexL)
    
    while true {
        
        guard let (start, size) = getMinBatchAndSize(mustBeMax: false) else {
            return
        }
        
        /*
        for i in 0..<size {
            doesItWorkPointer.advanced(by: Int(i)).pointee = 0
        }
        */
        
        startArrayIndex.pointee = uint(start)
        
        for i in 0..<size {
            
            solve_md5_cpu(
                hash_map,
                choicesArr,
                doesItWorkPointer,
                startArrayIndex,
                uint(i)
            );
 
        }
        
        for i in 0..<size {
            
            if doesItWorkPointer.advanced(by: Int(i)).pointee == 1 {
                
                let id = i + start
                let passwordPointer: UnsafeMutablePointer<Int8>? = IntegerToAsci(UInt(id), letterChoices)
                let password = String.init(cString: passwordPointer!)
                
                let encryptedPassword = String.init([Character].init(repeating: "\0", count: 33))
                let encryptedPasswordPointer = encryptedPassword.toUnsafeMutablePointer()
                
                md52(passwordPointer, letterChoicesLength, encryptedPasswordPointer)
                
                print("|\(String.init(cString: encryptedPasswordPointer))| |\(password)|")
            }
        }
    }
}

func main() {

    
    let url = URL.init(fileURLWithPath: "CHANGE URL") // CHANGE 1 URL
    
    do {
        let text = try String(contentsOf: url, encoding: .utf8)
        let hashMap = HashSetInit(8192)!
        for line in text.split(separator: "\n") {
            _ = HashSetAdd(self: hashMap, str: String(line))
        }
        
        hash_map = HashSetToArray(hashMap)
        hash_map_size = HashSetToArraySize(hashMap)
        
    }
    catch {
        print("ERROR LINE", #line)
    }
    
    
    /*
    letterChoices = NodeInit(str: "QWERTYUIOPASDFGHJKLZXCVBNMqwertyuiopasdfghjklzxcvbnm0123456789")!
    endBatch = 26 + 26 + 10
    letterChoicesTotalSize = 26 + 26 + 10 + 1
    for _ in 0..<0 {
        letterChoices = NodeAdd(self: letterChoices, str: "QWERTYUIOPASDFGHJKLZXCVBNMqwertyuiopasdfghjklzxcvbnm0123456789", allowDuplicates: true)!
        endBatch *= (26 + 26 + 10)
        letterChoicesTotalSize += 26 + 26 + 10 + 1
    }
 */
    
    endBatch = 10 * 10 * 26 * 26 * 26 * (26*2) // CHANGE 2 endBatch
    letterChoicesTotalSize = 11 + 11 + 3 * 27 + 26*2 + 1 // CHANGE 3 letterChoicesTotalSize
    letterChoices = NodeInit(str: "0123456789")!
    //letterChoices = NodeAdd(self: letterChoices, str: "0123456789", allowDuplicates: true)!
    letterChoices = NodeAdd(self: letterChoices, str: "0123456789", allowDuplicates: true)!
    //letterChoices = NodeAdd(self: letterChoices, str: "qwertyuiopasdfghjklzxcvbnm", allowDuplicates: true)!
    //letterChoices = NodeAdd(self: letterChoices, str: "qwertyuiopasdfghjklzxcvbnm", allowDuplicates: true)!
    //letterChoices = NodeAdd(self: letterChoices, str: "qwertyuiopasdfghjklzxcvbnm", allowDuplicates: true)!
    letterChoices = NodeAdd(self: letterChoices, str: "qwertyuiopasdfghjklzxcvbnm", allowDuplicates: true)!
    letterChoices = NodeAdd(self: letterChoices, str: "qwertyuiopasdfghjklzxcvbnm", allowDuplicates: true)!
    letterChoices = NodeAdd(self: letterChoices, str: "s", allowDuplicates: true)!
    letterChoices = NodeAdd(self: letterChoices, str: "QWERTYUIOPASDFGHJKLZXCVBNMqwertyuiopasdfghjklzxcvbnm", allowDuplicates: true)!
    
    letterChoicesLength = Int(NodeCount(letterChoices))
    
    let startTime = Date.init()
    
    // CHANGE 5
    var threadsFinished = [Bool].init(repeating: false, count: 9) // 9 is CPU + GPU -1
    
    // 8 is the amount of threeads on CPU
    for i in 0..<8 {
        DispatchQueue.global(qos: .default).async {
            cpuDoWork()
            threadsFinished[i] = true
        }
    }
    
    // AMOUNT OF GPU RUNNING IS 1 + the one below here
    DispatchQueue.global(qos: .default).async {
        gpuDoWork()
        threadsFinished[8] = true
    }
    // FINAL THREAD. EITHER DO GPU or CPU
    gpuDoWork()
    //cpuDoWork()
    //cpuDoWorkGPUTest()
    
    while threadsFinished.contains(false) {
        sleep(1)
    }
    // CHANGE 5
 
    print(Date.init().timeIntervalSince(startTime))
}


print("START")
//test()
main()

