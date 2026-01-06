import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ecg_data.dart';

/// Service for storing and retrieving ECG sessions from Supabase
/// Integrates with existing ecg_readings table structure
class ECGStorageService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Save a complete ECG session to Supabase using existing ecg_readings table
  /// Returns the reading_id if successful, null otherwise
  Future<int?> saveSession(ECGSession session) async {
    try {
      // Calculate statistics if not already done
      final sessionWithStats = session.averageHeartRate == null
          ? session.calculateStatistics()
          : session;

      // 1. Save to ecg_readings table with Pan-Tompkins metadata
      final readingData = {
        'user_id': sessionWithStats.userId,
        'timestamp': sessionWithStats.startTime.toIso8601String(),
        'raw_values': [], // Empty array or store downsampled data if needed
        'duration_seconds': sessionWithStats.durationSeconds,
        'average_heart_rate': sessionWithStats.averageHeartRate,
        'max_heart_rate': sessionWithStats.maxHeartRate,
        'min_heart_rate': sessionWithStats.minHeartRate,
        'r_peak_count': sessionWithStats.totalRPeaks,
        'session_end_time': sessionWithStats.endTime?.toIso8601String(),
      };

      final response = await _supabase
          .from('ecg_readings')
          .insert(readingData)
          .select('reading_id')
          .single();

      final readingId = response['reading_id'] as int;

      // 2. Save R-peaks
      if (sessionWithStats.rPeaks.isNotEmpty) {
        final rPeakData = sessionWithStats.rPeaks.map((peak) {
          return {
            'reading_id': readingId,
            'sample_index': peak.index,
            'timestamp': peak.timestamp.toIso8601String(),
            'rr_interval': peak.rrInterval,
            'instantaneous_bpm': peak.instantaneousBPM,
            'amplitude': peak.amplitude,
          };
        }).toList();

        await _supabase.from('ecg_r_peaks').insert(rPeakData);
      }

      return readingId;
    } catch (e) {
      print('Error saving ECG session: $e');
      return null;
    }
  }

  /// Get recent ECG sessions for a user
  Future<List<ECGSession>> getRecentSessions(
    String userId, {
    int limit = 10,
  }) async {
    try {
      final response = await _supabase
          .from('ecg_readings')
          .select()
          .eq('user_id', userId)
          .order('timestamp', ascending: false)
          .limit(limit);

      final sessions = <ECGSession>[];
      for (final sessionData in response as List<dynamic>) {
        final readingId = sessionData['reading_id'] as int;

        // Get R-peaks for this reading
        final rPeaksResponse = await _supabase
            .from('ecg_r_peaks')
            .select()
            .eq('reading_id', readingId)
            .order('sample_index', ascending: true);

        final rPeaks = (rPeaksResponse as List<dynamic>)
            .map(
              (data) => RPeak(
                index: data['sample_index'] as int,
                timestamp: DateTime.parse(data['timestamp'] as String),
                rrInterval: (data['rr_interval'] as num).toDouble(),
                instantaneousBPM: (data['instantaneous_bpm'] as num).toDouble(),
                amplitude: (data['amplitude'] as num).toDouble(),
              ),
            )
            .toList();

        final session = ECGSession(
          id: readingId.toString(),
          userId: sessionData['user_id'] as String,
          startTime: DateTime.parse(sessionData['timestamp'] as String),
          endTime: sessionData['session_end_time'] != null
              ? DateTime.parse(sessionData['session_end_time'] as String)
              : null,
          durationSeconds: sessionData['duration_seconds'] as int? ?? 0,
          averageHeartRate: sessionData['average_heart_rate'] != null
              ? (sessionData['average_heart_rate'] as num).toDouble()
              : null,
          maxHeartRate: sessionData['max_heart_rate'] != null
              ? (sessionData['max_heart_rate'] as num).toDouble()
              : null,
          minHeartRate: sessionData['min_heart_rate'] != null
              ? (sessionData['min_heart_rate'] as num).toDouble()
              : null,
          totalRPeaks: sessionData['r_peak_count'] as int?,
          samples: [],
          rPeaks: rPeaks,
        );

        sessions.add(session);
      }

      return sessions;
    } catch (e) {
      print('Error fetching recent sessions: $e');
      return [];
    }
  }

  /// Get a specific session by reading_id with full details
  Future<ECGSession?> getSessionById(int readingId) async {
    try {
      final sessionResponse = await _supabase
          .from('ecg_readings')
          .select()
          .eq('reading_id', readingId)
          .single();

      // Get R-peaks
      final rPeaksResponse = await _supabase
          .from('ecg_r_peaks')
          .select()
          .eq('reading_id', readingId)
          .order('sample_index', ascending: true);

      final rPeaks = (rPeaksResponse as List<dynamic>)
          .map(
            (data) => RPeak(
              index: data['sample_index'] as int,
              timestamp: DateTime.parse(data['timestamp'] as String),
              rrInterval: (data['rr_interval'] as num).toDouble(),
              instantaneousBPM: (data['instantaneous_bpm'] as num).toDouble(),
              amplitude: (data['amplitude'] as num).toDouble(),
            ),
          )
          .toList();

      return ECGSession(
        id: readingId.toString(),
        userId: sessionResponse['user_id'] as String,
        startTime: DateTime.parse(sessionResponse['timestamp'] as String),
        endTime: sessionResponse['session_end_time'] != null
            ? DateTime.parse(sessionResponse['session_end_time'] as String)
            : null,
        durationSeconds: sessionResponse['duration_seconds'] as int? ?? 0,
        averageHeartRate: sessionResponse['average_heart_rate'] != null
            ? (sessionResponse['average_heart_rate'] as num).toDouble()
            : null,
        maxHeartRate: sessionResponse['max_heart_rate'] != null
            ? (sessionResponse['max_heart_rate'] as num).toDouble()
            : null,
        minHeartRate: sessionResponse['min_heart_rate'] != null
            ? (sessionResponse['min_heart_rate'] as num).toDouble()
            : null,
        totalRPeaks: sessionResponse['r_peak_count'] as int?,
        samples: [],
        rPeaks: rPeaks,
      );
    } catch (e) {
      print('Error fetching session: $e');
      return null;
    }
  }

  /// Delete a session and all associated data
  Future<bool> deleteSession(int readingId) async {
    try {
      // Delete R-peaks first (foreign key constraint)
      await _supabase.from('ecg_r_peaks').delete().eq('reading_id', readingId);

      // Delete reading (this will cascade to analysis table if configured)
      await _supabase.from('ecg_readings').delete().eq('reading_id', readingId);

      return true;
    } catch (e) {
      print('Error deleting session: $e');
      return false;
    }
  }

  /// Get session count for a user
  Future<int> getSessionCount(String userId) async {
    try {
      final response = await _supabase
          .from('ecg_readings')
          .select('reading_id')
          .eq('user_id', userId);

      return (response as List<dynamic>).length;
    } catch (e) {
      print('Error getting session count: $e');
      return 0;
    }
  }

  /// Upload ECG chart image to Supabase Storage
  /// Returns the public URL of the uploaded image, or null if upload fails
  Future<String?> uploadECGImage({
    required File imageFile,
    required String userId,
    required int readingId,
  }) async {
    try {
      // Create file path: user_id/reading_id.png
      final String fileName = '$userId/$readingId.png';

      // Upload to Supabase Storage bucket 'ecg-images'
      await _supabase.storage
          .from('ecg-images')
          .upload(
            fileName,
            imageFile,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: true, // Replace if exists
            ),
          );

      // Get public URL
      final String imageUrl = _supabase.storage
          .from('ecg-images')
          .getPublicUrl(fileName);

      print('ECG image uploaded successfully: $imageUrl');
      return imageUrl;
    } catch (e) {
      print('Error uploading ECG image: $e');
      return null;
    }
  }

  /// Update the image URL for an existing ECG reading
  Future<bool> updateImageUrl(int readingId, String imageUrl) async {
    try {
      await _supabase
          .from('ecg_readings')
          .update({'ecg_image_url': imageUrl})
          .eq('reading_id', readingId);

      print('Image URL updated for reading $readingId');
      return true;
    } catch (e) {
      print('Error updating image URL: $e');
      return false;
    }
  }

  /// Delete ECG image from Supabase Storage
  Future<bool> deleteECGImage(String userId, int readingId) async {
    try {
      final String fileName = '$userId/$readingId.png';
      await _supabase.storage.from('ecg-images').remove([fileName]);

      print('ECG image deleted: $fileName');
      return true;
    } catch (e) {
      print('Error deleting ECG image: $e');
      return false;
    }
  }

  /// Save session with ECG image
  /// This is a convenience method that combines session saving and image upload
  Future<int?> saveSessionWithImage({
    required ECGSession session,
    required File imageFile,
  }) async {
    try {
      // 1. Save session to get reading_id
      final readingId = await saveSession(session);
      if (readingId == null) {
        print('Failed to save session');
        return null;
      }

      // 2. Upload image
      final imageUrl = await uploadECGImage(
        imageFile: imageFile,
        userId: session.userId,
        readingId: readingId,
      );

      if (imageUrl == null) {
        print('Failed to upload image, but session was saved');
        return readingId;
      }

      // 3. Update session with image URL
      await updateImageUrl(readingId, imageUrl);

      return readingId;
    } catch (e) {
      print('Error saving session with image: $e');
      return null;
    }
  }
}
