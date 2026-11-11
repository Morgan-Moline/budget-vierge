import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import 'tutorial_screen.dart';

/// One switch per optional module.
class ModuleSwitches extends StatelessWidget {
  const ModuleSwitches({super.key, required this.selected, required this.onChanged, this.hiddenCount});

  final Set<Module> selected;
  final void Function(Module m, bool on) onChanged;

  /// Number of saved lines per module, shown when the module is off.
  final int Function(Module m)? hiddenCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final m in Module.values) ...[
            if (m != Module.values.first) Divider(height: 1, color: cs.outlineVariant),
            SwitchListTile(
              value: selected.contains(m),
              onChanged: (v) => onChanged(m, v),
              title: Text(m.title, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(_subtitle(m)),
              isThreeLine: true,
            ),
          ],
        ],
      ),
    );
  }

  String _subtitle(Module m) {
    final n = hiddenCount?.call(m) ?? 0;
    if (!selected.contains(m) && n > 0) {
      return '${m.description}\n$n ligne${n > 1 ? 's' : ''} gardée${n > 1 ? 's' : ''}, cachée${n > 1 ? 's' : ''} tant que le module est retiré.';
    }
    return m.description;
  }
}

/// Lines saved in a module (shown in Réglages when the module is off).
int linesIn(BudgetData d, Module m) => switch (m) {
      Module.x4 => d.section('x4').length,
      Module.emprunts => d.section('emprunts').length,
      Module.credits => d.versements.length + (d.pretMontant > 0 ? 1 : 0),
    };

const _baseText = 'Toujours présents : Entrées, Charges fixes, Abonnements, Charges aléatoires, '
    'Autres dépenses et l’onglet Mois suivant.';

/// First launch: choose the optional modules.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.store});

  final BudgetStore store;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _selected = <Module>{};

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
          children: [
            Text('Bienvenue', style: TextStyle(fontSize: 13, letterSpacing: 1, color: cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text('Mon budget',
                style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.3)),
            const SizedBox(height: 12),
            const Text(
              'Note tes entrées et tes dépenses du mois, coche ce qui est prélevé, et prépare le mois suivant. '
              'Tes données restent sur cet appareil.',
            ),
            if (kIsWeb) ...[
              const SizedBox(height: 16),
              const InstallTip(),
            ],
            const SizedBox(height: 20),
            Text('De quoi as-tu besoin ?', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Active seulement ce qui te sert. Tu pourras changer à tout moment dans Réglages.',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            ModuleSwitches(
              selected: _selected,
              onChanged: (m, on) => setState(() => on ? _selected.add(m) : _selected.remove(m)),
            ),
            const SizedBox(height: 12),
            Text(_baseText, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: () => widget.store.update((d) {
                d.modules
                  ..clear()
                  ..addAll(_selected);
                d.onboarded = true;
              }),
              child: const Text('Commencer'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Réglages: add or remove modules at any time.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.store});

  final BudgetStore store;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Réglages')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text('Modules', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ModuleSwitches(
              selected: store.data.modules,
              hiddenCount: (m) => linesIn(store.data, m),
              onChanged: (m, on) => store.update((d) => on ? d.modules.add(m) : d.modules.remove(m)),
            ),
            const SizedBox(height: 12),
            Text(
              'Retirer un module ne supprime rien : ses lignes sont cachées et ne comptent plus dans le budget. '
              'Elles reviennent si tu le remets.',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(_baseText, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            const SizedBox(height: 24),
            Text('Aide', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (kIsWeb) ...[const InstallTip(), const SizedBox(height: 10)],
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: const Icon(Icons.school_outlined),
                title: const Text('Revoir le tuto', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Les fonctionnalités de l’app, page par page.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openTutorial(context, store),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the tutorial again (from the menu or Réglages), with a page per active module.
Future<void> openTutorial(BuildContext context, BudgetStore store) => Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (c) => TutorialScreen(pages: tutoPages(store.data.modules), onDone: () => Navigator.pop(c)),
      ),
    );

/// Web version only: how to put the app on the home screen (and keep the data).
class InstallTip extends StatelessWidget {
  const InstallTip({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.add_to_home_screen, color: cs.onPrimaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Installe l’app sur ton écran d’accueil',
                    style: TextStyle(fontWeight: FontWeight.w700, color: cs.onPrimaryContainer)),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
              'iPhone : dans Safari, touche Partager (le carré avec une flèche), puis « Sur l’écran d’accueil ».\n'
              'Android : dans Chrome, menu ⋮ puis « Ajouter à l’écran d’accueil » ou « Installer l’application ».\n\n'
              'L’app s’ouvre alors en plein écran, et tes données restent bien gardées sur ton téléphone. '
              'Pense quand même à copier une sauvegarde de temps en temps (menu ⋮).',
              style: TextStyle(color: cs.onPrimaryContainer, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
