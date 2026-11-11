import 'package:flutter/material.dart';

import '../calc.dart';
import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../widgets/common.dart';
import '../widgets/edit_sheet.dart';

/// "Mois suivant": next month prepared in advance; it replaces the "Mois" tab on the 1st.
class NextMonthScreen extends StatelessWidget {
  const NextMonthScreen({super.key, required this.store, required this.now});

  final BudgetStore store;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final d = store.data;
    final cur = monthIndexOf(now);
    final t = computeNextTotals(d, now);
    final nxtName = monthNames[t.month % 12];
    final curName = monthNames[cur % 12];
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _NextHero(totals: t, curName: curName, nxtName: nxtName),
        const SizedBox(height: 12),
        Text(
          'Ce que tu modifies ici remplacera l’onglet Mois le 1er $nxtName. '
          'Les lignes non modifiées suivent le mois en cours. Les autres dépenses repartent de zéro.',
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
        ),
        if (t.ending.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Se terminent en $curName : ${t.ending.map((e) => '${e.$2.label} (${money(e.$2.amount)})').join(', ')}',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ],
        for (final sec in sections.where(store.data.shows)) ...[
          const SizedBox(height: 14),
          _section(context, sec, t, nxtName),
        ],
      ],
    );
  }

  Widget _section(BuildContext context, SectionDef sec, NextTotals t, String nxtName) {
    final d = store.data;
    final lines = nextLines(d, sec, t.month);
    final dropped = droppedLines(d, sec);
    final changed = lines.where((l) => l.onlyNext || l.next != null).length + dropped.length;
    final sub = sec.key == 'autres'
        ? 'Repart de zéro le 1er $nxtName'
        : changed == 0
            ? 'Comme ce mois-ci'
            : '$changed modification${changed > 1 ? 's' : ''}';
    return SectionCard(
      title: sec.title,
      subtitle: sub,
      total: money(t.bySection[sec.key]),
      addTooltip: 'Ajouter dans ${sec.title} en $nxtName',
      onAdd: () => editNextLine(context, store, sec, null),
      emptyText: sec.key == 'autres'
          ? 'Aucune dépense prévue. Ajoute celles de $nxtName avec +.'
          : 'Aucune ligne. Ajoute-en une avec +.',
      children: [
        for (final l in lines)
          LineRow(
            key: ValueKey('n-${l.id}'),
            label: l.label,
            amount: nextAmount(l),
            subtitle: _subtitle(sec, l, t.month),
            badge: l.onlyNext
                ? const Pill('Nouveau', tone: Tone.accent)
                : (l.next != null ? const Pill('Modifié', tone: Tone.warn) : null),
            onTap: () => editNextLine(context, store, sec, l),
          ),
        for (final l in dropped)
          LineRow(
            key: ValueKey('d-${l.id}'),
            label: l.label,
            amount: l.amount,
            ended: true,
            subtitle: 'Retiré de $nxtName · touche pour le remettre',
            onTap: () async {
              final ok = await confirmAction(
                context,
                title: 'Remettre la ligne',
                message: 'Remettre « ${l.label} » dans le mois de $nxtName ?',
                okLabel: 'Remettre',
              );
              if (ok) store.update((_) => l.dropNext = false);
            },
          ),
      ],
    );
  }

  String? _subtitle(SectionDef sec, Line l, int month) {
    final parts = <String>[];
    if (!l.onlyNext && l.next != null) parts.add('Ce mois-ci : ${money(l.amount)}');
    final endIdx = parseMonthIndex(l.end);
    if (sec.end != EndKind.none && endIdx != null) {
      parts.add(endSummary(l, sec.end, month));
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

class _NextHero extends StatelessWidget {
  const _NextHero({required this.totals, required this.curName, required this.nxtName});

  final NextTotals totals;
  final String curName;
  final String nxtName;

  @override
  Widget build(BuildContext context) {
    final t = totals;
    final cs = Theme.of(context).colorScheme;
    final p = Palette(context);
    final pos = t.reste >= 0;
    Widget stat(String k, String v) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(k, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(v, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Reste prévu en $nxtName', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          money(t.reste),
                          style: TextStyle(
                            fontSize: 42,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.5,
                            color: p.fg(pos ? Tone.good : Tone.bad),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Pill('Prévision', tone: Tone.accent),
              ],
            ),
            const SizedBox(height: 16),
            Row(children: [
              stat('Entrées', money(t.entrees)),
              stat('Sorties', money(t.sorties)),
              stat('Report de $curName', signedMoney(t.report)),
            ]),
            const SizedBox(height: 10),
            Text(
              t.report < 0
                  ? 'Le reste de $curName deviendra ton découvert de début de mois.'
                  : 'Le reste de $curName deviendra ton positif de début de mois.',
              style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Edits a line of the "Mois suivant" tab.
/// A line of the current month only gets a new amount for next month (or is removed from it);
/// a line added for next month is fully editable.
Future<void> editNextLine(BuildContext context, BudgetStore store, SectionDef sec, Line? line) async {
  final nxt = monthIndexOf(DateTime.now()) + 1;
  final nxtName = monthNames[nxt % 12];
  if (line != null && !line.onlyNext) {
    final r = await showEditSheet(
      context,
      EditSpec(
        title: '${line.label} · $nxtName',
        showLabel: false,
        amountName: 'Montant en $nxtName (€)',
        amountHint: 'Ce mois-ci : ${money(line.amount)}. Pour additionner, utilise les boutons + − × ÷',
        canDelete: true,
        deleteLabel: 'Retirer de $nxtName',
        deleteText: 'Retirer « ${line.label} » du mois de $nxtName ? Il reste dans le mois en cours.',
      ),
      EditValues(
        amount: line.next != null ? amountText(line.next, line.nextExpr) : amountText(line.amount, line.expr),
      ),
    );
    if (r == null) return;
    store.update((_) {
      if (r.delete) {
        line.dropNext = true;
        return;
      }
      final v = r.amount ?? 0;
      if (round2(v) == round2(line.amount ?? 0)) {
        line.next = null;
        line.nextExpr = null;
      } else {
        line.next = v;
        line.nextExpr = r.expr;
      }
    });
    return;
  }

  final isNew = line == null;
  final r = await showEditSheet(
    context,
    EditSpec(
      title: isNew ? 'Ajouter en $nxtName : ${sec.title}' : '${sec.title} · $nxtName',
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
      canDelete: !isNew,
      deleteText: 'Supprimer « ${line?.label ?? ''} » du mois de $nxtName ?',
    ),
    isNew
        ? EditValues()
        : EditValues(label: line.label, amount: amountText(line.amount, line.expr), date: line.end ?? ''),
  );
  if (r == null) return;
  store.update((d) {
    if (r.delete) {
      d.section(sec.key).remove(line);
      return;
    }
    final l = line ?? Line(onlyNext: true);
    l.label = r.label;
    l.amount = r.amount ?? 0;
    l.expr = r.expr;
    if (sec.end != EndKind.none) l.end = r.date.isEmpty ? null : r.date;
    if (isNew) d.section(sec.key).add(l);
  });
}
