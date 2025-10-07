# Complete Folder Structure

This document shows the complete folder structure for the libdivecomputer Flutter plugin.

```
libdivecomputer/
│
├── README.md                               # Main documentation
├── SETUP_INSTRUCTIONS.md                   # Step-by-step setup guide
├── IMPLEMENTATION_SUMMARY.md               # What we learned, critical fixes
├── pubspec.yaml                            # Plugin dependencies
├── analysis_options.yaml                   # Linting configuration
├── setup.sh                                # Automated setup script
│
├── lib/                                    # Dart code
│   ├── libdivecomputer.dart                # Main export file
│   └── src/
│       ├── libdivecomputer_platform.dart   # Platform interface & API
│       ├── enums/
│       │   ├── transport_type.dart         # Transport enums
│       │   └── status_code.dart            # Status code enums
│       └── models/
│           ├── descriptor_info.dart        # Dive computer descriptor
│           ├── device_info.dart            # Device information
│           ├── dive_data.dart              # Complete dive data
│           └── dive_sample.dart            # Single dive sample
│
├── ios/                                    # iOS platform code
│   ├── libdivecomputer.podspec             # CocoaPods specification
│   ├── Classes/
│   │   ├── LibdivecomputerPlugin.swift     # Plugin entry point
│   │   ├── BLEManager.swift                # BLE manager with echo fix ⚠️
│   │   ├── DiveComputerBridge.swift        # C library bridge
│   │   └── LibdivecomputerSwiftAPI.swift   # C API declarations
│   └── Frameworks/
│       └── libdivecomputer.xcframework/    # ⚠️ YOU PROVIDE THIS
│           ├── Info.plist
│           ├── ios-arm64/
│           │   └── libdivecomputer.framework/
│           └── ios-arm64_x86_64-simulator/
│               └── libdivecomputer.framework/
│
├── macos/                                  # macOS platform code
│   ├── libdivecomputer.podspec             # CocoaPods specification
│   ├── Classes/
│   │   ├── LibdivecomputerPlugin.swift     # Plugin entry point (same as iOS)
│   │   ├── BLEManager.swift                # BLE manager (same as iOS)
│   │   ├── DiveComputerBridge.swift        # C library bridge (same as iOS)
│   │   └── LibdivecomputerSwiftAPI.swift   # C API declarations (same as iOS)
│   └── Frameworks/
│       └── libdivecomputer.xcframework/    # ⚠️ YOU PROVIDE THIS
│           ├── Info.plist
│           ├── macos-arm64/
│           │   └── libdivecomputer.framework/
│           └── macos-arm64_x86_64/
│               └── libdivecomputer.framework/
│
└── example/                                # Example application
    ├── pubspec.yaml                        # Example app dependencies
    ├── INFO_PLIST_CONFIG.md                # Info.plist configuration guide
    │
    ├── lib/
    │   └── main.dart                       # Complete demo app with UI
    │
    ├── ios/
    │   └── Runner/
    │       └── Info.plist                  # ⚠️ ADD BLUETOOTH PERMISSIONS
    │
    └── macos/
        └── Runner/
            ├── Info.plist                  # ⚠️ ADD BLUETOOTH PERMISSIONS
            ├── DebugProfile.entitlements   # ⚠️ ADD BLUETOOTH ENTITLEMENT
            └── Release.entitlements        # ⚠️ ADD BLUETOOTH ENTITLEMENT
```

## Files You Need to Modify

### 1. Add Your XCFramework

Copy your pre-built `libdivecomputer.xcframework` to:

```
ios/Frameworks/libdivecomputer.xcframework/
macos/Frameworks/libdivecomputer.xcframework/
```

The xcframework must contain:
- **iOS**: 
  - `ios-arm64/` (device)
  - `ios-arm64_x86_64-simulator/` (simulator)
- **macOS**:
  - `macos-arm64/` or `macos-arm64_x86_64/` (Apple Silicon + Intel)

### 2. Configure iOS Info.plist

File: `example/ios/Runner/Info.plist`

Add inside `<dict>`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth to connect to dive computers</string>

<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app needs Bluetooth to connect to dive computers</string>
```

### 3. Configure macOS Info.plist

File: `example/macos/Runner/Info.plist`

Add inside `<dict>`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth to connect to dive computers</string>

<key>com.apple.security.device.bluetooth</key>
<true/>
```

### 4. Configure macOS Entitlements

Files: 
- `example/macos/Runner/DebugProfile.entitlements`
- `example/macos/Runner/Release.entitlements`

Add inside `<dict>`:

```xml
<key>com.apple.security.device.bluetooth</key>
<true/>
```

## Key Files Explained

### Core Functionality

- **`lib/src/libdivecomputer_platform.dart`**: Main API that Flutter apps use
- **`ios/Classes/BLEManager.swift`**: Contains the critical write echo fix
- **`ios/Classes/DiveComputerBridge.swift`**: Bridges BLE to libdivecomputer
- **`ios/Classes/LibdivecomputerPlugin.swift`**: Threading and method channel handling

### Configuration

- **`ios/libdivecomputer.podspec`**: Links xcframework for iOS
- **`macos/libdivecomputer.podspec`**: Links xcframework for macOS
- **`pubspec.yaml`**: Declares flutter_blue_plus ^2.0.0 dependency

### Example App

- **`example/lib/main.dart`**: Complete UI demonstrating all features
- **`example/pubspec.yaml`**: Example app dependencies

## Building the XCFramework

If you need to build libdivecomputer.xcframework yourself:

```bash
# Clone libdivecomputer
git clone https://github.com/libdivecomputer/libdivecomputer.git
cd libdivecomputer

# Build for iOS
xcodebuild -create-xcframework \
  -library build-ios/libdivecomputer.a \
  -headers include/ \
  -library build-ios-simulator/libdivecomputer.a \
  -headers include/ \
  -output libdivecomputer-ios.xcframework

# Build for macOS
xcodebuild -create-xcframework \
  -library build-macos/libdivecomputer.a \
  -headers include/ \
  -output libdivecomputer-macos.xcframework

# Combine into universal xcframework
xcodebuild -create-xcframework \
  -framework libdivecomputer-ios.xcframework \
  -framework libdivecomputer-macos.xcframework \
  -output libdivecomputer.xcframework
```

See libdivecomputer documentation for detailed build instructions.

## Verification Checklist

After setup, verify:

- [ ] `ios/Frameworks/libdivecomputer.xcframework/` exists
- [ ] `macos/Frameworks/libdivecomputer.xcframework/` exists
- [ ] `example/ios/Runner/Info.plist` has Bluetooth permissions
- [ ] `example/macos/Runner/Info.plist` has Bluetooth permissions
- [ ] `example/macos/Runner/*.entitlements` have Bluetooth entitlement
- [ ] `flutter pub get` runs without errors
- [ ] `flutter analyze` passes (or only minor warnings)
- [ ] Example app builds for iOS
- [ ] Example app builds for macOS
- [ ] Example app runs and Bluetooth scanning works

## Notes

- Swift files are identical for iOS and macOS (uses platform checks)
- XCFramework can contain multiple platforms in one bundle
- flutter_blue_plus handles BLE differently on each platform
- Example app must run from Terminal on macOS for Bluetooth permissions
