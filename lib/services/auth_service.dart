import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, ValueNotifier;
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._() {
    _auth.authStateChanges().listen((u) {
      userNotifier.value = u;
    });
    userNotifier.value = _auth.currentUser;
  }
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ValueNotifier<User?> userNotifier = ValueNotifier<User?>(null);

  User? get currentUser => _auth.currentUser;
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<User?> signInWithGoogle() async {
    if (kIsWeb) {
      // Web: Firebase popup напрямую (без google_sign_in).
      final provider = GoogleAuthProvider();
      final cred = await _auth.signInWithPopup(provider);
      userNotifier.value = cred.user;
      return cred.user;
    }
    // Android: google_sign_in.
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null;
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final cred = await _auth.signInWithCredential(credential);
    userNotifier.value = cred.user;
    return cred.user;
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}
    }
    await _auth.signOut();
    userNotifier.value = null;
  }
}
