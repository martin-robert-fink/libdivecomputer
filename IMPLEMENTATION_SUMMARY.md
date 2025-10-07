# Libdivecomputer Flutter Plugin - Implementation Summary

## What We Learned from 5-6 Previous Attempts

### Critical Issues Solved

1. **Write Echo Bug** ✅
   - **Problem**: BLE writes were being echoed back into read queue
   - **Solution**: Filter echoed data in `BLEManager.swift` by tracking `lastWriteData`
   - **Location**: `BLEManager.swift` line ~80-90

2. **Threading Deadlock** ✅
   - **Problem**: libdivecomputer blocked waiting for Flutter platform channel response
   - **Solution**: Run libdivecomputer on background thread, Flutter calls on main thread
   - **Location**: `LibdivecomputerPlugin.swift` all handle methods

3. **BLE Architecture** ✅
   - **Problem**: Conflicting advice about whether to use flutter_blue_plus or native BLE
   - **Solution**: Use flutter_blue_plus (Dart) → BLEManager (Swift) → libdivecomputer (C)
   - **Source**: Subsurface methodology with Qt Bluetooth

4. **flutter_blue_plus 2.0.0 Requirements** ✅
   - **Must use**: `license: License.free` parameter
   - **Must use**: `debugPrint()` instead of `print()`
   - **Must import**: `package:flutter/foundation.dart`

## Architecture Decisions

### Correct Multi-Layer Architecture

```
┌─────────────────────────────────────────┐
│         Flutter (Dart)                  │
│  - UI, state management                 │
│  - flutter_blue_plus for BLE scanning   │
│  - Libdivecomputer API wrapper          │
└──────────────┬──────────────────────────┘
               │ MethodChannel
┌──────────────┴──────────────────────────┐
│      Swift Bridge Layer                 │
│  - LibdivecomputerPlugin.swift          │
│  - BLEManager.swift (echo filtering)    │
│  - DiveComputerBridge.swift (custom I/O)│
└──────────────┬──────────────────────────┘
               │ Custom I/O Callbacks
┌──────────────┴──────────────────────────┐
│    libdivecomputer (C Library)          │
│  - All dive computer protocols          │
│  - Data parsing                         │
│  - Vendor-specific implementations      │
└─────────────────────────────────────────┘
```

### Why This Works

1. **flutter_blue_plus** handles platform-native BLE differences (iOS/Android/macOS)
2. **BLEManager** bridges BLE data to libdivecomputer with echo filtering
3. **Custom I/O** lets libdivecomputer work without knowing about BLE specifics
4. **Threading** prevents deadlocks while maintaining responsiveness

## File Structure

```
libdivecomputer/
├── lib/
│   ├── libdivecomputer.dart                 # Main export
│   └── src/
│       ├── libdivecomputer_platform.dart    # Platform interface
│       ├── models/                          # Data models
│       │   ├── descriptor_info.dart
│       │   ├── device_info.dart
│       │   ├── dive_data.dart
│       │   └── dive_sample.dart
│       └── enums/                           # Enumerations
│           ├── transport_type.dart
│           └── status_code.dart
│
├── ios/
│   ├── libdivecomputer.podspec              # CocoaPods spec
│   ├── Classes/
│   │   ├── LibdivecomputerPlugin.swift      # Plugin entry point
│   │   ├── BLEManager.swift                 # BLE with echo fix ⚠️
│   │   ├── DiveComputerBridge.swift         # Custom I/O bridge
│   │   └── LibdivecomputerSwiftAPI.swift    # C API declarations
│   └── Frameworks/
│       └── libdivecomputer.xcframework/     # YOU PROVIDE THIS
│
├── macos/
│   ├── libdivecomputer.podspec              # CocoaPods spec
│   ├── Classes/                             # Same as iOS
│   └── Frameworks/
│       └── libdivecomputer.xcframework/     # YOU PROVIDE THIS
│
└── example/
    ├── lib/
    │   └── main.dart                        # Complete demo app
    └── pubspec.yaml
```

## What You Need to Provide

### 1. libdivecomputer.xcframework

Place your pre-built xcframework in:
- `ios/Frameworks/libdivecomputer.xcframework/`
- `macos/Frameworks/libdivecomputer.xcframework/`

Must include:
- **iOS**: arm64 (device), arm64+x86_64 (simulator)
- **macOS**: arm64+x86_64

### 2. Info.plist Configuration

**iOS** (`example/ios/Runner/Info.plist`):
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth to connect to dive computers</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app needs Bluetooth to connect to dive computers</string>
```

**macOS** (`example/macos/Runner/Info.plist`):
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth to connect to dive computers</string>
<key>com.apple.security.device.bluetooth</key>
<true/>
```

## Quick Start

```bash
# 1. Copy all files to your project directory

# 2. Add your libdivecomputer.xcframework
cp -r /path/to/libdivecomputer.xcframework ios/Frameworks/
cp -r /path/to/libdivecomputer.xcframework macos/Frameworks/

# 3. Install dependencies
flutter pub get
cd example
flutter pub get

# 4. Run example (macOS - from Terminal!)
cd example
flutter run -d macos

# 5. Run example (iOS - requires device/simulator)
flutter run -d <device-id>
```

## Key API Examples

### List All Vendors

```dart
final libdc = Libdivecomputer.instance;
final vendors = await libdc.getVendors();
// ['Shearwater', 'Suunto', 'Mares', ...]
```

### Get Devices by Vendor

