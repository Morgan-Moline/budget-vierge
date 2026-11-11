import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_budget/models.dart';
import 'package:mon_budget/screens/tutorial_screen.dart';

void main() {
  test('6 pages de base, plus une par module activé', () {
    expect(tutoPages({}).length, 6);
    expect(tutoPages({Module.x4, Module.credits}).map((p) => p.title),
        containsAllInOrder(['Paiements en 4×', 'Onglet Crédits', 'Modules et sauvegarde']));
    expect(tutoPages(Module.values.toSet()).length, 9);
  });

  testWidgets('on peut faire défiler le tuto jusqu’au bout, ou le passer', (tester) async {
    var done = 0;
    await tester.pumpWidget(MaterialApp(
      home: TutorialScreen(pages: tutoPages({}), doneLabel: 'Choisir mes modules', onDone: () => done++),
    ));
    expect(find.text('Le reste du mois'), findsOneWidget);
    expect(find.text('1 / 6'), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('Suivant'));
      await tester.pumpAndSettle();
    }
    expect(find.text('6 / 6'), findsOneWidget);
    expect(find.text('Passer'), findsNothing);
    await tester.tap(find.text('Choisir mes modules'));
    expect(done, 1);

    await tester.pumpWidget(MaterialApp(home: TutorialScreen(key: UniqueKey(), pages: tutoPages({}), onDone: () => done++)));
    await tester.tap(find.text('Passer'));
    expect(done, 2);
  });
}
