# Audit UI/UX et design system — ASSO Mobile

> État initial avant implémentation. Voir le [suivi des corrections autorisées](ui-ux-implementation.md) pour le code et les vérifications après audit.

Date : 25 octobre 2026. Phase : audit et planification uniquement. Technologie : Flutter, Material 3, GetX, SF-Pro. Aucun fichier applicatif modifié.

## Synthèse et niveau de preuve

**Le système de design existe, mais son adoption est incomplète.** `AppDesign`, `AppThemeSystem`, `app_ui.dart` et `AppSheet` constituent une base pertinente. Des helpers antérieurs, des styles Material surchargés et des composants locaux continuent toutefois de produire des règles concurrentes. La différence de géométrie entre l’accueil et les cartes livreur/vendeur est démontrable sans capture. L’accueil présente lui-même des défauts de contraste et des contraintes de hauteur à réévaluer.

Le registre compte **26 anomalies : 0 critique, 8 élevées, 14 moyennes, 4 faibles**. La gravité exprime l’impact potentiel et l’étendue ; elle ne transforme pas un risque de rendu en défaut observé. Aucun blocage critique de parcours n’a été reproduit.

### Méthode et limites

- Recensement structurel des **160 fichiers Dart de vues/widgets**, soit **80 456 lignes** : 93 fichiers de vues, 34 fichiers de widgets centraux, 33 fichiers de widgets métier. Ces nombres comprennent des sections, wrappers, squelettes et un backup ; ils ne représentent pas 160 composants ni 93 écrans indépendants.
- **25 écrans logiques examinés de façon ciblée**, listés dans la matrice de la partie 3 : lecture de leurs enveloppes, styles et extraits utiles, avec approfondissement de l’accueil, du tableau livreur et de la gestion/validation des commandes vendeur. Il ne s’agit pas d’une lecture ligne par ligne des 25 fichiers, ni d’une validation exhaustive de tous leurs états conditionnels.
- **20 composants analysés explicitement** : AppCard, AppContentWidth, AppButton, AppBadge, AppSelectionDot, AppSectionHeader, AppEmptyState, AppTextField, AppDivider, AppIconButton, AppBackButton, AppKeyboardDismisser, AppSheet, ConfirmCodeHeaderIcon, ConfirmCodeNotice, ConfirmCodeField, ConfirmCodeActions, ConfirmCodeSuccessDialog, QuickConfirmCodeDialog, SellerConfirmCodeDialog. Les classes privées internes ne sont pas recomptées. D’autres composants ont été repérés ou lus ponctuellement, sans être ajoutés à ce total.
- Lecture des 58 déclarations de routes produit, de la route de repli et du navigateur immobilier ; recherche des destinations construites directement, des appels de navigation, des interfaces dans les contrôleurs et des tests pertinents.
- Mesure non destructive des contrastes par luminance relative sRGB des tokens opaques ; pas d’échantillonnage de captures.
- **C** : structure ou valeurs confirmées par le code. **V** : conséquence nécessitant un rendu, une interaction ou une vérification de sémantique. **O** : observé visuellement dans l’application ; **aucun constat O dans cette passe**.
- Application non lancée ; aucun appareil, émulateur, compte métier ni jeu de commandes n’a été utilisé. Les quatre PNG de référence existants ont été recensés, pas utilisés comme preuve du rendu courant. Tests Flutter non exécutés, aucune baseline régénérée. Un SDK Flutter est présent, mais sa compatibilité avec le SDK Dart demandé et la disponibilité d’une cible n’ont pas été vérifiées.
- Les annexes recensent les fichiers et les routes ; une déclaration enregistrée ne prouve ni son accessibilité depuis un menu, ni les droits serveur, ni le rendu de ses états. Les modules hors matrice restent à approfondir. Aucun parcours métier n’est déclaré validé de bout en bout.

## Partie 1 — État des lieux

### 1.1 Architecture visuelle actuelle

| Couche | Implémentation et observation |
|---|---|
| Application | `lib/main.dart:126` : GetMaterialApp applique les thèmes clair/sombre d’AppThemeSystem ; thème système conditionné par `enableDynamicTheming`, actuellement faux. |
| Tokens récents | `lib/app/core/utils/app_design.dart` : accent #E87722, neutres chauds, tons sémantiques, espaces de 4 à 48, rayons 6/10/14/18/24/pilule, cible 48, largeurs de contenu. |
| Thème Material | `app_theme_system.dart:720` : ColorScheme et thèmes AppBar, cartes, boutons, champs, chips, feuilles, dialogues, navigation, contrôles et indicateurs. SF-Pro globale. |
| Helpers historiques | Dans le même fichier : tailles de texte calculées depuis hauteur/type d’appareil, rayons small/medium/large calculés depuis largeur, espacements et hauteurs adaptatifs. Les getters de couleurs actuels délèguent largement à AppDesign, mais des constantes historiques restent disponibles. |
| Troisième voie responsive | `lib/app/core/utils/responsive.dart` : breakpoints et rayons 8/12/16/24, mise à l’échelle linéaire par largeur/375. Référence repérée dans PaymentMethodCard, sans appel de ce composant trouvé. Dette latente, pas preuve de divergence visible actuelle. |
| Primitives partagées | `app_ui.dart` : surfaces, actions, badges, champs, états vides, retour/clavier. `app_sheet.dart` : plafond de hauteur, défilement, fermeture et pied de formulaire. |
| Variantes métier | Cartes et boutons locaux dans livraison, commandes, boutique, produit, portefeuille, Diaspo, maritime et chat. Immobilier et litiges adoptent plus largement les nouvelles primitives. |

Mesures lexicales sur les 160 fichiers UI, **définitions et backup inclus**, donc indicateurs d’adoption et non compte d’instances rendues : AppCard apparaît dans 22 fichiers, AppButton dans 33, AppContentWidth dans 9, AppEmptyState dans 30, AppSheet dans 23 ; `BorderRadiusType.medium` subsiste dans 29 fichiers. La centralisation des couleurs a davantage progressé que celle de la géométrie, des états et de la typographie.

### 1.2 Inventaire des espaces et parcours

| Espace | Destinations et parcours repérés | Profondeur de cette passe |
|---|---|---|
| Entrée et identité | splash → onboarding → accueil/connexion/inscription ; OTP, complément de profil, pays, préférences | Routes recensées ; login, inscription, OTP, complément ciblés. |
| Client marketplace | accueil → recherche → produit → variantes/quantité → livraison/carte → paiement ; favoris, boutique vendeur | Accueil approfondi ; recherche/produit/favoris ciblés ; sous-étapes et boutique recensées. |
| Suivi client | barre basse → suivi, commandes, détails de livraison/acompte/contrôle, litiges et produits similaires | Enveloppe Tracking ciblée ; route MY_ORDER réutilise TrackingView(initialSection: orders). Sections et litiges recensés. |
| Vendeur | configuration → dashboard → boutique/produits/inventaire/commandes/statistiques/factures ; validation/annulation ; abonnement/certification/boost | Dashboard, boutique/édition et commandes ciblés ; validation et détail inspectés dans le contrôleur. Autres branches recensées. |
| Livreur | vérification/configuration → dashboard → filtres/demandes/tournée → carte plein écran → retrait/livraison ou remise agence ; courses de litige | Dashboard approfondi ; carte, sections et actions repérées ; permissions/GPS et transitions serveur non exercés. |
| Finance | portefeuille → recharge/retrait/compte de versement → paiement externe ou natif ; historique ; confirmation par code | Portefeuille/historique ciblés ; confirmation rapide et composants communs analysés. Les autres feuilles sont recensées. |
| Transport international | Diaspo/PassColis et maritime → offre/départ → réservation/assurance → paiement ; création/modification et vérification selfie | Création/modification/détail/réservations ciblés ; sous-sections recensées. |
| Import | catalogue → produit de gros → livraison/variantes → paiement | Recensé structurellement ; pas de validation de toutes les combinaisons de prix/livraison. |
| Immobilier / bailleur | navigateur imbriqué → liste/fiche/visite/cabinet/projet/favoris/réservation/conversation ; dashboard bailleur → vérification/éditeur | Accueil immobilier et navigateur examinés ; autres écrans recensés et extraits d’enveloppes lus, pas d’audit complet des formulaires. |
| Communication / support | chat, conversation, notifications/digest, Ma Voix, publication/détail ; profil/réglages/aide/FAQ/légal/licences | Profil/réglages/notifications ciblés ; autres branches recensées. |

Les écrans longue liste incluent des RefreshIndicator, paginations, shimmers et indicateurs d’attente. Plusieurs états vides sont locaux. Les graphiques/statistiques, timelines, cartes géographiques et listes d’inventaire sont des représentations métier distinctes ; l’absence d’un tableau uniforme n’est pas un défaut. Les dialogues/feuilles ne vivent pas exclusivement sous `widgets/` : `order_management_controller.dart` construit validation, annulation, choix livreur et détail de commande. Une harmonisation limitée aux vues les manquerait.

### 1.3 Navigation : continuités déjà établies et points à exercer

- HomeView contient cinq destinations : HomeItemView, SearchTabView, ImportView, TrackingView et ProfileView (`home_view.dart:68`). Le balayage des onglets est désactivé pour éviter les conflits avec les carrousels. Les libellés sont présents.
- Profil et suivi détectent leur insertion comme onglet pour éviter une deuxième AppBar ; SearchTabView réutilise le contenu de SearchView. Préserver cette distinction page/onglet.
- Le retour système de HomeView revient à l’accueil depuis un autre onglet, puis ferme/remonte l’immobilier imbriqué avant de quitter. `AppNavigation.back` utilise maybePop et prévoit un repli vers HOME. Ce sont de bons mécanismes ; leur présence ne prouve pas tous les retours réels.
- L’immobilier dispose de son navigateur id 41 et de dix noms de destinations, dont la racine et le chat partagé. La barre haute de l’accueil est masquée pour chat/visite. Vérifier clavier, retour iOS/Android, liens profonds et cohérence de destination active pendant cette superposition.
- Des écrans s’ouvrent à la fois par route nommée et par constructeur direct, notamment depuis le dashboard vendeur. Vérifier arguments, bindings et retour sur les deux chemins ; ne pas conclure à un défaut de binding sur la seule différence syntaxique.
- `AppNavigation.pop` documente explicitement le cas Get.back + snackbar. Les confirmations par code continuent d’employer Get.back : scénario résiduel à tester (A16).

