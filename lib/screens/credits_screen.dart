import 'package:flutter/material.dart';

import '../calc.dart';
import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../widgets/common.dart';
import '../widgets/edit_sheet.dart';
import 'budget_screen.dart';

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key, required this.store, required this.now});

  final BudgetStore store;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final d = store.data;
    final cur = monthIndexOf(now);
    final loan = loanInfo(d, now);
    final verse = d.versements.fold(0.0, (a, v) => a + v.amount);
    var resteDette = round2(d.detteTotal - verse);
    if (resteDette < 0) resteDette = 0;
    final emprunts = currentLines(d, 'emprunts').where((l) => isActive(l, cur)).toList();
    final restantDu = emprunts.fold(
        0.0, (a, l) => a + (remainingMonths(l, cur) ?? 0) * (l.amount ?? 0));
    final vers = [...d.versements]..sort((a, b) => b.date.compareTo(a.date));
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _BigCard(
          title: 'Reste emprunt',
          subtitle: d.pretDate.isEmpty ? 'Date de départ non renseignée' : 'Depuis le ${dateLong(d.pretDate)}',
          action: TextButton(onPressed: () => _editLoan(context), child: const Text('Modifier')),
          value: money(loan.reste),
          meter: Meter(
            value: loan.progress,
            left: Caption('Remboursé', money(loan.rembourse), after: ' · ${(loan.progress * 100).round()} %'),
            right: loan.endMonth == null
                ? null
                : Caption('Fin estimée', monthLong(loan.endMonth! - 1)),
          ),
          details: [
            ('Montant', money(loan.montant)),
            ('Mensualité', money(loan.mensualite)),
            ('Mensualités passées', '${loan.paidMonths}'),
          ],
        ),
        const SizedBox(height: 14),
        _BigCard(
          title: 'Remboursement',
          subtitle: '${d.versements.length} versement${d.versements.length > 1 ? 's' : ''}',
          action: TextButton(onPressed: () => _editDette(context), child: const Text('Modifier la dette')),
          value: money(resteDette),
          meter: Meter(
            value: d.detteTotal > 0 ? verse / d.detteTotal : 0,
            left: Caption('Remboursé', money(verse),
                after: d.detteTotal > 0 ? ' · ${(verse / d.detteTotal * 100).clamp(0, 100).round()} %' : ''),
            right: Caption('Dette', money(d.detteTotal)),
          ),
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () => _editVersement(context, null),
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter un remboursement'),
                  ),
                ),
              ),
              for (final v in vers)
                LineRow(
                  key: ValueKey(v.id),
                  label: v.date.isEmpty ? 'Sans date' : dateLong(v.date),
                  subtitle: v.note,
                  amount: v.amount,
                  onTap: () => _editVersement(context, v),
                ),
            ],
          ),
        ),
        if (d.has(Module.emprunts)) ...[
          const SizedBox(height: 14),
          SectionLinesCard(
            store: store,
            sec: sectionByKey('emprunts'),
            current: cur,
            title: 'Crédits en cours',
            subtitle: 'Restant dû estimé ${money(restantDu)}',
            total: '${money(sumLines(emprunts))}/mois',
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'Le reste de l’emprunt enlève une mensualité pour chaque mois passé depuis la date de départ.',
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  Future<void> _editLoan(BuildContext context) async {
    final d = store.data;
    final r = await showEditSheet(
      context,
      const EditSpec(
        title: 'Reste emprunt',
        showLabel: false,
        dateField: DateField.date,
        dateName: 'Date de départ',
        amountName: 'Montant restant à cette date (€)',
        amount2Name: 'Mensualité (€)',
      ),
      EditValues(
        date: d.pretDate,
        amount: amountText(d.pretMontant, null),
        amount2: amountText(d.pretMensualite, null),
      ),
    );
    if (r == null) return;
    store.update((d) {
      d.pretDate = r.date;
      d.pretMontant = r.amount ?? 0;
      d.pretMensualite = r.amount2 ?? 0;
    });
  }

  Future<void> _editDette(BuildContext context) async {
    final r = await showEditSheet(
      context,
      const EditSpec(title: 'Remboursement', showLabel: false, amountName: 'Montant total à rembourser (€)'),
      EditValues(amount: amountText(store.data.detteTotal, null)),
    );
    if (r == null) return;
    store.update((d) => d.detteTotal = r.amount ?? 0);
  }

  Future<void> _editVersement(BuildContext context, Versement? v) async {
    final r = await showEditSheet(
      context,
      EditSpec(
        title: v == null ? 'Nouveau remboursement' : 'Remboursement',
        showLabel: false,
        amountName: 'Montant remboursé (€)',
        amountRequired: 'Indique le montant remboursé.',
        dateField: DateField.date,
        showNote: true,
        noteName: 'Commentaire',
        canDelete: v != null,
        deleteText: 'Supprimer ce remboursement ?',
      ),
      v == null
          ? EditValues(date: isoDate(now))
          : EditValues(amount: amountText(v.amount, null), date: v.date, note: v.note),
    );
    if (r == null) return;
    store.update((d) {
      if (r.delete) {
        d.versements.remove(v);
        return;
      }
      final o = v ?? Versement(amount: 0);
      o.amount = r.amount ?? 0;
      o.date = r.date;
      o.note = r.note;
      if (v == null) d.versements.add(o);
    });
  }
}

class _BigCard extends StatelessWidget {
  const _BigCard({
    required this.title,
    required this.subtitle,
    required this.action,
    required this.value,
    required this.meter,
    this.details = const [],
    this.footer,
  });

  final String title;
  final String subtitle;
  final Widget action;
  final String value;
  final Widget meter;
  final List<(String, String)> details;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          Text(subtitle, style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    action,
                  ],
                ),
                const SizedBox(height: 10),
                Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -.5)),
                const SizedBox(height: 12),
                Padding(padding: const EdgeInsets.only(right: 8), child: meter),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 24,
                    runSpacing: 8,
                    children: [
                      for (final (k, v) in details)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(k, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                            Text(v, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ],
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (footer != null) footer!,
        ],
      ),
    );
  }
}
