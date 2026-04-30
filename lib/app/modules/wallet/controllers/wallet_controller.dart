import 'dart:async';
import 'package:get/get.dart';

import '../../../data/models/wallet_model.dart';
import '../../../data/services/wallet_service.dart';
import '../../../data/services/fcm_service.dart';
import '../../../data/providers/storage_service.dart';
import '../../../data/providers/diaspo_service.dart';
import '../../../data/providers/currency_service.dart';

class WalletController extends GetxController {
  final WalletService _walletService = Get.find<WalletService>();

  // State management
  bool _isDisposed = false;
  bool get isSafe => !_isDisposed && isClosed == false;

  // FCM Service (optionnel - si disponible)
  FcmService? _fcmService;
  StreamSubscription? _fcmSubscription;

  // États réactifs
  final isLoading = true.obs;
  final isLoadingTransactions = false.obs;
  final isProcessingPayment = false.obs;

  // Données du wallet
  final wallet = Rxn<WalletModel>();
  final transactions = <WalletTransactionModel>[].obs;
  final lockedBookings = <Map<String, dynamic>>[].obs; // Bookings avec fonds bloqués

  // Soldes de retrait séparés par provider
  final freemopayBalance = 0.0.obs;
  final paypalBalance = 0.0.obs;
  final totalWithdrawableBalance = 0.0.obs;

  // Pagination des transactions
  final currentPage = 1.obs;
  final lastPage = 1.obs;
  final totalTransactions = 0.obs;
  final perPage = 20.obs;

  // Filtres
  final selectedType = Rxn<String>(); // credit, debit, refund, bonus, adjustment

  // Messages
  final errorMessage = ''.obs;
  final successMessage = ''.obs;

  // Getter pour le numéro de téléphone de l'utilisateur
  String? get userPhone {
    try {
      final user = StorageService.getUser();
      return user?.phone;
    } catch (e) {
      return null;
    }
  }

  // Getter pour compter les transactions en attente (pending)
  int get pendingTransactionsCount {
    return transactions.where((tx) => tx.status == 'pending').length;
  }

