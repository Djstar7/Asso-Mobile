# Design system ASSO Mobile

## Source de vérité

`AppDesign` porte les tokens ; `AppThemeSystem` construit les thèmes Material et conserve les adaptateurs des anciennes vues. `app_ui.dart` porte les primitives, `AppSheet` les feuilles et `ToneColors` les paires sémantiques clair/sombre. Aucun package supplémentaire.

## Couleurs

- Orange identitaire : `brandAccent` #E87722, réservé aux illustrations/décors.
- Action interactive : `accent` #A64F0F, texte blanc ; hover #97460B et pressé #8F430B. Utiliser le token, jamais recopier l’hex dans une vue.
- Fonds/surfaces/textes : `context.ds.canvas`, `.surface`, `.surfaceMuted`, `.border`, `.textPrimary`, `.textSecondary`, `.textTertiary`. Le tertiaire est désormais lisible sur les surfaces claires.
- Statuts : succès/avertissement/erreur/information, avec un libellé explicite. `ToneColors` résout les fonds et textes selon le thème. Le mode sombre reste désactivé dans la configuration de production ; son activation demande une validation dédiée.
- Les couleurs produit, prestataire de paiement, itinéraire ou illustration bancaire sont des exceptions fonctionnelles. Elles ne deviennent pas des couleurs d’action concurrentes.

## Typographie et géométrie

SF-Pro ; TextTheme commun. Titres de page17/w600 via AppBarTheme, sections18, corps14–16, actions15/w600, métadonnées12. Les tailles de texte ne dépendent plus de la hauteur de la fenêtre ; TextScaler reste appliqué par Flutter. Le clavier ne doit pas modifier la taille des lettres.

Échelle d’espaces :4/8/12/16/20/24/32/40/48. Gouttières par classes de largeur :16 mobile,24 tablette,32 grande tablette,40 très grande tablette,32 desktop avec colonne de contenu bornée. Les valeurs optiques intermédiaires sont réservées à une composition précise.

Rayons :6 badge,10 champ/bouton,14 carte,18 promotion/dialogue,24 feuille,999 pilule. Les helpers historiques small/medium/large/circular renvoient désormais10/14/18/999. Une nouvelle carte ne doit pas redéfinir son propre rayon8 ou12.

Breakpoints partagés : mobile<600 ; tablette600–899 ; grande tablette900–1023 ; très grande tablette1024–1365 ; desktop≥1366. `isTabletOrLarger` commence à600. La classe historique iPadPro13 décrit ici une largeur, pas une détection matérielle.

## Contrats des primitives

- `AppCard` : surface et bordure communes, padding16 par défaut, option elevated explicite selon le contexte. Garder la composition métier dans le module.
- `AppButton` : cible minimale48 ; grande variante56 ; hauteur extensible pour les textes longs. Le chargement conserve l’espace du libellé et interdit le tap. Utiliser primaire, secondaire, texte ou destructif selon le rôle.
- `AppIconButton` : contrôle Material avec cible48, tooltip, état disabled et sémantique native. La taille visuelle de l’icône reste indépendante de la cible.
- `AppTextField` : libellé persistant ; erreurs externes et erreurs de validator visibles. Ne pas masquer l’erreur native sans fournir une représentation équivalente.
- `AppSheet` : ouverture via AppSheet.show, contenu défilant, fermeture explicite, footer au-dessus du clavier. Ne pas compter deux fois viewInsets.
- `AppEmptyState` : absence de données ou erreur récupérable avec action contextuelle. Les états de chargement, cache, erreur et liste vide restent distincts.
- `AppFeedback` : retour non bloquant commun (position basse par défaut, durée4s, marge16, rayon14). Les erreurs corrigeables d’un formulaire restent près du champ.
- Navigation basse et `SegmentedTabs` : état selected exposé à l’accessibilité, feedback pressé/focus ; libellés visibles ; géométrie adaptée au texte agrandi.

Les boutons de retour continuent d’utiliser AppNavigation/AppBackButton. Une modification graphique ne change ni droits, ni statuts, ni montants, ni destination métier. Pendant une confirmation asynchrone, définir explicitement les possibilités de sortie et protéger la soumission répétée.

## Vérification

`test/helpers/themed_app.dart` applique le thème de production. Les goldens chargent SF-Pro et MaterialIcons. Vérifier320/390/tablette, français/anglais, texte100–200 %, clavier et états métier. Les captures déterministes sont des fixtures de test ; elles ne remplacent pas une validation Android/iOS du GPS, des paiements externes et des lecteurs d’écran.
