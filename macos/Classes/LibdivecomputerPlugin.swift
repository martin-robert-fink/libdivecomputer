#if os(iOS)
import Flutter
import UIKit
#elseif os(macOS)
import FlutterMacOS
import Cocoa
#endif
import CoreBluetooth

public class LibdivecomputerPlugin: NSObject, FlutterPlugin {
    private var bridge: DiveComputerBridge?
    private var channel: FlutterMethodChannel?
    private var centralManager: CBCentralManager?
    private var discoveredPeripherals: [String: CBPeripheral] = [:]
    
    public override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        #if os(iOS)
        let messenger = registrar.messenger()
        #elseif os(macOS)
        let messenger = registrar.messenger
        #endif
        
        let channel = FlutterMethodChannel(
            name: "libdivecomputer",
            binaryMessenger: messenger
        )
        
        let instance = LibdivecomputerPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getDescriptors":
            handleGetDescriptors(result: result)
            
        case "openDevice":
            guard let args = call.arguments as? [String: Any],
                  let vendor = args["vendor"] as? String,
                  let product = args["product"] as? String,
                  let deviceId = args["deviceId"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                return
            }
            handleOpenDevice(vendor: vendor, product: product, deviceId: deviceId, result: result)
            
        case "closeDevice":
            handleCloseDevice(result: result)
            
        case "downloadDives":
            handleDownloadDives(result: result)
            
        case "setupBLEDevice":
            guard let args = call.arguments as? [String: Any],
                  let deviceId = args["deviceId"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                return
            }
            handleSetupBLEDevice(deviceId: deviceId, result: result)
            
        case "getVersion":
            handleGetVersion(result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func handleGetDescriptors(result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            if self.bridge == nil {
                self.bridge = DiveComputerBridge(channel: self.channel)
            }
            
            let descriptors = self.bridge?.getDescriptors() ?? []
            
            DispatchQueue.main.async {
                result(descriptors)
            }
        }
    }
    
    private func handleOpenDevice(vendor: String, product: String, deviceId: String, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            if self.bridge == nil {
                self.bridge = DiveComputerBridge(channel: self.channel)
            }
            
            let status = self.bridge?.openDevice(
                vendor: vendor,
                product: product,
                deviceId: deviceId
            ) ?? -1
            
            DispatchQueue.main.async {
                result(status)
            }
        }
    }
    
    private func handleCloseDevice(result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            self.bridge?.closeDevice()
            
            DispatchQueue.main.async {
                result(nil)
            }
        }
    }
    
    private func handleDownloadDives(result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let status = self.bridge?.downloadDives() ?? -1
            
            DispatchQueue.main.async {
                result(status)
            }
        }
    }
    
    private func handleSetupBLEDevice(deviceId: String, result: @escaping FlutterResult) {
        debugPrint("LibDC: Setup BLE device: \(deviceId)")
        
        guard let uuid = UUID(uuidString: deviceId) else {
            debugPrint("LibDC: Invalid UUID: \(deviceId)")
            result(-1)
            return
        }
        
        if bridge == nil {
            bridge = DiveComputerBridge(channel: channel)
        }
        
        // Check if we've already discovered this peripheral
        if let peripheral = discoveredPeripherals[deviceId] {
            debugPrint("LibDC: Using cached peripheral")
            setupPeripheralForBridge(peripheral: peripheral, result: result)
            return
        }
        
        // Try to retrieve already-connected peripherals (from flutter_blue_plus)
        // First, we need to know which services to look for
        // For dive computers, we'll scan all connected peripherals
        let connectedPeripherals = centralManager?.retrieveConnectedPeripherals(withServices: [])
        debugPrint("LibDC: Found \(connectedPeripherals?.count ?? 0) connected peripherals")
        
        // Find the one matching our UUID
        if let peripheral = connectedPeripherals?.first(where: { $0.identifier == uuid }) {
            debugPrint("LibDC: Found connected peripheral: \(peripheral.name ?? "unknown")")
            discoveredPeripherals[deviceId] = peripheral
            setupPeripheralForBridge(peripheral: peripheral, result: result)
            return
        }
        
        // If not connected, try to retrieve known peripherals
        let peripherals = centralManager?.retrievePeripherals(withIdentifiers: [uuid])
        if let peripheral = peripherals?.first {
            debugPrint("LibDC: Retrieved known peripheral, connecting...")
            discoveredPeripherals[deviceId] = peripheral
            
            // Connect if not already connected
            if peripheral.state != .connected {
                centralManager?.connect(peripheral, options: nil)
                // Wait for connection
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    if peripheral.state == .connected {
                        self.setupPeripheralForBridge(peripheral: peripheral, result: result)
                    } else {
                        debugPrint("LibDC: Connection timeout")
                        result(-1)
                    }
                }
            } else {
                setupPeripheralForBridge(peripheral: peripheral, result: result)
            }
            return
        }
        
        // Not found
        debugPrint("LibDC: Peripheral not found. Ensure device is connected via flutter_blue_plus first.")
        result(-1)
    }
    
    private func setupPeripheralForBridge(peripheral: CBPeripheral, result: @escaping FlutterResult) {
        debugPrint("LibDC: Setting up peripheral for bridge")
        
        // Ensure bridge and bleManager exist
        if bridge == nil {
            bridge = DiveComputerBridge(channel: channel)
        }
        
        _ = bridge?.setupBLEDevice(deviceId: peripheral.identifier.uuidString)
        
        guard let bleManager = bridge?.bleManager else {
            debugPrint("LibDC: Failed to create BLE manager")
            result(-1)
            return
        }
        
        bleManager.setup(peripheral: peripheral)
        
        // Discover services and characteristics
        bleManager.discoverServices()
        
        // Give it time to discover and enable notifications
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            debugPrint("LibDC: BLE setup complete")
            result(0)
        }
    }
    
    private func handleGetVersion(result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            let version = DiveComputerBridge.getLibraryVersion()
            
            DispatchQueue.main.async {
                result(version)
            }
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension LibdivecomputerPlugin: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        debugPrint("LibDC: Central manager state: \(central.state.rawValue)")
    }
    
    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String : Any],
        rssi RSSI: NSNumber
    ) {
        // Store discovered peripherals
        let deviceId = peripheral.identifier.uuidString
        discoveredPeripherals[deviceId] = peripheral
        debugPrint("LibDC: Discovered peripheral: \(deviceId)")
    }
    
    public func centralManager(
        _ central: CBCentralManager,
        didConnect peripheral: CBPeripheral
    ) {
        debugPrint("LibDC: Connected to peripheral: \(peripheral.identifier.uuidString)")
    }
    
    public func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        debugPrint("LibDC: Failed to connect: \(error?.localizedDescription ?? "unknown")")
    }
    
    public func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        debugPrint("LibDC: Disconnected: \(peripheral.identifier.uuidString)")
    }
}
