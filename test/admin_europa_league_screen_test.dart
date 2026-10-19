import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:prono4/providers/app_provider.dart';
import 'package:prono4/screens/admin_europa_league_screen.dart';

class _Auth extends Fake implements FirebaseAuth {}
class _Admin extends AppProvider {
  _Admin(FirebaseFirestore db) : super(firestore: db, auth: _Auth());
  @override bool get adminMode => true;
  @override Future<bool> refreshAdminAccess() async => true;
}
class _Snapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this.rows);
  final List<Map<String, dynamic>> rows;
  @override Map<String, dynamic> data() => {'rows': rows};
  @override bool get exists => true;
}
class _Document extends Fake implements DocumentReference<Map<String, dynamic>> {
  _Document(this.events);
  final Stream<DocumentSnapshot<Map<String, dynamic>>> events;
  @override Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false, ListenSource source = ListenSource.defaultSource,
  }) => events;
}
class _Collection extends Fake implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.document);
  final _Document document;
  @override DocumentReference<Map<String, dynamic>> doc([String? path]) => document;
}
class _Database extends Fake implements FirebaseFirestore {
  _Database(List<Map<String, dynamic>> rows)
      : collectionValue = _Collection(_Document(Stream.value(_Snapshot(rows))));
  final _Collection collectionValue;
  @override CollectionReference<Map<String, dynamic>> collection(String path) => collectionValue;
}

Future<void> _open(WidgetTester tester, {List<Map<String, dynamic>> rows = const []}) async {
  final db = _Database(rows);
  await tester.pumpWidget(ChangeNotifierProvider<AppProvider>(
    create: (_) => _Admin(db),
    child: MaterialApp(home: AdminEuropaLeagueScreen(firestore: db)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Europa screen opens without any server function call', (tester) async {
    await _open(tester);
    expect(find.text('LIGUE EUROPA · ADMIN'), findsOneWidget);
    expect(find.text('Aucun match saisi. Appuie sur « Ajouter un match ».'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing a focused new-match dialog keeps its fields alive through the route transition', (tester) async {
    await _open(tester);
    await tester.tap(find.text('Ajouter un match'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Club à domicile'), 'Marseille');
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(find.text('Ajouter un match Europa'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing a focused score dialog keeps its fields alive through the route transition', (tester) async {
    await _open(tester, rows: [{
      'id': 'uel_0123456789abcdef0123456789abcdef',
      'homeName': 'Marseille', 'awayName': 'Lyon',
      'kickoffAtMs': 1700000000000, 'allowsDraw': true,
    }]);
    await tester.tap(find.text('Saisir le score'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Domicile'), '2');
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(find.text('Résultat officiel'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('back button closes a focused form and it can be reopened', (tester) async {
    await _open(tester);
    for (var attempt = 0; attempt < 2; attempt++) {
      await tester.tap(find.text('Ajouter un match'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Club à domicile'), 'Marseille');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Ajouter un match Europa'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('saving the form closes it safely even when Firebase is unavailable', (tester) async {
    await _open(tester);
    await tester.tap(find.text('Ajouter un match'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Club à domicile'), 'Marseille');
    await tester.enterText(find.widgetWithText(TextField, 'Club à l’extérieur'), 'Lyon');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('Ajouter un match Europa'), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
