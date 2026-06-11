import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../core/dependency_injection.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_extensions.dart';
import '../../../repositories/user_repository.dart';
import '../services/verification_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// State enum
// ─────────────────────────────────────────────────────────────────────────────

enum AuthState {
  initial,
  loading,
  authenticated,
  unauthenticated,
  awaitingEmailVerification,
  error,
}

// ─────────────────────────────────────────────────────────────────────────────
// Imam registration data — passed from ImamVerificationScreen into signUp
// ─────────────────────────────────────────────────────────────────────────────

class ImamRegistrationData {
  final Uint8List idCardBytes;
  final Uint8List idCardBackBytes;
  final Uint8List sanadBytes;
  final VerificationResult verificationResult;
  final String countryCode;
  final ImamProfileData profile;

  const ImamRegistrationData({
    required this.idCardBytes,
    required this.idCardBackBytes,
    required this.sanadBytes,
    required this.verificationResult,
    required this.countryCode,
    required this.profile,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// AuthNotifier
// ─────────────────────────────────────────────────────────────────────────────

class AuthNotifier extends ChangeNotifier {
  final FirebaseAuth _auth;
  final UserRepository _userRepo;

  AuthState _state = AuthState.initial;
  User? _currentUser;
  AppError? _error;
  String? _userRole;

  // Set to true just before signOut in the signup flow so the authStateChanges
  // listener knows to emit awaitingEmailVerification instead of unauthenticated.
  bool _awaitingEmailVerification = false;

  // Set to true during signup to suppress spurious authenticated state while
  // the account is being created and the Firestore write + signOut are pending.
  bool _suppressAuthUpdate = false;

  // Granular flags for operations that should NOT replace the main state.
  bool _isCheckingEmail = false;
  bool _isResendingEmail = false;

  StreamSubscription<User?>? _authSub;

  AuthNotifier({
    FirebaseAuth? auth,
    UserRepository? userRepo,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _userRepo = userRepo ?? ServiceLocator.get<UserRepository>() {
    _authSub = _auth.authStateChanges().listen(_onAuthChanged);
  }

  // ── Getters ───────────────────────────────────────────────────────────────

  AuthState get state => _state;
  User? get currentUser => _currentUser;
  AppError? get error => _error;
  String? get userRole => _userRole;
  bool get isCheckingEmail => _isCheckingEmail;
  bool get isResendingEmail => _isResendingEmail;

  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get isLoading => _state == AuthState.loading;

  /// Safe user-visible error message derived from [error].
  String get errorMessage =>
      _error != null ? _error!.userMessage : 'An unexpected error occurred.';

  // ── Internal auth stream handler ──────────────────────────────────────────

  void _onAuthChanged(User? user) {
    if (_suppressAuthUpdate) return;
    _currentUser = user;
    if (user == null) {
      _userRole = null;
      _state = _awaitingEmailVerification
          ? AuthState.awaitingEmailVerification
          : AuthState.unauthenticated;
      notifyListeners();
    } else {
      _state = AuthState.authenticated;
      notifyListeners();
      // Fetch role asynchronously (e.g. on app restart with a live session).
      // A second notifyListeners() fires once the role is available so the
      // profile view can show imam-specific controls.
      _fetchRoleAsync(user.uid);
    }
  }

  Future<void> _fetchRoleAsync(String uid) async {
    try {
      final profile = await _userRepo.getUser(uid);
      if (_currentUser?.uid == uid) {
        _userRole = profile?.role ?? 'common';
        notifyListeners();
      }
    } catch (_) {}
  }

  // ── Helper: wrap native exceptions into AppError ──────────────────────────

  AppError _toAppError(Object error, StackTrace st) {
    final appError = error.toAppError(st);
    appError.logToCrashlyticsSync();
    return appError;
  }

  void _setError(AppError err) {
    _error = err;
    _state = AuthState.error;
    notifyListeners();
  }

  // ── signIn ────────────────────────────────────────────────────────────────

  Future<void> signIn(String email, String password) async {
    _error = null;
    _state = AuthState.loading;
    notifyListeners();

    try {
      // Suppress the authStateChanges event while we check emailVerified.
      _suppressAuthUpdate = true;
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (!cred.user!.emailVerified) {
        await _auth.signOut();
        _suppressAuthUpdate = false;
        _userRole = null;
        _currentUser = null;
        _setError(const AuthError(
          code: 'email-not-verified',
          userMessage: 'Please verify your email before signing in.',
          debugMessage: 'Sign-in blocked: emailVerified == false',
        ));
        return;
      }

      final profile = await _userRepo.getUser(cred.user!.uid);
      _userRole = profile?.role ?? 'common';
      _currentUser = cred.user;
      _suppressAuthUpdate = false;
      _state = AuthState.authenticated;
      notifyListeners();
    } catch (e, st) {
      _suppressAuthUpdate = false;
      _setError(_toAppError(e, st));
    }
  }

  // ── signUp (common user) ──────────────────────────────────────────────────

  Future<void> signUp(String email, String password, String displayName, {
    String city = '',
  }) async {
    _error = null;
    _state = AuthState.loading;
    notifyListeners();

    try {
      _suppressAuthUpdate = true;
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await cred.user!.updateDisplayName(displayName.trim());
      await cred.user!.sendEmailVerification();

      await _userRepo.setUser(cred.user!.uid, {
        'email': email.trim(),
        'displayName': displayName.trim(),
        'city': city.trim(),
        'role': 'common',
        'createdAt': FieldValue.serverTimestamp(),
        'favorites': <String>[],
        'followedMosques': <String>[],
        'notificationsEnabled': true,
        'notificationPrefs': {
          'janaza': true,
          'adhan': true,
          'namaz': true,
          'eid': true,
          'taraweeh': true,
        },
      });

      _awaitingEmailVerification = true;
      _suppressAuthUpdate = false;
      await _auth.signOut();
      // _onAuthChanged fires with null → state becomes awaitingEmailVerification
    } catch (e, st) {
      _suppressAuthUpdate = false;
      _awaitingEmailVerification = false;
      _setError(_toAppError(e, st));
    }
  }

  // ── signUpAsImam ──────────────────────────────────────────────────────────

  /// Creates the account, uploads documents (requires authenticated user per
  /// storage.rules), writes the full imam profile, then signs out.
  ///
  /// Callers should listen to [uploadEvents] to show upload progress before
  /// calling this method (or consume the stream returned here).
  Future<void> signUpAsImam({
    required String email,
    required String password,
    required String displayName,
    required String city,
    required ImamRegistrationData imamData,
    void Function(UploadEvent)? onUploadEvent,
  }) async {
    _error = null;
    _state = AuthState.loading;
    notifyListeners();

    try {
      _suppressAuthUpdate = true;
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await cred.user!.updateDisplayName(displayName.trim());
      await cred.user!.sendEmailVerification();

      // Upload documents now that the user is authenticated.
      final Map<String, String> docUrls = {};
      await for (final event in InternationalVerificationService.uploadDocuments(
        uid: cred.user!.uid,
        idCardBytes: imamData.idCardBytes,
        idCardBackBytes: imamData.idCardBackBytes,
        sanadBytes: imamData.sanadBytes,
      )) {
        onUploadEvent?.call(event);
        if (event is UploadError) {
          throw Exception(event.message);
        }
        if (event is UploadComplete) {
          docUrls.addAll(event.urls);
        }
      }

      await InternationalVerificationService.writeRegistration(
        uid: cred.user!.uid,
        email: email.trim(),
        city: city.trim(),
        documentUrls: docUrls,
        verificationResult: imamData.verificationResult,
        countryCode: imamData.countryCode,
        profile: imamData.profile,
      );

      _awaitingEmailVerification = true;
      _suppressAuthUpdate = false;
      await _auth.signOut();
    } catch (e, st) {
      _suppressAuthUpdate = false;
      _awaitingEmailVerification = false;
      _setError(_toAppError(e, st));
    }
  }

  // ── checkEmailVerification ────────────────────────────────────────────────

  /// Re-signs in silently, force-reloads the user token, and routes if verified.
  /// Does NOT change [state] to [loading] — state stays [awaitingEmailVerification]
  /// while the check runs so the waiting screen remains visible. Callers read
  /// [isCheckingEmail] to show a progress indicator on the button.
  Future<bool> checkEmailVerification(String email, String password) async {
    _isCheckingEmail = true;
    notifyListeners();

    try {
      _suppressAuthUpdate = true;
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await cred.user!.reload();
      final fresh = _auth.currentUser;

      if (fresh != null && fresh.emailVerified) {
        final profile = await _userRepo.getUser(fresh.uid);
        _userRole = profile?.role ?? 'common';
        _currentUser = fresh;
        _suppressAuthUpdate = false;
        _awaitingEmailVerification = false;
        _isCheckingEmail = false;
        _state = AuthState.authenticated;
        notifyListeners();
        return true;
      } else {
        await _auth.signOut();
        _suppressAuthUpdate = false;
        _isCheckingEmail = false;
        _state = AuthState.awaitingEmailVerification;
        notifyListeners();
        return false;
      }
    } catch (e, st) {
      await _auth.signOut().catchError((_) {});
      _suppressAuthUpdate = false;
      _isCheckingEmail = false;
      _setError(_toAppError(e, st));
      return false;
    }
  }

  // ── resendVerificationEmail ───────────────────────────────────────────────

  /// Same principle as [checkEmailVerification]: state stays
  /// [awaitingEmailVerification]; callers read [isResendingEmail].
  Future<void> resendVerificationEmail(String email, String password) async {
    _isResendingEmail = true;
    notifyListeners();

    try {
      _suppressAuthUpdate = true;
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (!cred.user!.emailVerified) {
        await cred.user!.sendEmailVerification();
      }
      await _auth.signOut();
      _suppressAuthUpdate = false;
      _isResendingEmail = false;
      _state = AuthState.awaitingEmailVerification;
      notifyListeners();
    } catch (e, st) {
      _suppressAuthUpdate = false;
      _isResendingEmail = false;
      _setError(_toAppError(e, st));
    }
  }

  // ── signOut ───────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    _awaitingEmailVerification = false;
    _userRole = null;
    await _auth.signOut();
    // authStateChanges fires → _onAuthChanged sets unauthenticated
  }

  // ── resetPassword ─────────────────────────────────────────────────────────

  Future<void> resetPassword(String email) async {
    _error = null;
    _state = AuthState.loading;
    notifyListeners();

    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      _state = _currentUser != null
          ? AuthState.authenticated
          : AuthState.unauthenticated;
      notifyListeners();
    } catch (e, st) {
      _setError(_toAppError(e, st));
    }
  }

  // ── clearError ────────────────────────────────────────────────────────────

  void clearError() {
    if (_state == AuthState.error) {
      _error = null;
      _state = _currentUser != null
          ? AuthState.authenticated
          : AuthState.unauthenticated;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
