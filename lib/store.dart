import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'calc.dart';
import 'models.dart';

/// Holds the budget and saves it on the phone after every change.
class BudgetStore extends ChangeNotifier {
  BudgetStore._(this._prefs, this.data);

  static const _key = 'mon-budget-v1';

  final SharedPreferences _prefs;
  BudgetData data;

  /// True when opening the app switched to a new month (forecasts applied).
  bool newMonthApplied = false;

  bool _hadMonth(String raw) {
    try {
      final m = (jsonDecode(raw) as Map<String, dynamic>)['month'];
      return m is String && m.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Called when the app comes back to the foreground: switches month if needed.
  bool checkNewMonth() {
    if (!rolloverIfNeeded(data, DateTime.now())) return false;
    notifyListeners();
    _save();
    return true;
  }

  static Future<BudgetStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    BudgetData? data;
    if (raw != null) {
      try {
        data = BudgetData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        data = null;
      }
    }
    data ??= BudgetData();
    final store = BudgetStore._(prefs, data);
    final rolled = rolloverIfNeeded(data, DateTime.now());
    // A stored budget without a month only gets its month stamped: not a real month change.
    store.newMonthApplied = rolled && raw != null && store._hadMonth(raw);
    if (raw == null || rolled) await store._save();
    return store;
  }

  /// Applies a change, refreshes the screens and saves.
  void update(void Function(BudgetData d) change) {
    change(data);
    notifyListeners();
    _save();
  }

  Future<void> _save() => _prefs.setString(_key, jsonEncode(data.toJson()));

  String exportJson() => const JsonEncoder.withIndent(' ').convert(data.toJson());

  /// Returns false when the text is not a budget backup.
  bool importJson(String text) {
    try {
      final j = jsonDecode(text.trim());
      if (j is! Map<String, dynamic> || !j.containsKey('fixes')) return false;
      data = BudgetData.fromJson(j);
      rolloverIfNeeded(data, DateTime.now());
      notifyListeners();
      _save();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Erases every line and amount; keeps the chosen modules.
  Future<void> eraseAll() async {
    final modules = {...data.modules};
    data = BudgetData(modules: modules, onboarded: true, tutoSeen: true);
    rolloverIfNeeded(data, DateTime.now());
    notifyListeners();
    await _save();
  }
}
