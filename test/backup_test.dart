import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_budget/models.dart';
import 'package:mon_budget/screens/backup_screen.dart';
import 'package:mon_budget/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

BudgetData avecLignes() => BudgetData(onboarded: true, tutoSeen: true, lines: {
      'entrees': [Line(label: 'Salaire', amount: 2000)],
      'fixes': [Line(label: 'Loyer', amount: 700)],
      'aleatoires': [Line(label: 'Courses', amount: 300)],
    });

void main() {
  final now = DateTime(2026, 11, 11);

  test('pas de rappel pour un budget presque vide', () {
    expect(needsBackupReminder(BudgetData(), now), isFalse);
  });

  test('rappel si jamais sauvegardé, ou il y a plus de 30 jours', () {
    final d = avecLignes();
    expect(needsBackupReminder(d, now), isTrue);
    d.lastBackup = '2026-10-20';
    expect(needsBackupReminder(d, now), isFalse);
    d.lastBackup = '2026-10-01';
    expect(needsBackupReminder(d, now), isTrue);
  });

  test('« Plus tard » cache le rappel pendant une semaine', () {
    final d = avecLignes()..backupSnooze = '2026-11-18';
    expect(needsBackupReminder(d, now), isFalse);
    expect(needsBackupReminder(d, DateTime(2026, 11, 18)), isTrue);
  });

  test('le nom du fichier contient la date', () {
    expect(backupFileName(now), 'mon-budget-2026-11-11.json');
  });

  test('une sauvegarde se relit avec ses lignes et sa date', () {
    final d = avecLignes()..lastBackup = '2026-11-11';
    final again = BudgetData.fromJson(jsonDecode(jsonEncode(d.toJson())) as Map<String, dynamic>);
    expect(again.lastBackup, '2026-11-11');
    expect(again.section('fixes').single.label, 'Loyer');
  });

  testWidgets('hors web, l’écran Sauvegarde propose le copier-coller', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await BudgetStore.load();
    await tester.pumpWidget(MaterialApp(home: BackupScreen(store: store)));
    expect(find.text('Copier la sauvegarde'), findsOneWidget);
    expect(find.text('Coller une sauvegarde'), findsOneWidget);
    expect(find.text('Télécharger une sauvegarde'), findsNothing);
    expect(find.text('Aucune sauvegarde pour l’instant.'), findsOneWidget);
  });
}
