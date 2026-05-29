import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/constants/app_defaults.dart';
import '../../../core/dependency_injection.dart';
import '../../../core/locale_format.dart';
import '../../../core/location_service.dart';
import '../../../repositories/user_repository.dart';
import '../../../services/enhanced_prayer_tracker_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SortType — moved here from home_page.dart so the notifier owns sort state
// ─────────────────────────────────────────────────────────────────────────────

enum SortType { proximity, time, following }

const int _mosqueQueryLimit = 10;

// ─────────────────────────────────────────────────────────────────────────────
// HomeNotifier
// ─────────────────────────────────────────────────────────────────────────────

class HomeNotifier extends ChangeNotifier {
  // ── Auth / user ───────────────────────────────────────────────────────────
  User? _user;
  String _role = kDefaultRole;
  List<String> _following = [];
  bool _isImam = false;
  UserPrayerStats? _prayerStats;

  // ── Location ──────────────────────────────────────────────────────────────
  Position? _position;
  String? _manualCityName;

  // ── Mosques ───────────────────────────────────────────────────────────────
  List<QueryDocumentSnapshot> _rawMosques = [];
  bool _isLoadingMosques = true;
  bool _hasError = false;

  // ── Filters ───────────────────────────────────────────────────────────────
  SortType _activeSort = SortType.proximity;
  double _selectedRadiusKm = 3.0;
  String? _selectedFiqh;
  String _searchQuery = '';

  // ── Subscriptions ─────────────────────────────────────────────────────────
  StreamSubscription<User?>? _authSub;
  StreamSubscription<UserProfile?>? _userSub;
  StreamSubscription<Position>? _locationSub;
  StreamSubscription<QuerySnapshot>? _mosquesSub;
  Timer? _searchDebounceTimer;
  // Minimal periodic tick so time-sorted list stays accurate without GPS updates.
  Timer? _sortRefreshTimer;

  String? _activeStreamKey;

  static const int _maxSearchesPerMinute = 30;
  final List<DateTime> _searchTimestamps = [];

