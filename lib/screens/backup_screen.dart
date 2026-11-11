import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backup/file_backup.dart';
import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../widgets/common.dart';

/// Number of budget lines (an empty budget needs no backup reminder).
int lineCount(BudgetData d) => sections.fold(0, (a, s) => a + d.section(s.key).length);

/// Show the reminder when the budget has a few lines and no backup was made for 30 days
/// (or ever), unless the user chose "Plus tard" less than a week ago.
bool needsBackupReminder(BudgetData d, DateTime now) {
  if (lineCount(d) < 3) return false;
  final today = DateTime(now.year, now.month, now.day);
  final snooze = parseDate(d.backupSnooze);
  if (snooze != null && today.isBefore(snooze)) return false;
  final last = parseDate(d.lastBackup);
  return last == null || today.difference(last).inDays >= 30;
}

String backupFileName(DateTime now) => 'mon-budget-${isoDate(now)}.json';

Future<void> openBackup(BuildContext context, BudgetStore store) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => BackupScreen(store: store)));

/// Reminder card at the top of the Mois tab.
class BackupBanner extends StatelessWidget {
  const BackupBanner({super.key, required this.store});

  final BudgetStore store;

  @override
  Widget build(BuildContext context) {
    final p = Palette(context);
    final fg = p.fg(Tone.warn);
    final last = store.data.lastBackup;
    return Card(
      margin: EdgeInsets.zero,
      color: p.bg(Tone.warn),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.save_outlined, color: fg),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Pense à sauvegarder ton budget',
                    style: TextStyle(fontWeight: FontWeight.w700, color: fg)),
              ),
            ]),
            const SizedBox(height: 6),
            Text(
              last.isEmpty
                  ? 'Tu n’as encore jamais fait de sauvegarde. Un fichier de sauvegarde te permet de tout retrouver '
                      'si les données du navigateur sont effacées ou si tu changes de téléphone.'
                  : 'Dernière sauvegarde le ${dateLong(last)}. Fais-en une nouvelle pour garder tes derniers changements.',
              style: TextStyle(color: fg, height: 1.35),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => store.update((d) => d.backupSnooze = isoDate(DateTime.now().add(const Duration(days: 7)))),
                  child: Text('Plus tard', style: TextStyle(color: fg)),
                ),
                const SizedBox(width: 4),
                FilledButton(onPressed: () => openBackup(context, store), child: const Text('Sauvegarder')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key, required this.store});

  final BudgetStore store;

  void _done(BuildContext context, String message) {
    store.update((d) {
      d.lastBackup = isoDate(DateTime.now());
      d.backupSnooze = '';
    });
    toast(context, message);
  }

  Future<void> _saveFile(BuildContext context) async {
    // Called directly from the button: browsers only allow downloads right after a tap.
    final name = backupFileName(DateTime.now());
    final ok = await saveBackupFile(name, store.exportJson());
    if (ok && context.mounted) _done(context, 'Sauvegarde créée : $name');
  }

  Future<void> _restoreFile(BuildContext context) async {
    final text = await pickBackupFile();
    if (text == null || !context.mounted) return;
    await _restore(context, text);
  }

  Future<void> _restore(BuildContext context, String text) async {
    final ok = await confirmAction(
      context,
      title: 'Restaurer cette sauvegarde ?',
      message: 'Le budget actuel de cet appareil sera remplacé par celui de la sauvegarde.',
      okLabel: 'Restaurer',
    );
    if (!ok || !context.mounted) return;
    if (store.importJson(text)) {
      _done(context, 'Sauvegarde restaurée');
      Navigator.pop(context);
    } else {
      toast(context, 'Ce fichier n’est pas une sauvegarde de Mon budget.');
    }
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: store.exportJson()));
    if (context.mounted) _done(context, 'Sauvegarde copiée. Colle-la dans une note ou un mail pour la garder.');
  }

  Future<void> _paste(BuildContext context) async {
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Coller une sauvegarde'),
        content: TextField(controller: ctrl, maxLines: 6, decoration: const InputDecoration(hintText: '{ … }')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('Continuer')),
        ],
      ),
    );
    ctrl.dispose();
    if (text == null || text.trim().isEmpty || !context.mounted) return;
    await _restore(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final last = store.data.lastBackup;
        return Scaffold(
          appBar: AppBar(title: const Text('Sauvegarde')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              const Text(
                'Ton budget est enregistré automatiquement sur cet appareil : fermer l’app ou la fenêtre ne fait rien perdre.\n\n'
                'Mais si tu vides les données du navigateur, désinstalles l’app ou changes de téléphone, il est effacé. '
                'Garde un fichier de sauvegarde à l’abri pour tout retrouver.',
                style: TextStyle(height: 1.45),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Icon(last.isEmpty ? Icons.info_outline : Icons.check_circle_outline,
                    size: 20, color: last.isEmpty ? cs.onSurfaceVariant : Palette(context).fg(Tone.good)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(last.isEmpty ? 'Aucune sauvegarde pour l’instant.' : 'Dernière sauvegarde le ${dateLong(last)}.',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 20),
              if (fileBackupSupported) ...[
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: () => _saveFile(context),
                  icon: const Icon(Icons.download),
                  label: const Text('Télécharger une sauvegarde'),
                ),
                const SizedBox(height: 6),
                Text(
                  isAppleMobile
                      ? 'Sur iPhone, choisis « Enregistrer dans Fichiers » (iCloud Drive par exemple), ou envoie-la-toi par mail.'
                      : 'Le fichier arrive dans tes Téléchargements. Range-le dans Google Drive, ou envoie-le-toi par mail.',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: () => _restoreFile(context),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Restaurer depuis un fichier'),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pour retrouver ton budget sur un autre téléphone ou navigateur : ouvre l’app, puis choisis ton fichier mon-budget-….json.',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 28),
                Text('Autre méthode : copier-coller', style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
              ],
              if (!fileBackupSupported) ...[
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: () => _copy(context),
                  icon: const Icon(Icons.copy_all_outlined),
                  label: const Text('Copier la sauvegarde'),
                ),
                const SizedBox(height: 6),
                Text('Colle ensuite le texte dans une note ou un mail pour le garder.',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: () => _paste(context),
                  icon: const Icon(Icons.restore_page_outlined),
                  label: const Text('Coller une sauvegarde'),
                ),
              ] else
                Wrap(spacing: 8, children: [
                  TextButton.icon(
                      onPressed: () => _copy(context),
                      icon: const Icon(Icons.copy_all_outlined),
                      label: const Text('Copier la sauvegarde')),
                  TextButton.icon(
                      onPressed: () => _paste(context),
                      icon: const Icon(Icons.restore_page_outlined),
                      label: const Text('Coller une sauvegarde')),
                ]),
            ],
          ),
        );
      },
    );
  }
}
