import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/widgets/iso_country_field.dart';
import '../../../core/utils/app_design.dart';
import '../../../data/models/maritime.dart';
import '../../../data/providers/currency_service.dart';
import '../../../data/providers/maritime_service.dart';
import '../../../routes/app_pages.dart';

/// Devis Chine → autres pays, puis réservation avec le tarif accepté.
class FreightInquiriesView extends StatefulWidget {
  const FreightInquiriesView({super.key});

  @override
  State<FreightInquiriesView> createState() => _FreightInquiriesViewState();
}

class _FreightInquiriesViewState extends State<FreightInquiriesView> {
  final service = Get.find<MaritimeService>();
  List<Map<String, dynamic>> inquiries = [];
  bool loading = true;
  int? acceptingId;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final items = await service.getInquiries();
      if (mounted) {
        setState(() {
          inquiries = items;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void discuss(Map<String, dynamic> inquiry) {
    Get.toNamed(
      Routes.CHATDETAIL,
      arguments: {
        'id': inquiry['conversation_id'].toString(),
        'name': 'ASSO',
        'avatar': 'A',
        'isOnline': false,
        'is_support': true,
        'default_message': 'freight_quote.chat_message'.trParams({
          'id': '${inquiry['id']}',
        }),
      },
    );
  }

  Future<void> accept(Map<String, dynamic> inquiry) async {
    if (acceptingId != null) return;
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text('freight_quote.accept'.tr),
        content: Text(
          'freight_quote.accept_message'.trParams({
            'amount': CurrencyService.formatFromCurrency(
              (inquiry['freight_amount'] as num).toDouble(),
              inquiry['currency'],
            ),
            'volume':
                '${inquiry['volume_cbm'] ?? (double.tryParse('${inquiry['kg']}') ?? 0) / 1000}',
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('common.cancel'.tr),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: Text('freight_quote.accept'.tr),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => acceptingId = inquiry['id']);
    try {
      final accepted = await service.acceptInquiry(inquiry);
      final rawDeparture = accepted['departure'];
      if (rawDeparture is! Map) throw Exception('freight_quote.unavailable'.tr);
      final departure = MaritimeDeparture.fromJson(
        Map<String, dynamic>.from(rawDeparture),
      );
      if (!mounted) return;
      await Get.toNamed(
        Routes.MARITIME_BOOKING,
        arguments: {'departure': departure, 'freight_inquiry': accepted},
      );
      await load();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => acceptingId = null);
    }
  }

  Future<void> create() async {
    final result = await Get.dialog<Map<String, dynamic>>(
      const _InquiryDialog(),
      barrierDismissible: false,
    );
    if (result == null || !mounted) return;
    await load();
    discuss(result);
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: load,
    child: ListView(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Text('freight_quote.intro'.tr),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: create,
          icon: const Icon(Icons.chat_outlined),
          label: Text('freight_quote.request'.tr),
        ),
        if (loading) const LinearProgressIndicator(),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (!loading && inquiries.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text('freight_quote.empty'.tr),
          ),
        for (final inquiry in inquiries)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${inquiry['id']} · ${isoCountryName('CN')} → ${isoCountryName(inquiry['destination_country'])}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${inquiry['volume_cbm'] ?? (double.tryParse('${inquiry['kg']}') ?? 0) / 1000} CBM · ${'freight_quote.status.${inquiry['status']}'.tr}',
                  ),
                  Text(inquiry['description']?.toString() ?? ''),
                  if (inquiry['freight_amount'] != null)
                    Text(
                      CurrencyService.formatFromCurrency(
                        (inquiry['freight_amount'] as num).toDouble(),
                        inquiry['currency'],
                      ),
                    ),
                  if (inquiry['expires_at'] != null)
                    Text(
                      'freight_quote.expiry'.trParams({
                        'date': '${inquiry['expires_at']}',
                      }),
                    ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => discuss(inquiry),
                        child: Text('freight_quote.discuss'.tr),
                      ),
                      if (['quoted', 'accepted'].contains(inquiry['status']))
                        FilledButton(
                          onPressed: acceptingId == null
                              ? () => accept(inquiry)
                              : null,
                          child: Text('freight_quote.accept'.tr),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class _InquiryDialog extends StatefulWidget {
  const _InquiryDialog();
  @override
  State<_InquiryDialog> createState() => _InquiryDialogState();
}

class _InquiryDialogState extends State<_InquiryDialog> {
  final volume = TextEditingController();
  final description = TextEditingController();
  String? country;
  String category = 'general';
  String? error;
  bool busy = false;

  @override
  void dispose() {
    volume.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    if (country == null || ['CN', 'CM'].contains(country)) {
      setState(() => error = 'freight_quote.country_error'.tr);
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await Get.find<MaritimeService>().createInquiry({
        'destination_country': country,
        'cargo_category': category,
        'volume_cbm': double.tryParse(volume.text.replaceAll(',', '.')),
        'description': description.text.trim(),
      });
      if (mounted) Get.back(result: result);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text('freight_quote.request'.tr),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      actionsOverflowButtonSpacing: AppDesign.space2,
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IsoCountryField(
                label: 'freight_quote.destination'.tr,
                value: country,
                onChanged: (value) => setState(() => country = value),
              ),
              const SizedBox(height: AppDesign.space5),
              TextField(
                controller: volume,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'freight_quote.volume'.tr,
                ),
              ),
              const SizedBox(height: AppDesign.space5),
              DropdownButtonFormField<String>(
                initialValue: category,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'maritime.form.cargo_category'.tr,
                ),
                items: ['general', 'sensitive']
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text('freight_quote.$value'.tr),
                      ),
                    )
                    .toList(),
                onChanged: busy
                    ? null
                    : (value) => category = value ?? 'general',
              ),
              const SizedBox(height: AppDesign.space5),
              TextField(
                controller: description,
                maxLength: 3000,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'freight_quote.description'.tr,
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppDesign.space3),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (busy) const LinearProgressIndicator(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Get.back(),
          child: Text('common.cancel'.tr),
        ),
        FilledButton(
          onPressed: busy ? null : submit,
          child: Text('freight_quote.discuss'.tr),
        ),
      ],
    ),
  );
}
