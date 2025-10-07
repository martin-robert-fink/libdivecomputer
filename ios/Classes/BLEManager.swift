import Foundation
import CoreBluetooth

/// Manages BLE communication for dive computers
/// CRITICAL: Implements write echo filtering based on Subsurface methodology
class BLEManager: NSObject {
    private var peripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var readCharacteristic: CBCharacteristic?
    private var receiveQueue: Data = Data()
    private var lastWriteData: Data?  // Track last write for echo filtering
    private let queueLock = NSLock()
    
    // Callbacks for custom I/O
    var onDataReceived: ((Data) -> Void)?
    var onError: ((Error) -> Void)?
    
    /// Setup BLE device for communication
    func setup(peripheral: CBPeripheral) {
        self.peripheral = peripheral
        peripheral.delegate = self
    }
    
    /// Discover services and characteristics
    func discoverServices() {
        debugPrint("BLEManager: Discovering services")
        peripheral?.discoverServices(nil)
    }
    
    /// Write data to device
    func write(_ data: Data) {
        guard let characteristic = writeCharacteristic else {
            debugPrint("BLEManager: No write characteristic")
            return
        }
        
        queueLock.lock()
        // CRITICAL: Store last write data for echo filtering
        // The BLE write is being echoed back into the read queue, 
        // causing libdivecomputer to read garbage data
        lastWriteData = data
        queueLock.unlock()
        
        debugPrint("BLEManager: Writing \(data.count) bytes")
        peripheral?.writeValue(
            data,
            for: characteristic,
            type: .withResponse
        )
    }
    
    /// Read available data from queue
    func read(maxLength: Int) -> Data? {
        queueLock.lock()
        defer { queueLock.unlock() }
        
        guard !receiveQueue.isEmpty else {
            return nil
        }
        
        let length = min(maxLength, receiveQueue.count)
        let data = receiveQueue.prefix(length)
        receiveQueue.removeFirst(length)
        
        debugPrint("BLEManager: Read \(data.count) bytes, \(receiveQueue.count) remaining")
        return Data(data)
    }
    
    /// Get number of bytes available
    func available() -> Int {
        queueLock.lock()
        defer { queueLock.unlock() }
        return receiveQueue.count
    }
    
    /// Clear receive queue
    func flush() {
        queueLock.lock()
        receiveQueue.removeAll()
        lastWriteData = nil
        queueLock.unlock()
        debugPrint("BLEManager: Flushed queue")
    }
}

// MARK: - CBPeripheralDelegate
extension BLEManager: CBPeripheralDelegate {
    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverServices error: Error?
    ) {
        if let error = error {
            debugPrint("BLEManager: Error discovering services: \(error)")
            onError?(error)
            return
        }
        
        debugPrint("BLEManager: Discovered \(peripheral.services?.count ?? 0) services")
        
        // Discover characteristics for all services
        peripheral.services?.forEach { service in
            debugPrint("BLEManager: Discovering characteristics for service \(service.uuid)")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        if let error = error {
            debugPrint("BLEManager: Error discovering characteristics: \(error)")
            onError?(error)
            return
        }
        
        guard let characteristics = service.characteristics else {
            return
        }
        
        debugPrint("BLEManager: Discovered \(characteristics.count) characteristics")
        
        for characteristic in characteristics {
            debugPrint("BLEManager: Characteristic \(characteristic.uuid)")
            debugPrint("  Properties: \(characteristic.properties)")
            
            // Find write characteristic
            if characteristic.properties.contains(.write) ||
               characteristic.properties.contains(.writeWithoutResponse) {
                writeCharacteristic = characteristic
                debugPrint("BLEManager: Found write characteristic")
            }
            
            // Find read/notify characteristic
            if characteristic.properties.contains(.notify) ||
               characteristic.properties.contains(.indicate) {
                readCharacteristic = characteristic
                
                // Enable notifications
                debugPrint("BLEManager: Enabling notifications")
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    
    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error = error {
            debugPrint("BLEManager: Error updating value: \(error)")
            onError?(error)
            return
        }
        
        guard let data = characteristic.value, !data.isEmpty else {
            return
        }
        
        queueLock.lock()
        
        // CRITICAL FIX: Filter out write echo
        // The BLE write is being echoed back into the read queue,
        // causing libdivecomputer to read garbage data
        if let lastWrite = lastWriteData, lastWrite == data {
            debugPrint("BLEManager: Filtering write echo (\(data.count) bytes)")
            lastWriteData = nil  // Clear after filtering once
            queueLock.unlock()
            return
        }
        
        // Add to receive queue
        receiveQueue.append(data)
        debugPrint("BLEManager: Received \(data.count) bytes, queue: \(receiveQueue.count)")
        
        queueLock.unlock()
        
        // Notify callback
        onDataReceived?(data)
    }
    
    func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error = error {
            debugPrint("BLEManager: Error writing value: \(error)")
            onError?(error)
        } else {
            debugPrint("BLEManager: Write completed")
        }
    }
    
    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error = error {
            debugPrint("BLEManager: Error updating notification state: \(error)")
            onError?(error)
        } else {
            debugPrint("BLEManager: Notifications enabled for \(characteristic.uuid)")
        }
    }
}
