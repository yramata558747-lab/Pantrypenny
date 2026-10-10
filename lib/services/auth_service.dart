import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

/// Firebase Authentication (Email/Password + Google Sign-In).
/// Mirrors the AuthService shown in the course slides.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final GoogleSignIn? _googleSignIn =
      kIsWeb ? null : GoogleSignIn();

  User? get currentUser => _auth.currentUser;

  Stream<User?> get userStream => _auth.authStateChanges();

  // GOOGLE SIGN-IN
  // Returns null when the user closes the Google account picker.
  Future<User?> signInWithGoogle() async {
    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider();
      final userCredential =
          await _auth.signInWithPopup(googleProvider);
      return userCredential.user;
    }

    final googleUser = await _googleSignIn!.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return (await _auth.signInWithCredential(credential)).user;
  }

  // EMAIL/PASSWORD REGISTER + VERIFICATION EMAIL
  Future<User?> registerWithEmail(
    String email,
    String password, {
    String? displayName,
  }) async {
    final userCredential =
        await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = userCredential.user;

    if (user != null) {
      final name = displayName?.trim() ?? '';

      if (name.isNotEmpty) {
        await user.updateDisplayName(name);
      }

      if (!user.emailVerified) {
        await user.sendEmailVerification();
      }
    }

    return user;
  }

  // EMAIL/PASSWORD LOGIN
  Future<User?> signInWithEmail(
    String email,
    String password,
  ) async {
    final userCredential =
        await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    return userCredential.user;
  }

  // FORGOT PASSWORD
  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(
      email: email.trim(),
    );
  }

  // RESEND VERIFICATION EMAIL
  Future<void> resendVerification(
    String email,
    String password,
  ) async {
    final user = await signInWithEmail(email, password);

    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }

    await signOut();
  }

  // RE-AUTHENTICATE (required before deleting an account)
  Future<void> reauthWithPassword(String password) async {
    final user = _auth.currentUser;

    if (user == null || user.email == null) {
      throw FirebaseAuthException(code: 'no-current-user');
    }

    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      ),
    );
  }

  Future<void> reauthWithGoogle() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(code: 'no-current-user');
    }

    if (kIsWeb) {
      await user.reauthenticateWithPopup(GoogleAuthProvider());
      return;
    }

    final googleUser = await _googleSignIn!.signIn();

    if (googleUser == null) {
      throw FirebaseAuthException(code: 'cancelled');
    }

    final googleAuth = await googleUser.authentication;

    await user.reauthenticateWithCredential(
      GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      ),
    );
  }

  Future<void> deleteCurrentUser() async {
    await _auth.currentUser?.delete();

    if (!kIsWeb) {
      await _googleSignIn?.signOut();
    }
  }

  // SIGN OUT
  Future<void> signOut() async {
    if (!kIsWeb) {
      await _googleSignIn?.signOut();
    }

    await _auth.signOut();
  }
}