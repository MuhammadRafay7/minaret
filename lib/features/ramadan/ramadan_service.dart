import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adhan/adhan.dart';

import '../../core/location_service.dart';
import '../../repositories/mosque_repository.dart';
import '../../services/prayer_manager.dart';
import '../../services/system_config_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RamadanService
//
// Single source of truth for "is it Ramadan, and where are we in it?".
// Resolution order (most authoritative first):
//   1. Followed / nearest mosque `isRamadan` flag + optional ramadanStart/End
//      (chosen approach: a mosque in Pakistan announces Pakistan's dates, a
//      mosque in Saudi announces Saudi's — automatically correct per country).
//   2. The Hijri calendar (works offline, everywhere) — month 9 == Ramadan.
//   3. A user ±day adjustment to reconcile the local moon sighting with the
//      calculated calendar (e.g. mosque started a day early/late).
//
// Drives: the home dashboard card, the Ramadan theme, and notification windows.
// ─────────────────────────────────────────────────────────────────────────────

enum RamadanPhase {
  /// Far from Ramadan — nothing shows, no theme change.
  dormant,

  /// ~10 days before — a slim "Ramadan begins in X days" teaser shows.
  teaser,

  /// Ramadan is live — full dashboard + Ramadan theme + notifications armed.
  active,

  /// Eid al-Fitr (1–3 Shawwal) — dashboard swaps to "Eid Mubarak".
  eid,
}

class RamadanService extends ChangeNotifier {
  RamadanService();

  // ── Tunable prefs ──────────────────────────────────────────────────────────
  static const _adjustmentKey = 'ramadan_day_adjustment';
  static const _imsakBufferKey = 'ramadan_imsak_buffer_min';
  static const _themeEnabledKey = 'ramadan_theme_enabled';
  static const _teaserWindowDays = 10;
  static const _eidWindowDays = 3;

  final PrayerManager _prayerManager = PrayerManager();
  final MosqueRepository _mosqueRepo = MosqueRepository();

  // ── Resolved state ───────────────────────────────────────────────────────────
  RamadanPhase _phase = RamadanPhase.dormant;
  int _dayOfRamadan = 0; // 1..30 when active
  int _totalDays = 30; // 29 or 30
  int? _daysUntilRamadan; // for the teaser
  int? _daysUntilEid; // for the active-phase Eid countdown
  bool _initialised = false;

  // Live daily times (null when no location yet).
  DateTime? _fajr; // == suhoor end
  DateTime? _maghrib; // == iftar
  DateTime? _imsak; // == fajr - buffer

  // User-tunable.
  int _adjustmentDays = 0;
  int _imsakBufferMin = 10;
  bool _themeEnabled = true;

  GlobalSettings? _globalSettings;
  // Admin override from app_settings/global → ramadan (auto/on/off + dates).
  RamadanConfig _adminRamadan = const RamadanConfig();
  StreamSubscription<GlobalSettings>? _globalSub;

  // ── Public getters ───────────────────────────────────────────────────────────
  RamadanPhase get phase => _phase;
  bool get isActive => _phase == RamadanPhase.active;
  bool get isEid => _phase == RamadanPhase.eid;
  bool get isTeaser => _phase == RamadanPhase.teaser;
  bool get isInitialised => _initialised;

  /// The Ramadan theme should apply only while Ramadan is live AND the user
  /// hasn't switched the special look off.
  bool get themeActive => _phase == RamadanPhase.active && _themeEnabled;
  bool get themeEnabled => _themeEnabled;

  int get dayOfRamadan => _dayOfRamadan;
  int get totalDays => _totalDays;
  int? get daysUntilRamadan => _daysUntilRamadan;
  int? get daysUntilEid => _daysUntilEid;

  DateTime? get suhoorEnd => _fajr;
  DateTime? get iftarTime => _maghrib;
  DateTime? get imsakTime => _imsak;
  bool get hasTimes => _fajr != null && _maghrib != null;

  int get adjustmentDays => _adjustmentDays;
  int get imsakBufferMin => _imsakBufferMin;

