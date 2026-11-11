import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mon_budget/calc.dart';
import 'package:mon_budget/models.dart';

/// Budget fictif d'exemple, tous modules activés.
BudgetData exemple() => BudgetData(
      modules: {...Module.values},
      onboarded: true,
      lines: {
        'entrees': [Line(label: 'Salaire', amount: 2000), Line(label: 'Prime', amount: 100)],
        'fixes': [
          Line(label: 'Loyer', amount: 700, paid: true),
          Line(label: 'Électricité', amount: 80, paid: true),
          Line(label: 'Assurance', amount: 40),
        ],
        'abonnements': [Line(label: 'Streaming', amount: 15, paid: true), Line(label: 'Musique', amount: 10)],
        'x4': [
          Line(label: 'Téléphone', amount: 50, end: '2026-11-15'),
          Line(label: 'Canapé', amount: 100, end: '2027-02-01'),
        ],
        'emprunts': [Line(label: 'Voiture', amount: 200, end: '2027-12')],
        'aleatoires': [Line(label: 'Courses', amount: 300), Line(label: 'Essence', amount: 100)],
        'autres': [Line(label: 'Cadeau', amount: 30), Line(label: 'Restaurant', amount: 45)],
      },
      decouvert: 100,
      pretDate: '2026-05-25',
      pretMontant: 1200,
      pretMensualite: 100,
      detteTotal: 1000,
    );

void main() {
  final nov = DateTime(2026, 11, 11);

  test('reste du mois = entrées − sorties − découvert + positif', () {
    final t = computeTotals(exemple(), nov);
    expect(t.entrees, 2100);
    expect(t.sorties, 1670);
    expect(t.reste, 330);
    expect(t.paidCount, 3);
  });

  test('un paiement en 4× terminé ne compte plus le mois suivant', () {
    final d = exemple();
    final a = computeTotals(d, nov), b = computeTotals(d, DateTime(2026, 12, 5));
    expect(a.bySection['x4']! - b.bySection['x4']!, 50);
  });

  test('reste emprunt', () {
    final l = loanInfo(exemple(), nov);
    expect(l.paidMonths, 5);
    expect(l.reste, 700);
  });

  test('montants avec calcul', () {
    expect(evalAmount('0,5+0,9+0,7').value, 2.1);
    expect(evalAmount('=9.47-7.99').value, 1.48);
    expect(evalAmount('44,99*2').value, 89.98);
    expect(evalAmount('12,50').value, 12.5);
    expect(evalAmount('12,50').expr, isNull);
    expect(evalAmount('').value, isNull);
    expect(evalAmount('abc').error, isNotNull);
    expect(evalAmount('5+').error, isNotNull);
  });

  test('la sauvegarde JSON se relit à l’identique', () {
    final d = exemple();
    final again = BudgetData.fromJson(jsonDecode(jsonEncode(d.toJson())) as Map<String, dynamic>);
    expect(jsonEncode(again.toJson()), jsonEncode(d.toJson()));
    expect(again.modules, Module.values.toSet());
  });

  test('mois suivant : reprend le mois, sans autres dépenses ni paiements terminés', () {
    final t = computeNextTotals(exemple(), nov);
    expect(t.bySection['autres'], 0);
    expect(t.ending.map((e) => e.$2.label), ['Téléphone']);
    expect(t.report, 330);
    expect(t.reste, 2100 - 1545 + 330);
  });

  test('le 1er du mois, le mois suivant passe dans Mois', () {
    final d = exemple();
    expect(rolloverIfNeeded(d, nov), isTrue); // pose le mois courant
    expect(rolloverIfNeeded(d, DateTime(2026, 11, 30)), isFalse);

    final courses = d.section('aleatoires').first;
    courses.next = 250;
    d.section('abonnements').first.dropNext = true; // Streaming
    d.section('autres').add(Line(label: 'Sapin', amount: 60, onlyNext: true));
    d.section('abonnements').add(Line(label: 'Sport', amount: 20, onlyNext: true));

    expect(computeTotals(d, nov).reste, 330);
    final prevu = computeNextTotals(d, nov);

    expect(rolloverIfNeeded(d, DateTime(2026, 12, 1)), isTrue);
    expect(d.month, '2026-12');
    expect(courses.amount, 250);
    expect(d.section('abonnements').map((l) => l.label), ['Musique', 'Sport']);
    expect(d.section('autres').map((l) => l.label), ['Sapin']);
    expect(d.section('x4').map((l) => l.label), ['Canapé']);
    expect(d.section('fixes').every((l) => !l.paid), isTrue);
    expect(d.positif, 330);
    expect(d.decouvert, 0);
    expect(computeTotals(d, DateTime(2026, 12, 1)).reste, prevu.reste);
  });

  test('un mois négatif devient le découvert de début de mois', () {
    final d = exemple();
    rolloverIfNeeded(d, nov);
    d.section('autres').add(Line(label: 'Réparation', amount: 400));
    expect(computeTotals(d, nov).reste, -70);
    rolloverIfNeeded(d, DateTime(2026, 12, 2));
    expect(d.decouvert, 70);
    expect(d.positif, 0);
  });

  test('un module retiré ne compte plus, et revient avec ses lignes', () {
    final d = exemple();
    d.modules.remove(Module.x4);
    expect(computeTotals(d, nov).reste, 480);
    expect(d.section('x4').length, 2);
    d.modules.add(Module.x4);
    expect(computeTotals(d, nov).reste, 330);
  });

  test('une app neuve est vide', () {
    final d = BudgetData();
    expect(d.onboarded, isFalse);
    expect(d.modules, isEmpty);
    expect(computeTotals(d, nov).reste, 0);
  });

  test('les paiements en 4× se cochent et se décochent le 1er du mois', () {
    final d = exemple();
    rolloverIfNeeded(d, nov);
    final avant = computeTotals(d, nov);
    d.section('x4').last.paid = true; // Canapé, 100 €
    final apres = computeTotals(d, nov);
    expect(apres.paidCount, avant.paidCount + 1);
    expect(apres.checkPaid - avant.checkPaid, 100);
    expect(apres.reste, avant.reste);
    rolloverIfNeeded(d, DateTime(2026, 12, 1));
    expect(d.section('x4').last.paid, isFalse);
  });
}

