import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/logbook_entry.dart';

/// Response from Gemini AI
class GeminiResponse {
  final bool success;
  final String message;
  final String? error;

  GeminiResponse({
    required this.success,
    required this.message,
    this.error,
  });
}

/// Service for interacting with Google Gemini AI
class GeminiService {
  GenerativeModel? _model;
  String? _apiKey;
  
  /// Initialize the Gemini model
  void init() {
    _apiKey = dotenv.env['GEMINI_API_KEY'];
    
    if (_apiKey == null || _apiKey!.isEmpty || _apiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      print('WARNING: Gemini API key not configured! Add it to .env file.');
      return;
    }
    
    
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey!,
    );
  }
  
  /// Check if the service is configured
  bool get isConfigured => _model != null && _apiKey != null && _apiKey != 'YOUR_GEMINI_API_KEY_HERE';
  
  /// Generate flight advice based on a flight entry
  Future<GeminiResponse> generateFlightAdvice(LogbookEntry entry) async {
    if (!isConfigured) {
      return GeminiResponse(
        success: false,
        message: 'AI service not configured. Please add your Gemini API key.',
        error: 'No API key',
      );
    }
    
    try {
      final prompt = '''
You are Captain MAVE ✈️, a flight instructor AI. Be BRIEF and use emojis.

Flight: ${entry.depIcao} → ${entry.arrIcao} | ${entry.aircraftReg}
Date: ${entry.date.toString().split(' ')[0]} | ${entry.totalHours.toStringAsFixed(1)}h
Type: ${entry.flightType.join(', ')}
PIC: ${entry.picHours.toStringAsFixed(1)}h | Night: ${entry.nightHours.toStringAsFixed(1)}h | XC: ${entry.xcHours.toStringAsFixed(1)}h
Remarks: ${entry.remarks ?? 'None'}

Respond with EXACTLY 3 short bullet points (max 80 words total):
• 🎯 Quick observation (one line)
• ⚠️ Safety tip (one line)
• 💡 Improvement tip (one line)

Be encouraging! Use emojis. NO long paragraphs.
''';

      final content = [Content.text(prompt)];
      final response = await _model!.generateContent(content);
      
      return GeminiResponse(
        success: true,
        message: response.text ?? 'No response generated.',
      );
    } catch (e) {
      print('Gemini error: $e');
      return GeminiResponse(
        success: false,
        message: 'Failed to generate advice. Please try again.',
        error: e.toString(),
      );
    }
  }
  
  /// Ask Captain MAVE a general aviation question
  Future<GeminiResponse> askCaptainMave(String question, {LogbookEntry? contextFlight}) async {
    if (!isConfigured) {
      return GeminiResponse(
        success: false,
        message: 'AI service not configured. Please add your Gemini API key.',
        error: 'No API key',
      );
    }
    
    try {
      String contextInfo = '';
      if (contextFlight != null) {
        contextInfo = '''

**Context - Current Flight:**
- Route: ${contextFlight.depIcao} → ${contextFlight.arrIcao}
- Aircraft: ${contextFlight.aircraftReg}
- Flight Type: ${contextFlight.flightType.join(', ')}
- Total Time: ${contextFlight.totalHours.toStringAsFixed(1)} hours
''';
      }
      
      final prompt = '''
You are Captain MAVE ✈️, a flight instructor AI. Be BRIEF, use emojis.
$contextInfo
Question: $question

Rules:
• Answer in MAX 100 words
• Use bullet points for lists
• Add relevant emojis (✈️🛫🎯⚠️💡✅)
• Be direct and clear
• If about regulations, add: "📋 Regulations vary by country"

No long paragraphs. Be helpful and friendly!
''';

      final content = [Content.text(prompt)];
      final response = await _model!.generateContent(content);
      
      return GeminiResponse(
        success: true,
        message: response.text ?? 'No response generated.',
      );
    } catch (e) {
      print('Gemini error: $e');
      return GeminiResponse(
        success: false,
        message: 'Failed to get response. Please try again.',
        error: e.toString(),
      );
    }
  }
}
