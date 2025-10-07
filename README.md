# libdivecomputer Flutter Plugin

A Flutter plugin that wraps the libdivecomputer C library for iOS and macOS, enabling communication with dive computers via Bluetooth Low Energy (BLE).

## Features

- ✅ Full libdivecomputer API support
- ✅ iOS 12.0+ and macOS 10.13+ support
- ✅ BLE connectivity via flutter_blue_plus
- ✅ All dive computer vendors and models supported by libdivecomputer
- ✅ Async/await API with callbacks for progress and events
- ✅ Dart camelCase convention (not C snake_case)
- ✅ Complete example app with UI for vendor/device selection and dive download
- ✅ Write echo bug fix implemented
- ✅ Thread-safe architecture based on Subsurface

## Architecture

```
flutter_blue_plus (Dart) → Platform-native BLE operations
         ↓
BLEManager (Swift) → Custom I/O implementation with write echo filtering
         ↓
libdivecomputer (C) → All dive computer protocols and data parsing
```

## Prerequisites

- Flutter SDK 3.10.0+
- Xcode 14.0+ (for iOS/macOS development)
- libdivecomputer.xcframework (pre-built for iOS and macOS)

## Installation

### 1. Add to pubspec.yaml

```yaml
dependencies:
  libdivecomputer:
    path: /path/to/libdivecomputer
```

### 2. Place libdivecomputer.xcframework

Copy your pre-built `libdivecomputer.xcframework` to:

**iOS:**
```
ios/Frameworks/libdivecomputer.xcframework/
```

**macOS:**
```
macos/Frameworks/libdivecomputer.xcframework/
```

### 3. Configure Info.plist

**iOS** (ios/Runner/Info.plist):
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth to connect to dive computers</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app needs Bluetooth to connect to dive computers</string>
```

**macOS** (macos/Runner/Info.plist):
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth to connect to dive computers</string>
<key>com.apple.security.device.bluetooth</key>
<true/>
```

### 4. Run

```bash
flutter pub get
flutter run -d macos  # or ios
```

**Important**: On macOS, run from Terminal (not VSCode) for Bluetooth permissions to work.

## Usage

### 1. Get Available Vendors

```dart
import 'package:libdivecomputer/libdivecomputer.dart';

final libdc = Libdivecomputer.instance;

// Get all vendors
final vendors = await libdc.getVendors();

// Get devices for a vendor
final devices = await libdc.getDescriptorsByVendor('Shearwater');

// Filter for BLE-capable devices
final bleDevices = devices.where((d) => d.supportsBLE).toList();
```

### 2. Scan for BLE Devices

```dart
// Check Bluetooth is enabled
final isEnabled = await libdc.isBluetoothEnabled();

// Start scan
await libdc.startScan(timeout: Duration(seconds: 10));

// Listen to results
libdc.scanForDevices().listen((result) {
  debugPrint('Found: ${result.device.platformName}');
});
```

### 3. Connect and Setup Device

```dart
// Connect
await libdc.connectToDevice(device);

// Setup for libdivecomputer
await libdc.setupBLEDevice(device);

// Open device
final status = await libdc.openDevice(
  vendor: 'Shearwater',
  product: 'Perdix',
  deviceId: device.remoteId.toString(),
);
```

### 4. Download Dives

```dart
final status = await libdc.downloadDives(
  onProgress: (current, total) {
    debugPrint('Progress: $current/$total');
  },
  onDive: (dive) {
    debugPrint('Downloaded dive #${dive.number}');
    debugPrint('  Max depth: ${dive.maxDepth}m');
    debugPrint('  Duration: ${dive.formattedDuration}');
    debugPrint('  Samples: ${dive.samples.length}');
  },
  onDeviceInfo: (info) {
    debugPrint('Device: ${info.serial}');
  },
);

// Close when done
await libdc.closeDevice();
```

### 5. Access Dive Data

```dart
// Dive summary
debugPrint('Dive #${dive.number}');
debugPrint('Date: ${dive.dateTime}');
debugPrint('Duration: ${dive.formattedDuration}');
debugPrint('Max depth: ${dive.maxDepth}m');

// Temperature
if (dive.minTemperature != null) {
  debugPrint('Temperature: ${dive.minTemperature}°C');
}

// Tank pressure
if (dive.startPressure != null) {
  debugPrint('Start pressure: ${dive.startPressure} bar');
  debugPrint('End pressure: ${dive.endPressure} bar');
}

// Profile samples
for (final sample in dive.samples) {
  debugPrint('Time: ${sample.time}s');
  debugPrint('  Depth: ${sample.depth}m');
  debugPrint('  Temperature: ${sample.temperature}°C');
  debugPrint('  Pressure: ${sample.pressure} bar');
}
```

