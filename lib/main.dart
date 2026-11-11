import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'calc.dart';
import 'format.dart';
import 'models.dart';
import 'screens/budget_screen.dart';
import 'screens/credits_screen.dart';
import 'screens/next_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/tutorial_screen.dart';
import 'store.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');
  final store = await BudgetStore.load();
  runApp(BudgetApp(store: store));
}

const _accent = Color(0xFF2C3FB4);

ThemeData _theme(Brightness b) {
  final dark = b == Brightness.dark;
  final cs = ColorScheme.fromSeed(seedColor: _accent, brightness: b).copyWith(
    primary: dark ? const Color(0xFF93A3FF) : _accent,
    surface: dark ? const Color(0xFF0E1017) : const Color(0xFFF3F4F8),
    surfaceContainerLow: dark ? const Color(0xFF171A25) : Colors.white,
  );
  return ThemeData(
    colorScheme: cs,
    useMaterial3: true,
    scaffoldBackgroundColor: cs.surface,
    cardTheme: CardThemeData(
      color: cs.surfaceContainerLow,
      elevation: dark ? 0 : 1,
      shadowColor: const Color(0x22171A2B),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    appBarTheme: AppBarTheme(backgroundColor: cs.surface, surfaceTintColor: Colors.transparent),
  );
}

class BudgetApp extends StatelessWidget {
  const BudgetApp({super.key, required this.store});

  final BudgetStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mon budget',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          if (!store.data.tutoSeen) {
            return TutorialScreen(
              pages: tutoPages(store.data.modules),
              doneLabel: store.data.onboarded ? 'Terminer' : 'Choisir mes modules',
              onDone: () => store.update((d) => d.tutoSeen = true),
            );
          }
          return store.data.onboarded ? HomePage(store: store) : WelcomeScreen(store: store);
        },
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.store});

  final BudgetStore store;

  @override
  State<HomePage> createState() => _HomePageState();
}

enum _Menu { settings, tuto, backup, restore, erase }

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.store.newMonthApplied) {
      widget.store.newMonthApplied = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _announceNewMonth());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.store.checkNewMonth()) {
      _announceNewMonth();
    }
  }

  void _announceNewMonth() {
    if (!mounted) return;
    setState(() => _tab = 0);
    toast(context, 'Nouveau mois : le mois suivant est passé dans l’onglet Mois.');
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final tabs = <(String, NavigationDestination, Widget)>[
          (
            'Budget du mois',
            const NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet),
                label: 'Mois'),
            BudgetScreen(store: widget.store, now: now),
          ),
          (
            'Mois suivant',
            const NavigationDestination(icon: Icon(Icons.calendar_today_outlined), label: 'Suivant'),
            NextMonthScreen(store: widget.store, now: now),
          ),
          if (widget.store.data.has(Module.credits))
            (
              'Crédits',
              const NavigationDestination(
                  icon: Icon(Icons.account_balance_outlined),
                  selectedIcon: Icon(Icons.account_balance),
                  label: 'Crédits'),
              CreditsScreen(store: widget.store, now: now),
            ),
        ];
        if (_tab >= tabs.length) _tab = 0;
        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 72,
            titleSpacing: 16,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  monthLong(monthIndexOf(now) + (_tab == 1 ? 1 : 0)).toUpperCase(),
                  style: TextStyle(
                      fontSize: 12, letterSpacing: 1, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant),
                ),
                Text(tabs[_tab].$1,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -.3)),
              ],
            ),
            actions: [
              PopupMenuButton<_Menu>(
                tooltip: 'Menu',
                onSelected: (m) => _onMenu(context, m),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                      value: _Menu.settings,
                      child: ListTile(leading: Icon(Icons.tune), title: Text('Réglages (modules)'))),
                  PopupMenuItem(
                      value: _Menu.tuto,
                      child: ListTile(leading: Icon(Icons.school_outlined), title: Text('Revoir le tuto'))),
                  PopupMenuItem(
                      value: _Menu.backup,
                      child: ListTile(leading: Icon(Icons.copy_all_outlined), title: Text('Copier une sauvegarde'))),
                  PopupMenuItem(
                      value: _Menu.restore,
                      child: ListTile(leading: Icon(Icons.restore_page_outlined), title: Text('Restaurer une sauvegarde'))),
                  PopupMenuItem(
                      value: _Menu.erase,
                      child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Tout effacer'))),
                ],
              ),
            ],
          ),
          body: SafeArea(bottom: false, child: tabs[_tab].$3),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: [for (final t in tabs) t.$2],
          ),
        );
      },
    );
  }

  Future<void> _onMenu(BuildContext context, _Menu m) async {
    final store = widget.store;
    switch (m) {
      case _Menu.settings:
        await Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(store: store)));
      case _Menu.tuto:
        await openTutorial(context, store);
      case _Menu.backup:
        await Clipboard.setData(ClipboardData(text: store.exportJson()));
        if (context.mounted) {
          toast(context, 'Sauvegarde copiée. Colle-la dans une note ou un mail pour la garder.');
        }
      case _Menu.restore:
        final ctrl = TextEditingController();
        final text = await showDialog<String>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Restaurer une sauvegarde'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Colle ici le texte copié avec « Copier une sauvegarde ». Ton budget actuel sera remplacé.'),
                const SizedBox(height: 12),
                TextField(controller: ctrl, maxLines: 6, decoration: const InputDecoration(hintText: '{ … }')),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
              FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('Restaurer')),
            ],
          ),
        );
        ctrl.dispose();
        if (text == null || !context.mounted) return;
        final ok = store.importJson(text);
        toast(context, ok ? 'Sauvegarde restaurée' : 'Ce texte n’est pas une sauvegarde du budget.');
      case _Menu.erase:
        final ok = await confirmAction(
          context,
          title: 'Tout effacer',
          message: 'Toutes les lignes et tous les montants seront supprimés. Pense à copier une sauvegarde avant si tu veux les garder.',
          okLabel: 'Tout effacer',
          danger: true,
        );
        if (!ok) return;
        await store.eraseAll();
        if (context.mounted) toast(context, 'Budget effacé');
    }
  }
}
