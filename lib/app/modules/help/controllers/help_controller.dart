import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/app_theme_system.dart';

class HelpController extends GetxController {
  // État de chargement
  final isLoading = false.obs;

  // Recherche
  final searchController = TextEditingController();
  final searchQuery = ''.obs;

  // Sujets d'aide
  final supportTopics = <SupportTopic>[
    SupportTopic(
      icon: Icons.shopping_cart_outlined,
      title: 'Commandes',
      description: 'Aide sur vos commandes et livraisons',
      items: [
        'Comment passer une commande ?',
        'Suivre ma commande',
        'Annuler une commande',
        'Retourner un produit',
      ],
    ),
    SupportTopic(
      icon: Icons.payment_outlined,
      title: 'Paiements',
      description: 'Informations sur les paiements',
      items: [
        'Méthodes de paiement acceptées',
        'Sécurité des paiements',
        'Problèmes de paiement',
        'Remboursements',
      ],
    ),
    SupportTopic(
      icon: Icons.person_outline,
      title: 'Compte',
      description: 'Gérer votre compte',
      items: [
        'Créer un compte',
        'Modifier mes informations',
        'Mot de passe oublié',
        'Supprimer mon compte',
      ],
    ),
    SupportTopic(
      icon: Icons.local_shipping_outlined,
      title: 'Livraison',
      description: 'Questions sur la livraison',
      items: [
        'Zones de livraison',
        'Frais de livraison',
        'Délais de livraison',
        'Problèmes de livraison',
      ],
    ),
  ];

