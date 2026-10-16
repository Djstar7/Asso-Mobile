import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../data/providers/real_estate_service.dart';

/// « Confier mon projet » (capture SeLoger) : l'acheteur dit s'il a déjà un
/// terrain, puis décrit son projet ; ASSO le rappelle et l'oriente vers un
/// cabinet partenaire.
class ImmoProjectView extends StatefulWidget {
  const ImmoProjectView({super.key, this.hasLand});

  final bool? hasLand;

  @override
  State<ImmoProjectView> createState() => _ImmoProjectViewState();
}

class _ImmoProjectViewState extends State<ImmoProjectView> {
  late bool? _hasLand = widget.hasLand;
  final _city = TextEditingController();
  final _district = TextEditingController();
  final _surface = TextEditingController();
  final _budget = TextEditingController();
  final _phone = TextEditingController();
  final _message = TextEditingController();
  bool _sending = false;
  bool _sent = false;

  @override
  void dispose() {
    for (final c in [_city, _district, _surface, _budget, _phone, _message]) {
      c.dispose();
    }
    super.dispose();
  }

  int? _number(TextEditingController c) => int.tryParse(c.text.replaceAll(RegExp(r'[^0-9]'), ''));

  Future<void> _send() async {
    setState(() => _sending = true);
    final res = await RealEstateService.sendProjectRequest({
      'has_land': _hasLand,
      'city': _city.text.trim(),
      'district': _district.text.trim(),
      if (_number(_surface) != null) 'surface_m2': _number(_surface),
      if (_number(_budget) != null) 'budget': _number(_budget),
      if (_phone.text.trim().isNotEmpty) 'phone': _phone.text.trim(),
      'message': _message.text.trim(),
    }..removeWhere((_, v) => v == ''));
    if (!mounted) return;
    setState(() {
      _sending = false;
      _sent = res.success;
    });
    if (!res.success) {
      Get.snackbar('immo.project.error'.tr, res.message, snackPosition: SnackPosition.BOTTOM);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gutter = context.ds.gutter;

    return Scaffold(
      backgroundColor: context.ds.canvas,
      body: _sent
          ? AppEmptyState(
              icon: Icons.check_circle_outline_rounded,
              title: 'immo.project.sent_title'.tr,
              message: 'immo.project.sent_message'.tr,
              actionLabel: 'immo.project.back'.tr,
              onAction: () => Navigator.of(context).maybePop(),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(gutter, AppDesign.space4, gutter, AppDesign.space8),
              children: [
                Text('immo.project.title'.tr, textAlign: TextAlign.center,
                    style: context.textStyle(FontSizeType.h6, fontWeight: FontWeight.w800, color: context.ds.textPrimary)),
                const SizedBox(height: AppDesign.space2),
                Center(child: AppBadge(label: 'immo.project.free'.tr, tone: AppBadgeTone.accent)),
                const SizedBox(height: AppDesign.space3),
                Text('immo.project.intro'.tr, textAlign: TextAlign.center,
                    style: context.textStyle(FontSizeType.body1, color: context.ds.textSecondary)),
                const SizedBox(height: AppDesign.space6),
                Text('immo.project.question'.tr,
                    style: context.textStyle(FontSizeType.subtitle1, fontWeight: FontWeight.w800, color: context.ds.textPrimary)),
                const SizedBox(height: AppDesign.space3),
                Row(
                  children: [
                    Expanded(child: _Choice(
                      icon: Icons.landscape_rounded,
                      label: 'immo.project.has_land'.tr,
                      selected: _hasLand == true,
                      onTap: () => setState(() => _hasLand = true),
                    )),
                    const SizedBox(width: AppDesign.space3),
                    Expanded(child: _Choice(
                      icon: Icons.travel_explore_rounded,
                      label: 'immo.project.looking'.tr,
                      selected: _hasLand == false,
                      onTap: () => setState(() => _hasLand = false),
                    )),
                  ],
                ),
                if (_hasLand != null) ...[
                  const SizedBox(height: AppDesign.space6),
                  AppTextField(label: 'immo.project.city'.tr, controller: _city, prefixIcon: const Icon(Icons.location_city_outlined)),
                  const SizedBox(height: AppDesign.space3),
                  AppTextField(label: 'immo.project.district'.tr, controller: _district, prefixIcon: const Icon(Icons.location_on_outlined)),
                  const SizedBox(height: AppDesign.space3),
                  AppTextField(label: 'immo.project.surface'.tr, controller: _surface, keyboardType: TextInputType.number),
                  const SizedBox(height: AppDesign.space3),
                  AppTextField(label: 'immo.project.budget'.tr, controller: _budget, keyboardType: TextInputType.number),
                  const SizedBox(height: AppDesign.space3),
                  AppTextField(label: 'immo.project.phone'.tr, controller: _phone, keyboardType: TextInputType.phone),
                  const SizedBox(height: AppDesign.space3),
                  AppTextField(label: 'immo.project.message'.tr, controller: _message, maxLines: 4),
                  const SizedBox(height: AppDesign.space6),
                  AppButton(label: 'immo.project.send'.tr, isLoading: _sending, onPressed: _sending ? null : _send),
                ],
              ],
            ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      color: selected ? AppDesign.accentSubtle : null,
      padding: const EdgeInsets.symmetric(vertical: AppDesign.space6, horizontal: AppDesign.space3),
      child: Column(
        children: [
          Icon(icon, size: 48, color: selected ? AppDesign.accent : context.ds.textSecondary),
          const SizedBox(height: AppDesign.space3),
          Text(label, textAlign: TextAlign.center,
              style: context.textStyle(FontSizeType.body1, fontWeight: FontWeight.w600, color: context.ds.textPrimary)),
        ],
      ),
    );
  }
}
