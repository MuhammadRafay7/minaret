import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:minaret/core/constants/app_defaults.dart';
import 'package:minaret/core/theme.dart';
import 'package:minaret/core/theme_provider.dart';
import 'package:minaret/widgets/atelier_layout.dart';
import 'package:minaret/widgets/language_selector.dart';
import 'package:minaret/services/prayer_manager.dart';
import 'package:minaret/l10n/generated/app_localizations.dart';
import '../notifications/notifications_page.dart';
import '../prayer/prayer_stats_page.dart';
import '../legal/privacy_policy_page.dart';
import '../legal/terms_of_service_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _selectedMethod = kDefaultCalcMethod;
  String _selectedMadhab = kDefaultMadhab;
  
  bool _notifJanaza = true;
  bool _notifAdhan = true;
  bool _notifNamaz = true;
  bool _notifEid = true;
  bool _notifTaraweeh = true;
  bool _isLoadingPrefs = true;
  bool _isMosqueAdmin = false;
  int _unreadNotifications = 0;
  final Set<String> _savingKeys = {};

  @override
  void initState() {
    super.initState();
    _loadAllSettings();
  }

  Future<void> _loadAllSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;

    Map<String, dynamic> remotePrefs = {};
    bool isMosqueAdmin = false;
    int unreadNotifications = 0;
    
    if (user != null) {
      // Check if user is mosque admin
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      remotePrefs = userData?['notificationPrefs'] as Map<String, dynamic>? ?? {};
      
      // Check if user manages any mosques
      final mosquesQuery = await FirebaseFirestore.instance
          .collection('mosques')
          .where('adminUid', isEqualTo: user.uid)
          .limit(1)
          .get();
      isMosqueAdmin = mosquesQuery.docs.isNotEmpty;
      
      // Get unread notifications count
      if (isMosqueAdmin) {
        final notificationsQuery = await FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: user.uid)
            .where('read', isEqualTo: false)
            .get();
        unreadNotifications = notificationsQuery.docs.length;
      }
    }

    setState(() {
      _selectedMethod = prefs.getString('pref_calculation_method') ?? kDefaultCalcMethod;
      _selectedMadhab = prefs.getString('pref_madhab') ?? kDefaultMadhab;

      _notifJanaza = remotePrefs['janaza'] ?? true;
      _notifAdhan = remotePrefs['adhan'] ?? true;
      _notifNamaz = remotePrefs['namaz'] ?? true;
      _notifEid = remotePrefs['eid'] ?? true;
      _notifTaraweeh = remotePrefs['taraweeh'] ?? true;

      _isMosqueAdmin = isMosqueAdmin;
      _unreadNotifications = unreadNotifications;
      _isLoadingPrefs = false;
    });
  }

  Future<void> _updateNotification(String key, bool value) async {
    if (_savingKeys.contains(key)) return;
    final user = FirebaseAuth.instance.currentUser;

    final bool prevJanaza = _notifJanaza;
    final bool prevAdhan = _notifAdhan;
    final bool prevNamaz = _notifNamaz;
    final bool prevEid = _notifEid;
    final bool prevTaraweeh = _notifTaraweeh;

    setState(() {
      _savingKeys.add(key);
      if (key == 'janaza') _notifJanaza = value;
      if (key == 'adhan') _notifAdhan = value;
      if (key == 'namaz') _notifNamaz = value;
      if (key == 'eid') _notifEid = value;
      if (key == 'taraweeh') _notifTaraweeh = value;
    });

    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'notificationPrefs': {
            'janaza': _notifJanaza,
            'adhan': _notifAdhan,
            'namaz': _notifNamaz,
            'eid': _notifEid,
            'taraweeh': _notifTaraweeh,
          }
        }, SetOptions(merge: true));
      } catch (e) {
        if (mounted) {
          setState(() {
            _notifJanaza = prevJanaza;
            _notifAdhan = prevAdhan;
            _notifNamaz = prevNamaz;
            _notifEid = prevEid;
            _notifTaraweeh = prevTaraweeh;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.notifPrefUpdateFailed),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }

    if (mounted) setState(() => _savingKeys.remove(key));
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final l10n = AppLocalizations.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n?.deleteAccountLabel ?? 'Delete Account?'),
        content: Text(
          l10n?.deleteConfirmationPrompt ?? 'This action is permanent.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n?.cancelAction ?? 'CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n?.deleteAction ?? 'DELETE'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
      await user.delete();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.reAuthBeforeDelete)),
        );
      }
    }
  }

  String _displayText(BuildContext context, String value) {
    final code = Localizations.localeOf(context).languageCode;
    final rtl = code == 'ar' || code == 'ur';
    return rtl ? value : value.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: AtelierLayout(
        child: Column(
          children: [
            const SizedBox(height: 60),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                      color: isDark ? Colors.white : MinaretTheme.onyx, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _displayText(context, l10n?.settingsTitle ?? 'SETTINGS'),
                    style: MinaretTheme.heading.copyWith(fontSize: 22, letterSpacing: 4),
                  ),
                ],
              ),
            ),
            if (_isLoadingPrefs)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 30),
                  children: [
                    _sectionHeader(_displayText(context, l10n?.sectionAppearance ?? 'APPEARANCE')),
                    _buildSwitchTile(
                      l10n?.darkModeLabel ?? 'Dark Mode',
                      l10n?.darkModeSub ?? 'Use the aged dome aesthetic',
                      themeProvider.isDark,
                      (v) => themeProvider.toggleDark(v)
                    ),
                    
                    const SizedBox(height: 30),
                    _sectionHeader(_displayText(context, l10n?.sectionLanguage ?? 'LANGUAGE')),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: LanguageSelector(),
                    ),

                    if (user != null) ...[
                      const SizedBox(height: 30),
                      _sectionHeader(_displayText(context, l10n?.sectionNotifications ?? 'NOTIFICATIONS')),
                      if (_isMosqueAdmin) ...[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Stack(
                            children: [
                              Icon(Icons.notifications_outlined, color: MinaretTheme.gold),
                              if (_unreadNotifications > 0)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: Text(
                            'Mosque Notifications',
                            style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600, color: MinaretTheme.gold)
                          ),
                          subtitle: Text(
                            _unreadNotifications > 0 
                                ? '$_unreadNotifications unread alerts'
                                : 'View mosque alerts and reports',
                            style: GoogleFonts.lato(fontSize: 12, color: MinaretTheme.slate)
                          ),
                          trailing: Icon(Icons.arrow_forward_ios, size: 16, color: MinaretTheme.gold),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const NotificationsPage()),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                      // Prayer Stats for all users
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.analytics_outlined, color: MinaretTheme.gold),
                        title: Text(
                          l10n?.prayerStatisticsLabel ?? 'Prayer Statistics',
                          style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600, color: MinaretTheme.gold)
                        ),
                        subtitle: Text(
                          l10n?.prayerStatisticsSub ?? 'View your prayer history and analytics',
                          style: GoogleFonts.lato(fontSize: 12, color: MinaretTheme.slate)
                        ),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: MinaretTheme.gold),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PrayerStatsPage()),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildSwitchTile(
                        l10n?.notifAdhanLabel ?? 'Adhan Alerts',
                        l10n?.notifAdhanSub ?? 'Notification at exact prayer time',
                        _notifAdhan,
                        (v) => _updateNotification('adhan', v),
                        savingKey: 'adhan',
                      ),
                      _buildSwitchTile(
                        l10n?.notifPrayerLabel ?? 'Prayer Reminders',
                        l10n?.notifPrayerSub ?? '5 minutes before congregation',
                        _notifNamaz,
                        (v) => _updateNotification('namaz', v),
                        savingKey: 'namaz',
                      ),
                      _buildSwitchTile(
                        l10n?.notifJanazaLabel ?? 'Janaza Alerts',
                        l10n?.notifJanazaSub ?? 'Urgent local funeral notifications',
                        _notifJanaza,
                        (v) => _updateNotification('janaza', v),
                        savingKey: 'janaza',
                      ),
                      _buildSwitchTile(
                        l10n?.notifEidLabel ?? 'Eid & Taraweeh',
                        l10n?.notifEidSub ?? 'Special prayer announcements',
                        _notifEid,
                        (v) => _updateNotification('eid', v),
                        savingKey: 'eid',
                      ),
                    ],

                    const SizedBox(height: 30),
                    _sectionHeader(_displayText(context, l10n?.sectionPrayerCalc ?? 'PRAYER CALCULATION')),
                    _buildDropdownTile(
                      l10n?.calculationMethodLabel ?? 'Method',
                      _selectedMethod,
                      {
                        kCalcMethodKarachi:   'University of Islamic Sciences, Karachi',
                        kCalcMethodIsna:      'ISNA (North America)',
                        kCalcMethodMwl:       'Muslim World League',
                        kCalcMethodEgypt:     'Egyptian Authority',
                        kCalcMethodDubai:     'Dubai',
                        kCalcMethodQatar:     'Qatar',
                        kCalcMethodSingapore: 'Singapore',
                        kCalcMethodTehran:    'Tehran',
                        kCalcMethodTurkey:    'Turkey',
                      },
                      (val) {
                        if (val != null) {
                          setState(() => _selectedMethod = val);
                          PrayerManager.setMethod(val);
                        }
                      },
                    ),
                    _buildDropdownTile(
                      l10n?.madhabAsrLabel ?? 'Madhab (Asr)',
                      _selectedMadhab,
                      {
                        kMadhabHanafi: 'Hanafi (Later)',
                        kMadhabShafi:  'Shafi\'i / Maliki / Hanbali (Earlier)',
                      },
                      (val) {
                        if (val != null) {
                          setState(() => _selectedMadhab = val);
                          PrayerManager.setMadhab(val);
                        }
                      },
                    ),

                    if (user != null) ...[
                      const SizedBox(height: 30),
                      _sectionHeader(_displayText(context, l10n?.sectionDangerZone ?? 'DANGER ZONE')),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          l10n?.deleteAccountLabel ?? 'Delete Account',
                          style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.redAccent)
                        ),
                        subtitle: Text(
                          l10n?.deleteAccountSub ?? 'Permanently remove your identity and data',
                          style: GoogleFonts.lato(fontSize: 12, color: MinaretTheme.slate)
                        ),
                        onTap: _deleteAccount,
                      ),
                    ],

                    const SizedBox(height: 30),
                    _sectionHeader(_displayText(context, 'LEGAL')),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.privacy_tip_outlined, color: MinaretTheme.gold),
                      title: Text(
                        'Privacy Policy',
                        style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'How we handle your data',
                        style: GoogleFonts.lato(fontSize: 12, color: MinaretTheme.slate),
                      ),
                      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: MinaretTheme.gold),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.description_outlined, color: MinaretTheme.gold),
                      title: Text(
                        'Terms of Service',
                        style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Terms governing your use of Minaret',
                        style: GoogleFonts.lato(fontSize: 12, color: MinaretTheme.slate),
                      ),
                      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: MinaretTheme.gold),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TermsOfServicePage()),
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Text(title, style: MinaretTheme.detailHeader.copyWith(color: MinaretTheme.gold, fontSize: 9, letterSpacing: 2)),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged, {
    String? savingKey,
  }) {
    final isSaving = savingKey != null && _savingKeys.contains(savingKey);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: GoogleFonts.lato(fontSize: 12, color: MinaretTheme.slate)),
      trailing: isSaving
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Switch(value: value, onChanged: onChanged),
    );
  }

  Widget _buildDropdownTile(String title, String value, Map<String, String> items, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text(title, style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w500)),
        DropdownButton<String>(
          value: value,
          isExpanded: true,
          underline: Container(height: 1, color: MinaretTheme.dividerColor),
          items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: GoogleFonts.lato(fontSize: 13)))).toList(),
          onChanged: onChanged,
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}