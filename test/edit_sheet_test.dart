import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_budget/widgets/edit_sheet.dart';

void main() {
  testWidgets('les boutons + permettent d’additionner des montants', (tester) async {
    EditResult? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await showEditSheet(context, const EditSpec(title: 'Courses'), EditValues(label: 'Courses'));
            },
            child: const Text('ouvrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    final amount = find.widgetWithText(TextField, 'Montant (€)');
    await tester.enterText(amount, '17,46');
    await tester.tap(find.text('+'));
    await tester.pump();
    final field = tester.widget<TextField>(amount);
    field.controller!.selection = TextSelection.collapsed(offset: field.controller!.text.length);
    await tester.enterText(amount, '${field.controller!.text}9,55');
    expect(field.controller!.text, '17,46+9,55');

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(result?.amount, 27.01);
  });
}
