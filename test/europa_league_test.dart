import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prono4/data/competitions_data.dart';
import 'package:prono4/widgets/competition_emblem.dart';

void main() {
  const previous = [
    'ligue-1',
    'premier-league',
    'serie-a',
    'bundesliga',
    'la-liga',
    'champions-league',
    'euro'
  ];
  test('Europa League is the only new competition, managed manually', () {
    expect(
        kCompetitions.map((c) => c.id).toSet(), {...previous, 'europa-league'});
    expect(kCompetitions.where((c) => c.manualResults).map((c) => c.id),
        ['europa-league']);
    expect(competitionById('europa-league')!.emblemAsset, isNotNull);
  });
  test('An existing all-competitions preference gains Europa League once', () {
    expect(
        restoreCompetitionSelection(previous), {...previous, 'europa-league'});
  });
  test(
      'A personal subset and a later explicit Europa deselection survive restoration',
      () {
    expect(restoreCompetitionSelection(['ligue-1']), {'ligue-1'});
    expect(
        restoreCompetitionSelection(previous,
            knownCatalog: [...previous, 'europa-league']),
        previous.toSet());
  });
  testWidgets(
      'Europa League emblem renders from the bundled asset without network images',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Center(
            child: SizedBox(
                width: 48,
                height: 48,
                child: CompetitionEmblem(
                    competition: competitionById('europa-league')!)))));
    await tester.pumpAndSettle();
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
