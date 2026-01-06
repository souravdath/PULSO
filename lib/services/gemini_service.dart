import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/session_context.dart';
import '../models/ecg_summary.dart';

import 'dart:io';

class GeminiService {
  // TODO: Replace with your actual key or use --dart-define=GEMINI_API_KEY=...
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: ''); 

  late final GenerativeModel _model;

  GeminiService() {
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _apiKey,
    );
  }

  Future<String> generateConsultation(
    SessionContext context,
    EcgSummary summary, {
    File? chartImage,
  }) async {
    if (_apiKey.isEmpty) {
      return "Error: Gemini API Key is missing. Please provide it via --dart-define=GEMINI_API_KEY=YOUR_KEY or hardcode it in gemini_service.dart.";
    }

    final promptText = _buildPrompt(context, summary);
    final contentParts = [Content.text(promptText)];

    if (chartImage != null) {
      try {
        final imageBytes = await chartImage.readAsBytes();
        contentParts.add(Content.data('image/png', imageBytes));
      } catch (e) {
        print("Error reading chart image: $e");
      }
    }
    
    try {
      final response = await _model.generateContent([
        Content.multi(contentParts.map((e) {
          if (e.parts.first is TextPart) return TextPart((e.parts.first as TextPart).text);
          if (e.parts.first is DataPart) return DataPart((e.parts.first as DataPart).mimeType, (e.parts.first as DataPart).bytes);
          return TextPart(''); // Fallback
        }).toList())
      ]);
      return response.text ?? "Unable to generate insights at this time.";
    } catch (e) {
      return "Error generating insights: $e";
    }
  }

  String _buildPrompt(SessionContext context, EcgSummary summary) {
    return '''
You are an expert cardiologist AI assistant named "Pulso AI".
Analyze the following ECG session data, user context, and the attached ECG chart image (if available) to provide a brief, professional, and empathetic consultation report.

USER CONTEXT:
- Time of Day: ${context.timeOfDay}
- Activity Level: ${context.activityLevel.toString().split('.').last}
- Stress Level (1-5): ${context.stressScore}
- Recent Stimulants: ${context.stimulants ? "Yes" : "No"}
- Recent Nicotine: ${context.nicotine ? "Yes" : "No"}

ECG SESSION METRICS:
- Average Heart Rate: ${summary.averageHeartRate.toStringAsFixed(1)} BPM
- Total Beats (R-Peaks): ${summary.totalRPeaks}
- Duration: ${summary.durationSeconds} seconds

INSTRUCTIONS:
1. Provide a "Heart Rate Analysis": Is the HR normal for the given context?
2. If the ECG chart image is provided, analyze the waveform for visible regularity or irregularity (rhythm analysis). Mention if you see clear R-peaks.
3. Provide a "Stress & Lifestyle Impact" section.
4. Provide "Recommendations": 1-2 actionable tips.
5. Disclaimer: You are an AI, not a doctor. Suggest professional help for abnormalities.
6. Return response in Markdown.
''';
  }
}
