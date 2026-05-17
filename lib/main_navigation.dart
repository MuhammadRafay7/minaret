import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import 'package:minaret/l10n/generated/app_localizations.dart';
import 'package:minaret/core/theme.dart';
import 'package:minaret/core/animation_constants.dart';
import 'package:minaret/features/mosque/home_page.dart';
import 'package:minaret/features/auth/auth_page.dart';
import 'package:minaret/features/mosque/global_registry_page.dart';
import 'package:minaret/features/quran/quran_language_page.dart';
import 'package:minaret/features/hadith/hadith_page.dart';
import 'package:minaret/services/notification_service.dart';
import 'package:minaret/services/fcm_token_service.dart';
import 'package:minaret/services/app_content_service.dart';
import 'package:minaret/core/location_service.dart';
import 'package:minaret/services/ad_service.dart';
import 'package:minaret/services/system_config_service.dart';

class NavigationItem {
  final IconData icon;
  final String labelKey;
  final String fallbackLabel;
  final Widget page;
  final bool isEnabled;

  const NavigationItem({
    required this.icon,
    required this.labelKey,
    required this.fallbackLabel,
    required this.page,
    this.isEnabled = true,
  });
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({
    super.key,
    required this.firebaseReady,
  });
  final bool firebaseReady;

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with TickerProviderStateMixin, WidgetsBindingObserver {

  int _currentIndex = 0;
  StreamSubscription<User?>? _authSubscription;
  Future<DocumentSnapshot?>? _contentFuture;

  late final AnimationController _pageTransitionController;
  late final AnimationController _navBarAnimationController;

  // Banner State
  BannerAd? _adMobBannerAd;
  bool _isAdMobLoaded = false;
  String? _currentAdMobBannerId;

  // Interstitial Logic
  String? _currentInterstitialId;
  int _adFrequencyMinutes = 15;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAnimations();
    _initializeContentFuture();
    _initializeServices();
    _startAnimations();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageTransitionController.dispose();
    _navBarAnimationController.dispose();
    _authSubscription?.cancel();
    _adMobBannerAd?.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _pageTransitionController = AppAnimations.createController(this, duration: AppAnimations.medium);
    _navBarAnimationController = AppAnimations.createController(this, duration: AppAnimations.slow);
  }

  void _initializeContentFuture() {
    _contentFuture = _loadContentData();
  }

  void _initializeServices() {
    _initAppServices();
  }

  void _startAnimations() {
    _navBarAnimationController.forward();
  }

