# Parcours et attentes de paiement

Les parcours passent par `PaymentPreparation.run` pendant le paiement Wallet ou la création du paiement externe. KPay enchaîne ensuite sur `MobileMoneyWaiting.run`, la même fenêtre que le paiement d'un produit. Stripe affiche sa modale dédiée pendant la création du paiement et l'initialisation native ; elle est retirée avant la présentation de la feuille de carte.

| Parcours | Point d'entrée de la préparation | Confirmation KPay |
| --- | --- | --- |
| Produit, acompte initial compris | `product_controller.dart` : `createOrder` | `product_view.dart` |
| Commande en gros | `wholesale_product_view.dart` : `_create`, `_createCard` | même fichier |
| Solde d'une commande avec acompte (commandes et suivi) | `deposit_balance_payment.dart` : `pay` | même fichier |
| Réservation immobilière | `immo_payment.dart` : `pay` | même fichier |
| Transport retour/remplacement après litige | `dispute_shipment_payment.dart` : `pay` | même fichier |
| Réservation Diaspo | `diaspo_booking_controller.dart` : `_processKpayBooking`, `_processCardBooking` | même fichier |
| Envoi international | `maritime_booking_controller.dart` : `_create` | même fichier |
| Forfait vendeur | `package_subscription_controller.dart` : `_subscribeViaKpay`, `_subscribeViaCard` | même fichier |
| Boost | `boost_controller.dart` : `_buyWithKpay`, `_buyWithCard` | même fichier |
| Certification | `certification_packages_controller.dart` : `createOrder`, `createCardOrder` | `certification_packages_view.dart` |
| Recharge Wallet | `recharge_bottom_sheet.dart` : `_handleRecharge` | même fichier |

`StripeNativeService.payWithCard` centralise l'attente de préparation du SDK (réglages et initialisation, délai maximal 25 secondes) et les couleurs de la feuille native. Le bouton primaire Stripe et les sélections Mobile Money utilisent l'orange de marque et des textes blancs.

La préparation interdit la fermeture par retour ou toucher du fond. Sa route est retirée dans `finally`, y compris en cas d'erreur immédiate ; aucune autre page n'est fermée. Les appels avec `method: 'wallet'`, dont la réservation immobilière, affichent une attente Wallet dédiée après confirmation. Les redirections PayPal conservent leur parcours.

La fenêtre USSD conserve l'option « Continuer en arrière-plan ». Un paiement n'est annoncé payé qu'après confirmation du serveur. Les parcours gardent leurs traitements métier de succès, refus, annulation et suivi différé.
