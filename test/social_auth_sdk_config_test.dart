import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prono4/services/social_auth_service.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    test('production SDK construction preserves server client on $platform',
        () {
      debugDefaultTargetPlatformOverride = platform;

      final sdk = SocialAuthService.createGoogleSignIn();

      expect(sdk.clientId, isNull);
      expect(sdk.serverClientId, SocialAuthService.googleServerClientId);
      expect(sdk.scopes, ['email']);
    });
  }
}
