# macOS Build Fix - October 2025

## Problem Summary
The macOS example project failed to build due to improper xcframework linking and API mismatches with the libdivecomputer C library.

## Root Causes

1. **Incorrect podspec configuration**: The macOS podspec was using `vendored_libraries` instead of `vendored_frameworks`
2. **Missing module map**: No module.modulemap to expose the C API to Swift
3. **Missing umbrella header**: No libdivecomputer.h in the xcframework
4. **Self-import**: DiveComputerBridge.swift was trying to import its own module
5. **API signature mismatches**: The Swift code used old/incorrect API signatures

## Fixes Applied

### 1. Created module.modulemap
**File**: `macos/Frameworks/libdivecomputer.xcframework/macos-arm64/module.modulemap`

```modulemap
framework module libdivecomputer {
    umbrella header "libdivecomputer.h"
    export *
    module * { export * }
}
```

This tells Swift how to import the C library as a module.

### 2. Created umbrella header
**File**: `macos/Frameworks/libdivecomputer.xcframework/macos-arm64/Headers/libdivecomputer.h`

Includes all necessary libdivecomputer headers in one place.

### 3. Updated macOS podspec
**File**: `macos/libdivecomputer.podspec`

Changed from:
```ruby
s.vendored_libraries = 'Frameworks/libdivecomputer.xcframework/macos-arm64/libdivecomputer.a'
s.preserve_paths = 'Frameworks/libdivecomputer.xcframework/**/*'
```

To:
```ruby
s.vendored_frameworks = 'Frameworks/libdivecomputer.xcframework'
```

This matches the iOS configuration and properly handles xcframeworks.

### 4. Removed self-import
**File**: `macos/Classes/DiveComputerBridge.swift`

Removed `import libdivecomputer` line (line 3) - this was causing the "ignoring import" warning.

### 5. Fixed API signatures

#### dc_descriptor_iterator
Changed from macro to actual function:
```swift
// Before (macro doesn't work in Swift)
dc_descriptor_iterator(&iterator)

// After (actual function)
dc_descriptor_iterator_new(&iterator, context)
```

#### dc_custom_cbs_t structure
Updated to match new API where userdata is passed to callbacks, not stored in struct:
```swift
// Before
var customCallbacks = dc_custom_cbs_t(
    userdata: Unmanaged.passUnretained(self).toOpaque(),
    set_timeout: customSetTimeout,
    ...
)

// After
let userdata = Unmanaged.passUnretained(self).toOpaque()
var customCallbacks = dc_custom_cbs_t(
    set_timeout: customSetTimeout,
    set_break: nil,
    set_dtr: nil,
    ...
    // All callbacks now receive userdata as first parameter
)
```

#### dc_custom_open
Added missing userdata parameter:
```swift
// Before
dc_custom_open(&iostream, ctx, DC_TRANSPORT_BLE.rawValue, &customCallbacks)

// After
dc_custom_open(&iostream, ctx, DC_TRANSPORT_BLE, &customCallbacks, userdata)
```

#### Custom I/O callbacks
Updated all callback signatures to match C API:
```swift
// Before
private func customRead(
    iostream: OpaquePointer?,
    data: UnsafeMutableRawPointer?,
    size: Int,
    actual: UnsafeMutablePointer<Int>?,
    userdata: UnsafeMutableRawPointer?
) -> dc_status_t

// After
private func customRead(
    userdata: UnsafeMutableRawPointer?,
    data: UnsafeMutableRawPointer?,
    size: Int,
    actual: UnsafeMutablePointer<Int>?
) -> dc_status_t
```

Applied to: customSetTimeout, customRead, customWrite, customClose, customGetAvailable

#### dc_device_foreach callback
Fixed types to match C API:
```swift
// Before
private func diveCallback(
    data: UnsafePointer<UInt8>?,
    size: Int,  // Wrong type
    fingerprint: UnsafePointer<UInt8>?,
    fsize: Int,  // Wrong type
    userdata: UnsafeMutableRawPointer?
) -> Int32

// After
private func diveCallback(
    data: UnsafePointer<UInt8>?,
    size: UInt32,  // Correct type (unsigned int)
    fingerprint: UnsafePointer<UInt8>?,
    fsize: UInt32,  // Correct type (unsigned int)
    userdata: UnsafeMutableRawPointer?
) -> Int32
```

#### Status type conversions
Fixed dc_status_t to Int conversions:
```swift
// Before
return Int(status)  // Doesn't work - dc_status_t is not BinaryFloatingPoint

// After
return Int(status.rawValue)  // Correct - access the enum's raw value
```

## Testing

After applying these fixes:
1. Clean the build: `flutter clean` in the example directory
2. Get dependencies: `flutter pub get`
3. Run: `flutter run -d macos` (from Terminal, not VSCode)

The project should now build successfully.

## Notes

- These fixes align the macOS implementation with iOS, which was already working
- The libdivecomputer C API has evolved - the Swift wrapper needed updates to match
- All changes maintain backward compatibility with the Dart API layer
- The xcframework structure (static library .a with headers) is now properly exposed to Swift

## Files Modified

1. `macos/libdivecomputer.podspec` - Fixed vendored framework configuration
2. `macos/Classes/DiveComputerBridge.swift` - Fixed all API signatures and removed self-import
3. `macos/Frameworks/libdivecomputer.xcframework/macos-arm64/module.modulemap` - NEW
4. `macos/Frameworks/libdivecomputer.xcframework/macos-arm64/Headers/libdivecomputer.h` - NEW
