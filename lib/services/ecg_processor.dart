import 'dart:collection';
import '../models/ecg_data.dart';

/// Implements the Pan-Tompkins algorithm for real-time QRS detection
/// Reference: Pan, J., & Tompkins, W. J. (1985). A real-time QRS detection algorithm.
class ECGProcessor {
  final double samplingRate;

  // Filter buffers
  final Queue<double> _lowPassBuffer = Queue();
  final Queue<double> _highPassBuffer = Queue();
  final Queue<double> _derivativeBuffer = Queue();
  final Queue<double> _integrationBuffer = Queue();

  // Processing state
  int _sampleIndex = 0;
  DateTime? _sessionStartTime;

  // R-peak detection state
  final List<RPeak> _detectedRPeaks = [];
  double _signalPeak = 0;
  double _noisePeak = 0;
  double _thresholdI1 = 0;
  double _thresholdI2 = 0;
  int _lastRPeakIndex = -1000; // Initialize far in the past

  // Configuration
  late final int _refractoryPeriodSamples;
  late final int _integrationWindowSize;
  late final double _learningRate;

  // Recent R-R intervals for BPM calculation
  final Queue<double> _rrIntervals = Queue();
  static const int _maxRRIntervals = 8;

  ECGProcessor({required this.samplingRate}) {
    // Calculate parameters based on sampling rate
    // INCREASED refractory period to prevent double-detection
    _refractoryPeriodSamples = (0.3 * samplingRate)
        .round(); // 300ms refractory period (was 200ms)
    _integrationWindowSize = (0.15 * samplingRate)
        .round(); // 150ms integration window
    _learningRate =
        0.1; // REDUCED learning rate for more stable thresholds (was 0.125)

    // Initialize thresholds
    _thresholdI1 = 0;
    _thresholdI2 = 0;
  }

  /// Process a single ECG sample through the Pan-Tompkins pipeline
  /// Returns the filtered value and whether an R-peak was detected
  (double filteredValue, bool isRPeak) processSample(double rawValue) {
    _sessionStartTime ??= DateTime.now();

    // Stage 1: Bandpass Filter (5-15 Hz)
    double lowPassed = _lowPassFilter(rawValue);
    double bandPassed = _highPassFilter(lowPassed);

    // Stage 2: Derivative (emphasize slope)
    double derivative = _derivativeFilter(bandPassed);

    // Stage 3: Squaring (make positive, emphasize larger values)
    double squared = derivative * derivative;

    // Stage 4: Moving Window Integration
    double integrated = _movingWindowIntegration(squared);

    // Stage 5: R-peak Detection
    bool isRPeak = _detectRPeak(integrated, rawValue);

    _sampleIndex++;

    return (integrated, isRPeak);
  }

  /// Low-pass filter: y[n] = 2*y[n-1] - y[n-2] + x[n] - 2*x[n-6] + x[n-12]
  /// Cutoff frequency: ~15 Hz
  double _lowPassFilter(double input) {
    _lowPassBuffer.add(input);

    if (_lowPassBuffer.length < 13) {
      return input;
    }

    if (_lowPassBuffer.length > 13) {
      _lowPassBuffer.removeFirst();
    }

    final list = _lowPassBuffer.toList();
    final output =
        2 * (list.length >= 2 ? list[list.length - 2] : 0) -
        (list.length >= 3 ? list[list.length - 3] : 0) +
        list[list.length - 1] -
        2 * (list.length >= 7 ? list[list.length - 7] : 0) +
        (list.length >= 13 ? list[list.length - 13] : 0);

    return output / 32.0; // Normalize
  }

  /// High-pass filter: y[n] = y[n-1] - x[n]/32 + x[n-16] - x[n-17] + x[n-32]/32
  /// Cutoff frequency: ~5 Hz
  double _highPassFilter(double input) {
    _highPassBuffer.add(input);

    if (_highPassBuffer.length < 33) {
      return input;
    }

    if (_highPassBuffer.length > 33) {
      _highPassBuffer.removeFirst();
    }

    final list = _highPassBuffer.toList();
    final output =
        (list.length >= 2 ? list[list.length - 2] : 0) -
        list[list.length - 1] / 32 +
        (list.length >= 17 ? list[list.length - 17] : 0) -
        (list.length >= 18 ? list[list.length - 18] : 0) +
        (list.length >= 33 ? list[list.length - 33] : 0) / 32;

    return output;
  }

  /// Derivative filter: y[n] = (2*x[n] + x[n-1] - x[n-3] - 2*x[n-4]) / 8
  /// Emphasizes QRS slope information
  double _derivativeFilter(double input) {
    _derivativeBuffer.add(input);

    if (_derivativeBuffer.length < 5) {
      return 0;
    }

    if (_derivativeBuffer.length > 5) {
      _derivativeBuffer.removeFirst();
    }

    final list = _derivativeBuffer.toList();
    final output = (2 * list[4] + list[3] - list[1] - 2 * list[0]) / 8.0;

    return output;
  }

