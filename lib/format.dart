import 'package:intl/intl.dart';

import 'calc.dart';

final _eur = NumberFormat.currency(locale: 'fr_FR', symbol: '€', decimalDigits: 2);

String money(num? v) => _eur.format(round2((v ?? 0).toDouble()));

String signedMoney(double v) {
  final r = round2(v);
  final sign = r > 0 ? '+' : (r < 0 ? '−' : '');
  return '$sign${_eur.format(r.abs())}';
}

const monthNames = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];
const monthShort = ['jan', 'fév', 'mar', 'avr', 'mai', 'jun', 'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'];

String capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Month index -> "novembre 2026".
String monthLong(int idx) => '${monthNames[idx % 12]} ${idx ~/ 12}';

/// Month index -> "déc. 2027".
String monthAbbr(int idx) => DateFormat('MMM y', 'fr_FR').format(monthStart(idx));

DateTime? parseDate(String s) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
  if (m == null) return null;
  return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
}

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// "2027-02-15" -> "15 févr. 2027".
String dateShort(String s) {
  final d = parseDate(s);
  return d == null ? s : DateFormat('d MMM y', 'fr_FR').format(d);
}

/// "2026-05-25" -> "25 mai 2026".
String dateLong(String s) {
  final d = parseDate(s);
  return d == null ? s : DateFormat('d MMMM y', 'fr_FR').format(d);
}
