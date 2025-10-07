import '../enums/transport_type.dart';

/// Information about a dive computer descriptor
class DescriptorInfo {
  /// Vendor name
  final String vendor;

  /// Product name
  final String product;

  /// Model number
  final int model;

  /// Supported transport types
  final List<TransportType> transports;

  const DescriptorInfo({
    required this.vendor,
    required this.product,
    required this.model,
    required this.transports,
  });

  /// Create from JSON map
  factory DescriptorInfo.fromMap(Map<String, dynamic> map) {
    final transportsData = map['transports'] as List<dynamic>? ?? [];
    final transports = transportsData
        .map((t) => TransportType.fromInt(t as int))
        .toList();

    return DescriptorInfo(
      vendor: map['vendor'] as String,
      product: map['product'] as String,
      model: map['model'] as int,
      transports: transports,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toMap() {
    return {
      'vendor': vendor,
      'product': product,
      'model': model,
      'transports': transports.map((t) => t.toInt()).toList(),
    };
  }

  /// Check if transport type is supported
  bool supportsTransport(TransportType type) {
    return transports.contains(type);
  }

  /// Check if Bluetooth LE is supported
  bool get supportsBLE => supportsTransport(TransportType.bluetoothLE);

  /// Check if Bluetooth Classic is supported
  bool get supportsBluetooth => supportsTransport(TransportType.bluetooth);

  @override
  String toString() {
    return 'DescriptorInfo(vendor: $vendor, product: $product, '
        'model: $model, transports: $transports)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DescriptorInfo &&
        other.vendor == vendor &&
        other.product == product &&
        other.model == model;
  }

  @override
  int get hashCode => Object.hash(vendor, product, model);
}
