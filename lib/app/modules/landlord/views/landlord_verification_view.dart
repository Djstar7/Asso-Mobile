import 'package:asso/app/core/utils/app_feedback.dart';
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
  State<LandlordVerificationView> createState() =>
      _LandlordVerificationViewState();
}

class _LandlordVerificationViewState extends State<LandlordVerificationView> {
  static const _proofTypes = [
    'land_title',
    'sale_deed',
    'certificate',
    'lease_contract',
    'other',
  ];

  String _idType = 'cni';
  String _proofType = 'land_title';
  XFile? _front;
  XFile? _back;
  XFile? _proof;
  XFile? _video;
  bool _sending = false;
  final _errors = <String, String>{};
  final _fieldKeys = {
    for (final field in [
      'id_document_type',
      'id_front',
      'id_back',
      'ownership_proof_type',
      'ownership_proof',
      'video',
    ])
      field: GlobalKey(),
  };
  String? _formError;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _replaceFile(String field, VoidCallback update) {
    if (!mounted) return;
    setState(() {
      update();
      _errors.remove(field);
      _formError = null;
    });
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _errors.clear();
      _formError = null;
    });
    try {
      final files = <String, (XFile?, int, String)>{
        'id_front': (_front, 8 * 1024 * 1024, 'id_size'),
        if (_idType == 'cni') 'id_back': (_back, 8 * 1024 * 1024, 'id_size'),
        'ownership_proof': (_proof, 10 * 1024 * 1024, 'proof_size'),
        'video': (_video, 100 * 1024 * 1024, 'video_size'),
      };
      for (final entry in files.entries) {
        final (file, maxBytes, sizeMessage) = entry.value;
        if (file == null) {
          _errors[entry.key] = 'landlord_upload.${entry.key}'.tr;
        } else {
          try {
            if (await file.length() > maxBytes) {
              _errors[entry.key] = 'landlord_upload.$sizeMessage'.tr;
            }
          } catch (_) {
            _errors[entry.key] = 'landlord_upload.read_failed'.tr;
          }
        }
      }
      if (_errors.isNotEmpty) return;
      final res = await RealEstateService.submitVerification(
        idType: _idType,
        idFront: _front!,
        idBack: _idType == 'cni' ? _back : null,
        proofType: _proofType,
        proof: _proof!,
        video: _video!,
      );
      if (!mounted) return;
      if (res.success) {
        Get.back(result: true);
        AppFeedback.show(
          'landlord.verify.sent_title'.tr,
          'landlord.verify.sent_message'.tr,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
      final serverErrors = res.data?['errors'];
      if (serverErrors is Map) {
        for (final entry in serverErrors.entries) {
          if ([
            'id_document_type',
            'id_front',
            'id_back',
            'ownership_proof_type',
            'ownership_proof',
            'video',
          ].contains(entry.key)) {
            final messages = entry.value;
            _errors[entry.key.toString()] = messages is List
                ? messages.map((e) => e.toString()).join('\n')
                : messages.toString();
          }
        }
      }
      if (_errors.isEmpty) {
        _formError = res.statusCode == 413
            ? 'landlord_upload.too_large'.tr
            : res.statusCode >= 500
            ? 'landlord_upload.server'.tr
            : res.statusCode == 0
            ? 'landlord_upload.network'.tr
            : res.message;
      }
    } catch (_) {
      _formError = 'landlord_upload.network'.tr;
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        if (_errors.isNotEmpty || _formError != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_scroll.hasClients) return;
            final target = _errors.isNotEmpty
                ? _fieldKeys[_errors.keys.first]?.currentContext
                : null;
            if (target != null) {
              Scrollable.ensureVisible(
                target,
                duration: const Duration(milliseconds: 250),
                alignment: 0.15,
              );
            } else {
              _scroll.animateTo(
                0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              );
            }
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gutter = context.ds.gutter;

    return Scaffold(
      backgroundColor: context.ds.canvas,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text('landlord.verify.title'.tr),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            gutter,
            AppDesign.space2,
            gutter,
            AppDesign.space3,
          ),
          child: AppButton(
            label: 'landlord.verify.send'.tr,
            isLoading: _sending,
            onPressed: !_sending ? _send : null,
          ),
        ),
      ),
      body: ListView(
        controller: _scroll,
        padding: EdgeInsets.fromLTRB(
          gutter,
          AppDesign.space4,
          gutter,
          AppDesign.space8,
        ),
        children: [
          if (_formError != null) ...[
            Text(
              _formError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: AppDesign.space3),
          ],
          Text(
            'landlord.verify.intro'.tr,
            style: context.textStyle(
              FontSizeType.body1,
              color: context.ds.textSecondary,
            ),
          ),
          const SizedBox(height: AppDesign.space6),
          _Step(number: 1, title: 'landlord.verify.id_title'.tr),
          Wrap(
            key: _fieldKeys['id_document_type'],
            spacing: AppDesign.space2,
            children: [
              for (final t in ['cni', 'passport'])
                ChoiceChip(
                  label: Text('landlord.verify.id_$t'.tr),
                  selected: _idType == t,
                  selectedColor: AppDesign.accentSubtle,
                  onSelected: _sending
                      ? null
                      : (_) => setState(() {
                          _idType = t;
                          _errors.remove('id_document_type');
                          if (t == 'passport') _errors.remove('id_back');
                        }),
                ),
            ],
          ),
          if (_errors['id_document_type'] != null)
            Text(
              _errors['id_document_type']!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: AppDesign.space3),
          Row(
            children: [
              Expanded(
                child: _FileTile(
                  label: 'landlord.verify.front'.tr,
                  file: _front,
                  key: _fieldKeys['id_front'],
                  errorText: _errors['id_front'],
                  icon: Icons.badge_outlined,
                  onTap: () async {
                    if (_sending) return;
                    final f = await LandlordPickers.photo(context);
                    if (f != null) _replaceFile('id_front', () => _front = f);
                  },
                ),
              ),
              if (_idType == 'cni') ...[
                const SizedBox(width: AppDesign.space3),
                Expanded(
                  child: _FileTile(
                    label: 'landlord.verify.back'.tr,
                    file: _back,
                    key: _fieldKeys['id_back'],
                    errorText: _errors['id_back'],
                    icon: Icons.badge_outlined,
                    onTap: () async {
                      if (_sending) return;
                      final f = await LandlordPickers.photo(context);
                      if (f != null) _replaceFile('id_back', () => _back = f);
                    },
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppDesign.space6),
          _Step(number: 2, title: 'landlord.verify.proof_title'.tr),
          DropdownButtonFormField<String>(
            key: _fieldKeys['ownership_proof_type'],
            initialValue: _proofType,
            decoration: InputDecoration(
              labelText: 'landlord.verify.proof_type'.tr,
              errorText: _errors['ownership_proof_type'],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDesign.radiusSm),
              ),
            ),
            items: [
              for (final t in _proofTypes)
                DropdownMenuItem(value: t, child: Text('landlord.proof.$t'.tr)),
            ],
            onChanged: _sending
                ? null
                : (v) => setState(() {
                    _proofType = v ?? _proofType;
                    _errors.remove('ownership_proof_type');
                  }),
          ),
          const SizedBox(height: AppDesign.space3),
          _FileTile(
            label: 'landlord.verify.proof_file'.tr,
            file: _proof,
            key: _fieldKeys['ownership_proof'],
            errorText: _errors['ownership_proof'],
            icon: Icons.description_outlined,
            onTap: () async {
              if (_sending) return;
              final f = await LandlordPickers.photo(context);
              if (f != null) _replaceFile('ownership_proof', () => _proof = f);
            },
          ),
          const SizedBox(height: AppDesign.space6),
          _Step(number: 3, title: 'landlord.verify.video_title'.tr),
          Text(
            'landlord.verify.video_help'.tr,
            style: context.textStyle(
              FontSizeType.body2,
              color: context.ds.textSecondary,
            ),
          ),
          const SizedBox(height: AppDesign.space3),
          _FileTile(
            label: 'landlord.verify.video_button'.tr,
            file: _video,
            key: _fieldKeys['video'],
            errorText: _errors['video'],
            icon: Icons.videocam_outlined,
            onTap: () async {
              if (_sending) return;
              final f = await LandlordPickers.video(context);
              if (f != null) _replaceFile('video', () => _video = f);
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
                const Icon(
                  Icons.lock_outline_rounded,
                  color: AppDesign.infoText,
                ),
                const SizedBox(width: AppDesign.space2),
                Expanded(
                  child: Text(
                    'landlord.verify.privacy'.tr,
                    style: context.textStyle(
                      FontSizeType.body2,
                      color: AppDesign.infoText,
                    ),
                  ),
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
            child: Text(
              '$number',
              style: context.textStyle(
                FontSizeType.caption,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: AppDesign.space2),
          Expanded(
            child: Text(
              title,
              style: context.textStyle(
                FontSizeType.subtitle1,
                fontWeight: FontWeight.w700,
                color: context.ds.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({
    super.key,
    required this.label,
    required this.file,
    required this.icon,
    required this.onTap,
    this.errorText,
  });

  final String label;
  final XFile? file;
  final IconData icon;
  final VoidCallback onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final done = file != null;

    return AppCard(
      onTap: onTap,
      color: done ? AppDesign.successSubtle : null,
      padding: const EdgeInsets.all(AppDesign.space4),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : icon,
            color: done ? AppDesign.success : context.ds.textSecondary,
          ),
          const SizedBox(width: AppDesign.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: context.textStyle(
                    FontSizeType.body1,
                    fontWeight: FontWeight.w600,
                    color: context.ds.textPrimary,
                  ),
                ),
                if (errorText != null)
                  Text(
                    errorText!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                Text(
                  done ? file!.name : 'landlord.verify.tap_to_add'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyle(
                    FontSizeType.caption,
                    color: context.ds.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
