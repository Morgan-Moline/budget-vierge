import 'package:flutter/material.dart';

import '../models.dart';

/// One page of the tutorial.
class TutoPage {
  const TutoPage(this.icon, this.title, this.text);

  final IconData icon;
  final String title;
  final String text;
}

const _intro = <TutoPage>[
  TutoPage(
    Icons.account_balance_wallet_outlined,
    'Le reste du mois',
    'En haut de l’onglet Mois, un seul chiffre : ce qu’il te reste.\n\n'
        'C’est tes entrées, moins tes dépenses, moins ton découvert de début de mois (ou plus ton positif). '
        'En vert tout va bien, en rouge tu es dans le rouge.',
  ),
  TutoPage(
    Icons.edit_note,
    'Ajouter et modifier une ligne',
    'Le bouton + d’une rubrique ajoute une ligne. Touche une ligne pour changer son nom ou son montant, '
        'ou pour la supprimer.\n\n'
        'Pour additionner, utilise les boutons + − × ÷ sous le montant : 17,46 + 9,55 = 27,01 €.',
  ),
  TutoPage(
    Icons.task_alt,
    'Coche ce qui est prélevé',
    'Dans les charges fixes, les abonnements, les paiements en 4× et les emprunts, coche une ligne quand elle est sortie de ton compte.\n\n'
        'La barre en haut montre ce qui est déjà prélevé et ce qu’il reste à prélever.',
  ),
  TutoPage(
    Icons.calendar_month_outlined,
    'Prépare le mois suivant',
    'L’onglet Suivant reprend ton mois en cours. Ajuste ce qui change : un montant, une ligne en plus ou en moins.\n\n'
        'Les autres dépenses y repartent de zéro : ajoute celles que tu prévois déjà. '
        'En haut, tu vois le reste prévu.',
  ),
  TutoPage(
    Icons.event_repeat,
    'Le 1er du mois, tout bascule',
    'À la première ouverture du mois, le mois suivant devient le mois en cours.\n\n'
        'Le reste du mois écoulé devient ton découvert ou ton positif de début de mois, '
        'et les cases « prélevé » se décochent. Tu n’as rien à faire.',
  ),
];

const _modulePages = <Module, TutoPage>{
  Module.x4: TutoPage(
    Icons.credit_card,
    'Paiements en 4×',
    'Note le montant d’une échéance et la date de la dernière. Coche-la quand elle est prélevée.\n\n'
        'La ligne compte chaque mois jusqu’à cette date, puis disparaît toute seule.',
  ),
  Module.emprunts: TutoPage(
    Icons.account_balance_outlined,
    'Emprunts',
    'Note la mensualité et le mois de la dernière. Coche-la quand elle est prélevée.\n\n'
        'Elle disparaît après sa dernière mensualité.',
  ),
  Module.credits: TutoPage(
    Icons.savings_outlined,
    'Onglet Crédits',
    'Suis le reste d’un emprunt : montant, mensualité et date de départ.\n\n'
        'Et un remboursement : note chaque versement, l’app calcule ce qu’il reste à rembourser.',
  ),
};

const _outro = TutoPage(
  Icons.tune,
  'Modules et sauvegarde',
  'Menu ⋮ → Réglages : ajoute ou retire les paiements en 4×, les emprunts et l’onglet Crédits.\n\n'
      'Menu ⋮ → Copier une sauvegarde : garde une copie de ton budget dans une note ou un mail.\n\n'
      'Tu peux revoir ce tuto à tout moment dans le menu ⋮.',
);

/// The tutorial pages: the basics, one page per module turned on, then modules and backup.
List<TutoPage> tutoPages(Set<Module> modules) => [
      ..._intro,
      for (final m in Module.values)
        if (modules.contains(m)) _modulePages[m]!,
      _outro,
    ];

/// Swipeable tutorial shown at first launch and from the menu.
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key, required this.pages, required this.onDone, this.doneLabel = 'Terminer'});

  final List<TutoPage> pages;
  final VoidCallback onDone;
  final String doneLabel;

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int i) => _controller.animateToPage(i, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final last = _page == widget.pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(
                children: [
                  Text('${_page + 1} / ${widget.pages.length}',
                      style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  if (!last) TextButton(onPressed: widget.onDone, child: const Text('Passer')),
                  if (last) const SizedBox(height: 48),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  for (final p in widget.pages)
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle),
                            child: Icon(p.icon, size: 44, color: cs.primary),
                          ),
                          const SizedBox(height: 28),
                          Text(p.title,
                              style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.3)),
                          const SizedBox(height: 14),
                          Text(p.text, style: const TextStyle(fontSize: 16.5, height: 1.5)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < widget.pages.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _page ? 22 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _page ? cs.primary : cs.outlineVariant,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      if (_page > 0)
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                            onPressed: () => _go(_page - 1),
                            child: const Text('Précédent'),
                          ),
                        ),
                      if (_page > 0) const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                          onPressed: last ? widget.onDone : () => _go(_page + 1),
                          child: Text(last ? widget.doneLabel : 'Suivant'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
