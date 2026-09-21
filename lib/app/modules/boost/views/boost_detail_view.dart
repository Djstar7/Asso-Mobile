import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../data/models/boost_models.dart';
import '../controllers/boost_controller.dart';

/// Asso Ads — suivi détaillé d'une campagne.
///
/// Trois questions, dans cet ordre : combien de personnes ont vu l'annonce,
/// combien ont ouvert la fiche, combien ont pris contact. L'entonnoir se lit
/// de haut en bas.
class BoostDetailView extends StatefulWidget {
  const BoostDetailView({super.key});

  @override
  State<BoostDetailView> createState() => _BoostDetailViewState();
}

class _BoostDetailViewState extends State<BoostDetailView> {
  final controller = Get.find<BoostController>();

  BoostCampaign? campaign;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final args = Get.arguments;
    final id = int.tryParse(args is Map ? '${args['boost_id']}' : '');

    if (id == null) {
      setState(() => loading = false);
      return;
    }

    final fresh = await controller.refreshCampaign(id) ??
        controller.campaigns.firstWhereOrNull((c) => c.id == id);

    if (!mounted) return;
    setState(() {
      campaign = fresh;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesign.canvas(context),
      appBar: AppBar(
        backgroundColor: AppDesign.surface(context),
        elevation: 0,
        title: Text(
          'Suivi de la campagne',
          style: TextStyle(
            color: AppDesign.textPrimary(context),
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        iconTheme: IconThemeData(color: AppDesign.icon(context)),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : campaign == null
              ? Center(
                  child: Text(
                    'Campagne introuvable.',
                    style: TextStyle(color: AppDesign.textSecondary(context)),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      AppDesign.gutter(context),
                      16,
                      AppDesign.gutter(context),
                      32,
                    ),
                    children: [
                      _header(context, campaign!),
                      const SizedBox(height: 20),
                      _progress(context, campaign!),
                      const SizedBox(height: 20),
                      _funnel(context, campaign!),
                      const SizedBox(height: 20),
                      _chart(context, campaign!),
                      if (campaign!.isRunning) ...[
                        const SizedBox(height: 24),
                        _cancelButton(context, campaign!),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _header(BuildContext context, BoostCampaign c) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 56,
            height: 56,
            color: AppDesign.surfaceMuted(context),
            child: c.productImage != null && c.productImage!.isNotEmpty
                ? Image.network(
                    c.productImage!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => Icon(
                      Icons.inventory_2_outlined,
                      color: AppDesign.icon(context),
                    ),
                  )
                : Icon(Icons.inventory_2_outlined, color: AppDesign.icon(context)),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.productName,
                style: TextStyle(
                  color: AppDesign.textPrimary(context),
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${c.packageName ?? 'Sponsoring'} · ${c.statusLabel}',
                style: TextStyle(
                  color: AppDesign.textSecondary(context),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _progress(BuildContext context, BoostCampaign c) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppDesign.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppDesign.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Portée délivrée',
                      style: TextStyle(
                        color: AppDesign.textSecondary(context),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_n(c.impressionsServed)} / ${_n(c.impressionsQuota)}',
                      style: TextStyle(
                        color: AppDesign.textPrimary(context),
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${c.progressPercent.toStringAsFixed(1)} %',
                style: TextStyle(
                  color: AppDesign.accentText,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: c.progressFraction,
              minHeight: 8,
              backgroundColor: AppDesign.surfaceMuted(context),
              valueColor: AlwaysStoppedAnimation(
                c.isRunning ? AppDesign.accent : AppDesign.neutral400,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            c.isRunning
                ? 'Il reste ${_n(c.impressionsRemaining)} vues à délivrer '
                    'et ${c.remainingDays} jour${c.remainingDays > 1 ? 's' : ''}.'
                : 'Campagne terminée.',
            style: TextStyle(
              color: AppDesign.textSecondary(context),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _funnel(BuildContext context, BoostCampaign c) {
    return Column(
      children: [
        _funnelRow(
          context,
          icon: Icons.campaign_outlined,
          label: 'Personnes touchées',
          hint: "Votre annonce s'est affichée",
          value: _n(c.reached),
        ),
        const SizedBox(height: 10),
        _funnelRow(
          context,
          icon: Icons.touch_app_outlined,
          label: 'Ont ouvert votre article',
          hint: "${c.clickThroughRate.toStringAsFixed(1)} % des personnes touchées",
          value: _n(c.clicks),
        ),
        const SizedBox(height: 10),
        _funnelRow(
          context,
          icon: Icons.visibility_outlined,
          label: 'Ont vu la fiche',
          hint: 'Personnes différentes, toutes origines',
          value: _n(c.viewers),
        ),
        const SizedBox(height: 10),
        _funnelRow(
          context,
          icon: Icons.chat_bubble_outline,
          label: 'Vous ont contacté',
          hint: 'Personnes différentes',
          value: _n(c.interactions),
          highlight: true,
        ),
      ],
    );
  }

  Widget _funnelRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String hint,
    required String value,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight
            ? AppDesign.successSubtle
            : AppDesign.surface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight
              ? AppDesign.success.withValues(alpha: 0.25)
              : AppDesign.border(context),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: highlight
                ? AppDesign.successText
                : AppDesign.textSecondary(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: highlight
                        ? AppDesign.successText
                        : AppDesign.textPrimary(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hint,
                  style: TextStyle(
                    color: AppDesign.textTertiary(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: highlight
                  ? AppDesign.successText
                  : AppDesign.textPrimary(context),
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  /// Histogramme simple : une barre par jour, hauteur relative au maximum.
  /// Pas de dépendance graphique pour trois barres.
  Widget _chart(BuildContext context, BoostCampaign c) {
    if (c.series.isEmpty) return const SizedBox.shrink();

    final max = c.series
        .map((p) => p.impressions)
        .fold<int>(0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppDesign.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppDesign.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Diffusion jour par jour',
            style: TextStyle(
              color: AppDesign.textPrimary(context),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: c.series.map((point) {
                final ratio = max > 0 ? point.impressions / max : 0.0;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${point.impressions}',
                          style: TextStyle(
                            color: AppDesign.textTertiary(context),
                            fontSize: 9.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          height: (ratio * 70).clamp(3.0, 70.0),
                          decoration: BoxDecoration(
                            color: AppDesign.accent,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _shortDate(point.date),
                          style: TextStyle(
                            color: AppDesign.textTertiary(context),
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cancelButton(BuildContext context, BoostCampaign c) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          await controller.cancelCampaign(c);
          if (mounted) _load();
        },
        icon: const Icon(Icons.stop_circle_outlined, size: 18),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppDesign.danger,
          side: BorderSide(color: AppDesign.danger.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        label: const Text('Arrêter le sponsoring'),
      ),
    );
  }

  String _shortDate(String iso) {
    final parts = iso.split('-');
    return parts.length >= 3 ? '${parts[2]}/${parts[1]}' : iso;
  }

  String _n(int value) {
    final text = value.toString();
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(text[i]);
    }

    return buffer.toString();
  }
}
