import FlutterMacOS
import Foundation

// Extension to LibdivecomputerPlugin for BLE operations
extension LibdivecomputerPlugin {
    
    private var bleChannel: FlutterMethodChannel {
        return FlutterMethodChannel(
            name: "libdivecomputer_ble",
            binaryMessenger: registrar!.messenger
        )
    }
    
    // Store custom I/O instance and libdivecomputer objects
    private static var customIO: BLECustomIO?
    private static var context: OpaquePointer?
    private static var iostream: OpaquePointer?
    private static var device: OpaquePointer?
    
    /// Setup BLE method channel handlers
    func setupBLEChannel() {
        bleChannel.setMethodCallHandler { [weak self] (call, result) in
            self?.handleBLEMethodCall(call: call, result: result)
        }
    }
    
    /// Handle BLE-specific method calls from Dart
    private func handleBLEMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "ble_ready":
            // Dart side is ready with characteristic
            handleBLEReady(result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func handleBLEReady(result: @escaping FlutterResult) {
        print("BLE: Dart side ready with characteristic")
        result(true)
    }
    
    /// Open device using custom I/O
    func handleOpenDevice(vendor: String, product: String, result: @escaping FlutterResult) {
        print("Opening device with custom I/O: \(vendor) \(product)")
        
        // Create custom I/O instance if needed
        if LibdivecomputerPlugin.customIO == nil {
            LibdivecomputerPlugin.customIO = BLECustomIO(channel: bleChannel)
            LibdivecomputerPlugin.customIO?.setConnected(true)
        }
        
        guard let customIO = LibdivecomputerPlugin.customIO else {
            result(FlutterError(code: "INIT_FAILED", message: "Failed to create custom I/O", details: nil))
            return
        }
        
        // Create libdivecomputer context if needed
        if LibdivecomputerPlugin.context == nil {
            var ctx: OpaquePointer?
            let status = dc_context_new(&ctx)
            
            if status != DC_STATUS_SUCCESS || ctx == nil {
                result(FlutterError(code: "CONTEXT_FAILED", message: "Failed to create context", details: nil))
                return
            }
            
            LibdivecomputerPlugin.context = ctx
        }
        
        guard let context = LibdivecomputerPlugin.context else {
            result(FlutterError(code: "NO_CONTEXT", message: "No context available", details: nil))
            return
        }
        
        // Setup custom I/O callbacks
        var callbacks = dc_custom_cbs_t()
        callbacks.set_timeout = custom_io_set_timeout
        callbacks.set_latency = custom_io_stub
        callbacks.set_break = custom_io_stub
        callbacks.set_dtr = custom_io_stub
        callbacks.set_rts = custom_io_stub
        callbacks.get_available = custom_io_stub_get
        callbacks.get_lines = custom_io_stub_get_lines
        callbacks.configure = custom_io_stub_configure
        callbacks.read = custom_io_read
        callbacks.write = custom_io_write
        callbacks.flush = custom_io_stub_flush
        callbacks.purge = custom_io_stub_flush
        callbacks.sleep = custom_io_stub_sleep
        callbacks.close = custom_io_close
        
        // Retain customIO for callbacks
        let userdata = Unmanaged.passRetained(customIO).toOpaque()
        
        // Create custom iostream
        var iostream: OpaquePointer?
        var status = dc_custom_open(
            &iostream,
            context,
            DC_TRANSPORT_BLE,
            &callbacks,
            userdata
        )
        
        if status != DC_STATUS_SUCCESS || iostream == nil {
            Unmanaged<BLECustomIO>.fromOpaque(userdata).release()
            result(FlutterError(
                code: "IOSTREAM_FAILED",
                message: "Failed to create custom iostream: \(status)",
                details: nil
            ))
            return
        }
        
        LibdivecomputerPlugin.iostream = iostream
        
        // Get descriptor for the device
        var descriptor: OpaquePointer?
        var iterator: OpaquePointer?
        
        status = dc_descriptor_iterator(&iterator)
        if status != DC_STATUS_SUCCESS {
            result(FlutterError(
                code: "DESCRIPTOR_FAILED",
                message: "Failed to create descriptor iterator",
                details: nil
            ))
            return
        }
        
        // Find the descriptor matching vendor/product
        while dc_iterator_next(iterator, &descriptor) == DC_STATUS_SUCCESS {
            if let desc = descriptor {
                let vendorStr = String(cString: dc_descriptor_get_vendor(desc))
                let productStr = String(cString: dc_descriptor_get_product(desc))
                
                if vendorStr == vendor && productStr == product {
                    print("Found matching descriptor: \(vendorStr) \(productStr)")
                    break
                }
            }
            descriptor = nil
        }
        
        _ = dc_iterator_free(iterator)
        
        guard let desc = descriptor else {
            result(FlutterError(
                code: "DEVICE_NOT_FOUND",
                message: "Device not found: \(vendor) \(product)",
                details: nil
            ))
            return
        }
        
        // Safely unwrap iostream before passing to dc_device_open
        guard let unwrappedIOStream = iostream else {
            result(FlutterError(
                code: "NO_IOSTREAM",
                message: "iostream is nil",
                details: nil
            ))
            return
        }
        
        // Open device
        var device: OpaquePointer?
        status = dc_device_open(&device, context, desc, unwrappedIOStream)
        
        if status != DC_STATUS_SUCCESS {
            result(FlutterError(
                code: "DEVICE_OPEN_FAILED",
                message: "Failed to open device: \(status)",
                details: nil
            ))
            return
        }
        
        LibdivecomputerPlugin.device = device
        
        print("Device opened successfully!")
        result(Int(DC_STATUS_SUCCESS))
    }
    
    /// Download dives from the connected device
    func handleDownloadDives(result: @escaping FlutterResult) {
        guard let device = LibdivecomputerPlugin.device else {
            result(FlutterError(code: "NO_DEVICE", message: "No device opened", details: nil))
            return
        }
        
        print("Starting dive download...")
        
        // CRITICAL: Run libdivecomputer on background thread to avoid blocking main thread
        // This prevents deadlock when custom I/O callbacks need to call Flutter on main thread
        DispatchQueue.global(qos: .userInitiated).async {
            var diveCount = 0
            
            // Callback for each dive
            let diveCallback: @convention(c) (UnsafePointer<UInt8>?, UInt32, UnsafePointer<UInt8>?, UInt32, UnsafeMutableRawPointer?) -> Int32 = { (data, size, fingerprint, fsize, userdata) in
                
                guard let countPtr = userdata?.assumingMemoryBound(to: Int.self) else {
                    return 0
                }
                
                countPtr.pointee += 1
                print("Downloaded dive #\(countPtr.pointee) - \(size) bytes")
                
                return 1 // Continue
            }
            
            // Download dives
            let status = dc_device_foreach(device, diveCallback, &diveCount)
            
            // CRITICAL: Return result on MAIN thread (required for Flutter)
            DispatchQueue.main.async {
                if status == DC_STATUS_SUCCESS {
                    result(Int(DC_STATUS_SUCCESS))
                } else {
                    result(FlutterError(
                        code: "DOWNLOAD_FAILED",
                        message: "Failed to download dives: \(status)",
                        details: nil
                    ))
                }
            }
        }
    }
    
    /// Close device and cleanup resources
    func handleCloseDevice(result: @escaping FlutterResult) {
        if let device = LibdivecomputerPlugin.device {
            _ = dc_device_close(device)
            LibdivecomputerPlugin.device = nil
        }
        
        if let iostream = LibdivecomputerPlugin.iostream {
            _ = dc_iostream_close(iostream)
            LibdivecomputerPlugin.iostream = nil
        }
        
        if let context = LibdivecomputerPlugin.context {
            _ = dc_context_free(context)
            LibdivecomputerPlugin.context = nil
        }
        
        LibdivecomputerPlugin.customIO = nil
        
        result(nil)
    }
}

// MARK: - libdivecomputer C function declarations

@_silgen_name("dc_version")
func dc_version(_ output: UnsafePointer<CChar>?) -> UnsafePointer<CChar>

@_silgen_name("dc_context_new")
func dc_context_new(_ context: UnsafeMutablePointer<OpaquePointer?>) -> Int32

@_silgen_name("dc_context_free")
func dc_context_free(_ context: OpaquePointer) -> Int32

@_silgen_name("dc_custom_open")
func dc_custom_open(
    _ iostream: UnsafeMutablePointer<OpaquePointer?>,
    _ context: OpaquePointer,
    _ transport: UInt32,
    _ callbacks: UnsafePointer<dc_custom_cbs_t>,
    _ userdata: UnsafeMutableRawPointer?
) -> Int32

@_silgen_name("dc_iostream_close")
func dc_iostream_close(_ iostream: OpaquePointer) -> Int32

@_silgen_name("dc_descriptor_iterator")
func dc_descriptor_iterator(_ iterator: UnsafeMutablePointer<OpaquePointer?>) -> Int32

@_silgen_name("dc_iterator_next")
func dc_iterator_next(_ iterator: OpaquePointer?, _ item: UnsafeMutablePointer<OpaquePointer?>) -> Int32

@_silgen_name("dc_iterator_free")
func dc_iterator_free(_ iterator: OpaquePointer?) -> Int32

@_silgen_name("dc_descriptor_get_vendor")
func dc_descriptor_get_vendor(_ descriptor: OpaquePointer) -> UnsafePointer<CChar>

@_silgen_name("dc_descriptor_get_product")
func dc_descriptor_get_product(_ descriptor: OpaquePointer) -> UnsafePointer<CChar>

@_silgen_name("dc_descriptor_get_model")
func dc_descriptor_get_model(_ descriptor: OpaquePointer) -> UInt32

@_silgen_name("dc_descriptor_get_transports")
func dc_descriptor_get_transports(_ descriptor: OpaquePointer) -> UInt32

@_silgen_name("dc_descriptor_free")
func dc_descriptor_free(_ descriptor: OpaquePointer?)

@_silgen_name("dc_device_open")
func dc_device_open(
    _ device: UnsafeMutablePointer<OpaquePointer?>,
    _ context: OpaquePointer,
    _ descriptor: OpaquePointer,
    _ iostream: OpaquePointer
) -> Int32

@_silgen_name("dc_device_close")
func dc_device_close(_ device: OpaquePointer) -> Int32

@_silgen_name("dc_device_foreach")
func dc_device_foreach(
    _ device: OpaquePointer,
    _ callback: @convention(c) (UnsafePointer<UInt8>?, UInt32, UnsafePointer<UInt8>?, UInt32, UnsafeMutableRawPointer?) -> Int32,
    _ userdata: UnsafeMutableRawPointer?
) -> Int32

// dc_custom_cbs_t structure
struct dc_custom_cbs_t {
    var set_timeout: (@convention(c) (UnsafeMutableRawPointer?, UInt32) -> Int32)?
    var set_latency: (@convention(c) (UnsafeMutableRawPointer?, UInt32) -> Int32)?
    var set_break: (@convention(c) (UnsafeMutableRawPointer?, UInt32) -> Int32)?
    var set_dtr: (@convention(c) (UnsafeMutableRawPointer?, UInt32) -> Int32)?
    var set_rts: (@convention(c) (UnsafeMutableRawPointer?, UInt32) -> Int32)?
    var get_available: (@convention(c) (UnsafeMutableRawPointer?, UnsafeMutablePointer<Int>?) -> Int32)?
    var get_lines: (@convention(c) (UnsafeMutableRawPointer?, UnsafeMutablePointer<UInt32>?) -> Int32)?
    var configure: (@convention(c) (UnsafeMutableRawPointer?, UInt32, UInt32, UInt32, Int32, Int32, Int32) -> Int32)?
    var read: (@convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, Int, UnsafeMutablePointer<Int>?) -> Int32)?
    var write: (@convention(c) (UnsafeMutableRawPointer?, UnsafeRawPointer?, Int, UnsafeMutablePointer<Int>?) -> Int32)?
    var flush: (@convention(c) (UnsafeMutableRawPointer?, Int32) -> Int32)?
    var purge: (@convention(c) (UnsafeMutableRawPointer?, Int32) -> Int32)?
    var sleep: (@convention(c) (UnsafeMutableRawPointer?, UInt32) -> Int32)?
    var close: (@convention(c) (UnsafeMutableRawPointer?) -> Int32)?
}

// Transport types
let DC_TRANSPORT_SERIAL: UInt32 = (1 << 0)
let DC_TRANSPORT_USB: UInt32 = (1 << 1)
let DC_TRANSPORT_USBHID: UInt32 = (1 << 2)
let DC_TRANSPORT_IRDA: UInt32 = (1 << 3)
let DC_TRANSPORT_BLUETOOTH: UInt32 = (1 << 4)
let DC_TRANSPORT_BLE: UInt32 = (1 << 5)
let DC_TRANSPORT_USBSTORAGE: UInt32 = (1 << 6)

// Status codes
let DC_STATUS_SUCCESS: Int32 = 0
let DC_STATUS_UNSUPPORTED: Int32 = 1
let DC_STATUS_INVALIDARGS: Int32 = 3
let DC_STATUS_NOMEMORY: Int32 = 4
let DC_STATUS_NODEVICE: Int32 = 5
let DC_STATUS_NOACCESS: Int32 = 6
let DC_STATUS_IO: Int32 = 7
let DC_STATUS_TIMEOUT: Int32 = 8
let DC_STATUS_PROTOCOL: Int32 = 9
