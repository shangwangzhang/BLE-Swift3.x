//
//  BLELister.swift
//  bluz-iOS-app
//
//  Created by ShangWang on 11/27/16.
//  Copyright © 2016 ShangWang. All rights reserved.
//

import UIKit
import Foundation
import CoreBluetooth

let BLUZ_UUID = "871E0223-38FF-77B1-ED41-9FB3AA142DB2"
let BLUZ_CHAR_RX_UUID = "871E0224-38FF-77B1-ED41-9FB3AA142DB2"
let BLUZ_CHAR_TX_UUID = "871E0225-38FF-77B1-ED41-9FB3AA142DB2"

public class BLEManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var centralManager: CBCentralManager?
    public var peripherals = [BLEDeviceInfo]()
    var eventCallback: ((BLEManagerEvent, BLEDeviceInfo) -> (Void))?
    var startScanOnPowerup: Bool?
    var discoverOnlyBluz: Bool?
    var automaticReconnect: Bool?
    var lastService: UInt8
    private var taskID: UIBackgroundTaskIdentifier
    
    enum BLEManagerEvent {
        case deviceDiscovered
        case deviceUpdated
        case deviceConnected
        case deviceDisconnected
        case bleRadioChange
    }

    override init(){
        lastService = 0
        taskID = -1
        super.init()
        discoverOnlyBluz = false
        
        let defaults = UserDefaults.standard
        defaults.synchronize()
        let ac = defaults.object(forKey: "automaticReconnect")
        let dob = defaults.object(forKey: "discoverOnlyBluz")

        if dob != nil {
            discoverOnlyBluz = dob as? Bool
        }
        if ac != nil {
            automaticReconnect = ac as? Bool
        }
        startScanOnPowerup = false
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func registerCallback(_ callback: @escaping (_ result: BLEManagerEvent, _ peripheral: BLEDeviceInfo) -> Void) {
        eventCallback = callback
    }
    
    func startScanning() {
        if let _ = centralManager {
            if #available(iOS 10.0, *) {
                if (centralManager!.state == CBManagerState.poweredOn) {
                    centralManager!.scanForPeripherals(withServices: nil, options: nil)
                } else {
                    startScanOnPowerup = true
                }
            } else {
                // Fallback on earlier versions
                
//                if (centralManager!.state == CBCentralManagerState.PoweredOn) {
//                    centralManager!.scanForPeripheralsWithServices(nil, options: nil)
//                } else {
//                    startScanOnPowerup = true
//                }

            }
        }
    }
    
    func stopScanning() {
        if let _ = centralManager {
            centralManager?.stopScan()
        }
    }
    
    func clearScanResults() {
//        peripherals.removeAll()
        
        for dev in peripherals {
            if dev.state != BLEDeviceState.connected {
                if let index = findPeripheralIndex(dev.peripheral!) {
                    peripherals.remove(at: index)
                }
            }
        }

    }
    
    func peripheralCount() -> Int {
        return peripherals.count
    }
    
    func findPeripheralIndex(_ periperhal: CBPeripheral) -> Int? {
        var i = 0
        for dev in peripherals {
            if dev.peripheral!.identifier == periperhal.identifier {
                return i
            }
            i += 1
        }
        return nil
    }
    
    func peripheralAtIndex(_ index: Int) -> BLEDeviceInfo? {
        return peripherals[index]
    }
    
    func indexOfPeripheral(_ peripheral: BLEDeviceInfo) -> Int? {
        return findPeripheralIndex(peripheral.peripheral!)
    }
    
    //peripheral commands
    func connectPeripheral(_ peripheral: BLEDeviceInfo) {
        peripheral.state = BLEDeviceState.bleConnecting
        centralManager!.connect(peripheral.peripheral!, options: nil)
    }
    
    func disconnectPeripheral(_ peripheral: BLEDeviceInfo) {
        centralManager!.cancelPeripheralConnection(peripheral.peripheral!)
    }
    
    
    //delegate methods
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : AnyObject], rssi RSSI: NSNumber) {
        if let index = findPeripheralIndex(peripheral) {
            //TO DO: update the objecta advertisiment data and RSSI
            peripherals[index].advertisementData = advertisementData
            peripherals[index].rssi = RSSI
            eventCallback!(BLEManagerEvent.deviceUpdated, peripherals[index])
        } else {
            let dIno = BLEDeviceInfo(p: peripheral, r: RSSI, a: advertisementData)
            if self.discoverOnlyBluz == true && dIno.isBluzCompatible() {
                peripherals.append(dIno)
                eventCallback!(BLEManagerEvent.deviceDiscovered, dIno)
            } else if self.discoverOnlyBluz == false {
                peripherals.append(dIno)
                eventCallback!(BLEManagerEvent.deviceDiscovered, dIno)
            }
        }
    }
    
    func requestId(_ timer: Timer) {
        let peripheral = timer.userInfo as! BLEDeviceInfo
        peripheral.requestParticleId()
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("peripheral connected")
        if let index = findPeripheralIndex(peripheral) {
            peripherals[index].state = BLEDeviceState.cloudConnecting
            eventCallback!(BLEManagerEvent.deviceConnected, peripherals[index])
            peripherals[index].peripheral?.delegate = self;
            peripherals[index].peripheral?.discoverServices([CBUUID(string: BLUZ_UUID)])
            let _ = Timer.scheduledTimer(timeInterval: 22, target: self, selector: #selector(BLEManager.requestId(_:)), userInfo: peripherals[index], repeats: false)
        }
    }
    
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        print("peripheral disconnected")
        if let index = findPeripheralIndex(peripheral) {
            peripherals[index].state = BLEDeviceState.disconnected
            peripherals[index].socket?.disconnect()
            peripherals[index].lastByteCount = 0
            peripherals[index].rxBuffer.length = 0
            eventCallback!(BLEManagerEvent.deviceDisconnected, peripherals[index])
            if self.automaticReconnect == true {
                connectPeripheral(peripherals[index])
            }
        }
    }
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if #available(iOS 10.0, *) {
            switch (central.state) {
            case CBManagerState.poweredOff:
                print("Power off")
                
            case CBManagerState.unauthorized:
                print("Unauthorized")
                // Indicate to user that the iOS device does not support BLE.
                break
                
            case CBManagerState.unknown:
                print("Unknown")
                // Wait for another event
                break
                
            case CBManagerState.poweredOn:
                print("Powered on")
                if let _ = startScanOnPowerup {
                    centralManager!.scanForPeripherals(withServices: nil, options: nil)
                }
                
            case CBManagerState.resetting:
                print("resetting")
                
            case CBManagerState.unsupported:
                print("unsupported")
                break
                
            default:
                break
            }
        } else {
            // Fallback on earlier versions
            
//            switch (central.state) {
//            case CBCentralManagerState.PoweredOff:
//                print("Power off")
//                
//            case CBCentralManagerState.Unauthorized:
//                print("Unauthorized")
//                // Indicate to user that the iOS device does not support BLE.
//                break
//                
//            case CBCentralManagerState.Unknown:
//                print("Unknown")
//                // Wait for another event
//                break
//                
//            case CBCentralManagerState.PoweredOn:
//                print("Powered on")
//                if let _ = startScanOnPowerup {
//                    centralManager!.scanForPeripheralsWithServices(nil, options: nil)
//                }
//                
//            case CBCentralManagerState.Resetting:
//                print("resetting")
//                
//            case CBCentralManagerState.Unsupported:
//                print("unsupported")
//                break
//                
//            default:
//                break
//            }
        }
    }
    
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        for service in peripheral.services! {
            if service.uuid == CBUUID(string: BLUZ_UUID) {
                peripheral.discoverCharacteristics([CBUUID(string: BLUZ_CHAR_RX_UUID), CBUUID(string: BLUZ_CHAR_TX_UUID)], for: service)
            }
        }
        
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: NSError?) {
        for characteristic in service.characteristics! {
            if characteristic.uuid == CBUUID(string: BLUZ_CHAR_RX_UUID) {
                print("found the right thing")
                peripheral.setNotifyValue(true, for: characteristic)
            } else if characteristic.uuid == CBUUID(string: BLUZ_CHAR_TX_UUID) {
                if let index = findPeripheralIndex(peripheral) {
                    peripherals[index].writeCharacteristic = characteristic
                }
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: NSError?) {
        if let index = findPeripheralIndex(peripheral) {
            peripherals[index].peripheral!.readValue(for: characteristic)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: NSError?) {
        if error != nil {
            NSLog(error.debugDescription)
        }
        NSLog("Finished writing value")
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: NSError?) {
        if characteristic.uuid != CBUUID(string: BLUZ_CHAR_RX_UUID) {
            return
        }
        
        if taskID > 0 {
            self.endBackgroundUpdateTask(taskID);
        }
        
        taskID = self.beginBackgroundUpdateTask();
        
        if let index = findPeripheralIndex(peripheral) {
            let peripheral = peripherals[index]
            let eosBuffer = Data(bytes: UnsafePointer<UInt8>([0x03, 0x04] as [UInt8]), count: 2)
            
            NSLog("Got data from bluz of size " + String(characteristic.value!.count))
            if peripheral.state == BLEDeviceState.cloudConnecting && (characteristic.value! == eosBuffer) && peripheral.lastByteCount > 0 {
               
                let bytes = "" as NSMutableString
                let length = characteristic.value!.count
                var byteArray = [UInt8](repeating: 0x0, count: length)
                (characteristic.value! as NSData).getBytes(&byteArray, length:length)
                
                for byte in byteArray {
                    bytes.appendFormat("%02x ", byte)
                }
                NSLog("As we connect, bluz data is: " + (bytes as String))
                
                peripheral.socket?.connect()
                peripheral.rxBuffer.length = 0
                peripheral.state = BLEDeviceState.connected
            } else if peripheral.state == BLEDeviceState.connected {
                if (characteristic.value!.count == 2 && (characteristic.value! == eosBuffer)) {
                    if lastService == 0x01 {
                        peripheral.socket?.write( UnsafePointer<UInt8>((peripheral.rxBuffer.bytes)), len: (peripheral.rxBuffer.length))
                    } else if lastService == 2 {
                        let length = peripheral.rxBuffer.length
                        let deviceId = "" as NSMutableString

                        var byteArray = [UInt8](repeating: 0x0, count: length)
                        peripheral.rxBuffer.getBytes(&byteArray, length:length)
                        
                        for byte in byteArray {
                            deviceId.appendFormat("%02x", byte)
                        }
                        
                        peripheral.cloudId = deviceId
                        getCloudName(peripheral)
                    }
                    peripheral.rxBuffer.length = 0
                } else {
                    if peripheral.rxBuffer.length == 0 {
                        var array = [UInt8](repeating: 0, count: (characteristic.value?.count)!)
                        (characteristic.value! as NSData).getBytes(&array, length: (characteristic.value?.count)!)
                        lastService = array.first!
                        
                        var headerBytes = 1
                        let count = characteristic.value!.count
                        if lastService == 1 {
                            headerBytes = 2
                        }
                        peripheral.rxBuffer.append(characteristic.value!.subdata(in: headerBytes ..< count))
                    } else {
                        peripheral.rxBuffer.append(characteristic.value!)
                    }
                }
            } else {
                //this is to catch issues when reconnecting
                //with beacons, for some reason we are seeing the eos characters sent immediately upon connection, not sure why yet
                peripheral.lastByteCount = characteristic.value!.count

                let bytes = "" as NSMutableString
                let length = characteristic.value!.count
                var byteArray = [UInt8](repeating: 0x0, count: length)
                (characteristic.value! as NSData).getBytes(&byteArray, length:length)
                
                for byte in byteArray {
                    bytes.appendFormat("%02x ", byte)
                }
                NSLog("Bluz data is: " + (bytes as String))
            }
        }
    }
    
    public func getCloudName(_ peripheral: BLEDeviceInfo) {
        SparkCloud.sharedInstance().getDevices { (sparkDevices:[AnyObject]?, error:NSError?) -> Void in
            if error != nil {
                NSLog("Check your internet connectivity")
            }
            else {
                if let devices = sparkDevices as? [SparkDevice] {
                    for device in devices {
                        if device.id == peripheral.cloudId {
                            peripheral.cloudName = device.name
                            peripheral.particleDevice = device
                            peripheral.isClaimed = true
                        }
                    }
                }
            }
            self.eventCallback!(BLEManagerEvent.deviceUpdated, peripheral)
        }
    }
    
    func beginBackgroundUpdateTask() -> UIBackgroundTaskIdentifier {
        return UIApplication.shared().beginBackgroundTask(expirationHandler: {})
    }
    
    func endBackgroundUpdateTask(_ taskID: UIBackgroundTaskIdentifier) {
        UIApplication.shared().endBackgroundTask(taskID)
    }
}