### 1.4 Accueil comme référence initiale

Qualités confirmées par la composition du code : fond neutre chaud, surfaces blanches, bordure discrète, accent limité aux actions/sélections, recherche de rayon 10, cartes courantes de rayon 14, bannières de rayon 18, catégories en pilules. Gouttière partagée, sections identifiables, cartes produit mutualisées, icônes accompagnées de libellés et barre basse avec fond de sélection. Les tons sémantiques peuvent distinguer un statut sans recolorer toute la carte.

À conserver : cette hiérarchie surface/contenu/action, la densité raisonnable des sections, les contrôleurs de fiche isolés et les composants communs. À ne pas copier sans correction : contraste de l’accent et du texte tertiaire, navigation contrainte à 64 de hauteur, titre local/squelette historique. Le jugement de satisfaction visuelle fourni par l’utilisateur n’a pas été reconfirmé par capture.

## Partie 2 — Registre des anomalies

Les chemins abrégés ci-dessous sont relatifs à `lib/app/`. Les lignes sont des points d’entrée au code observé à cette date, pas une promesse de stabilité après modification. Chaque recommandation est différée à une phase autorisée.

| ID | Gravité / étendue / preuve | Page, composant et source | Constat et référence | Correction recommandée ; dépendances |
|---|---|---|---|---|
| A01 | **Élevé**, transversal, C | Livreur : `modules/deliveryDashboard/views/delivery_dashboard_view.dart:1283` ; vendeur : `modules/orderManagement/widgets/order_card.dart:35` ; `core/utils/app_theme_system.dart:601` | Cartes utilisent medium historique = 8 à largeur 375, contre 14 pour AppCard/CardTheme. Small historique = 4, contre 6/10 selon rôle actuel. Cela explique la géométrie plus carrée ; une carte de commande n’a pas de raison établie d’avoir une autre famille de rayon. | Affecter des rôles stables carte/champ/badge à AppDesign ; conserver les formes de carte géographique et de médias quand utiles. Fondation avant migration des vues. |
| A02 | Moyen, transversal, C | `core/utils/app_theme_system.dart:94,294,1063` ; titres vendeur, livreur, OTP/profil | Texte responsive dépend de la hauteur, TextTheme partiellement défini, styles locaux fixes coexistent. Exemple body2 : 14 à hauteur 800, 11,2 à hauteur 640 ; titre AppBar du thème = 17, h5 historique = 18 × facteur. Rotation et petits écrans modifient la hiérarchie indépendamment du réglage texte utilisateur. | Définir les rôles dans TextTheme, conserver le TextScaler système ; réserver les adaptations à des breakpoints utiles. Dépend du lot typographie. |
| A03 | Moyen, transversal, C | `core/utils/app_theme_system.dart:63-86` ; `core/utils/responsive.dart:10` | getDeviceType classe 600–899 comme tablette mais isTabletOrLarger ne devient vrai qu’à 900 ; desktopBreakpoint=1200 est déclaré mais la branche desktop commence à 1366. Responsive considère desktop dès 900. Contrats contradictoires, conséquences selon les appels. | Un seul modèle de breakpoints ; tests aux bornes et audit des appelants avant changement. A02, A01. |
| A04 | **Élevé**, transversal, C (mesure) | `core/utils/app_design.dart:47` ; `core/utils/app_theme_system.dart:753,812` ; `core/widgets/app_ui.dart:170` | Blanc sur #E87722 = **2,96:1 environ** ; orange sur blanc identique, orange sur accentSubtle ≈2,70. Boutons/libellés actifs et liens de petite taille sont concernés. Le couple échoue au seuil de 4,5:1 du texte courant et même à 3:1. | Distinguer orange identité et couples de couleurs de texte/action conformes ; mesurer aussi focus et pictogrammes. Ne pas adopter automatiquement accentHover sans mesure. Priorité fondation, avant nouvelles captures. |
| A05 | **Élevé**, transversal, C (mesure) | `core/utils/app_design.dart:147` ; AppTextField, AppIconButton et `home/views/home_view.dart:2522` | neutral500 #80807B sur blanc ≈3,97 ; sur canvas #F2F2F0 ≈3,54. Ce token sert à des aides/placeholder et aux libellés de navigation inactifs, qui sont lisibles et actionnables, pas désactivés. | Utiliser un token de texte secondaire conforme pour l’information nécessaire ; réserver le tertiaire faible au décor et aux états réellement inactifs. A04. |
| A06 | Moyen, transversal, C | `core/widgets/app_ui.dart:154,168` ; `modules/storeManagement/views/store_management_view.dart:179` ; livreur `delivery_dashboard_view.dart:1590` | AppButton et thème : rayon10, hauteur48 ; _PrimaryButton boutique : rayon14 et hauteur context.buttonHeight ; actions livreur principales vertes. La diversité sémantique n’est pas entièrement documentée. | Mutualiser actions primaires/secondaires/destructives et états. Vert acceptable pour un résultat/succès ; décider explicitement le rôle « Accepter/Livré » plutôt que recolorer toutes les actions aveuglément. A01, A04. |
| A07 | Moyen, transversal, C | `core/utils/app_theme_system.dart:779` ; favoris `views/favorites_view.dart:24` ; complément `complete_profile_view.dart:19` ; Diaspo `diaspo_detail_view.dart:38` | Le thème prévoit titre17/w600 aligné début ; plusieurs pages forcent centre, h5/h4 ou bold. Les écarts ne correspondent pas à une convention explicite de modalité/hiérarchie. | Définir les en-têtes de page, d’onglet et de dialogue ; exceptions limitées aux médias ou parcours guidés. A02. |
| A08 | Moyen, local, C | `modules/wallet/views/wallet_history_view.dart:16` | L’historique a une AppBar orange/blanc, centrée, alors que le portefeuille utilise une AppBar neutre et un retour standard. Même espace, nouvelle hiérarchie chromatique ; contraste également concerné. | AppBar neutre commune ; conserver la couleur dans les statuts de transactions. A04, A07. |
| A09 | Moyen, transversal, C | `core/utils/app_theme_system.dart:31` ; `modules/notification/views/notification_view.dart:20` ; `modules/diaspoCreate/views/diaspo_create_view.dart:17` | Fond historique #F6F6F6 pour notifications, grey100 (#F5F5F5) pour création Diaspo, canvas actuel #F2F2F0 ailleurs. Blanc/noir et gris Material locaux contournent les neutres chauds résolus. | Employer canvas/surface/muted et tokens de texte par rôle ; les couleurs de carte géographique, produits et prestataires ne sont pas des dérives de marque. A04, A24. |
| A10 | **Élevé**, local répété, C/V | `modules/deliveryDashboard/views/delivery_dashboard_view.dart:106-138` ; `modules/orderManagement/controllers/order_management_controller.dart:964` | Flèches de bandeau en GestureDetector (icône20 + faible padding), fermeture16 sans cible dédiée ; copie de détail commande icône18 + padding2. Ces régions ne garantissent pas les 48 prévus par AppDesign. Mesure de hit-test finale à faire. | Utiliser AppIconButton ou cible explicitement dimensionnée, tooltip et label ; préserver la compacité visuelle. Vérifier gestes carte. A11. |
| A11 | **Élevé**, transversal, C/V | `core/widgets/app_ui.dart:122,351,751` ; `modules/home/views/home_view.dart:2504` | Boutons maison = Material/InkWell ; pas de déclaration explicite des rôles bouton/état disabled/loading dans AppButton/AppIconButton, ni selected dans _NavItem. InkWell fournit une action tap, mais cela ne démontre pas une annonce complète de l’état. AppIconButton garde aussi sa couleur active quand onPressed est nul. | Ajouter un contrat sémantique et des états visuels contrôlés ; tester l’arbre et TalkBack/VoiceOver avant de conclure à l’inaccessibilité réelle. A06. |
| A12 | Moyen, transversal, C/V | `core/widgets/app_ui.dart:154,213,237` | AppButton.small impose40, les autres48/56 ; label limité à une ligne avec ellipse. Le composant garantit sa hauteur, pas la visibilité de l’action à texte long/fort agrandissement. Un TextStyle local continue bien de respecter le TextScaler par défaut : le défaut n’est pas une désactivation automatique du zoom. | Hauteur minimale extensible, règles de retour à la ligne pour actions critiques ; cible48 ou zone de frappe équivalente pour small. Tester traductions et texte200 %. A02, A11. |
| A13 | Moyen, local, C/V | `modules/home/views/home_view.dart:178,2530` | Barre basse haute64 avec pilule, icône22, espacement et texte. Sa hauteur ne suit pas la croissance des libellés ; aucun overflow n’a été observé ici. Splash et highlight sont désactivés, retour pressé peu explicite. | Tester à320 et texte200 %, adapter hauteur minimale et état pressé/focus sans perdre la pastille de sélection ; exposer selected. A02, A11. |
| A14 | Moyen, local partagé, C/V | `modules/wallet/widgets/confirm_code_parts.dart:220` ; `seller_confirm_code_dialog.dart:152` | Succès : Column et Padding sans défilement ; montant24 non flexible. Carte client du dialogue vendeur : montant en Text final non flexible. Risque avec petite hauteur, gros texte, devise ou montant longs. Le dialogue vendeur nommé n’a pas d’appel trouvé, contrairement à QuickConfirmCodeDialog. | Dialogue de succès scrollable et largeur contrainte ; Wrap/flexibilité des données financières sans masquer les montants. Vérifier l’utilité de la variante non appelée. A02, A12. |
| A15 | Moyen, local, C/V | `modules/orderManagement/controllers/order_management_controller.dart:253` | Confirmation de validation : AlertDialog avec titre/message n’affichant que id et client via trParams ; pas de résumé explicite montant/articles/livraison. Ce n’est pas automatiquement un défaut de rayon : AlertDialog hérite déjà du thème. Le niveau d’information de décision diffère du détail. | Définir les données minimales avant engagement et un gabarit de confirmation cohérent ; faire valider la formulation par le métier. A07 ; conserver la validation API. |
| A16 | **Élevé**, local répété, C/V (UX fonctionnelle) | `modules/wallet/widgets/quick_confirm_code_dialog.dart:46,76` ; `confirm_code_parts.dart:145,181` ; `modules/wallet/views/wallet_view.dart:966` | Action Confirmer désactivée pendant envoi, mais onSubmitted du champ reste relié à _submitCode, sans garde isSubmitting. Annuler reste actif ; route ouverte barrierDismissible:true ; succès utilise Get.back après attente sans vérifier que le dialogue est encore courant. Enchaînement pouvant permettre soumissions répétées/fermeture tardive du mauvais écran. Résultat serveur non testé. | Tester entrée répétée, annulation et snackbar pendant attente ; contrat d’attente cohérent, garde de soumission et fermeture ciblant la route. Toute modification comportementale nécessite une phase explicitement autorisée et tests de paiement/livraison. |
| A17 | **Élevé**, local, C/V (UX fonctionnelle) | `modules/profile/views/profile_view.dart:32` ; `modules/profile/controllers/profile_controller.dart:47,64` | La vue affiche un spinner tant que userProfile est vide ; le contrôleur retombe sur le cache mais n’expose pas d’erreur lorsque cache absent/API en échec, et isLoading finit faux. Cette combinaison laisse l’attente sans sortie de reprise dans le corps. | Distinguer attente initiale, erreur avec reprise et profil en cache ; reproduire session sans cache/réseau. Aucun besoin de changer les données métier. |
| A18 | Faible, transversal latent, C | `core/widgets/app_ui.dart:648,687` | AppTextField accepte validator, masque le texte d’erreur natif (taille0), et n’affiche son erreur externe que depuis errorText. Un validator seul peut donc échouer sans message visible. Aucun appel actif combinant ce composant et validator n’a été établi dans cette passe. | Unifier source d’erreur FormField et erreur serveur ; ajouter test de contrat avant réutilisation avec validator. Ne pas annoncer un formulaire courant déjà bloqué. |
| A19 | Moyen, transversal, C | `core/widgets/app_ui.dart:482` ; `modules/wallet/views/wallet_history_view.dart:36` ; `modules/favorites/views/favorites_view.dart:130` | AppEmptyState : icône26 dans bloc56 et largeur360 ; historique : icône80 et Column locale ; favoris : gabarit local. Les mêmes absences de résultats ont une densité et une hiérarchie différentes. | Variantes communes vide initial / filtre sans résultat / erreur ; action reprise/effacer filtres selon besoin, pas un texte universel. A02, A17. |
| A20 | Moyen, transversal, C | `modules/orderManagement/controllers/order_management_controller.dart:290,908` ; `modules/wallet/widgets/quick_confirm_code_dialog.dart:51` | Get.snackbar définit localement fonds/positions/durées ; quelques retours utilisent Colors.green/red au lieu des tokens. SnackBarTheme de Material ne centralise pas automatiquement les surcharges de Get.snackbar. | Un service de feedback avec tons, durée et position définis ; erreur récupérable du champ près du champ, succès non bloquant quand suffisant. A04, A16. |
| A21 | Moyen, transversal, C | `modules/storeManagement/views/store_management_view.dart:154,179,217` ; `modules/addProduct/views/add_product_view.dart:3090` | _Card/_PrimaryButton/_SecondaryButton réimplémentent le socle ; _SelectionDot coexiste avec AppSelectionDot. Même si les couleurs sont déjà communes, la géométrie et l’évolution des états divergent. | Mutualiser le comportement des primitives ; garder la composition métier dans le module. Vérifier les paramètres nécessaires avant substitution. A01, A06, A11. |
| A22 | Faible, transversal latent, C | `modules/search/views/search_view_old_backup.dart` ; `core/utils/responsive.dart` ; `modules/wallet/widgets/payment_method_card.dart` ; `routes/app_routes.dart:25` | Backup définit une autre SearchView sans import trouvé ; PaymentMethodCard/Responsive non appelés dans le parcours recensé ; /dashbord est une constante sans GetPage. Faux positifs possibles lors d’un inventaire naïf et risque de réintroduire l’ancien style. | Documenter éléments non actifs, vérifier entrées externes et prévoir nettoyage séparé après autorisation. A03. Aucun fichier à supprimer en audit. |
| A23 | **Élevé**, transversal, C | `test/auth_golden_test.dart:34-43` ; `lib/main.dart:129` | Golden harness monte GetMaterialApp(home:view) sans AppThemeSystem, alors que la production applique ce thème. Une seule taille logique390×844 est définie ; quatre images seulement (login, inscription, préférences x2). Ces images ne prouvent pas la cohérence du thème de production. | Harness thème/police/locale/données déterministes commun ; comparer thème réel et variantes critiques. Ne pas mettre à jour les goldens en aveugle. Fondation avant migrations. |
| A24 | Faible, transversal latent, C/V | `core/utils/app_theme_system.dart:17,475` ; `modules/notification/views/notification_view.dart:20` ; `modules/wallet/widgets/confirm_code_parts.dart:18` | Deux implémentations de palette sombre et des blancs/noirs explicites subsistent ; isDarkMode dépend d’un flag désactivé. Certaines paires sémantiques sont fixes dans AppBadge et adaptatives dans ToneColors. Ce n’est pas un défaut actuellement reproduit en clair. | Décider du support sombre, puis fusionner résolution de palette et vérifier thèmes injectés ; aucune activation prématurée. A09. |
| A25 | Moyen, transversal, C/V | `modules/home/views/home_view.dart:1198,1223` ; `core/widgets/shimmer_widgets.dart` ; `core/widgets/product_card.dart` | Squelettes d’accueil à rayon8, autres placeholders à4/6/12/16, cartes produit actuelles rayon14. La transition attente→contenu ne partage pas systématiquement la géométrie ; saut de layout à mesurer, pas affirmé. | Squelettes dérivés du gabarit réel et de ses contraintes ; stabiliser dimensions et ratio média. A01, A02. |
| A26 | Faible, local, C/V | `modules/post/views/post_view.dart:12` ; `routes/app_pages.dart:205` | /post est enregistrée mais affiche seulement le texte post.working, taille20. Aucun lien d’entrée interne retrouvé ; accessibilité réelle à confirmer. Il s’agit d’une destination inachevée, pas de l’écran Ma Voix. | Confirmer usage produit/deep link, fournir un état explicite ou une destination appropriée dans une phase séparée. Aucun changement de route ici. |

