import Foundation
import FlutterMacOS

/// Bridge between Flutter/BLE and libdivecomputer C library
/// Implements custom I/O callbacks based on Subsurface methodology
class DiveComputerBridge {
    private var context: OpaquePointer?
    private var device: OpaquePointer?
    private var descriptor: OpaquePointer?
    internal var bleManager: BLEManager?  // Internal so LibdivecomputerPlugin can access it
    private weak var channel: FlutterMethodChannel?
    
    init(channel: FlutterMethodChannel?) {
        self.channel = channel
        initializeContext()
    }
    
    deinit {
        closeDevice()
        if let ctx = context {
            dc_context_free(ctx)
        }
    }
    
    // MARK: - Initialization
    
    private func initializeContext() {
        var ctx: OpaquePointer?
        let status = dc_context_new(&ctx)
        
        if status == DC_STATUS_SUCCESS {
            context = ctx
            debugPrint("DiveComputerBridge: Context initialized")
        } else {
            debugPrint("DiveComputerBridge: Failed to initialize context: \(status)")
        }
    }
    
    // MARK: - Descriptors
    
    func getDescriptors() -> [[String: Any]] {
        var descriptors: [[String: Any]] = []
        var iterator: OpaquePointer?
        
        guard dc_descriptor_iterator_new(&iterator, context) == DC_STATUS_SUCCESS else {
            debugPrint("DiveComputerBridge: Failed to create descriptor iterator")
            return []
        }
        
        defer {
            dc_iterator_free(iterator)
        }
        
        while true {
            var desc: OpaquePointer?
            let status = dc_iterator_next(iterator, &desc)
            
            if status != DC_STATUS_SUCCESS || desc == nil {
                break
            }
            
            let vendor = String(cString: dc_descriptor_get_vendor(desc))
            let product = String(cString: dc_descriptor_get_product(desc))
            let model = dc_descriptor_get_model(desc)
            let transports = dc_descriptor_get_transports(desc)
            
            var transportList: [Int] = []
            if transports & DC_TRANSPORT_SERIAL.rawValue != 0 {
                transportList.append(1)
            }
            if transports & DC_TRANSPORT_USBHID.rawValue != 0 {
                transportList.append(2)
            }
            if transports & DC_TRANSPORT_BLUETOOTH.rawValue != 0 {
                transportList.append(5)
            }
            if transports & DC_TRANSPORT_BLE.rawValue != 0 {
                transportList.append(6)
            }
            
            descriptors.append([
                "vendor": vendor,
                "product": product,
                "model": Int(model),
                "transports": transportList
            ])
            
            dc_descriptor_free(desc)
        }
        
        debugPrint("DiveComputerBridge: Found \(descriptors.count) descriptors")
        return descriptors
    }
    
    // MARK: - Device Operations
    
    func setupBLEDevice(deviceId: String) -> Int {
        if bleManager == nil {
            bleManager = BLEManager()
            debugPrint("DiveComputerBridge: Created BLEManager")
        }
        // Actual setup happens in LibdivecomputerPlugin
        return 0  // DC_STATUS_SUCCESS
    }
    
