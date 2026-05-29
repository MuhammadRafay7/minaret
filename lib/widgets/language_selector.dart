import 'package:flutter/material.dart';
import 'package:minaret/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/language_provider.dart';
import '../core/theme.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<LanguageProvider>(context);
    final currentCode = provider.currentLocale.languageCode.toUpperCase();
    final supported = AppLocalizations.supportedLocales;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopupMenuButton<String>(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : MinaretTheme.surface,
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : MinaretTheme.dividerColor,
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.language_rounded,
              size: 16,
              color: MinaretTheme.gold.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Text(
              currentCode,
              style: GoogleFonts.montserrat(
                fontSize: 11,
                letterSpacing: 2,
                color: MinaretTheme.gold,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 17,
              color: isDark ? Colors.white38 : MinaretTheme.slate.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
      offset: const Offset(0, 44),
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      color: isDark ? const Color(0xFF1A1F26) : MinaretTheme.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      onSelected: (String code) => provider.setLocale(Locale(code)),
      itemBuilder: (context) => supported
          .map(
            (locale) => _buildMenuItem(
              context,
              locale.languageCode,
              _languageLabel(locale.languageCode),
              Icons.translate_rounded,
            ),
          )
          .toList(),
    );
  }

  String _languageLabel(String code) {
    switch (code) {
      case 'ar': return 'العربية';
      case 'ur': return 'اردو';
      case 'ru': return 'Русский';
      case 'nl': return 'Nederlands';
      case 'zh': return '中文';
      case 'fa': return 'فارسی';
      case 'id': return 'Bahasa Indonesia';
      case 'tr': return 'Türkçe';
      case 'ms': return 'Bahasa Melayu';
      case 'fr': return 'Français';
      case 'de': return 'Deutsch';
      case 'en':
      default: return 'English';
    }
  }

  PopupMenuItem<String> _buildMenuItem(
    BuildContext context,
    String value,
    String label,
    IconData icon,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopupMenuItem<String>(
      value: value,
      height: 56,
      child: Row(
        children: [
          Icon(icon, size: 13, color: MinaretTheme.gold.withValues(alpha: 0.6)),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white.withValues(alpha: 0.9) : MinaretTheme.onyx,
            ),
          ),
        ],
      ),
    );
  }
}
