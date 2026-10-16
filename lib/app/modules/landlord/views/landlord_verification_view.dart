import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../data/providers/real_estate_service.dart';
import '../landlord_pickers.dart';

/// Vérification du bailleur : pièce d'identité, preuve de propriété et vidéo
/// où il tient ces documents. ASSO valide avant toute publication.
class LandlordVerificationView extends StatefulWidget {
  const LandlordVerificationView({super.key});

  @override
  State<LandlordVerificationView> createState() => _LandlordVerificationViewState();
}

class _LandlordVerificationViewState extends State<LandlordVerificationView> {
  static const _proofTypes = ['land_title', 'sale_deed', 'certificate', 'lease_contract', 'other'];

  String _idType = 'cni';
  String _proofType = 'land_title';
  XFile? _front;
  XFile? _back;
  XFile? _proof;
  XFile? _video;
  bool _sending = false;

  bool get _ready => _front != null && (_idType == 'passport' || _back != null) && _proof != null && _video != null;

  Future<void> _send() async {
    setState(() => _sending = true);
    final res = await RealEstateService.submitVerification(
      idType: _idType,
      idFront: _front!,
      idBack: _back,
      proofType: _proofType,
      proof: _proof!,
      video: _video!,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (res.success) {
      Get.back(result: true);
      Get.snackbar('landlord.verify.sent_title'.tr, 'landlord.verify.sent_message'.tr, snackPosition: SnackPosition.BOTTOM);
    } else {
      Get.snackbar('landlord.verify.error'.tr, res.message, snackPosition: SnackPosition.BOTTOM);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gutter = context.ds.gutter;

    return Scaffold(
      backgroundColor: context.ds.canvas,
      appBar: AppBar(leading: const AppBackButton(), title: Text('landlord.verify.title'.tr)),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(gutter, AppDesign.space2, gutter, AppDesign.space3),
          child: AppButton(
            label: 'landlord.verify.send'.tr,
            isLoading: _sending,
            onPressed: _ready && !_sending ? _send : null,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(gutter, AppDesign.space4, gutter, AppDesign.space8),
        children: [
          Text('landlord.verify.intro'.tr, style: context.textStyle(FontSizeType.body1, color: context.ds.textSecondary)),
          const SizedBox(height: AppDesign.space6),
          _Step(number: 1, title: 'landlord.verify.id_title'.tr),
          Wrap(
            spacing: AppDesign.space2,
            children: [
              for (final t in ['cni', 'passport'])
                ChoiceChip(
                  label: Text('landlord.verify.id_$t'.tr),
                  selected: _idType == t,
                  selectedColor: AppDesign.accentSubtle,
                  onSelected: (_) => setState(() => _idType = t),
                ),
            ],
          ),
          const SizedBox(height: AppDesign.space3),
          Row(
            children: [
              Expanded(child: _FileTile(
                label: 'landlord.verify.front'.tr,
                file: _front,
                icon: Icons.badge_outlined,
                onTap: () async {
                  final f = await LandlordPickers.photo(context);
                  if (f != null) setState(() => _front = f);
                },
              )),
              if (_idType == 'cni') ...[
                const SizedBox(width: AppDesign.space3),
                Expanded(child: _FileTile(
                  label: 'landlord.verify.back'.tr,
                  file: _back,
                  icon: Icons.badge_outlined,
                  onTap: () async {
                    final f = await LandlordPickers.photo(context);
                    if (f != null) setState(() => _back = f);
                  },
                )),
              ],
            ],
          ),
          const SizedBox(height: AppDesign.space6),
          _Step(number: 2, title: 'landlord.verify.proof_title'.tr),
          DropdownButtonFormField<String>(
            initialValue: _proofType,
            decoration: InputDecoration(
              labelText: 'landlord.verify.proof_type'.tr,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDesign.radiusSm)),
            ),
            items: [for (final t in _proofTypes) DropdownMenuItem(value: t, child: Text('landlord.proof.$t'.tr))],
            onChanged: (v) => setState(() => _proofType = v ?? _proofType),
          ),
          const SizedBox(height: AppDesign.space3),
          _FileTile(
            label: 'landlord.verify.proof_file'.tr,
            file: _proof,
            icon: Icons.description_outlined,
            onTap: () async {
              final f = await LandlordPickers.photo(context);
              if (f != null) setState(() => _proof = f);
            },
          ),
          const SizedBox(height: AppDesign.space6),
          _Step(number: 3, title: 'landlord.verify.video_title'.tr),
          Text('landlord.verify.video_help'.tr, style: context.textStyle(FontSizeType.body2, color: context.ds.textSecondary)),
          const SizedBox(height: AppDesign.space3),
          _FileTile(
            label: 'landlord.verify.video_button'.tr,
            file: _video,
            icon: Icons.videocam_outlined,
            onTap: () async {
              final f = await LandlordPickers.video(context, cameraOnly: !kIsWeb);
              if (f != null) setState(() => _video = f);
            },
          ),
          const SizedBox(height: AppDesign.space6),
          AppCard(
            color: AppDesign.infoSubtle,
            showBorder: false,
            elevated: false,
            padding: const EdgeInsets.all(AppDesign.space3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock_outline_rounded, color: AppDesign.infoText),
                const SizedBox(width: AppDesign.space2),
                Expanded(
                  child: Text('landlord.verify.privacy'.tr,
                      style: context.textStyle(FontSizeType.body2, color: AppDesign.infoText)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title});

  final int number;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesign.space3),
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: AppDesign.accent,
            child: Text('$number', style: context.textStyle(FontSizeType.caption, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
          const SizedBox(width: AppDesign.space2),
          Expanded(
            child: Text(title, style: context.textStyle(FontSizeType.subtitle1, fontWeight: FontWeight.w700, color: context.ds.textPrimary)),
          ),
        ],
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({required this.label, required this.file, required this.icon, required this.onTap});

  final String label;
  final XFile? file;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = file != null;

    return AppCard(
      onTap: onTap,
      color: done ? AppDesign.successSubtle : null,
      padding: const EdgeInsets.all(AppDesign.space4),
      child: Row(
        children: [
          Icon(done ? Icons.check_circle_rounded : icon, color: done ? AppDesign.success : context.ds.textSecondary),
          const SizedBox(width: AppDesign.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.textStyle(FontSizeType.body1, fontWeight: FontWeight.w600, color: context.ds.textPrimary)),
                Text(
                  done ? file!.name : 'landlord.verify.tap_to_add'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyle(FontSizeType.caption, color: context.ds.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
