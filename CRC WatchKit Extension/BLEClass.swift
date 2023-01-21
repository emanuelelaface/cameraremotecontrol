//
//  BLEClass.swift
//  CRC WatchKit Extension
//
//  Created by Emanuele Laface on 2021-11-21.
//

import Foundation
import CoreBluetooth

class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
  
    var myCentral: CBCentralManager!

    @Published var isSwitchedOn = false
    @Published var isConnected = false
        
    private var peripheral: CBPeripheral!
    private var characteristicPairing: CBCharacteristic!
    private var characteristicEvent: CBCharacteristic!

    override init() {
        super.init()
        myCentral = CBCentralManager(delegate: self, queue: nil)
        myCentral.delegate = self
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            self.isSwitchedOn = true
        }
        else {
            self.isSwitchedOn = false
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let services = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            if (services[0]).uuidString == UUIDService {
                self.stopScanning()
                self.myCentral.connect(peripheral, options: nil)
                self.peripheral = peripheral
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices(nil)
        peripheral.delegate = self
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral: CBPeripheral, error: Error?) {
        self.isConnected = false
        self.startScanning()
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            for service in services {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let charac = service.characteristics {
            for characteristic in charac {
                if characteristic.uuid == CBUUID(string: UUIDCharacteristicPairing) {
                    self.characteristicPairing = characteristic
                    self.peripheral.writeValue(AppName, for: self.characteristicPairing, type: .withoutResponse)
                    self.isConnected = true
                }
                if characteristic.uuid == CBUUID(string: UUIDCharacteristicEvent) {
                    self.characteristicEvent = characteristic
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        self.peripheral.readValue(for: characteristic)
    }
    
    func startScanning() {
        myCentral.scanForPeripherals(withServices: nil, options: nil)
    }
    
    func stopScanning() {
        myCentral.stopScan()
    }
    
    func clickButton(mode: Int, button: Int) {
        let data = Data([UInt8(mode | button)])
        self.peripheral.writeValue(data, for: self.characteristicEvent, type: .withoutResponse)
        usleep(60000)
        self.peripheral.writeValue(Data([UInt8(SwitchImmediate)]), for: self.characteristicEvent, type: .withoutResponse)

    }
}
