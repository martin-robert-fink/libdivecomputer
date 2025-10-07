/// Transport types supported by dive computers
enum TransportType {
  /// No transport
  none,

  /// Serial/USB connection
  serial,

  /// USB HID connection
  usbHid,

  /// USB Storage connection
  usbStorage,

  /// IrDA infrared connection
  irda,

  /// Bluetooth Classic connection
  bluetooth,

  /// Bluetooth Low Energy connection
  bluetoothLE,

  /// USB connection
  usb,

  /// Unknown transport
  unknown;

  /// Create from integer value
  static TransportType fromInt(int value) {
    switch (value) {
      case 0:
        return TransportType.none;
      case 1:
        return TransportType.serial;
      case 2:
        return TransportType.usbHid;
      case 3:
        return TransportType.usbStorage;
      case 4:
        return TransportType.irda;
      case 5:
        return TransportType.bluetooth;
      case 6:
        return TransportType.bluetoothLE;
      case 7:
        return TransportType.usb;
      default:
        return TransportType.unknown;
    }
  }

  /// Convert to integer value
  int toInt() {
    switch (this) {
      case TransportType.none:
        return 0;
      case TransportType.serial:
        return 1;
      case TransportType.usbHid:
        return 2;
      case TransportType.usbStorage:
        return 3;
      case TransportType.irda:
        return 4;
      case TransportType.bluetooth:
        return 5;
      case TransportType.bluetoothLE:
        return 6;
      case TransportType.usb:
        return 7;
      case TransportType.unknown:
        return -1;
    }
  }
}
