import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prono4/services/social_auth_service.dart';

class Auth extends Fake implements FirebaseAuth {
  User? user;
  int signIns = 0;
  @override User? get currentUser => user;
  @override Future<UserCredential> signInWithCredential(AuthCredential c) async {
    signIns++;
    user = Player('existing', this);
    return Credential(user!);
  }
}
class Credential extends Fake implements UserCredential {
  final User value;
  Credential(this.value);
  @override User get user => value;
}
class Player extends Fake implements User {
  @override final String uid;
  final Auth auth;
  Object? failure;
  int links = 0;
  Player(this.uid, this.auth);
  @override bool get isAnonymous => true;
  @override List<UserInfo> get providerData => [];
  Future<UserCredential> link() async {
    links++;
    if (failure != null) throw failure!;
    return Credential(this);
  }
  @override Future<UserCredential> linkWithCredential(AuthCredential c) => link();
  @override Future<UserCredential> linkWithProvider(AuthProvider p) => link();
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final provider in ['google.com', 'apple.com']) {
      for (final loaded in [true, false]) {
        test('$platform $provider keeps anonymous UID (profile loaded=$loaded)', () async {
          debugDefaultTargetPlatformOverride = platform;
          final auth = Auth();
          final player = Player('player-$loaded', auth);
          auth.user = player;
          final service = SocialAuthService(auth: auth,
            googleCredential: () async => GoogleAuthProvider.credential(idToken: 'test'));
          final result = await service.connect(provider, hasProfile: loaded);
          expect(result.status, SocialAuthStatus.connected);
          expect(result.uid, player.uid);
          expect(auth.currentUser!.uid, player.uid);
          expect(player.links, 1);
          expect(auth.signIns, 0);
        });
      }
    }
  }
  for (final code in ['credential-already-in-use', 'account-exists-with-different-credential']) {
    test('conflict $code never signs in or switches profile', () async {
      final auth = Auth(); final player = Player('owner', auth); auth.user = player;
      player.failure = FirebaseAuthException(code: code);
      final result = await SocialAuthService(auth: auth,
        googleCredential: () async => GoogleAuthProvider.credential(idToken: 'test'))
        .connect('google.com', hasProfile: true);
      expect(result.status, SocialAuthStatus.conflict);
      expect(auth.currentUser!.uid, 'owner'); expect(auth.signIns, 0);
    });
  }
  test('switch forbidden while a profile is open', () async {
    final auth = Auth()..user = null;
    final result = await SocialAuthService(auth: auth).connect('google.com',
      hasProfile: true, useExistingAccount: true);
    expect(result.code, 'sign-out-before-account-switch'); expect(auth.signIns, 0);
  });
  test('missing restored session never creates a replacement for cached profile', () async {
    final auth = Auth();
    final result = await SocialAuthService(auth: auth).connect('apple.com', hasProfile: true);
    expect(result.code, 'profile-session-mismatch'); expect(auth.signIns, 0);
  });
  test('cancellation preserves session', () async {
    final auth=Auth(); auth.user=Player('owner',auth);
    final result=await SocialAuthService(auth:auth,
      googleCredential: () async => throw PlatformException(code:'sign_in_canceled'))
      .connect('google.com',hasProfile:true);
    expect(result.status,SocialAuthStatus.canceled); expect(auth.currentUser!.uid,'owner');
  });
  test('session changes during Google prompt cannot attach to an obsolete user', () async {
    final auth=Auth(); final player=Player('owner',auth); auth.user=player;
    final result=await SocialAuthService(auth:auth,googleCredential:() async {
      auth.user=Player('different',auth);
      return GoogleAuthProvider.credential(idToken:'test');
    }).connect('google.com',hasProfile:true);
    expect(result.code,'profile-session-mismatch'); expect(player.links,0); expect(auth.signIns,0);
  });
  test('explicit sign in without an open profile still works', () async {
    final auth=Auth(); auth.user=Player('empty-guest',auth);
    final result=await SocialAuthService(auth:auth,
      googleCredential:() async=>GoogleAuthProvider.credential(idToken:'test'))
      .connect('google.com',hasProfile:false,useExistingAccount:true);
    expect(result.uid,'existing'); expect(auth.signIns,1);
  });
}
