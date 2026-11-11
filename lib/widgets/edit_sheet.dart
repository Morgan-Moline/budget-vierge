import 'package:flutter/material.dart';

import '../calc.dart';
import '../format.dart';
import 'common.dart';

enum DateField { none, date, month }

/// Describes which fields the edit sheet shows.
class EditSpec {
  const EditSpec({
    required this.title,
    this.showLabel = true,
    this.labelName = 'Nom',
    this.labelRequired = 'Donne un nom à cette ligne.',
    this.showAmount = true,
    this.amountName = 'Montant (€)',
    this.amountHint = 'Pour additionner, utilise les boutons : 17,46 + 9,55',
    this.amountRequired,
    this.amount2Name,
    this.dateField = DateField.none,
    this.dateName = 'Date',
    this.dateHint,
    this.showNote = false,
    this.noteName = 'Commentaire ou lien',
    this.toggleName,
    this.monthPicker = false,
    this.canDelete = false,
    this.deleteText = 'Supprimer cette ligne ?',
    this.deleteLabel = 'Supprimer',
    this.saveLabel = 'Enregistrer',
  });

  final String title;
  final bool showLabel;
  final String labelName;
  final String labelRequired;
  final bool showAmount;
  final String amountName;
  final String amountHint;

  /// Error shown when the amount is empty; null means the amount is optional.
  final String? amountRequired;
  final String? amount2Name;
  final DateField dateField;
  final String dateName;
  final String? dateHint;
  final bool showNote;
  final String noteName;
  final String? toggleName;
  final bool monthPicker;
  final bool canDelete;
  final String deleteText;
  final String deleteLabel;
  final String saveLabel;
}

class EditValues {
  EditValues({
    this.label = '',
    this.amount = '',
    this.amount2 = '',
    this.date = '',
    this.note = '',
    this.toggle = false,
    this.month = 0,
  });

  String label;
  String amount;
  String amount2;
  String date;
  String note;
  bool toggle;
  int month;
}

class EditResult {
  EditResult({
    this.delete = false,
    this.label = '',
    this.amount,
    this.expr,
    this.amount2,
    this.date = '',
    this.note = '',
    this.toggle = false,
    this.month = 0,
  });

  final bool delete;
  final String label;
  final double? amount;
  final String? expr;
  final double? amount2;
  final String date;
  final String note;
  final bool toggle;
  final int month;
}

Future<EditResult?> showEditSheet(BuildContext context, EditSpec spec, [EditValues? initial]) {
  return showModalBottomSheet<EditResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _EditSheet(spec: spec, initial: initial ?? EditValues()),
  );
}

