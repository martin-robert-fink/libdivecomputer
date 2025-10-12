import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'models/descriptor_info.dart';
import 'models/device_info.dart';
import 'models/dive_data.dart';
import 'enums/status_code.dart';

/// Main interface to libdivecomputer functionality
class Libdivecomputer {
  static const MethodChannel _channel = MethodChannel('libdivecomputer');
  static const MethodChannel _bleChannel = MethodChannel('libdivecomputer_ble');

  /// Singleton instance
  static final Libdivecomputer instance = Libdivecomputer._();

  // Store current BLE characteristic for read/write operations
  BluetoothCharacteristic? _currentCharacteristic;

  Libdivecomputer._() {
    _channel.setMethodCallHandler(_handleMethodCall);
    _bleChannel.setMethodCallHandler(_handleBLEMethodCall);
  }

  // Callbacks
  void Function(int current, int total)? _onProgress;
  void Function(DiveData dive)? _onDive;
  void Function(String message)? _onLog;
  void Function(DeviceInfo info)? _onDeviceInfo;

  /// Handle method calls from native platform
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    try {
      switch (call.method) {
        case 'onProgress':
          final args = call.arguments as Map<Object?, Object?>;
          final current = args['current'] as int;
          final total = args['total'] as int;
          _onProgress?.call(current, total);
          break;

        case 'onDive':
          final args = Map<String, dynamic>.from(call.arguments as Map);
          final dive = DiveData.fromMap(args);
          _onDive?.call(dive);
          break;

        case 'onLog':
          final message = call.arguments as String;
          debugPrint('LibDC: $message');
          _onLog?.call(message);
          break;

        case 'onDeviceInfo':
          final args = Map<String, dynamic>.from(call.arguments as Map);
          final info = DeviceInfo.fromMap(args);
          _onDeviceInfo?.call(info);
          break;

        default:
          debugPrint('Unknown method: ${call.method}');
      }
    } catch (e) {
      debugPrint('Error handling method call: $e');
    }
  }

  /// Handle BLE method calls from native platform
  Future<dynamic> _handleBLEMethodCall(MethodCall call) async {
    try {
      switch (call.method) {
        case 'ble_read':
          return await _handleBLERead(call.arguments as Map);

        case 'ble_write':
          return await _handleBLEWrite(call.arguments as Map);

        default:
          debugPrint('Unknown BLE method: ${call.method}');
          return {'success': false, 'error': 'UNKNOWN_METHOD'};
      }
    } catch (e) {
      debugPrint('Error handling BLE method call: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Handle BLE read request from native code
  Future<Map<String, dynamic>> _handleBLERead(Map args) async {
    final timeoutMs = args['timeoutMs'] as int? ?? 5000;

    try {
      if (_currentCharacteristic == null) {
        debugPrint('BLE: No characteristic available for read');
        return {'success': false, 'error': 'NO_CHARACTERISTIC'};
      }

      // Read with timeout
      final data = await _currentCharacteristic!
          .read()
          .timeout(Duration(milliseconds: timeoutMs));

      debugPrint('BLE: Read ${data.length} bytes from Dart');
      
      return {
        'success': true,
        'data': data,
      };
    } on TimeoutException {
      debugPrint('BLE: Read timeout');
      return {'success': false, 'error': 'TIMEOUT'};
    } catch (e) {
      debugPrint('BLE: Read error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Handle BLE write request from native code
  Future<Map<String, dynamic>> _handleBLEWrite(Map args) async {
    final data = (args['data'] as List).cast<int>();

    try {
      if (_currentCharacteristic == null) {
        debugPrint('BLE: No characteristic available for write');
        return {'success': false, 'error': 'NO_CHARACTERISTIC'};
      }

      debugPrint('BLE: Writing ${data.length} bytes from Dart');

      // Write with response
      await _currentCharacteristic!.write(
        data,
        withoutResponse: false,
      );

      debugPrint('BLE: Write complete from Dart');

      return {'success': true};
    } catch (e) {
      debugPrint('BLE: Write error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get all dive computer descriptors
  Future<List<DescriptorInfo>> getDescriptors() async {
    try {
      final result =
          await _channel.invokeMethod<List<Object?>>('getDescriptors');
      if (result == null) return [];

      return result
          .map(
            (item) => DescriptorInfo.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('Error getting descriptors: $e');
      return [];
    }
  }

  /// Get descriptors for a specific vendor
  Future<List<DescriptorInfo>> getDescriptorsByVendor(String vendor) async {
    final all = await getDescriptors();
    return all.where((d) => d.vendor == vendor).toList();
  }

  /// Get list of all vendors
  Future<List<String>> getVendors() async {
    final descriptors = await getDescriptors();
    final vendors = descriptors.map((d) => d.vendor).toSet().toList();
    vendors.sort();
    return vendors;
  }

  /// Open connection to a dive computer
  Future<StatusCode> openDevice({
    required String vendor,
    required String product,
    required String deviceId,
  }) async {
    try {
      final result = await _channel.invokeMethod<int>('openDevice', {
        'vendor': vendor,
        'product': product,
        'deviceId': deviceId,
      });

      return StatusCode.fromInt(result ?? -1);
    } catch (e) {
      debugPrint('Error opening device: $e');
      return StatusCode.unknown;
    }
  }

  /// Close connection to dive computer
  Future<void> closeDevice() async {
    try {
      await _channel.invokeMethod<void>('closeDevice');
    } catch (e) {
      debugPrint('Error closing device: $e');
    }
  }

  /// Download dives from connected device
  Future<StatusCode> downloadDives({
    void Function(int current, int total)? onProgress,
    void Function(DiveData dive)? onDive,
    void Function(DeviceInfo info)? onDeviceInfo,
    void Function(String message)? onLog,
  }) async {
    _onProgress = onProgress;
    _onDive = onDive;
    _onDeviceInfo = onDeviceInfo;
    _onLog = onLog;

    try {
      final result = await _channel.invokeMethod<int>('downloadDives');
      return StatusCode.fromInt(result ?? -1);
    } catch (e) {
      debugPrint('Error downloading dives: $e');
      return StatusCode.unknown;
    } finally {
      _onProgress = null;
      _onDive = null;
      _onDeviceInfo = null;
      _onLog = null;
    }
  }

  /// Scan for BLE dive computers
  ///
  /// Returns a stream of scan results. Remember to use
  /// `license: License.free` when calling flutter_blue_plus methods.
  Stream<ScanResult> scanForDevices({
    Duration timeout = const Duration(seconds: 10),
  }) {
    return FlutterBluePlus.onScanResults
        .asyncMap((results) {
          return results.lastOrNull;
        })
        .where((result) => result != null)
        .cast<ScanResult>();
  }

  /// Start BLE scan
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidUsesFineLocation: true,
      );
    } catch (e) {
      debugPrint('Error starting scan: $e');
    }
  }

  /// Stop BLE scan
  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      debugPrint('Error stopping scan: $e');
    }
  }

  /// Check if Bluetooth is available and enabled
  Future<bool> isBluetoothEnabled() async {
    try {
      final adapterState = await FlutterBluePlus.adapterState.first;
      return adapterState == BluetoothAdapterState.on;
    } catch (e) {
      debugPrint('Error checking Bluetooth state: $e');
      return false;
    }
  }

  /// Connect to BLE device
  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect(
        license: License.free,
        timeout: const Duration(seconds: 15),
      );
      debugPrint('Connected to ${device.platformName}');
    } catch (e) {
      debugPrint('Error connecting to device: $e');
      rethrow;
    }
  }

  /// Disconnect from BLE device
  Future<void> disconnectFromDevice(BluetoothDevice device) async {
    try {
      await device.disconnect();
      debugPrint('Disconnected from ${device.platformName}');
    } catch (e) {
      debugPrint('Error disconnecting from device: $e');
    }
  }

  /// Setup BLE device for libdivecomputer communication
  /// 
  /// This method should be called AFTER connecting with flutter_blue_plus
  /// and discovering services/characteristics.
  Future<StatusCode> setupBLEDevice(
    BluetoothDevice device, {
    BluetoothCharacteristic? characteristic,
  }) async {
    try {
      // If no characteristic provided, try to find it
      if (characteristic == null) {
        final services = await device.discoverServices();
        
        // Find a characteristic that supports both write and notify
        for (final service in services) {
          for (final char in service.characteristics) {
            final canWrite = char.properties.write || char.properties.writeWithoutResponse;
            final canNotify = char.properties.notify || char.properties.indicate;
            
            if (canWrite && canNotify) {
              characteristic = char;
              debugPrint('Found suitable characteristic: ${char.uuid}');
              break;
            }
          }
          if (characteristic != null) break;
        }
        
        if (characteristic == null) {
          debugPrint('No suitable characteristic found');
          return StatusCode.unknown;
        }
      }

      // Store for BLE operations
      _currentCharacteristic = characteristic;

      // Enable notifications
      await characteristic.setNotifyValue(true);
      debugPrint('Enabled notifications on characteristic');

      // Call native setup
      final result = await _channel.invokeMethod<int>('setupBLEDevice', {
        'deviceId': device.remoteId.toString(),
      });

      return StatusCode.fromInt(result ?? -1);
    } catch (e) {
      debugPrint('Error setting up BLE device: $e');
      return StatusCode.unknown;
    }
  }

  /// Get library version information
  Future<String> getVersion() async {
    try {
      final result = await _channel.invokeMethod<String>('getVersion');
      return result ?? 'unknown';
    } catch (e) {
      debugPrint('Error getting version: $e');
      return 'unknown';
    }
  }
}
