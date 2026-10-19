import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

enum SocialAuthStatus { connected, canceled, conflict, failed }

class SocialAuthResult {
  final SocialAuthStatus status;
  final String? code;
  final String? uid;
  const SocialAuthResult(this.status, {this.code, this.uid});
}

class SocialAuthService {
  final FirebaseAuth auth;
  final Future<AuthCredential> Function()? googleCredential;
  static GoogleSignIn? _google;
  SocialAuthService({FirebaseAuth? auth, this.googleCredential})
      : auth = auth ?? FirebaseAuth.instance;
  static const googleServerClientId =
      '531137173785-tltuheu808j5t8j5qd51a1a79qak2upl.apps.googleusercontent.com';
  static const googleIosClientId =
      '531137173785-kutgukbjcgqkq67a4141u22hk6e22b9q.apps.googleusercontent.com';

  Future<AuthCredential> _googleCredential() async {
    if (googleCredential != null) return googleCredential!();
    _google ??= GoogleSignIn(
      clientId: defaultTargetPlatform == TargetPlatform.iOS
          ? googleIosClientId
          : null,
      serverClientId: googleServerClientId,
      scopes: const ['email'],
    );
    await _google!.signOut();
    final account = await _google!.signIn();
    if (account == null) throw PlatformException(code: 'sign_in_canceled');
    final tokens = await account.authentication;
    if (tokens.idToken == null) {
      throw FirebaseAuthException(code: 'missing-id-token');
    }
    return GoogleAuthProvider.credential(
      idToken: tokens.idToken,
      accessToken: tokens.accessToken,
    );
  }

  Future<SocialAuthResult> connect(
    String providerId, {
    required bool hasProfile,
    bool useExistingAccount = false,
  }) async {
    try {
      if (providerId != 'google.com' && providerId != 'apple.com') {
        return const SocialAuthResult(SocialAuthStatus.failed, code: 'unsupported-provider');
      }
      final current = auth.currentUser;
      // An association must keep even an anonymous UID whose profile is
      // still loading. Signing in is a separate, explicit account change.
      if (useExistingAccount && hasProfile) {
        return const SocialAuthResult(SocialAuthStatus.failed,
            code: 'sign-out-before-account-switch');
      }
      if (hasProfile && current == null) {
        return const SocialAuthResult(SocialAuthStatus.failed, code: 'profile-session-mismatch');
      }
      final linking = current != null && !useExistingAccount;
      if (linking &&
          current.providerData.any((p) => p.providerId == providerId)) {
        return SocialAuthResult(SocialAuthStatus.connected, uid: current.uid);
      }
      UserCredential result;
      if (providerId == 'google.com' && !kIsWeb) {
        final credential = await _googleCredential();
        if (auth.currentUser?.uid != current?.uid) {
          return const SocialAuthResult(SocialAuthStatus.failed, code: 'profile-session-mismatch');
        }
        result = linking
            ? await current.linkWithCredential(credential)
            : await auth.signInWithCredential(credential);
      } else {
        final AuthProvider provider = providerId == 'apple.com'
            ? (AppleAuthProvider()
              ..addScope('email')
              ..addScope('name'))
            : (GoogleAuthProvider()
              ..setCustomParameters({'prompt': 'select_account'}));
        if (kIsWeb) {
          result = linking
              ? await current.linkWithPopup(provider)
              : await auth.signInWithPopup(provider);
        } else {
          result = linking
              ? await current.linkWithProvider(provider)
              : await auth.signInWithProvider(provider);
        }
      }
      if (result.user == null || auth.currentUser?.uid != result.user?.uid) {
        return const SocialAuthResult(SocialAuthStatus.failed, code: 'profile-session-mismatch');
      }
      if (linking && (result.user?.uid != current.uid ||
          auth.currentUser?.uid != current.uid)) {
        return const SocialAuthResult(SocialAuthStatus.failed, code: 'profile-session-mismatch');
      }
      return SocialAuthResult(
        SocialAuthStatus.connected,
        uid: result.user?.uid,
      );
    } on PlatformException catch (e) {
      return SocialAuthResult(
        const {
          'sign_in_canceled',
          'sign_in_cancelled',
          'canceled',
        }.contains(e.code)
            ? SocialAuthStatus.canceled
            : SocialAuthStatus.failed,
        code: e.code,
      );
    } on FirebaseAuthException catch (e) {
      if (const {
        'credential-already-in-use',
        'email-already-in-use',
        'account-exists-with-different-credential',
      }.contains(e.code)) {
        return SocialAuthResult(SocialAuthStatus.conflict, code: e.code);
      }
      if (const {
        'web-context-canceled',
        'popup-closed-by-user',
        'canceled',
        'user-cancelled',
      }.contains(e.code)) {
        return const SocialAuthResult(SocialAuthStatus.canceled);
      }
      return SocialAuthResult(SocialAuthStatus.failed, code: e.code);
    } catch (_) {
      return const SocialAuthResult(SocialAuthStatus.failed, code: 'unknown');
    }
  }
}