### Interprétation des confirmations vendeur

La « page de confirmation » signalée ne doit pas être assimilée à un seul fichier sans reproduction :

1. Gestion des commandes → `validateOrder` : AlertDialog hérité du thème ; A15 concerne surtout le résumé de décision. Les cartes de cette page expliquent l’écart d’arrondi (A01).
2. Gestion des commandes → `showOrderDetails` : AppSheet déjà adoptée, mais lignes/articles et petites actions restent locaux (A10).
3. Portefeuille → code de déblocage : **QuickConfirmCodeDialog réellement appelé** (`wallet_view.dart:969`). Rayons18/14/10 et padding24/12 déjà issus d’AppDesign ; ne pas le décrire comme une ancienne UI entièrement carrée.
4. **SellerConfirmCodeDialog** : définition analysée, aucun appel trouvé dans `lib`. Variante potentielle, pas écran utilisateur confirmé. Les composants de code sont communs aux deux dialogues.

La validation visuelle devra faire identifier par l’utilisateur le parcours exact à l’origine du symptôme. Cela n’empêche pas de traiter les causes transversales établies.

## Partie 3 — Matrice comparative des écrans ciblés

Unités : pixels logiques Flutter. R=rayon ; H=hauteur ; G=gouttière AppDesign/context responsive. « À rendre » signifie absence de preuve visuelle ; une contrainte dans le code n’est pas un débordement observé. L’ensemble des critères demandés est couvert, mais pas chaque état de chaque écran.