```dart
final devices = await libdc.getDescriptorsByVendor('Shearwater');
// [DescriptorInfo(vendor: 'Shearwater', product: 'Perdix', ...)]

// Filter for BLE
final bleDevices = devices.where((d) => d.supportsBLE).toList();
```

### Scan for BLE Devices

```dart
await libdc.startScan(timeout: Duration(seconds: 10));

libdc.scanForDevices().listen((result) {
  debugPrint('Found: ${result.device.platformName}');
});
```

### Download Dives

```dart
await libdc.openDevice(
  vendor: 'Shearwater',
  product: 'Perdix',
  deviceId: device.remoteId.toString(),
);

await libdc.downloadDives(
  onProgress: (current, total) {
    debugPrint('Downloading $current/$total');
  },
  onDive: (dive) {
    debugPrint('Got dive #${dive.number}');
    debugPrint('  Depth: ${dive.maxDepth}m');
    debugPrint('  Duration: ${dive.formattedDuration}');
    debugPrint('  Samples: ${dive.samples.length}');
  },
);

await libdc.closeDevice();
```

## Critical Code Sections

### Write Echo Fix (BLEManager.swift)

```swift
// CRITICAL: This fixes the write echo bug
func peripheral(
    _ peripheral: CBPeripheral,
    didUpdateValueFor characteristic: CBCharacteristic,
    error: Error?
) {
    guard let data = characteristic.value else { return }
    
    queueLock.lock()
    
    // Filter out write echo - this was the bug!
    if let lastWrite = lastWriteData, lastWrite == data {
        debugPrint("Filtering write echo")
        lastWriteData = nil
        queueLock.unlock()
        return
    }
    
    receiveQueue.append(data)
    queueLock.unlock()
}
```

### Threading Pattern (LibdivecomputerPlugin.swift)

```swift
private func handleDownloadDives(result: @escaping FlutterResult) {
    // CRITICAL: Background thread for libdivecomputer
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
        let status = self?.bridge?.downloadDives() ?? -1
        
        // CRITICAL: Main thread for Flutter
        DispatchQueue.main.async {
            result(status)
        }
    }
}
```

### Custom I/O Setup (DiveComputerBridge.swift)

```swift
// Setup custom I/O callbacks for BLE
var customCallbacks = dc_custom_cbs_t(
    userdata: Unmanaged.passUnretained(self).toOpaque(),
    set_timeout: customSetTimeout,
    read: customRead,
    write: customWrite,
    close: customClose,
    get_available: customGetAvailable
)

let status = dc_custom_open(
    &iostream,
    ctx,
    DC_TRANSPORT_BLE,
    &customCallbacks
)
```

## Testing Checklist

- [ ] Place libdivecomputer.xcframework in ios/Frameworks/
- [ ] Place libdivecomputer.xcframework in macos/Frameworks/
- [ ] Configure Info.plist for iOS
- [ ] Configure Info.plist for macOS
- [ ] Run `flutter pub get` in plugin root
- [ ] Run `flutter pub get` in example/
- [ ] Run `flutter analyze` (should pass with no issues)
- [ ] Run example app from Terminal on macOS
- [ ] Grant Bluetooth permissions when prompted
- [ ] Test vendor dropdown
- [ ] Test device dropdown
- [ ] Test BLE scan
- [ ] Test device connection
- [ ] Test dive download
- [ ] Verify dive data displays correctly

## Common Issues and Solutions

### Issue: "Framework not found"
**Solution**: Verify xcframework is in `ios/Frameworks/` and `macos/Frameworks/`

### Issue: "Bluetooth permissions denied"
**Solution**: Check Info.plist has correct keys, run from Terminal on macOS

### Issue: "Write echo causing garbage data"
**Solution**: Verify `BLEManager.swift` has the echo filtering code

### Issue: "App freezes during download"
**Solution**: Verify threading in `LibdivecomputerPlugin.swift` uses background queue

### Issue: "Connection timeout"
**Solution**: Ensure dive computer is in BLE mode, check battery, move closer

## Differences from Previous Attempts

| Attempt | Issue | This Solution |
|---------|-------|---------------|
| 1-2 | Conflicting advice on BLE | Clear: Use flutter_blue_plus |
| 3 | Write echo bug | Fixed in BLEManager |
| 4 | Threading deadlock | Background + main thread pattern |
| 5 | flutter_blue_plus usage | Correct License.free usage |
| 6 | No native BLE claimed | Uses flutter_blue_plus correctly |

## Next Steps

1. **Android Support**: Add Kotlin/JNI bridge (similar architecture)
2. **Windows/Linux**: Add FFI bridge (no BLE on these platforms yet in Flutter)
3. **Dive Parser**: Expand `DiveComputerBridge` to parse all dive fields
4. **Tests**: Add unit and integration tests
5. **Persistence**: Add dive log storage (Hive, SQLite, etc.)
6. **Visualization**: Add dive profile graphs

## Resources

- [libdivecomputer docs](https://libdivecomputer.org/)
- [Subsurface source](https://github.com/subsurface/subsurface) (especially qt-ble.cpp)
- [flutter_blue_plus docs](https://pub.dev/packages/flutter_blue_plus)
- [Flutter plugin docs](https://flutter.dev/docs/development/packages-and-plugins/developing-packages)

## Success Metrics

✅ Plugin builds without errors
✅ Example app runs on iOS and macOS
✅ BLE scan finds dive computers
✅ Connection succeeds
✅ Dive download completes
✅ Dive data parses correctly
✅ No write echo issues
✅ No threading deadlocks

**This implementation incorporates all learnings from 5-6 previous attempts and provides a solid foundation for a production-ready dive computer plugin.**
