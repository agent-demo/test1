import 'package:flutter/material.dart';

enum AppLanguage { hindi, marathi, telugu }

class AppCopy {
  const AppCopy({required this.language});

  final AppLanguage language;

  String get appName => _value('Crop Saathi', 'क्रॉप साथी', 'క్రాప్ సాథి');
  String get offlineReady => _value('Offline mode ready', 'ऑफलाइन मोड तैयार है',
      'ఆఫ్‌లైన్ మోడ్ సిద్ధంగా ఉంది');
  String get scanCrop =>
      _value('Scan a crop', 'फसल स्कैन करें', 'పంటను స్కాన్ చేయండి');
  String get history =>
      _value('My crop history', 'मेरी फसल का इतिहास', 'నా పంట చరిత్ర');
  String get prices => _value('Market prices', 'मंडी भाव', 'మార్కెట్ ధరలు');
  String get chooseCrop =>
      _value('Choose the crop', 'फसल चुनें', 'పంటను ఎంచుకోండి');
  String get takePhoto => _value('Take a photo', 'फोटो लें', 'ఫోటో తీయండి');
  String get symptoms =>
      _value('Describe symptoms', 'लक्षण बताएं', 'లక్షణాలు చెప్పండి');
  String get screen =>
      _value('Screen crop', 'फसल की जांच करें', 'పంటను పరీక్షించండి');
  String get needsReview =>
      _value('Needs review', 'जांच जरूरी है', 'సమీక్ష అవసరం');
  String get saveOffline => _value(
      'Save offline and send for review',
      'ऑफलाइन सेव करके जांच के लिए भेजें',
      'ఆఫ్‌లైన్‌లో సేవ్ చేసి సమీక్షకు పంపండి');
  String get languageLabel => _value('Language', 'भाषा', 'భాష');

  String _value(String english, String hindi, String telugu) {
    switch (language) {
      case AppLanguage.hindi:
        return hindi;
      case AppLanguage.marathi:
        return english; // Marathi pack is a safe fallback until reviewed translations are supplied.
      case AppLanguage.telugu:
        return telugu;
    }
  }
}

class AppLanguageController extends ChangeNotifier {
  AppLanguage _language = AppLanguage.hindi;

  AppLanguage get language => _language;
  AppCopy get copy => AppCopy(language: _language);

  void setLanguage(AppLanguage language) {
    if (_language == language) return;
    _language = language;
    notifyListeners();
  }
}
