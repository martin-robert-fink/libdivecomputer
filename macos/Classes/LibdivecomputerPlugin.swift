import FlutterMacOS
import Foundation
import CoreBluetooth

public class LibdivecomputerPlugin: NSObject, FlutterPlugin {
    fileprivate var registrar: FlutterPluginRegistrar?
    private var channel: FlutterMethodChannel?
    
    // BLE-related state (accessed by extension)
    fileprivate var currentDevice: BluetoothDevice?
    fileprivate var currentCharacteristic: CBCharacteristic?
    fileprivate var currentPeripheral: CBPeripheral?
    
    public override init() {
        super.init()
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let messenger = registrar.messenger
        
        let channel = FlutterMethodChannel(
            name: "libdivecomputer",
            binaryMessenger: messenger
        )
        
        let instance = LibdivecomputerPlugin()
        instance.channel = channel
        instance.registrar = registrar
        instance.setupBLEChannel()
        
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getDescriptors":
            handleGetDescriptors(result: result)
            
        case "getVersion":
            handleGetVersion(result: result)
            
        case "setupBLEDevice":
            guard let args = call.arguments as? [String: Any],
                  let deviceId = args["deviceId"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                return
            }
            handleSetupBLEDevice(deviceId: deviceId, result: result)
            
        case "openDevice":
            guard let args = call.arguments as? [String: Any],
                  let vendor = args["vendor"] as? String,
                  let product = args["product"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                return
            }
            handleOpenDevice(vendor: vendor, product: product, result: result)
            
        case "closeDevice":
            handleCloseDevice(result: result)
            
        case "downloadDives":
            handleDownloadDives(result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func handleGetDescriptors(result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            var descriptors: [[String: Any]] = []
            var iterator: OpaquePointer?
            
            // Create temporary context for getting descriptors
            var ctx: OpaquePointer?
            guard dc_context_new(&ctx) == DC_STATUS_SUCCESS, let context = ctx else {
                DispatchQueue.main.async {
                    result([])
                }
                return
            }
            
            defer {
                dc_context_free(context)
            }
            
            guard dc_descriptor_iterator(&iterator) == DC_STATUS_SUCCESS else {
                DispatchQueue.main.async {
                    result([])
                }
                return
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
                
                if let descriptor = desc {
                    let vendor = String(cString: dc_descriptor_get_vendor(descriptor))
                    let product = String(cString: dc_descriptor_get_product(descriptor))
                    let model = dc_descriptor_get_model(descriptor)
                    let transports = dc_descriptor_get_transports(descriptor)
                    
                    var transportList: [Int] = []
                    if transports & DC_TRANSPORT_SERIAL != 0 {
                        transportList.append(1)
                    }
                    if transports & DC_TRANSPORT_USBHID != 0 {
                        transportList.append(2)
                    }
                    if transports & DC_TRANSPORT_BLUETOOTH != 0 {
                        transportList.append(5)
                    }
                    if transports & DC_TRANSPORT_BLE != 0 {
                        transportList.append(6)
                    }
                    
                    descriptors.append([
                        "vendor": vendor,
                        "product": product,
                        "model": Int(model),
                        "transports": transportList
                    ])
                    
                    dc_descriptor_free(descriptor)
                }
            }
            
            DispatchQueue.main.async {
                result(descriptors)
            }
        }
    }
    
    private func handleSetupBLEDevice(deviceId: String, result: @escaping FlutterResult) {
        print("LibDC: Setup BLE device: \(deviceId)")
        
        // Just mark as connected - the actual BLE device is managed by flutter_blue_plus
        // We'll get the characteristic reference when openDevice is called
        result(0) // DC_STATUS_SUCCESS
    }
    
    private func handleGetVersion(result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            let version = String(cString: dc_version(nil))
            
            DispatchQueue.main.async {
                result(version)
            }
        }
    }
}

// Simple struct to hold device info
struct BluetoothDevice {
    let deviceId: String
    let name: String
}