  /// The current Hijri date, with the user's ±day adjustment applied.
  HijriCalendar get adjustedHijri =>
      HijriCalendar.fromDate(DateTime.now().add(Duration(days: _adjustmentDays)));

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  /// Resolve everything. Safe to call repeatedly (e.g. on app resume).
  /// Fire-and-forget from a provider `create:` — listeners are notified when done.
  Future<void> init({GlobalSettings? globalSettings}) async {
    if (globalSettings != null) {
      _globalSettings = globalSettings;
      _adminRamadan = globalSettings.ramadan;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      _adjustmentDays = prefs.getInt(_adjustmentKey) ?? 0;
      _imsakBufferMin = prefs.getInt(_imsakBufferKey) ?? 10;
      _themeEnabled = prefs.getBool(_themeEnabledKey) ?? true;

      // Live-listen to the admin Ramadan switch so toggling it in the panel
      // flips the app without a restart (also drives easy testing).
      _globalSub ??= SystemConfigService.globalSettingsStream().listen(
        (gs) {
          _globalSettings = gs;
          _adminRamadan = gs.ramadan;
          _resolvePhase().then((_) => notifyListeners());
        },
        onError: (e) => debugPrint('⚠️ Ramadan global settings stream error: $e'),
      );

      await _resolvePhase();
      await _loadTimes();
    } catch (e) {
      debugPrint('🔴 RamadanService.init failed: $e');
    } finally {
      _initialised = true;
      notifyListeners();
    }
  }

  Future<void> refresh() => init();

  @override
  void dispose() {
    _globalSub?.cancel();
    super.dispose();
  }

  // ── Phase resolution ───────────────────────────────────────────────────────────

  Future<void> _resolvePhase() async {
    final h = adjustedHijri;
    final now = DateTime.now();

    // 0. Admin override (top priority — drives the panel toggle & testing).
    if (_adminRamadan.forcedOff) {
      _phase = RamadanPhase.dormant;
      _dayOfRamadan = 0;
      _daysUntilRamadan = null;
      _daysUntilEid = null;
      return;
    }

    // 1. Mosque override (chosen source of truth). Best-effort: silently falls
    //    back to the calendar when offline or no mosque is followed.
    final mosque = await _resolveAuthoritativeMosque();
    final bool? mosqueRamadan = mosque?.raw['isRamadan'] as bool?;

    // 2. Calendar baseline.
    final bool calendarRamadan = h.hMonth == 9;
    final bool calendarEid = h.hMonth == 10 && h.hDay <= _eidWindowDays;

    final bool active = _adminRamadan.forcedOn || (mosqueRamadan ?? calendarRamadan);

    if (active) {
      _phase = RamadanPhase.active;
      _totalDays = h.lengthOfMonth;
      _dayOfRamadan = _resolveDayNumber(mosque, h, now);
      _daysUntilEid = _adminRamadan.eidDate != null
          ? _dateOnly(_adminRamadan.eidDate!).difference(_dateOnly(now)).inDays
          : _daysUntil(h.hYear, 10, 1, now);
      _daysUntilRamadan = null;
      return;
    }

    if (calendarEid) {
      _phase = RamadanPhase.eid;
      _dayOfRamadan = 0;
      _daysUntilEid = 0;
      _daysUntilRamadan = null;
      return;
    }

    // Pre-Ramadan teaser window.
    final until = _daysUntil(_nextRamadanYear(h, now), 9, 1, now);
    if (until != null && until > 0 && until <= _teaserWindowDays) {
      _phase = RamadanPhase.teaser;
      _daysUntilRamadan = until;
      _dayOfRamadan = 0;
      _daysUntilEid = null;
      return;
    }

    _phase = RamadanPhase.dormant;
    _daysUntilRamadan = until;
    _dayOfRamadan = 0;
    _daysUntilEid = null;
  }

