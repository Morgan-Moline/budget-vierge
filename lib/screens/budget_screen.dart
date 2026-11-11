import 'package:flutter/material.dart';

import '../calc.dart';
import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../widgets/common.dart';
import '../widgets/edit_sheet.dart';
import 'line_editor.dart';

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key, required this.store, required this.now});

  final BudgetStore store;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final d = store.data;
    final t = computeTotals(d, now);
    final cur = monthIndexOf(now);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _Hero(totals: t, data: d),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _StartTile(store: store, field: _StartField.decouvert)),
            const SizedBox(width: 10),
            Expanded(child: _StartTile(store: store, field: _StartField.positif)),
          ],
        ),
        for (final sec in sections.where(store.data.shows)) ...[
          const SizedBox(height: 14),
          SectionLinesCard(store: store, sec: sec, current: cur, totals: t),
        ],
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.restart_alt),
            label: const Text('Nouveau mois : tout décocher'),
            onPressed: () async {
              final ok = await confirmAction(
                context,
                title: 'Commencer un nouveau mois',
                message:
                    'Toutes les cases « prélevé » des charges fixes, abonnements et emprunts seront décochées. Les montants ne changent pas.',
                okLabel: 'Tout décocher',
              );
              if (!ok) return;
              store.update((d) {
                for (final k in ['fixes', 'abonnements', 'emprunts']) {
                  for (final l in d.section(k)) {
                    l.paid = false;
                  }
                }
              });
              if (context.mounted) toast(context, 'Cases décochées');
            },
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Reste du mois = entrées − charges fixes − abonnements − paiements 4× − emprunts − charges aléatoires − autres dépenses − découvert + positif. Les paiements en 4× et emprunts terminés ne comptent plus.',
          style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.totals, required this.data});

  final Totals totals;
  final BudgetData data;

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
                      Text('Reste du mois',
                          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
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
                Pill(pos ? 'Budget positif' : 'Dans le rouge', tone: pos ? Tone.good : Tone.bad),
              ],
            ),
            const SizedBox(height: 16),
            Row(children: [
              stat('Entrées', money(t.entrees)),
              stat('Sorties', money(t.sorties)),
              stat('Solde de départ', signedMoney(data.positif - data.decouvert)),
            ]),
            const SizedBox(height: 16),
            Meter(
              value: t.checkTotal > 0 ? t.checkPaid / t.checkTotal : 0,
              left: Caption('Prélevé', money(t.checkPaid), after: ' · ${t.paidCount}/${t.checkCount}'),
              right: Caption('Reste à prélever', money(t.checkTotal - t.checkPaid)),
            ),
          ],
        ),
      ),
    );
  }
}

enum _StartField { decouvert, positif }

class _StartTile extends StatelessWidget {
  const _StartTile({required this.store, required this.field});

  final BudgetStore store;
  final _StartField field;

  (Tone, String) _level(double d) {
    if (d <= 0) return (Tone.good, 'Aucun découvert');
    if (d <= 50) return (Tone.good, 'Léger');
    if (d <= 150) return (Tone.warn, 'À surveiller');
    if (d <= 250) return (Tone.serious, 'Élevé');
    return (Tone.bad, 'Très élevé');
  }

  @override
  Widget build(BuildContext context) {
    final d = store.data;
    final isDec = field == _StartField.decouvert;
    final value = isDec ? d.decouvert : d.positif;
    final title = isDec ? 'Découvert début de mois' : 'Positif début de mois';
    final (tone, txt) = isDec ? _level(value) : (Tone.neutral, 'Ajouté au reste');
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          final r = await showEditSheet(
            context,
            EditSpec(title: title, showLabel: false, amountName: '$title (€)'),
            EditValues(amount: amountText(value == 0 ? null : value, null)),
          );
          if (r == null) return;
          store.update((d) {
            final v = (r.amount ?? 0).abs();
            if (isDec) {
              d.decouvert = v;
            } else {
              d.positif = v;
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
              const SizedBox(height: 6),
              Text(money(value), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Pill(txt, tone: tone),
            ],
          ),
        ),
      ),
    );
  }
}

/// A section of budget lines (also used on the Crédits tab for loans).
class SectionLinesCard extends StatelessWidget {
  const SectionLinesCard({
    super.key,
    required this.store,
    required this.sec,
    required this.current,
    this.totals,
    this.title,
    this.subtitle,
    this.total,
  });

  final BudgetStore store;
  final SectionDef sec;
  final int current;
  final Totals? totals;
  final String? title;
  final String? subtitle;
  final String? total;

  @override
  Widget build(BuildContext context) {
    final items = currentLines(store.data, sec.key);
    final active = items.where((l) => isActive(l, current)).toList();
    final totalValue = sec.income ? sumLines(items) : sumLines(active);
    String sub;
    if (sec.check) {
      final paid = active.where((l) => l.paid).length;
      sub = '$paid/${active.length} prélevé${paid > 1 ? 's' : ''}';
    } else if (sec.end != EndKind.none) {
      sub = '${active.length} en cours';
    } else {
      sub = sec.subtitle ?? '${items.length} ligne${items.length > 1 ? 's' : ''}';
    }
    return SectionCard(
      title: title ?? sec.title,
      subtitle: subtitle ?? sub,
      total: total ?? money(totalValue),
      addTooltip: 'Ajouter dans ${sec.title}',
      onAdd: () => editSectionLine(context, store, sec, null),
      children: [for (final l in items) _row(context, l)],
    );
  }

  Widget _row(BuildContext context, Line l) {
    final active = isActive(l, current);
    String? small;
    final endIdx = parseMonthIndex(l.end);
    if (sec.end != EndKind.none && endIdx != null) {
      if (!active) {
        small = 'Terminé en ${monthAbbr(endIdx)}';
      } else {
        final r = remainingMonths(l, current)!;
        small = sec.end == EndKind.date
            ? 'Dernière échéance ${dateShort(l.end!)} · $r restante${r > 1 ? 's' : ''}'
            : 'Fin ${monthAbbr(endIdx)} · $r mois · ${money(r * (l.amount ?? 0))} restants';
      }
    } else if (l.expr != null) {
      small = l.expr!.replaceAll('.', ',').replaceAll('*', '×');
    }
    return LineRow(
      key: ValueKey(l.id),
      label: l.label,
      amount: l.amount,
      subtitle: small,
      ended: !active,
      checked: sec.check && active ? l.paid : null,
      checkLabel: l.paid ? 'Décocher ${l.label}' : 'Cocher ${l.label}',
      onCheck: () => store.update((_) => l.paid = !l.paid),
      onTap: () => editSectionLine(context, store, sec, l),
    );
  }
}
