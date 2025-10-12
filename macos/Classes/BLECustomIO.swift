import Foundation
import FlutterMacOS

/// Custom I/O implementation that bridges Flutter BLE to libdivecomputer
class BLECustomIO {
    private let channel: FlutterMethodChannel
    private var timeout: UInt32 = 5000 // milliseconds
    private var isConnected: Bool = false
    
    init(channel: FlutterMethodChannel) {
        self.channel = channel
        print("BLECustomIO: Initialized")
    }
    
    /// Set timeout for I/O operations
    func setTimeout(_ timeoutMs: UInt32) {
        self.timeout = timeoutMs
        print("BLECustomIO: Timeout set to \(timeoutMs)ms")
    }
    
    /// Mark connection as established
    func setConnected(_ connected: Bool) {
        self.isConnected = connected
        print("BLECustomIO: Connection status: \(connected)")
    }
    
    /// Read data via BLE (blocking call for libdivecomputer)
    func customRead(data: UnsafeMutableRawPointer, size: Int) -> (Int, Int32) {
        guard isConnected else {
            print("BLECustomIO: Read failed - not connected")
            return (0, 7) // DC_STATUS_IO
        }
        
        print("BLECustomIO: Reading up to \(size) bytes...")
        
        let semaphore = DispatchSemaphore(value: 0)
        var resultData: [UInt8]? = nil
        var errorCode: Int32 = 0 // DC_STATUS_SUCCESS
        
        // Define the work to do
        let performRead = { [weak self] in
            guard let self = self else {
                semaphore.signal()
                return
            }
            
            self.channel.invokeMethod("ble_read", arguments: [
                "maxLength": size,
                "timeoutMs": Int(self.timeout)
            ]) { response in
                if let result = response as? [String: Any] {
                    if let success = result["success"] as? Bool, success {
                        if let dataList = result["data"] as? [UInt8] {
                            resultData = dataList
                            print("BLECustomIO: Received \(dataList.count) bytes from Dart")
                        } else {
                            errorCode = 7 // DC_STATUS_IO
                            print("BLECustomIO: Invalid data format from Dart")
                        }
                    } else {
                        // Handle error
                        let error = result["error"] as? String ?? "UNKNOWN"
                        if error == "TIMEOUT" {
                            errorCode = 8 // DC_STATUS_TIMEOUT
                            print("BLECustomIO: Read timeout")
                        } else {
                            errorCode = 7 // DC_STATUS_IO
                            print("BLECustomIO: Read error: \(error)")
                        }
                    }
                } else {
                    errorCode = 7 // DC_STATUS_IO
                    print("BLECustomIO: Invalid response from Dart")
                }
                semaphore.signal()
            }
        }
        
        // Call on main thread (sync if not already on it, direct if already on it)
        if Thread.isMainThread {
            performRead()
        } else {
            DispatchQueue.main.sync(execute: performRead)
        }
        
        // Wait for response
        let waitResult = semaphore.wait(timeout: .now() + .seconds(10))
        
        if waitResult == .timedOut {
            print("BLECustomIO: Read semaphore timeout")
            return (0, 8) // DC_STATUS_TIMEOUT
        }
        
        guard let receivedData = resultData else {
            return (0, errorCode)
        }
        
        // Copy data to output buffer
        let copySize = min(receivedData.count, size)
        receivedData.withUnsafeBytes { bufferPtr in
            if let baseAddress = bufferPtr.baseAddress {
                data.copyMemory(from: baseAddress, byteCount: copySize)
            }
        }
        
        print("BLECustomIO: Read complete - \(copySize) bytes")
        return (copySize, 0) // DC_STATUS_SUCCESS
    }
    
    /// Write data via BLE (blocking call for libdivecomputer)
    func customWrite(data: UnsafeRawPointer, size: Int) -> (Int, Int32) {
        guard isConnected else {
            print("BLECustomIO: Write failed - not connected")
            return (0, 7) // DC_STATUS_IO
        }
        
        print("BLECustomIO: Writing \(size) bytes...")
        
        let semaphore = DispatchSemaphore(value: 0)
        var errorCode: Int32 = 0 // DC_STATUS_SUCCESS
        
        // Convert data to array
        let dataArray = Array(UnsafeBufferPointer(
            start: data.assumingMemoryBound(to: UInt8.self),
            count: size
        ))
        
        // Define the work to do
        let performWrite = { [weak self] in
            guard let self = self else {
                semaphore.signal()
                return
            }
            
            self.channel.invokeMethod("ble_write", arguments: [
                "data": dataArray
            ]) { response in
                if let result = response as? [String: Any] {
                    if let success = result["success"] as? Bool, !success {
                        errorCode = 7 // DC_STATUS_IO
                        let error = result["error"] as? String ?? "UNKNOWN"
                        print("BLECustomIO: Write error: \(error)")
                    } else {
                        print("BLECustomIO: Write acknowledged by Dart")
                    }
                } else {
                    errorCode = 7 // DC_STATUS_IO
                    print("BLECustomIO: Invalid response from Dart")
                }
                semaphore.signal()
            }
        }
        
        // Call on main thread (sync if not already on it, direct if already on it)
        if Thread.isMainThread {
            performWrite()
        } else {
            DispatchQueue.main.sync(execute: performWrite)
        }
        
        // Wait for response
        let waitResult = semaphore.wait(timeout: .now() + .seconds(10))
        
        if waitResult == .timedOut {
            print("BLECustomIO: Write semaphore timeout")
            return (0, 8) // DC_STATUS_TIMEOUT
        }
        
        if errorCode != 0 {
            return (0, errorCode)
        }
        
        print("BLECustomIO: Write complete - \(size) bytes")
        return (size, 0) // DC_STATUS_SUCCESS
    }
    
