import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';

/// Result of an authentication action.
class AuthResult {
  final bool ok;
  final bool cancelled;
  final bool needsVerification;
  final String? message;

  const AuthResult._({
    required this.ok,
    this.cancelled = false,
    this.needsVerification = false,
    this.message,
  });

  factory AuthResult.success([String? message]) =>
      AuthResult._(ok: true, message: message);

  factory AuthResult.failure(String message) =>
      AuthResult._(ok: false, message: message);

  factory AuthResult.cancelled() =>
      const AuthResult._(ok: false, cancelled: true);

  factory AuthResult.unverified() => const AuthResult._(
        ok: false,
        needsVerification: true,
        message:
            'Please verify your email before logging in. '
            'Check your inbox for the verification link.',
      );
}

/// Firebase-backed authentication state.
///
/// Supports Email/Password (with email verification),
/// Google Sign-In, Forgot Password and Remember Me.
///
/// The old local PIN account stored in Hive ('auth_box') is NOT
/// deleted. Pantry, grocery and history data are stored separately
/// and are untouched by this migration.
class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? service})
      : _service = service ?? AuthService();

  final AuthService _service;

  StreamSubscription<User?>? _subscription;
  SharedPreferences? _prefs;

  User? _user;
  bool _ready = false;

  bool rememberMe = true;
  String rememberedEmail = '';

  /// Username of a previous local PIN account, if one exists.
  String? legacyUsername;

  bool get isReady => _ready;

  /// Only verified users are allowed into the app.
  bool get isLoggedIn =>
      _user != null && _user!.emailVerified;

  User? get user => _user;

  String? get email => _user?.email;

  String? get currentUsername {
    final name = _user?.displayName?.trim();

    if (name != null && name.isNotEmpty) return name;

    return _user?.email;
  }

  bool get usesPassword =>
      _user?.providerData.any(
        (info) => info.providerId == 'password',
      ) ??
      false;

  // ------------------------------------------------------------
  // INIT
  // ------------------------------------------------------------
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    rememberMe = _prefs?.getBool('remember_me') ?? true;
    rememberedEmail =
        _prefs?.getString('remembered_email') ?? '';

    // Detect (but never modify) an older local PIN account.
    try {
      final legacy = await Hive.openBox('auth_box');
      legacyUsername = legacy.get('username') as String?;
    } catch (_) {}

    // Remember Me off: start every app launch signed out.
    if (!rememberMe && _service.currentUser != null) {
      await _service.signOut();
    }

    _user = _service.currentUser;

    _subscription = _service.userStream.listen((user) {
      _user = user;
      notifyListeners();
    });

    _ready = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------
  // HELPERS
  // ------------------------------------------------------------
  Future<void> _saveRemember(bool remember, String email) async {
    rememberMe = remember;
    rememberedEmail = remember ? email.trim() : '';

    await _prefs?.setBool('remember_me', remember);
    await _prefs?.setString(
      'remembered_email',
      rememberedEmail,
    );
  }

  String _friendly(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Choose a stronger password (8+ characters).';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      case 'requires-recent-login':
        return 'Please log in again, then retry.';
      case 'account-exists-with-different-credential':
        return 'This email is registered with another sign-in '
            'method.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }

  // ------------------------------------------------------------
  // REGISTER (sends verification email, then signs out)
  // ------------------------------------------------------------
  Future<AuthResult> register(
    String email,
    String password, {
    String? displayName,
  }) async {
    try {
      await _service.registerWithEmail(
        email,
        password,
        displayName: displayName,
      );

      // The user must verify before entering the app.
      await _service.signOut();

      return AuthResult.success(
        'Verification email sent to ${email.trim()}. '
        'Open the link, then log in.',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_friendly(e));
    } catch (_) {
      return AuthResult.failure(
        'Unable to create your account. Please try again.',
      );
    }
  }

  // ------------------------------------------------------------
  // EMAIL LOGIN
  // ------------------------------------------------------------
  Future<AuthResult> loginWithEmail(
    String email,
    String password, {
    required bool remember,
  }) async {
    try {
      final signedIn =
          await _service.signInWithEmail(email, password);

      if (signedIn == null) {
        return AuthResult.failure('Unable to log in.');
      }

      await _service.currentUser?.reload();
      final fresh = _service.currentUser;

      if (fresh == null || !fresh.emailVerified) {
        await _service.signOut();
        return AuthResult.unverified();
      }

      await _saveRemember(remember, email);

      _user = fresh;
      notifyListeners();

      return AuthResult.success();
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_friendly(e));
    } catch (_) {
      return AuthResult.failure(
        'Unable to log in. Please try again.',
      );
    }
  }

  // ------------------------------------------------------------
  // GOOGLE SIGN-IN
  // ------------------------------------------------------------
  Future<AuthResult> signInWithGoogle({
    required bool remember,
  }) async {
    try {
      final signedIn = await _service.signInWithGoogle();

      if (signedIn == null) return AuthResult.cancelled();

      await _saveRemember(remember, signedIn.email ?? '');

      _user = _service.currentUser;
      notifyListeners();

      return AuthResult.success();
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_friendly(e));
    } catch (_) {
      return AuthResult.failure(
        'Google Sign-In failed. Check your internet '
        'connection and Firebase SHA-1 setup.',
      );
    }
  }

  // ------------------------------------------------------------
  // FORGOT PASSWORD / RESEND VERIFICATION
  // ------------------------------------------------------------
  Future<AuthResult> sendPasswordReset(String email) async {
    try {
      await _service.sendPasswordReset(email);

      return AuthResult.success(
        'Password reset email sent to ${email.trim()}.',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_friendly(e));
    } catch (_) {
      return AuthResult.failure('Unable to send reset email.');
    }
  }

  Future<AuthResult> resendVerification(
    String email,
    String password,
  ) async {
    try {
      await _service.resendVerification(email, password);

      return AuthResult.success(
        'Verification email sent to ${email.trim()}.',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_friendly(e));
    } catch (_) {
      return AuthResult.failure(
        'Unable to resend the verification email.',
      );
    }
  }

  // ------------------------------------------------------------
  // LOG OUT (keeps local pantry data)
  // ------------------------------------------------------------
  Future<void> logout() async {
    await _service.signOut();

    _user = null;
    notifyListeners();
  }

  // ------------------------------------------------------------
  // DELETE ACCOUNT
  // Re-authenticate first (Firebase requires a recent login).
  // ------------------------------------------------------------
  Future<AuthResult> reauthenticate({String? password}) async {
    try {
      if (usesPassword) {
        await _service.reauthWithPassword(password ?? '');
      } else {
        await _service.reauthWithGoogle();
      }

      return AuthResult.success();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'cancelled') return AuthResult.cancelled();
      return AuthResult.failure(_friendly(e));
    } catch (_) {
      return AuthResult.failure('Unable to verify your identity.');
    }
  }

  Future<AuthResult> deleteAccount() async {
    try {
      await _service.deleteCurrentUser();

      await _saveRemember(false, '');

      _user = null;
      notifyListeners();

      return AuthResult.success();
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_friendly(e));
    } catch (_) {
      return AuthResult.failure('Unable to delete the account.');
    }
  }
}