import 'dive_sample.dart';

/// Complete data for a single dive
class DiveData {
  /// Dive number
  final int number;

  /// Dive date and time
  final DateTime dateTime;

  /// Dive duration (seconds)
  final int duration;

  /// Maximum depth (meters)
  final double maxDepth;

  /// Average depth (meters)
  final double? avgDepth;

  /// Minimum temperature (Celsius)
  final double? minTemperature;

  /// Maximum temperature (Celsius)
  final double? maxTemperature;

  /// Surface air temperature (Celsius)
  final double? airTemperature;

  /// Starting tank pressure (bar)
  final double? startPressure;

  /// Ending tank pressure (bar)
  final double? endPressure;

  /// Dive mode (e.g., "Air", "Nitrox", "Gauge")
  final String? diveMode;

  /// Salinity (0 = fresh water, 1 = salt water)
  final double? salinity;

  /// Atmospheric pressure at surface (bar)
  final double? atmosphericPressure;

  /// Profile samples
  final List<DiveSample> samples;

  /// Raw dive data (if available)
  final List<int>? rawData;

  const DiveData({
    required this.number,
    required this.dateTime,
    required this.duration,
    required this.maxDepth,
    this.avgDepth,
    this.minTemperature,
    this.maxTemperature,
    this.airTemperature,
    this.startPressure,
    this.endPressure,
    this.diveMode,
    this.salinity,
    this.atmosphericPressure,
    required this.samples,
    this.rawData,
  });

  /// Create from JSON map
  factory DiveData.fromMap(Map<String, dynamic> map) {
    final samplesData = map['samples'] as List<dynamic>? ?? [];
    final samples = samplesData
        .map((s) => DiveSample.fromMap(s as Map<String, dynamic>))
        .toList();

    final rawDataList = map['rawData'] as List<dynamic>?;
    final rawData = rawDataList?.cast<int>();

    return DiveData(
      number: map['number'] as int,
      dateTime: DateTime.fromMillisecondsSinceEpoch(map['dateTime'] as int),
      duration: map['duration'] as int,
      maxDepth: map['maxDepth'] as double,
      avgDepth: map['avgDepth'] as double?,
      minTemperature: map['minTemperature'] as double?,
      maxTemperature: map['maxTemperature'] as double?,
      airTemperature: map['airTemperature'] as double?,
      startPressure: map['startPressure'] as double?,
      endPressure: map['endPressure'] as double?,
      diveMode: map['diveMode'] as String?,
      salinity: map['salinity'] as double?,
      atmosphericPressure: map['atmosphericPressure'] as double?,
      samples: samples,
      rawData: rawData,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toMap() {
    return {
      'number': number,
      'dateTime': dateTime.millisecondsSinceEpoch,
      'duration': duration,
      'maxDepth': maxDepth,
      if (avgDepth != null) 'avgDepth': avgDepth,
      if (minTemperature != null) 'minTemperature': minTemperature,
      if (maxTemperature != null) 'maxTemperature': maxTemperature,
      if (airTemperature != null) 'airTemperature': airTemperature,
      if (startPressure != null) 'startPressure': startPressure,
      if (endPressure != null) 'endPressure': endPressure,
      if (diveMode != null) 'diveMode': diveMode,
      if (salinity != null) 'salinity': salinity,
      if (atmosphericPressure != null)
        'atmosphericPressure': atmosphericPressure,
      'samples': samples.map((s) => s.toMap()).toList(),
      if (rawData != null) 'rawData': rawData,
    };
  }

  /// Format dive duration as HH:MM:SS
  String get formattedDuration {
    final hours = duration ~/ 3600;
    final minutes = (duration % 3600) ~/ 60;
    final seconds = duration % 60;
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  String toString() {
    return 'DiveData(number: $number, dateTime: $dateTime, '
        'duration: $formattedDuration, maxDepth: ${maxDepth}m, '
        'samples: ${samples.length})';
  }
}
