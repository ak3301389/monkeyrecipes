import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

/// Сервис аутентификации.
///
/// Web: используется Firebase Auth popup (google_sign_in НЕ используется).
/// Android: используется google_sign_in + Firebase Auth credential.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Вход через Google. Возвращает User при успехе, null — если отменили.
  Future<User?> signInWithGoogle() async {
    if (kIsWeb) {
      // На Web — ТОЛЬКО Firebase popup. Никакого GoogleSignIn!
      final provider = GoogleAuthProvider();
      provider.setCustomParameters({'prompt': 'select_account'});
      final cred = await _auth.signInWithPopup(provider);
      return cred.user;
    } else {
      // На Android — google_sign_in.
      final google = GoogleSignIn();
      final googleUser = await google.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final cred = await _auth.signInWithCredential(credential);
      return cred.user;
    }
  }

  /// Выход.
  Future<void> signOut() async {
    if (!kIsWeb) {
      try {
        await GoogleSignIn().signOut();
      } catch (_) {
        // Игнорируем, если что-то не так — главное, выйти из Firebase.
      }
    }
    await _auth.signOut();
  }
}
