import 'package:flutter/material.dart';
import '../core/providers/locale_provider.dart';
import '../l10n/app_localizations.dart';
import '../main.dart' as app_main;

/// LanguageToggleButton is a reusable widget that shows the current language
/// and allows users to toggle between English and Arabic
class LanguageToggleButton extends StatefulWidget {
  /// Optional callback when locale changes
  final VoidCallback? onLocaleChanged;
  
  const LanguageToggleButton({
    Key? key,
    this.onLocaleChanged,
  }) : super(key: key);

  @override
  State<LanguageToggleButton> createState() => _LanguageToggleButtonState();
}

class _LanguageToggleButtonState extends State<LanguageToggleButton> {
  Future<void> _toggleLanguage() async {
    // Toggle the locale using the global provider
    await app_main.localeProvider.toggleLocale();
    
    // Call the optional callback
    widget.onLocaleChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    if (l10n == null) return const SizedBox.shrink();

    return Tooltip(
      message: l10n.language,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _toggleLanguage,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  app_main.localeProvider.isArabic
                      ? Icons.translate
                      : Icons.language,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  app_main.localeProvider.languageCode,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
