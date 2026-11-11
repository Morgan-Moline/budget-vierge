import 'package:flutter/material.dart';

import '../format.dart';

enum Tone { good, warn, serious, bad, neutral, accent }

/// Semantic colours (good / warning / serious / critical), separate from the accent.
class Palette {
  Palette(this.context);

  final BuildContext context;

  bool get dark => Theme.of(context).brightness == Brightness.dark;
  ColorScheme get cs => Theme.of(context).colorScheme;

  Color fg(Tone t) => switch (t) {
        Tone.good => dark ? const Color(0xFF57C984) : const Color(0xFF1D7F47),
        Tone.warn => dark ? const Color(0xFFE8B949) : const Color(0xFF9A6A00),
        Tone.serious => dark ? const Color(0xFFF08A4F) : const Color(0xFFB9531A),
        Tone.bad => dark ? const Color(0xFFFF7B74) : const Color(0xFFC0322F),
        Tone.neutral => cs.onSurfaceVariant,
        Tone.accent => cs.primary,
      };

  Color bg(Tone t) => switch (t) {
        Tone.good => dark ? const Color(0xFF15301F) : const Color(0xFFDDF2E5),
        Tone.warn => dark ? const Color(0xFF33290F) : const Color(0xFFFBF0D2),
        Tone.serious => dark ? const Color(0xFF3A2215) : const Color(0xFFFCE6D8),
        Tone.bad => dark ? const Color(0xFF3D1A1A) : const Color(0xFFFADEDD),
        Tone.neutral => cs.surfaceContainerHighest,
        Tone.accent => cs.primaryContainer,
      };
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.tone = Tone.neutral});

  final String text;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final p = Palette(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: p.bg(tone), borderRadius: BorderRadius.circular(99)),
      child: Text(text,
          style: TextStyle(color: p.fg(tone), fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

/// A progress bar with a caption on each side.
class Meter extends StatelessWidget {
  const Meter({super.key, required this.value, this.left, this.right});

  final double value;
  final Widget? left;
  final Widget? right;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: value.clamp(0, 1).toDouble(),
            minHeight: 8,
            backgroundColor: cs.surfaceContainerHighest,
            color: cs.primary,
          ),
        ),
        const SizedBox(height: 6),
        DefaultTextStyle.merge(
          style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 2,
            children: [if (left != null) left!, if (right != null) right!],
          ),
        ),
      ],
    );
  }
}

/// "Label **value**" caption used under meters.
class Caption extends StatelessWidget {
  const Caption(this.label, this.value, {super.key, this.after = ''});

  final String label;
  final String value;
  final String after;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text.rich(TextSpan(children: [
      TextSpan(text: '$label '),
      TextSpan(text: value, style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
      if (after.isNotEmpty) TextSpan(text: after),
    ]));
  }
}

/// A card that holds one budget section: header with total and a + button, then the rows.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.total,
    required this.children,
    this.onAdd,
    this.addTooltip,
    this.emptyText = 'Aucune ligne. Ajoute-en une avec +.',
    this.footer,
  });

  final String title;
  final String subtitle;
  final String total;
  final List<Widget> children;
  final VoidCallback? onAdd;
  final String? addTooltip;
  final String emptyText;
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
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                Text(total,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                if (onAdd != null) ...[
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    onPressed: onAdd,
                    tooltip: addTooltip ?? 'Ajouter',
                    icon: const Icon(Icons.add),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
          ),
          if (children.isEmpty)
            Container(
              decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.outlineVariant))),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Text(emptyText, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13.5)),
            )
          else
            ...children,
          if (footer != null) footer!,
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

/// One line of a section: optional tick box, name with a detail line, amount.
class LineRow extends StatelessWidget {
  const LineRow({
    super.key,
    required this.label,
    required this.amount,
    this.subtitle,
    this.checked,
    this.onCheck,
    this.onTap,
    this.ended = false,
    this.badge,
    this.link,
    this.onLink,
    this.checkLabel,
  });

  final String label;
  final double? amount;
  final String? subtitle;

  /// Null: no tick box.
  final bool? checked;
  final VoidCallback? onCheck;
  final VoidCallback? onTap;
  final bool ended;
  final Widget? badge;
  final String? link;
  final VoidCallback? onLink;
  final String? checkLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = Palette(context);
    final done = checked == true;
    return Opacity(
      opacity: ended ? .55 : 1,
      child: Container(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.outlineVariant))),
        constraints: const BoxConstraints(minHeight: 52),
        child: Row(
          children: [
            if (checked != null)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Semantics(
                  label: checkLabel,
                  child: Checkbox(
                    value: checked,
                    onChanged: onCheck == null ? null : (_) => onCheck!(),
                    activeColor: p.fg(Tone.good),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              )
            else
              const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label.isEmpty ? 'Sans nom' : label,
                                style: TextStyle(color: done ? cs.onSurfaceVariant : cs.onSurface)),
                            if (subtitle != null && subtitle!.isNotEmpty)
                              Text(subtitle!,
                                  style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
                            if (link != null)
                              GestureDetector(
                                onTap: onLink,
                                child: Text('$link ↗',
                                    style: TextStyle(fontSize: 12.5, color: cs.primary)),
                              ),
                          ],
                        ),
                      ),
                      if (badge != null) ...[badge!, const SizedBox(width: 8)],
                      Text(
                        amount == null ? '—' : money(amount),
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          decoration: ended ? TextDecoration.lineThrough : null,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String okLabel,
  bool danger = false,
}) async {
  final p = Palette(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: p.fg(Tone.bad)) : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(okLabel),
        ),
      ],
    ),
  );
  return ok == true;
}

void toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
}

String hostOf(String url) {
  final u = Uri.tryParse(url);
  return (u?.host ?? 'lien').replaceFirst(RegExp(r'^www\.'), '');
}

bool isLink(String s) => RegExp(r'^https?://', caseSensitive: false).hasMatch(s);
