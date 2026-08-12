import 'package:flutter_tts/flutter_tts.dart';

import '../i18n/app_localizations.dart';

class VoicePrompter {
  VoicePrompter({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  Future<void> speak(String text, AppLanguage language) async {
    final locale = switch (language) {
      AppLanguage.hindi => 'hi-IN',
      AppLanguage.marathi => 'mr-IN',
      AppLanguage.telugu => 'te-IN',
    };
    try {
      await _tts.setLanguage(locale);
      await _tts.setSpeechRate(0.42);
      await _tts.speak(text);
    } catch (_) {
      // Voice is an accessibility aid; visual controls remain authoritative.
    }
  }
}