class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.spec, required this.initial});

  final EditSpec spec;
  final EditValues initial;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final _label = TextEditingController(text: widget.initial.label);
  late final _amount = TextEditingController(text: widget.initial.amount);
  late final _amount2 = TextEditingController(text: widget.initial.amount2);
  late final _note = TextEditingController(text: widget.initial.note);
  late final _month = TextEditingController(text: widget.initial.date);
  late String _date = widget.initial.date;
  late bool _toggle = widget.initial.toggle;
  late int _monthIdx = widget.initial.month;
  String? _error;

  @override
  void dispose() {
    for (final c in [_label, _amount, _amount2, _note, _month]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final s = widget.spec;
    final label = _label.text.trim();
    if (s.showLabel && label.isEmpty) return setState(() => _error = s.labelRequired);
    AmountResult a = const AmountResult(), a2 = const AmountResult();
    if (s.showAmount) {
      a = evalAmount(_amount.text);
      if (a.error != null) return setState(() => _error = a.error);
      if (a.value == null && s.amountRequired != null) {
        return setState(() => _error = s.amountRequired);
      }
    }
    if (s.amount2Name != null) {
      a2 = evalAmount(_amount2.text);
      if (a2.error != null) return setState(() => _error = a2.error);
    }
    var date = _date;
    if (s.dateField == DateField.month) {
      date = _month.text.trim();
      if (date.isNotEmpty && !RegExp(r'^\d{4}-\d{2}$').hasMatch(date)) {
        return setState(() => _error = 'Écris le mois de fin comme 2027-04.');
      }
    }
    Navigator.pop(
      context,
      EditResult(
        label: label,
        amount: a.value,
        expr: a.expr,
        amount2: a2.value,
        date: date,
        note: _note.text.trim(),
        toggle: _toggle,
        month: _monthIdx,
      ),
    );
  }

  Future<void> _delete() async {
    final ok = await confirmAction(context,
        title: widget.spec.deleteLabel,
        message: widget.spec.deleteText,
        okLabel: widget.spec.deleteLabel,
        danger: true);
    if (ok && mounted) Navigator.pop(context, EditResult(delete: true));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: parseDate(_date) ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 15),
    );
    if (picked != null) setState(() => _date = isoDate(picked));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.spec;
    final cs = Theme.of(context).colorScheme;
    const gap = SizedBox(height: 14);
    final fields = <Widget>[
      Text(s.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
      gap,
      if (s.showLabel) ...[
        TextField(
          controller: _label,
          autofocus: widget.initial.label.isEmpty,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: s.labelName),
          textInputAction: TextInputAction.next,
        ),
        gap,
      ],
      if (s.showAmount) ...[
        TextField(
          controller: _amount,
          autofocus: !s.showLabel,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: InputDecoration(
            labelText: s.amountName,
            hintText: 'ex. 12,50 ou 9+7,7',
            helperText: s.amountHint,
          ),
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: 6),
        CalcKeys(controller: _amount),
        gap,
      ],
      if (s.amount2Name != null) ...[
        TextField(
          controller: _amount2,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: InputDecoration(labelText: s.amount2Name),
        ),
        const SizedBox(height: 6),
        CalcKeys(controller: _amount2),
        gap,
      ],
      if (s.dateField == DateField.date) ...[
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(4),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: s.dateName,
              helperText: s.dateHint,
              suffixIcon: _date.isEmpty
                  ? const Icon(Icons.calendar_today_outlined)
                  : IconButton(
                      tooltip: 'Effacer la date',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _date = ''),
                    ),
            ),
            child: Text(_date.isEmpty ? 'Choisir une date' : dateLong(_date)),
          ),
        ),
        gap,
      ],
      if (s.dateField == DateField.month) ...[
        TextField(
          controller: _month,
          keyboardType: TextInputType.datetime,
          decoration: InputDecoration(
            labelText: s.dateName,
            hintText: 'AAAA-MM',
            helperText: s.dateHint,
          ),
        ),
        gap,
      ],
      if (s.monthPicker) ...[
        DropdownButtonFormField<int>(
          initialValue: _monthIdx,
          decoration: const InputDecoration(labelText: 'Mois'),
          items: [
            for (var i = 0; i < 12; i++)
              DropdownMenuItem(value: i, child: Text(capitalize(monthNames[i]))),
          ],
          onChanged: (v) => setState(() => _monthIdx = v ?? _monthIdx),
        ),
        gap,
      ],
      if (s.showNote) ...[
        TextField(
          controller: _note,
          decoration: InputDecoration(labelText: s.noteName),
          keyboardType: TextInputType.text,
        ),
        gap,
      ],
      if (s.toggleName != null)
        CheckboxListTile(
          value: _toggle,
          onChanged: (v) => setState(() => _toggle = v ?? false),
          title: Text(s.toggleName!),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(_error!, style: TextStyle(color: cs.error)),
        ),
      const SizedBox(height: 10),
      Row(
        children: [
          if (s.canDelete)
            TextButton(
              onPressed: _delete,
              style: TextButton.styleFrom(foregroundColor: cs.error),
              child: Text(s.deleteLabel),
            ),
          const Spacer(),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          const SizedBox(width: 8),
          FilledButton(onPressed: _save, child: Text(s.saveLabel)),
        ],
      ),
    ];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: fields),
      ),
    );
  }
}


/// + − × ÷ buttons under an amount field: Android's number keyboard has no "+" key.
class CalcKeys extends StatelessWidget {
  const CalcKeys({super.key, required this.controller});

  final TextEditingController controller;

  void _insert(String t) {
    final text = controller.text;
    final sel = controller.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    controller.value = TextEditingValue(
      text: text.replaceRange(start, end, t),
      selection: TextSelection.collapsed(offset: start + t.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget key(String label, String insert, String tip) => Expanded(
          child: Tooltip(
            message: tip,
            child: OutlinedButton(
              onPressed: () => _insert(insert),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                minimumSize: const Size(0, 44),
                foregroundColor: cs.primary,
              ),
              child: Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            ),
          ),
        );
    // ExcludeFocus + TextFieldTapRegion: tapping a key keeps the keyboard open on the field.
    return TextFieldTapRegion(
      child: ExcludeFocus(
        child: Row(
          children: [
            key('+', '+', 'Ajouter'),
            const SizedBox(width: 8),
            key('−', '-', 'Soustraire'),
            const SizedBox(width: 8),
            key('×', '*', 'Multiplier'),
            const SizedBox(width: 8),
            key('÷', '/', 'Diviser'),
          ],
        ),
      ),
    );
  }
}