    func openDevice(vendor: String, product: String, deviceId: String) -> Int {
        debugPrint("DiveComputerBridge: openDevice called - vendor: \(vendor), product: \(product)")
        
        guard let ctx = context else {
            debugPrint("DiveComputerBridge: No context")
            return -1
        }
        
        // Find matching descriptor
        var iterator: OpaquePointer?
        guard dc_descriptor_iterator_new(&iterator, ctx) == DC_STATUS_SUCCESS else {
            debugPrint("DiveComputerBridge: Failed to create iterator")
            return -1
        }
        
        defer {
            dc_iterator_free(iterator)
        }
        
        var foundDescriptor: OpaquePointer?
        
        while true {
            var desc: OpaquePointer?
            let status = dc_iterator_next(iterator, &desc)
            
            if status != DC_STATUS_SUCCESS || desc == nil {
                break
            }
            
            let descVendor = String(cString: dc_descriptor_get_vendor(desc))
            let descProduct = String(cString: dc_descriptor_get_product(desc))
            
            if descVendor == vendor && descProduct == product {
                foundDescriptor = desc
                debugPrint("DiveComputerBridge: Found matching descriptor: \(descVendor) \(descProduct)")
                break
            }
            
            dc_descriptor_free(desc)
        }
        
        guard let desc = foundDescriptor else {
            debugPrint("DiveComputerBridge: Descriptor not found for \(vendor) \(product)")
            return -1
        }
        
        self.descriptor = desc
        
        debugPrint("DiveComputerBridge: Creating custom I/O callbacks")
        
        // Create custom I/O callbacks for BLE
        let userdata = Unmanaged.passUnretained(self).toOpaque()
        var customCallbacks = dc_custom_cbs_t(
            set_timeout: customSetTimeout,
            set_break: nil,
            set_dtr: nil,
            set_rts: nil,
            get_lines: nil,
            get_available: customGetAvailable,
            configure: nil,
            poll: nil,
            read: customRead,
            write: customWrite,
            ioctl: nil,
            flush: nil,
            purge: nil,
            sleep: nil,
            close: customClose
        )
        
        // Open device with custom I/O
        var iostream: OpaquePointer?
        debugPrint("DiveComputerBridge: Opening custom iostream")
        let status = dc_custom_open(
            &iostream,
            ctx,
            DC_TRANSPORT_BLE,
            &customCallbacks,
            userdata
        )
        
        if status != DC_STATUS_SUCCESS {
            debugPrint("DiveComputerBridge: Failed to open custom iostream: \(status)")
            return Int(status.rawValue)
        }
        
        debugPrint("DiveComputerBridge: Custom iostream opened, now opening device")
        
        // Open device
        var dev: OpaquePointer?
        let devStatus = dc_device_open(&dev, ctx, desc, iostream)
        
        if devStatus != DC_STATUS_SUCCESS {
            debugPrint("DiveComputerBridge: Failed to open device: \(devStatus)")
            dc_iostream_close(iostream)
            return Int(devStatus.rawValue)
        }
        
        device = dev
        debugPrint("DiveComputerBridge: Device opened successfully!")
        
        return 0  // DC_STATUS_SUCCESS
    }
    
    func closeDevice() {
        if let dev = device {
            dc_device_close(dev)
            device = nil
        }
        
        if let desc = descriptor {
            dc_descriptor_free(desc)
            descriptor = nil
        }
        
        bleManager = nil
    }
    
    func downloadDives() -> Int {
        guard let dev = device else {
            debugPrint("DiveComputerBridge: No device open")
            return -1
        }
        
        let userdata = Unmanaged.passUnretained(self).toOpaque()
        
        let status = dc_device_foreach(dev, diveCallback, userdata)
        
        debugPrint("DiveComputerBridge: Download completed with status: \(status)")
        
        return Int(status.rawValue)
    }
    
    // MARK: - Version
    
    static func getLibraryVersion() -> String {
        return String(cString: dc_version(nil))
    }
    
    // MARK: - Callbacks
    
    private func sendProgress(current: Int, total: Int) {
        DispatchQueue.main.async { [weak self] in
            self?.channel?.invokeMethod("onProgress", arguments: [
                "current": current,
                "total": total
            ])
        }
    }
    
    fileprivate func sendDive(_ diveData: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.channel?.invokeMethod("onDive", arguments: diveData)
        }
    }
    
    private func sendLog(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.channel?.invokeMethod("onLog", arguments: message)
        }
    }
}

// MARK: - Custom I/O Callbacks

/// Set timeout for I/O operations
private func customSetTimeout(
    userdata: UnsafeMutableRawPointer?,
    timeout: Int32
) -> dc_status_t {
    debugPrint("CustomIO: Set timeout to \(timeout)ms")
    return DC_STATUS_SUCCESS
}

/// Read data from BLE device
private func customRead(
    userdata: UnsafeMutableRawPointer?,
    data: UnsafeMutableRawPointer?,
    size: Int,
    actual: UnsafeMutablePointer<Int>?
) -> dc_status_t {
    guard let userdata = userdata,
          let data = data,
          let actual = actual else {
        return DC_STATUS_INVALIDARGS
    }
    
    let bridge = Unmanaged<DiveComputerBridge>.fromOpaque(userdata).takeUnretainedValue()
    
    guard let bleManager = bridge.bleManager else {
        return DC_STATUS_IO
    }
    
    // CRITICAL: Wait for data with timeout and polling
    // BLE is asynchronous - response may take up to several seconds
    let timeoutMs: Int32 = 5000  // 5 second total timeout
    let pollIntervalMs: Int32 = 50  // Check every 50ms
    let maxPolls = timeoutMs / pollIntervalMs
    
    for poll in 0..<maxPolls {
        let semaphore = DispatchSemaphore(value: 0)
        var readData: Data?
        
        DispatchQueue.main.async {
            readData = bleManager.read(maxLength: size)
            semaphore.signal()
        }
        
        // Wait for this poll
        let timeout = DispatchTime.now() + .milliseconds(Int(pollIntervalMs))
        _ = semaphore.wait(timeout: timeout)
        
        // Check if we got data
        if let readData = readData, !readData.isEmpty {
            readData.copyBytes(to: data.assumingMemoryBound(to: UInt8.self), count: readData.count)
            actual.pointee = readData.count
            let elapsedMs = poll * pollIntervalMs
            debugPrint("CustomIO: Read \(readData.count) bytes after \(elapsedMs)ms")
            return DC_STATUS_SUCCESS
        }
    }
    
    // Timeout - no data received after polling
    debugPrint("CustomIO: Read timeout after \(timeoutMs)ms")
    actual.pointee = 0
    return DC_STATUS_TIMEOUT
}

