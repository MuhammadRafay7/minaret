import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:minaret/core/constants/app_defaults.dart';
import 'package:minaret/core/theme.dart';
import 'package:minaret/core/theme_provider.dart';
import 'package:minaret/widgets/atelier_layout.dart';
import 'package:minaret/services/prayer_manager.dart';
import 'package:minaret/services/notification_service.dart';
import 'package:minaret/l10n/generated/app_localizations.dart';
import '../notifications/notifications_page.dart';
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
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final userData = userDoc.data();
        remotePrefs = userData?['notificationPrefs'] as Map<String, dynamic>? ?? {};

        final mosquesQuery = await FirebaseFirestore.instance
            .collection('mosques')
            .where('adminUid', isEqualTo: user.uid)
            .limit(1)
            .get();
        isMosqueAdmin = mosquesQuery.docs.isNotEmpty;

        if (isMosqueAdmin) {
          final notificationsQuery = await FirebaseFirestore.instance
              .collection('notifications')
              .where('userId', isEqualTo: user.uid)
              .where('read', isEqualTo: false)
              .get();
          unreadNotifications = notificationsQuery.docs.length;
        }
      } catch (e) {
        debugPrint('SettingsPage remote load error: $e');
      }
    }

    if (!mounted) return;
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

  Future<void> _sendTestNotification() async {
    final status = await NotificationService.debugStatus();
    await NotificationService.sendTestNotification();
    if (!mounted) return;

    final bool osEnabled = status['osNotificationsEnabled'] == true;
    final String message = osEnabled
        ? 'Test sent — check your notification shade.'
        : 'Notifications are disabled for Minaret in system settings. '
            'Enable them to receive alerts.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: osEnabled ? null : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<String?> _showPasswordDialog() async {
    final ctrl = TextEditingController();
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n?.deleteAccountLabel ?? 'Delete Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n?.confirmWithPasswordPrompt ?? 'Enter your password to confirm deletion'),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n?.fieldPassword ?? 'Password',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n?.cancelAction ?? 'CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n?.deleteAction ?? 'DELETE'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  Future<bool> _reauthenticate(User user) async {
    final provider = user.providerData.isNotEmpty
        ? user.providerData.first.providerId
        : 'password';

    if (provider == 'google.com') {
      try {
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null || !mounted) return false;
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await user.reauthenticateWithCredential(credential);
        return true;
      } catch (_) {
        return false;
      }
    } else {
      final password = await _showPasswordDialog();
      if (password == null || password.isEmpty) return false;
      try {
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );
        await user.reauthenticateWithCredential(credential);
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  Future<void> _deleteAccount() async {
    var user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final l10n = AppLocalizations.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n?.deleteAccountLabel ?? 'Delete Account?'),
        content: Text(l10n?.deleteAccountSub ?? 'This action is permanent.'),
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

    if (confirm != true || !mounted) return;

    final uid = user.uid;

    Future<void> performDeletion(User u) async {
      await u.delete();
      // Firestore cleanup after auth deletion succeeds
      await FirebaseFirestore.instance.collection('users').doc(uid).delete().catchError((_) {});
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    }

    try {
      await performDeletion(user);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        if (!mounted) return;
        final reauthed = await _reauthenticate(user);
        if (!mounted) return;
        if (!reauthed) {
          _showError(l10n?.reAuthFailedMessage ?? 'Re-authentication failed. Please try again.');
          return;
        }
        final freshUser = FirebaseAuth.instance.currentUser;
        if (freshUser == null) return;
        try {
          await performDeletion(freshUser);
        } catch (_) {
          if (mounted) _showError(l10n?.reAuthBeforeDelete ?? 'Failed to delete account.');
        }
      } else {
        _showError(e.message ?? l10n?.reAuthBeforeDelete ?? 'Failed to delete account.');
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
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                children: [
                  _backButton(isDark),
                  const SizedBox(width: 12),
                  Text(
                    _displayText(context, l10n?.settingsTitle ?? 'SETTINGS'),
                    style: MinaretTheme.heading.copyWith(fontSize: 22, letterSpacing: 4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoadingPrefs)
              const Expanded(child: Center(child: CircularProgressIndicator(color: MinaretTheme.gold)))
            else
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 40),
                  children: [
                    // ── APPEARANCE ──
                    _sectionHeader(_displayText(context, l10n?.sectionAppearance ?? 'APPEARANCE')),
                    _card([
                      _buildSwitchTile(
                        Icons.dark_mode_outlined,
                        l10n?.darkModeLabel ?? 'Dark Mode',
                        l10n?.darkModeSub ?? 'Use the aged dome aesthetic',
                        themeProvider.isDark,
                        (v) => themeProvider.toggleDark(v),
                      ),
                    ]),
                    const SizedBox(height: 26),

                    // ── NOTIFICATIONS ──
                    if (user != null) ...[
                      _sectionHeader(_displayText(context, l10n?.sectionNotifications ?? 'NOTIFICATIONS')),
                      _card([
                        if (_isMosqueAdmin)
                          _navTile(
                            icon: Icons.notifications_outlined,
                            title: l10n?.mosqueNotificationsLabel ?? 'Mosque Notifications',
                            subtitle: _unreadNotifications > 0
                                ? '$_unreadNotifications unread alerts'
                                : 'View mosque alerts and reports',
                            badge: _unreadNotifications > 0,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const NotificationsPage()),
                            ),
                          ),
                        _buildSwitchTile(
                          Icons.volume_up_outlined,
                          l10n?.notifAdhanLabel ?? 'Adhan Alerts',
                          l10n?.notifAdhanSub ?? 'Notification at exact prayer time',
                          _notifAdhan,
                          (v) => _updateNotification('adhan', v),
                          savingKey: 'adhan',
                        ),
                        _buildSwitchTile(
                          Icons.access_time_rounded,
                          l10n?.notifPrayerLabel ?? 'Prayer Reminders',
                          l10n?.notifPrayerSub ?? '5 minutes before congregation',
                          _notifNamaz,
                          (v) => _updateNotification('namaz', v),
                          savingKey: 'namaz',
                        ),
                        _buildSwitchTile(
                          Icons.favorite_outline_rounded,
                          l10n?.notifJanazaLabel ?? 'Janaza Alerts',
                          l10n?.notifJanazaSub ?? 'Urgent local funeral notifications',
                          _notifJanaza,
                          (v) => _updateNotification('janaza', v),
                          savingKey: 'janaza',
                        ),
                        _buildSwitchTile(
                          Icons.celebration_outlined,
                          l10n?.notifEidLabel ?? 'Eid & Taraweeh',
                          l10n?.notifEidSub ?? 'Special prayer announcements',
                          _notifEid,
                          (v) => _updateNotification('eid', v),
                          savingKey: 'eid',
                        ),
                        _navTile(
                          icon: Icons.notifications_active_outlined,
                          title: 'Send Test Notification',
                          subtitle:
                              'Tap to confirm notifications work on this device',
                          onTap: _sendTestNotification,
                        ),
                      ]),
                      const SizedBox(height: 26),
                    ],

                    // ── PRAYER CALCULATION ──
                    _sectionHeader(_displayText(context, l10n?.sectionPrayerCalc ?? 'PRAYER CALCULATION')),
                    _card([
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
                    ]),
                    const SizedBox(height: 26),

                    // ── LEGAL ──
                    _sectionHeader(_displayText(context, 'LEGAL')),
                    _card([
                      _navTile(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacy Policy',
                        subtitle: 'How we handle your data',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
                        ),
                      ),
                      _navTile(
                        icon: Icons.description_outlined,
                        title: 'Terms of Service',
                        subtitle: 'Terms governing your use of Minaret',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const TermsOfServicePage()),
                        ),
                      ),
                    ]),

                    // ── Sign Out + Delete ──
                    if (user != null) ...[
                      const SizedBox(height: 32),
                      _signOutButton(isDark),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: _deleteAccount,
                          child: Text(
                            l10n?.deleteAccountLabel ?? 'Delete Account',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.redAccent.withValues(alpha: 0.8),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── UI helpers ──────────────────────────────────────────────────────────────

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _cardColor => _isDark ? const Color(0xFF1C2430) : Colors.white;
  Color get _textPrimary => _isDark ? Colors.white : MinaretTheme.onyx;

  Widget _backButton(bool isDark) {
    return Material(
      color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => Navigator.pop(context),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : MinaretTheme.onyx, size: 18),
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) {
    final withDividers = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      withDividers.add(children[i]);
      if (i < children.length - 1) {
        withDividers.add(Divider(
          height: 1,
          thickness: 0.5,
          indent: 54,
          color: _isDark ? Colors.white12 : MinaretTheme.dividerColor,
        ));
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: MinaretTheme.cardShadow,
      ),
      child: Column(children: withDividers),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title,
        style: GoogleFonts.montserrat(
          color: MinaretTheme.gold,
          fontSize: 10,
          letterSpacing: 2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _navTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool badge = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: MinaretTheme.gold, size: 22),
                if (badge)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.montserrat(
                          fontSize: 14, fontWeight: FontWeight.w600, color: _textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: GoogleFonts.lato(fontSize: 12, color: MinaretTheme.slate)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: _isDark ? Colors.white38 : MinaretTheme.slate),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged, {
    String? savingKey,
  }) {
    final isSaving = savingKey != null && _savingKeys.contains(savingKey);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: MinaretTheme.gold, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.montserrat(
                        fontSize: 14, fontWeight: FontWeight.w600, color: _textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: GoogleFonts.lato(fontSize: 12, color: MinaretTheme.slate)),
              ],
            ),
          ),
          isSaving
              ? const SizedBox(
                  width: 24, height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: MinaretTheme.gold),
                )
              : Switch.adaptive(
                  value: value,
                  onChanged: onChanged,
                  activeThumbColor: MinaretTheme.gold,
                ),
        ],
      ),
    );
  }

  Widget _buildDropdownTile(String title, String value, Map<String, String> items, Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.montserrat(
                  fontSize: 13, fontWeight: FontWeight.w600, color: _textPrimary)),
          const SizedBox(height: 4),
          DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: Container(height: 1, color: MinaretTheme.dividerColor),
            style: GoogleFonts.lato(fontSize: 13, color: _textPrimary),
            dropdownColor: _cardColor,
            items: items.entries
                .map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value, style: GoogleFonts.lato(fontSize: 13, color: _textPrimary))))
                .toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _signOutButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          await FirebaseAuth.instance.signOut();
          if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
        },
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: Text(
          AppLocalizations.of(context)?.signOutLabel ?? 'Sign Out',
          style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: MinaretTheme.gold,
          side: BorderSide(color: MinaretTheme.gold.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}