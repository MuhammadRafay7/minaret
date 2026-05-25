import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';

class AdService {
  static final _db = FirebaseFirestore.instance;
  static DateTime? _lastInterstitialTime;
  static InterstitialAd? _interstitialAd;
  
  static Stream<DocumentSnapshot> monetizationStream() {
    return _db.collection('app_settings').doc('monetization').snapshots();
  }

  /// Creates a Banner Ad instance
  static BannerAd? createBannerAd({
    required String adUnitId,
    required VoidCallback onAdLoaded,
    required Function(LoadAdError) onAdFailed,
  }) {
    if (kIsWeb) return null;
    
    try {
      return BannerAd(
        adUnitId: adUnitId,
        request: const AdRequest(),
        size: AdSize.banner,
        listener: BannerAdListener(
          onAdLoaded: (ad) => onAdLoaded(),
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            onAdFailed(error);
          },
        ),
      )..load();
    } catch (e) {
      debugPrint('AdService: Error creating banner ad: $e');
      return null;
    }
  }

  /// Loads an Interstitial Ad and stores it in memory
  static void loadInterstitial(String adUnitId) {
    if (kIsWeb) return;
    
    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _interstitialAd = null;
            },
          );
        },
        onAdFailedToLoad: (err) {
          debugPrint('AdService: Interstitial failed to load: $err');
        },
      ),
    );
  }

  /// Shows the Interstitial Ad if frequency capping allows
  static void showInterstitialIfAllowed(int frequencyMinutes) {
    if (_interstitialAd == null) return;

    final now = DateTime.now();
    if (_lastInterstitialTime == null || 
        now.difference(_lastInterstitialTime!).inMinutes >= frequencyMinutes) {
      _interstitialAd!.show();
      _lastInterstitialTime = now;
    } else {
      debugPrint('AdService: Interstitial suppressed by frequency capping');
    }
  }

  static Future<void> launchPersonalAdUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