  Future<DocumentSnapshot?> _loadContentData() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('app_settings').doc('content').get();
      return snapshot;
    } catch (e) {
      return null;
    }
  }

  void _initAppServices() {
    unawaited(_checkPermissions());
    _initAuthenticationListener();
  }

  void _initAppServicesWithRole(User? user) {
     if (user != null) {
        NotificationService.startForUser();
        FcmTokenService.init();
     }
  }

  void _initAuthenticationListener() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(_handleAuthStateChange);
  }

  Future<void> _handleAuthStateChange(User? user) async {
    if (user != null) {
      if (FirebaseAuth.instance.currentUser != null) {
        await NotificationService.startForUser();
        await FcmTokenService.init();
      }
    } else {
      await FcmTokenService.removeToken();
      await NotificationService.cancelAllListeners();
    }
  }

  Future<void> _checkPermissions() async {
    if (!kIsWeb) {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
    }
  }

  // ============================================================================
  // REMOTE AD MANAGEMENT
  // ============================================================================

  void _syncAdMob(Map<String, dynamic> config) {
    final bannerId = (defaultTargetPlatform == TargetPlatform.android)
        ? config['androidBannerId'] as String?
        : config['iosBannerId'] as String?;

    final interstitialId = (defaultTargetPlatform == TargetPlatform.android)
        ? config['androidInterstitialId'] as String?
        : config['iosInterstitialId'] as String?;

    _adFrequencyMinutes = config['adFrequencyMinutes'] as int? ?? 15;

    // Sync Banner
    if (bannerId != null && bannerId.isNotEmpty && _currentAdMobBannerId != bannerId) {
      _currentAdMobBannerId = bannerId;
      _adMobBannerAd?.dispose();
      _isAdMobLoaded = false;
      _adMobBannerAd = AdService.createBannerAd(
        adUnitId: bannerId,
        onAdLoaded: () => setState(() => _isAdMobLoaded = true),
        onAdFailed: (_) {},
      );
    }

    // Sync Interstitial (Pre-load if changed)
    if (interstitialId != null && interstitialId.isNotEmpty && _currentInterstitialId != interstitialId) {
      _currentInterstitialId = interstitialId;
      AdService.loadInterstitial(interstitialId);
    }
  }

  void _onLoginSuccess() => _animateToPage(0);

  void _animateToPage(int index) {
    if (_currentIndex == index) return;
    
    // Remote Interstitial Logic: Show ad before moving if allowed
    AdService.showInterstitialIfAllowed(_adFrequencyMinutes);
    
    HapticFeedback.selectionClick();
    _pageTransitionController.reset();
    setState(() => _currentIndex = index);
    _pageTransitionController.forward();
  }

  List<NavigationItem> _getEnabledItems(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final globalSettings = Provider.of<GlobalSettings?>(context);
    
    final features = globalSettings?.features;

    final allItems = [
      NavigationItem(
        icon: Icons.roofing_rounded, 
        labelKey: 'nav_home', 
        fallbackLabel: l10n?.minaretTitle ?? 'Home',
        page: const HomePage(),
        isEnabled: true, // Home is always enabled
      ),
      NavigationItem(
        icon: Icons.menu_book_rounded, 
        labelKey: 'nav_quran', 
        fallbackLabel: l10n?.quranTitle ?? 'Quran',
        page: const QuranLanguagePage(),
        isEnabled: features?.enableQuran ?? true,
      ),
      NavigationItem(
        icon: Icons.auto_stories_outlined, 
        labelKey: 'nav_hadith', 
        fallbackLabel: l10n?.hadithTitle ?? 'Hadith',
        page: const HadithPage(),
        isEnabled: features?.enableHadith ?? true,
      ),
      NavigationItem(
        icon: Icons.public_rounded, 
        labelKey: 'nav_global', 
        fallbackLabel: l10n?.globalHeader ?? 'Global',
        page: const GlobalRegistryPage(),
        isEnabled: features?.enableMosqueDiscovery ?? true,
      ),
      NavigationItem(
        icon: Icons.person_outline_rounded, 
        labelKey: 'nav_account', 
        fallbackLabel: l10n?.profileHeader ?? 'Account',
        page: AuthPage(onLoginSuccess: _onLoginSuccess),
        isEnabled: true,
      ),
    ];

    return allItems.where((item) => item.isEnabled).toList();
  }

  @override
  Widget build(BuildContext context) {
    final enabledItems = _getEnabledItems(context);
    
    // Safety check for index out of bounds if items are removed dynamically
    if (_currentIndex >= enabledItems.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: enabledItems.map((e) => e.page).toList(),
          ),
          _buildManagedAds(),
        ],
      ),
      bottomNavigationBar: _buildFloatingNavBar(enabledItems),
    );
  }

  Widget _buildManagedAds() {
    return StreamBuilder<DocumentSnapshot>(
      stream: AdService.monetizationStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
        
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final adType = data['adType'] as String? ?? 'none';

        if (adType == 'admob') {
          final config = data['admobConfig'] as Map<String, dynamic>? ?? {};
          final isEnabled = config['isEnabled'] as bool? ?? false;
          if (!isEnabled) return const SizedBox.shrink();

          _syncAdMob(config);
          return _buildAdMobWidget();
        } else if (adType == 'personal') {
          final config = data['personalAdConfig'] as Map<String, dynamic>? ?? {};
          return _buildPersonalAdWidget(config);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildAdMobWidget() {
    if (!_isAdMobLoaded || _adMobBannerAd == null) return const SizedBox.shrink();
    return Positioned(
      left: 0,
      right: 0,
      bottom: 110,
      child: Center(
        child: Container(
          width: _adMobBannerAd!.size.width.toDouble(),
          height: _adMobBannerAd!.size.height.toDouble(),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.black54 : Colors.white54,
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: AdWidget(ad: _adMobBannerAd!),
        ),
      ),
    );
  }

  Widget _buildPersonalAdWidget(Map<String, dynamic> config) {
    final imageUrl = config['imageUrl'] as String? ?? '';
    final clickUrl = config['clickUrl'] as String? ?? '';
    if (imageUrl.isEmpty) return const SizedBox.shrink();

    return Positioned(
      left: 20,
      right: 20,
      bottom: 110,
      child: GestureDetector(
        onTap: () => AdService.launchPersonalAdUrl(clickUrl),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 4))],
          ),
          clipBehavior: Clip.antiAlias,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: Colors.grey[200]),
            errorWidget: (context, url, error) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingNavBar(List<NavigationItem> items) {
    return FutureBuilder<DocumentSnapshot?>(
      future: _contentFuture,
      builder: (context, snapshot) {
        return AnimatedBuilder(
          animation: _navBarAnimationController,
          builder: (context, child) {
            return SlideTransition(
              position: AppAnimations.slideTween(const Offset(0, 1.0), Offset.zero).animate(CurvedAnimation(parent: _navBarAnimationController, curve: AppAnimations.easeOutCubic)),
              child: FadeTransition(
                opacity: AppAnimations.fadeIn(_navBarAnimationController),
                child: _NavBarContent(items: items, currentIndex: _currentIndex, onTap: _animateToPage),
              ),
            );
          },
        );
      },
    );
  }
}

