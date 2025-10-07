#if os(iOS)
import Flutter
import UIKit
#elseif os(macOS)
import FlutterMacOS
import Cocoa
#endif

public class LibdivecomputerPlugin: NSObject, FlutterPlugin {
    private var bridge: DiveComputerBridge?
    private var channel: FlutterMethodChannel?
    
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
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            if self.bridge == nil {
                self.bridge = DiveComputerBridge(channel: self.channel)
            }
            
            let status = self.bridge?.setupBLEDevice(deviceId: deviceId) ?? -1
            
            DispatchQueue.main.async {
                result(status)
            }
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
