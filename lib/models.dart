import 'dart:math';

final _rand = Random();

/// Generates a short unique identifier for new lines.
String newId() =>
    'n${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_rand.nextInt(1 << 20).toRadixString(36)}';

double? _toDouble(Object? v) => v is num ? v.toDouble() : null;

/// One budget line: an income, a charge, a planned purchase or a project item.
class Line {
  Line({
    String? id,
    this.label = '',
    this.amount,
    this.expr,
    this.paid = false,
    this.end,
    this.note = '',
    this.done = false,
    this.next,
    this.nextExpr,
    this.onlyNext = false,
    this.dropNext = false,
  }) : id = id ?? newId();

  final String id;
  String label;
  double? amount;

  /// The calculation typed by the user (e.g. "17.46+9.55"), if any.
  String? expr;

  /// Ticked when the payment has left the account this month.
  bool paid;

  /// Last payment: "YYYY-MM-DD" for 4× payments, "YYYY-MM" for loans.
  String? end;

  /// Comment or link.
  String note;

  /// Project item already bought.
  bool done;

  /// Amount changed in the "Mois suivant" tab; replaces [amount] on the 1st of the month.
  double? next;
  String? nextExpr;

  /// Line added in the "Mois suivant" tab: not part of the current month yet.
  bool onlyNext;

  /// Line removed in the "Mois suivant" tab: still part of the current month.
  bool dropNext;

  factory Line.fromJson(Map<String, dynamic> j) => Line(
        id: j['id'] as String?,
        label: (j['label'] as String?) ?? '',
        amount: _toDouble(j['amount']),
        expr: j['expr'] as String?,
        paid: j['paid'] == true,
        end: (j['end'] as String?)?.isEmpty == true ? null : j['end'] as String?,
        note: (j['note'] as String?) ?? '',
        done: j['done'] == true,
        next: _toDouble(j['next']),
        nextExpr: j['nextExpr'] as String?,
        onlyNext: j['onlyNext'] == true,
        dropNext: j['dropNext'] == true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'amount': amount,
        if (expr != null) 'expr': expr,
        'paid': paid,
        if (end != null && end!.isNotEmpty) 'end': end,
        if (note.isNotEmpty) 'note': note,
        'done': done,
        if (next != null) 'next': next,
        if (nextExpr != null) 'nextExpr': nextExpr,
        if (onlyNext) 'onlyNext': true,
        if (dropNext) 'dropNext': true,
      };
}

/// A repayment to dad.
class Versement {
  Versement({String? id, required this.amount, this.date = '', this.note = ''})
      : id = id ?? newId();

  final String id;
  double amount;
  String date;
  String note;

