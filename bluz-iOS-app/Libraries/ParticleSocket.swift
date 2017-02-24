//
//  ParticleSocket.swift
//  bluz-iOS-app
//
//  Created by ShangWang on 12/1/16.
//  Copyright © 2016 ShangWang. All rights reserved.
//

import Foundation

public class ParticleSocket: NSObject, StreamDelegate {
    let serverAddress: CFString = "device.spark.io" as CFString
    let serverPort: UInt32 = 5683
    
    private var inputStream: InputStream!
    private var outputStream: OutputStream!
    
    var dataCallback: ((Data, Data) -> (Void))?
    
    func registerCallback(_ callback: @escaping (_ data: Data, _ length: Data) -> Void) {
        dataCallback = callback
    }
    
    public func connect() {
        var readStream : Unmanaged<CFReadStream>?
        var writeStream : Unmanaged<CFWriteStream>?
        CFStreamCreatePairWithSocketToHost(nil, self.serverAddress, self.serverPort, &readStream, &writeStream)
        
        inputStream = readStream!.takeUnretainedValue()
        outputStream = writeStream!.takeUnretainedValue()
        
        inputStream!.delegate = self
        outputStream!.delegate = self
        
        inputStream!.schedule(in: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
        outputStream!.schedule(in: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
        
        inputStream!.open()
        outputStream!.open()
    }
    
    public func disconnect() {
        inputStream!.close()
        outputStream!.close()
    }
    
    public func write(_ data: UnsafePointer<UInt8>, len: Int) {
        NSLog("Sending data of size " + String(len) + " to Particle")
        outputStream.write(data, maxLength: len)
    }
    
    public func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch (eventCode){
        case Stream.Event.errorOccurred:
            NSLog("ErrorOccurred")
            break
        case Stream.Event.endEncountered:
            NSLog("EndEncountered")
            break
        case Stream.Event():
            NSLog("None")
            break
        case Stream.Event.hasBytesAvailable:
            NSLog("HasBytesAvaible")
            var buffer = [UInt8](repeating: 0, count: 200000)
            if ( aStream == inputStream){
                
                while (inputStream.hasBytesAvailable){
                    let len = inputStream.read(&buffer, maxLength: buffer.count)
                    
                    var header = [UInt8](repeating: 0x00, count: 2)
                    header[0] = 0x01
                    header[1] = 0x00
                    
                    if(len > 0) {
                        dataCallback!( Data(bytes: UnsafePointer<UInt8>(buffer), count: len), Data(bytes: UnsafePointer<UInt8>(header), count: header.count))
                    }
                }
            }
            break
        case Stream.Event.openCompleted:
            NSLog("OpenCompleted")
            break
        case Stream.Event.hasSpaceAvailable:
            NSLog("HasSpaceAvailable")
            break
        default:
            NSLog("Unknown Network Event")
            break
        }
    }
}
