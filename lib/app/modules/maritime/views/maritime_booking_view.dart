import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_ui.dart';
import '../controllers/maritime_booking_controller.dart';
import 'maritime_insurance_section.dart';

/// Formulaire d'envoi maritime : kilos et colis, coordonnées, nature et valeur
/// du colis, récapitulatif avec la date limite de dépôt, puis paiement.
class MaritimeBookingView extends GetView<MaritimeBookingController> {
  const MaritimeBookingView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppThemeSystem.isDarkMode(context);

    return Scaffold(
      backgroundColor: isDark ? AppThemeSystem.darkBackgroundColor : AppDesign.neutral50,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text('maritime.form.title'.tr),
        centerTitle: true,
      ),
      body: Obx(() {
        final d = controller.departure.value;
        if (d == null) return const SizedBox.shrink();

        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: controller.scrollController,
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _routeCard(isDark),
                    Obx(() => Text(controller.departure.value?.commercialSummary ?? '', style: TextStyle(color: AppThemeSystem.grey600))),
                    const SizedBox(height: 16),
                    _section(isDark, 'maritime.form.parcel'.tr, Icons.scale_outlined, [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _field(isDark, controller.kgController, 'maritime.form.kg'.tr,
                                errorKey: 'kg_booked', suffix: 'kg', number: true, decimal: true),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _field(isDark, controller.parcelsController, 'maritime.form.parcels'.tr,
                                errorKey: 'parcels_count', number: true),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'maritime.form.kg_available'.trParams({'kg': controller.remainingKg.toStringAsFixed(1)}),
                        style: TextStyle(fontSize: 12, color: _muted(isDark)),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _section(isDark, 'maritime.form.sender'.tr, Icons.person_outline, [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                            child: _field(isDark, controller.senderFirstName, 'maritime.form.first_name'.tr,
                                errorKey: 'sender_first_name')),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _field(isDark, controller.senderLastName, 'maritime.form.last_name'.tr,
                                errorKey: 'sender_last_name')),
                      ]),
                      const SizedBox(height: 12),
                      _field(isDark, controller.senderPhone, 'maritime.form.your_phone'.tr,
                          errorKey: 'sender_phone', phone: true),
                      const SizedBox(height: 12),
                      _field(isDark, controller.emergencyPhone, 'maritime.form.emergency_phone'.tr,
                          errorKey: 'emergency_phone', phone: true),
                    ]),
                    const SizedBox(height: 16),
                    _section(isDark, 'maritime.form.recipient'.tr, Icons.person_pin_circle_outlined, [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                            child: _field(isDark, controller.recipientFirstName, 'maritime.form.first_name'.tr,
                                errorKey: 'recipient_first_name')),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _field(isDark, controller.recipientLastName, 'maritime.form.last_name'.tr,
                                errorKey: 'recipient_last_name')),
                      ]),
                      const SizedBox(height: 12),
                      _field(isDark, controller.recipientPhone, 'maritime.form.recipient_phone'.tr,
                          errorKey: 'recipient_phone', phone: true),
                    ]),
                    const SizedBox(height: 16),
                    Obx(
                      () => MaritimeInsuranceSection(
                        form: controller.insurance,
                        optIn: controller.insuranceOptIn,
                        formatAmount: controller.formatAmount,
                        decoration: _cardDeco(isDark),
                        mutedColor: _muted(isDark),
                        natureError: controller.errorOf('parcel_nature_id'),
                        valueError: controller.errorOf('declared_value'),
                        natureKey: controller.fieldKeys['parcel_nature_id'],
                        valueKey: controller.fieldKeys['declared_value'],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _summary(isDark),
                  ],
                ),
              ),
            ),
            _payButton(context, isDark),
          ],
        );
      }),
    );
  }

  Color _muted(bool isDark) => isDark ? Colors.white70 : AppDesign.neutral500;
  Color _fill(bool isDark) => isDark ? Colors.white.withValues(alpha: 0.04) : AppDesign.neutral50;

  BoxDecoration _cardDeco(bool isDark) => BoxDecoration(
        color: isDark ? AppThemeSystem.darkCardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : AppDesign.neutral200),
      );

  Widget _section(bool isDark, String title, IconData icon, List<Widget> children) => Container(
        padding: const EdgeInsets.all(18),
        decoration: _cardDeco(isDark),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 20, color: AppThemeSystem.primaryColor),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      );

  Widget _field(
    bool isDark,
    TextEditingController c,
    String label, {
    required String errorKey,
    String? suffix,
    bool number = false,
    bool decimal = false,
    bool phone = false,
  }) =>
      Obx(() => KeyedSubtree(
            key: controller.fieldKeys[errorKey],
            child: TextField(
              controller: c,
              keyboardType: phone
                  ? TextInputType.phone
                  : number
                      ? TextInputType.numberWithOptions(decimal: decimal)
                      : TextInputType.name,
              textCapitalization: number || phone ? TextCapitalization.none : TextCapitalization.words,
              inputFormatters: number
                  ? [FilteringTextInputFormatter.allow(RegExp(decimal ? r'^\d+[.,]?\d{0,1}' : r'^\d+'))]
                  : phone
                      ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))]
                      : null,
              decoration: InputDecoration(
                labelText: label,
                hintText: phone ? '+237 6XX XX XX XX' : null,
                suffixText: suffix,
                errorText: controller.errorOf(errorKey),
                errorMaxLines: 2,
                filled: true,
                fillColor: _fill(isDark),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppDesign.danger, width: 1.2),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppDesign.danger, width: 1.5),
                ),
              ),
            ),
          ));

  Widget _routeCard(bool isDark) {
    final d = controller.departure.value!;
    final from = d.originHub;
    final to = d.destinationHub;

    Widget hub(IconData icon, Color color, String label, String? text) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: TextStyle(fontSize: 11, color: _muted(isDark))),
                Text(text ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
            ),
          ],
        );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDeco(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(d.transportMode == 'air' ? Icons.flight : Icons.directions_boat, color: AppThemeSystem.primaryColor),
            const SizedBox(width: 8),
            Expanded(child: Text('Diaspo Exchange', style: const TextStyle(fontWeight: FontWeight.w700))),
            Text('${controller.formatAmount(d.pricePerKg)}/kg',
                style: TextStyle(fontWeight: FontWeight.w700, color: AppThemeSystem.primaryColor)),
          ]),
          const SizedBox(height: 14),
          if (!d.meetingDetailsAvailable) ...[
            Text('partner_freight.meeting_after_payment'.tr, style: TextStyle(color: _muted(isDark))),
            const SizedBox(height: 10),
          ],
          hub(Icons.warehouse_outlined, AppDesign.success, 'maritime.form.dropoff_hub'.tr, from?.fullAddress),
          const SizedBox(height: 10),
          hub(Icons.place_outlined, AppDesign.danger, 'maritime.form.pickup_hub'.tr, to?.fullAddress),
          const SizedBox(height: 10),
          Text(
            'maritime.departure_on'.trParams({'date': controller.formatDate(d.departureDate)}),
            style: TextStyle(fontSize: 12, color: _muted(isDark)),
          ),
          if (d.notes != null && d.notes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(d.notes!, style: TextStyle(fontSize: 12, color: _muted(isDark))),
          ],
        ],
      ),
    );
  }

  Widget _summary(bool isDark) {
    final d = controller.departure.value!;
    return Obx(() => Container(
          padding: const EdgeInsets.all(18),
          decoration: _cardDeco(isDark),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('maritime.form.summary'.tr, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              _row(isDark, '${controller.kg.value.toStringAsFixed(1)} kg × ${controller.formatAmount(controller.pricePerKg)}',
                  controller.formatAmount(controller.freight)),
              if (d.isPricedPerCbm) ...[
                const SizedBox(height: 4),
                Text(
                  'maritime.form.volume_line'.trParams({
                    'volume': d.volumeForKg(controller.kg.value)!.toStringAsFixed(3),
                    'price': controller.formatAmount(d.pricePerCbm!),
                  }),
                  style: TextStyle(fontSize: 12, color: _muted(isDark)),
                ),
              ],
              const SizedBox(height: 8),
              _insuranceQuoteLine(isDark),
              const Divider(height: 24),
              _row(isDark, 'maritime.form.total'.tr, controller.formatAmount(controller.grandTotal), total: true),
              const SizedBox(height: 14),
              // Transparence : la date limite de dépôt est montrée avant le paiement.
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppDesign.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.schedule, size: 18, color: AppDesign.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'maritime.form.dropoff_warning'.trParams({
                          'hub': d.originHub?.fullAddress ?? '',
                          'date': controller.formatDate(d.dropoffDeadline),
                        }),
                        style: const TextStyle(fontSize: 12, color: AppDesign.accentText, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ));
  }

  Widget _insuranceQuoteLine(bool isDark) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              controller.insuranceOptIn.value
                  ? 'maritime.form.insurance_line'.tr
                  : 'maritime.form.insurance_quote_not_charged'.tr,
              style: TextStyle(fontSize: 14, color: _muted(isDark)),
            ),
          ),
          if (controller.insurance.isQuoting.value)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Text(
              controller.insurance.quoteAvailable.value
                  ? controller.formatAmount(
                      controller.insurance.insuranceAmount.value,
                    )
                  : 'maritime.form.insurance_quote_unknown'.tr,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
        ],
      );

  Widget _row(bool isDark, String label, String value, {bool total = false}) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(label,
                style: TextStyle(
                  fontSize: total ? 16 : 14,
                  fontWeight: total ? FontWeight.w700 : FontWeight.w500,
                  color: total ? null : _muted(isDark),
                )),
          ),
          Text(value,
              style: TextStyle(
                fontSize: total ? 20 : 14,
                fontWeight: FontWeight.w700,
                color: total ? AppThemeSystem.primaryColor : null,
              )),
        ],
      );

  Widget _payButton(BuildContext context, bool isDark) => Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
        color: isDark ? AppThemeSystem.darkCardColor : Colors.white,
        child: Obx(() => SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: controller.isSubmitting.value ||
                        (controller.insuranceOptIn.value &&
                            controller.insurance.isQuoting.value)
                    ? null
                    : controller.submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeSystem.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: controller.isSubmitting.value ||
                        (controller.insuranceOptIn.value &&
                            controller.insurance.isQuoting.value)
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.lock_outline, size: 18),
                label: Text(
                  'maritime.form.pay'.trParams({'amount': controller.formatAmount(controller.grandTotal)}),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            )),
      );
}