| Écran / fichier sous modules/ | Couleurs | Typographie | Arrondis | Espacements | Cartes / boutons | Alignements | Navigation | Adaptabilité / cohérence |
|---|---|---|---|---|---|---|---|---|
| Accueil `home/views/home_view.dart` | canvas/surface/accent ; A04–05 | context.textStyle + textes locaux | 10 recherche,14 carte,18 bannière,pilules | G et4/8/12/16 ; résidus | AppCard/AppButton/ProductCard ; squelette8 | sections sur G ; bannière/media spécifiques | 5 onglets ; sélection ; immobilier imbriqué | H64 barre et H56 en-tête à rendre ; référence partielle |
| Connexion `login/views/login_view.dart` | tokens | styles contextuels | champs/bouton10 | échelle AppDesign | AuthScaffold, AppTextField, AppButton | formulaire commun | inscription/reset/visiteur | scaffold défilant ; contraste à corriger |
| Inscription `welcomer/views/welcomer_view.dart` | tokens | styles contextuels | champs10 | 16/20/24 ; bannière ratio .18 | même famille que login | champs en rangées selon contenu | lien connexion/visiteur | rangées, clavier et erreurs à rendre ; bannière différente justifiée |
| OTP `otp/views/otp_view.dart` | helpers thème | h/context + champs | small/medium historiques | context.sectionSpacing | champ/validation locaux | colonne début | AppBackButton | scroll présent ; largeur code/zoom à rendre |
| Complément profil `completeProfile/views/complete_profile_view.dart` | helpers | titre h5 mobile/h4 au-delà | medium historique | context adaptatif | sections/formulaire locaux | titre centré vs thème début | retour spécifique + accueil | poids/taille titre divergents ; longues données à rendre |
| Profil `profile/views/profile_view.dart` | helpers délégués | titre h5 local | medium historique | context | cartes locales | en-tête propre au profil | AppBar conditionnelle onglet/page | bon double contexte ; erreur sans cache A17 |
| Réglages `settings/views/settings_view.dart` | helpers | titre h5 | medium historique | sectionSpacing | groupes locaux | AppBar transparente | retour commun | cohérence géométrique à migrer ; états à rendre |
| Favoris `favorites/views/favorites_view.dart` | tokens + vieux isDark | titre h5/h4 bold | produits14 ; décor local12 | G | ProductCard commun, vide local | titre centré | retour ; suppression groupée | grille déléguée commune ; titre/vide divergent |
| Notifications `notification/views/notification_view.dart` | #F6F6F6 blanc/noir explicites | titre20 bold | composants locaux | valeurs locales | liste/menus ; états locaux | titre local | retour/menu global | thème local rigide ; états long texte à rendre |
| Recherche `search/views/search_view.dart` | thème/tokens | locale/context | locaux12/20/24 et pilules | locales + grille | résultat/vide partagés ; filtres AppSheet | wrapper unique page/onglet | SearchView/SearchTabView | réutilisation positive ; filtres/tris à approfondir |
| Produit `product/views/product_view.dart` | thème/tokens et overlay média | nombreuses surcharges | locaux8/10/12/14/16/20 | locales | _OrderButton, AppButton, AppSheet | média/actions dédiés | fiche à contrôleur isolé ; sous-feuilles | variantes/prix/adresses longs non rendus ; pas d’uniformisation aveugle du média |
| Suivi `tracking/views/tracking_view.dart` | thème/tokens | styles locaux | 12/16/20/25 | recherche→filtres12 puis8 | listes/feuilles locales | enveloppe unifiée commandes/suivi | AppBar conditionnelle | sections imbriquées à tester ; route MY_ORDER réutilise le suivi |
| Dashboard vendeur `vendorDashboard/views/vendor_dashboard_view.dart` | ds.canvas/surface | hiérarchie locale | 10/14/18/pilules | G +4pt | surfaces locales ; shimmer dédié | maxWidth ds centré | AppBackButton, raccourcis directs | largeur bornée : bon modèle ; états hors ligne à rendre |
| Commandes vendeur `orderManagement/views/order_management_view.dart` | tokens/helpers | h5/h6/caption historiques | medium≈8 à375 | G/context + espacements locaux | OrderCard/FiltersSection locaux | liste/statistiques ; filtres sur mêmes marges | retour, AlertDialog, AppSheet détail | pas de maxContentWidth explicite ; A01/A15 ; confirmation à rendre |
| Dashboard livreur `deliveryDashboard/views/delivery_dashboard_view.dart` | tokens + blancs/gris locaux ; CTA vert | metadata10–12 + context | carte medium≈8 ; badges small≈4 ; locaux12/24 | G +6/8/10/12 | _DeliveryCard ; boutons Material locaux | alignements de rangées denses ; carte pleine largeur | retour sur carte ; plein écran ; filtres épinglés | hauteur filtre suit TextScaler : point positif ; autres rangées/cibles à rendre |
| Boutique vendeur `storeManagement/views/store_management_view.dart` | ds | context.button | cartes18 ; primaire14 | G/échelle | _Card/_PrimaryButton/_SecondaryButton | maxWidth ds centré | retour/édition directe | bon gabarit large ; primitives redondantes |
| Éditer boutique `storeManagement/views/edit_store_view.dart` | ds + helpers | locale/context | mélange medium historique et radiusSm | locales/G | AppCard/AppButton/AppSheet + zones locales | formulaires et médias propres | retour commun, picker | paramètres géoloc/documents à rendre ; ancien rayon résiduel |
| Portefeuille `wallet/views/wallet_view.dart` | ds + tokens ; or décor de carte justifié | nombreux styles locaux | 6/8/10/12/14/16 + tokens | marge20 locale et autres | AppCard et composants locaux ; carteH190 | carte financière spécifique | code rapide, réservations, feuilles | montants/devise/solde à rendre ; ne pas traiter l’or comme accent concurrent |
| Historique wallet `wallet/views/wallet_history_view.dart` | AppBar orange/blanc | titre thème + corps local18 | locaux6/8/10/12/16 | locales | filtres/liste/vide icône80 | titre centré | retour blanc | rupture avec wallet ; pas de preuve sur longs montants |
| Créer Diaspo `diaspoCreate/views/diaspo_create_view.dart` | grey100 ; tons sémantiques trajet | getTextStyle historique | paramètres locaux et12 | horizontalPadding/elementSpacing | champs Material, stepper local | titre centré ; étapes en Row | AppBackButton ; pied de navigation | scroll par étape ; pied/clavier à tester |
| Modifier Diaspo `diaspoEdit/views/diaspo_edit_view.dart` | similaire création | similaire création | borderRadius local | helpers context | formulaire/stepper parallèle | titre centré | retour commun | duplication de structure à rapprocher sans confondre règles création/édition |
| Détail Diaspo `diaspoDetail/views/diaspo_detail_view.dart` | thème + tons | styles locaux | 6/10/12/14/16 | locales | cartes locales ; actionsH52 | titre centré | route détail→réservation | plusieurs rayons par rôle non documentés ; long trajet à rendre |
| Réserver Diaspo `diaspoBooking/views/diaspo_booking_view.dart` | thème + tons | styles locaux | 12/14/16 | locales | cartes/champs ; CTAH54 | titre centré | formulaire→paiement | assurance et prix longs à rendre ; aligner composants avec maritime |
| Réserver maritime `maritime/views/maritime_booking_view.dart` | thème + tons | styles locaux | champs12, carte16 | locales | champs remplis ; CTAH54 | titre centré | formulaire→paiement | proche Diaspo, sans primitives uniques ; assurance à approfondir |
| Accueil immobilier `immo/views/immo_home_view.dart` | ds ; CTA projet noir | context.textStyle | 10/14/pilules | G/échelle4pt | AppCard via widgets immo, AppEmptyState | sections/listes ; shell | navigateur 41 ; FAB bailleur/projet | forte adoption tokens ; FAB sombre contextuel à documenter |

### Écarts justifiés et non-anomalies

Les pilules de catégorie, avatars ronds, badges compacts et cartes rectangulaires peuvent légitimement avoir des rayons différents. Une carte de tournée doit montrer retrait et destination ; elle ne doit pas devenir une carte produit. Les bulles de chat, carte bancaire illustrée, vue immersive de visite, graphique et carte géographique ont des contraintes propres. Les teintes de prestataires, métaux de certification et pastilles de variantes produit sont des données/identités externes. Les exceptions du test `brand_color_test.dart` les documentent déjà en partie. L’audit ne considère pas chaque valeur locale ni chaque couleur sémantique comme une faute.

## Partie 4 — Design system cible proposé

### 4.1 Architecture Flutter

Consolider le socle existant, sans dépendance nouvelle :

1. AppDesign définit les valeurs primitives et leurs rôles. ColorScheme porte les couleurs Material standard ; une ThemeExtension immuable et interpolable peut porter espacements, rayons, élévations et paires sémantiques complémentaires si ces valeurs doivent varier par thème. Ne pas maintenir simultanément deux résolveurs de palette.
2. AppThemeSystem devient la fabrique de ThemeData et des thèmes de composants. Les anciens helpers deviennent des adaptateurs temporaires vers les rôles retenus ; retrait seulement après migration des appelants.
3. app_ui/AppSheet portent interaction, accessibilité et géométrie communes. Séparer en fichiers par primitive si nécessaire, sans transformer l’arborescence en objectif en soi.
4. Les modules composent les primitives en OrderCard, DeliveryRequestCard, MonetarySummary, StatusBadge, FilterBar, ConfirmationSummary et FormFooter. Les modèles et règles métier restent dans les modules.
5. Une convention commune couvre AppBar de page, enveloppe d’onglet, feedback et états attente/vide/erreur/reprise. Les widgets ne construisent plus librement une nouvelle grammaire dans chaque contrôleur.

### 4.2 Palette et couples accessibles

Conserver le caractère orange et les neutres chauds actuels. Distinguer **accent identité**, **fond d’action**, **texte d’action**, **fond subtil** et **texte sur fond subtil**. Le couple accentText #9C4A0A / accentSubtle #FDF3EA atteint environ5,65:1 ; il constitue une base déjà existante pour les badges. textSecondary #5F5F5A sur blanc atteint environ6,42:1 et convient mieux à l’information de navigation que le tertiaire actuel.

Pour l’action pleine, comparer une teinte orange plus foncée avec texte blanc à l’orange actuel avec un texte sombre ; choisir en revue visuelle après calcul. Ne pas imposer un nouvel hex arbitraire ici. Les tests doivent vérifier les couples effectifs, pas seulement interdire un second orange. L’actuel garde-fou sur accentText peut devoir évoluer si de nouveaux rôles conformes sont adoptés.

Objectif de contraste pour les contenus textuels : 4,5:1 pour texte courant et 3:1 pour grand texte, en utilisant les seuils et définitions de la référence [W3C, contraste minimum](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html). Ce sont des critères de conception et de test, pas une certification globale WCAG de l’application native. Les contrôles inactifs bénéficient d’une exception, contrairement aux onglets inactifs mais disponibles.

### 4.3 Typographie

| Rôle | Base mobile proposée | Justification |
|---|---|---|
| Titre de page | 17/w600 ; variante éditoriale20–24 | 17 existe dans AppBarTheme ; éviter de le remplacer par h4 dans des pages utilitaires. Les grands titres restent une variante nommée. |
| Titre de section | 18/w600–700 | Proche h5 et AppSectionHeader existants. |
| Corps principal / champ | 14–16/w400–500, hauteur1,4–1,5 selon densité | Reprend body2/body1, sans réduction automatique à11,2 sur petit écran. |
| Action | 15/w600, hauteur minimale48 | Déjà présent dans le thème bouton ; permettre le retour à la ligne si essentiel. |
| Métadonnée / aide | 12–13, couleur conforme | Les statuts à10–11 du livreur doivent être réévalués ; ne pas cacher une donnée métier importante dans une miniature. |
| Montant / code | variantes dédiées, chiffres tabulaires si utiles | Le code26/espacement8 est fonctionnel, mais doit tenir dans la fenêtre/clavier ; montant extensible et lisible. |

SF-Pro reste la famille commune. Le pubspec ne déclare qu’un fichier sans correspondances de poids : vérifier les métadonnées de la police et le rendu w400/500/600/700 sur Android/iOS avant d’affirmer que les graisses sont absentes. Toute taille locale respecte normalement TextScaler ; le problème à tester est l’espace disponible. Préférer TextTheme aux helpers fondés sur la hauteur. Le choix des variantes tablette doit servir la lecture, pas agrandir toutes les dimensions proportionnellement.

### 4.4 Espaces, rayons, surfaces et dimensions

