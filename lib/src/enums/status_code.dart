/// Status codes returned by libdivecomputer operations
enum StatusCode {
  /// Operation completed successfully
  success,

  /// Operation is not supported
  unsupported,

  /// Invalid parameters
  invalidParams,

  /// Device not found
  noDevice,

  /// Device access denied
  noaccess,

  /// Input/output error
  ioError,

  /// Operation timed out
  timeout,

  /// Protocol error
  protocolError,

  /// Data format error
  dataFormat,

  /// Operation cancelled
  cancelled,

  /// Unknown error
  unknown;

  /// Create from integer value
  static StatusCode fromInt(int value) {
    switch (value) {
      case 0:
        return StatusCode.success;
      case 1:
        return StatusCode.unsupported;
      case 2:
        return StatusCode.invalidParams;
      case 3:
        return StatusCode.noDevice;
      case 4:
        return StatusCode.noaccess;
      case 5:
        return StatusCode.ioError;
      case 6:
        return StatusCode.timeout;
      case 7:
        return StatusCode.protocolError;
      case 8:
        return StatusCode.dataFormat;
      case 9:
        return StatusCode.cancelled;
      default:
        return StatusCode.unknown;
    }
  }

  /// Convert to integer value
  int toInt() {
    switch (this) {
      case StatusCode.success:
        return 0;
      case StatusCode.unsupported:
        return 1;
      case StatusCode.invalidParams:
        return 2;
      case StatusCode.noDevice:
        return 3;
      case StatusCode.noaccess:
        return 4;
      case StatusCode.ioError:
        return 5;
      case StatusCode.timeout:
        return 6;
      case StatusCode.protocolError:
        return 7;
      case StatusCode.dataFormat:
        return 8;
      case StatusCode.cancelled:
        return 9;
      case StatusCode.unknown:
        return -1;
    }
  }

  /// Get human-readable description
  String get description {
    switch (this) {
      case StatusCode.success:
        return 'Operation completed successfully';
      case StatusCode.unsupported:
        return 'Operation is not supported';
      case StatusCode.invalidParams:
        return 'Invalid parameters';
      case StatusCode.noDevice:
        return 'Device not found';
      case StatusCode.noaccess:
        return 'Device access denied';
      case StatusCode.ioError:
        return 'Input/output error';
      case StatusCode.timeout:
        return 'Operation timed out';
      case StatusCode.protocolError:
        return 'Protocol error';
      case StatusCode.dataFormat:
        return 'Data format error';
      case StatusCode.cancelled:
        return 'Operation cancelled';
      case StatusCode.unknown:
        return 'Unknown error';
    }
  }
}
