//
//  BLEAdvPeripheralBundle.swift
//  bluz-iOS-app
//
//  Created by ShangWang on 11/27/16.
//  Copyright © 2016 ShangWang. All rights reserved.
//

import Foundation
import CoreBluetooth

public enum BLEDeviceState {
    case disconnected
    case bleConnecting
    case cloudConnecting
    case connected
}

public class BLEDeviceInfo: NSObject {
    
    public var peripheral: CBPeripheral?
    public var rssi: NSNumber = 0
    public var advertisementData: [String : AnyObject]
    public var state: BLEDeviceState
    public var socket: ParticleSocket?
    public var rxBuffer: NSMutableData
    public var cloudName: NSString
    public var cloudId: NSString
    public var particleDevice: SparkDevice?
    public var isClaimed: Bool
    public var lastByteCount: Int
    
    public var writeCharacteristic: CBCharacteristic?
    
    init(p: CBPeripheral, r: NSNumber, a: [String : AnyObject]){
        isClaimed = false
        peripheral = p
        rssi = r
        advertisementData = a
        state = BLEDeviceState.disconnected
        socket = ParticleSocket()
        writeCharacteristic = nil
        rxBuffer = NSMutableData()
        cloudName = ""
        cloudId = ""
        lastByteCount = 0
        super.init()
        
        self.socket!.registerCallback(particleSocketCallback)
    }
    
    func numberOfServices() -> Int {
        if let _ = self.advertisementData.index(forKey: "kCBAdvDataServiceUUIDs") {
            let servicesCount = self.advertisementData["kCBAdvDataServiceUUIDs"]?.count
            return servicesCount!
        }
        return 0
    }
    
    func isBluzCompatible() -> Bool {
        if let _ = self.advertisementData.index(forKey: "kCBAdvDataServiceUUIDs") {
            let services: NSArray = self.advertisementData["kCBAdvDataServiceUUIDs"] as! NSArray
            for service in services {
                if (service as AnyObject).description == BLUZ_UUID {
                    return true
                }
            }
        }
        return false
    }
    
    func requestParticleId() {
        let nameBuffer = [0x02, 0x00] as [UInt8]
        sendParticleData(Data(bytes: UnsafePointer<UInt8>(nameBuffer), count: nameBuffer.count), header: nil)
    }
    
    func particleSocketCallback(_ data: Data, header: Data) {
        sendParticleData(data, header: header)
    }
    
    func sendParticleData(_ data: Data, header: Data?) {

        let maxChunk = 960
        
        var writeType = CBCharacteristicWriteType.withResponse
        if let prop = writeCharacteristic?.properties {
            if prop.contains(CBCharacteristicProperties.writeWithoutResponse) {
                NSLog("Can write without response")
                writeType = CBCharacteristicWriteType.withoutResponse
            }
        }
        
//        for var chunkPointer = 0; chunkPointer < data.count; chunkPointer += maxChunk

        var chunkPointer = 0
        
        while chunkPointer < data.count {
            
            var chunkLength = (data.count-chunkPointer > maxChunk ? maxChunk : data.count-chunkPointer)
            
            var chunk = NSMutableData()
            if let _ = header {
                chunk = NSMutableData(data: header!)
                chunk.append(data.subdata(in: chunkPointer ..< chunkPointer + chunkLength))
                chunkLength += (header?.count)!
            } else {
                chunk = NSMutableData(data: data.subdata(in: chunkPointer ..< chunkPointer + chunkLength))
            }
            
//            for var i = 0; i < chunkLength; i+=20
            var i = 0
            
            while i < chunkLength {
                
                let size = (chunkLength-i > 20 ? 20 : chunkLength-i)
                
                let dataSlice = chunk.subdata(with: NSMakeRange(i, size))
                
                peripheral?.writeValue(dataSlice, for: writeCharacteristic!, type: writeType)
                NSLog("Sent data of size " + String(dataSlice.count) + " to bluz")
                
                i+=20
            }
            
            let eosBuffer = [0x03, 0x04] as [UInt8]
            let eos = Data(bytes: UnsafePointer<UInt8>(eosBuffer), count: eosBuffer.count)
            peripheral?.writeValue(eos, for: writeCharacteristic!, type: writeType)
            NSLog("Sent eos to bluz")
            
            chunkPointer += maxChunk            
        }
    }
}