    /// Close BLE connection
    func customClose() -> Int32 {
        print("BLECustomIO: Close callback called (ignoring - BLE stays active)")
        
        // Do nothing!
        // libdivecomputer calls this to clean up the iostream structure,
        // but the BLE connection should stay active for communication.
        // isConnected stays true so read/write continue to work.
        
        return 0 // DC_STATUS_SUCCESS
    }
}

// MARK: - C Function Callbacks for libdivecomputer

/// Custom I/O read callback
/// libdivecomputer calls this when it needs to read data
func custom_io_read(
    io: UnsafeMutableRawPointer?,
    data: UnsafeMutableRawPointer?,
    size: Int,
    actual: UnsafeMutablePointer<Int>?
) -> Int32 {
    guard let io = io, let data = data, let actual = actual else {
        print("custom_io_read: Invalid parameters")
        return 3 // DC_STATUS_INVALIDARGS
    }
    
    let customIO = Unmanaged<BLECustomIO>.fromOpaque(io).takeUnretainedValue()
    let (bytesRead, status) = customIO.customRead(data: data, size: size)
    actual.pointee = bytesRead
    
    return status
}

/// Custom I/O write callback
/// libdivecomputer calls this when it needs to write data
func custom_io_write(
    io: UnsafeMutableRawPointer?,
    data: UnsafeRawPointer?,
    size: Int,
    actual: UnsafeMutablePointer<Int>?
) -> Int32 {
    guard let io = io, let data = data, let actual = actual else {
        print("custom_io_write: Invalid parameters")
        return 3 // DC_STATUS_INVALIDARGS
    }
    
    let customIO = Unmanaged<BLECustomIO>.fromOpaque(io).takeUnretainedValue()
    let (bytesWritten, status) = customIO.customWrite(data: data, size: size)
    actual.pointee = bytesWritten
    
    return status
}

/// Custom I/O close callback
func custom_io_close(io: UnsafeMutableRawPointer?) -> Int32 {
    guard let io = io else {
        print("custom_io_close: Invalid parameters")
        return 3 // DC_STATUS_INVALIDARGS
    }
    
    let customIO = Unmanaged<BLECustomIO>.fromOpaque(io).takeUnretainedValue()
    let status = customIO.customClose()
    
    // Release the retained reference
    Unmanaged<BLECustomIO>.fromOpaque(io).release()
    
    return status
}

/// Custom I/O set timeout callback
func custom_io_set_timeout(io: UnsafeMutableRawPointer?, timeout: UInt32) -> Int32 {
    guard let io = io else {
        return 3 // DC_STATUS_INVALIDARGS
    }
    
    let customIO = Unmanaged<BLECustomIO>.fromOpaque(io).takeUnretainedValue()
    customIO.setTimeout(timeout)
    
    return 0 // DC_STATUS_SUCCESS
}

// Stubs for other callbacks (not needed for BLE, but required by dc_custom_cbs_t)
func custom_io_stub(_: UnsafeMutableRawPointer?, _: UInt32) -> Int32 { return 0 }
func custom_io_stub_get(_: UnsafeMutableRawPointer?, _: UnsafeMutablePointer<Int>?) -> Int32 { return 0 }
func custom_io_stub_get_lines(_: UnsafeMutableRawPointer?, _: UnsafeMutablePointer<UInt32>?) -> Int32 { return 0 }
func custom_io_stub_configure(_: UnsafeMutableRawPointer?, _: UInt32, _: UInt32, _: UInt32, _: Int32, _: Int32, _: Int32) -> Int32 { return 0 }
func custom_io_stub_flush(_: UnsafeMutableRawPointer?, _: Int32) -> Int32 { return 0 }
func custom_io_stub_purge(_: UnsafeMutableRawPointer?, _: Int32) -> Int32 { return 0 }
func custom_io_stub_sleep(_: UnsafeMutableRawPointer?, _: UInt32) -> Int32 { return 0 }
