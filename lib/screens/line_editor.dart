import 'package:flutter/material.dart';

import '../calc.dart';
import '../models.dart';
import '../store.dart';
import '../widgets/common.dart';
import '../widgets/edit_sheet.dart';

/// Opens the edit sheet for a line of a budget section (new line when [line] is null).
Future<void> editSectionLine(
    BuildContext context, BudgetStore store, SectionDef sec, Line? line) async {
  final isNew = line == null;
  final r = await showEditSheet(
    context,
    EditSpec(
      title: isNew ? 'Ajouter : ${sec.title}' : sec.title,
      amountName: switch (sec.key) {
        'x4' => 'Montant d’une échéance (€)',
        'emprunts' => 'Mensualité (€)',
        _ => 'Montant (€)',
      },
      dateField: switch (sec.end) {
        EndKind.date => DateField.date,
        EndKind.month => DateField.month,
        EndKind.none => DateField.none,
      },
      dateName: sec.end == EndKind.date ? 'Date de la dernière échéance' : 'Mois de la dernière mensualité',
      dateHint: sec.end == EndKind.date
          ? 'La ligne ne compte plus dans le budget après ce mois.'
          : 'Facultatif. Exemple : 2027-12',
      toggleName: sec.check ? 'Déjà prélevé ce mois-ci' : null,
      canDelete: !isNew,
      deleteText: 'Supprimer « ${line?.label ?? ''} » ?',
    ),
    isNew
        ? EditValues()
        : EditValues(
            label: line.label,
            amount: amountText(line.amount, line.expr),
            date: line.end ?? '',
            toggle: line.paid,
          ),
  );
  if (r == null) return;
  if (r.delete) {
    store.update((d) => d.section(sec.key).remove(line));
    if (context.mounted) toast(context, 'Supprimé');
    return;
  }
  store.update((d) {
    final l = line ?? Line();
    l.label = r.label;
    l.amount = r.amount ?? 0;
    l.expr = r.expr;
    if (sec.end != EndKind.none) l.end = r.date.isEmpty ? null : r.date;
    if (sec.check) l.paid = r.toggle;
    if (isNew) d.section(sec.key).add(l);
  });
}