  /// Moving window integration: smooths the squared derivative
  double _movingWindowIntegration(double input) {
    _integrationBuffer.add(input);

    if (_integrationBuffer.length > _integrationWindowSize) {
      _integrationBuffer.removeFirst();
    }

    // Calculate average of window
    double sum = 0;
    for (var value in _integrationBuffer) {
      sum += value;
    }

    return sum / _integrationWindowSize;
  }

  /// Adaptive thresholding and R-peak detection
  bool _detectRPeak(double integratedValue, double rawValue) {
    // Check refractory period
    if (_sampleIndex - _lastRPeakIndex < _refractoryPeriodSamples) {
      return false;
    }

    // Initialize thresholds on first samples
    if (_thresholdI1 == 0) {
      _thresholdI1 = integratedValue * 0.5;
      _thresholdI2 = _thresholdI1 * 0.5;
      return false;
    }

    // Check if current value exceeds threshold
    if (integratedValue > _thresholdI1) {
      // Potential R-peak detected
      // Look for local maximum in a small window
      if (_isLocalMaximum(integratedValue)) {
        _registerRPeak(integratedValue, rawValue);
        return true;
      }
    } else {
      // Update noise peak
      _noisePeak =
          _learningRate * integratedValue + (1 - _learningRate) * _noisePeak;
      _updateThresholds();
    }

    return false;
  }

  /// Check if current sample is a local maximum
  bool _isLocalMaximum(double currentValue) {
    if (_integrationBuffer.length < 3) return false;

    final list = _integrationBuffer.toList();
    final current = list[list.length - 1];
    final prev = list[list.length - 2];

    return current >= prev; // Simple check, can be enhanced
  }

  /// Register a detected R-peak
  void _registerRPeak(double integratedValue, double rawValue) {
    // Update signal peak with learning rate
    _signalPeak =
        _learningRate * integratedValue + (1 - _learningRate) * _signalPeak;
    _updateThresholds();

    // Calculate R-R interval
    double rrInterval = 0;
    double instantaneousBPM = 0;

    if (_detectedRPeaks.isNotEmpty) {
      final lastPeak = _detectedRPeaks.last;
      final samplesSinceLastPeak = _sampleIndex - lastPeak.index;
      rrInterval =
          (samplesSinceLastPeak / samplingRate) * 1000; // Convert to ms

      // Calculate instantaneous BPM
      if (rrInterval > 0) {
        instantaneousBPM = 60000 / rrInterval; // 60000 ms per minute

        // Store R-R interval for average BPM calculation
        _rrIntervals.add(rrInterval);
        if (_rrIntervals.length > _maxRRIntervals) {
          _rrIntervals.removeFirst();
        }
      }
    }

    final timestamp = _sessionStartTime!.add(
      Duration(microseconds: (_sampleIndex / samplingRate * 1000000).round()),
    );

    final rPeak = RPeak(
      index: _sampleIndex,
      timestamp: timestamp,
      rrInterval: rrInterval,
      instantaneousBPM: instantaneousBPM,
      amplitude: rawValue,
    );

    _detectedRPeaks.add(rPeak);
    _lastRPeakIndex = _sampleIndex;
  }

  /// Update adaptive thresholds
  void _updateThresholds() {
    // INCREASED threshold multiplier to be more selective (was 0.25)
    _thresholdI1 = _noisePeak + 0.35 * (_signalPeak - _noisePeak);
    _thresholdI2 = 0.5 * _thresholdI1;
  }

  /// Calculate current heart rate from recent R-R intervals
  double calculateBPM() {
    if (_rrIntervals.isEmpty) return 0;

    // Average R-R interval
    double avgRRInterval =
        _rrIntervals.reduce((a, b) => a + b) / _rrIntervals.length;

    // Convert to BPM
    double bpm = 60000 / avgRRInterval;

    // Sanity check: clamp BPM to realistic range (30-200 BPM)
    if (bpm < 30) return 30;
    if (bpm > 200) return 200;

    return bpm;
  }

  /// Get all detected R-peaks
  List<RPeak> getDetectedRPeaks() {
    return List.unmodifiable(_detectedRPeaks);
  }

  /// Get the most recent R-peaks (for visualization)
  List<RPeak> getRecentRPeaks(int count) {
    if (_detectedRPeaks.length <= count) {
      return List.unmodifiable(_detectedRPeaks);
    }
    return List.unmodifiable(
      _detectedRPeaks.sublist(_detectedRPeaks.length - count),
    );
  }

  /// Reset the processor for a new session
  void reset() {
    _lowPassBuffer.clear();
    _highPassBuffer.clear();
    _derivativeBuffer.clear();
    _integrationBuffer.clear();
    _detectedRPeaks.clear();
    _rrIntervals.clear();

    _sampleIndex = 0;
    _sessionStartTime = null;
    _signalPeak = 0;
    _noisePeak = 0;
    _thresholdI1 = 0;
    _thresholdI2 = 0;
    _lastRPeakIndex = -1000;
  }

  /// Get current session statistics
  Map<String, dynamic> getSessionStats() {
    return {
      'total_samples': _sampleIndex,
      'total_r_peaks': _detectedRPeaks.length,
      'current_bpm': calculateBPM(),
      'signal_peak': _signalPeak,
      'noise_peak': _noisePeak,
      'threshold': _thresholdI1,
    };
  }
}