## Key Implementation Details

### Write Echo Fix

The critical bug fix for BLE communication:

```swift
// In BLEManager.swift
func peripheral(
    _ peripheral: CBPeripheral,
    didUpdateValueFor characteristic: CBCharacteristic,
    error: Error?
) {
    guard let data = characteristic.value else { return }
    
    // CRITICAL: Filter out write echo
    // The BLE write is being echoed back into the read queue,
    // causing libdivecomputer to read garbage data
    if let lastWrite = lastWriteData, lastWrite == data {
        debugPrint("Filtering write echo")
        lastWriteData = nil
        return
    }
    
    // Add to receive queue
    receiveQueue.append(data)
}
```

### Threading Architecture

All libdivecomputer operations run on a background thread, while Flutter method channel calls are made on the main thread:

```swift
// In LibdivecomputerPlugin.swift
private func handleDownloadDives(result: @escaping FlutterResult) {
    // Background thread for libdivecomputer
    DispatchQueue.global(qos: .userInitiated).async {
        let status = self.bridge?.downloadDives() ?? -1
        
        // Main thread for Flutter callback
        DispatchQueue.main.async {
            result(status)
        }
    }
}
```

### Custom I/O Callbacks

The bridge implements custom I/O callbacks that route BLE data through flutter_blue_plus:

```swift
// In DiveComputerBridge.swift
var customCallbacks = dc_custom_cbs_t(
    userdata: Unmanaged.passUnretained(self).toOpaque(),
    set_timeout: customSetTimeout,
    read: customRead,
    write: customWrite,
    close: customClose,
    get_available: customGetAvailable
)

dc_custom_open(&iostream, ctx, DC_TRANSPORT_BLE, &customCallbacks)
```

## Supported Dive Computers

All dive computers supported by libdivecomputer that use BLE, including but not limited to:

- **Shearwater**: Perdix, Teric, Peregrine, Petrel
- **Suunto**: EON Steel, EON Core, D5
- **Mares**: Smart, Genius, Quad
- **Oceanic**: Pro Plus X, Geo 4.0
- **And many more...**

Check the complete list with:

```dart
final descriptors = await Libdivecomputer.instance.getDescriptors();
for (final desc in descriptors) {
  if (desc.supportsBLE) {
    debugPrint('${desc.vendor} ${desc.product}');
  }
}
```

## Example App

The included example app demonstrates:

1. Vendor selection dropdown
2. Device selection dropdown (filtered by vendor)
3. BLE scanning with flutter_blue_plus
4. Device connection and setup
5. Dive download with progress updates
6. Split-pane UI showing dive list and details
7. Complete dive data display including profile samples

Run with:

```bash
cd example
flutter run -d macos  # Run from Terminal, not VSCode!
```

## Troubleshooting

### Bluetooth Permissions

If Bluetooth doesn't work:

1. Check Info.plist has correct keys (see Installation step 3)
2. On macOS, run from Terminal, not VSCode
3. Grant permissions when prompted

### Build Errors

**Framework not found:**
- Verify libdivecomputer.xcframework is in correct location
- Check podspec files reference correct paths

**Architecture mismatch:**
- Ensure xcframework has slices for all needed architectures
- iOS: arm64 (device), arm64 + x86_64 (simulator)
- macOS: arm64 + x86_64

### Runtime Errors

**Connection timeout:**
- Ensure dive computer is in Bluetooth mode
- Move closer to dive computer
- Check battery level

**Write echo causing garbage data:**
- This should be fixed automatically by BLEManager
- Check lastWriteData filtering is working

## Testing

Run lint checks:

```bash
flutter analyze
```

## Contributing

Contributions welcome! Please ensure:

1. Code passes `flutter_lints: ^6.0.0` checks
2. Use `debugPrint` instead of `print`
3. Import `package:flutter/foundation.dart` when using `debugPrint`
4. Follow Dart camelCase conventions
5. Test on both iOS and macOS

## Credits

- Based on [libdivecomputer](https://libdivecomputer.org/)
- Inspired by [Subsurface](https://github.com/subsurface/subsurface)
- Uses [flutter_blue_plus](https://pub.dev/packages/flutter_blue_plus) for BLE

## License

[Your License Here]
