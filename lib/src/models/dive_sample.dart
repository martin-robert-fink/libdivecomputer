/// A single sample point from a dive profile
class DiveSample {
  /// Time offset from dive start (seconds)
  final int time;

  /// Depth (meters)
  final double? depth;

  /// Temperature (Celsius)
  final double? temperature;

  /// Tank pressure (bar)
  final double? pressure;

  /// Heart rate (bpm)
  final int? heartRate;

  /// NDL (no decompression limit) time (minutes)
  final int? ndl;

  /// Deco stop depth (meters)
  final double? decoDepth;

  /// Deco stop time (minutes)
  final int? decoTime;

  /// CNS (central nervous system oxygen toxicity) percentage
  final double? cns;

  /// Partial pressure of oxygen (bar)
  final double? ppO2;

  /// Gas mix number
  final int? gasMix;

  /// Bearing/heading (degrees)
  final int? bearing;

  const DiveSample({
    required this.time,
    this.depth,
    this.temperature,
    this.pressure,
    this.heartRate,
    this.ndl,
    this.decoDepth,
    this.decoTime,
    this.cns,
    this.ppO2,
    this.gasMix,
    this.bearing,
  });

  /// Create from JSON map
  factory DiveSample.fromMap(Map<String, dynamic> map) {
    return DiveSample(
      time: map['time'] as int,
      depth: map['depth'] as double?,
      temperature: map['temperature'] as double?,
      pressure: map['pressure'] as double?,
      heartRate: map['heartRate'] as int?,
      ndl: map['ndl'] as int?,
      decoDepth: map['decoDepth'] as double?,
      decoTime: map['decoTime'] as int?,
      cns: map['cns'] as double?,
      ppO2: map['ppO2'] as double?,
      gasMix: map['gasMix'] as int?,
      bearing: map['bearing'] as int?,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toMap() {
    return {
      'time': time,
      if (depth != null) 'depth': depth,
      if (temperature != null) 'temperature': temperature,
      if (pressure != null) 'pressure': pressure,
      if (heartRate != null) 'heartRate': heartRate,
      if (ndl != null) 'ndl': ndl,
      if (decoDepth != null) 'decoDepth': decoDepth,
      if (decoTime != null) 'decoTime': decoTime,
      if (cns != null) 'cns': cns,
      if (ppO2 != null) 'ppO2': ppO2,
      if (gasMix != null) 'gasMix': gasMix,
      if (bearing != null) 'bearing': bearing,
    };
  }

  @override
  String toString() {
    return 'DiveSample(time: $time, depth: $depth, temp: $temperature, '
        'pressure: $pressure)';
  }
}