  factory Versement.fromJson(Map<String, dynamic> j) => Versement(
        id: j['id'] as String?,
        amount: _toDouble(j['amount']) ?? 0,
        date: (j['date'] as String?) ?? '',
        note: (j['note'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'amount': amount, 'date': date, if (note.isNotEmpty) 'note': note};
}

List<Line> _lines(Object? raw) => raw is List
    ? raw.whereType<Map>().map((e) => Line.fromJson(Map<String, dynamic>.from(e))).toList()
    : <Line>[];

enum EndKind { none, date, month }

/// Optional parts of the app, chosen at first launch and in Réglages.
enum Module {
  x4('Paiements en 4×', 'Achats payés en plusieurs fois, avec leur dernière échéance.'),
  emprunts('Emprunts', 'Mensualités de crédits, à cocher quand elles sont prélevées.'),
  credits('Onglet Crédits', 'Reste d’un emprunt et suivi d’un remboursement (une dette à rembourser).');

  const Module(this.title, this.description);

  final String title;
  final String description;
}

/// Static description of a budget section ("Charges fixes", "Abonnements"...).
class SectionDef {
  const SectionDef(this.key, this.title,
      {this.check = false, this.income = false, this.end = EndKind.none, this.subtitle, this.module});

  final String key;
  final String title;
  final bool check;
  final bool income;
  final EndKind end;
  final String? subtitle;

  /// Null for the base sections, which are always shown.
  final Module? module;
}

const sections = <SectionDef>[
  SectionDef('entrees', 'Entrées', income: true, subtitle: 'Salaire, aides et revenus du mois'),
  SectionDef('fixes', 'Charges fixes', check: true),
  SectionDef('abonnements', 'Abonnements', check: true),
  SectionDef('x4', 'Paiements en 4×', check: true, end: EndKind.date, module: Module.x4),
  SectionDef('emprunts', 'Emprunts', check: true, end: EndKind.month, module: Module.emprunts),
  SectionDef('aleatoires', 'Charges aléatoires'),
  SectionDef('autres', 'Autres dépenses'),
];

const outKeys = ['fixes', 'abonnements', 'x4', 'emprunts', 'aleatoires', 'autres'];

SectionDef sectionByKey(String key) => sections.firstWhere((s) => s.key == key);

/// Everything the app stores.
class BudgetData {
  BudgetData({
    this.month = '',
    Map<String, List<Line>>? lines,
    this.positif = 0,
    this.decouvert = 0,
    this.pretDate = '',
    this.pretMontant = 0,
    this.pretMensualite = 0,
    this.detteTotal = 0,
    List<Versement>? versements,
    Set<Module>? modules,
    this.onboarded = false,
    this.tutoSeen = false,
  })  : lines = lines ?? {for (final s in sections) s.key: <Line>[]},
        versements = versements ?? [],
        modules = modules ?? <Module>{};

  /// Month the current amounts belong to ("YYYY-MM").
  String month;
  final Map<String, List<Line>> lines;
  double positif;
  double decouvert;
  String pretDate;
  double pretMontant;
  double pretMensualite;

  /// Debt being repaid (onglet Crédits > Remboursement).
  double detteTotal;
  List<Versement> versements;

  /// Optional modules turned on.
  final Set<Module> modules;

  /// False until the first-launch screen has been completed.
  bool onboarded;

  /// False until the tutorial has been seen once (or skipped).
  bool tutoSeen;

  bool has(Module m) => modules.contains(m);

  /// A section counts and is shown only if it is a base section or its module is on.
  bool shows(SectionDef s) => s.module == null || has(s.module!);

  List<Line> section(String key) => lines.putIfAbsent(key, () => <Line>[]);

  factory BudgetData.fromJson(Map<String, dynamic> j) {
    final compte = (j['compte'] as Map?) ?? const {};
    final pret = (j['pret'] as Map?) ?? const {};
    final dette = (j['remboursement'] as Map?) ?? const {};
    final mods = (j['modules'] is List) ? (j['modules'] as List).whereType<String>().toSet() : <String>{};
    return BudgetData(
      month: (j['month'] as String?) ?? '',
      lines: {for (final s in sections) s.key: _lines(j[s.key])},
      positif: _toDouble(compte['positif']) ?? 0,
      decouvert: _toDouble(compte['decouvert']) ?? 0,
      pretDate: (pret['date'] as String?) ?? '',
      pretMontant: _toDouble(pret['montant']) ?? 0,
      pretMensualite: _toDouble(pret['mensualite']) ?? 0,
      detteTotal: _toDouble(dette['total']) ?? 0,
      versements: (dette['versements'] is List)
          ? (dette['versements'] as List)
              .whereType<Map>()
              .map((e) => Versement.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : [],
      modules: {for (final m in Module.values) if (mods.contains(m.name)) m},
      onboarded: j['onboarded'] == true,
      tutoSeen: j['tutoSeen'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'v': 1,
        'month': month,
        'onboarded': onboarded,
        'tutoSeen': tutoSeen,
        'modules': [for (final m in Module.values) if (modules.contains(m)) m.name],
        for (final s in sections) s.key: section(s.key).map((e) => e.toJson()).toList(),
        'compte': {'positif': positif, 'decouvert': decouvert},
        'pret': {'date': pretDate, 'montant': pretMontant, 'mensualite': pretMensualite},
        'remboursement': {'total': detteTotal, 'versements': versements.map((e) => e.toJson()).toList()},
      };
}
