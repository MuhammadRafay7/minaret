import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_spacing.dart';
import '../../core/theme.dart';
import '../../core/dependency_injection.dart';
import '../../repositories/notification_repository.dart';
import '../../widgets/premium_loading.dart';
import '../../l10n/generated/app_localizations.dart';
import 'notifiers/notifications_notifier.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return _buildSignedOut(context);
    }
    return ChangeNotifierProvider(
      create: (_) => NotificationsNotifier(
        repo: ServiceLocator.get<NotificationRepository>(),
      )..init(user.uid),
      child: _NotificationsView(uid: user.uid),
    );
  }

  Widget _buildSignedOut(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MinaretTheme.darkBackground : MinaretTheme.background;
    final titleColor = isDark ? Colors.white : MinaretTheme.onyx;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          l10n.notificationsTitle,
          style: MinaretTheme.heading.copyWith(
            fontSize: 20,
            color: titleColor,
            letterSpacing: 2,
          ),
        ),
      ),
      body: Center(
        child: Text(l10n.signInToViewNotifications),
      ),
    );
  }
}

class _NotificationsView extends StatefulWidget {
  const _NotificationsView({required this.uid});
  final String uid;

  @override
  State<_NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<_NotificationsView> {
  final ScrollController _scrollController = ScrollController();
  final bool _isDebugMode = kDebugMode;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      context.read<NotificationsNotifier>().loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _testNotificationsAccess() async {
    final repo = ServiceLocator.get<NotificationRepository>();
    try {
      if (kDebugMode) debugPrint('Testing notifications read access');
      final count = await repo.getUnreadCount(widget.uid);
      if (kDebugMode) debugPrint('Test 1 - Read access: SUCCESS ($count unread)');
      await repo.addNotification({
        'userId': widget.uid,
        'type': 'test',
        'title': 'Test Notification',
        'message': 'This is a test notification',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (kDebugMode) debugPrint('Test 2 - Create access: SUCCESS');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Test FAILED: $e');
        if (e is FirebaseException) {
          debugPrint('Firebase error code: ${e.code}');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = context.watch<NotificationsNotifier>();
    final l10n = AppLocalizations.of(context)!;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MinaretTheme.darkBackground : MinaretTheme.background;
    final titleColor = isDark ? Colors.white : MinaretTheme.onyx;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: titleColor),
        ),
        title: Text(
          l10n.notificationsTitle,
          style: MinaretTheme.heading.copyWith(
            fontSize: 20,
            color: titleColor,
            letterSpacing: 2,
          ),
        ),
        actions: [
          if (_isDebugMode)
            IconButton(
              onPressed: _testNotificationsAccess,
              icon: const Icon(Icons.bug_report, color: Colors.white),
              tooltip: 'Test notifications access',
            ),
          if (n.unreadCount > 0)
            IconButton(
              onPressed: () => n.markAllAsRead(widget.uid),
              icon: const Icon(Icons.done_all, color: Colors.white),
              tooltip: 'Mark all as read',
            ),
        ],
      ),
      body: _buildBody(n, l10n),
    );
  }

  Widget _buildBody(NotificationsNotifier n, AppLocalizations l10n) {
    if (!n.initialized) {
      return const PremiumLoadingScreen();
    }

    if (n.hasError) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.errorLoadingNotifications,
                style: GoogleFonts.lato(
                  color: Colors.red,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'Error: ${n.error}',
                  style: GoogleFonts.lato(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _testNotificationsAccess,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MinaretTheme.emerald,
                  foregroundColor: Colors.white,
                ),
                child: Text(l10n.testPermissions),
              ),
            ],
          ),
        ),
      );
    }

    final notifications = n.notifications;

    if (notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 64,
              color: MinaretTheme.emerald.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noNotificationsYet,
              style: GoogleFonts.lato(
                fontSize: 18,
                color: MinaretTheme.emerald.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.mosqueAlertsHere,
              style: GoogleFonts.lato(
                fontSize: 14,
                color: MinaretTheme.emerald.withValues(alpha: 0.4),
              ),
            ),
            if (_isDebugMode) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _testNotificationsAccess,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MinaretTheme.emerald,
                  foregroundColor: Colors.white,
                ),
                child: Text(l10n.testPermissions),
              ),
            ],
          ],
        ),
      );
    }

    final itemCount = notifications.length + (n.hasMore ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == notifications.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: MinaretTheme.gold.withValues(alpha: 0.6),
                ),
              ),
            ),
          );
        }
        final notification = notifications[index];
        return Dismissible(
          key: ValueKey(notification.id),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => n.deleteNotification(notification.id),
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
          ),
          child: _buildNotificationCard(
            n: n,
            id: notification.id,
            title: notification.title,
            message: notification.body ?? '',
            type: notification.type,
            isRead: notification.isRead,
            createdAt: notification.createdAt,
            mosqueName: notification.raw['mosqueName'] as String?,
            reportReason: notification.raw['reportReason'] as String?,
          ),
        );
      },
    );
  }

  Widget _buildNotificationCard({
    required NotificationsNotifier n,
    required String id,
    required String title,
    required String message,
    required String type,
    required bool isRead,
    DateTime? createdAt,
    String? mosqueName,
    String? reportReason,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isRead
            ? MinaretTheme.background.withValues(alpha: 0.5)
            : MinaretTheme.emerald.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRead
              ? MinaretTheme.dividerColor.withValues(alpha: 0.3)
              : MinaretTheme.emerald.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (!isRead) {
              n.markAsRead(id);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getNotificationColor(type).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getNotificationIcon(type),
                        size: 20,
                        color: _getNotificationColor(type),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isRead
                                  ? MinaretTheme.emerald.withValues(alpha: 0.6)
                                  : MinaretTheme.emerald,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (createdAt != null)
                            Text(
                              _formatDate(createdAt),
                              style: GoogleFonts.lato(
                                fontSize: 12,
                                color: MinaretTheme.slate.withValues(alpha: 0.6),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!isRead)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: MinaretTheme.gold,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    color: isRead
                        ? MinaretTheme.onyx.withValues(alpha: 0.6)
                        : MinaretTheme.onyx,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (mosqueName != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: MinaretTheme.gold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      mosqueName,
                      style: GoogleFonts.lato(
                        fontSize: 12,
                        color: MinaretTheme.gold,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'report_warning':
      case 'warning':
        return Colors.orange;
      case 'ban':
        return Colors.red;
      case 'role_change':
        return Colors.purple;
      case 'mosque_update':
        return MinaretTheme.emerald;
      case 'prayer_time':
        return Colors.blue;
      case 'janaza':
        return Colors.red.shade700;
      default:
        return MinaretTheme.gold;
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'report_warning':
      case 'warning':
        return Icons.warning;
      case 'ban':
        return Icons.block;
      case 'role_change':
        return Icons.admin_panel_settings;
      case 'mosque_update':
        return Icons.mosque;
      case 'prayer_time':
        return Icons.access_time;
      case 'janaza':
        return Icons.notifications_active;
      default:
        return Icons.notifications;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }
}
