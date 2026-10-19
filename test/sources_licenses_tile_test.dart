import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/widgets/sources_licenses_tile.dart';

void main() {
  testWidgets('credits stay collapsed, links work and dialog closes in a small dark screen', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final links = <Uri>[];
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('fr'),
      theme: ThemeData.dark(),
      home: Scaffold(body: SourcesLicensesTile(openLink: (uri) async {
        links.add(uri);
        return true;
      })),
    ));
    expect(find.text('OpenLigaDB'), findsNothing);
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('OpenLigaDB'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('ODbL', findRichText: true).last);
    await tester.pumpAndSettle();
    expect(links.map((u) => u.toString()).toList(), [
      'https://www.openligadb.de/',
      'https://opendatacommons.org/licenses/odbl/1-0/',
    ]);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