- Conserver l’échelle **4/8/12/16/20/24/32/40/48** déjà déclarée. Les valeurs2/6 peuvent rester des ajustements optiques nommés (séparateur, alignement d’icône), pas des nouvelles marges de page.
- Gouttière mobile nominale16, tablette24, large32 ; utiliser un contrat unique et explicite. Les largeurs actuelles720/880/1040/1140 sont des points de départ à tester et à simplifier, pas des tailles à imposer à tout tableau/carte.
- Rayons par rôle : badge6, champ/bouton10, carte14, promotion18, feuille24, pilule999. Ces valeurs reprennent AppDesign et l’accueil. Un dialogue18 est acceptable comme rôle distinct si la convention est assumée ; ne pas conclure que toute différence18/24 est fautive.
- Carte standard : surface, bordure1, padding16 ; variante dense12 justifiée pour liste de travail ; élévation nulle pour une liste simple, shadowSm seulement lorsqu’une surface doit se détacher. Le thème Card est sans ombre alors qu’AppCard est élevée par défaut : documenter cette variante avant généralisation.
- Garder deux niveaux d’ombre existants ; éviter les nouvelles ombres colorées. Fonds de carte géographique et overlays médias restent spécifiques.
- Cible d’interaction **48×48 logiques** comme standard produit existant. Elle ne doit pas être confondue avec le minimum WCAG web de24 CSS px et ses exceptions : [W3C, taille de cible](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html). La petite icône peut rester16–22 dans une cible48.

### 4.5 Contrats des composants et états

| Composant | Règles proposées |
|---|---|
| Bouton | primaire/secondaire/texte/destructif ; hauteur minimale48, rayon10 ; focus/pressé/désactivé/chargement ; rôle sémantique, annonce du chargement ; garde de répétition à la frontière de l’action. Une action principale par étape, plusieurs confirmations possibles dans une liste. |
| Champ | label persistant, aides et erreurs visibles ; source de validation unique ; états repos/focus/erreur/désactivé ; autofill et clavier adaptés ; aucun effacement silencieux des messages de validator. |
| Carte | géométrie commune et variantes métier explicites ; zone tactile et sélection annoncées ; ordre titre→statut→données→action stable. Montants/adresses ne deviennent pas illisibles pour respecter une hauteur fixe. |
| Badge | tonalité associée à un sens et à un libellé ; couleurs définies pour clair/sombre ; statut distingué autrement que par couleur seule. |
| Dialogue / feuille | titre/action/retour ou fermeture ; contenu scrollable ; actions atteignables clavier ouvert ; confirmation comprenant les données nécessaires à la décision ; modalité pendant requête définie explicitement. |
| Barre de filtres | variante de SegmentedTabs ou chips commune ; actif/compte/disabled annoncés ; débordement horizontal ou Wrap choisi selon la quantité ; pas de double rangée de filtres redondants. |
| État de page | attente initiale, rafraîchissement, cache, erreur récupérable, absence de données, recherche vide ; action de reprise adaptée ; skeleton reprend le gabarit final. |
| Icônes | famille Material existante, variante rounded/outlines selon rôle ; 20–24 pour actions,16–18 pour métadonnées ; conserver les icônes métier distinctes ; tooltip/label pour action sans texte. |
| Navigation | même retour commun sauf contrat de parcours explicite ; statut selected de destination ; presse/focus visibles ; aucun changement des droits et destinations métier par une simple migration graphique. |

Exceptions à documenter : plein écran carte/vidéo/visite, bulles de discussion, couleurs prestataire, indicateurs logistiques et variantes produit, tableaux ou graphiques larges, étapes guidées et informations financières à forte saillance.

## Partie 5 — Plan d’implémentation priorisé (non exécuté)

| Lot / priorité | Corrections et fichiers principaux | Dépendances / risques | Critères d’acceptation |
|---|---|---|---|
| 0 — P0, validation de référence | Confirmer le parcours de « confirmation vendeur », préparer fixtures client/vendeur/livreur, relever les trois écrans prioritaires et états critiques. Construire harness visuel avec ThemeData réel ; `test/auth_golden_test.dart`. | A23 ; risque de valider une ancienne baseline ou des données trop courtes. | Écrans et états identifiés, thème/police/locale figés, captures de référence approuvées ; aucune donnée réelle modifiée. |
| 1 — P0, fondations transversales | A01–05/A09/A24 : `app_design.dart`, `app_theme_system.dart`, `responsive.dart`, conventions TextTheme/ColorScheme/échelle. Définir une stratégie de compatibilité. | Impacts très larges ; changer medium globalement avant de classifier ses usages peut aussi arrondir des petits badges de façon excessive. | Couples de texte conformes ; rôles de rayons documentés ; breakpoints testés aux bornes ; zoom texte préservé ; exceptions nommées. |
| 2 — P0, interactions communes | A10–12/A18/A20/A21 : `app_ui.dart`, `app_sheet.dart`, feedback, ConfirmationSummary, FormFooter, états et filtres. | Sémantique, taille, validation et comportements disabled/loading ; éviter de changer les callbacks et les règles métier. | Composants vérifiés dans tous leurs états ; cibles48 ; action et montant lisibles ; erreurs de validation visibles ; annonce selected/disabled/loading. |
| 3 — P0, risques UX transactionnels | A16/A17 : code de déblocage, confirm_code_parts, wallet_view, profil/contrôleur. Isoler cette correction fonctionnelle de la migration esthétique. | Nécessite autorisation d’implémenter ce comportement ; réponse tardive, snackbar et sortie pendant attente. | Un seul déclenchement côté UI ; navigation correcte après fermeture ; état erreur/reprise profil ; tests serveur mocks succès/échec/retard ; idempotence serveur à vérifier séparément. |
| 4 — P1, espace livreur | Dashboard, _DeliveryCard, bandeaux carte, carte plein écran et courses de litige : A01/A06/A10 ; lisibilité10–12 et hiérarchie commission/statut. | Les statuts transporteur/agence et la capacité de tournée doivent conserver leurs règles ; gestes carte et slivers sensibles. | Même famille visuelle que socle ; bonnes cibles ; filtres lisibles à320/200 % ; retrait/livraison/agence et retour carte fonctionnent sans altération métier. |
| 5 — P1, commandes vendeur | OrderManagementView, OrderCard, FiltersSection et dialogues/feuilles du contrôleur ; validation/annulation/détail/acompte. | A01/A07/A15 ; montants/articles, filtres déployés et commandes transporteur. | Résumé de décision approuvé ; cartes harmonisées ; articles/adresses longs lisibles ; validations/annulations identiques côté métier ; sorties cohérentes. |
| 6 — P1, finance | Wallet/history, confirmations, recharge/retrait, comptes de versement, moyens de paiement, attente mobile money et WebViews ; A08/A14/A19. | Argent/devise, clavier, actions pendant attente ; interfaces externes Stripe/WebView partiellement hors contrôle graphique. | Totaux visibles ; parcours succès/annulation/échec testés ; AppBar et feedback cohérents ; libellés et codes non coupés. |
| 7 — P2, vendeur élargi | Dashboard, boutique/édition, produits/éditeur variantes, inventaire, statistiques/factures, abonnements/certifications/boost. | A21 ; traiter les wrappers avant leurs pages ; hors ligne et médias. | Même contrat carte/bouton/états ; comparaisons dashboard→commande→boutique cohérentes ; brouillon/hors ligne conservés. |
| 8 — P2, client et transport | Accueil/recherche/produit/suivi/favoris, import, Diaspo création/édition/détail/réservation, maritime ; A07/A13/A25. | Ne pas copier le média produit dans les formulaires ; international/variantes et navigation page/onglet. | Référence accueil corrigée ; flux produit→paiement→suivi stable ; grilles adaptatives ; formulaires à marge et pied cohérents ; assurance et calculs inchangés. |
| 9 — P2, reste et consolidation | Immobilier/bailleur, chat/notifications/Ma Voix, profil/réglages/identité/support/légal ; approfondir les fichiers seulement recensés. A22/A26. | Shell imbriqué, plein écran, longs textes et traductions ; contenus légaux distincts. | Chaque destination de l’annexe reçoit une fiche de validation ; exception justifiée ou écart traité ; parcours imbriqués stables ; dette non active documentée, nettoyage séparé. |

Le changement des fondations doit être progressif : tester les primitives, migrer les trois parcours prioritaires, puis étendre. Une substitution globale de toutes les valeurs8/12/16 serait risquée et ne distinguerait pas densité métier, géométrie des médias et contrôles.

## Partie 6 — Validation qualité

### 6.1 Protocole de rendu

Créer une galerie de composants et des fixtures sans réseau dépendantes de données déterministes, puis capturer seulement les états représentatifs :

- Largeurs logiques320,375/390,600,900 et1200 ; ajouter les bornes599/600,899/900,1023/1024,1365/1366 aux tests du contrat responsive. Une hauteur courte et le paysage sont nécessaires pour les dialogues.
- Texte100 %,130 % et200 %, français et anglais ; clavier fermé/ouvert. Ne pas neutraliser TextScaler pour faire passer une capture.
- Au moins un Android et un iPhone pour SafeArea, encoche, barre système, clavier, retour et lecteurs d’écran. Prévoir carte sans GPS/permission refusée et erreur réseau.
- Thème clair obligatoire. Le sombre n’entre dans les critères de mise en production que si son support est décidé ; tester néanmoins le thème injecté si les primitives le revendiquent.
- Données longues : nom client/boutique, adresse multi-ligne, 6 caractères du code, montants et devises, variantes multiples, statuts longs, message d’erreur et liste vide filtrée.

Pour chaque capture : vérifier grille/gouttières, absence de RenderFlex overflow, coupure de texte essentiel, collisions des actions, continuité des surfaces, tailles de titre, rayons par rôle, position du bouton et accès à la fermeture. Comparaison humaine indispensable : un golden identique à une mauvaise référence ne suffit pas.

### 6.2 Tests existants utiles (lus ou recensés, non exécutés)