  /// If the mosque admin set an explicit `ramadanStart` date, count from it so
  /// the day number matches the local announcement exactly; otherwise use the
  /// (adjusted) Hijri day-of-month.
  int _resolveDayNumber(Mosque? mosque, HijriCalendar h, DateTime now) {
    // Admin-set start wins, then the mosque's published start, then the Hijri day.
    final start = _adminRamadan.startDate ?? _parseDate(mosque?.raw['ramadanStart']);
    if (start != null) {
      final days = _dateOnly(now).difference(_dateOnly(start)).inDays + 1;
      if (days >= 1 && days <= 30) return days;
    }
    // Forced on outside the real month (testing) with no start date → day 1.
    if (h.hMonth != 9 && _adminRamadan.forcedOn) return 1;
    return h.hDay;
  }

  /// Followed mosque takes priority; falls back to the nearest mosque to the
  /// user's location so users who follow none still get correct, local dates.
  Future<Mosque?> _resolveAuthoritativeMosque() async {
    try {
      final followed = await _mosqueRepo.followedMosqueIds().first;
      if (followed.isNotEmpty) {
        final m = await _mosqueRepo.getMosqueStream(followed.first).first;
        if (m != null) return m;
      }
    } catch (_) {/* offline / unauthenticated — fall through */}

    try {
      final pos = await LocationService.getCurrentLocation();
      if (pos != null) {
        final nearby =
            await _mosqueRepo.searchNearby(pos.latitude, pos.longitude, 0.5);
        if (nearby.isNotEmpty) return nearby.first;
      }
    } catch (_) {/* no location — fall through to calendar */}

    return null;
  }

  // ── Times ────────────────────────────────────────────────────────────────────

  Future<void> _loadTimes() async {
    try {
      final pos = await LocationService.getCurrentLocation();
      if (pos == null) {
        _fajr = _maghrib = _imsak = null;
        return;
      }
      final PrayerTimes t = await _prayerManager.getTodayTimes(
        pos.latitude,
        pos.longitude,
        globalSettings: _globalSettings,
      );
      _fajr = t.fajr;
      _maghrib = t.maghrib;
      _imsak = t.fajr.subtract(Duration(minutes: _imsakBufferMin));
    } catch (e) {
      debugPrint('🔴 RamadanService._loadTimes failed: $e');
      _fajr = _maghrib = _imsak = null;
    }
  }

  // ── User adjustments ───────────────────────────────────────────────────────────

  Future<void> setAdjustment(int days) async {
    final clamped = days.clamp(-2, 2);
    if (clamped == _adjustmentDays) return;
    _adjustmentDays = clamped;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_adjustmentKey, _adjustmentDays);
    await _resolvePhase();
    notifyListeners();
  }

  Future<void> setImsakBuffer(int minutes) async {
    final clamped = minutes.clamp(0, 30);
    if (clamped == _imsakBufferMin) return;
    _imsakBufferMin = clamped;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_imsakBufferKey, _imsakBufferMin);
    if (_fajr != null) {
      _imsak = _fajr!.subtract(Duration(minutes: _imsakBufferMin));
    }
    notifyListeners();
  }

  Future<void> setThemeEnabled(bool enabled) async {
    if (enabled == _themeEnabled) return;
    _themeEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeEnabledKey, enabled);
    notifyListeners();
  }

  // ── Date helpers ───────────────────────────────────────────────────────────────

  /// Whole days from `now` until the Gregorian date of the given Hijri date,
  /// or null if the conversion fails. Negative if already past.
  int? _daysUntil(int hYear, int hMonth, int hDay, DateTime now) {
    try {
      final greg = HijriCalendar().hijriToGregorian(hYear, hMonth, hDay);
      return _dateOnly(greg).difference(_dateOnly(now)).inDays;
    } catch (_) {
      return null;
    }
  }

  /// The Hijri year whose Ramadan is still ahead of (or includes) today.
  int _nextRamadanYear(HijriCalendar h, DateTime now) {
    // If this year's Ramadan already passed, look to next year.
    final thisYear = _daysUntil(h.hYear, 9, 1, now);
    if (thisYear != null && thisYear < 0) return h.hYear + 1;
    return h.hYear;
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String && raw.trim().isNotEmpty) {
      return DateTime.tryParse(raw.trim());
    }
    // Firestore Timestamp exposes toDate() — accessed dynamically to avoid a
    // hard dependency here.
    try {
      final d = (raw as dynamic).toDate();
      if (d is DateTime) return d;
    } catch (_) {}
    return null;
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