  // FAQ
  final allFaqs = <FaqItem>[
    // Commandes
    FaqItem(
      category: 'Commandes',
      question: 'Comment passer une commande sur Asso ?',
      answer:
          'Pour passer une commande, parcourez les produits disponibles, ajoutez-les à votre panier en cliquant sur le bouton "Ajouter au panier", puis accédez à votre panier et suivez les étapes de paiement. Vous recevrez une confirmation par email une fois la commande validée.',
    ),
    FaqItem(
      category: 'Commandes',
      question: 'Comment suivre ma commande ?',
      answer:
          'Vous pouvez suivre votre commande en temps réel depuis la section "Mes Commandes" dans votre profil. Vous recevrez également des notifications à chaque étape de livraison (préparation, expédition, en route, livrée).',
    ),
    FaqItem(
      category: 'Commandes',
      question: 'Puis-je annuler ma commande ?',
      answer:
          'Oui, vous pouvez annuler une commande tant qu\'elle n\'a pas été expédiée. Rendez-vous dans "Mes Commandes", sélectionnez la commande concernée et cliquez sur "Annuler". Le remboursement sera effectué dans un délai de 5 à 7 jours ouvrables.',
    ),
    FaqItem(
      category: 'Commandes',
      question: 'Que faire si je reçois un produit endommagé ?',
      answer:
          'Contactez immédiatement notre service client via l\'application avec des photos du produit endommagé. Nous organiserons un retour gratuit et un remplacement ou remboursement selon votre préférence.',
    ),

    // Paiements
    FaqItem(
      category: 'Paiements',
      question: 'Quels modes de paiement sont acceptés ?',
      answer:
          'Nous acceptons Mobile Money (MTN Mobile Money, Orange Money), le paiement à la livraison, et les virements bancaires. Tous les paiements en ligne sont sécurisés et cryptés.',
    ),
    FaqItem(
      category: 'Paiements',
      question: 'Le paiement en ligne est-il sécurisé ?',
      answer:
          'Absolument. Nous utilisons un système de cryptage SSL pour protéger vos informations de paiement. Vos données bancaires ne sont jamais stockées sur nos serveurs et sont transmises directement aux fournisseurs de paiement certifiés.',
    ),
    FaqItem(
      category: 'Paiements',
      question: 'Comment fonctionne le paiement à la livraison ?',
      answer:
          'Sélectionnez "Paiement à la livraison" lors du checkout. Vous paierez en espèces au livreur lors de la réception de votre commande. Cette option peut nécessiter une vérification supplémentaire.',
    ),
    FaqItem(
      category: 'Paiements',
      question: 'Combien de temps prend un remboursement ?',
      answer:
          'Les remboursements sont traités dans un délai de 5 à 7 jours ouvrables après validation de votre demande. Le délai peut varier selon votre mode de paiement initial.',
    ),

    // Compte
    FaqItem(
      category: 'Compte',
      question: 'Comment créer un compte ?',
      answer:
          'Cliquez sur "S\'inscrire" sur l\'écran d\'accueil, renseignez vos informations (nom, email, téléphone) et créez un mot de passe. Vous recevrez un code de vérification par SMS pour activer votre compte.',
    ),
    FaqItem(
      category: 'Compte',
      question: 'J\'ai oublié mon mot de passe, que faire ?',
      answer:
          'Cliquez sur "Mot de passe oublié" sur l\'écran de connexion. Entrez votre email ou numéro de téléphone et suivez les instructions pour réinitialiser votre mot de passe.',
    ),
    FaqItem(
      category: 'Compte',
      question: 'Comment modifier mes informations personnelles ?',
      answer:
          'Accédez à votre profil, cliquez sur "Modifier le profil" et mettez à jour vos informations (nom, email, téléphone, adresse). N\'oubliez pas de sauvegarder vos modifications.',
    ),
    FaqItem(
      category: 'Compte',
      question: 'Puis-je supprimer mon compte ?',
      answer:
          'Oui, vous pouvez supprimer votre compte depuis les paramètres. Attention : cette action est irréversible et toutes vos données seront définitivement supprimées.',
    ),

    // Livraison
    FaqItem(
      category: 'Livraison',
      question: 'Quelles sont les zones de livraison ?',
      answer:
          'Nous livrons dans toutes les grandes villes du Cameroun : Douala, Yaoundé, Bafoussam, Bamenda, Garoua, Maroua, Ngaoundéré, et bien d\'autres. Les délais peuvent varier selon votre localisation.',
    ),
    FaqItem(
      category: 'Livraison',
      question: 'Quels sont les frais de livraison ?',
      answer:
          'Les frais de livraison varient selon votre zone géographique et le poids de votre commande. Ils sont calculés automatiquement lors du checkout. La livraison est gratuite pour les commandes supérieures à 50 000 FCFA dans certaines zones.',
    ),
    FaqItem(
      category: 'Livraison',
      question: 'Quel est le délai de livraison ?',
      answer:
          'Le délai standard est de 24-48h pour Douala et Yaoundé, et de 3-5 jours pour les autres villes. Vous serez informé du délai précis lors de votre commande.',
    ),
    FaqItem(
      category: 'Livraison',
      question: 'Puis-je modifier l\'adresse de livraison ?',
      answer:
          'Oui, vous pouvez modifier l\'adresse de livraison avant l\'expédition de votre commande. Contactez notre service client dès que possible pour effectuer la modification.',
    ),

    // Vendeurs
    FaqItem(
      category: 'Vendeurs',
      question: 'Comment devenir vendeur sur Asso ?',
      answer:
          'Accédez à la section "Devenir Vendeur" dans votre profil. Remplissez le formulaire avec vos informations professionnelles, téléchargez les documents requis, et notre équipe validera votre demande sous 48-72h.',
    ),
    FaqItem(
      category: 'Vendeurs',
      question: 'Quels sont les frais pour vendre sur Asso ?',
      answer:
          'Nous proposons différents forfaits : Gratuit (commission de 15%), Basique (5000 FCFA/mois, 10% commission), Pro (15000 FCFA/mois, 5% commission). Choisissez le forfait adapté à votre volume de ventes.',
    ),
    FaqItem(
      category: 'Vendeurs',
      question: 'Comment ajouter un produit à vendre ?',
      answer:
          'Dans votre tableau de bord vendeur, cliquez sur "Ajouter un produit", remplissez les informations (titre, description, prix, photos, catégorie), et publiez. Vos produits seront visibles après validation.',
    ),
    FaqItem(
      category: 'Vendeurs',
      question: 'Comment gérer mes stocks ?',
      answer:
          'Utilisez la section "Gestion des stocks" dans votre tableau de bord pour suivre vos inventaires en temps réel, recevoir des alertes de stock faible, et mettre à jour les quantités disponibles.',
    ),

    // Général
    FaqItem(
      category: 'Général',
      question: 'Qu\'est-ce que Asso ?',
      answer:
          'Asso est une marketplace camerounaise qui connecte vendeurs et acheteurs. Nous facilitons l\'achat et la vente de produits variés (mode, électronique, maison, alimentation) avec un système de paiement sécurisé et livraison fiable.',
    ),
    FaqItem(
      category: 'Général',
      question: 'Comment contacter le service client ?',
      answer:
          'Vous pouvez nous contacter par email (support@asso-corporation.com), téléphone (658895572 / 651826475), ou WhatsApp. Notre équipe est disponible 24h/24 et 7j/7 pour vous assister.',
    ),
    FaqItem(
      category: 'Général',
      question: 'L\'application est-elle gratuite ?',
      answer:
          'Oui, l\'application Asso est entièrement gratuite à télécharger et à utiliser pour les acheteurs. Les vendeurs peuvent choisir entre un compte gratuit avec commission ou des forfaits payants.',
    ),
    FaqItem(
      category: 'Général',
      question: 'Comment signaler un problème ou un produit frauduleux ?',
      answer:
          'Utilisez le bouton "Signaler" sur la page du produit ou contactez directement notre service client. Nous prenons très au sérieux la sécurité de notre communauté et enquêterons rapidement.',
    ),
  ];