| Fichier de test | Valeur pour le chantier / limite |
|---|---|
| `test/brand_color_test.dart` | Contrôle source des oranges et de l’usage accentText ; ne mesure pas le contraste, ni les rayons et états. |
| `test/auth_golden_test.dart` | Quatre golden cases, une taille390×844 ; harness sans thème de production (A23). |
| `test/auth_screens_test.dart` | Formulaires, liens, débordements et clavier ; compléter avec thème et zoom. |
| `test/navigation_keyboard_test.dart` | Retour/garde/repli accueil, fermeture clavier, AppSheet et ouverture page/onglet. |
| `test/delivery_dashboard_filters_test.dart` | Teste plusieurs largeurs et TextScaler pour les filtres ; ne prouve pas toutes les cartes de mission. |
| `test/delivery_carrier_actions_test.dart` | Actions transporteur et distance ; étendre à états de tournée sans modifier les règles. |
| `test/tracking_order_control_test.dart`, `customer_order_handover_test.dart` | Contrôle client/remise transporteur ; préserver les différences métier. |
| `test/payment_exit_test.dart` | Fermeture malgré bannière dans sélection/confirmation paiement ; étendre aux dialogues de code encore en Get.back. |
| `test/edit_store_view_test.dart`, `dispute_workflow_test.dart`, tests immobilier/import | Tests présents à intégrer aux lots correspondants après lecture détaillée ; couverture intégrale non affirmée. |

Tests à ajouter pendant l’implémentation : contrastes de couples effectifs ; contrat des rayons/breakpoints ; sémantique selected/button/enabled/loading et labels ; AppTextField avec validator ; AppButton long/zoom ; missions longues et pied de dialogue ; submit code répété/annulation/réponse tardive ; profil vide sans cache/API en erreur. Les assertions doivent porter sur comportements et lisibilité, pas recopier l’arbre d’implémentation.

### 6.3 Parcours et critères de clôture

1. Client : connexion ou invité → recherche → produit/variante → livraison → paiement → commandes/suivi → contrôle/litige ; retour depuis notification/lien profond.
2. Vendeur : dashboard → commande → détail → validation/annulation → message/transporteur → portefeuille ; répétition en mode hors ligne et reprise lorsque pertinent.
3. Livreur : accès au rôle → disponibilité/filtre → accepter/refuser → tournée → carte → retrait/remise agence/livraison ; capacité pleine, erreur et GPS absent.
4. International : création/modification offre → détail → réservation/assurance → paiement → déblocage et historique ; parcours maritime distinct.
5. Immobilier : ouverture du shell → fiche/visite → réservation → conversation → retour à l’onglet initial ; bailleur vérification/édition distinct.

Clôture de chaque lot : aucun écart de style sans rôle ou exception explicite, aucune information ou action métier essentielle masquée aux tailles cibles, aucun débordement Flutter dans les scénarios, toutes les primitives cohérentes avec ThemeData, destination active et retour compréhensibles, montants et transitions métier identiques aux fixtures avant refonte. Les tests fonctionnels existants pertinents passent ; les captures nouvelles sont relues et approuvées humainement.

### 6.4 Vérifications restantes et conditions

Le rendu complet des 93 fichiers de vues et des sous-états n’a pas été vérifié. Priorité aux fiches hors matrice : import/gros, produit et ses nombreuses variantes, chat/conversation, tableaux/graphiques, immobilier/réservations/bailleur, configuration vendeur/livreur, Stripe, abonnements/boost, litiges et documents. Prévoir fixtures de rôles, statuts et permissions, un environnement de test sans transaction réelle et la possibilité de simuler réseau/serveur/GPS/clavier. Les WebViews et la feuille Stripe doivent être évaluées selon leurs possibilités natives, sans promettre une identité parfaite hors du contrôle Flutter.

Aucune autorisation d’implémentation n’est présumée. Ce rapport est le seul livrable créé ; les corrections, les changements de tests et la régénération des références attendent une autorisation explicite.

## Annexe A — Inventaire des routes enregistrées

Recensement de configuration, pas preuve de passage utilisateur. Sources : `lib/app/routes/app_pages.dart` et `app_routes.dart`. Les arguments et contrôleurs restent à valider en exécution.

| Route | Widget cible / variante | Ligne app_pages.dart |
|---|---|---|
| `/introuvable` | `UnknownRouteView()` | 121 |
| `/home` | `HomeView()` | 127 |
| `/splash` | `SplashView()` | 132 |
| `/onboarding` | `OnboardingView()` | 137 |
| `/welcomer` | `WelcomerView()` | 142 |
| `/login` | `LoginView()` | 147 |
| `/search` | `SearchView()` | 152 |
| `/chat` | `ChatView()` | 156 |
| `/chatdetail` | `ChatdetailPage()` | 161 |
| `/notification` | `NotificationView()` | 165 |
| `/profile` | `ProfileView()` | 170 |
| `/tracking` | `TrackingView()` | 175 |
| `/product` | `ProductPage()` | 180 |
| `/favorites` | `FavoritesView()` | 185 |
| `/settings` | `SettingsView()` | 190 |
| `/shipment` | `ShipmentView()` | 195 |
| `/preferences` | `PreferencesView()` | 200 |
| `/post` | `PostView()` | 205 |
| `/complete-profile` | `CompleteProfileView()` | 210 |
| `/otp` | `OtpView()` | 215 |
| `/delivery-dashboard` | `DeliveryDashboardView()` | 220 |
| `/vendor-dashboard` | `VendorDashboardView()` | 225 |
| `/wallet` | `WalletView()` | 230 |
| `/stripe-connect` | `StripeConnectView()` | 235 |
| `/vendor-config` | `VendorConfigView()` | 240 |
| `/order-management` | `OrderManagementView()` | 245 |
| `/store-management` | `StoreManagementView()` | 250 |
| `/ship-config` | `ShipConfigView()` | 255 |
| `/delivery-check` | `DeliveryCheckView()` | 260 |
| `/my-order` | `TrackingView(initialSection: TrackingSection.orders)` | 265 |
| `/help` | `HelpView()` | 270 |
| `/faq` | `FaqView()` | 275 |
| `/about` | `AboutView()` | 280 |
| `/legal` | `LegalView()` | 285 |
| `/disputes/detail` | `DisputeDetailView()` | 292 |
| `/vendor/disputes` | `VendorDisputesView()` | 297 |
| `/disputes/similar` | `SimilarProductsView()` | 302 |
| `/package-subscription` | `PackageSubscriptionView()` | 307 |
| `/certification-packages` | `CertificationPackagesView()` | 312 |
| `/sales-program` | `SalesProgramView()` | 317 |
| `/sales-program/success` | `SalesProgramSuccessView()` | 322 |
| `/product-management` | `ProductManagementView()` | 326 |
| `/add-product` | `AddProductView()` | 331 |
| `/wallet/history` | `WalletHistoryView()` | 336 |
| `/inventory-list` | `InventoryListView()` | 341 |
| `/invoices` | `InvoicesView()` | 346 |
| `/vendor-details` | `VendorDetailsPage()` | 351 |
| `/my-voice` | `MyVoiceView()` | 355 |
| `/shop-statistics` | `ShopStatisticsView()` | 360 |
| `/boost` | `BoostView()` | 365 |
| `/boost-detail` | `BoostDetailView()` | 370 |
| `/post-detail` | `PostDetailView()` | 375 |
| `/diaspo` | `DiaspoListView()` | 380 |
| `/diaspo/create` | `DiaspoCreateView()` | 385 |
| `/diaspo/edit` | `DiaspoEditView()` | 390 |
| `/diaspo/detail` | `DiaspoDetailPage()` | 395 |
| `/diaspo/booking` | `DiaspoBookingView()` | 400 |
| `/diaspo/maritime/booking` | `MaritimeBookingView()` | 405 |
| `/country-selection` | `CountrySelectionView()` | 410 |

58 routes produit et une route de repli `/introuvable`. La constante `/dashbord` n’a pas de GetPage correspondant. `/my-order` et `/tracking` convergent vers TrackingView, avec sections initiales différentes ; ce ne sont pas deux implémentations de liste à harmoniser indépendamment.

Destinations du navigateur immobilier (`lib/app/modules/immo/immo_nav.dart:25`) : `/` → ImmoHomeView, `/listing` → ImmoListingView, `/tour` → ImmoRoomTourView, `/cabinet` → ImmoCabinetView, `/project` → ImmoProjectView, `/favorites` → ImmoFavoritesView, `/chat` → ChatdetailPage, `/reserve` → ImmoReserveView, `/reservation` → ImmoReservationView, `/reservations` → ImmoReservationsView. Ces noms appartiennent au navigateur 41 et ne doivent pas être confondus avec les routes racine de même suffixe.

### Destinations construites directement repérées

Recherche statique des appels Get.to/off et des constructeurs de routes ; liste utile pour les interfaces absentes du registre nommé, non garantie exhaustive pour les callbacks indirects :

| Point d’entrée | Destinations |
|---|---|
| Dashboard vendeur | OrderManagementView, StoreManagementView, WalletView |
| Boutique vendeur | EditStoreView |
| Accueil / immobilier | LandlordDashboardView |
| Dashboard bailleur | LandlordEditorView, LandlordVerificationView, ImmoReservationView |
| Paiement Diaspo / maritime / produit de gros | PaymentWebView |
| Paiement abonnement réussi | InvoiceWebView |
| Liens documentaires / licences | LegalDocumentView, LicensesView, détail des licences d’un package |
| Notifications Firebase | ImmoReservationView, LandlordDashboardView, NotificationDigestView |
| Dashboard livreur | DeliveryMapFullscreenView |
| Flows de localisation / médias / vérification | MapSelectionView, MapLocationPickerView, ProductImageViewer, vidéo plein écran, SelfieCaptureView : définitions et références repérées ; conditions d’entrée non exercées |

## Annexe B — Les 93 fichiers de vues : périmètre et géométrie repérée

Chemins relatifs à `lib/app/modules/`. **Ciblé** correspond aux 25 écrans de la matrice ; **recensé** signifie lecture structurelle (classes/enveloppes/styles/références) uniquement, pas audit écran par écran accompli. « Section » désigne un fragment plutôt qu’une destination autonome ; la colonne couverture ne présume pas que chaque classe du fichier ait été inspectée. Les rayons sont les expressions `BorderRadius.circular` repérées, complétées par les helpers small/medium/large ; les formes verticales/only et héritées ne sont pas intégralement décrites. Une liste de rayons n’est pas une liste d’anomalies.

