import 'models.dart';

double round2(double v) => (v * 100).roundToDouble() / 100;

int monthIndexOf(DateTime d) => d.year * 12 + d.month - 1;

/// "2027-02-15" or "2027-02" -> absolute month index, or null.
int? parseMonthIndex(String? s) {
  final m = RegExp(r'^(\d{4})-(\d{2})').firstMatch(s ?? '');
  if (m == null) return null;
  return int.parse(m.group(1)!) * 12 + int.parse(m.group(2)!) - 1;
}

DateTime monthStart(int idx) => DateTime(idx ~/ 12, idx % 12 + 1, 1);

/// A line with an end date counts until (and including) the month of its last payment.
bool isActive(Line l, int currentMonth) {
  final e = parseMonthIndex(l.end);
  return e == null || e >= currentMonth;
}

/// Payments left AFTER [currentMonth] (the current month is already in the budget).
/// 0 means the last payment is this month. Null when the line has no end date.
int? remainingMonths(Line l, int currentMonth) {
  final e = parseMonthIndex(l.end);
  if (e == null) return null;
  final r = e - currentMonth;
  return r < 0 ? 0 : r;
}

double sumLines(Iterable<Line> lines) => lines.fold(0.0, (a, l) => a + (l.amount ?? 0));

/// Lines of the current month (lines added only for next month are left out).
List<Line> currentLines(BudgetData d, String key) =>
    d.section(key).where((l) => !l.onlyNext).toList();

class Totals {
  Totals({
    required this.entrees,
    required this.sorties,
    required this.reste,
    required this.bySection,
    required this.checkTotal,
    required this.checkPaid,
    required this.checkCount,
    required this.paidCount,
  });

  final double entrees;
  final double sorties;
  final double reste;
  final Map<String, double> bySection;
  final double checkTotal;
  final double checkPaid;
  final int checkCount;
  final int paidCount;
}

/// Reste du mois = entrées − charges fixes − abonnements − paiements 4× − emprunts
/// − charges aléatoires − autres dépenses − découvert + positif
/// (ended 4× payments and loans, and modules turned off, no longer count).
Totals computeTotals(BudgetData d, DateTime now) {
  final cur = monthIndexOf(now);
  final entrees = sumLines(currentLines(d, 'entrees'));
  final bySection = <String, double>{
    for (final k in outKeys)
      k: d.shows(sectionByKey(k)) ? sumLines(currentLines(d, k).where((l) => isActive(l, cur))) : 0.0,
  };
  final sorties = bySection.values.fold(0.0, (a, b) => a + b);
  var checkTotal = 0.0, checkPaid = 0.0;
  var checkCount = 0, paidCount = 0;
  for (final s in sections.where((s) => s.check && d.shows(s))) {
    for (final l in currentLines(d, s.key).where((l) => isActive(l, cur))) {
      checkTotal += l.amount ?? 0;
      checkCount++;
      if (l.paid) {
        checkPaid += l.amount ?? 0;
        paidCount++;
      }
    }
  }
  return Totals(
    entrees: entrees,
    sorties: sorties,
    reste: round2(entrees - sorties - d.decouvert + d.positif),
    bySection: bySection,
    checkTotal: checkTotal,
    checkPaid: checkPaid,
    checkCount: checkCount,
    paidCount: paidCount,
  );
}

class LoanInfo {
  LoanInfo(this.montant, this.mensualite, this.paidMonths, this.reste, this.endMonth);

  final double montant;
  final double mensualite;
  final int paidMonths;
  final double reste;

  /// Month index of the estimated last payment.
  final int? endMonth;

  double get rembourse => montant - reste;
  double get progress => montant > 0 ? ((montant - reste) / montant).clamp(0, 1).toDouble() : 0;
}

/// Remaining loan: amount at the start date minus one monthly payment
/// for every monthly anniversary of that date already passed.
LoanInfo loanInfo(BudgetData d, DateTime now) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(d.pretDate);
  var paid = 0;
  int? endMonth;
  if (m != null) {
    final y = int.parse(m.group(1)!), mo = int.parse(m.group(2)!) - 1, day = int.parse(m.group(3)!);
    paid = (now.year - y) * 12 + (now.month - 1 - mo) - (now.day < day ? 1 : 0);
    if (paid < 0) paid = 0;
    if (d.pretMensualite > 0) {
      endMonth = y * 12 + mo + (d.pretMontant / d.pretMensualite).ceil();
    }
  }
  var reste = round2(d.pretMontant - d.pretMensualite * paid);
  if (reste < 0) reste = 0;
  return LoanInfo(d.pretMontant, d.pretMensualite, paid, reste, endMonth);
}

class AmountResult {
  const AmountResult({this.value, this.expr, this.error});

  final double? value;
  final String? expr;
  final String? error;
}

/// Reads an amount, with simple calculations: "12,50", "0,5+0,9+0,7", "=9.47-7.99", "44.99*2".
AmountResult evalAmount(String raw) {
  final s = raw
      .trim()
      .replaceFirst(RegExp(r'^='), '')
      .replaceAll(RegExp(r'\s'), '')
      .replaceAll('€', '')
      .replaceAll(',', '.')
      .replaceAll('×', '*')
      .replaceAll('÷', '/')
      .replaceAll('−', '-');
  if (s.isEmpty) return const AmountResult();
  if (!RegExp(r'^[0-9.+\-*/()]+$').hasMatch(s)) {
    return const AmountResult(error: 'Utilise seulement des chiffres et + − × ÷.');
  }
  final p = _Parser(s);
  try {
    final v = p.expr();
    if (p.i != s.length || v.isNaN || v.isInfinite) throw const FormatException();
    final isExpr = RegExp(r'[+*/()]').hasMatch(s) || RegExp(r'.-').hasMatch(s);
    return AmountResult(value: round2(v), expr: isExpr ? s : null);
  } catch (_) {
    return const AmountResult(error: 'Ce montant n’est pas lisible.');
  }
}

