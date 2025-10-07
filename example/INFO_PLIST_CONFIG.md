# Info.plist Configuration

## iOS (example/ios/Runner/Info.plist)

Add these keys inside the `<dict>` tag:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth to connect to dive computers and download dive data</string>

<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app needs Bluetooth to connect to dive computers and download dive data</string>
```

## macOS (example/macos/Runner/Info.plist)

Add these keys inside the `<dict>` tag:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth to connect to dive computers and download dive data</string>

<key>com.apple.security.device.bluetooth</key>
<true/>
```

Also ensure the macOS app has proper entitlements in `example/macos/Runner/DebugProfile.entitlements` and `example/macos/Runner/Release.entitlements`:

```xml
<key>com.apple.security.device.bluetooth</key>
<true/>
```

## Running the Example App

**Important**: On macOS, the example app must be run OUTSIDE of VSCode for Bluetooth permissions to work properly.

Use Terminal:
```bash
cd example
flutter run -d macos
```