  HomeNotifier() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
    _initLocation();
    _sortRefreshTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) {
        if (_activeSort == SortType.time) notifyListeners();
      },
    );
  }

  // ── Getters ───────────────────────────────────────────────────────────────

  User? get user => _user;
  String get role => _role;
  List<String> get following => _following;
  bool get isImam => _isImam;
  UserPrayerStats? get prayerStats => _prayerStats;
  Position? get position => _position;
  String? get manualCityName => _manualCityName;
  bool get isLoadingMosques => _isLoadingMosques;
  bool get hasError => _hasError;
  SortType get activeSort => _activeSort;
  double get selectedRadiusKm => _selectedRadiusKm;
  String? get selectedFiqh => _selectedFiqh;
  String get searchQuery => _searchQuery;
  bool get hasActiveFilters => _selectedRadiusKm != 3 || _selectedFiqh != null;

  List<QueryDocumentSnapshot> get filteredMosques {
    var docs = _rawMosques.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final isOwner = _user?.uid == data['adminUid'];
      final matchesSearch = (data['name'] ?? '')
          .toString()
          .toLowerCase()
          .contains(_searchQuery);
      if (isOwner) return matchesSearch;
      return matchesSearch && (_isImam || data['restricted'] != true);
    }).toList();

    if (_activeSort == SortType.proximity || _activeSort == SortType.time) {
      docs = docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        if (_user?.uid == data['adminUid']) return true;
        return _distanceKm(data) <= _selectedRadiusKm;
      }).toList();
    }

    if (_activeSort == SortType.following) {
      docs = docs.where((doc) => _following.contains(doc.id)).toList();
    }

    docs.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;

      if (_user != null) {
        final isAOwner = aData['adminUid'] == _user!.uid;
        final isBOwner = bData['adminUid'] == _user!.uid;
        if (isAOwner && !isBOwner) return -1;
        if (!isAOwner && isBOwner) return 1;
      }

      return switch (_activeSort) {
        SortType.proximity =>
          _distanceKm(aData).compareTo(_distanceKm(bData)),
        SortType.time =>
          _nextPrayerTime(aData).compareTo(_nextPrayerTime(bData)),
        SortType.following =>
          _distanceKm(aData).compareTo(_distanceKm(bData)),
      };
    });

    return docs;
  }

  double distanceKmForDoc(Map<String, dynamic> data) => _distanceKm(data);

  // ── Private helpers ───────────────────────────────────────────────────────

  double _distanceKm(Map<String, dynamic> data) {
    if (_position == null) return double.infinity;
    final lat = (data['lat'] as num?)?.toDouble();
    final lng = (data['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return double.infinity;
    return Geolocator.distanceBetween(
          _position!.latitude,
          _position!.longitude,
          lat,
          lng,
        ) /
        1000;
  }

  DateTime _nextPrayerTime(Map<String, dynamic> data) {
    final now = DateTime.now();
    for (final key in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']) {
      final dt = LocaleFormat.parsePrayerTimeToday(
        data[key] as String? ?? '',
        base: now,
      );
      if (dt != null && dt.isAfter(now)) return dt;
    }
    return now.add(const Duration(days: 1));
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  void _onAuthChanged(User? user) {
    _user = user;
    _userSub?.cancel();
    _userSub = null;

    if (user == null) {
      _role = kDefaultRole;
      _following = [];
      _isImam = false;
      _prayerStats = null;
      _ensureMosqueStream();
      notifyListeners();
      return;
    }

    _userSub = ServiceLocator.get<UserRepository>()
        .getUserStream(user.uid)
        .listen(_onUserProfileChanged);
  }

  void _onUserProfileChanged(UserProfile? profile) {
    if (profile == null) return;
    final newRole = profile.role;
    final newFollowing = profile.followedMosques;
    final newIsImam = newRole == kRoleImam;

    final roleChanged = newRole != _role;
    _role = newRole;
    _following = newFollowing;
    _isImam = newIsImam;

    if (roleChanged) _ensureMosqueStream();
    notifyListeners();

    if (_isImam && _prayerStats == null) {
      EnhancedPrayerTrackerService.getCurrentUserStats().then((stats) {
        if (stats != null) {
          _prayerStats = stats;
          notifyListeners();
        }
      }).catchError((_) {});
    }
  }

  // ── Mosque stream ─────────────────────────────────────────────────────────

  String _streamKey() =>
      'mosques:${_user?.uid ?? "anon"}:$_role:$_selectedFiqh';

  void _ensureMosqueStream() {
    final key = _streamKey();
    if (_activeStreamKey == key) return;
    _activeStreamKey = key;

    _mosquesSub?.cancel();

    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('mosques');
    if (_selectedFiqh != null) {
      query = query.where('fiqh', isEqualTo: _selectedFiqh);
    }

    _isLoadingMosques = true;
    _hasError = false;
    notifyListeners();

    _mosquesSub = query.limit(_mosqueQueryLimit).snapshots().listen(
      (snapshot) {
        _rawMosques = snapshot.docs;
        _isLoadingMosques = false;
        notifyListeners();
      },
      onError: (Object e) {
        debugPrint('HomeNotifier: mosque stream error: $e');
        _isLoadingMosques = false;
        _hasError = true;
        notifyListeners();
      },
    );
  }

  // ── Location ──────────────────────────────────────────────────────────────

  Future<void> _initLocation() async {
    _position = await LocationService.getCurrentLocation();
    _manualCityName = await LocationService.getManualCityName();
    notifyListeners();

    if (_manualCityName == null) _startLocationStream();
    _ensureMosqueStream();
  }

  void _startLocationStream() {
    _locationSub?.cancel();
    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 100,
      ),
    ).listen(
      (pos) {
        _position = pos;
        notifyListeners();
      },
      onError: (Object e) => debugPrint('HomeNotifier: location error: $e'),
    );
  }

  Future<void> refresh() async {
    _position = await LocationService.getCurrentLocation();
    _manualCityName = await LocationService.getManualCityName();

    if (_manualCityName == null) {
      _startLocationStream();
    } else {
      _locationSub?.cancel();
      _locationSub = null;
    }

    _activeStreamKey = null;
    _ensureMosqueStream();
    notifyListeners();
  }

  Future<void> setManualLocation(double lat, double lng, String name) async {
    await LocationService.setManualLocation(lat, lng, name);
    await refresh();
  }

  Future<void> clearManualLocation() async {
    await LocationService.clearManualLocation();
    await refresh();
  }

  // ── Filter / sort mutations ───────────────────────────────────────────────

  void setActiveSort(SortType sort) {
    if (_activeSort == sort) return;
    _activeSort = sort;
    notifyListeners();
  }

  void setRadiusKm(double km) {
    if (_selectedRadiusKm == km) return;
    _selectedRadiusKm = km;
    notifyListeners();
  }

  void setFiqh(String? fiqh) {
    if (_selectedFiqh == fiqh) return;
    _selectedFiqh = fiqh;
    _activeStreamKey = null;
    _ensureMosqueStream();
    // notifyListeners() called inside _ensureMosqueStream via loading state
  }

  bool _isRateLimited() {
    final now = DateTime.now();
    _searchTimestamps.removeWhere((ts) => now.difference(ts).inSeconds > 60);
    if (_searchTimestamps.length >= _maxSearchesPerMinute) return true;
    _searchTimestamps.add(now);
    return false;
  }

  void onSearchChanged(String query) {
    if (_isRateLimited()) return;
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 450), () {
      _searchQuery = query.toLowerCase().trim();
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userSub?.cancel();
    _locationSub?.cancel();
    _mosquesSub?.cancel();
    _searchDebounceTimer?.cancel();
    _sortRefreshTimer?.cancel();
    super.dispose();
  }
}