class _Parser {
  _Parser(this.s);

  final String s;
  int i = 0;

  String? get peek => i < s.length ? s[i] : null;

  double number() {
    final start = i;
    while (i < s.length && RegExp(r'[0-9.]').hasMatch(s[i])) {
      i++;
    }
    final v = double.tryParse(s.substring(start, i));
    if (v == null) throw const FormatException();
    return v;
  }

  double factor() {
    if (peek == '-') {
      i++;
      return -factor();
    }
    if (peek == '+') {
      i++;
      return factor();
    }
    if (peek == '(') {
      i++;
      final v = expr();
      if (peek != ')') throw const FormatException();
      i++;
      return v;
    }
    return number();
  }

  double term() {
    var v = factor();
    while (peek == '*' || peek == '/') {
      final op = s[i++];
      final r = factor();
      v = op == '*' ? v * r : v / r;
    }
    return v;
  }

  double expr() {
    var v = term();
    while (peek == '+' || peek == '-') {
      final op = s[i++];
      final r = term();
      v = op == '+' ? v + r : v - r;
    }
    return v;
  }
}

/// Text to show in an amount field when editing a line.
String amountText(double? amount, String? expr) {
  if (expr != null) return expr.replaceAll('.', ',');
  if (amount == null) return '';
  final t = amount == amount.roundToDouble() ? amount.toInt().toString() : amount.toString();
  return t.replaceAll('.', ',');
}

/// Month index -> "2026-12".
String monthKey(int idx) => '${idx ~/ 12}-${(idx % 12 + 1).toString().padLeft(2, '0')}';

/// Amount a line will have next month.
double nextAmount(Line l) => l.next ?? l.amount ?? 0;

/// Lines shown in the "Mois suivant" tab for a section.
/// "Autres dépenses" start from zero: only lines added for next month.
List<Line> nextLines(BudgetData d, SectionDef s, int nextMonth) => d.section(s.key).where((l) {
      if (s.key == 'autres') return l.onlyNext;
      return !l.dropNext && isActive(l, nextMonth);
    }).toList();

/// Lines removed from next month (shown greyed so they can be put back).
List<Line> droppedLines(BudgetData d, SectionDef s) =>
    s.key == 'autres' ? const [] : d.section(s.key).where((l) => l.dropNext && !l.onlyNext).toList();

class NextTotals {
  NextTotals({
    required this.month,
    required this.entrees,
    required this.sorties,
    required this.bySection,
    required this.report,
    required this.ending,
  });

  /// Month index of next month.
  final int month;
  final double entrees;
  final double sorties;
  final Map<String, double> bySection;

  /// Balance of the current month, carried over as overdraft (negative) or credit (positive).
  final double report;

  /// 4× payments and loans whose last payment is this month.
  final List<(SectionDef, Line)> ending;

  double get reste => round2(entrees - sorties + report);
}

/// What the "Mois" tab will show on the 1st of next month.
NextTotals computeNextTotals(BudgetData d, DateTime now) {
  final cur = monthIndexOf(now);
  final nxt = cur + 1;
  final bySection = <String, double>{
    for (final s in sections)
      s.key: d.shows(s) ? nextLines(d, s, nxt).fold(0.0, (a, l) => a + nextAmount(l)) : 0.0,
  };
  final ending = <(SectionDef, Line)>[
    for (final s in sections.where((s) => s.end != EndKind.none && d.shows(s)))
      for (final l in currentLines(d, s.key))
        if (isActive(l, cur) && !isActive(l, nxt)) (s, l),
  ];
  return NextTotals(
    month: nxt,
    entrees: bySection['entrees']!,
    sorties: outKeys.fold(0.0, (a, k) => a + bySection[k]!),
    bySection: bySection,
    report: computeTotals(d, now).reste,
    ending: ending,
  );
}

/// On the first opening of a new month, the "Mois suivant" tab becomes the "Mois" tab:
/// - adjusted amounts replace the old ones, removed lines go, added lines join;
/// - "Autres dépenses" are replaced by the ones planned for next month;
/// - ended 4× payments and loans are removed;
/// - "prélevé" ticks are reset;
/// - the old month's balance becomes the starting overdraft (negative) or credit (positive).
/// Returns true when the data changed and must be saved.
bool rolloverIfNeeded(BudgetData d, DateTime now) {
  final cur = monthIndexOf(now);
  final stored = parseMonthIndex(d.month);
  if (stored == null) {
    d.month = monthKey(cur);
    return true;
  }
  if (stored >= cur) return false;
  final oldReste = computeTotals(d, monthStart(stored)).reste;
  for (final s in sections) {
    final list = d.section(s.key);
    list.removeWhere((l) => s.key == 'autres'
        ? !l.onlyNext
        : (l.dropNext && !l.onlyNext) || (l.end != null && !isActive(l, cur)));
    for (final l in list) {
      if (l.next != null) {
        l.amount = l.next;
        l.expr = l.nextExpr;
      }
      l.next = null;
      l.nextExpr = null;
      l.onlyNext = false;
      l.dropNext = false;
      l.paid = false;
    }
  }
  d.decouvert = oldReste < 0 ? round2(-oldReste) : 0;
  d.positif = oldReste > 0 ? oldReste : 0;
  d.month = monthKey(cur);
  return true;
}