class _NavBarContent extends StatelessWidget {
  final List<NavigationItem> items;
  final int currentIndex;
  final Function(int) onTap;

  const _NavBarContent({required this.items, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final langCode = Localizations.localeOf(context).languageCode;
    final isRtl = langCode == 'ar' || langCode == 'ur';
    final isArabic = langCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? const Color(0xFF0F141D).withOpacity(0.92) : const Color(0xFF111111).withOpacity(0.88);
    final inactive = isDark ? Colors.white.withOpacity(0.55) : Colors.white.withOpacity(0.28);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 74,
            decoration: BoxDecoration(
              color: navBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(isDark ? 0.14 : 0.08), width: 0.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(items.length, (index) {
                return Expanded(
                  child: _NavigationButton(item: items[index], isSelected: currentIndex == index, isRtl: isRtl, isArabic: isArabic, inactiveColor: inactive, onTap: () => onTap(index)),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationButton extends StatelessWidget {
  final NavigationItem item;
  final bool isSelected;
  final bool isRtl;
  final bool isArabic;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _NavigationButton({required this.item, required this.isSelected, required this.isRtl, required this.isArabic, required this.inactiveColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppAnimations.medium,
        curve: AppAnimations.easeOutCubic,
        transform: Matrix4.identity()..scale(isSelected ? 1.05 : 0.96),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        decoration: BoxDecoration(border: isSelected ? Border(bottom: BorderSide(color: MinaretTheme.gold, width: 2)) : null),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(duration: AppAnimations.fast, transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child), child: Icon(item.icon, key: ValueKey(isSelected), size: 22, color: isSelected ? MinaretTheme.gold : inactiveColor)),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: AppAnimations.medium,
              curve: AppAnimations.easeOutCubic,
              style: (isArabic ? GoogleFonts.amiri() : GoogleFonts.montserrat()).copyWith(fontSize: 8.2, letterSpacing: isRtl ? 0 : 0.6, fontWeight: FontWeight.w700, color: isSelected ? MinaretTheme.gold : inactiveColor),
              child: Text(isRtl ? item.fallbackLabel : item.fallbackLabel.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}