  // FAQ filtrées
  RxList<FaqItem> get filteredFaqs {
    if (searchQuery.value.isEmpty) {
      return allFaqs.obs;
    }

    final query = searchQuery.value.toLowerCase();
    return allFaqs
        .where(
          (faq) =>
              faq.question.toLowerCase().contains(query) ||
              faq.answer.toLowerCase().contains(query) ||
              faq.category.toLowerCase().contains(query),
        )
        .toList()
        .obs;
  }

  // Catégories FAQ
  List<String> get faqCategories {
    return allFaqs.map((faq) => faq.category).toSet().toList();
  }

  @override
  void onInit() {
    super.onInit();
    searchController.addListener(() {
      searchQuery.value = searchController.text;
    });
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  /// Effacer la recherche
  void clearSearch() {
    searchController.clear();
    searchQuery.value = '';
  }

  /// Contacter par email
  Future<void> contactByEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@asso-corporation.com',
      query: 'subject=Demande de support',
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        Get.snackbar(
          'Erreur',
          'Impossible d\'ouvrir le client email',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Une erreur est survenue',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Contacter par téléphone
  Future<void> contactByPhone() async {
    final Uri phoneUri = Uri(scheme: 'tel', path: '+237658895572');

    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        Get.snackbar(
          'Erreur',
          'Impossible d\'ouvrir le dialer',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Une erreur est survenue',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Contacter par WhatsApp
  Future<void> contactByWhatsApp() async {
    final Uri whatsappUri = Uri.parse(
      'https://wa.me/237658895572?text=Bonjour, j\'ai besoin d\'aide concernant',
    );

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else {
        Get.snackbar(
          'Erreur',
          'Impossible d\'ouvrir WhatsApp',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Une erreur est survenue',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Ouvrir un sujet d'aide
  void openTopic(SupportTopic topic) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    topic.icon,
                    color: AppThemeSystem.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topic.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        topic.description,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ...topic.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.help_outline,
                      color: AppThemeSystem.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(item, style: const TextStyle(fontSize: 15)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Get.back();
                  contactByEmail();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeSystem.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Contacter le support'),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }
}

class SupportTopic {
  final IconData icon;
  final String title;
  final String description;
  final List<String> items;

  SupportTopic({
    required this.icon,
    required this.title,
    required this.description,
    required this.items,
  });
}

class FaqItem {
  final String category;
  final String question;
  final String answer;

  FaqItem({
    required this.category,
    required this.question,
    required this.answer,
  });
}