  @override
  void onInit() {
    super.onInit();

    // Charger les données uniquement si l'utilisateur est connecté
    if (StorageService.isAuthenticated) {
      loadWallet();
      loadTransactions(); // Charger l'historique dès l'ouverture
      loadWithdrawalBalances(); // Charger les soldes de retrait
      loadLockedBookings(); // Charger les réservations avec fonds bloqués

      // NOTE: Deposit polling is no longer needed!
      // The backend now processes deposits asynchronously using:
      // - Background jobs that check FreeMoPay API every 30 seconds
      // - FCM notifications sent to user when payment completes
      // Users no longer wait on a screen - they receive a notification instead

      // Setup FCM listener pour auto-refresh quand notification reçue
      _setupFcmListener();
    } else {
      // Mode invité - arrêter le chargement
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    print('');
    print('========================================');
    print('💰 WALLET CONTROLLER: Closing');
    print('========================================');

    _isDisposed = true;

    // Annuler la subscription FCM
    try {
      _fcmSubscription?.cancel();
      print('  └─ FCM subscription cancelled');
    } catch (e) {
      print('  └─ Error cancelling FCM subscription: $e');
    }

    super.onClose();

    print('  └─ Controller disposed safely');
    print('========================================');
  }

  /// Configure l'écoute des notifications FCM pour le wallet
  void _setupFcmListener() {
    try {
      _fcmService = Get.find<FcmService>();

      // Écouter les notifications de wallet
      _fcmSubscription = _fcmService?.walletNotificationStream.listen((data) {
        print('[WalletController] FCM wallet notification received: $data');

        final type = data['type'] as String?;

        if (type == 'wallet_credit') {
          // Dépôt réussi
          print('[WalletController] Deposit completed - refreshing wallet');
          refresh();

          Get.snackbar(
            '💰 Dépôt réussi',
            'Votre dépôt de ${data['amount']} FCFA a été confirmé.',
            backgroundColor: Get.theme.colorScheme.primary,
            colorText: Get.theme.colorScheme.onPrimary,
            duration: const Duration(seconds: 4),
          );
        } else if (type == 'wallet_credit_failed') {
          // Dépôt échoué
          print('[WalletController] Deposit failed - refreshing wallet');
          refresh();

          Get.snackbar(
            '❌ Dépôt échoué',
            data['reason'] as String? ?? 'Le dépôt a échoué',
            backgroundColor: Get.theme.colorScheme.error,
            colorText: Get.theme.colorScheme.onError,
            duration: const Duration(seconds: 5),
          );
        } else if (type == 'wallet_withdrawal_completed') {
          // Retrait réussi
          print('[WalletController] Withdrawal completed - refreshing wallet');
          refresh();

          Get.snackbar(
            '💸 Retrait effectué',
            'Votre retrait de ${data['amount']} FCFA a été envoyé.',
            backgroundColor: Get.theme.colorScheme.primary,
            colorText: Get.theme.colorScheme.onPrimary,
            duration: const Duration(seconds: 4),
          );
        } else if (type == 'wallet_withdrawal_failed') {
          // Retrait échoué (avec remboursement automatique)
          print('[WalletController] Withdrawal failed - refreshing wallet');
          refresh();

          Get.snackbar(
            '⚠️ Retrait échoué',
            'Votre retrait a échoué. Le montant a été remboursé dans votre wallet.',
            backgroundColor: Get.theme.colorScheme.error,
            colorText: Get.theme.colorScheme.onError,
            duration: const Duration(seconds: 5),
          );
        } else if (type == 'wallet_unlocked') {
          // Fonds débloqués après confirmation de livraison diaspo
          print('[WalletController] Funds unlocked - refreshing wallet');
          refresh();

          Get.snackbar(
            '💰 Fonds débloqués!',
            'Vous avez reçu ${data['amount']} FCFA. Les fonds sont maintenant disponibles dans votre wallet.',
            backgroundColor: Get.theme.colorScheme.primary,
            colorText: Get.theme.colorScheme.onPrimary,
            duration: const Duration(seconds: 4),
          );
        }
      });

      print('[WalletController] FCM listener setup complete');
    } catch (e) {
      print('[WalletController] FCM service not available: $e');
      // FCM is optional - app still works without it
    }
  }

  /// Charge les données du wallet (solde et stats)
  Future<void> loadWallet() async {
    if (_isDisposed) return;

    isLoading.value = true;
    errorMessage.value = '';

    try {
      final result = await _walletService.getWalletStats();

      if (_isDisposed) return;

      if (result != null) {
        wallet.value = result;
        print('[WalletController] 💰 Wallet loaded:');
        print('  - Current Balance: ${result.currentBalance}');
        print('  - Total Locked: ${result.totalLockedBalance}');
        print('  - Locked Freemopay: ${result.lockedFreemopayBalance}');
        print('  - Locked Paypal: ${result.lockedPaypalBalance}');
        print('  - Has Locked Funds: ${result.hasLockedFunds}');
      } else {
        errorMessage.value = 'Impossible de charger le wallet';
      }
    } catch (e) {
      print('[WalletController] Error loading wallet: $e');
      errorMessage.value = 'Erreur lors du chargement du wallet';
    } finally {
      isLoading.value = false;
    }
  }

  /// Charge l'historique des transactions
  Future<void> loadTransactions({bool loadMore = false}) async {
    if (loadMore) {
      if (currentPage.value >= lastPage.value) return;
      currentPage.value++;
    } else {
      currentPage.value = 1;
      isLoadingTransactions.value = true;
    }

    try {
      final result = await _walletService.getTransactionHistory(
        page: currentPage.value,
        perPage: perPage.value,
        type: selectedType.value,
      );

      final List<WalletTransactionModel> newTransactions =
          result['transactions'] as List<WalletTransactionModel>;

      if (loadMore) {
        transactions.addAll(newTransactions);
      } else {
        transactions.value = newTransactions;
      }

      lastPage.value = result['last_page'] as int;
      totalTransactions.value = result['total'] as int;
    } catch (e) {
      print('[WalletController] Error loading transactions: $e');
      errorMessage.value = 'Erreur lors du chargement des transactions';
    } finally {
      isLoadingTransactions.value = false;
    }
  }

  /// Filtre les transactions par type
  void filterByType(String? type) {
    selectedType.value = type;
    loadTransactions();
  }

  /// Rafraîchit les données (pull to refresh)
  Future<void> refresh() async {
    await Future.wait([
      loadWallet(),
      loadTransactions(),
      loadWithdrawalBalances(),
      loadLockedBookings(),
    ]);
  }

  /// Charge les réservations avec fonds bloqués (pour le seller)
  Future<void> loadLockedBookings() async {
    if (_isDisposed) return;

    try {
      // Import DiaspoService
      final diaspoService = Get.find<DiaspoService>();

      // Récupérer les bookings en tant que seller avec status 'paid'
      final result = await diaspoService.getBookings(
        role: 'seller',
        status: 'paid', // paid = payé, en attente de confirmation de livraison par le seller
        perPage: 100, // Récupérer tous les bookings payés en attente
      );

      if (_isDisposed) return;

      if (result['success'] == true && result['data'] != null) {
        // L'API retourne un objet avec pagination {current_page, data: [...], ...}
        final responseData = result['data'];

        List<dynamic> bookingsData;
        if (responseData is List) {
          // Si c'est déjà une liste
          bookingsData = responseData;
        } else if (responseData is Map && responseData['data'] != null) {
          // Si c'est un objet avec pagination
          bookingsData = responseData['data'] as List<dynamic>;
        } else {
          bookingsData = [];
        }

        // Filtrer pour ne garder que ceux avec des fonds bloqués (status = 'paid')
        lockedBookings.value = bookingsData
            .where((booking) => booking['status'] == 'paid')
            .map((booking) {
                  // Parser correctement les valeurs numériques qui peuvent être String ou num
                  final subtotalRaw = booking['subtotal'];
                  final subtotal = subtotalRaw is String
                      ? double.tryParse(subtotalRaw) ?? 0.0
                      : (subtotalRaw is num ? subtotalRaw.toDouble() : 0.0);

                  final kgBookedRaw = booking['kg_booked'];
                  final kgBooked = kgBookedRaw is String
                      ? double.tryParse(kgBookedRaw) ?? 0.0
                      : (kgBookedRaw is num ? kgBookedRaw.toDouble() : 0.0);

                  return {
                    'id': booking['id'],
                    'confirmation_code': booking['confirmation_code'],
                    'subtotal': subtotal,
                    'kg_booked': kgBooked,
                    'buyer_name': booking['buyer']?['name'] ?? 'Client',
                    'created_at': booking['created_at'],
                  };
                })
            .toList();

        print('[WalletController] 🔒 Locked bookings loaded: ${lockedBookings.length} bookings');
        for (var booking in lockedBookings) {
          print('  - Booking #${booking['id']}: ${booking['subtotal']} FCFA (${booking['kg_booked']} kg)');
        }
      } else {
        lockedBookings.value = [];
      }
    } catch (e) {
      print('[WalletController] Error loading locked bookings: $e');
      lockedBookings.value = [];
    }
  }

  /// Initie une recharge du wallet
  /// Retourne l'URL de paiement si succès
  /// phoneNumber: requis pour freemopay
  Future<Map<String, dynamic>> initiateRecharge({
    required double amount,
    required String paymentMethod, // 'freemopay' ou 'paypal'
    String? phoneNumber, // Requis pour freemopay
  }) async {
    if (_isDisposed) return {'success': false, 'message': 'Controller disposed'};

    isProcessingPayment.value = true;
    errorMessage.value = '';
    successMessage.value = '';

    try {
      final result = await _walletService.rechargeWallet(
        amount: amount,
        paymentMethod: paymentMethod,
        phoneNumber: phoneNumber,
      );

      if (_isDisposed) return {'success': false, 'message': 'Controller disposed'};

      if (result['success'] == true) {
        successMessage.value = result['message'] ?? 'Recharge initiée avec succès';

        // Si c'est FreeMoPay et que le wallet est déjà crédité, rafraîchir
        if (paymentMethod == 'freemopay' && result['status'] == 'completed') {
          await Future.wait([
            loadWallet(),
            loadWithdrawalBalances(),
          ]);
        }

        return result;
      } else {
        errorMessage.value = result['message'] ?? 'Échec de l\'initiation de la recharge';
        return {'success': false, 'message': errorMessage.value};
      }
    } catch (e) {
      print('[WalletController] Error initiating recharge: $e');
      errorMessage.value = 'Erreur lors de l\'initiation de la recharge';
      return {'success': false, 'message': errorMessage.value};
    } finally {
      isProcessingPayment.value = false;
    }
  }

  /// Vérifie le statut d'un paiement avec polling
  /// maxAttempts: nombre max de tentatives (défaut 120 = 6 minutes avec interval 3s)
  /// pollInterval: intervalle entre les tentatives en secondes (défaut 3s)
  Future<Map<String, dynamic>> pollPaymentStatus({
    required int paymentId,
    int maxAttempts = 120,
    int pollInterval = 3,
    Function(String status)? onStatusUpdate,
  }) async {
    int attempts = 0;

    while (attempts < maxAttempts) {
      try {
        // Attendre l'intervalle avant de vérifier (sauf pour la première tentative)
        if (attempts > 0) {
          await Future.delayed(Duration(seconds: pollInterval));
        }

        final result = await _walletService.checkPaymentStatus(paymentId);

        if (result['success'] == true) {
          final status = result['status'] as String?;

          // Notifier du changement de statut
          if (onStatusUpdate != null && status != null) {
            onStatusUpdate(status);
          }

          // Si le paiement est complété
          if (status == 'completed') {
            // Rafraîchir le solde et les soldes de retrait
            await Future.wait([
              loadWallet(),
              loadWithdrawalBalances(),
            ]);
            return {
              'success': true,
              'status': 'completed',
              'message': 'Paiement réussi',
              ...result,
            };
          }

          // Si le paiement a échoué
          if (status == 'failed') {
            return {
              'success': false,
              'status': 'failed',
              'message': result['failure_reason'] ?? 'Le paiement a échoué',
              ...result,
            };
          }

          // Si le paiement a été annulé
          if (status == 'cancelled') {
            return {
              'success': false,
              'status': 'cancelled',
              'message': 'Le paiement a été annulé',
              ...result,
            };
          }

          // Sinon le paiement est encore pending, continuer le polling
          attempts++;
        } else {
          // Erreur lors de la vérification, continuer le polling
          attempts++;
        }
      } catch (e) {
        print('[WalletController] Error polling payment status: $e');
        attempts++;

        // Si trop d'erreurs consécutives, abandonner
        if (attempts >= 15) {
          return {
            'success': false,
            'status': 'error',
            'message': 'Impossible de vérifier le statut du paiement',
          };
        }
      }
    }

    // Timeout atteint
    return {
      'success': false,
      'status': 'timeout',
      'message': 'Le délai de vérification a expiré. Vérifiez votre wallet plus tard.',
    };
  }

  /// Vérifie le statut d'un paiement (appel unique)
  /// Utilisé par la page d'attente USSD pour vérifier périodiquement
  Future<Map<String, dynamic>> checkPaymentStatus(int paymentId) async {
    try {
      return await _walletService.checkPaymentStatus(paymentId);
    } catch (e) {
      print('[WalletController] Error checking payment status: $e');
      return {
        'success': false,
        'message': 'Erreur lors de la vérification du statut',
      };
    }
  }

  /// Vérifie si l'utilisateur peut payer un montant
  Future<Map<String, dynamic>> checkCanPay(double amount) async {
    try {
      final result = await _walletService.canPayWithWallet(amount);
      return result;
    } catch (e) {
      print('[WalletController] Error checking payment ability: $e');
      return {
        'can_pay': false,
        'current_balance': wallet.value?.currentBalance ?? 0.0,
        'required_amount': amount,
        'missing_amount': amount - (wallet.value?.currentBalance ?? 0.0),
        'message': 'Erreur lors de la vérification',
      };
    }
  }

  /// Effectue un paiement avec le wallet
  /// IMPORTANT: Cette méthode nécessite maintenant le paramètre paymentProvider
  Future<bool> payWithWallet({
    required double amount,
    required String description,
    required String referenceType,
    required int referenceId,
    required String paymentProvider, // 'freemopay' ou 'paypal'
  }) async {
    if (_isDisposed) return false;

    isProcessingPayment.value = true;
    errorMessage.value = '';
    successMessage.value = '';

    try {
      final result = await _walletService.payWithWallet(
        amount: amount,
        description: description,
        referenceType: referenceType,
        referenceId: referenceId,
        paymentProvider: paymentProvider,
      );

      if (_isDisposed) return false;

      if (result['success'] == true) {
        successMessage.value = result['message'] ?? 'Paiement effectué avec succès';

        // Rafraîchir le wallet et les soldes de retrait après paiement
        await Future.wait([
          loadWallet(),
          loadWithdrawalBalances(),
        ]);

        return true;
      } else {
        errorMessage.value = result['message'] ?? 'Échec du paiement';
        return false;
      }
    } catch (e) {
      print('[WalletController] Error paying with wallet: $e');
      errorMessage.value = 'Erreur lors du paiement';
      return false;
    } finally {
      isProcessingPayment.value = false;
    }
  }

  /// Initie un paiement PayPal natif
  Future<Map<String, dynamic>> initiateNativePayPalPayment({
    required double amount,
  }) async {
    isProcessingPayment.value = true;
    errorMessage.value = '';
    successMessage.value = '';

    try {
      final result = await _walletService.createNativePayPalOrder(amount: amount);

      if (result['success'] == true) {
        successMessage.value = 'Ordre PayPal créé avec succès';
        return result;
      } else {
        errorMessage.value = result['message'] ?? 'Échec de la création de l\'ordre PayPal';
        return {'success': false, 'message': errorMessage.value};
      }
    } catch (e) {
      print('[WalletController] Error initiating native PayPal payment: $e');
      errorMessage.value = 'Erreur lors de la création de l\'ordre PayPal';
      return {'success': false, 'message': errorMessage.value};
    } finally {
      isProcessingPayment.value = false;
    }
  }

  /// Capture un paiement PayPal natif après approbation
  Future<Map<String, dynamic>> captureNativePayPalPayment({
    required int paymentId,
    required String orderId,
  }) async {
    if (_isDisposed) return {'success': false, 'message': 'Controller disposed'};

    isProcessingPayment.value = true;
    errorMessage.value = '';
    successMessage.value = '';

    try {
      final result = await _walletService.captureNativePayPalOrder(
        paymentId: paymentId,
        orderId: orderId,
      );

      if (_isDisposed) return {'success': false, 'message': 'Controller disposed'};

      if (result['success'] == true) {
        successMessage.value = result['message'] ?? 'Paiement effectué avec succès';

        // Rafraîchir le wallet et les soldes de retrait après paiement
        await Future.wait([
          loadWallet(),
          loadWithdrawalBalances(),
        ]);

        return result;
      } else {
        errorMessage.value = result['message'] ?? 'Échec de la capture du paiement';
        return {'success': false, 'message': errorMessage.value};
      }
    } catch (e) {
      print('[WalletController] Error capturing native PayPal payment: $e');
      errorMessage.value = 'Erreur lors de la capture du paiement';
      return {'success': false, 'message': errorMessage.value};
    } finally {
      isProcessingPayment.value = false;
    }
  }

  /// Getter pour le solde actuel
  double get currentBalance => wallet.value?.currentBalance ?? 0.0;

  /// Getter pour le solde formaté
  String get formattedBalance => wallet.value?.formattedBalance ?? '0 FCFA';

  /// Vérifie si le wallet a un solde suffisant
  bool hasSufficientBalance(double amount) {
    return currentBalance >= amount;
  }

  /// Efface les messages d'erreur et de succès
  void clearMessages() {
    errorMessage.value = '';
    successMessage.value = '';
  }

  // ============================================
  // MÉTHODES DE RETRAIT
  // ============================================

  /// Charge les soldes disponibles pour retrait
  Future<void> loadWithdrawalBalances() async {
    try {
      final result = await _walletService.getWithdrawalBalances();

      if (result['success'] == true) {
        // Parse safely - handle both string and numeric responses
        freemopayBalance.value = _parseBalance(result['freemopay_balance']);
        paypalBalance.value = _parseBalance(result['paypal_balance']);
        totalWithdrawableBalance.value = _parseBalance(result['total_balance']);
      }
    } catch (e) {
      print('[WalletController] Error loading withdrawal balances: $e');
    }
  }

  /// Parse balance value safely (handles both string and numeric types)
  double _parseBalance(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Récupère les soldes disponibles pour retrait
  Future<Map<String, dynamic>> getWithdrawalBalances() async {
    try {
      return await _walletService.getWithdrawalBalances();
    } catch (e) {
      print('[WalletController] Error getting withdrawal balances: $e');
      return {
        'success': false,
        'message': 'Erreur lors de la récupération des soldes',
      };
    }
  }

  /// Initie un retrait FreeMoPay
  Future<Map<String, dynamic>> initiateFreeMoPayWithdrawal({
    required double amount,
    required String paymentMethod, // 'om' ou 'momo'
    required String phoneNumber,
    String? notes,
  }) async {
    isProcessingPayment.value = true;
    errorMessage.value = '';
    successMessage.value = '';

    try {
      final result = await _walletService.initiateFreeMoPayWithdrawal(
        amount: amount,
        paymentMethod: paymentMethod,
        phoneNumber: phoneNumber,
        notes: notes,
      );

      if (result['success'] == true) {
        successMessage.value = result['message'] ?? 'Retrait initié avec succès';

        // ⚠️ CRITIQUE: Mettre à jour le solde IMMÉDIATEMENT avec la valeur retournée
        // Le backend a déjà débité le solde, il faut refléter ça côté frontend
        if (result['data'] != null && result['data']['new_balance'] != null) {
          freemopayBalance.value = _parseBalance(result['data']['new_balance']);
          print('[WalletController] ✅ Balance updated immediately: ${freemopayBalance.value} FCFA');
        }

        // Rafraîchir le solde complet et les soldes de retrait en arrière-plan
        await Future.wait([
          loadWallet(),
          loadWithdrawalBalances(),
        ]);
        return result;
      } else {
        errorMessage.value = result['message'] ?? 'Échec de l\'initiation du retrait';
        return result;
      }
    } catch (e) {
      print('[WalletController] Error initiating FreeMoPay withdrawal: $e');
      errorMessage.value = 'Erreur lors de l\'initiation du retrait';
      return {'success': false, 'message': errorMessage.value};
    } finally {
      isProcessingPayment.value = false;
    }
  }

  /// Initie un retrait PayPal Payout
  Future<Map<String, dynamic>> initiatePayPalWithdrawal({
    required double amount,
    required String paypalEmail,
    String? notes,
  }) async {
    isProcessingPayment.value = true;
    errorMessage.value = '';
    successMessage.value = '';

    try {
      final result = await _walletService.initiatePayPalWithdrawal(
        amount: amount,
        paypalEmail: paypalEmail,
        notes: notes,
      );

      if (result['success'] == true) {
        successMessage.value = result['message'] ?? 'Retrait PayPal initié avec succès';

        // ⚠️ CRITIQUE: Mettre à jour le solde IMMÉDIATEMENT avec la valeur retournée
        // Le backend a déjà débité le solde, il faut refléter ça côté frontend
        if (result['data'] != null && result['data']['new_balance'] != null) {
          paypalBalance.value = _parseBalance(result['data']['new_balance']);
          print('[WalletController] ✅ PayPal balance updated immediately: ${paypalBalance.value} FCFA');
        }

        // Rafraîchir le solde complet et les soldes de retrait en arrière-plan
        await Future.wait([
          loadWallet(),
          loadWithdrawalBalances(),
        ]);
        return result;
      } else {
        errorMessage.value = result['message'] ?? 'Échec de l\'initiation du retrait PayPal';
        return result;
      }
    } catch (e) {
      print('[WalletController] Error initiating PayPal withdrawal: $e');
      errorMessage.value = 'Erreur lors de l\'initiation du retrait PayPal';
      return {'success': false, 'message': errorMessage.value};
    } finally {
      isProcessingPayment.value = false;
    }
  }

  /// Méthode wrapper générique pour initier un retrait
  /// Provider: 'freemopay' ou 'paypal'
  Future<Map<String, dynamic>> initiateWithdrawal({
    required String provider,
    required double amount,
    String? paymentMethod, // Pour FreeMoPay: 'om' ou 'momo'
    String? phoneNumber, // Pour FreeMoPay
    String? paypalEmail, // Pour PayPal
    String? notes,
  }) async {
    if (provider == 'freemopay') {
      if (paymentMethod == null || phoneNumber == null) {
        return {
          'success': false,
          'message': 'Méthode de paiement et numéro de téléphone requis pour FreeMoPay',
        };
      }
      return await initiateFreeMoPayWithdrawal(
        amount: amount,
        paymentMethod: paymentMethod,
        phoneNumber: phoneNumber,
        notes: notes,
      );
    } else if (provider == 'paypal') {
      if (paypalEmail == null) {
        return {
          'success': false,
          'message': 'Email PayPal requis',
        };
      }
      return await initiatePayPalWithdrawal(
        amount: amount,
        paypalEmail: paypalEmail,
        notes: notes,
      );
    } else {
      return {
        'success': false,
        'message': 'Provider invalide: $provider',
      };
    }
  }

  /// Vérifie le statut d'un retrait
  Future<Map<String, dynamic>> checkWithdrawalStatus(int withdrawalId) async {
    try {
      return await _walletService.checkWithdrawalStatus(withdrawalId);
    } catch (e) {
      print('[WalletController] Error checking withdrawal status: $e');
      return {
        'success': false,
        'message': 'Erreur lors de la vérification du statut',
      };
    }
  }

  /// Récupère l'historique des retraits
  Future<Map<String, dynamic>> getWithdrawalHistory({
    int page = 1,
    int perPage = 20,
    String? provider,
    String? status,
  }) async {
    try {
      return await _walletService.getWithdrawalHistory(
        page: page,
        perPage: perPage,
        provider: provider,
        status: status,
      );
    } catch (e) {
      print('[WalletController] Error getting withdrawal history: $e');
      return {
        'withdrawals': [],
        'current_page': 1,
        'last_page': 1,
        'total': 0,
        'per_page': perPage,
      };
    }
  }

  // ================================
  // CURRENCY FORMATTING
  // ================================

  /// Format price with user's currency
  String formatPrice(double priceInXOF, {bool showSymbol = true}) {
    if (!Get.isRegistered<CurrencyService>()) {
      return '${priceInXOF.toStringAsFixed(0)} FCFA';
    }
    return CurrencyService.to.formatPrice(priceInXOF, showSymbol: showSymbol);
  }

  /// Get currency symbol
  String get currencySymbol {
    if (!Get.isRegistered<CurrencyService>()) {
      return 'FCFA';
    }
    return CurrencyService.to.currencySymbol;
  }
}
