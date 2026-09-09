import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../l10n/app_localizations.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

class AuthService {
  AuthService({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
      : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  Stream<User?> get userChanges => _auth.userChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> initialize() async {
    await _googleSignIn.initialize();
  }

  Future<User?> signInWithGoogle(AppLocalizations loc) async {
    try {
      await initialize();
      final googleUser = await _googleSignIn.authenticate();
      final googleAuth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? loc.signInFailed);
    } catch (e) {
      throw AuthException(loc.authErrorNetworkError);
    }
  }

  Future<User?> signInWithEmail(String email, String password, AppLocalizations loc) async {
    try {
      final res = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return res.user;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyAuthError(e, loc));
    }
  }

  Future<User?> signUpWithEmail(
    String email,
    String password, {
    String? displayName,
    required AppLocalizations loc,
  }) async {
    try {
      final res = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final name = displayName?.trim();
      if (name != null && name.isNotEmpty) {
        await res.user?.updateDisplayName(name);
        await res.user?.reload();
      }
      return _auth.currentUser ?? res.user;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyAuthError(e, loc));
    }
  }

  Future<User?> signInAnonymously(AppLocalizations loc) async {
    try {
      final res = await _auth.signInAnonymously();
      return res.user;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyAuthError(e, loc));
    }
  }

  /// Link the (anonymous) current user with an email/password credential.
  /// If the email already belongs to a different account, falls back to a
  /// plain sign-in (anonymous data is orphaned but not lost on this device).
  Future<User?> linkWithEmailPassword(
    String email,
    String password, {
    required bool createAccount,
    String? displayName,
    required AppLocalizations loc,
  }) async {
    final user = _auth.currentUser;
    if (user == null || !user.isAnonymous) {
      return createAccount
          ? signUpWithEmail(email, password, displayName: displayName, loc: loc)
          : signInWithEmail(email, password, loc);
    }
    try {
      final credential = EmailAuthProvider.credential(
        email: email.trim(),
        password: password,
      );
      final res = await user.linkWithCredential(credential);
      final name = displayName?.trim();
      if (name != null && name.isNotEmpty) {
        await res.user?.updateDisplayName(name);
        await res.user?.reload();
      }
      return _auth.currentUser ?? res.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use' ||
          e.code == 'email-already-in-use' ||
          e.code == 'provider-already-linked') {
        return createAccount
            ? signUpWithEmail(email, password, displayName: displayName, loc: loc)
            : signInWithEmail(email, password, loc);
      }
      throw AuthException(_friendlyAuthError(e, loc));
    }
  }

  /// Link the (anonymous) current user with a Google credential. If the
  /// Google account already belongs to a different Firebase user, falls
  /// back to plain Google sign-in.
  Future<User?> linkWithGoogle(AppLocalizations loc) async {
    final user = _auth.currentUser;
    if (user == null || !user.isAnonymous) return signInWithGoogle(loc);
    final googleUser = await _googleSignIn.authenticate();
    final googleAuth = googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    try {
      final res = await user.linkWithCredential(credential);
      return res.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use' ||
          e.code == 'email-already-in-use' ||
          e.code == 'provider-already-linked') {
        final res = await _auth.signInWithCredential(credential);
        return res.user;
      }
      throw AuthException(_friendlyAuthError(e, loc));
    }
  }

  Future<void> sendPasswordReset(String email, AppLocalizations loc) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyAuthError(e, loc));
    }
  }

  String _friendlyAuthError(FirebaseAuthException e, AppLocalizations loc) {
    switch (e.code) {
      case 'invalid-email':
        return loc.authErrorInvalidEmail;
      case 'user-disabled':
        return loc.authErrorAccountDisabled;
      case 'user-not-found':
        return loc.authErrorUserNotFound;
      case 'invalid-credential':
        return loc.authErrorInvalidCredential;
      case 'wrong-password':
        return loc.authErrorWrongPassword;
      case 'email-already-in-use':
        return loc.authErrorEmailInUse;
      case 'weak-password':
        return loc.authErrorWeakPassword;
      case 'network-request-failed':
        return loc.authErrorNetworkError;
      case 'operation-not-allowed':
        return loc.authErrorOperationNotAllowed;
      default:
        return e.message ?? loc.somethingWrong;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _googleSignIn.signOut();
    await user.delete();
  }
}
