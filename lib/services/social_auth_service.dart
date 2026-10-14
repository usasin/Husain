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

  Future<AuthCredential> _googleCredential() async {
    if (googleCredential != null) return googleCredential!();
    // Use the Firebase configuration validated for the actual iOS bundle.
    // Do not assume the Android ZIP's hardcoded iOS client matches this app.
    final iosClientId = auth.app.options.iosClientId;
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        (iosClientId == null || iosClientId.isEmpty)) {
      throw FirebaseAuthException(code: 'invalid-oauth-client-id');
    }
    _google ??= GoogleSignIn(
      clientId: defaultTargetPlatform == TargetPlatform.iOS
          ? iosClientId
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
      final current = auth.currentUser;
      final linking = current != null &&
          (hasProfile || !current.isAnonymous) &&
          !useExistingAccount;
      if (linking &&
          current.providerData.any((p) => p.providerId == providerId)) {
        return SocialAuthResult(SocialAuthStatus.connected, uid: current.uid);
      }
      UserCredential result;
      if (providerId == 'google.com' && !kIsWeb) {
        final credential = await _googleCredential();
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
