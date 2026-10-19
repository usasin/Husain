import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prono4/screens/permissions_welcome_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const ads = MethodChannel('plugins.flutter.io/google_mobile_ads');
  final adCalls = <String>[];
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    adCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ads, (call) async {
      adCalls.add(call.method);
      return null;
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ads, null);
  });

  testWidgets('iPhone keeps its permission choice before ads or the app', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: PermissionsWelcomeGate(child: Text('MATCHES_READY')),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Before you play'), findsOneWidget);
    expect(find.text('MATCHES_READY'), findsNothing);
    expect(find.text('Continue to PRONO4'), findsOneWidget);
    expect(adCalls, isEmpty);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Android continues directly to the existing application', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: PermissionsWelcomeGate(child: Text('MATCHES_READY')),
    ));
    await tester.pumpAndSettle();
    expect(find.text('MATCHES_READY'), findsOneWidget);
    expect(find.text('Before you play'), findsNothing);
    expect(adCalls, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
