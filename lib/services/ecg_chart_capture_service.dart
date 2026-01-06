import 'dart:io';
import 'dart:typed_data';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';

/// Service for capturing ECG charts as images
class ECGChartCaptureService {
  final ScreenshotController screenshotController = ScreenshotController();

  /// Capture the ECG chart widget as a PNG image
  /// Returns the image file or null if capture fails
  Future<File?> captureChart({
    required String userId,
    required String sessionId,
    int imageQuality = 100,
  }) async {
    try {
      // Capture the widget as image bytes
      final Uint8List? imageBytes = await screenshotController.capture(
        pixelRatio: 2.0, // Higher quality for medical accuracy
      );

      if (imageBytes == null) {
        print('Failed to capture chart image');
        return null;
      }

      // Get temporary directory
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName =
          'ecg_${userId}_${sessionId}_${DateTime.now().millisecondsSinceEpoch}.png';
      final String filePath = '${tempDir.path}/$fileName';

      // Save to file
      final File imageFile = File(filePath);
      await imageFile.writeAsBytes(imageBytes);

      print(
        'Chart captured successfully: $filePath (${imageBytes.length} bytes)',
      );
      return imageFile;
    } catch (e) {
      print('Error capturing chart: $e');
      return null;
    }
  }

  /// Capture chart with custom dimensions
  Future<File?> captureChartWithSize({
    required String userId,
    required String sessionId,
    double? width,
    double? height,
  }) async {
    try {
      final Uint8List? imageBytes = await screenshotController.capture(
        pixelRatio: 2.0,
      );

      if (imageBytes == null) return null;

      final Directory tempDir = await getTemporaryDirectory();
      final String fileName = 'ecg_${userId}_${sessionId}.png';
      final String filePath = '${tempDir.path}/$fileName';

      final File imageFile = File(filePath);
      await imageFile.writeAsBytes(imageBytes);

      return imageFile;
    } catch (e) {
      print('Error capturing chart with size: $e');
      return null;
    }
  }

  /// Delete temporary image file
  Future<void> deleteTemporaryImage(File imageFile) async {
    try {
      if (await imageFile.exists()) {
        await imageFile.delete();
        print('Temporary image deleted: ${imageFile.path}');
      }
    } catch (e) {
      print('Error deleting temporary image: $e');
    }
  }

  /// Get estimated file size in KB
  Future<int> getImageSizeKB(File imageFile) async {
    try {
      final int bytes = await imageFile.length();
      return (bytes / 1024).round();
    } catch (e) {
      print('Error getting image size: $e');
      return 0;
    }
  }
}
