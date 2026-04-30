import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../data/providers/currency_service.dart';

/// Widget de debug pour afficher les informations de devise en temps réel
class CurrencyDebugWidget extends StatelessWidget {
  const CurrencyDebugWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 100,
      right: 10,
      child: Obx(() {
        if (!Get.isRegistered<CurrencyService>()) {
          return Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '❌ CurrencyService\nNOT REGISTERED',
              style: TextStyle(color: Colors.white, fontSize: 10),
            ),
          );
        }

        final currencyService = CurrencyService.to;
        final currency = currencyService.userCurrency;
        final isLoading = currencyService.isLoading;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green, width: 2),
          ),
          constraints: const BoxConstraints(maxWidth: 200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '💱 CURRENCY DEBUG',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(color: Colors.green, height: 10),
              if (isLoading)
                const Row(
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Loading...',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ],
                )
              else if (currency != null) ...[
                _buildInfoRow('Code:', currency.code),
                _buildInfoRow('Symbol:', currency.symbol),
                _buildInfoRow('Name:', currency.name, maxLines: 2),
                const SizedBox(height: 4),
                _buildInfoRow('Country:', currencyService.detectedCountry),
                const SizedBox(height: 4),
                _buildInfoRow(
                  'Rate to XOF:',
                  currencyService.exchangeRateToXOF.toStringAsFixed(4),
                ),
                const Divider(color: Colors.green, height: 10),
                _buildInfoRow(
                  'Test 1000 XOF:',
                  currencyService.formatPrice(1000),
                ),
              ] else
                const Text(
                  'No currency set',
                  style: TextStyle(color: Colors.orange, fontSize: 10),
                ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  await currencyService.detectAndSetUserCurrency();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Refresh',
                    style: TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildInfoRow(String label, String value, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 9),
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
