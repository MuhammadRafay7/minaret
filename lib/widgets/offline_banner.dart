import 'dart:async';
import 'package:flutter/material.dart';
import '../core/app_spacing.dart';
import '../core/dependency_injection.dart';
import '../services/connectivity_service.dart';

/// Non-blocking offline indicator. Drop it as the first item in any Column that
/// wraps a screen body. It collapses to nothing when the device is online.
///
/// Usage:
/// ```dart
/// Column(
///   children: [
///     const OfflineBanner(),
///     Expanded(child: myScreenContent),
///   ],
/// )
/// ```
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  late bool _isOnline;
  StreamSubscription<bool>? _sub;

  @override
  void initState() {
    super.initState();
    final svc = ServiceLocator.tryGet<ConnectivityService>();
    _isOnline = svc?.isOnline ?? true;
    _sub = svc?.onlineStream.listen((online) {
      if (mounted) setState(() => _isOnline = online);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: _isOnline ? const SizedBox.shrink() : _buildStrip(context),
    );
  }

  Widget _buildStrip(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.orange.shade800,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: const Row(
        children: [
          Icon(Icons.wifi_off, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text(
            'Offline — showing cached data',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
