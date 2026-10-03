import 'package:asso/app/core/utils/app_theme_system.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/widgets/app_ui.dart';
import '../../../core/utils/app_navigation.dart';

/// WebView générique pour les paiements (KPay et PayPal)
class PaymentWebView extends StatefulWidget {
  final String paymentUrl;
  final String paymentMethod; // 'kpay' ou 'paypal'
  final int paymentId;
  final Function(bool success, String message)? onPaymentComplete;

  const PaymentWebView({
    Key? key,
    required this.paymentUrl,
    required this.paymentMethod,
    required this.paymentId,
    this.onPaymentComplete,
  }) : super(key: key);

  @override
  State<PaymentWebView> createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<PaymentWebView> {
  late final WebViewController _controller;
  final isLoading = true.obs;
  final loadingProgress = 0.0.obs;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            print('[PaymentWebView] Page started: $url');
            isLoading.value = true;
            _checkPaymentCompletion(url);
          },
          onPageFinished: (String url) {
            print('[PaymentWebView] Page finished: $url');
            isLoading.value = false;
          },
          onProgress: (int progress) {
            loadingProgress.value = progress / 100;
          },
          onWebResourceError: (WebResourceError error) {
            print('[PaymentWebView] Error: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) {
            // Intercept flutter:// URLs
            if (request.url.startsWith('flutter://payment-success')) {
              print('[PaymentWebView] Flutter URL intercepted: ${request.url}');
              _handleFlutterUrl(request.url);
              return NavigationDecision.prevent;
            } else if (request.url.startsWith('flutter://payment-cancelled')) {
              print('[PaymentWebView] Payment cancelled via Flutter URL');
              _handlePaymentFailure('wallet.webview.cancelled'.tr);
              return NavigationDecision.prevent;
            } else if (request.url.startsWith('flutter://payment-error')) {
              print('[PaymentWebView] Payment error via Flutter URL');
              _handlePaymentFailure('wallet.webview.error_occurred'.tr);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..addJavaScriptChannel(
        'FlutterPayment',
        onMessageReceived: (JavaScriptMessage message) {
          print('[PaymentWebView] 📨 JavaScript message received: ${message.message}');
          _handleJavaScriptMessage(message.message);
        },
      )
      ..addJavaScriptChannel(
        'PaymentResult',
        onMessageReceived: (JavaScriptMessage message) {
          print('[PaymentWebView] 📨 PaymentResult message received: ${message.message}');
          _handleJavaScriptMessage(message.message);
        },
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  void _checkPaymentCompletion(String url) {
    print('[PaymentWebView] Checking URL: $url');

    // Détection générique des URLs de retour, valable pour TOUS les rails de
    // redirection (KPay, PayPal, Stripe Checkout). La confirmation réelle du
    // paiement se fait côté serveur (webhook + polling) ; ici on ne fait que
    // clôturer la WebView au bon moment.
    if (url.contains('/payment/success') || url.contains('status=success')) {
      _handlePaymentSuccess('wallet.webview.payment_done'.tr);
    } else if (url.contains('/payment/cancel') ||
        url.contains('/payment/failed') ||
        url.contains('status=failed') ||
        url.contains('status=cancel')) {
      _handlePaymentFailure('wallet.webview.cancelled_or_failed'.tr);
    }
  }

  /// Handle JavaScript messages from payment result pages
  void _handleJavaScriptMessage(String message) {
    try {
      print('[PaymentWebView] Parsing JavaScript message...');

      // Parse JSON message
      final data = message.contains('{') ? _parseJson(message) : null;

      if (data == null) {
        print('[PaymentWebView] Invalid JSON message');
        return;
      }

      print('[PaymentWebView] Parsed data: $data');

      final success = data['success'] == true;
      final cancelled = data['cancelled'] == true;
      final error = data['error'] == true;

      if (success) {
        final amount = data['amount']?.toString() ?? '';
        _handlePaymentSuccess(
            'wallet.webview.success_credited'.trParams({'amount': '$amount'}));
      } else if (cancelled) {
        _handlePaymentFailure('wallet.webview.cancelled'.tr);
      } else if (error) {
        final errorMessage = data['message']?.toString() ?? 'wallet.webview.error_occurred'.tr;
        _handlePaymentFailure(errorMessage);
      }
    } catch (e) {
      print('[PaymentWebView] Error handling JavaScript message: $e');
    }
  }

  /// Parse JSON string to Map
  Map<String, dynamic>? _parseJson(String jsonString) {
    try {
      // Remove any escape characters
      final cleanJson = jsonString.replaceAll(r'\', '');

      // Simple JSON parser (basic implementation)
      // In production, you should use dart:convert
      if (!cleanJson.contains('{') || !cleanJson.contains('}')) {
        return null;
      }

      // For this use case, we'll use a simple regex approach
      final Map<String, dynamic> result = {};

      final successMatch = RegExp(r'"success"\s*:\s*(true|false)').firstMatch(cleanJson);
      if (successMatch != null) {
        result['success'] = successMatch.group(1) == 'true';
      }

      final cancelledMatch = RegExp(r'"cancelled"\s*:\s*(true|false)').firstMatch(cleanJson);
      if (cancelledMatch != null) {
        result['cancelled'] = cancelledMatch.group(1) == 'true';
      }

      final errorMatch = RegExp(r'"error"\s*:\s*(true|false)').firstMatch(cleanJson);
      if (errorMatch != null) {
        result['error'] = errorMatch.group(1) == 'true';
      }

      final amountMatch = RegExp(r'"amount"\s*:\s*(\d+\.?\d*)').firstMatch(cleanJson);
      if (amountMatch != null) {
        result['amount'] = double.tryParse(amountMatch.group(1) ?? '0');
      }

      final messageMatch = RegExp(r'"message"\s*:\s*"([^"]*)"').firstMatch(cleanJson);
      if (messageMatch != null) {
        result['message'] = messageMatch.group(1);
      }

      return result;
    } catch (e) {
      print('[PaymentWebView] JSON parsing error: $e');
      return null;
    }
  }

  /// Handle flutter:// URL navigation
  void _handleFlutterUrl(String url) {
    try {
      final uri = Uri.parse(url);

      if (uri.scheme == 'flutter' && uri.host == 'payment-success') {
        final paymentId = uri.queryParameters['payment_id'];
        final amount = uri.queryParameters['amount'];

        print('[PaymentWebView] Payment success: ID=$paymentId, Amount=$amount');
        _handlePaymentSuccess(
            'wallet.webview.success_credited'.trParams({'amount': '$amount'}));
      }
    } catch (e) {
      print('[PaymentWebView] Error handling Flutter URL: $e');
    }
  }

  void _handlePaymentSuccess(String message) {
    if (widget.onPaymentComplete != null) {
      widget.onPaymentComplete!(true, message);
    } else {
      _close({'success': true, 'message': message});
      Get.snackbar(
        'wallet.webview.success_title'.tr,
        message,
        backgroundColor: AppThemeSystem.successColor,
        colorText: AppThemeSystem.whiteColor,
        duration: const Duration(seconds: 3),
      );
    }
  }

  void _handlePaymentFailure(String message) {
    if (widget.onPaymentComplete != null) {
      widget.onPaymentComplete!(false, message);
    } else {
      _close({'success': false, 'message': message});
      Get.snackbar(
        'wallet.webview.failure_title'.tr,
        message,
        backgroundColor: AppThemeSystem.errorColor,
        colorText: AppThemeSystem.whiteColor,
        duration: const Duration(seconds: 3),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.paymentMethod == 'paypal'
              ? 'wallet.webview.title_paypal'.tr
              : widget.paymentMethod == 'stripe'
                  ? 'wallet.webview.title_card'.tr
                  : 'wallet.webview.title_mobile_money'.tr,
        ),
        centerTitle: true,
        backgroundColor: AppThemeSystem.primaryColor,
        foregroundColor: AppThemeSystem.whiteColor,
        leading: AppBackButton(
          close: true,
          color: AppThemeSystem.whiteColor,
          onPressed: _showCancelDialog,
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),

          // Loading indicator
          Obx(() {
            if (isLoading.value) {
              return Builder(
                builder: (context) => Container(
                  color: context.backgroundColor,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: AppThemeSystem.primaryColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'wallet.webview.loading'.tr,
                          style: TextStyle(
                            fontSize: 16,
                            color: context.secondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Obx(() => LinearProgressIndicator(
                              value: loadingProgress.value,
                              backgroundColor: AppThemeSystem.grey200,
                              color: AppThemeSystem.primaryColor,
                            )),
                      ],
                    ),
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
    );
  }

  /// Referme la page de paiement avec son résultat.
  ///
  /// Navigator et non Get.back() : avec GetX 4.7.3, Get.back() ne ferme que
  /// la bannière éventuellement affichée, et la page restait ouverte.
  void _close(Map<String, dynamic> result) {
    // Ferme aussi la confirmation d'annulation si elle est ouverte, et ne
    // ferme rien si la page est déjà en train de partir.
    if (mounted) AppNavigation.closeRoute(context, result);
  }

  Future<void> _showCancelDialog() async {
    final cancel = await Get.dialog<bool>(
      Builder(
        builder: (dialogContext) => AlertDialog(
          title: Text('wallet.webview.cancel_title'.tr),
          content: Text('wallet.webview.cancel_message'.tr),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('wallet.webview.no'.tr),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'wallet.webview.yes_cancel'.tr,
                style: TextStyle(color: AppThemeSystem.errorColor),
              ),
            ),
          ],
        ),
      ),
    );
    if (cancel == true) {
      _close({'success': false, 'message': 'wallet.webview.cancelled_by_user'.tr});
    }
  }
}
