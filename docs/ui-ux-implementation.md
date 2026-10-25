# Harmonisation UI/UX — suivi d’implémentation

Cette phase a été autorisée après remise de [l’audit initial](ui-ux-audit.md). Le rapport initial reste une photographie du code avant corrections ; ses numéros de ligne ne doivent pas servir de référence après refonte.

## Changements réalisés

| Domaine | Changements | Anomalies associées |
|---|---|---|
| Socle | Palette chaude commune, orange interactif lisible avec blanc, texte tertiaire renforcé ; styles TextTheme stables ; espaces/rayons historiques raccordés aux tokens ; breakpoints cohérents. | A01–05, A09 |
| Primitives | Boutons extensibles, cible48, hauteur conservée en chargement, sémantique et disabled ; icônes Material ; erreurs de validator visibles ; sélection annoncée ; grilles produit adaptées au texte agrandi. | A06, A11–12, A18 |
| Livreur | AppCard commune, statut sur une ligne distincte des données client, métadonnées12 minimum, cibles de bandeau48, actions principales cohérentes, largeur de lecture bornée. | A01, A06, A10 |
| Commandes vendeur | Carte commune ; titre/statut et total peuvent se réorganiser ; actions verticales sur écran étroit/texte agrandi ; résumé d’articles, montant et adresse avant validation ; copie accessible ; colonne bornée. | A01, A10, A15 |
| Boutique / ajout produit | Les wrappers de carte et boutons composent les primitives partagées ; indicateur de sélection mutualisé. | A21 |
| Finance | Historique à en-tête neutre et état vide partagé ; code protégé contre répétition ; champ désactivé pendant envoi ; sortie bloquée pendant traitement ; erreur locale au champ ; succès scrollable et fermeture ciblée ; carte client adaptée. | A08, A14, A16, A19 |
| Profil | Distingue attente et échec sans cache ; reprise explicite et traductions FR/EN. | A17 |
| Navigation / en-têtes | Barre basse adapte sa hauteur au texte et expose selected ; conventions de titres pour les pages utilitaires traitées ; les couvertures média et cartes conservent leurs besoins particuliers. | A07, A13 |
| Chargement / feedback | Rayons des squelettes rapprochés des cartes finales ; présentation AppFeedback commune dans la gestion des commandes ; prix PassColis/sélecteur de paiement sans observateur vide lorsque CurrencyService est absent. | A20, A25 ; problèmes UX révélés par tests |
| Thème sombre / placeholder | Paires sémantiques mutualisées ; les tokens respectent le thème injecté sans activer le sombre en production. /post présente un état d’indisponibilité explicite et traduit. | A24, A26 |
| Références | Harness avec thème réel et polices ; quatre goldens existants actualisés et quatre ajoutés : carte vendeur320/390, tableau livreur390, succès320 à200 %. | A23 |

La [charte maintenable](design-system.md) décrit les tokens et contrats à utiliser pour les changements suivants.

## Périmètre préservé et limites

Aucun endpoint, calcul financier, droit, statut métier ou règle de capacité de tournée n’a été modifié. Les ajustements comportementaux concernent la prévention de soumission répétée, la fermeture de dialogue, la reprise du profil et les états d’erreur. Les routes existantes sont conservées. Aucun package ajouté, aucune migration ni suppression de données.

L’adoption du socle se propage aux anciennes vues via les adaptateurs. Cela ne prouve pas que chaque style local des93 fichiers recensés est justifié : des compositions et feedbacks locaux restent à revoir en rendu. AppFeedback est introduit dans le parcours commandes ; tous les Get.snackbar du projet ne sont pas migrés. Les champs spécialisés et médias gardent leurs composants métier.

A22 (backup de recherche, composant non appelé et constante /dashbord) est documentée comme dette non active : aucune suppression de fichier ni de route spéculative. Les quatre nouvelles captures servent de preuves sur leurs fixtures ; la carte du livreur n’a volontairement ni GPS ni tuiles réseau dans les tests. Les dialogues SellerConfirmCodeDialog restent sans point d’entrée trouvé ; leur code partagé a été harmonisé.

À valider sur appareil : navigation native et lecteur d’écran, GPS/permissions et carte réelle, clavier iOS/Android, paiements externes, parcours avec données métier réelles, et éventuelle activation du sombre. Les captures de tests ne constituent pas une validation intégrale de l’application.

## Validation finale

- Les82 fichiers de tests ont été exécutés en deux lots de41 fichiers : **207 réussites +1 échec** dans le premier, **225 réussites** dans le second, soit **432 réussites sur433 cas**.
- L’unique échec concerne `test/announcement_topics_test.dart`, cas « changer de langue change le topic et la marque d’abonnement ». Le test attend une variation du marqueur ; `FirebaseMessagingService.topicMarker` retourne déjà `retired-v2|$token`, indépendamment de la langue. Le service, LocaleService et ce test sont byte pour byte identiques à HEAD : problème préexistant, sans modification des règles de notifications dans ce chantier.
- Après le contrôle final de l’orange sur les surfaces grises, le lot ciblé composants/contrastes/charte et les huit goldens a été réexécuté : **20 tests réussis**. Les comparaisons d’images ne sont pas présentées comme une validation de tous les écrans.
- Analyse statique complète : **0 erreur**,39 avertissements et1648 informations. Commande : `flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings`. La dette de lint restante n’est pas masquée comme une analyse sans diagnostic.
- `git diff --check` sans anomalie ; catalogues FR/EN valides et contrôle de parité passant.
- Le contraste de l’orange interactif final est d’environ **5,61:1 sur blanc**, **5,00:1 sur canvas**, **4,65:1 sur surface atténuée**, **5,12:1 sur fond accent subtil**. Les assertions portent sur ces quatre couples, en plus des textes secondaires.
- Les fichiers GetStorage suivis, temporairement écrits par les mocks des tests, sont restaurés depuis leur version initiale après vérification. Aucune modification de ces données ne fait partie du livrable.

Commandes de reproduction des contrôles ciblés :

```sh
flutter test --no-pub test/design_system_test.dart test/brand_color_test.dart test/auth_golden_test.dart test/ui_consistency_golden_test.dart
flutter test --no-pub test/navigation_keyboard_test.dart test/delivery_dashboard_filters_test.dart test/delivery_carrier_actions_test.dart test/payment_exit_test.dart
flutter test --no-pub
```

La dernière commande expose aussi l’échec de notifications décrit ci-dessus. Pour actualiser une baseline à l’avenir, vérifier le rendu avant d’utiliser `--update-goldens`.
