import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prono4/services/social_auth_service.dart';

class _Auth extends Fake implements FirebaseAuth {
  User? user;
  int signIns = 0;

  @override
  User? get currentUser => user;

  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    signIns += 1;
    user = _Guest('unexpected-replacement');
    return _Credential(user!);
  }
}

class _Guest extends Fake implements User {
  @override
  final String uid;
  int links = 0;
  AuthCredential? linkedCredential;
  Object? linkFailure;

  _Guest(this.uid);

  @override
  bool get isAnonymous => true;

  @override
  List<UserInfo> get providerData => [];

  @override
  Future<UserCredential> linkWithCredential(AuthCredential credential) async {
    links += 1;
    linkedCredential = credential;
    if (linkFailure != null) throw linkFailure!;
    return _Credential(this);
  }
}

class _Credential extends Fake implements UserCredential {
  final User _user;
  _Credential(this._user);

  @override
  User get user => _user;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/google_sign_in');
  final calls = <MethodCall>[];
  late _Auth auth;
  late _Guest guest;
  var cancelPrompt = false;
  String? idToken;
  PlatformException? promptFailure;
  VoidCallback? duringPrompt;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    auth = _Auth();
    guest = _Guest('original-guest-uid');
    auth.user = guest;
    calls.clear();
    cancelPrompt = false;
    idToken = 'sdk-test-id-token';
    promptFailure = null;
    duringPrompt = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'init':
        case 'signOut':
          return null;
        case 'signIn':
          duringPrompt?.call();
          if (promptFailure != null) throw promptFailure!;
          if (cancelPrompt) return null;
          return {
            'id': 'selected-google-account',
            'email': 'selected@example.invalid',
            'displayName': 'Selected Google account',
          };
        case 'getTokens':
          return {
            'idToken': idToken,
            'accessToken': 'sdk-test-access-token',
          };
        default:
          throw StateError('Unexpected Google SDK call: ${call.method}');
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('real SDK initialization delegates the iPhone client to native config',
      () async {
    // No credential/factory injection: exercise the production GoogleSignIn
    // constructor, its initialization and account.authentication token request.
    final result = await SocialAuthService(auth: auth)
        .connect('google.com', hasProfile: true);

    expect(result.status, SocialAuthStatus.connected);
    expect(result.uid, guest.uid);
    expect(auth.currentUser?.uid, guest.uid);
    expect(auth.signIns, 0);
    expect(guest.links, 1);
    expect(calls.map((call) => call.method),
        ['init', 'signOut', 'signIn', 'getTokens']);
    final init = Map<String, dynamic>.from(calls.first.arguments as Map);
    expect(init['clientId'], isNull,
        reason:
            'The validated iPhone plist must choose the native OAuth client; '
            'an explicit Dart client overrides it in google_sign_in_ios.');
    expect(init['serverClientId'], SocialAuthService.googleServerClientId);
    expect(init['scopes'], ['email']);
    final tokenRequest =
        calls.singleWhere((call) => call.method == 'getTokens');
    expect(
        (tokenRequest.arguments as Map)['email'], 'selected@example.invalid');
    final credential = guest.linkedCredential! as OAuthCredential;
    expect(credential.providerId, 'google.com');
    expect(credential.idToken, 'sdk-test-id-token');
    expect(credential.accessToken, 'sdk-test-access-token');
  });

  test('canceling the actual SDK account prompt keeps the guest session',
      () async {
    cancelPrompt = true;

    final result = await SocialAuthService(auth: auth)
        .connect('google.com', hasProfile: true);

    expect(result.status, SocialAuthStatus.canceled);
    expect(auth.currentUser?.uid, guest.uid);
    expect(auth.signIns, 0);
    expect(guest.links, 0);
    expect(calls.map((call) => call.method), ['signOut', 'signIn']);
  });

  test('SDK cancellation exceptions cannot replace the guest account',
      () async {
    promptFailure = PlatformException(code: 'sign_in_canceled');

    final result = await SocialAuthService(auth: auth)
        .connect('google.com', hasProfile: false);

    expect(result.status, SocialAuthStatus.canceled);
    expect(auth.currentUser?.uid, guest.uid);
    expect(auth.signIns, 0);
    expect(guest.links, 0);
    expect(calls.any((call) => call.method == 'getTokens'), isFalse);
  });

  test('a Google credential conflict after token acquisition keeps guest UID',
      () async {
    guest.linkFailure =
        FirebaseAuthException(code: 'credential-already-in-use');

    final result = await SocialAuthService(auth: auth)
        .connect('google.com', hasProfile: true);

    expect(result.status, SocialAuthStatus.conflict);
    expect(result.code, 'credential-already-in-use');
    expect(auth.currentUser?.uid, guest.uid);
    expect(auth.signIns, 0);
    expect(guest.links, 1);
    expect(
        calls.map((call) => call.method), ['signOut', 'signIn', 'getTokens']);
  });

  test('a missing SDK ID token fails before any Firebase account mutation',
      () async {
    idToken = null;

    final result = await SocialAuthService(auth: auth)
        .connect('google.com', hasProfile: true);

    expect(result.status, SocialAuthStatus.failed);
    expect(result.code, 'missing-id-token');
    expect(auth.currentUser?.uid, guest.uid);
    expect(auth.signIns, 0);
    expect(guest.links, 0);
  });

  test('session changes during the SDK prompt cannot link an obsolete guest',
      () async {
    duringPrompt = () => auth.user = _Guest('new-session-uid');

    final result = await SocialAuthService(auth: auth)
        .connect('google.com', hasProfile: true);

    expect(result.status, SocialAuthStatus.failed);
    expect(result.code, 'profile-session-mismatch');
    expect(auth.currentUser?.uid, 'new-session-uid');
    expect(auth.signIns, 0);
    expect(guest.links, 0);
  });
}