| Fichier | Couverture | Classes UI déclarées / famille | Rayons repérés |
|---|---|---|---|
| `about/views/about_view.dart` | Recensé | AboutView | helper:medium |
| `about/views/licenses_view.dart` | Recensé | LicensesView | 12, helper:medium |
| `addProduct/views/add_product_view.dart` | Recensé | AddProductView | 12, 16, 2, 6, radiusLg, radiusMd, radiusMd - 1, radiusPill, radiusSm, radiusXs, helper:large, helper:medium, helper:small |
| `addProduct/views/variant_editor_page.dart` | Recensé | VariantEditorPage | 10, 12, 14, 16, 8 |
| `boost/views/boost_detail_view.dart` | Recensé | BoostDetailView | 10, 12, 16, 3, 5 |
| `boost/views/boost_view.dart` | Recensé | BoostView | 12, 16 |
| `certificationPackages/views/certification_packages_view.dart` | Recensé | Déclaration/section à approfondir | radiusLg, radiusSm |
| `chat/views/chat_view.dart` | Recensé | ChatView | 12, 2, radiusPill, helper:small |
| `chatdetail/views/chatdetail_view.dart` | Recensé | ChatdetailPage, ChatdetailView | 10, 12, 16, 2, 24, 4, 8 |
| `completeProfile/views/complete_profile_view.dart` | Ciblé | CompleteProfileView | helper:medium |
| `countrySelection/views/country_selection_view.dart` | Recensé | CountrySelectionView | radiusPill, radiusSm |
| `deliveryCheck/views/delivery_check_view.dart` | Recensé | DeliveryCheckView | hérité/forme spécifique, non détaillé |
| `deliveryDashboard/views/delivery_dashboard_view.dart` | Ciblé | DeliveryDashboardView | 12, 24, 25, 8, helper:medium, helper:small |
| `deliveryDashboard/views/delivery_map_fullscreen_view.dart` | Recensé | DeliveryMapFullscreenView | 16 |
| `deliveryDashboard/views/dispute_courses_section.dart` | Section recensée | DisputeCoursesSection | helper:medium, helper:small |
| `diaspoBooking/views/diaspo_booking_view.dart` | Ciblé | DiaspoBookingView | 12, 14, 16 |
| `diaspoCreate/views/diaspo_create_view.dart` | Ciblé | DiaspoCreateView | 12, 2, borderRadius, helper:medium |
| `diaspoDetail/views/diaspo_detail_view.dart` | Ciblé | DiaspoDetailPage, DiaspoDetailView | 10, 12, 14, 16, 6 |
| `diaspoEdit/views/diaspo_edit_view.dart` | Ciblé | DiaspoEditView | 2, borderRadius, helper:medium |
| `diaspoList/views/diaspo_list_view.dart` | Recensé | DiaspoListView | 10, 12, 16, 20, 4, 8, 9 |
| `diaspoList/views/passcolis_section.dart` | Section recensée | PasscolisSection | hérité/forme spécifique, non détaillé |
| `diaspoList/views/selfie_capture_view.dart` | Recensé | SelfieCaptureView | hérité/forme spécifique, non détaillé |
| `disputes/views/dispute_detail_view.dart` | Recensé | DisputeDetailView | radiusSm |
| `disputes/views/similar_products_view.dart` | Recensé | SimilarProductsView | radiusSm |
| `disputes/views/vendor_disputes_view.dart` | Recensé | VendorDisputesView | hérité/forme spécifique, non détaillé |
| `faq/views/faq_view.dart` | Recensé | FaqView | 2, helper:medium |
| `favorites/views/favorites_view.dart` | Ciblé | FavoritesView | 12 |
| `help/views/help_view.dart` | Recensé | HelpView | 8, helper:medium |
| `home/views/home_view.dart` | Ciblé | HomeView, HomeItemView | 3, 8, radiusLg, radiusMd, radiusPill, radiusSm, helper:medium |
| `immo/views/immo_cabinet_view.dart` | Recensé | ImmoCabinetView | hérité/forme spécifique, non détaillé |
| `immo/views/immo_favorites_view.dart` | Recensé | ImmoFavoritesView | hérité/forme spécifique, non détaillé |
| `immo/views/immo_home_view.dart` | Ciblé | ImmoHomeView | radiusMd, radiusSm |
| `immo/views/immo_listing_view.dart` | Recensé | ImmoListingView | radiusMd, radiusPill, radiusSm |
| `immo/views/immo_project_view.dart` | Recensé | ImmoProjectView | hérité/forme spécifique, non détaillé |
| `immo/views/immo_reservation_view.dart` | Recensé | ImmoReservationView, ImmoReservationsView, ImmoReservationTile | radiusSm |
| `immo/views/immo_reserve_view.dart` | Recensé | ImmoReserveView | radiusPill |
| `immo/views/immo_room_tour_view.dart` | Recensé | ImmoRoomTourView | hérité/forme spécifique, non détaillé |
| `import/views/import_view.dart` | Recensé | ImportView | radiusMd, radiusPill, space1 |
| `import/views/wholesale_product_view.dart` | Recensé | WholesaleProductView | radiusSm |
| `inventoryList/views/inventory_list_view.dart` | Recensé | InventoryListView | 10, 12, 8 |
| `invoices/views/invoices_view.dart` | Recensé | InvoicesView | helper:medium, helper:small |
| `landlord/views/landlord_dashboard_view.dart` | Recensé | LandlordDashboardView | radiusSm |
| `landlord/views/landlord_editor_view.dart` | Recensé | LandlordEditorView | radiusSm |
| `landlord/views/landlord_verification_view.dart` | Recensé | LandlordVerificationView | radiusSm |
| `legal/views/legal_document_view.dart` | Recensé | LegalDocumentView | 12, helper:medium |
| `legal/views/legal_view.dart` | Recensé | LegalView, LegalDocumentsCard, LegalTile | 8, helper:medium |
| `login/views/login_view.dart` | Ciblé | LoginView | radiusSm |
| `maritime/views/freight_inquiries_view.dart` | Recensé | FreightInquiriesView | hérité/forme spécifique, non détaillé |
| `maritime/views/maritime_booking_view.dart` | Ciblé | MaritimeBookingView | 10, 12, 14, 16 |
| `maritime/views/maritime_contact_button.dart` | Section recensée | MaritimeContactButton | hérité/forme spécifique, non détaillé |
| `maritime/views/maritime_insurance_section.dart` | Section recensée | MaritimeInsuranceSection | hérité/forme spécifique, non détaillé |
| `maritime/views/maritime_section.dart` | Section recensée | MaritimeSection | 10, 12, 16, 8 |
| `myOrder/views/my_order_view.dart` | Recensé | MyOrderList | 12, helper:medium, helper:small |
| `myOrder/views/order_control_section.dart` | Section recensée | CustomerOrderControlSection | radiusSm |
| `myOrder/views/order_delivery_section.dart` | Section recensée | CustomerOrderDeliverySection | hérité/forme spécifique, non détaillé |
| `myOrder/views/order_deposit_section.dart` | Section recensée | CustomerOrderDepositSection | hérité/forme spécifique, non détaillé |
| `myVoice/views/my_voice_view.dart` | Recensé | MyVoiceView | radiusPill, radiusSm |
| `notification/views/notification_digest_view.dart` | Recensé | NotificationDigestView | hérité/forme spécifique, non détaillé |
| `notification/views/notification_view.dart` | Ciblé | NotificationView | hérité/forme spécifique, non détaillé |
| `onboarding/views/onboarding_view.dart` | Recensé | OnboardingView | radiusPill, radiusXl |
| `orderManagement/views/order_management_view.dart` | Ciblé | OrderManagementView | helper:medium |
| `otp/views/otp_view.dart` | Ciblé | OtpView | helper:medium, helper:small |
| `packageSubscription/views/invoice_webview.dart` | Recensé | InvoiceWebView | 12 |
| `packageSubscription/views/package_subscription_view.dart` | Recensé | PackageSubscriptionView | radiusLg, radiusMd, radiusPill, radiusSm |
| `post/views/post_view.dart` | Recensé | PostView | hérité/forme spécifique, non détaillé |
| `postDetail/views/post_detail_view.dart` | Recensé | PostDetailView | 10, 12, 8 |
| `preferences/views/preferences_view.dart` | Recensé | PreferencesView | radiusMd, radiusPill, radiusSm |
| `product/views/map_selection_view.dart` | Recensé | MapSelectionView | 10, 12, 2, 20, 5, 6 |
| `product/views/product_view.dart` | Ciblé | ProductPage, ProductView | 10, 12, 14, 16, 2, 20, 4, 6, 8, 9, radiusSm |
| `productManagement/views/product_management_view.dart` | Recensé | ProductManagementView | 12, 18, 24, 6, radius |
| `profile/views/profile_view.dart` | Ciblé | ProfileView | helper:medium, helper:small |
| `salesProgram/views/sales_program_success_view.dart` | Recensé | SalesProgramSuccessView | hérité/forme spécifique, non détaillé |
| `salesProgram/views/sales_program_view.dart` | Recensé | SalesProgramView | radiusMd |
| `search/views/search_view.dart` | Ciblé | SearchView, SearchTabView | 12, 20, 24, radiusPill |
| `search/views/search_view_old_backup.dart` | Backup, aucun import trouvé | SearchView | 10, 2, 3, helper:large, helper:medium |
| `settings/views/settings_view.dart` | Ciblé | SettingsView | helper:medium, helper:small |
| `shipConfig/views/ship_config_view.dart` | Recensé | ShipConfigView | helper:medium, helper:small |
| `shipment/views/shipment_view.dart` | Recensé | ShipmentView | 12, helper:medium, helper:small |
| `shopStatistics/views/shop_statistics_view.dart` | Recensé | ShopStatisticsView | radiusPill, radiusSm, radiusXs, helper:medium |
| `splash/views/splash_view.dart` | Recensé | SplashView | hérité/forme spécifique, non détaillé |
| `storeManagement/views/edit_store_view.dart` | Ciblé | EditStoreView | 2, radiusSm, helper:medium, helper:small |
| `storeManagement/views/store_management_view.dart` | Ciblé | StoreManagementView | radiusLg, radiusMd, radiusPill, radiusSm |
| `stripeConnect/views/stripe_connect_view.dart` | Recensé | StripeConnectView | 10, 12, 4, 8 |
| `tracking/views/tracking_view.dart` | Ciblé | TrackingView | 12, 16, 20, 25 |
| `vendorConfig/views/map_location_picker_view.dart` | Recensé | MapLocationPickerView | 12, 16, 4, 8, helper:medium |
| `vendorConfig/views/vendor_config_view.dart` | Recensé | VendorConfigView | 8, helper:large, helper:medium |
| `vendorDashboard/views/vendor_dashboard_shimmer.dart` | Squelette recensé | VendorDashboardShimmer | radiusLg, radius |
| `vendorDashboard/views/vendor_dashboard_view.dart` | Ciblé | VendorDashboardView | radiusLg, radiusMd, radiusPill, radiusSm, borderRadius |
| `vendorDetails/views/vendor_details_view.dart` | Recensé | VendorDetailsPage, VendorDetailsView | radiusMd, radiusPill |
| `wallet/views/payment_webview.dart` | Recensé | PaymentWebView | hérité/forme spécifique, non détaillé |
| `wallet/views/wallet_history_view.dart` | Ciblé | WalletHistoryView | 10, 12, 16, 6, 8 |
| `wallet/views/wallet_view.dart` | Ciblé | WalletView | 10, 12, 14, 16, 6, 8, radiusLg, radiusMd, radiusPill, radiusSm |
| `welcomer/views/welcomer_view.dart` | Ciblé | WelcomerView | hérité/forme spécifique, non détaillé |

