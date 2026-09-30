import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_ui.dart';
import '../controllers/wallet_controller.dart';
import '../../../core/utils/app_navigation.dart';

/// Page d'attente pendant la validation du paiement USSD
/// Affiche les instructions et attend la réponse du backend en arrière-plan
class UssdWaitingView extends StatefulWidget {
  const UssdWaitingView({super.key});

  @override
  State<UssdWaitingView> createState() => _UssdWaitingViewState();
}

class _UssdWaitingViewState extends State<UssdWaitingView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _timeoutTimer;

  int _remainingSeconds = 330; // Timeout de 330 secondes (5.5 minutes)
  final walletController = Get.find<WalletController>();

  // Arguments passés depuis la page précédente
  late final double amount;
  late final String phoneNumber;
  late final Future<Map<String, dynamic>> Function() rechargeCallback;

  String _statusMessage = 'wallet.ussd.pending_validation'.tr;
  bool _isCompleted = false;
  bool _isError = false;
  String? _errorMessage;

  // Pour gérer le lifecycle
  DateTime? _pausedAt;
  bool _isRequestInProgress = false;

  @override
  void initState() {
    super.initState();

    // Ajouter l'observer pour le lifecycle
    WidgetsBinding.instance.addObserver(this);

    // Récupérer les arguments
    final args = Get.arguments as Map<String, dynamic>?;
    amount = args?['amount'] as double? ?? 0.0;
    phoneNumber = args?['phone_number'] as String? ?? '';
    rechargeCallback = args?['recharge_callback'] as Future<Map<String, dynamic>> Function()?
        ?? () async => {'success': false};

    print('📲 [USSD WAITING] Démarrage de l\'attente');
    print('📲 [USSD WAITING] Montant: $amount FCFA');
    print('📲 [USSD WAITING] Téléphone: $phoneNumber');

    // Animation de pulsation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Démarrer le compteur
    _startCountdown();

    // Lancer la recharge APRÈS le build initial pour éviter "setState() during build"
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initiateRecharge();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    print('🔄 [USSD WAITING] App lifecycle changed: $state');

    switch (state) {
      case AppLifecycleState.paused:
        // App mis en arrière-plan
        print('⏸️  [USSD WAITING] App en pause - Timer sauvegardé');
        _pausedAt = DateTime.now();
        // Ne pas annuler le timer ni la requête - ils continuent en arrière-plan
        break;

      case AppLifecycleState.resumed:
        // App revenu au premier plan
        print('▶️  [USSD WAITING] App repris');
        if (_pausedAt != null && !_isCompleted && !_isError) {
          final elapsed = DateTime.now().difference(_pausedAt!).inSeconds;
          print('⏱️  [USSD WAITING] Temps écoulé en pause: ${elapsed}s');

          // Ajuster le temps restant en fonction du temps écoulé
          if (mounted && _remainingSeconds > 0) {
            setState(() {
              _remainingSeconds = (_remainingSeconds - elapsed).clamp(0, 330);
            });
            print('⏱️  [USSD WAITING] Nouveau temps restant: $_remainingSeconds s');
          }

          _pausedAt = null;
        }
        break;

      case AppLifecycleState.inactive:
        // App en transition (ex: notification)
        print('💤 [USSD WAITING] App inactive');
        break;

      case AppLifecycleState.detached:
        // App en train de se fermer
        print('🔌 [USSD WAITING] App détachée');
        break;

      case AppLifecycleState.hidden:
        print('👁️  [USSD WAITING] App cachée');
        break;
    }
  }

  /// Lance la recharge en arrière-plan
  Future<void> _initiateRecharge() async {
    if (_isRequestInProgress) {
      print('⚠️  [USSD WAITING] Requête déjà en cours, ignorer');
      return;
    }

    _isRequestInProgress = true;

    try {
      print('🚀 [USSD WAITING] Lancement de la recharge...');

      final result = await rechargeCallback();

      if (!mounted) {
        print('⚠️  [USSD WAITING] Widget démonté, ignorer le résultat');
        return;
      }

      if (result['success'] == true) {
        final status = result['status'] as String?;

        if (status == 'completed') {
          _handleSuccess();
        } else if (status == 'failed') {
          _handleFailure(result['failure_reason'] as String? ?? 'wallet.messages.payment_failed'.tr);
        } else {
          // Status pending ou autre
          setState(() {
            _statusMessage = result['message'] ?? 'wallet.ussd.in_progress'.tr;
          });
        }
      } else {
        _handleFailure(result['message'] as String? ?? 'wallet.errors.payment_error'.tr);
      }
    } catch (e) {
      print('❌ [USSD WAITING] Erreur lors de la recharge: $e');
      if (mounted) {
        _handleFailure('wallet.ussd.retry_error'.tr);
      }
    } finally {
      _isRequestInProgress = false;
    }
  }

  /// Démarre le compte à rebours
  void _startCountdown() {
    _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        print('⚠️  [USSD WAITING] Timer annulé - widget démonté');
        timer.cancel();
        return;
      }

      // Ne décrémenter que si l'app n'est pas en pause
      if (_pausedAt == null) {
        setState(() {
          _remainingSeconds--;
        });

        // Log tous les 30 secondes
        if (_remainingSeconds % 30 == 0) {
          print('⏱️  [USSD WAITING] Temps restant: $_remainingSeconds s');
        }
      }

      if (_remainingSeconds <= 0) {
        print('⏰ [USSD WAITING] Timeout atteint - annulation du timer');
        timer.cancel();
        if (!_isCompleted && !_isError) {
          _handleTimeout();
        }
      }
    });
  }

  /// Gère le succès du paiement
  void _handleSuccess() {
    print('✅ [USSD WAITING] Paiement validé avec succès !');

    setState(() {
      _isCompleted = true;
      _statusMessage = 'wallet.ussd.validated'.tr;
    });

    _timeoutTimer?.cancel();

    // Rafraîchir le wallet
    walletController.refresh();

    // Retour après 2 secondes
    Future.delayed(const Duration(seconds: 2), () {
      // Referme d'abord « Annuler la recharge ? » s'il est resté ouvert :
      // `Get.back(result: {...})` lui renvoyait ce résultat à lui, qui
      // attend un booléen — erreur de type en pleine navigation.
      if (mounted) AppNavigation.closeRoute(context, {'success': true});
    });
  }

  /// Gère l'échec du paiement
  void _handleFailure(String reason) {
    print('❌ [USSD WAITING] Paiement échoué: $reason');

    setState(() {
      _isError = true;
      _statusMessage = 'wallet.errors.payment_failed'.tr;
      _errorMessage = reason;
    });

    _timeoutTimer?.cancel();
  }

  /// Gère le timeout
  void _handleTimeout() {
    print('⏰ [USSD WAITING] Timeout atteint');

    setState(() {
      _isError = true;
      _statusMessage = 'wallet.ussd.timeout_title'.tr;
      _errorMessage = 'wallet.ussd.timeout_message'.tr;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _isCompleted || _isError,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('wallet.ussd.cancel_title'.tr),
            content: Text(
              'wallet.ussd.cancel_message'.tr,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('wallet.ussd.keep_waiting'.tr),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: AppThemeSystem.errorColor,
                ),
                child: Text('wallet.stripe_dialog.cancel'.tr),
              ),
            ],
          ),
        );

        if (shouldPop == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppThemeSystem.getBackgroundColor(context),
        appBar: AppBar(
          backgroundColor: AppThemeSystem.getBackgroundColor(context),
          // Passe par le `PopScope` ci-dessus, comme le retour système : pendant
          // le paiement, quitter demande toujours confirmation.
          leading: const AppBackButton(),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // La barre du haut occupe déjà l'essentiel de cet espace.
                const SizedBox(height: 8),

                // Icône animée
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _isCompleted || _isError ? 1.0 : _pulseAnimation.value,
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: _isCompleted
                              ? AppThemeSystem.successColor.withValues(alpha: 0.1)
                              : _isError
                                  ? AppThemeSystem.errorColor.withValues(alpha: 0.1)
                                  : AppDesign.accent.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isCompleted
                              ? Icons.check_circle_rounded
                              : _isError
                                  ? Icons.error_rounded
                                  : Icons.phone_android_rounded,
                          size: 80,
                          color: _isCompleted
                              ? AppThemeSystem.successColor
                              : _isError
                                  ? AppThemeSystem.errorColor
                                  : AppDesign.accent,
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 32),

                // Message de statut
                Text(
                  _statusMessage,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppThemeSystem.getPrimaryTextColor(context),
                  ),
                  textAlign: TextAlign.center,
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppThemeSystem.errorColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],

                const SizedBox(height: 16),

                // Indicateur de progression
                if (!_isCompleted && !_isError) ...[
                  const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'wallet.ussd.remaining_time'
                        .trParams({'seconds': '$_remainingSeconds'}),
                    style: TextStyle(
                      fontSize: 14,
                      color: AppThemeSystem.getSecondaryTextColor(context),
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Détails de la recharge
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppThemeSystem.getSurfaceColor(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppThemeSystem.getBorderColor(context),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow(
                        'wallet.locked.amount'.tr,
                        '${amount.toStringAsFixed(0)} FCFA',
                        context,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        'wallet.ussd.number'.tr,
                        phoneNumber,
                        context,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Instructions USSD
                if (!_isCompleted && !_isError)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppDesign.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppDesign.accent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline, color: AppDesign.accent),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'wallet.ussd.instructions_title'.tr,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'wallet.ussd.instructions'
                              .trParams({'phone': phoneNumber}),
                          style: TextStyle(
                            fontSize: 14,
                            color: AppThemeSystem.getSecondaryTextColor(context),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                // Boutons d'action
                if (_isCompleted)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Get.back(result: {'success': true}),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppThemeSystem.successColor,
                        foregroundColor: AppThemeSystem.whiteColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'wallet.ussd.continue'.tr,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                else if (_isError)
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Get.back(result: {'success': false}),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppThemeSystem.primaryColor,
                            foregroundColor: AppThemeSystem.whiteColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'wallet.retry'.tr,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Get.back(),
                        child: Text('wallet.stripe_dialog.cancel'.tr),
                      ),
                    ],
                  )
                else
                  TextButton(
                    onPressed: () => Get.back(),
                    child: Text('wallet.ussd.cancel_recharge'.tr),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: AppThemeSystem.getSecondaryTextColor(context),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppThemeSystem.getPrimaryTextColor(context),
          ),
        ),
      ],
    );
  }
}
