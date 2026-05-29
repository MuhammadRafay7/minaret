import 'package:flutter/material.dart';
import 'package:minaret/l10n/generated/app_localizations.dart';

import '../app_spacing.dart';
import '../errors/app_error.dart';
import '../theme.dart';

// ---------------------------------------------------------------------------
// ErrorDisplay — inline error widget for non-fatal, localised error states.
//
// Use when a single screen or widget fails and you want to show an error
// within the existing layout rather than replacing the whole app.
//
// Usage:
//   if (state.hasError)
//     ErrorDisplay(error: state.error, onRetry: () => ref.refresh(provider))
// ---------------------------------------------------------------------------

class ErrorDisplay extends StatelessWidget {
  const ErrorDisplay({
    super.key,
    required this.error,
    this.onRetry,
    this.compact = false,
  });

  final AppError error;

  /// If provided and [error.isRecoverable] is true, a retry button is shown.
  final VoidCallback? onRetry;

  /// When true, renders a smaller inline card instead of the centred layout.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return compact ? _CompactError(error: error, onRetry: onRetry) : _FullError(error: error, onRetry: onRetry);
  }
}

class _FullError extends StatelessWidget {
  const _FullError({required this.error, this.onRetry});

  final AppError error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _iconForError(error),
              size: 56,
              color: _colorForError(context, error),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              error.userMessage,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
              textAlign: TextAlign.center,
            ),
            if (error.isRecoverable && onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(AppLocalizations.of(context)!.tryAgain),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MinaretTheme.emerald,
                  side: const BorderSide(color: MinaretTheme.emerald),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(MinaretTheme.buttonRadius),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompactError extends StatelessWidget {
  const _CompactError({required this.error, this.onRetry});

  final AppError error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final color = _colorForError(context, error);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(_iconForError(error), color: color, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              error.userMessage,
              style: TextStyle(color: color, fontSize: 14, height: 1.4),
            ),
          ),
          if (error.isRecoverable && onRetry != null) ...[
            const SizedBox(width: AppSpacing.sm),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: color,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
              ),
              child: Text(AppLocalizations.of(context)!.retry),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ErrorSnackbar — transient error notification at the bottom of the screen.
//
// Usage:
//   ErrorSnackbar.show(context, error);
//   ErrorSnackbar.show(context, error, onRetry: () => doSomething());
// ---------------------------------------------------------------------------

class ErrorSnackbar {
  ErrorSnackbar._();

  static void show(
    BuildContext context,
    AppError error, {
    VoidCallback? onRetry,
  }) {
    // Dismiss any currently visible snack first to avoid stacking.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error.userMessage,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        backgroundColor: _colorForError(context, error),
        behavior: SnackBarBehavior.floating,
        // Non-recoverable errors stay longer so users can read them.
        duration: error.isRecoverable
            ? const Duration(seconds: 4)
            : const Duration(seconds: 8),
        margin: const EdgeInsets.all(AppSpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        action: (error.isRecoverable && onRetry != null)
            ? SnackBarAction(
                label: AppLocalizations.of(context)!.retry,
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers shared by both widgets
// ---------------------------------------------------------------------------

IconData _iconForError(AppError error) => switch (error) {
      AuthError() => Icons.lock_outline_rounded,
      NetworkError() => Icons.wifi_off_rounded,
      FirestoreError() => Icons.cloud_off_rounded,
      StorageError() => Icons.folder_off_outlined,
      ValidationError() => Icons.info_outline_rounded,
      PermissionError() => Icons.block_rounded,
      UnknownError() => Icons.error_outline_rounded,
    };

Color _colorForError(BuildContext context, AppError error) => switch (error) {
      ValidationError() || PermissionError() =>
        const Color(0xFFC9962A), // MinaretTheme.gold
      NetworkError() => Colors.blueGrey.shade600,
      AuthError() => Colors.orange.shade700,
      FirestoreError() || StorageError() =>
        Theme.of(context).colorScheme.error,
      UnknownError() => Theme.of(context).colorScheme.error,
    };
