# Flutter Libdivecomputer Plugin - Complete Setup Guide

## Overview

This Flutter plugin wraps the libdivecomputer C library for iOS and macOS, using flutter_blue_plus for Bluetooth connectivity.

### Architecture

```
flutter_blue_plus (Dart) → Platform-native BLE
         ↓
BLEManager (Swift) → Custom I/O callbacks
         ↓
libdivecomputer (C) → All dive computer protocols
```

## Prerequisites

- Flutter SDK 3.10.0+
- Xcode 14.0+ (for iOS/macOS development)
- macOS 10.13+ / iOS 12.0+
- libdivecomputer.xcframework (pre-built)

## Step 1: Create the Flutter Plugin

```bash
flutter create --template=plugin \
  --platforms=ios,macos \
  -i swift \
  libdivecomputer

cd libdivecomputer
```

## Step 2: Update pubspec.yaml

Replace the contents of `pubspec.yaml` with the provided file.

Key dependencies:
- `flutter_blue_plus: ^2.0.0` (BLE functionality)
- `flutter_lints: ^6.0.0` (code quality)

## Step 3: Directory Structure

Create the following structure:

```
libdivecomputer/
├── lib/
│   ├── libdivecomputer.dart
│   └── src/
│       ├── models/
│       │   ├── descriptor_info.dart
│       │   ├── device_info.dart
│       │   ├── dive_data.dart
│       │   └── dive_sample.dart
│       ├── enums/
│       │   ├── transport_type.dart
│       │   └── status_code.dart
│       └── libdivecomputer_platform.dart
├── ios/
│   ├── libdivecomputer.podspec
│   ├── Classes/
│   │   ├── LibdivecomputerPlugin.swift
│   │   ├── BLEManager.swift
│   │   ├── DiveComputerBridge.swift
│       └── LibdivecomputerSwiftAPI.swift
│   └── Frameworks/
│       └── libdivecomputer.xcframework/
│           ├── ios-arm64/
│           │   └── libdivecomputer.framework/
│           ├── ios-arm64_x86_64-simulator/
│           │   └── libdivecomputer.framework/
│           └── Info.plist
├── macos/
│   ├── libdivecomputer.podspec
│   ├── Classes/
│   │   ├── LibdivecomputerPlugin.swift
│   │   ├── BLEManager.swift
│   │   ├── DiveComputerBridge.swift
│   │   └── LibdivecomputerSwiftAPI.swift
│   └── Frameworks/
│       └── libdivecomputer.xcframework/
│           ├── macos-arm64/
│           │   └── libdivecomputer.framework/
│           ├── macos-arm64_x86_64/
│           │   └── libdivecomputer.framework/
│           └── Info.plist
└── example/
    ├── lib/
    │   └── main.dart
    ├── ios/
    │   └── Runner/
    │       └── Info.plist
    └── macos/
        └── Runner/
            └── Info.plist
```

## Step 4: Place libdivecomputer.xcframework

### iOS
Copy your `libdivecomputer.xcframework` to:
```
ios/Frameworks/libdivecomputer.xcframework/
```

### macOS
Copy your `libdivecomputer.xcframework` to:
```
macos/Frameworks/libdivecomputer.xcframework/
```

The xcframework should contain:
- iOS device (arm64)
- iOS simulator (arm64 + x86_64)
- macOS (arm64 + x86_64)

## Step 5: Configure iOS Podspec

The iOS podspec (`ios/libdivecomputer.podspec`) configures:
- Deployment target: iOS 12.0+
- Framework search paths
- XCFramework integration
- Required system frameworks

## Step 6: Configure macOS Podspec

The macOS podspec (`macos/libdivecomputer.podspec`) configures:
- Deployment target: macOS 10.13+
- Framework search paths
- XCFramework integration
- Required system frameworks

## Step 7: Configure Info.plist Files

### Example App iOS (example/ios/Runner/Info.plist)

Add Bluetooth permissions:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth to connect to dive computers</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app needs Bluetooth to connect to dive computers</string>
```

### Example App macOS (example/macos/Runner/Info.plist)

Add Bluetooth permissions:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth to connect to dive computers</string>
```

## Step 8: Install Dependencies

```bash
flutter pub get
cd example
flutter pub get
cd ..
```

## Step 9: Build and Run

### For macOS
```bash
cd example
flutter run -d macos
```

### For iOS (requires physical device or simulator)
```bash
cd example
flutter run -d <device-id>
```

## Key Implementation Details

### BLEManager (Swift)

The `BLEManager` class bridges flutter_blue_plus and libdivecomputer:

1. **Write Echo Fix**: The critical fix filters out write echoes:
```swift
// Filter out write echo - this data was just sent, not received
if lastWriteData == data {
    debugPrint("Filtering write echo")
    return
}
```

2. **Threading**: All libdivecomputer operations run on background thread:
```swift
DispatchQueue.global(qos: .userInitiated).async {
    // libdivecomputer operations
}
```

3. **Flutter Communication**: All method channel calls on main thread:
```swift
DispatchQueue.main.async {
    self.channel.invokeMethod("onProgress", arguments: data)
}
```

### Custom I/O Callbacks

The bridge implements these callbacks for libdivecomputer:

- `set_timeout`: Configure read/write timeouts
- `read`: Read data from BLE device
- `write`: Write data to BLE device
- `close`: Clean up connection
- `get_available`: Get available bytes to read

### Dart API

The Dart API uses camelCase conventions:

```dart
// Get all descriptors
Future<List<DescriptorInfo>> getDescriptors()

// Open device
Future<void> openDevice(String descriptor, String address)

// Download dives with callbacks
Future<void> downloadDives({
  void Function(int current, int total)? onProgress,
  void Function(DiveData dive)? onDive,
})
```

## Troubleshooting

### Build Errors

1. **Framework not found**: Verify xcframework is in correct location
2. **Architecture mismatch**: Ensure xcframework has correct slices
3. **Deployment target**: Check minimum versions match

### Runtime Errors

1. **BLE permission denied**: Check Info.plist has correct keys
2. **Connection timeout**: Increase timeout values
3. **Read/write errors**: Check BLE characteristic permissions

### Debugging

Enable debug logging:

```dart
// In Dart
debugPrint("Message");

// In Swift
debugPrint("Message")
```

View logs:
```bash
# macOS
flutter run -d macos -v

# iOS
flutter run -d <device> -v
```

## Testing

### Unit Tests
```bash
flutter test
```

### Integration Tests
```bash
cd example
flutter drive --target=test_driver/app.dart
```

## Example App Features

The example app demonstrates:

1. **Vendor Selection**: Dropdown with all vendors
2. **Device Selection**: Filtered by selected vendor
3. **BLE Scanning**: Uses flutter_blue_plus to find devices
4. **Download Progress**: Real-time progress updates
5. **Dive Display**: List of dives with details

## Next Steps

1. Add Android support (using JNI bridge)
2. Add Windows/Linux support (using FFI)
3. Implement dive log persistence
4. Add dive data visualization
5. Implement dive computer configuration

## Additional Resources

- libdivecomputer docs: https://libdivecomputer.org/
- flutter_blue_plus docs: https://pub.dev/packages/flutter_blue_plus
- Subsurface source: https://github.com/subsurface/subsurface
