/// Represents a single ECG data point with processing metadata
class ECGSample {
  final DateTime timestamp;
  final double rawValue;
  final double filteredValue;
  final bool isRPeak;
  final int index;

  ECGSample({
    required this.timestamp,
    required this.rawValue,
    required this.filteredValue,
    required this.isRPeak,
    required this.index,
  });

  ECGSample copyWith({
    DateTime? timestamp,
    double? rawValue,
    double? filteredValue,
    bool? isRPeak,
    int? index,
  }) {
    return ECGSample(
      timestamp: timestamp ?? this.timestamp,
      rawValue: rawValue ?? this.rawValue,
      filteredValue: filteredValue ?? this.filteredValue,
      isRPeak: isRPeak ?? this.isRPeak,
      index: index ?? this.index,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'raw_value': rawValue,
      'filtered_value': filteredValue,
      'is_r_peak': isRPeak,
      'sample_index': index,
    };
  }

  factory ECGSample.fromJson(Map<String, dynamic> json) {
    return ECGSample(
      timestamp: DateTime.parse(json['timestamp'] as String),
      rawValue: (json['raw_value'] as num).toDouble(),
      filteredValue: (json['filtered_value'] as num).toDouble(),
      isRPeak: json['is_r_peak'] as bool,
      index: json['sample_index'] as int,
    );
  }
}

/// Represents a detected R-peak in the ECG signal
class RPeak {
  final int index;
  final DateTime timestamp;
  final double rrInterval; // in milliseconds
  final double instantaneousBPM;
  final double amplitude;

  RPeak({
    required this.index,
    required this.timestamp,
    required this.rrInterval,
    required this.instantaneousBPM,
    required this.amplitude,
  });

  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'timestamp': timestamp.toIso8601String(),
      'rr_interval': rrInterval,
      'instantaneous_bpm': instantaneousBPM,
      'amplitude': amplitude,
    };
  }

  factory RPeak.fromJson(Map<String, dynamic> json) {
    return RPeak(
      index: json['index'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
      rrInterval: (json['rr_interval'] as num).toDouble(),
      instantaneousBPM: (json['instantaneous_bpm'] as num).toDouble(),
      amplitude: (json['amplitude'] as num).toDouble(),
    );
  }
}

/// Represents a complete ECG recording session
class ECGSession {
  final String id;
  final String userId;
  final DateTime startTime;
  final DateTime? endTime;
  final List<ECGSample> samples;
  final List<RPeak> rPeaks;
  final double? averageHeartRate;
  final double? maxHeartRate;
  final double? minHeartRate;
  final int? totalRPeaks;
  final int durationSeconds;

  ECGSession({
    required this.id,
    required this.userId,
    required this.startTime,
    this.endTime,
    required this.samples,
    required this.rPeaks,
    this.averageHeartRate,
    this.maxHeartRate,
    this.minHeartRate,
    this.totalRPeaks,
    required this.durationSeconds,
  });

  /// Calculate session statistics from R-peaks
  ECGSession calculateStatistics() {
    if (rPeaks.isEmpty) {
      return this;
    }

    final bpmValues = rPeaks.map((peak) => peak.instantaneousBPM).toList();
    final avgBPM = bpmValues.reduce((a, b) => a + b) / bpmValues.length;
    final maxBPM = bpmValues.reduce((a, b) => a > b ? a : b);
    final minBPM = bpmValues.reduce((a, b) => a < b ? a : b);

    return ECGSession(
      id: id,
      userId: userId,
      startTime: startTime,
      endTime: endTime,
      samples: samples,
      rPeaks: rPeaks,
      averageHeartRate: avgBPM,
      maxHeartRate: maxBPM,
      minHeartRate: minBPM,
      totalRPeaks: rPeaks.length,
      durationSeconds: durationSeconds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'duration_seconds': durationSeconds,
      'average_heart_rate': averageHeartRate,
      'max_heart_rate': maxHeartRate,
      'min_heart_rate': minHeartRate,
      'r_peak_count': totalRPeaks,
      'samples': samples.map((s) => s.toJson()).toList(),
      'r_peaks': rPeaks.map((r) => r.toJson()).toList(),
    };
  }

  factory ECGSession.fromJson(Map<String, dynamic> json) {
    return ECGSession(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'] as String)
          : null,
      durationSeconds: json['duration_seconds'] as int,
      averageHeartRate: json['average_heart_rate'] != null
          ? (json['average_heart_rate'] as num).toDouble()
          : null,
      maxHeartRate: json['max_heart_rate'] != null
          ? (json['max_heart_rate'] as num).toDouble()
          : null,
      minHeartRate: json['min_heart_rate'] != null
          ? (json['min_heart_rate'] as num).toDouble()
          : null,
      totalRPeaks: json['r_peak_count'] as int?,
      samples:
          (json['samples'] as List<dynamic>?)
              ?.map((s) => ECGSample.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      rPeaks:
          (json['r_peaks'] as List<dynamic>?)
              ?.map((r) => RPeak.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
