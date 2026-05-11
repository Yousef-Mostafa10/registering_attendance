import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// LocaleProvider manages the app's current locale and persists the user's choice
class LocaleProvider extends ChangeNotifier {
  static const String _localeKey = 'app_locale';
  static const Set<String> _supportedLocales = {'en', 'ar'};
  
  Locale _locale = const Locale('ar');
  
  Locale get locale => _locale;
  
  bool get isArabic => _locale.languageCode == 'ar';
  bool get isEnglish => _locale.languageCode == 'en';
  
  /// Initialize the locale from saved preferences
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLocale = prefs.getString(_localeKey);
    
    if (savedLocale != null && _supportedLocales.contains(savedLocale)) {
      _locale = Locale(savedLocale);
    } else {
      // Default to Arabic if nothing is saved
      _locale = const Locale('ar');
    }
    
    notifyListeners();
  }
  
  /// Toggle between English and Arabic
  Future<void> toggleLocale() async {
    final newLocaleCode = isEnglish ? 'ar' : 'en';
    await setLocale(newLocaleCode);
  }
  
  /// Set locale to a specific language
  Future<void> setLocale(String languageCode) async {
    if (!_supportedLocales.contains(languageCode)) {
      return; // Only allow 'en' and 'ar'
    }
    
    _locale = Locale(languageCode);
    
    // Persist the choice
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, languageCode);
    
    notifyListeners();
  }
  
  /// Get the current language display name
  String get currentLanguageName => isArabic ? 'العربية' : 'English';
  
  /// Get current language code for display (EN, AR)
  String get languageCode => isArabic ? 'AR' : 'EN';
}
