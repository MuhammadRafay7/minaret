import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minaret/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Minimal reproducer for the notification toggle section UI/logic.
// Mirrors SettingsPage._updateNotification without Firebase dependencies.
// ---------------------------------------------------------------------------

class _NotifPrefsWidget extends StatefulWidget {
  final Future<void> Function(String key, bool value) onUpdate;
  const _NotifPrefsWidget({required this.onUpdate});

  @override
  State<_NotifPrefsWidget> createState() => _NotifPrefsWidgetState();
}

class _NotifPrefsWidgetState extends State<_NotifPrefsWidget> {
  bool _adhan = true;
  bool _janaza = true;
  final Set<String> _savingKeys = {};
  String? _errorMessage;

  Future<void> _update(String key, bool value) async {
    if (_savingKeys.contains(key)) return;

    final prevAdhan = _adhan;
    final prevJanaza = _janaza;

    setState(() {
      _savingKeys.add(key);
      if (key == 'adhan') _adhan = value;
      if (key == 'janaza') _janaza = value;
      _errorMessage = null;
    });

    try {
      await widget.onUpdate(key, value);
    } catch (_) {
      if (mounted) {
        setState(() {
          _adhan = prevAdhan;
          _janaza = prevJanaza;
          _errorMessage = 'Failed to save preference.';
        });
      }
    } finally {
      if (mounted) setState(() => _savingKeys.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_errorMessage != null)
          Text(_errorMessage!, key: const Key('error')),
        ListTile(
          key: const Key('adhan-tile'),
          title: const Text('Adhan Alerts'),
          trailing: _savingKeys.contains('adhan')
              ? const CircularProgressIndicator(key: Key('adhan-spinner'))
              : Switch(
                  key: const Key('adhan-switch'),
                  value: _adhan,
                  onChanged: (v) => _update('adhan', v),
                ),
        ),
        ListTile(
          key: const Key('janaza-tile'),
          title: const Text('Janaza Alerts'),
          trailing: _savingKeys.contains('janaza')
              ? const CircularProgressIndicator(key: Key('janaza-spinner'))
              : Switch(
                  key: const Key('janaza-switch'),
                  value: _janaza,
                  onChanged: (v) => _update('janaza', v),
                ),
        ),
      ],
    );
  }
}

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Notification preference screen', () {
    // ── Initial render ───────────────────────────────────────────────────────

    testWidgets('renders switches for each notification type', (tester) async {
      // Arrange / Act
      await tester.pumpWidget(
        _wrap(_NotifPrefsWidget(onUpdate: (_, __) async {})),
      );

      // Assert
      expect(find.byKey(const Key('adhan-switch')), findsOneWidget);
      expect(find.byKey(const Key('janaza-switch')), findsOneWidget);
    });

    // ── Loading state ────────────────────────────────────────────────────────

    testWidgets('shows spinner instead of switch while saving', (tester) async {
      // Arrange — slow save that we control
      final completer = Completer<void>();
      await tester.pumpWidget(
        _wrap(_NotifPrefsWidget(onUpdate: (_, __) => completer.future)),
      );

      // Act — tap the adhan switch
      await tester.tap(find.byKey(const Key('adhan-switch')));
      await tester.pump();

      // Assert — spinner is visible, switch is replaced
      expect(find.byKey(const Key('adhan-spinner')), findsOneWidget);
      expect(find.byKey(const Key('adhan-switch')), findsNothing);

      // Resolve and verify switch returns
      completer.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('adhan-switch')), findsOneWidget);
    });

    // ── Double-tap guard ─────────────────────────────────────────────────────

    testWidgets('second tap while saving is ignored', (tester) async {
      // Arrange
      int callCount = 0;
      final completer = Completer<void>();

      await tester.pumpWidget(
        _wrap(_NotifPrefsWidget(onUpdate: (key, value) async {
          callCount++;
          await completer.future;
        })),
      );

      // Act — first tap starts the save; spinner replaces switch immediately
      await tester.tap(find.byKey(const Key('adhan-switch')));
      await tester.pump();

      // The spinner is now shown, switch is gone — no second tap possible
      expect(find.byKey(const Key('adhan-spinner')), findsOneWidget);
      expect(find.byKey(const Key('adhan-switch')), findsNothing);

      completer.complete();
      await tester.pumpAndSettle();

      // Only one save call was made
      expect(callCount, 1);
    });

    // ── Error state ──────────────────────────────────────────────────────────

    testWidgets('shows error text and rolls back value when save fails', (tester) async {
      // Arrange
      await tester.pumpWidget(
        _wrap(_NotifPrefsWidget(
          onUpdate: (_, __) async => throw Exception('Firestore down'),
        )),
      );

      // Initial state — adhan is ON (true)
      expect(
        tester.widget<Switch>(find.byKey(const Key('adhan-switch'))).value,
        isTrue,
      );

      // Act — toggle OFF (optimistic update); save will throw
      await tester.tap(find.byKey(const Key('adhan-switch')));
      await tester.pumpAndSettle();

      // Assert — error text is visible
      expect(find.byKey(const Key('error')), findsOneWidget);
      // Value rolled back to true
      expect(
        tester.widget<Switch>(find.byKey(const Key('adhan-switch'))).value,
        isTrue,
      );
    });

    // ── Success state ────────────────────────────────────────────────────────

    testWidgets('value persists as toggled when save succeeds', (tester) async {
      // Arrange
      await tester.pumpWidget(
        _wrap(_NotifPrefsWidget(onUpdate: (_, __) async {})),
      );

      // Act — toggle adhan OFF
      await tester.tap(find.byKey(const Key('adhan-switch')));
      await tester.pumpAndSettle();

      // Assert — value is now false; no error
      expect(
        tester.widget<Switch>(find.byKey(const Key('adhan-switch'))).value,
        isFalse,
      );
      expect(find.byKey(const Key('error')), findsNothing);
    });

    // ── Independent keys ─────────────────────────────────────────────────────

    testWidgets('toggling one preference does not affect the other', (tester) async {
      // Arrange
      await tester.pumpWidget(
        _wrap(_NotifPrefsWidget(onUpdate: (_, __) async {})),
      );

      // Act — toggle adhan
      await tester.tap(find.byKey(const Key('adhan-switch')));
      await tester.pumpAndSettle();

      // Assert — janaza is still ON
      expect(
        tester.widget<Switch>(find.byKey(const Key('janaza-switch'))).value,
        isTrue,
      );
    });
  });
}
