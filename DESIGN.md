# Charte visuelle ASSO

Ce document décrit le socle visuel de l'application et la façon de s'en
servir. Il s'adresse à quiconque ajoute ou modifie un écran.

## Le principe

**Une seule couleur d'accent : l'orange de marque.**

Toute autre couleur vive doit porter un sens, jamais une décoration :

| Couleur | Rôle | Exemple légitime |
|---|---|---|
| `AppDesign.accent` | action principale, élément actif | bouton « Commander », onglet courant |
| `AppDesign.success` | confirmation, état sain | badge « Livré », boutique vérifiée |
| `AppDesign.warning` | attention, action à prévoir | « Aucun package actif » |
| `AppDesign.danger` | erreur, action irréversible | « Supprimer », IBAN refusé |
| `AppDesign.info` | information neutre | badge de certification |

Tout le reste s'exprime en neutres (`neutral0` … `neutral900`), en
typographie et en espacement. Si une couleur n'apporte aucune information,
elle n'a pas sa place : trois boutons vert / ambre / bleu pour trois actions
neutres ne se distinguent pas mieux que trois boutons gris, mais ils épuisent
le vocabulaire chromatique et affaiblissent les vrais signaux.

## Fichiers

| Fichier | Contenu |
|---|---|
| `lib/app/core/utils/app_design.dart` | tokens : couleurs, espacements, rayons, ombres, gabarits responsives |
| `lib/app/core/widgets/app_ui.dart` | composants : `AppCard`, `AppButton`, `AppBadge`, `AppSectionHeader`, `AppEmptyState`, `AppTextField`, `AppIconButton`, `AppDivider`, `AppContentWidth` |
| `lib/app/core/widgets/product_card.dart` | `ProductCard` et son gabarit de grille partagé |
| `lib/app/core/utils/app_theme_system.dart` | thèmes Material + typographie responsive (délègue aux tokens) |

Dans une vue, `context.ds` donne accès aux couleurs résolues selon le thème :

```dart
Container(
  color: context.ds.surface,
  padding: EdgeInsets.all(AppDesign.space4),
  child: Text('…', style: context.textStyle(
    FontSizeType.body2,
    color: context.ds.textSecondary,
  )),
)
```

## Règles à respecter

**Espacement** — échelle de 4 points (`AppDesign.space1` = 4 … `space12` = 48).
Pas de 10, 13 ou 22 arbitraires : ce sont ces valeurs dépareillées qui font
qu'une interface « ne tombe pas juste ».

**Typographie** — toujours `context.textStyle(FontSizeType.…)`, jamais
`fontSize:` en dur. Les tailles s'adaptent au téléphone, à la tablette et au
réglage d'accessibilité du système ; une valeur figée ignore les trois.

**Texte dans un `Row`** — tout texte venant du serveur (nom de produit,
d'utilisateur, de ville, montant) doit être dans un `Expanded` ou `Flexible`,
avec `maxLines` et `overflow: TextOverflow.ellipsis`. C'est la première cause
de débordement.

**Grilles de produits** — utiliser `ProductCard.gridDelegate(context)`, qui
impose la hauteur réelle d'une carte. Un `childAspectRatio` fait dépendre la
hauteur de la largeur d'écran : les cartes se désalignent et le texte déborde.

**Cibles tactiles** — 48 px minimum (`AppDesign.minTapTarget`). Ne jamais
passer `constraints: BoxConstraints()` vide à un `IconButton` : cela annule
le minimum garanti par Material.

**États vides** — `AppEmptyState`. Une icône mesurée sur fond neutre ; une
icône géante et colorée attire l'œil sur l'absence de contenu plutôt que sur
la sortie proposée. Le message distingue « rien à afficher » de « aucun
résultat pour ces filtres ».

**Dégradés** — réservés aux voiles de lisibilité sur image
(`transparent → noir`). Un dégradé décoratif est un aplat qui s'excuse.

## Vérifier un écran

```bash
flutter analyze lib          # 0 erreur, 0 avertissement attendus
flutter test                 # dont les tests du socle
```

Puis sur appareil, en surveillant la console : un `RenderFlex overflowed`
signale un débordement même s'il n'est pas toujours visible à l'écran.

Tester à plusieurs tailles, le responsive se casse d'abord aux extrêmes :

```bash
adb shell wm size 1080x2400 && adb shell wm density 440   # téléphone compact
adb shell wm size 1600x2560 && adb shell wm density 320   # tablette
adb shell wm size reset     && adb shell wm density reset
```

## Environnement de développement

L'API est configurée dans `lib/app/core/values/constants.dart` et se résout
seule : `10.0.2.2:8000` sur émulateur Android, `localhost:8000` ailleurs.

```bash
# Backend (Laravel) — voir Asso-Backend/setup-local.sh
php artisan serve --host=0.0.0.0 --port=8000

# Application
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

Comptes de démonstration (mot de passe `password`) :
`marie.ahossou@client.com`, `amina.kossou@vendeur.com`, `admin@asso.com`.

Pour peupler la base de démonstration : `php artisan db:seed --class=ProductSeeder`
(le seeder par défaut ne crée volontairement ni boutique ni produit).