## Annexe C — Composants, formulaires et états recensés

Les 67 fichiers de widgets ci-dessous sont inventoriés. Seuls les 20 composants explicitement nommés en tête du rapport font partie du décompte d’analyse ciblée ; les autres exigent une revue détaillée selon leur lot. Les composants analysés peuvent partager un fichier ; leur nombre est distinct du nombre de fichiers.

| Fichier sous lib/app/ | Classes / rôle repérés |
|---|---|
| `core/widgets/app_network_image.dart` | AppNetworkImage |
| `core/widgets/app_sheet.dart` | AppSheet |
| `core/widgets/app_ui.dart` | AppCard, AppContentWidth, AppButton, AppBadge, AppSelectionDot, AppSectionHeader, AppEmptyState, AppTextField, AppDivider, AppIconButton, AppBackButton, AppKeyboardDismisser |
| `core/widgets/app_update_gate.dart` | AppUpdateGate |
| `core/widgets/asso_ads_banner.dart` | AssoAdsBanner |
| `core/widgets/auth_scaffold.dart` | AuthScaffold, AuthDivider, AuthSwitchLink |
| `core/widgets/autoplay_video.dart` | AutoplayVideo |
| `core/widgets/currency_switcher.dart` | CurrencySwitcher |
| `core/widgets/delivery_details_widgets.dart` | DeliveryInfoLine, DeliveryChip, DeliveryBreakdownView, ExportDeliveryCostLines, DeliveryServiceLines, DeliveryNotice, CarrierTrackingCard, DeliveryTimelineView, OrderDeliveryDetails |
| `core/widgets/deposit_widgets.dart` | DepositInfoCard, DepositOrderTimeline, DepositBalanceCard, DepositVendorNotice |
| `core/widgets/english_version_section.dart` | EnglishVersionSection |
| `core/widgets/free_delivery_widgets.dart` | FreeDeliveryBadge, FreeDeliveryNotice, DeliveryPriceText, FreeDeliveryToggle |
| `core/widgets/image_source_sheet.dart` | fonctions de composition / classes internes |
| `core/widgets/iso_country_field.dart` | IsoCountryField |
| `core/widgets/map_search_results.dart` | MapSearchResults, AddressSuggestionList |
| `core/widgets/markdown_bottom_sheet.dart` | fonctions de composition / classes internes |
| `core/widgets/masonry_grid.dart` | SliverMasonryGrid |
| `core/widgets/masonry_product_tile.dart` | MasonryProductTile, MasonryTileImage, MasonryTileSkeleton |
| `core/widgets/offline_badge.dart` | OfflineBadge |
| `core/widgets/order_progress_timeline.dart` | OrderProgressTimeline |
| `core/widgets/passcolis_card.dart` | PasscolisCard, PasscolisCardShimmer |
| `core/widgets/product_card.dart` | ProductCard, AssoAdsChip, CertifiedMark |
| `core/widgets/product_image_viewer.dart` | ProductImageViewer, ProductThumbnailStrip |
| `core/widgets/product_variant_selector.dart` | ProductVariantSelector, VariantOptionsPreview |
| `core/widgets/product_video_player.dart` | ProductGalleryVideo, ProductVideoFullscreen, VideoDurationPill |
| `core/widgets/quantity_stepper.dart` | QuantityStepper |
| `core/widgets/scoped_controller_page.dart` | fonctions de composition / classes internes |
| `core/widgets/segmented_tabs.dart` | SegmentedTabs |
| `core/widgets/shimmer_widgets.dart` | fonctions de composition / classes internes |
| `core/widgets/unknown_route_view.dart` | UnknownRouteView |
| `core/widgets/user_avatar.dart` | UserAvatar |
| `core/widgets/variant_combo_picker.dart` | VariantComboPicker |
| `core/widgets/variant_quantity_list.dart` | VariantQuantityList |
| `core/widgets/verified_badge.dart` | VerifiedBadge, VerifiedBadgeWithLabel |
| `modules/boost/widgets/boost_campaign_card.dart` | BoostCampaignCard |
| `modules/boost/widgets/boost_package_card.dart` | BoostPackageCard |
| `modules/boost/widgets/boost_product_picker.dart` | BoostProductPicker |
| `modules/diaspoBooking/widgets/parcel_insurance_form.dart` | ParcelInsuranceCard |
| `modules/disputes/widgets/dispute_form_sheet.dart` | DisputeFormSheet |
| `modules/disputes/widgets/dispute_shipment_payment.dart` | fonctions de composition / classes internes |
| `modules/immo/widgets/immo_dispute_sheet.dart` | fonctions de composition / classes internes |
| `modules/immo/widgets/immo_fee_details.dart` | ImmoFeeDetails |
| `modules/immo/widgets/immo_quote_sheet.dart` | fonctions de composition / classes internes |
| `modules/immo/widgets/immo_sheets.dart` | ImmoRangeField, ImmoSwitchTile, ImmoMonthsStepper |
| `modules/immo/widgets/immo_summary_row.dart` | ImmoSummaryRow |
| `modules/immo/widgets/immo_widgets.dart` | ImmoPhotoCarousel, ImmoFavoriteButton, ImmoPhotoTag, ImmoAvailability, ImmoPriceText, ImmoHouseCard, ImmoLandCard, ImmoCabinetLogo, ImmoFilterChip, ImmoCardSkeleton |
| `modules/import/widgets/wholesale_delivery.dart` | WholesaleDeliverySection |
| `modules/orderManagement/widgets/filters_section.dart` | FiltersSection |
| `modules/orderManagement/widgets/order_card.dart` | OrderCard |
| `modules/packageSubscription/widgets/package_details_sheet.dart` | PackageDetailsSheet |
| `modules/packageSubscription/widgets/payment_loading_dialog.dart` | PaymentLoadingDialog |
| `modules/packageSubscription/widgets/payment_success_dialog.dart` | PaymentSuccessDialog |
| `modules/packageSubscription/widgets/sales_code_field.dart` | SalesCodeField |
| `modules/payment/widgets/mobile_money_waiting.dart` | fonctions de composition / classes internes |
| `modules/payment/widgets/payment_method_selector.dart` | PaymentMethodSelector |
| `modules/payment/widgets/wallet_payment_confirm_dialog.dart` | WalletPaymentConfirmDialog |
| `modules/profile/widgets/logout_loading_dialog.dart` | LogoutLoadingDialog |
| `modules/salesProgram/widgets/sales_agent_code_panel.dart` | SalesAgentCodePanel |
| `modules/wallet/widgets/confirm_code_parts.dart` | ConfirmCodeHeaderIcon, ConfirmCodeNotice, ConfirmCodeField, ConfirmCodeActions, ConfirmCodeSuccessDialog |
| `modules/wallet/widgets/kpay_payment_sheet.dart` | KpayDirectPaymentSheet |
| `modules/wallet/widgets/kpay_phone_selector.dart` | KpayPhoneSelector |
| `modules/wallet/widgets/payment_method_card.dart` | PaymentMethodCard |
| `modules/wallet/widgets/payout_account_sheet.dart` | PayoutAccountSheet |
| `modules/wallet/widgets/quick_confirm_code_dialog.dart` | QuickConfirmCodeDialog |
| `modules/wallet/widgets/recharge_bottom_sheet.dart` | RechargeBottomSheet |
| `modules/wallet/widgets/seller_confirm_code_dialog.dart` | SellerConfirmCodeDialog |
| `modules/wallet/widgets/withdrawal_bottom_sheet.dart` | WithdrawalBottomSheet |

Interfaces supplémentaires hors fichiers de widgets : dialogues/feuilles dans contrôleurs (notamment order_management_controller), gestion des variantes dans variant_editor_page, progression des étapes Diaspo, filtres de recherche, médias produit, formulaires de comptes Stripe et éditeur bailleur. Les fichiers `immo_sheets.dart` et `immo_quote_sheet.dart` couvrent des formulaires/choix métier dédiés ; leur recensement ne remplace pas la validation des erreurs, documents et montants.

Entrée de production auditée : `lib/main.dart`. `lib/zz_immo_preview.dart` est une entrée de prévisualisation distincte, exclue du nombre des écrans utilisateur de production ; son rendu n’a pas été utilisé pour valider le produit.

## Annexe D — Traçabilité des mesures et contrôle du livrable

Les ratios du registre sont obtenus à partir des canaux sRGB normalisés : conversion linéaire par canal (c/12,92 si c≤0,04045, sinon ((c+0,055)/1,055)^2,4), luminance0,2126R+0,7152G+0,0722B, puis (Lclair+0,05)/(Lsombre+0,05). Valeurs arrondies pour lecture ; comparer les valeurs non arrondies aux seuils dans les futurs tests. Ces calculs ne couvrent pas photos, gradients, transparences ni états de focus.

Le recensement et les recherches utilisent les sources présentes dans l’arbre de travail, sans modification du code applicatif. Aucun test, formatage, analyseur Flutter, build ou migration n’a été lancé ; aucun résultat de test passant n’est revendiqué. L’absence de captures est une limite de preuve assumée, et non une confirmation de l’absence d’overflow.
