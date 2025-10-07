/// Information about a connected dive computer device
class DeviceInfo {
  /// Device serial number
  final String? serial;

  /// Firmware version
  final String? firmware;

  /// Hardware version
  final String? hardware;

  /// Device model
  final int? model;

  const DeviceInfo({
    this.serial,
    this.firmware,
    this.hardware,
    this.model,
  });

  /// Create from JSON map
  factory DeviceInfo.fromMap(Map<String, dynamic> map) {
    return DeviceInfo(
      serial: map['serial'] as String?,
      firmware: map['firmware'] as String?,
      hardware: map['hardware'] as String?,
      model: map['model'] as int?,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toMap() {
    return {
      if (serial != null) 'serial': serial,
      if (firmware != null) 'firmware': firmware,
      if (hardware != null) 'hardware': hardware,
      if (model != null) 'model': model,
    };
  }

  @override
  String toString() {
    return 'DeviceInfo(serial: $serial, firmware: $firmware, '
        'hardware: $hardware, model: $model)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeviceInfo &&
        other.serial == serial &&
        other.firmware == firmware &&
        other.hardware == hardware &&
        other.model == model;
  }

  @override
  int get hashCode => Object.hash(serial, firmware, hardware, model);
}
