# Mon budget

Application Android (Flutter) pour tenir un budget mensuel simple, avec des modules à la carte.
Aucune donnée au départ : chacun saisit les siennes, qui restent sur son téléphone.

## Ce que fait l'app
- **Mois** : reste du mois (entrées − dépenses − découvert + positif), cases « prélevé » à cocher.
- **Mois suivant** : reprend le mois en cours. On y ajuste les montants, on ajoute ou retire des lignes.
  Le 1er du mois, il remplace automatiquement l'onglet Mois :
  - les autres dépenses repartent de celles prévues ;
  - les paiements 4× et emprunts terminés disparaissent ;
  - les cases « prélevé » se décochent ;
  - le reste du mois écoulé devient le découvert ou le positif de début de mois.
- Rubriques toujours présentes : Entrées, Charges fixes, Abonnements, Charges aléatoires, Autres dépenses.
- **Modules à activer** au premier lancement ou dans **⋮ → Réglages** :
  - Paiements en 4× (avec la date de la dernière échéance) ;
  - Emprunts ;
  - Onglet Crédits : reste d'un emprunt et suivi d'un remboursement.
  Retirer un module cache ses lignes (elles ne comptent plus) sans les supprimer.
- Montants avec calcul grâce aux boutons + − × ÷.
- Menu ⋮ : copier ou restaurer une sauvegarde, tout effacer.

## Mise en place (une seule fois)
1. Dans **Settings → Secrets and variables → Actions**, ajoute :
   `SHOREBIRD_TOKEN` (clé API Shorebird « Full access »), `ANDROID_KEYSTORE_BASE64`,
   `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`.
   Pas de clé Android ? Lance le workflow **Créer la clé Android (une seule fois)** et télécharge l'artefact.
2. **Actions → Shorebird Init (une seule fois)**.
3. **Actions → Shorebird Release Android** : l'APK apparaît dans **Releases**.

## Version web (iPhone, sans App Store)
Le workflow **Version web (GitHub Pages)** publie l'app sur `https://morgan-moline.github.io/budget-vierge/`
à chaque modification (dépôt public et GitHub Pages réglé sur « GitHub Actions »).
Sur iPhone : ouvrir le lien dans Safari → Partager → « Sur l'écran d'accueil ».

## Mises à jour
Un push sur `main` qui touche `lib/` publie un patch Shorebird : l'app se met à jour au lancement suivant
(fermer et rouvrir deux fois). Une modification de `android/` ou un nouveau plugin demande une nouvelle release.

## Développement
```bash
flutter pub get
flutter test
flutter run
```