/// Write data to BLE device
private func customWrite(
    userdata: UnsafeMutableRawPointer?,
    data: UnsafeRawPointer?,
    size: Int,
    actual: UnsafeMutablePointer<Int>?
) -> dc_status_t {
    guard let userdata = userdata,
          let data = data,
          let actual = actual else {
        debugPrint("CustomIO: Write - invalid arguments")
        return DC_STATUS_INVALIDARGS
    }
    
    let bridge = Unmanaged<DiveComputerBridge>.fromOpaque(userdata).takeUnretainedValue()
    
    guard let bleManager = bridge.bleManager else {
        debugPrint("CustomIO: Write - no BLE manager")
        return DC_STATUS_IO
    }
    
    let writeData = Data(bytes: data, count: size)
    
    // CRITICAL: Wait for write completion with proper callback
    // CoreBluetooth operations MUST happen on main thread
    let semaphore = DispatchSemaphore(value: 0)
    var writeSuccess = false
    
    DispatchQueue.main.async {
        debugPrint("CustomIO: Writing \(writeData.count) bytes on main thread")
        bleManager.write(writeData) { success in
            writeSuccess = success
            semaphore.signal()
        }
    }
    
    // Wait for write to complete (with timeout)
    let timeout = DispatchTime.now() + .seconds(5)
    if semaphore.wait(timeout: timeout) == .timedOut {
        debugPrint("CustomIO: Write timeout")
        return DC_STATUS_TIMEOUT
    }
    
    if writeSuccess {
        actual.pointee = size
        debugPrint("CustomIO: Wrote \(size) bytes successfully")
        return DC_STATUS_SUCCESS
    } else {
        debugPrint("CustomIO: Write failed")
        return DC_STATUS_IO
    }
}

/// Close I/O stream
private func customClose(
    userdata: UnsafeMutableRawPointer?
) -> dc_status_t {
    debugPrint("CustomIO: Close")
    return DC_STATUS_SUCCESS
}

/// Get available bytes in receive buffer
private func customGetAvailable(
    userdata: UnsafeMutableRawPointer?,
    available: UnsafeMutablePointer<Int>?
) -> dc_status_t {
    guard let userdata = userdata,
          let available = available else {
        return DC_STATUS_INVALIDARGS
    }
    
    let bridge = Unmanaged<DiveComputerBridge>.fromOpaque(userdata).takeUnretainedValue()
    
    if let bleManager = bridge.bleManager {
        // CRITICAL: CoreBluetooth operations MUST happen on main thread
        let semaphore = DispatchSemaphore(value: 0)
        var count = 0
        
        DispatchQueue.main.async {
            count = bleManager.available()
            semaphore.signal()
        }
        
        let timeout = DispatchTime.now() + .milliseconds(100)
        _ = semaphore.wait(timeout: timeout)
        
        available.pointee = count
    } else {
        available.pointee = 0
    }
    
    return DC_STATUS_SUCCESS
}

// MARK: - Dive Callback

private func diveCallback(
    data: UnsafePointer<UInt8>?,
    size: UInt32,
    fingerprint: UnsafePointer<UInt8>?,
    fsize: UInt32,
    userdata: UnsafeMutableRawPointer?
) -> Int32 {
    guard let userdata = userdata,
          let _ = data else {
        return 1  // Continue
    }
    
    let bridge = Unmanaged<DiveComputerBridge>.fromOpaque(userdata).takeUnretainedValue()
    
    // Parse dive data (simplified - real implementation would parse all fields)
    let diveData: [String: Any] = [
        "number": 1,  // Would come from parser
        "dateTime": Date().timeIntervalSince1970 * 1000,
        "duration": 1800,  // 30 minutes
        "maxDepth": 18.5,
        "samples": []
    ]
    
    bridge.sendDive(diveData)
    
    return 1  // Continue with next dive
}
